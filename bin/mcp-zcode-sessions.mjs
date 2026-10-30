#!/usr/bin/env node
// stdio MCP server exposing ZCode desktop session data (read-only) plus a
// narrow set of write tools. Backed by the app's SQLite databases:
// ~/.zcode/cli/db/db.sqlite (sessions, transcripts; WAL — short writes while
// the app runs are safe) and ~/.zcode/v2/tasks-index.sqlite (task index and
// the automation queue).
//
// Read tools run on a readOnly connection — SQLite refuses writes there, so a
// bug in a read tool cannot touch data. Writes: rename_session (title), and
// the automation queue — send_message (deliver a prompt into an existing
// session) and spawn_session (create a NEW session running a prompt). Both
// queue one-shot rows into `automations`; the app's scheduler (20 s DB poll)
// does the delivery — for spawn_session it calls createTask (new session with
// the given workspace path, model pin and mode) + sendPrompt, the same path
// cron automations take when they start a fresh session.

import { createInterface } from 'node:readline';
import { DatabaseSync } from 'node:sqlite';
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

const DB = join(homedir(), '.zcode/cli/db/db.sqlite');
const TASKS_DB = join(homedir(), '.zcode/v2/tasks-index.sqlite');
const ROLLOUT_DIR = join(homedir(), '.zcode/cli/rollout');
const LOG_DIR = join(homedir(), '.zcode/cli/log');

const SKIP_PART_TYPES = new Set(['step-start', 'step-finish', 'timeline']);

let reader;

// ---------- database helpers ----------

function ro() {
  reader ??= new DatabaseSync(DB, { readOnly: true });
  return reader;
}

// Local time, not ISO/UTC: it matches the app UI and sqlite 'localtime', so
// MCP output and direct SQL agree without mental conversion.
function iso(ms) {
  if (!ms) return null;
  const d = new Date(ms);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ` +
    `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

function clip(s, n) {
  s = String(s ?? '');
  return s.length <= n ? s : s.slice(0, n) + ` …[${s.length - n} chars more]`;
}

// User-role texts the app injects rather than the user typing. Both real inputs
// and injections carry the same part shape (time included), so only the
// wrapper prefixes tell them apart.
const INJECTED_USER_PREFIXES = [
  'Available agent types',
  'The TodoWrite tool',
  'This session is being continued',
  'The user sent a new message while you were working',
  '<system-reminder>',
  '<untrusted_gen_ui_state>',
  '<task-notification>',
];

function looksInjected(text) {
  return INJECTED_USER_PREFIXES.some(p => text.startsWith(p));
}

function requireSession(id) {
  const row = ro().prepare(
    'SELECT id, title, title_source, task_type, parent_id, directory, workspace_id,' +
    ' time_created, time_updated, last_outcome' +
    ' FROM session WHERE id = ? AND time_deleted IS NULL'
  ).get(id);
  if (!row) throw new Error(`session not found (or deleted): ${id}`);
  return row;
}

// ---------- tools ----------

function listSessions(args) {
  const { query = null, directory = null, title_source = null, outcome = null,
    since = null, until = null, include_subagents = false, limit = 20 } = args || {};
  let sql = 'SELECT id, title, title_source, task_type, directory, workspace_id,' +
    ' time_created, time_updated, last_outcome FROM session WHERE time_deleted IS NULL';
  const params = [];
  if (!include_subagents) sql += ' AND parent_id IS NULL';
  if (query) { sql += ' AND title LIKE ?'; params.push(`%${query}%`); }
  if (directory) { sql += ' AND directory LIKE ?'; params.push(`%${directory}%`); }
  if (title_source) { sql += ' AND title_source = ?'; params.push(title_source); }
  if (outcome) { sql += ' AND last_outcome = ?'; params.push(outcome); }
  if (since) { sql += ' AND time_updated >= ?'; params.push(Date.parse(since) || since); }
  if (until) { sql += ' AND time_updated <= ?'; params.push(Date.parse(until) || until); }
  sql += ' ORDER BY time_updated DESC LIMIT ?';
  params.push(Math.min(Number(limit) || 20, 100));
  const rows = ro().prepare(sql).all(...params);
  if (!rows.length) return 'no sessions match';
  return rows.map(r =>
    `${r.id}\n  ${clip(r.title, 100)} [${r.title_source}${r.task_type === 'interactive' ? '' : ',' + r.task_type}]\n` +
    `  ${iso(r.time_updated)}  ${r.directory}` +
    (r.last_outcome ? `  outcome: ${clip(r.last_outcome, 40)}` : '')
  ).join('\n\n');
}

function getSession(args) {
  const s = requireSession(args.session_id);
  let inputs = ro().prepare(
    'SELECT kind, text, time_created, attachments FROM input_history' +
    ' WHERE session_id = ? ORDER BY time_created'
  ).all(s.id);
  let rebuilt = false;
  if (!inputs.length) {
    // input_history is a pruned recency cache, not a per-session store — old
    // sessions fall back to their user parts, wrapper injections filtered out.
    rebuilt = true;
    inputs = ro().prepare(
      `SELECT p.time_created, p.data FROM part p` +
      ' LEFT JOIN message m ON m.id = p.message_id' +
      ` WHERE p.session_id = ? AND json_extract(m.data, '$.role') = 'user'` +
      ` AND json_extract(p.data, '$.type') = 'text' ORDER BY p.time_created`
    ).all(s.id).reduce((acc, r) => {
      const d = JSON.parse(r.data);
      if (d.text && !looksInjected(d.text) && !acc.some(i => i.text === d.text)) {
        acc.push({ kind: 'prompt', text: d.text, time_created: r.time_created, attachments: null });
      }
      return acc;
    }, []).slice(0, 10);
  }
  const counts = {};
  for (const r of ro().prepare(
    `SELECT json_extract(data, '$.type') t, count(*) c FROM part WHERE session_id = ? GROUP BY t`
  ).all(s.id)) counts[r.t] = r.c;
  const lines = [
    `${s.id} [${s.title_source}]`,
    `title: ${s.title}`,
    `created: ${iso(s.time_created)}   updated: ${iso(s.time_updated)}` +
      (s.last_outcome ? `   outcome: ${s.last_outcome}` : ''),
    `directory: ${s.directory}${s.parent_id ? `\nparent: ${s.parent_id}` : ''}`,
    `parts: ${JSON.stringify(counts)}`,
    '',
    'user inputs:',
  ];
  if (!inputs.length) lines.push('  (none)');
  if (rebuilt && inputs.length) {
    lines.push('  (rebuilt from the transcript: input_history pruned this session; wrapper injections filtered by prefix)');
  }
  const shown = inputs;
  for (const i of shown) {
    const nAttach = i.attachments ? JSON.parse(i.attachments).length : 0;
    lines.push(`  ${iso(i.time_created)} [${i.kind}] ${clip(i.text, 300)}` +
      (nAttach ? ` (+${nAttach} attachment${nAttach > 1 ? 's' : ''})` : ''));
  }
  if (rebuilt && inputs.length === 10) lines.push('  (+more — narrow with get_transcript)');
  return lines.join('\n');
}

function getTranscript(args) {
  const s = requireSession(args.session_id);
  const { types = ['text', 'tool'], maxChars = 1200, limit = 50, offset = 0 } = args || {};
  const want = new Set(Array.isArray(types) ? types : [types]);
  const rows = ro().prepare(
    `SELECT p.time_created, p.data, json_extract(m.data, '$.role') role` +
    ' FROM part p LEFT JOIN message m ON m.id = p.message_id' +
    ' WHERE p.session_id = ? ORDER BY p.time_created, p.sequence'
  ).all(s.id);
  const picked = [];
  for (const r of rows) {
    const d = JSON.parse(r.data);
    if (SKIP_PART_TYPES.has(d.type)) continue;
    if (!want.has(d.type)) continue;
    picked.push({ t: r.time_created, role: r.role || '?', d });
  }
  const slice = picked.slice(Number(offset) || 0, (Number(offset) || 0) + (Math.min(Number(limit) || 50, 200)));
  const cap = Math.min(Number(maxChars) || 1200, 6000);
  // Real user inputs are mirrored in input_history; other user-role text parts
  // are environment injections (AGENTS.md, agent lists) — label them context.
  const realInputs = new Set(
    ro().prepare('SELECT text FROM input_history WHERE session_id = ?').all(s.id).map(r => r.text)
  );
  const isRealInput = (text) => {
    for (const t of realInputs) if (t && text.startsWith(t.slice(0, 60))) return true;
    return !realInputs.size && !looksInjected(text);
  };
  const lines = [`session ${s.id}: ${slice.length} of ${picked.length} parts (types ${[...want].join(',')})`];
  for (const p of slice) {
    const stamp = iso(p.t).slice(11);
    if (p.d.type === 'text') {
      const who = p.role === 'user' ? (isRealInput(p.d.text) ? 'USER' : 'context') : 'assistant';
      lines.push(`\n[${stamp}] ${who}:\n${clip(p.d.text, cap)}`);
    } else if (p.d.type === 'tool') {
      const st = p.d.state || {};
      const input = st.input ? JSON.stringify(st.input) : '';
      const status = st.status && st.status !== 'completed' ? ` (${st.status})` : '';
      lines.push(`\n[${stamp}] tool ${p.d.tool}${status}\n  in: ${clip(input, Math.min(cap, 1500))}` +
        (st.output != null ? `\n  out: ${clip(st.output, Math.min(cap, 1500))}` : ''));
    } else if (p.d.type === 'reasoning') {
      lines.push(`\n[${stamp}] thinking:\n${clip(p.d.text, cap)}`);
    } else if (p.d.type === 'file') {
      lines.push(`\n[${stamp}] file: ${clip(d0f(p.d), 200)}`);
    }
  }
  if (picked.length > slice.length) lines.push(`\n(+${picked.length - slice.length} more parts — use offset/limit)`);
  return lines.join('\n');
}

function d0f(d) {
  return d.path || d.name || JSON.stringify(d).slice(0, 120);
}

// Titles and inputs are matched in JS (LIKE/lower() are ASCII-only and would
// miss Cyrillic case variants); transcripts are prefiltered by LIKE over the
// stored JSON — raw UTF-8, so Cyrillic matches there, but case-sensitively.
function searchSessions(args) {
  const q = String(args.query || '').trim();
  if (!q) throw new Error('query is required');
  const { directory = null, title_source = null, since = null, until = null,
    include_subagents = false, limit = 20 } = args || {};
  let sql = 'SELECT id, title, title_source, directory, time_updated, last_outcome' +
    ' FROM session WHERE time_deleted IS NULL';
  const params = [];
  if (!include_subagents) sql += ' AND parent_id IS NULL';
  if (directory) { sql += ' AND directory LIKE ?'; params.push(`%${directory}%`); }
  if (title_source) { sql += ' AND title_source = ?'; params.push(title_source); }
  if (since) { sql += ' AND time_updated >= ?'; params.push(Date.parse(since) || since); }
  if (until) { sql += ' AND time_updated <= ?'; params.push(Date.parse(until) || until); }
  sql += ' ORDER BY time_updated DESC';
  const needle = q.toLowerCase();
  const like = q.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  const inputsBySession = {};
  for (const r of ro().prepare('SELECT session_id, text, time_created FROM input_history').all()) {
    (inputsBySession[r.session_id] ??= []).push(r);
  }
  const transcriptHit = ro().prepare(
    'SELECT time_created, data FROM part WHERE session_id = ? AND data LIKE ? LIMIT 3'
  );
  const around = (text, at) => {
    const start = Math.max(0, at - 60);
    return ((start > 0 ? '…' : '') + text.slice(start, at + q.length + 120) + '…').replace(/\n/g, ' ⏎ ');
  };
  const lines = [];
  let n = 0;
  for (const s of ro().prepare(sql).all(...params)) {
    const hits = [];
    if (s.title.toLowerCase().includes(needle)) hits.push(`title: ${clip(s.title, 200)}`);
    for (const i of inputsBySession[s.id] || []) {
      const at = i.text.toLowerCase().indexOf(needle);
      if (at >= 0) hits.push(`${iso(i.time_created)}  ${around(i.text, at)}`);
    }
    if (hits.length < 3) {
      for (const p of transcriptHit.all(s.id, `%${like}%`)) {
        const raw = JSON.parse(p.data);
        const text = raw.text || raw.state?.output || JSON.stringify(raw.state?.input || '');
        const at = text.toLowerCase().indexOf(needle);
        if (at < 0) continue; // the LIKE hit lives in escaped JSON, not the visible text
        hits.push(`${iso(p.time_created)}  [transcript] ${around(text, at)}`);
        if (hits.length >= 3) break;
      }
    }
    if (!hits.length) continue;
    n++;
    lines.push(`\n${s.id}\n  ${clip(s.title, 100)} [${s.title_source}]\n` +
      `  ${iso(s.time_updated)}  ${s.directory}` +
      (s.last_outcome ? `  outcome: ${s.last_outcome}` : '') + '\n' +
      hits.slice(0, 3).map(h => `  > ${clip(h, 260)}`).join('\n') +
      (hits.length > 3 ? `\n  (+${hits.length - 3} more matches)` : ''));
    if (n >= Math.min(Number(limit) || 20, 100)) break;
  }
  return n ? `${n} session(s) matching "${q}":\n${lines.join('\n')}` : `no sessions match: ${q}`;
}

function findInTranscript(args) {
  const s = requireSession(args.session_id);
  const q = String(args.query || '');
  if (!q) throw new Error('query is required');
  const { context = 160, limit = 20 } = args || {};
  const rows = ro().prepare(
    `SELECT p.time_created, p.data, json_extract(m.data, '$.role') role` +
    ' FROM part p LEFT JOIN message m ON m.id = p.message_id' +
    " WHERE p.session_id = ? AND p.data LIKE ? ORDER BY p.time_created LIMIT ?"
  ).all(s.id, `%${q}%`, Math.min(Number(limit) || 20, 100));
  if (!rows.length) return `no transcript parts match: ${q}`;
  const cap = Math.min(Number(context) || 160, 800);
  const lines = [];
  let n = 0;
  for (const r of rows) {
    n++;
    const raw = JSON.parse(r.data);
    const text = raw.text || raw.state?.output || JSON.stringify(raw.state?.input || '');
    const i = text.indexOf(q);
    const start = Math.max(0, i - cap / 2);
    const snippet = (start > 0 ? '…' : '') + text.slice(start, i + q.length + cap) + '…';
    lines.push(`\n#${n} [${iso(r.time_created).slice(11)}] ${raw.type}${raw.tool ? ' ' + raw.tool : ''} (${r.role})` +
      `\n  ${snippet.replace(/\n/g, ' ⏎ ')}`);
  }
  return `${n} match(es) for "${q}":\n${lines.join('\n')}`;
}

// Read-only escape hatch for one-off shapes no fixed tool covers (GROUP BY,
// odd filters). The connection is readOnly — SQLite refuses writes there.
function runQuery(args) {
  const sql = String(args.sql || '').trim();
  if (!/^(select|with)\b/i.test(sql)) throw new Error('only a single SELECT/WITH statement is allowed');
  const rows = ro().prepare(sql).all();
  return `${rows.length} row(s)\n` + clip(rows.map(r => JSON.stringify(r)).join('\n'), 10000);
}

// One JSON event per line (timestamp UTC, level, event, message, sessionId,
// context{...}), 25-120 MB per day — streamed, never loaded whole. Cheap
// substring prefilters run per line; JSON.parse runs only on candidates.
async function searchLog(args) {
  const { day = null, days = 1, session_id = null, query = null, level = null,
    since = null, until = null, limit = 30 } = args || {};
  const list = [];
  if (day) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) throw new Error('day must be YYYY-MM-DD');
    list.push(day);
  } else {
    const n = Math.min(Math.max(Number(days) || 1, 1), 7);
    const p = (x) => String(x).padStart(2, '0');
    for (let i = n - 1; i >= 0; i--) {
      const dt = new Date(Date.now() - i * 86400000);
      list.push(`${dt.getFullYear()}-${p(dt.getMonth() + 1)}-${p(dt.getDate())}`);
    }
  }
  const when = (v) => {
    const m = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/.exec(String(v).trim());
    if (m) return { tod: (+m[1] * 3600 + +m[2] * 60 + +(m[3] || 0)) * 1000 };
    const t = Date.parse(v);
    if (Number.isNaN(t)) throw new Error(`bad time: ${v} (expect HH:MM or an ISO datetime)`);
    return { abs: t };
  };
  const lo = since ? when(since) : null;
  const hi = until ? when(until) : null;
  const needle = query ? query.toLowerCase() : null;
  const maxLines = Math.min(Number(limit) || 30, 200);
  const out = [];
  let total = 0;
  let truncated = false;
  outer:
  for (const d of list) {
    const file = join(LOG_DIR, `zcode-${d}.jsonl`);
    if (!existsSync(file)) { out.push(`(no log file for ${d})`); continue; }
    const dayStart = Date.parse(`${d}T00:00:00`);
    const resolve = (w) => (w ? (w.abs !== undefined ? w.abs : dayStart + w.tod) : null);
    const loT = resolve(lo);
    const hiT = resolve(hi);
    const rl = createInterface({ input: createReadStream(file) });
    try {
      for await (const line of rl) {
        if (!line) continue;
        if (session_id && !line.includes(session_id)) continue;
        if (level && !line.includes(`"level":"${level}"`)) continue;
        if (needle && !line.toLowerCase().includes(needle)) continue;
        let rec;
        try { rec = JSON.parse(line); } catch { rec = {}; }
        const t = rec.timestamp ? Date.parse(rec.timestamp) : null;
        if ((loT != null || hiT != null) && t == null) continue;
        if (loT != null && t < loT) continue;
        if (hiT != null && t > hiT) continue;
        total++;
        out.push(`\n${iso(t).slice(11)} ${rec.level || '?'} ${rec.event || rec.message || ''}` +
          `\n  ${clip(line, 260)}`);
        if (total >= maxLines) { truncated = true; break outer; }
      }
    } finally {
      rl.close();
    }
  }
  const head = `${total} match(es) in ${list.join(', ')}${truncated ? ' (stopped at limit — narrow the query)' : ''}`;
  if (!total) out.push('no matching log lines');
  return `${head}\n${out.join('\n')}`;
}

function renameSession(args) {
  const title = String(args.title || '').trim();
  if (!title) throw new Error('title is required');
  let id = args.session_id || null;
  if (!id) {
    // "current session" = the rollout file written last (only open sessions
    // have rollout files; if several windows stream at once, newest wins).
    const latest = readdirSync(ROLLOUT_DIR)
      .filter(f => /^model-io-session_.+\.jsonl$/.test(f))
      .map(f => ({ f, mtime: statSync(join(ROLLOUT_DIR, f)).mtimeMs }))
      .sort((a, b) => b.mtime - a.mtime)[0];
    if (!latest) throw new Error('session_id is required (no open session found via rollout files)');
    id = latest.f.replace(/^model-io-|\.jsonl$/g, '');
  }
  const s = requireSession(id);
  const db = new DatabaseSync(DB);
  try {
    db.prepare(
      "UPDATE session SET title = ?, title_source = 'custom'," +
      " time_title_updated = ? WHERE id = ? AND time_deleted IS NULL"
    ).run(title, Date.now(), id);
  } finally {
    db.close();
  }
  return `session: ${id}\nwas: ${s.title} [${s.title_source}]\nnow: ${title} [custom]` +
    '\n(the app session list may not repaint instantly; the value is written)';
}

// Interactive sessions carry no model pin in the task index; model_usage has
// the model the session actually runs on. Pinning that on resume is a no-op,
// while the missing pin would make the host fall back to the workspace
// default plan and switch the session off its model.
function sessionModel(id) {
  const db = new DatabaseSync(DB, { readOnly: true });
  try {
    const u = db.prepare(
      'SELECT provider_id, model_id FROM model_usage' +
      ' WHERE session_id = ? AND model_id IS NOT NULL' +
      ' ORDER BY started_at DESC LIMIT 1'
    ).get(id);
    return u ? `${u.provider_id}/${u.model_id}` : null;
  } finally {
    db.close();
  }
}

// Queue a one-shot prompt into ZCode's automation table; the app's scheduler
// (20 s DB poll) delivers it into the target session (resumeTask + sendPrompt)
// — same mechanism bin/zcode-revive uses, which proved the row shape. The
// message lands as a user input; a busy session queues it until its turn ends.
function sendMessage(args) {
  const message = String(args.message || '').trim();
  if (!message) throw new Error('message is required');
  const id = String(args.session_id || '').trim();
  if (!id) throw new Error('session_id is required');
  const db = new DatabaseSync(TASKS_DB);
  try {
    const task = db.prepare(
      'SELECT model, json_extract(meta_json, \'$.thoughtLevel\') thought,' +
      ' workspace_key, workspace_path, project_id, host_id FROM tasks' +
      ' WHERE task_id = ? AND deleted = 0 ORDER BY updated_at DESC LIMIT 1'
    ).get(id);
    if (!task) throw new Error(`session not found in the task index: ${id}`);
    let model = task.model && task.model.includes('/') ? task.model : sessionModel(id);
    if (!model) {
      throw new Error(`no model for target session (no pin in the task index and nothing in model_usage): ${id}`);
    }
    // A task-index pin can carry a reasoning-level suffix ("…/GLM-5.3-Flash$max")
    // which the resume dispatch rejects as a model id — move it into the
    // selection's reasoningLevel, where it belongs.
    const [providerId, rawModelId] = model.split('/');
    const dollar = rawModelId.indexOf('$');
    const modelId = dollar === -1 ? rawModelId : rawModelId.slice(0, dollar);
    const level = dollar === -1 ? (task.thought || 'max') : rawModelId.slice(dollar + 1);
    const selection = {
      providerId, modelId,
      options: { reasoningLevel: level || 'max' },
    };
    // housekeeping: drop settled one-shot rows of ours older than 10 minutes
    db.prepare(
      "DELETE FROM automations WHERE automation_id LIKE 'ext-msg-%'" +
      " AND lifecycle_status = 'completed' AND updated_at < ?"
    ).run(Date.now() - 600000);
    const now = Date.now();
    const aid = `ext-msg-${id.replace(/^session_/, '').slice(0, 12)}-${now}`;
    db.prepare(
      'INSERT INTO automations (' +
      ' automation_id, title, cron_expr, prompt, workspace_key, workspace_path,' +
      ' target_task_id, location_kind, recurring, run_count, scheduled_run_count,' +
      ' enabled, lifecycle_status, next_run_at, schedule_edited_by_user, model_selection,' +
      ' dispatch_status, dispatch_attempts, created_at, updated_at, project_id, host_id' +
      ') VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)'
    ).run(
      aid, `send: ${message.slice(0, 60)}`, '* * * * *', message,
      task.workspace_key, task.workspace_path,
      id, 'local', 0, 0, 0,
      1, 'active', now - 20000, 0, JSON.stringify(selection),
      'idle', 0, now, now, task.project_id || null, task.host_id || 'local'
    );
    return `queued: ${aid}\nto: ${id} (model ${modelId}, thought ${selection.options.reasoningLevel})` +
      '\nZCode delivers it as a user input within ~20 s (a busy session queues it until its turn ends).';
  } finally {
    db.close();
  }
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

function renameTitle(id, title) {
  const db = new DatabaseSync(DB);
  try {
    return db.prepare(
      "UPDATE session SET title = ?, title_source = 'custom'," +
      " time_title_updated = ? WHERE id = ? AND time_deleted IS NULL"
    ).run(title, Date.now(), id).changes > 0;
  } finally {
    db.close();
  }
}

// Spawn a NEW ZCode session running a prompt — a real app session (visible in
// the session list, resumable, able to outlive this call), not a subagent.
// Mechanism: same automation queue send_message uses, but with
// target_task_id NULL — the app's scheduler then runs createTask (new session
// in `directory`, model pinned, permission `mode`) + sendPrompt, the path cron
// automations take for a fresh session. One-shot: the row completes itself.
// Waits for the run row to report the created session id (the scheduler polls
// the DB every ~20 s), then applies `title` if given.
// `mode` is honored end-to-end (2026-10-29: guarded survives to
// session.permission.mode); the tasks.mode column is not — verify via the
// session store or the runtime log, never via tasks.mode. When the caller
// omits mode it inherits the calling session's mode (resolved via process
// cwd), falling back to build — a silent default build has already produced
// a 'ask before changes' child out of an autonomous parent.
// Placement: the scheduler copies the automation row's project_id onto the
// created task, and that id is what pins the session to a project's list in
// the app — without it the session shows under Tasks (verified 2026-10-30 on
// ext-revive rows: their tasks got the automation's project_id). Default:
// copy the newest known project_id of the workspace, so an explicit "spawn a
// session" lands in the project; `task: true` (drills, background pipelines)
// skips the copy and lands in Tasks.
async function spawnSession(args) {
  const prompt = String(args.prompt || '').trim();
  if (!prompt) throw new Error('prompt is required');
  const directory = String(args.directory || '').trim();
  if (!directory || !directory.startsWith('/')) throw new Error('directory is required (absolute path — the new session\'s working directory)');
  if (!existsSync(directory)) throw new Error(`directory does not exist: ${directory}`);
  const model = String(args.model || '').trim();
  // A missing pin would force the workspace default plan onto the new session.
  if (!model.includes('/')) {
    throw new Error("model is required as 'provider/model' (e.g. 'account:zai-individual-coding-plan/GLM-5.3-Flash') — a missing pin forces the workspace default plan");
  }
  // Permission mode: explicit wins; when omitted, inherit the calling
  // session's own mode — the 2026-10-30 incident: an /opsx:apply session
  // running guarded omitted mode, guessed its own mode wrong, and the child
  // got the default build ('ask before changes'). Inheritance, not escalation
  // — same rule the sentry_drill docs state for fixers. The caller is the
  // newest open main session in process cwd (the same resolution
  // current_session uses); an unresolvable caller falls back to build.
  const MODES = ['build', 'edit', 'plan', 'yolo', 'guarded'];
  let mode = String(args.mode || '').trim();
  let modeFrom = 'explicit';
  if (!mode) {
    const caller = openMainSessions(process.cwd())[0]?.s;
    if (caller?.mode && MODES.includes(caller.mode)) {
      mode = caller.mode;
      modeFrom = `inherited from the calling session ${caller.id}`;
    } else {
      mode = 'build';
      modeFrom = 'default (calling session not resolved in process cwd)';
    }
  } else if (!MODES.includes(mode)) {
    throw new Error(`unknown mode: ${mode} (build | edit | plan | yolo | guarded)`);
  }
  const thoughtLevel = String(args.thought_level || 'max').trim();
  const title = args.title ? String(args.title).trim() : null;
  const asTask = args.task === true;
  // The app groups the session list per project by the task's project_id.
  // One workspace maps to one project (checked over the whole task index), so
  // the newest task's id is the workspace's project; a directory never opened
  // in the app has no task rows and nothing to copy — such a spawn lands in
  // Tasks regardless of the flag.
  let projectId = null;
  if (!asTask) {
    const q = new DatabaseSync(TASKS_DB, { readOnly: true });
    try {
      projectId = q.prepare(
        'SELECT project_id FROM tasks WHERE workspace_key = ? AND deleted = 0' +
        " AND project_id IS NOT NULL AND project_id != ''" +
        ' ORDER BY updated_at DESC LIMIT 1'
      ).get(directory)?.project_id || null;
    } finally {
      q.close();
    }
  }
  const placement = asTask ? 'Tasks' : projectId ? 'the project session list' : "Tasks (no project known for this directory yet)";
  const [providerId, modelId] = model.split('/');
  const selection = { providerId, modelId, options: { reasoningLevel: thoughtLevel } };

  const db = new DatabaseSync(TASKS_DB);
  let aid;
  try {
    db.prepare(
      "DELETE FROM automations WHERE automation_id LIKE 'ext-spawn-%'" +
      " AND lifecycle_status = 'completed' AND updated_at < ?"
    ).run(Date.now() - 600000);
    const now = Date.now();
    aid = `ext-spawn-${now}`;
    db.prepare(
      'INSERT INTO automations (' +
      ' automation_id, title, cron_expr, prompt, workspace_key, workspace_path,' +
      ' location_kind, recurring, run_count, scheduled_run_count,' +
      ' enabled, lifecycle_status, next_run_at, schedule_edited_by_user, model_selection,' +
      ' mode, dispatch_status, dispatch_attempts, created_at, updated_at, host_id, project_id' +
      ') VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)'
    ).run(
      aid, `spawn: ${prompt.slice(0, 60)}`, '* * * * *', prompt,
      directory, directory,
      'local', 0, 0, 0,
      1, 'active', now - 20000, 0, JSON.stringify(selection),
      mode, 'idle', 0, now, now, 'local', projectId
    );
  } finally {
    db.close();
  }

  // The scheduler polls every ~20 s; give it a generous window, then report
  // either way — the row stays queued and fires when the app gets to it.
  let run = null;
  const deadline = Date.now() + 60000;
  while (Date.now() < deadline) {
    await sleep(2000);
    const q = new DatabaseSync(TASKS_DB, { readOnly: true });
    try {
      run = q.prepare(
        'SELECT session_id, outcome, error FROM automation_runs' +
        ' WHERE automation_id = ? ORDER BY created_at DESC LIMIT 1'
      ).get(aid);
    } finally {
      q.close();
    }
    if (run && (run.session_id || run.error)) break;
  }

  if (!run || !run.session_id) {
    const why = run?.error ? `\nerror: ${run.error}` : '';
    return `queued: ${aid}\ndirectory: ${directory} (model ${modelId}, mode ${mode})` +
      `\nno session id yet after 60 s${why}` +
      '\nThe row stays queued — check `query` on automation_runs later, or list_sessions for a new session in that directory. If the ZCode app is not running, the scheduler delivers when it starts.';
  }

  let renamed = '';
  if (title) {
    for (let i = 0; i < 3; i++) {
      if (renameTitle(run.session_id, title)) { renamed = `\ntitle: ${title}`; break; }
      await sleep(1500);
    }
  }
  return `spawned: ${run.session_id}${renamed}` +
    `\nautomation: ${aid}\ndirectory: ${directory}  model: ${modelId}  thought: ${thoughtLevel}` +
    `\nmode: ${mode} (${modeFrom})` +
    `\nlands in: ${placement}` +
    '\nThe session starts working on the prompt on its own (first response within ~20-60 s); it is a regular app session — resumable and reachable via send_message.';
}

// Open main sessions in `dir` (open = streaming a rollout file — only open
// ones have one), newest first, subagents excluded. The shared discovery
// behind current_session and spawnSession's mode inheritance.
function openMainSessions(dir) {
  return readdirSync(ROLLOUT_DIR)
    .filter(f => /^model-io-session_.+\.jsonl$/.test(f))
    .map(f => ({
      id: f.replace(/^model-io-|\.jsonl$/g, ''),
      mtime: statSync(join(ROLLOUT_DIR, f)).mtimeMs,
    }))
    .sort((a, b) => b.mtime - a.mtime)
    .map(o => ({ ...o, s: ro().prepare(
      'SELECT id, title, title_source, directory, parent_id,' +
      " json_extract(permission, '$.mode') AS mode FROM session WHERE id = ?"
    ).get(o.id) }))
    .filter(o => o.s && !o.s.parent_id && o.s.directory === dir);
}

// Best-effort id of the CALLING session — the one the user is talking to.
// Only open sessions stream rollout files; among main sessions (subagents
// excluded via parent_id) whose directory matches, the newest rollout wins.
// Ambiguity (two open main sessions in one directory) is reported, not hidden.
function currentSession(args) {
  const dir = String(args.directory || process.cwd()).trim();
  const rows = openMainSessions(dir);
  if (!rows.length) {
    const any = ro().prepare(
      'SELECT id, title, directory FROM session WHERE directory = ? AND time_deleted IS NULL' +
      ' AND parent_id IS NULL ORDER BY time_updated DESC LIMIT 5'
    ).all(dir);
    return `no OPEN main session found in ${dir}` +
      (any.length ? `\nclosed sessions there (for reference):\n${any.map(s => `  ${s.id}  ${clip(s.title, 80)}`).join('\n')}` : '') +
      '\nAn open session streams a rollout file (only open ones do); a spawned child session in another directory does not match. Pass the directory of the session you are running in.';
  }
  if (rows.length > 1) {
    return `several open main sessions in ${dir} — newest first, pick by title:\n` +
      rows.map(r => `  ${r.id}  ${clip(r.s.title, 80)} [${r.s.title_source}]`).join('\n');
  }
  const r = rows[0];
  // The task row carries the model pin (provider/model) for spawned sessions;
  // interactive sessions have none there, so fall back to the model they
  // actually run on (model_usage) — that pin is what spawn_session wants when
  // the spawned session should follow this one.
  const task = (() => {
    const db = new DatabaseSync(TASKS_DB, { readOnly: true });
    try {
      return db.prepare(
        'SELECT model, json_extract(meta_json, \'$.thoughtLevel\') thought FROM tasks' +
        ' WHERE task_id = ? AND deleted = 0 ORDER BY updated_at DESC LIMIT 1'
      ).get(r.id);
    } finally {
      db.close();
    }
  })();
  const model = task?.model && task.model.includes('/') ? task.model : sessionModel(r.id);
  return `${r.id}\ntitle: ${clip(r.s.title, 100)} [${r.s.title_source}]\ndirectory: ${r.s.directory}` +
    (r.s.mode ? `\nmode: ${r.s.mode} — pass as spawn_session mode to make the spawned session inherit this one's permission mode` : '') +
    (model ? `\nmodel: ${model}${task?.thought ? ` (thought ${task.thought})` : ''} — pass as spawn_session model to follow this session` : '') +
    '\nThis is the newest open main session in that directory — treat it as the current one.';
}

// ---------- tool metadata ----------

const sessionIdArg = {
  type: 'string',
  description: 'ZCode session id (session_<hex>, from "Copy session ID" in the app or list_sessions)',
};

const TOOLS = [
  {
    name: 'list_sessions',
    description: 'List ZCode desktop sessions, newest first. Main sessions only by default ' +
      '(include_subagents for subagent children). Filters: title substring (query), directory ' +
      'substring (directory), title_source (first_input/generated/custom), outcome ' +
      '(completed/interrupted/error), updated time range (since/until, ISO or epoch ms). ' +
      'Returns id, title, title_source, timestamps, working directory, last outcome.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'substring of the title' },
        directory: { type: 'string', description: 'substring of the working directory' },
        title_source: { type: 'string', description: 'exact match: first_input, generated or custom' },
        outcome: { type: 'string', description: 'exact match on last_outcome: completed, interrupted, error' },
        since: { type: 'string', description: 'updated after this (ISO or epoch ms)' },
        until: { type: 'string', description: 'updated before this (ISO or epoch ms)' },
        include_subagents: { type: 'boolean', description: 'include subagent child sessions (default false)' },
        limit: { type: 'number', description: 'max rows, default 20, cap 100' },
      },
    },
  },
  {
    name: 'search_sessions',
    description: 'Find sessions by content, no session id needed (get_session/find_in_transcript ' +
      'require one). Matches titles and user inputs case-insensitively, then scans the full ' +
      'transcripts (input_history holds only recent inputs — the transcripts cover weeks). ' +
      'Transcript matches are case-insensitive only for Latin; Cyrillic matches there ' +
      'case-sensitively. Returns sessions with the matching lines. Filters: directory, ' +
      'title_source, since/until, include_subagents (default false), limit.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'case-insensitive substring of user inputs or title' },
        directory: { type: 'string', description: 'substring of the working directory' },
        title_source: { type: 'string', description: 'exact match: first_input, generated or custom' },
        since: { type: 'string', description: 'updated after this (ISO or epoch ms)' },
        until: { type: 'string', description: 'updated before this (ISO or epoch ms)' },
        include_subagents: { type: 'boolean', description: 'include subagent child sessions (default false)' },
        limit: { type: 'number', description: 'max sessions, default 20, cap 100' },
      },
      required: ['query'],
    },
  },
  {
    name: 'get_session',
    description: 'Session metadata + all user inputs (prompts, steers) with timestamps, ' +
      'and per-type part counts. The compact entry point before reading the transcript. ' +
      'input_history is a pruned recency cache — for old sessions the inputs are ' +
      'rebuilt from the transcript (wrapper injections filtered by prefix).',
    inputSchema: {
      type: 'object',
      properties: { session_id: sessionIdArg },
      required: ['session_id'],
    },
  },
  {
    name: 'get_transcript',
    description: 'Read a session transcript: parts ordered chronologically, joined with the ' +
      'message role (USER vs assistant). Types: text (default), tool (calls with input and ' +
      'output), reasoning (model thinking, off by default). Use offset/limit for paging.',
    inputSchema: {
      type: 'object',
      properties: {
        session_id: sessionIdArg,
        types: { type: 'array', items: { type: 'string', enum: ['text', 'tool', 'reasoning', 'file'] }, description: 'part types to include, default ["text","tool"]' },
        maxChars: { type: 'number', description: 'per-part cap, default 1200, cap 6000' },
        limit: { type: 'number', description: 'max parts per call, default 50' },
        offset: { type: 'number', description: 'skip N parts, for paging' },
      },
      required: ['session_id'],
    },
  },
  {
    name: 'find_in_transcript',
    description: 'Substring search across a session transcript parts (texts, tool inputs, outputs). ' +
      'Returns matches with a context window — the fastest way to find an error or a command.',
    inputSchema: {
      type: 'object',
      properties: {
        session_id: sessionIdArg,
        query: { type: 'string' },
        context: { type: 'number', description: 'chars of context per side, default 160' },
        limit: { type: 'number', description: 'max matches, default 20' },
      },
      required: ['session_id', 'query'],
    },
  },
  {
    name: 'query',
    description: 'Read-only SQL against the sessions database (~/.zcode/cli/db/db.sqlite — tables: ' +
      'session, input_history, part, message) for aggregations and one-off filters no fixed tool ' +
      'covers. Single SELECT/WITH statement only; the connection is read-only.',
    inputSchema: {
      type: 'object',
      properties: {
        sql: { type: 'string', description: 'a single SELECT/WITH statement' },
      },
      required: ['sql'],
    },
  },
  {
    name: 'search_log',
    description: 'Search ZCode app event logs (~/.zcode/cli/log/zcode-YYYY-MM-DD.jsonl — one ' +
      'JSON event per line: timestamp, level, event, message, sessionId, context). For ' +
      '«what happened inside the app» questions a transcript cannot answer: title generation, ' +
      'model network calls, turn phases, background jobs. Filters: session id, case-insensitive ' +
      'substring of the raw line, exact level, local time window (HH:MM or ISO). Streams the files.',
    inputSchema: {
      type: 'object',
      properties: {
        day: { type: 'string', description: 'YYYY-MM-DD, a single day (default: today)' },
        days: { type: 'number', description: 'scan the last N days including today (default 1, cap 7); ignored when day is given' },
        session_id: { type: 'string', description: 'only lines carrying this session id' },
        query: { type: 'string', description: 'case-insensitive substring of the raw line' },
        level: { type: 'string', description: 'exact level as written in the log: info, warn, error, debug' },
        since: { type: 'string', description: 'local HH:MM or ISO datetime, from' },
        until: { type: 'string', description: 'local HH:MM or ISO datetime, until' },
        limit: { type: 'number', description: 'max lines, default 30, cap 200' },
      },
    },
  },
  {
    name: 'rename_session',
    description: 'Rename a session title (sets title_source=custom so the app stops auto-generating). ' +
      'Without session_id renames the current session. Returns was:/now:. When the user gave no ' +
      'title, propose one and confirm before calling.',
    inputSchema: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        session_id: sessionIdArg,
      },
      required: ['title'],
    },
  },
  {
    name: 'send_message',
    description: 'Send a message (prompt) to another ZCode session by id — cross-session messaging. ' +
      'Queues into the app automation table; the scheduler delivers it as a user input within ~20 s ' +
      '(a busy session queues it until its turn ends). Works for idle and error-stopped sessions.',
    inputSchema: {
      type: 'object',
      properties: {
        session_id: sessionIdArg,
        message: { type: 'string', description: 'text to deliver as a user input' },
      },
      required: ['session_id', 'message'],
    },
  },
  {
    name: 'spawn_session',
    description: 'Spawn a NEW background ZCode session running a prompt — a full app session ' +
      '(own context, resumable, reachable via send_message afterwards), not a subagent. ' +
      'Placement: by default the session is attached to the project `directory` belongs to and shows ' +
      'in that project\'s session list (the default for an explicit "spawn a session" request); ' +
      '`task: true` leaves it unattached so it shows under Tasks — use it for background workers ' +
      'spawned by pipelines and drills. The app scheduler creates the session in `directory` with the ' +
      'model pin and permission mode, then delivers the prompt; the session starts working on its own. ' +
      'Returns the new session id (waits up to 60 s for it). Use for background workers that must ' +
      'outlive the caller and report back.',
    inputSchema: {
      type: 'object',
      properties: {
        prompt: { type: 'string', description: 'the prompt the new session runs (e.g. \'/sentry_fix <handoff path>\')' },
        directory: { type: 'string', description: 'absolute path — the new session\'s working directory (e.g. the worktree path)' },
        model: { type: 'string', description: "'provider/model' pin, e.g. 'account:zai-individual-coding-plan/GLM-5.3-Flash' — required; a missing pin forces the workspace default plan" },
        mode: { type: 'string', enum: ['build', 'edit', 'plan', 'yolo', 'guarded'], description: 'permission mode of the new session. Default: the calling session\'s own mode (resolved like current_session), falling back to build — pass it explicitly only when the child must differ from yours' },
        thought_level: { type: 'string', description: 'reasoning level of the model pin, default max' },
        title: { type: 'string', description: 'optional session title (title_source=custom), applied once the session exists' },
        task: { type: 'boolean', description: 'true — the session shows under Tasks (drills, spawned pipelines); false/omitted — attached to the project of `directory`, its session list. A directory never opened in the app has no project to attach to — such a session lands in Tasks either way' },
      },
      required: ['prompt', 'directory', 'model'],
    },
  },
  {
    name: 'current_session',
    description: 'Id of the CALLING session — the newest OPEN main session in `directory` (default: ' +
      'process cwd), plus its title, permission mode and model pin. Call it once, early, before ' +
      'spawning parallel sessions, and pass the id to them so they can send_message their reports ' +
      'back; pass the mode and model to spawn_session to make the child inherit this session. ' +
      'Subagent sessions are excluded.',
    inputSchema: {
      type: 'object',
      properties: {
        directory: { type: 'string', description: 'absolute path of the calling session\'s working directory (default: process cwd)' },
      },
    },
  },
];

const HANDLERS = {
  list_sessions: listSessions,
  search_sessions: searchSessions,
  get_session: getSession,
  get_transcript: getTranscript,
  find_in_transcript: findInTranscript,
  query: runQuery,
  search_log: searchLog,
  rename_session: renameSession,
  send_message: sendMessage,
  spawn_session: spawnSession,
  current_session: currentSession,
};

// ---------- stdio JSON-RPC ----------

function emit(message) {
  process.stdout.write(JSON.stringify(message) + '\n');
}

function ok(id, text) {
  emit({ jsonrpc: '2.0', id, result: { content: [{ type: 'text', text }] } });
}

function fail(id, error) {
  emit({ jsonrpc: '2.0', id, result: { content: [{ type: 'text', text: String(error?.message || error) }], isError: true } });
}

// Async handlers (searchLog streams big files) must finish before exit —
// stdin closes as soon as the client is done writing, not when we are done.
let inFlight = 0;
let stdinClosed = false;
const maybeExit = () => { if (stdinClosed && inFlight === 0) process.exit(0); };

createInterface({ input: process.stdin }).on('line', (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  let message;
  try {
    message = JSON.parse(trimmed);
  } catch (error) {
    console.error(`mcp-zcode-sessions: unparseable stdin line: ${error.message}`);
    return;
  }
  if (message.id === undefined) return; // notification
  const { id, method, params } = message;
  try {
    if (method === 'initialize') {
      emit({
        jsonrpc: '2.0', id, result: {
          protocolVersion: params?.protocolVersion || '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: { name: 'zcode-sessions', version: '1.4.0' },
        },
      });
    } else if (method === 'tools/list') {
      emit({ jsonrpc: '2.0', id, result: { tools: TOOLS } });
    } else if (method === 'tools/call') {
      const name = params?.name;
      const handler = HANDLERS[name];
      if (!handler) throw new Error(`unknown tool: ${name}`);
      inFlight++;
      Promise.resolve().then(() => handler(params?.arguments || {})).then(
        (text) => ok(id, text),
        (error) => fail(id, error)
      ).finally(() => { inFlight--; maybeExit(); });
    } else if (method === 'ping') {
      emit({ jsonrpc: '2.0', id, result: {} });
    } else {
      emit({ jsonrpc: '2.0', id, error: { code: -32601, message: `method not found: ${method}` } });
    }
  } catch (error) {
    fail(id, error);
  }
}).on('close', () => { stdinClosed = true; maybeExit(); });

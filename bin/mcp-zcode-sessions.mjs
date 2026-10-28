#!/usr/bin/env node
// stdio MCP server exposing ZCode desktop session data (read-only) plus a
// narrow rename tool. Backed by the app's SQLite database:
// ~/.zcode/cli/db/db.sqlite (WAL; short writes while the app runs are safe).
//
// Read tools run on a readOnly connection — SQLite refuses writes there, so a
// bug in a read tool cannot touch data. The only write is rename_session:
// title, title_source='custom', time_title_updated — same fields the stock
// rename-session.sh script wrote.

import { createInterface } from 'node:readline';
import { DatabaseSync } from 'node:sqlite';
import { readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

const DB = join(homedir(), '.zcode/cli/db/db.sqlite');
const ROLLOUT_DIR = join(homedir(), '.zcode/cli/rollout');

const SKIP_PART_TYPES = new Set(['step-start', 'step-finish', 'timeline']);

let reader;

// ---------- database helpers ----------

function ro() {
  reader ??= new DatabaseSync(DB, { readOnly: true });
  return reader;
}

function iso(ms) {
  return ms ? new Date(ms).toISOString().replace('T', ' ').slice(0, 19) : null;
}

function clip(s, n) {
  s = String(s ?? '');
  return s.length <= n ? s : s.slice(0, n) + ` …[${s.length - n} chars more]`;
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
  const { query = null, directory = null, limit = 20, since = null, until = null } = args || {};
  let sql = 'SELECT id, title, title_source, task_type, directory, workspace_id,' +
    ' time_created, time_updated, last_outcome FROM session WHERE time_deleted IS NULL';
  const params = [];
  if (query) { sql += ' AND title LIKE ?'; params.push(`%${query}%`); }
  if (directory) { sql += ' AND directory LIKE ?'; params.push(`%${directory}%`); }
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
  const inputs = ro().prepare(
    'SELECT kind, text, time_created, attachments FROM input_history' +
    ' WHERE session_id = ? ORDER BY time_created'
  ).all(s.id);
  const counts = {};
  for (const r of ro().prepare(
    `SELECT json_extract(data, '$.type') t, count(*) c FROM part WHERE session_id = ? GROUP BY t`
  ).all(s.id)) counts[r.t] = r.c;
  const lines = [
    `${s.id} [${s.title_source}]`,
    `title: ${s.title}`,
    `created: ${iso(s.time_created)}   updated: ${iso(s.time_updated)}` +
      (s.last_outcome ? `   outcome: ${clip(s.last_outcome, 60)}` : ''),
    `directory: ${s.directory}${s.parent_id ? `\nparent: ${s.parent_id}` : ''}`,
    `parts: ${JSON.stringify(counts)}`,
    '',
    'user inputs:',
  ];
  if (!inputs.length) lines.push('  (none)');
  for (const i of inputs) {
    const nAttach = i.attachments ? JSON.parse(i.attachments).length : 0;
    lines.push(`  ${iso(i.time_created)} [${i.kind}] ${clip(i.text, 300)}` +
      (nAttach ? ` (+${nAttach} attachment${nAttach > 1 ? 's' : ''})` : ''));
  }
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
    return false;
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

// ---------- tool metadata ----------

const sessionIdArg = {
  type: 'string',
  description: 'ZCode session id (session_<hex>, from "Copy session ID" in the app or list_sessions)',
};

const TOOLS = [
  {
    name: 'list_sessions',
    description: 'List ZCode desktop sessions, newest first. Filter by title substring (query), ' +
      'directory substring (directory), and updated time range (since/until, ISO or epoch ms). ' +
      'Returns id, title, timestamps, working directory per session.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'substring of the title' },
        directory: { type: 'string', description: 'substring of the working directory' },
        since: { type: 'string', description: 'updated after this (ISO or epoch ms)' },
        until: { type: 'string', description: 'updated before this (ISO or epoch ms)' },
        limit: { type: 'number', description: 'max rows, default 20, cap 100' },
      },
    },
  },
  {
    name: 'get_session',
    description: 'Session metadata + all user inputs (prompts, steers) with timestamps, ' +
      'and per-type part counts. The compact entry point before reading the transcript.',
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
];

const HANDLERS = {
  list_sessions: listSessions,
  get_session: getSession,
  get_transcript: getTranscript,
  find_in_transcript: findInTranscript,
  rename_session: renameSession,
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
          serverInfo: { name: 'zcode-sessions', version: '1.0.0' },
        },
      });
    } else if (method === 'tools/list') {
      emit({ jsonrpc: '2.0', id, result: { tools: TOOLS } });
    } else if (method === 'tools/call') {
      const name = params?.name;
      const handler = HANDLERS[name];
      if (!handler) throw new Error(`unknown tool: ${name}`);
      ok(id, handler(params?.arguments || {}));
    } else if (method === 'ping') {
      emit({ jsonrpc: '2.0', id, result: {} });
    } else {
      emit({ jsonrpc: '2.0', id, error: { code: -32601, message: `method not found: ${method}` } });
    }
  } catch (error) {
    fail(id, error);
  }
}).on('close', () => process.exit(0));

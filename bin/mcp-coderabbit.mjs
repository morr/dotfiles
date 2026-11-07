#!/usr/bin/env node
// stdio MCP server for CodeRabbit review triage on GitHub PRs — the parsing
// half of minisklad's `/coderabbit` skill, moved out of per-session
// improvisation (each run used to write a fresh jq/python digest script).
//
// Tools:
//   list_unresolved_threads — fetch a PR's unresolved review threads and return
//     a compact digest: severity/category/effort, claim, prompt-for-AI,
//     committable suggestion, path:line, isOutdated, url, thread id. Raw bot
//     bodies never enter the caller's context.
//   resolve_threads — batch-resolve review threads (one aliased GraphQL
//     mutation), per-id status back.
//   get_thread_bodies — full raw bodies by thread id; not for walking, this is
//     the format-drift fix loop's input.
//
// Fail-loudly contract: when a coderabbit-authored body does not parse
// (unknown anatomy, newer format marker, missing severity or claim), the whole
// list_unresolved_threads call fails — never a partial digest. The caller's
// workflow must stop and wait for this server to be fixed; the error text
// carries the fix loop. Regression test for that loop:
//   node ~/dotfiles/bin/mcp-coderabbit.mjs --selftest [fixture]
// (no fixture arg → the sibling mcp-coderabbit-fixture.json)

import { execFileSync } from 'node:child_process';
import { createInterface } from 'node:readline';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const VERSION = '1.0.0';
const V1_MARKER = 'coderabbit-ai-generated:v1';
const KNOWN_SEVERITIES = new Set(['major', 'minor']);

function clip(s, n) {
  s = String(s ?? '');
  return s.length <= n ? s : s.slice(0, n) + ` …[${s.length - n} chars more]`;
}

// ---------- gh helpers ----------

function gh(argv, cwd) {
  try {
    return execFileSync('gh', argv, { cwd: cwd || undefined, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  } catch (e) {
    throw new Error(`gh ${argv.join(' ')} failed: ${e.message}${e.stderr ? `\n${e.stderr}` : ''}`);
  }
}

// PR from args or the working directory: explicit pr/repo win, the rest comes
// from `gh pr view` in `directory` (default: this process's cwd).
function resolvePr({ repo = null, pr = null, directory = null }) {
  if (pr && !repo && !directory) throw new Error('pass repo (owner/name) or directory together with pr');
  const argv = ['pr', 'view'];
  if (pr) argv.push(String(pr));
  if (repo) argv.push('-R', repo);
  const meta = JSON.parse(gh([...argv, '--json', 'number,title,headRefName,url'], directory));
  const m = /github\.com\/([^/]+)\/([^/]+)\/pull\//.exec(meta.url || '');
  if (!meta.number || !m) throw new Error(`cannot resolve owner/repo/pr (got url: ${meta.url}) — pass repo and pr explicitly`);
  return { owner: m[1], repo: m[2], pr: meta.number, title: meta.title, branch: meta.headRefName };
}

const THREADS_QUERY = `
  query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id isResolved isOutdated path line
            comments(first: 20) { nodes { author { login } body url } }
          }
        }
      }
    }
  }`;

function fetchThreads(owner, repo, pr) {
  const nodes = [];
  let cursor = null;
  for (let page = 0; page < 10; page++) {
    const argv = ['api', 'graphql', '-f', `query=${THREADS_QUERY}`,
      '-F', `owner=${owner}`, '-F', `repo=${repo}`, '-F', `pr=${pr}`];
    if (cursor) argv.push('-F', `cursor=${cursor}`);
    const conn = JSON.parse(gh(argv))?.data?.repository?.pullRequest?.reviewThreads;
    if (!conn) throw new Error('no reviewThreads in the gh response');
    nodes.push(...conn.nodes);
    if (!conn.pageInfo.hasNextPage) return nodes;
    cursor = conn.pageInfo.endCursor;
  }
  throw new Error('more than 10 pages of review threads — extend the page cap');
}

// ---------- CodeRabbit body parsing ----------
// Format reference (v1, marker `coderabbit-ai-generated:v1` first line):
//   severity paragraph  **<picture>…</picture> Minor** · **Category** · **Effort**
//   claim               bold title + body paragraphs, up to the first collapsed
//                       <details> block / ai-agent-prompt marker / ✅ status line
//   <details> blocks    named by <summary>: "Prompt for AI Agents" (a plain
//                       fence), "Committable suggestion" (a ```suggestion fence)
//   trailing            HTML-comment sentinels; after resolution a visible
//                       `✅ Addressed in commits …` line
// Old format (no marker): emoji line `_⚠️ Potential issue_` → major,
// `_🛠️ Refactor suggestion_` / `_🧹 Nitpick_` → minor, blocks named by top-level
// bold headers. Anything else → FORMAT DRIFT error.

function stripTags(s) { return s.replace(/<[^>]+>/g, ''); }

function oneLine(s) { return stripTags(s).replace(/\*\*/g, '').replace(/\s+/g, ' ').trim(); }

function visibleParagraphs(body) {
  return body
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<picture>[\s\S]*?<\/picture>/g, '')
    .split(/\n{2,}/)
    .map(p => p.replace(/<img [^>]*>/g, '').trim())
    .filter(Boolean);
}

function severityFromParagraph(p) {
  const parts = oneLine(p).split('·').map(s => s.trim());
  if (parts.length < 2) return null;
  const severity = parts[0].toLowerCase();
  if (!KNOWN_SEVERITIES.has(severity)) return null;
  return { severity, category: parts[1] || '', effort: parts.slice(2).join(' · ') };
}

// The claim ends at the first collapsed block, the prompt marker, or a visible
// ✅/❌ status line — everything after is metadata, not the finding.
function claimCut(body) {
  const cuts = [];
  const dm = /<details[\s>]/.exec(body);
  if (dm) cuts.push(dm.index);
  const pm = body.indexOf('<!-- ai-agent-prompt');
  if (pm !== -1) cuts.push(pm);
  const sm = /(^|\n)\s*[❌✅]/.exec(body);
  if (sm) cuts.push(sm.index + sm[1].length);
  return cuts.length ? Math.min(...cuts) : body.length;
}

function detailBlocks(body) {
  const blocks = [];
  const re = /<details>([\s\S]*?)<\/details>/g;
  let m;
  while ((m = re.exec(body))) {
    const sm = m[1].match(/<summary>([\s\S]*?)<\/summary>/);
    blocks.push({
      summary: sm ? oneLine(sm[1]) : '',
      content: sm ? m[1].slice(sm.index + sm[0].length).trim() : m[1].trim(),
    });
  }
  return blocks;
}

function findBlock(blocks, hint) {
  const h = hint.toLowerCase();
  return blocks.find(b => b.summary.toLowerCase().includes(h)) || null;
}

function fenceContent(content, lang = null) {
  const re = lang
    ? new RegExp('```' + lang + '[ \\t]*\\n([\\s\\S]*?)```', 'i')
    : /```[a-z]*[ \t]*\n([\s\S]*?)```/i;
  const m = content.match(re) || content.match(/```[a-z]*[ \t]*\n([\s\S]*?)```/i);
  return (m ? m[1] : stripTags(content)).trim();
}

function parseV1(body) {
  const paras = visibleParagraphs(body.slice(0, claimCut(body)));
  const headerIdx = paras.findIndex(p => severityFromParagraph(p));
  if (headerIdx === -1) throw new Error('v1 body has no `severity · category · effort` header paragraph');
  const header = severityFromParagraph(paras[headerIdx]);
  const blocks = detailBlocks(body);
  const prompt = findBlock(blocks, 'prompt for ai agents');
  const promptForAi = prompt ? fenceContent(prompt.content) : '';
  let claim = paras.slice(headerIdx + 1).join('\n\n').trim();
  if (!claim) {
    // Anatomy variant: no visible claim at all (severity header straight into
    // the collapsed blocks) — the finding lives only in the prompt block, after
    // its boilerplate, as `Review comment at …`.
    const review = /^Review comment at[\s\S]*/m.exec(promptForAi);
    if (!review) throw new Error('v1 body has no claim paragraphs and no `Review comment at` section in the prompt block');
    claim = review[0].trim();
  }
  const committable = findBlock(blocks, 'committable suggestion');
  return {
    ...header,
    claim,
    prompt_for_ai: promptForAi,
    committable_suggestion: committable ? fenceContent(committable.content, 'suggestion') : '',
  };
}

const OLD_SEVERITY = [[/⚠️/, 'major'], [/🛠|🧹/, 'minor']];
const OLD_BLOCK_HEADERS = ['Prompt for AI Agents', 'Committable suggestion', 'Suggested fix', 'Additional context'];

function parseOld(body) {
  let cut = body.length;
  for (const name of OLD_BLOCK_HEADERS) {
    const i = body.indexOf(`**${name}**`);
    if (i !== -1 && i < cut) cut = i;
  }
  const dm = /<details[\s>]/.exec(body);
  if (dm && dm.index < cut) cut = dm.index;
  const paras = visibleParagraphs(body.slice(0, cut));
  const emoji = OLD_SEVERITY.find(([re]) => re.test(paras[0] || ''));
  if (!emoji) throw new Error('neither v1 nor a known old-format anatomy (first line is no emoji severity line)');
  const claim = paras.slice(1).join('\n\n').trim();
  if (!claim) throw new Error('old-format body has no claim paragraphs after the emoji severity line');
  const prompt = /(?:^|\n)\*\*Prompt for AI Agents\*\*[\s\S]*?```[ \t]*\n([\s\S]*?)```/.exec(body);
  const committable = /(?:^|\n)\*\*Committable suggestion\*\*[\s\S]*?```suggestion[ \t]*\n([\s\S]*?)```/.exec(body);
  return {
    severity: emoji[1], category: '', effort: '',
    claim,
    prompt_for_ai: prompt ? prompt[1].trim() : '',
    committable_suggestion: committable ? committable[1].trim() : '',
  };
}

function parseCoderabbitBody(body) {
  const marker = /coderabbit-ai-generated:v\d+/.exec(body);
  if (marker && marker[0] !== V1_MARKER) throw new Error(`format marker ${marker[0]} — this parser implements ${V1_MARKER}`);
  return body.includes(V1_MARKER) ? parseV1(body) : parseOld(body);
}

// ---------- tools ----------

function safeThreadId(id) {
  if (typeof id !== 'string' || !/^[A-Za-z0-9_-]{5,100}$/.test(id)) {
    throw new Error(`not a review thread id: ${clip(id, 60)}`);
  }
  return id;
}

function listUnresolvedThreads(args) {
  const { repo = null, pr = null, directory = null, author = '^coderabbit' } = args || {};
  let authorRe;
  try { authorRe = new RegExp(author, 'i'); } catch { throw new Error(`bad author regex: ${author}`); }
  const meta = resolvePr({ repo, pr, directory });
  const threads = [];
  const failures = [];
  const candidates = fetchThreads(meta.owner, meta.repo, meta.pr).filter(t => !t.isResolved);
  for (const t of candidates) {
    const c0 = t.comments?.nodes?.[0];
    if (!c0 || !authorRe.test(c0.author?.login || '')) continue;
    if (!/^coderabbit/i.test(c0.author?.login || '')) {
      // A widened author filter: a foreign thread passes through unparsed.
      threads.push({
        id: t.id, path: t.path, line: t.line, is_outdated: !!t.isOutdated,
        severity: null, category: null, effort: null, claim: clip(c0.body, 1500),
        prompt_for_ai: '', committable_suggestion: '', url: c0.url,
      });
      continue;
    }
    try {
      threads.push({
        id: t.id, path: t.path, line: t.line, is_outdated: !!t.isOutdated,
        ...parseCoderabbitBody(c0.body), url: c0.url,
      });
    } catch (e) {
      failures.push({ id: t.id, path: t.path, line: t.line, reason: e.message, body: c0.body });
    }
  }
  if (failures.length) throw new Error(driftReport(meta, candidates, failures));
  const digest = {
    repo: `${meta.owner}/${meta.repo}`, pr: meta.pr, pr_title: meta.title, branch: meta.branch,
    threads,
    ...(threads.length ? {} : { note: 'no unresolved threads match — tell the user and stop' }),
  };
  return JSON.stringify(digest, null, 1);
}

function driftReport(meta, candidates, failures) {
  const lines = [
    'CODERABBIT FORMAT DRIFT — the /coderabbit workflow must stop here and wait for an mcp-coderabbit fix.',
    'Do not walk, do not resolve threads, do not improvise a local jq/python parser: a hand-made digest hides format drift.',
    '',
    `${failures.length} of ${candidates.length} unresolved coderabbit threads failed to parse (${meta.owner}/${meta.repo}#${meta.pr}):`,
    '',
  ];
  for (const f of failures) {
    lines.push(`- ${f.id} ${f.path}:${f.line} — ${f.reason}`);
    for (const l of clip(f.body, 500).split('\n')) lines.push(`  | ${l}`);
    lines.push('');
  }
  lines.push(
    'Fix loop (only on the user\'s go):',
    '1. mcp__coderabbit__get_thread_bodies with the failed thread ids — full raw bodies;',
    '2. extend ~/dotfiles/bin/mcp-coderabbit-fixture.json, patch the parser in ~/dotfiles/bin/mcp-coderabbit.mjs;',
    '3. node ~/dotfiles/bin/mcp-coderabbit.mjs --selftest — must end with "selftest OK";',
    '4. reload the server (new ZCode session or app restart), re-run list_unresolved_threads, and only then resume the walk.',
  );
  return lines.join('\n');
}

function resolveThreads(args) {
  const ids = (args?.thread_ids || []).map(safeThreadId);
  if (!ids.length || ids.length > 100) throw new Error('thread_ids: a non-empty array, cap 100 per call');
  const mutation = `mutation {\n${ids.map((id, i) =>
    `  t${i}: resolveReviewThread(input: { threadId: "${id}" }) { thread { isResolved } }`).join('\n')}\n}`;
  const resp = JSON.parse(gh(['api', 'graphql', '-f', `query=${mutation}`]));
  const errorsByAlias = new Map();
  for (const e of resp.errors || []) {
    const alias = Array.isArray(e.path) && e.path[0];
    if (typeof alias === 'string') errorsByAlias.set(alias, e.message);
  }
  const lines = [];
  let resolved = 0;
  ids.forEach((id, i) => {
    const alias = `t${i}`;
    const thread = resp.data?.[alias]?.thread;
    if (thread?.isResolved) { resolved++; lines.push(`${id}: resolved`); }
    else lines.push(`${id}: FAILED — ${errorsByAlias.get(alias) || (thread ? 'isResolved returned false' : 'no result')}`);
  });
  lines.push('', `${resolved} resolved, ${ids.length - resolved} failed`);
  return lines.join('\n');
}

function getThreadBodies(args) {
  const ids = (args?.thread_ids || []).map(safeThreadId);
  if (!ids.length || ids.length > 50) throw new Error('thread_ids: a non-empty array, cap 50 per call');
  const query = `query {\n${ids.map((id, i) =>
    `  t${i}: node(id: "${id}") { ... on PullRequestReviewThread { id isResolved isOutdated path line comments(first: 20) { nodes { author { login } body url } } } }`).join('\n')}\n}`;
  const resp = JSON.parse(gh(['api', 'graphql', '-f', `query=${query}`]));
  const out = [];
  ids.forEach((id, i) => {
    const t = resp.data?.[`t${i}`];
    if (!t) { out.push(`=== ${id}: not found`, ''); return; }
    const c0 = t.comments?.nodes?.[0];
    out.push(`=== ${id} ${t.path}:${t.line} resolved=${t.isResolved} outdated=${t.isOutdated} comments=${t.comments?.nodes?.length ?? 0}`);
    out.push(c0 ? c0.body : '(no comments)');
    out.push('');
  });
  return clip(out.join('\n'), 100000);
}

// ---------- selftest ----------
// Regression test for the parser, run in the format-drift fix loop. Fixture
// threads carry their expectation in `path`: expect/v1-*.js and expect/old-*.js
// must parse with the asserted fields; expect/drift-*.js must FAIL.

function selftest(fixturePath) {
  const path = fixturePath || join(dirname(fileURLToPath(import.meta.url)), 'mcp-coderabbit-fixture.json');
  const raw = JSON.parse(readFileSync(path, 'utf8'));
  const nodes = raw?.data?.repository?.pullRequest?.reviewThreads?.nodes || raw?.nodes || raw;
  if (!Array.isArray(nodes)) throw new Error(`fixture ${path}: no threads array inside`);

  const results = [];
  const failedParse = [];
  const problems = [];
  for (const t of nodes) {
    const c0 = t.comments?.nodes?.[0];
    if (!c0) { problems.push(`${t.path}: fixture thread has no first comment`); continue; }
    try {
      results.push({ path: t.path, line: t.line, is_outdated: !!t.isOutdated, ...parseCoderabbitBody(c0.body) });
    } catch (e) {
      failedParse.push({ path: t.path, reason: e.message });
    }
  }
  const byPath = Object.fromEntries(results.map(r => [r.path, r]));
  const assert = (cond, msg) => { if (!cond) problems.push(msg); };

  const v1 = byPath['expect/v1-minor.js'];
  if (v1) {
    assert(v1.severity === 'minor', `expect/v1-minor.js: severity ${v1.severity} !== minor`);
    assert(v1.category === 'Functional Correctness', `expect/v1-minor.js: category ${JSON.stringify(v1.category)}`);
    assert(v1.effort === 'Quick win', `expect/v1-minor.js: effort ${JSON.stringify(v1.effort)}`);
    assert(/^\*\*Exclude fields disabled/.test(v1.claim || ''), 'expect/v1-minor.js: claim lost');
    assert(!/Addressed in commits/.test(v1.claim || ''), 'expect/v1-minor.js: resolution status leaked into the claim');
    assert(/untrusted review data/.test(v1.prompt_for_ai || ''), 'expect/v1-minor.js: prompt_for_ai lost');
    assert(!v1.committable_suggestion, 'expect/v1-minor.js: phantom committable_suggestion');
  } else problems.push('expect/v1-minor.js did not parse');

  const outdated = byPath['expect/v1-outdated.js'];
  if (outdated) {
    assert(outdated.severity === 'minor' && outdated.claim, 'expect/v1-outdated.js: severity/claim lost');
    assert(outdated.is_outdated === true, 'expect/v1-outdated.js: is_outdated lost');
  } else problems.push('expect/v1-outdated.js did not parse');

  const committable = byPath['expect/v1-committable.js'];
  if (committable) {
    assert(committable.severity === 'major', `expect/v1-committable.js: severity ${committable.severity}`);
    assert(committable.committable_suggestion === '-      <%= raw body %>\n+      <%= body %>',
      `expect/v1-committable.js: committable fence mismatch:\n${committable.committable_suggestion}`);
    assert(/Escaping instruction/.test(committable.prompt_for_ai || ''), 'expect/v1-committable.js: prompt_for_ai lost');
  } else problems.push('expect/v1-committable.js did not parse');

  const oldMajor = byPath['expect/old-major.js'];
  if (oldMajor) {
    assert(oldMajor.severity === 'major', `expect/old-major.js: severity ${oldMajor.severity}`);
    assert(/orphaned records/.test(oldMajor.claim || ''), 'expect/old-major.js: claim lost');
    assert(/company&\.name/.test(oldMajor.committable_suggestion || ''), 'expect/old-major.js: committable lost');
  } else problems.push('expect/old-major.js did not parse');

  const nitpick = byPath['expect/old-nitpick.js'];
  if (nitpick) {
    assert(nitpick.severity === 'minor', `expect/old-nitpick.js: severity ${nitpick.severity} !== minor`);
    assert(/map\(&:name\)/.test(nitpick.claim || ''), 'expect/old-nitpick.js: claim lost');
  } else problems.push('expect/old-nitpick.js did not parse');

  const noClaim = byPath['expect/v1-no-claim.js'];
  if (noClaim) {
    assert(noClaim.severity === 'major', `expect/v1-no-claim.js: severity ${noClaim.severity} !== major`);
    assert(/^Review comment at/.test(noClaim.claim || ''), 'expect/v1-no-claim.js: claim is not the prompt-block review section');
    assert(!/Treat finding text/.test(noClaim.claim || ''), 'expect/v1-no-claim.js: prompt boilerplate leaked into the claim');
    assert(/untrusted review data/.test(noClaim.prompt_for_ai || ''), 'expect/v1-no-claim.js: prompt_for_ai lost');
  } else problems.push('expect/v1-no-claim.js did not parse');

  const expectedFails = nodes.filter(t => /expect\/drift-/.test(t.path)).map(t => t.path).sort();
  const actualFails = failedParse.map(f => f.path).sort();
  assert(JSON.stringify(expectedFails) === JSON.stringify(actualFails),
    `expected failures ${JSON.stringify(expectedFails)}, got ${JSON.stringify(actualFails)}`);

  console.log(JSON.stringify({ digest: results, parseFailures: failedParse, problems }, null, 1));
  if (problems.length) {
    console.error(`selftest FAILED: ${problems.length} problem(s)`);
    process.exit(1);
  }
  console.error('selftest OK');
}

// ---------- stdio JSON-RPC ----------

const TOOLS = [
  {
    name: 'list_unresolved_threads',
    description: 'Fetch a GitHub PR\'s unresolved CodeRabbit review threads and return a compact ' +
      'digest — per thread: severity/category/effort, claim, prompt-for-AI (verbatim), ' +
      'committable suggestion, path:line, isOutdated, url, thread id — plus PR number/title/branch. ' +
      'Raw bot bodies never enter the caller\'s context; merge duplicates/overlaps on the digest ' +
      '(per the coderabbit skill), never on raw bodies. ALL-OR-NOTHING: any coderabbit body the ' +
      'parser cannot read fails the whole call (FORMAT DRIFT error) — the triage walk must stop ' +
      'and wait for the server fix described in the error text; never work around it with a local ' +
      'parser. The PR comes from args (pr/repo) or `gh pr view` in directory (default: cwd). ' +
      '`author` widens the bot filter (regex on the first comment\'s login; non-coderabbit threads ' +
      'pass through unparsed).',
    inputSchema: {
      type: 'object',
      properties: {
        pr: { type: 'number', description: 'PR number; default: gh pr view in directory' },
        repo: { type: 'string', description: "'owner/name'; default: from the PR url" },
        directory: { type: 'string', description: 'working directory for gh (repo checkout or worktree); default: server cwd' },
        author: { type: 'string', description: "regex the first comment's author login must match; default '^coderabbit'" },
      },
    },
  },
  {
    name: 'resolve_threads',
    description: 'Resolve GitHub PR review threads by id — one aliased GraphQL mutation for the ' +
      'whole batch, per-id status back. The /coderabbit close rule: every reviewed thread resolves ' +
      '(fixed or no-fix alike); several thread ids of one merged issue go in a single call. ' +
      'Never comment on the PR — resolution is the only interaction.',
    inputSchema: {
      type: 'object',
      properties: {
        thread_ids: { type: 'array', items: { type: 'string' }, description: 'review thread node ids (PRRT_…), from the digest' },
      },
      required: ['thread_ids'],
    },
  },
  {
    name: 'get_thread_bodies',
    description: 'Full raw bodies of review threads by id. Not for walking — walking reads the ' +
      'list_unresolved_threads digest; bodies are kilobytes of HTML padding. Use in the ' +
      'format-drift fix loop: list_unresolved_threads failed, these bodies feed the fixture and ' +
      'the parser patch.',
    inputSchema: {
      type: 'object',
      properties: {
        thread_ids: { type: 'array', items: { type: 'string' } },
      },
      required: ['thread_ids'],
    },
  },
];

const HANDLERS = {
  list_unresolved_threads: listUnresolvedThreads,
  resolve_threads: resolveThreads,
  get_thread_bodies: getThreadBodies,
};

if (process.argv[2] === '--selftest') { selftest(process.argv[3]); process.exit(0); }

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
    console.error(`mcp-coderabbit: unparseable stdin line: ${error.message}`);
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
          serverInfo: { name: 'coderabbit', version: VERSION },
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
});

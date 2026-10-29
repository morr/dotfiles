---
name: zcode-sessions
description: Work with ZCode sessions by id or title — inspect what happened in a past session (metadata, user inputs, transcript with tool calls, search), list/find sessions, and rename a session. Triggers — «посмотри сессию …», «что случилось в сессии …», «почему сессия … не смогла …», «найди сессию …», «переименуй сессию», «назови эту сессию …», "rename this session". Use whenever a session id (`session_<hex>`) or the word «сессия» in a ZCode context comes up.
---

# zcode-sessions

Reads and renames ZCode desktop sessions through the `zcode-sessions` MCP server
(tools `mcp__zcode-sessions__*`), backed by the app's SQLite database
`~/.zcode/cli/db/db.sqlite`. All read tools are read-only connections; the only
write anywhere is `rename_session`. Printed timestamps are machine-local —
the same clock as the app UI and sqlite `localtime` (they used to be UTC and
sessions burned reasoning on converting between the two).

## Tools

- `list_sessions(query, directory, title_source, outcome, since, until, include_subagents, limit)` —
  sessions newest-first: id, title, title_source, timestamps, working directory,
  last outcome. Main sessions only by default (`include_subagents: true` adds
  subagent children — they outnumber the main ones). Find a session when only a
  title fragment or repo path is known.
- `search_sessions(query, directory, title_source, since, until, include_subagents, limit)` —
  find sessions by content when no id is known: titles and user inputs
  case-insensitively, then the transcripts themselves (`input_history` holds
  only recent inputs — a couple dozen sessions; parts cover weeks). Transcript
  matches are case-insensitive for Latin, case-sensitive for Cyrillic. Returns
  sessions with the matching lines.
- `get_session(session_id)` — metadata + every user input with timestamps and
  attachment counts + per-type part counts. The entry point: read this before
  the transcript. `input_history` is a pruned recency cache — old sessions get
  their inputs rebuilt from the transcript (wrapper injections filtered by
  prefix), and transcripts of such sessions label USER/context by the same
  prefixes instead of matching input_history.
- `get_transcript(session_id, types, maxChars, limit, offset)` — chronological
  transcript. `types` selects parts: `text` (USER / assistant / context labels;
  `context` = environment injections like AGENTS.md — skip them), `tool`
  (name + condensed input + output), `reasoning` (model thinking, off by
  default), `file`. Page with `offset`/`limit` for long sessions.
- `find_in_transcript(session_id, query, context, limit)` — substring search
  across texts, tool inputs and outputs with context windows. The fastest way
  to locate an error or a specific command.
- `query(sql)` — read-only SQL against the sessions database, a single
  SELECT/WITH only (tables are in the fallback section below). For aggregations
  and one-off filters no fixed tool covers.
- `search_log(day, days, session_id, query, level, since, until, limit)` — search
  the app's event logs (`~/.zcode/cli/log/zcode-YYYY-MM-DD.jsonl`, streamed —
  days run 25–120 MB) for «what happened inside the app» a transcript cannot
  answer: title generation, model network calls, turn phases. Time filters are
  local (HH:MM or ISO); lines come back with their raw JSON for grep-style reading.
- `rename_session(title, session_id?)` — sets the title and marks it `custom`
  so the app's generator leaves it alone. Without `session_id` renames the
  current session (newest rollout file; if several windows stream at once, the
  newest wins — the accepted ambiguity).
- `send_message(session_id, message)` — cross-session messaging: queues the text
  into ZCode's automation table (`~/.zcode/v2/tasks-index.sqlite`); the app's
  scheduler delivers it as a user input within ~20 s (one-shot row, housekeeping
  is automatic). A busy session queues the message until its turn ends; idle and
  error-stopped sessions are resumed for delivery. The tool pins the target's
  model — the task row's pin, or, when the row has none (interactive sessions),
  the model the session actually runs on (`model_usage`), so the resume keeps
  it on its model instead of the workspace default. Delivery proof is the
  message in the recipient's `input_history`; the ext-msg row's outcome in
  `automation_runs` finalizes when the recipient's turn ends, so `running`
  while the recipient is mid-turn is normal, not a failed delivery.
- `spawn_session(prompt, directory, model, mode?, thought_level?, title?)` —
  spawns a NEW background ZCode session (a full app session with its own
  context — visible in the session list, resumable, reachable via
  `send_message` — not a subagent). Same automation queue as `send_message`,
  but with no target session: the app's scheduler calls createTask (new session
  in `directory`, model pin `provider/model` required — a missing pin forces
  the workspace default plan — and permission `mode`, default `build`) and
  delivers the prompt. Waits up to 60 s and returns the new session id. Use for
  background workers that must outlive the caller and report back; the
  ZCode-side replacement for `claude --bg`. The mode is honored end-to-end:
  `mode: 'guarded'` lands in the spawned session's permission (verify via the
  session store or the runtime log — the `tasks.mode` column of the task index
  can still show the default and is a red herring). Two 2026-10-29 live-test
  facts: spawning while the spawner is mid-turn routinely 429s the child's
  first turns (`user concurrency limit exceeded`, ZAI providerCode 3008) — the
  scheduler self-heals with «continue» injections, do not retry; and the spawn
  run's outcome in `automation_runs` is unreliable (it can read `failed` with
  an empty error for a session that completed) — judge the child by
  `session.last_outcome` and its report, never by that row.
- `current_session(directory?)` — id, title, permission mode and model of the
  CALLING session: the newest OPEN
  main session in `directory` (default: process cwd; subagents excluded — only
  open sessions stream rollout files). Call it once, early, before spawning
  parallel sessions, and pass the id to them so they can `send_message` their
  reports back; pass the mode and model to `spawn_session` to make the child
  inherit this session. Ambiguity (several open main sessions in one directory)
  is reported, not hidden.

## Typical flows

Diagnose «what happened in session X»:
1. `get_session` — when it ran, where, what the user asked (inputs);
2. `get_transcript` with `types: ["text"]` for the story, or jump straight to
   `find_in_transcript` when the user names a symptom (error text, command);
3. `get_transcript` with `types: ["tool"]` around the timestamp that failed to
   see the exact call and its output.

Rename (absorbs the old rename-session skill):
- Explicit title from the user → write as given, report the `was:`/`now:` lines.
- No title given → propose one that names the session's subject in the user's
  language (short, no truncation) and confirm before calling.
- The app's session list may not repaint instantly; the value is written
  regardless.

Send a message to another session:
- Check the target with `get_session` first (exists, right workspace), then
  `send_message`. Deliver the sender's intent verbatim — don't paraphrase; the
  message arrives as a user input on the other side. Remember delivery is
  asynchronous (~20 s, later if the target is mid-turn) — tell the user it's
  queued, not applied.

Spawn a background worker session (drill-style pipelines):
1. `current_session` once, at the START of the driving session — before any
   parallel session exists — to learn the driver's own id;
2. `spawn_session(prompt, directory: <worktree>, model: '…/…', mode: <driver's mode>, title: <branch>)` —
   the worker runs in its own context; the prompt carries the driver's session
   id so the worker can report back;
3. the worker finishes with `send_message(driver_id, <report>)` — the report
   lands in the driver as a user input, no polling needed (keep a file
   contract too: messages arrive only while the driver's app runs).

## Fallback when the MCP server is down or not loaded

The server is `~/dotfiles/bin/mcp-zcode-sessions.mjs` (test: `echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node ~/dotfiles/bin/mcp-zcode-sessions.mjs`). Without it, read the database directly (read-only!):

- `sqlite3 -readonly ~/.zcode/cli/db/db.sqlite` —
  `session`: id, title, `title_source`, `directory`, `workspace_id`
  (there is **no `workspace` column**), `time_created`/`time_updated`,
  `last_outcome`, `time_deleted`; `parent_id` is set on subagent child
  sessions (`sess_subagent_agent_*`), and `task_type` tells `interactive`
  from selection-side chats and the like;
  `input_history`: user inputs (kind `prompt` / `steered_input`) + attachments;
  `part`: the **full transcript of closed sessions** keyed by `session_id` —
  JSON per row, `type` = `text` | `reasoning` | `tool` (tool rows hold
  `state.input` / `state.output`) — order by `time_created`;
  `message`: envelopes only (context snapshots, no conversation text);
  `session_entry`: runtime facts only.
- `~/.zcode/cli/rollout/model-io-<id>.jsonl` — exact model requests; **only
  exists while the session is open**.
- `~/.zcode/cli/log/zcode-YYYY-MM-DD.jsonl` — event log with `sessionId`
  (through the MCP: `search_log`). Tool calls are logged **without
  inputs/outputs** (metadata only), so the transcript source is `part`, not
  the log.
- `~/.zcode/cli/artifacts/<id>/` — tool media results (base64 data-URLs);
  `~/.zcode/cli/agents/<id>/<agent>/` — subagent metadata and output;
  `~/.zcode/cli/image-cache/<id>/` — images the user pasted.
- Built-in `ReadSessionContext` does not accept `session_<hex>` ids (its
  validator wants `current` or `sess_*`) — don't try it for desktop sessions.

To rename without the MCP, write exactly what `rename_session` writes:
`title`, `title_source='custom'`, `time_title_updated` (epoch ms) — nothing else.

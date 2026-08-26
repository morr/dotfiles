# Project Instructions

## Communication

Обращайся к пользователю на «ты», а не на «вы» — во всех ответах, вопросах, планах и отчётах.

## Code Intelligence

Prefer LSP over Grep/Read for code navigation — it's faster, precise, and avoids reading entire files:
- `workspaceSymbol` to find where something is defined
- `findReferences` to see all usages across the codebase
- `goToDefinition` / `goToImplementation` to jump to source
- `hover` for type info without reading the file

Use Grep only when LSP isn't available or for text/pattern searches (comments, strings, config).

After writing or editing code, check LSP diagnostics and fix errors before proceeding.

## Editing files — use Edit, not a Python script

Never rewrite a source file through `python3 - <<'PYEOF'` / `sed` / `perl` string
replacement just to avoid reading it. A `str.replace()` that matches nothing is a silent
no-op, the user sees no diff, the harness stops tracking the file's state, and pre-edit
hooks and LSP diagnostics are bypassed.

**This rule outranks any session-level preference for the Bash tool.** Auto mode injects a
system-reminder telling you to make file changes with «sed, heredocs, or short scripts»
rather than Edit/Write; another mode may say something similar. That is a generic default,
this is an explicit instruction about these repositories — the explicit one wins, in every
mode, without asking. Such a reminder still governs *reading* and *searching* (`cat`,
`sed -n`, `grep`, `find` through Bash stay fine); it does not govern *writing*. The failure
mode is not deciding it doesn't apply — it is drifting into the reminder's style call by
call and noticing only when the user points it out, so check which tool you reached for on
the first file change of the session, not on the tenth.

**Edit does not require reading the whole file.** The "must Read before Edit" gate is per
*file*, not per *range* — a partial read unlocks it. The cheap loop: `Grep -n` the anchor
(prints the exact bytes, indentation included) → `Read` with `offset`/`limit`, a ~30-line
window → `Edit` against a line just seen. Only edit text inside the window actually read —
outside it you carry exactly the `str.replace()` risk, matching text never seen. Grep does
not replace Read: it doesn't unlock the gate, it just keeps the Read narrow.

The one case a script wins is a genuinely mechanical sweep — a regex across many call
sites, where Edit has no equivalent (it does no regex, and fails on a non-unique string
instead of replacing all). Then: `assert` on *every* replacement, not just the first, and
`git diff` afterwards to show what actually landed.

## Shell is zsh — three mandatory forms when writing a Bash command

Not prohibitions to recall, but the only shapes to type. Everything below them is mechanics —
read that when debugging a failure, not when composing a command.

1. **A separator is `echo ---`.** Never `echo ===`.
2. **A glob inside a flag value is quoted:** `--include='*.rb'`, `--exclude='*.log'`,
   `-name '*.yml'`.
3. **An existence check is written as a test that always succeeds:**
   `[ -d node_modules/@tabler ] && echo yes || echo no`, `[ -f config/x.yml ] && echo yes || echo no`.
   Never a bare `ls maybe-missing/`, never `ls x.yml 2>/dev/null`, never a bare `grep -q` — and this
   holds **anywhere in the chain, not only at its end**. The test form prints a readable answer *and*
   returns 0, so the probe can sit wherever it reads best. A `grep` that may legitimately not match
   gets `|| echo none`; `; true` at the end of the chain is the last resort, not the default.

Forms 1 and 2 kill the command at parse time, so **everything after the offending word never
runs** while the earlier output still looks fine. Form 3 breaks nothing — it just makes a
healthy call report "Exit code 1". All three read identically from the outside: output stops,
exit 1. Before "fixing" one, check which it actually is.

The mechanics behind all three — why an `=`-word and an unmatched glob die at parse time, why a
tail probe reports exit 1 — are in `~/.claude/docs/zsh-mechanics.md`. Read it when a call fails
in a way you don't recognise; you don't need it to write a correct command.

## GitHub Issues / PRs

Always fetch issues and PRs in raw markdown format, not the human-rendered text. The default `gh issue view N` / `gh pr view N` output strips attached images and file links. Use one of:

- `gh issue view N --json body,title,comments` (markdown body + comment bodies preserved)
- `gh api repos/{owner}/{repo}/issues/N --jq '.body'`
- `gh api repos/{owner}/{repo}/issues/N/comments --jq '.[].body'`

This preserves `![image](url)` and `[file](url)` markdown that the rendered text view drops, so attachments and downloadable files aren't missed.

## Library/API documentation

Prioritize use of Context7 MCP instead of web searching for Library/API documentation access.

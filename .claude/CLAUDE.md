# Project Instructions

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

**Edit does not require reading the whole file.** The "must Read before Edit" gate is
per *file*, not per *range* — a partial read unlocks it (verified: reading 6 lines of a
3000-line file was enough). The cheap loop:

1. `Grep -n "anchor" path/to/file.rs -C 5` — locates the spot and prints the exact text,
   byte for byte, including indentation.
2. `Read` with `offset` / `limit` — a ~30-line window around it.
3. `Edit` against a line just seen.

Two rules for it:

- Only edit text inside the window actually read. Editing outside it is technically
  allowed but carries exactly the `str.replace()` risk — matching text never seen.
- Grep does not replace Read: it does not unlock the gate, it just lets the Read be narrow.

The one case a script wins is a genuinely mechanical sweep — a regex across many call
sites, where Edit has no equivalent (it does no regex, and fails on a non-unique string
instead of replacing all). Then: `assert` on *every* replacement, not just the first, and
`git diff` afterwards to show what actually landed.

## GitHub Issues / PRs

Always fetch issues and PRs in raw markdown format, not the human-rendered text. The default `gh issue view N` / `gh pr view N` output strips attached images and file links. Use one of:

- `gh issue view N --json body,title,comments` (markdown body + comment bodies preserved)
- `gh api repos/{owner}/{repo}/issues/N --jq '.body'`
- `gh api repos/{owner}/{repo}/issues/N/comments --jq '.[].body'`

This preserves `![image](url)` and `[file](url)` markdown that the rendered text view drops, so attachments and downloadable files aren't missed.

## Library/API documentation

Prioritize use of Context7 MCP instead of web searching for Library/API documentation access.

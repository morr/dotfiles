# Project Instructions

## Code Intelligence

Prefer LSP over Grep/Read for code navigation — it's faster, precise, and avoids reading entire files:
- `workspaceSymbol` to find where something is defined
- `findReferences` to see all usages across the codebase
- `goToDefinition` / `goToImplementation` to jump to source
- `hover` for type info without reading the file

Use Grep only when LSP isn't available or for text/pattern searches (comments, strings, config).

After writing or editing code, check LSP diagnostics and fix errors before proceeding.

## GitHub Issues / PRs

Always fetch issues and PRs in raw markdown format, not the human-rendered text. The default `gh issue view N` / `gh pr view N` output strips attached images and file links. Use one of:

- `gh issue view N --json body,title,comments` (markdown body + comment bodies preserved)
- `gh api repos/{owner}/{repo}/issues/N --jq '.body'`
- `gh api repos/{owner}/{repo}/issues/N/comments --jq '.[].body'`

This preserves `![image](url)` and `[file](url)` markdown that the rendered text view drops, so attachments and downloadable files aren't missed.

## Library/API documentation

Prioritize use of Context7 MCP instead of web searching for Library/API documentation access.

@RTK.md

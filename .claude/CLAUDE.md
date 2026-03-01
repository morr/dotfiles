# Project Instructions

## Git Commits

- Only add `Co-Authored-By: Claude` to commits where Claude authored or co-authored the changes. Do not add it when committing changes made entirely by the user.
- Never chain `git add` and `git commit` with `&&` in a single Bash call. Always use separate Bash tool calls for `git add` and `git commit` so each matches its permission rule individually.

## Code Intelligence

Prefer LSP over Grep/Read for code navigation — it's faster, precise, and avoids reading entire files:
- `workspaceSymbol` to find where something is defined
- `findReferences` to see all usages across the codebase
- `goToDefinition` / `goToImplementation` to jump to source
- `hover` for type info without reading the file

Use Grep only when LSP isn't available or for text/pattern searches (comments, strings, config).

After writing or editing code, check LSP diagnostics and fix errors before proceeding.

## Library/API documentation

Prioritize use of Context7 MCP instead of web searching for Library/API documentation access.

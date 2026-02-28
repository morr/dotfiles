## Git Commits

- Only add `Co-Authored-By: Claude` to commits where Claude authored or co-authored the changes. Do not add it when committing changes made entirely by the user.
- Never chain `git add` and `git commit` with `&&` in a single Bash call. Always use separate Bash tool calls for `git add` and `git commit` so each matches its permission rule individually.

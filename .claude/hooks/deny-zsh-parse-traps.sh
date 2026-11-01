#!/bin/bash
# PreToolUse/Bash: deny an unquoted glob after -name/-iname.
#
# The Bash tool runs zsh; ~/.zshenv unsets EQUALS and NOMATCH in non-interactive
# zsh, so the old parse-time deaths (a bare =-word, an unmatched glob in a flag
# value) are gone — an unquoted --include=*.rb reaches grep intact, and a ===
# separator is just a literal. What survives is silent corruption on a
# separate-word glob: -name *.yml expands against the *current* directory, so
# when the cwd has any .yml file find gets those filenames instead of the
# pattern. Quoting costs nothing; deny is one retry with the right spelling.

cmd=$(jq -r '.tool_input.command // ""')

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])-i?name[[:space:]]+[^"'"'"'[:space:]]*[*?[]'; then
  deny 'Unquoted glob after -name/-iname: zsh expands it against the current directory before find sees it — when a file there matches, find gets filenames instead of the pattern. Quote it: -name '"'"'*.yml'"'"'.'
fi

exit 0

#!/bin/bash
# PreToolUse/Bash: deny the two zsh word-expansion traps that silently truncate a command.
#
# The Bash tool runs zsh. Two constructs die at expansion time and take the rest
# of the command line with them — the output just stops, and the call reports
# exit 1, which reads like the last command failed rather than like the line was
# cut in half:
#
#   echo ===            EQUALS expansion turns a leading `=` into a command path
#                       lookup: `(eval):1: == not found`, nothing after it runs.
#   --include=*.rb      an unmatched glob is an error in zsh, and the glob is
#                       expanded against the *current* directory, not against
#                       grep's search target: `no matches found: --include=*.rb`.
#
# Both are documented in ~/.claude/CLAUDE.md and both keep happening — 88 and 57
# occurrences respectively in two weeks of minisklad sessions. Deny is cheap:
# one retry with the right spelling instead of a half-executed command.

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

# `echo ===` as a statement (start of line, or after ; && || | & ( ). A quoted
# `echo "==="` or an `echo ===` sitting inside a quoted string is left alone.
if printf '%s' "$cmd" | grep -qE '(^|[;&|(])[[:space:]]*echo[[:space:]]+='; then
  deny 'zsh EQUALS expansion: a word starting with `=` is replaced by the path to the command of that name, so `echo ===` fails with `== not found` AND everything after it on the line never runs. Write the separator as `echo ---`, or quote it: `echo "==="`.'
fi

# Unquoted glob inside a flag value or after -name: zsh expands it against the
# current directory and errors out when nothing matches.
if printf '%s' "$cmd" | grep -qE '\-\-(include|exclude|glob|iglob)=[^"'"'"'[:space:]]*[*?[]'; then
  deny 'Unquoted glob in a flag value: zsh expands it against the current directory (not against the tool'"'"'s search target) and kills the command with `no matches found`. Quote it: --include='"'"'*.rb'"'"'.'
fi

if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])-i?name[[:space:]]+[^"'"'"'[:space:]]*[*?[]'; then
  deny 'Unquoted glob after -name/-iname: zsh expands it before find sees it. Quote it: -name '"'"'*.yml'"'"'.'
fi

exit 0

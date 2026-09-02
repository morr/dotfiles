#!/bin/bash
# PreToolUse/Bash: deny bare `sleep N` statements.
#
# Waiting is the harness's job, not the model's: a background command notifies
# on exit, Monitor streams events from a log. A standalone `sleep` is either a
# no-op (launched in background, then polled anyway) or a blocked foreground
# call. Sleeps inside an `until`/`while` condition loop are the sanctioned
# wait pattern and stay allowed.

cmd=$(jq -r '.tool_input.command // ""')

# Sanctioned: sleep as the body of a polling loop.
if printf '%s' "$cmd" | grep -qE '\b(until|while)\b'; then
  exit 0
fi

# Statement-level `sleep <number>`: start of command, or after ; && || | & (
if printf '%s' "$cmd" | grep -qE '(^|[;&|(])[[:space:]]*sleep[[:space:]]+[0-9]'; then
  cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Bare `sleep` is blocked. Do not poll. To wait for a background command, do nothing — the harness sends a task notification when it exits. To wait for a condition, use Bash with run_in_background and an `until <check>; do sleep 2; done` loop, or Monitor on a log with a grep filter."
  }
}
JSON
fi

exit 0

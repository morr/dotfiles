#!/usr/bin/env bash
# Auto-allow curl only when every request targets agileseason3.s3.eu-central-1.amazonaws.com.
# Anything else: exit silently and let normal permission handling take over.

ALLOWED_HOST="agileseason3.s3.eu-central-1.amazonaws.com"

command -v jq &>/dev/null || exit 0

CMD=$(jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

# Reject anything that could smuggle in a second command or redirect output.
case "$CMD" in
  *';'*|*'|'*|*'`'*|*'$('*|*'<'*|*'>'*|*'&&'*'rm '*) exit 0 ;;
esac

# Every segment must be a curl invocation (rtk-rewritten form allowed).
SEGMENTS=$(printf '%s' "$CMD" | tr '\n' ' ' | sed 's/&&/\n/g')
while IFS= read -r seg; do
  seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -z "$seg" ] && continue
  case "$seg" in
    curl\ *|rtk\ curl\ *) ;;
    *) exit 0 ;;
  esac
done <<< "$SEGMENTS"

# Every URL in the command must point at the allowed host.
URLS=$(printf '%s' "$CMD" | grep -oE '(https?|ftp|file)://[^"'"'"' ]+' || true)
[ -z "$URLS" ] && exit 0
while IFS= read -r url; do
  case "$url" in
    "https://$ALLOWED_HOST/"*) ;;
    *) exit 0 ;;
  esac
done <<< "$URLS"

jq -n --arg host "$ALLOWED_HOST" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": ("curl restricted to " + $host)
  }
}'

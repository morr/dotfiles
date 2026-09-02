#!/bin/bash
# UserPromptSubmit: keep opus as the default model for NEW sessions.
#
# The /model picker persists the choice unless you press `s` ("use this session
# only") instead of enter ("set as default"), and `/model fable` typed with an
# argument persists it unconditionally in an interactive session. Either way the
# choice lands in ~/.claude/settings.json as "model", and every session started
# afterwards boots on it.
#
# The running session keeps its model in memory (mainLoopModel), so rewriting the
# file does not switch the current session back — exactly what we want: switch to
# fable here, and the next session still starts on opus.
#
# Writes with `cat >` rather than `mv`, so the ~/.claude/settings.json symlink
# into ~/dotfiles stays a symlink. Prints nothing: UserPromptSubmit stdout is
# appended to the prompt as context.

set -u

settings="$HOME/.claude/settings.json"
[ -f "$settings" ] || exit 0

current=$(jq -r '.model // empty' "$settings" 2>/dev/null) || exit 0
[ "$current" = "opus" ] && exit 0

tmp=$(mktemp) || exit 0
if jq '.model = "opus"' "$settings" >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
  cat "$tmp" >"$settings"
fi
rm -f "$tmp"

exit 0

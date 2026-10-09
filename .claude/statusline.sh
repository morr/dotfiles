#!/bin/bash
input=$(cat)

# seconds-until-reset -> "2h15m", or "3d4h" for multi-day (weekly) windows
fmt_reset() {
  local d=$(($1 / 86400)) h=$(($1 % 86400 / 3600)) m=$(($1 % 3600 / 60))
  if [ "$d" -gt 0 ]; then echo "${d}d${h}h"; else echo "${h}h${m}m"; fi
}

read -r USED FIVE_HOUR FIVE_HOUR_RESET SEVEN_DAY SEVEN_DAY_RESET <<EOF
$(echo "$input" | jq -r '
  [ ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)),
    (.rate_limits.five_hour.used_percentage // -1 | floor),
    (.rate_limits.five_hour.resets_at // 0),
    (.rate_limits.seven_day.used_percentage // -1 | floor),
    (.rate_limits.seven_day.resets_at // 0)
  ] | @tsv')
EOF

# z.ai session (zclaude): the payload carries no Anthropic rate_limits, so
# pull the GLM Coding Plan quota from api.z.ai instead — same endpoint the
# official glm-plan-usage plugin uses. Cached in /tmp for 30s: the statusline
# redraws far more often than the quota moves. limits[0] is the 5-hour window
# (unit 3 / number 5), limits[1] the weekly one (unit 6 / number 1); both
# carry percentage plus nextResetTime in ms epoch.
if [[ "$ANTHROPIC_BASE_URL" == *z.ai* ]] && [ "$FIVE_HOUR" -lt 0 ]; then
  keyfile="${ZCLAUDE_KEY_FILE:-$HOME/dotfiles/.zai_api_key.secret}"
  cache="/tmp/zai_quota_$(id -u).json"
  if [ -s "$keyfile" ]; then
    mtime=$(stat -f %m "$cache" 2>/dev/null || echo 0)
    if [ $(( $(date +%s) - mtime )) -ge 30 ]; then
      if curl -sS --connect-timeout 3 -m 8 \
           -H "Authorization: $(cat "$keyfile")" \
           'https://api.z.ai/api/monitor/usage/quota/limit' > "$cache.new" 2>/dev/null \
         && jq -e '.code == 200' "$cache.new" > /dev/null; then
        mv "$cache.new" "$cache"
      fi
      rm -f "$cache.new"
    fi
    if [ -s "$cache" ]; then
      read -r FIVE_HOUR FIVE_HOUR_RESET SEVEN_DAY SEVEN_DAY_RESET <<EOF
$(jq -r '[(.data.limits[0].percentage // -1),
          ((.data.limits[0].nextResetTime // 0) / 1000 | floor),
          (.data.limits[1].percentage // -1),
          ((.data.limits[1].nextResetTime // 0) / 1000 | floor)] | @tsv' "$cache")
EOF
    fi
  fi
fi

OUTPUT="Tokens: $((USED / 1000))k"

if [ "$FIVE_HOUR" -ge 0 ]; then
  RESET_STR=""
  if [ "$FIVE_HOUR_RESET" -gt 0 ]; then
    DIFF=$((FIVE_HOUR_RESET - $(date +%s)))
    if [ "$DIFF" -gt 0 ]; then
      RESET_STR=" resets $(fmt_reset "$DIFF")"
    fi
  fi
  OUTPUT="$OUTPUT · 5h: ${FIVE_HOUR}%${RESET_STR}"
fi

if [ "$SEVEN_DAY" -ge 0 ]; then
  RESET_STR=""
  if [ "$SEVEN_DAY_RESET" -gt 0 ]; then
    DIFF=$((SEVEN_DAY_RESET - $(date +%s)))
    if [ "$DIFF" -gt 0 ]; then
      RESET_STR=" resets $(fmt_reset "$DIFF")"
    fi
  fi
  OUTPUT="$OUTPUT · Week: ${SEVEN_DAY}%${RESET_STR}"
fi

# Neovim statusline reads this file
echo "$OUTPUT" > "/tmp/claude_statusline_$(basename "$PWD").txt"

echo "$OUTPUT"

#!/bin/bash
input=$(cat)

read -r USED FIVE_HOUR FIVE_HOUR_RESET SEVEN_DAY <<EOF
$(echo "$input" | jq -r '
  [ ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)),
    (.rate_limits.five_hour.used_percentage // -1 | floor),
    (.rate_limits.five_hour.resets_at // 0),
    (.rate_limits.seven_day.used_percentage // -1 | floor)
  ] | @tsv')
EOF

OUTPUT="Tokens: $((USED / 1000))k"

if [ "$FIVE_HOUR" -ge 0 ]; then
  RESET_STR=""
  if [ "$FIVE_HOUR_RESET" -gt 0 ]; then
    DIFF=$((FIVE_HOUR_RESET - $(date +%s)))
    if [ "$DIFF" -gt 0 ]; then
      RESET_STR=" resets $((DIFF / 3600))h$(((DIFF % 3600) / 60))m"
    fi
  fi
  OUTPUT="$OUTPUT · 5h: ${FIVE_HOUR}%${RESET_STR}"
fi

if [ "$SEVEN_DAY" -ge 0 ]; then
  OUTPUT="$OUTPUT · Week: ${SEVEN_DAY}%"
fi

# Neovim statusline reads this file
echo "$OUTPUT" > "/tmp/claude_statusline_$(basename "$PWD").txt"

echo "$OUTPUT"

#!/bin/bash
input=$(cat)

# Context window info
PERCENT_USED=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
PERCENT_LEFT=$(echo "$input" | jq -r '.context_window.remaining_percentage // 100')
TOTAL=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
TOTAL_K=$((TOTAL / 1000))

# Session usage from Anthropic API (cached for 60 seconds)
CACHE_FILE="/tmp/claude_usage_cache.json"
CACHE_MAX_AGE=60
SESSION_INFO=""

fetch_usage() {
  TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')
  if [ -z "$TOKEN" ]; then
    return 1
  fi

  RESPONSE=$(~/dotfiles/bin/with-proxy curl -s --max-time 5 \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

  if echo "$RESPONSE" | jq -e '.five_hour' >/dev/null 2>&1; then
    echo "$RESPONSE" > "$CACHE_FILE"
    return 0
  fi
  return 1
}

# Check cache age
if [ -f "$CACHE_FILE" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  else
    CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  fi

  if [ "$CACHE_AGE" -gt "$CACHE_MAX_AGE" ]; then
    fetch_usage
  fi
else
  fetch_usage
fi

# Parse cached usage data
if [ -f "$CACHE_FILE" ]; then
  FIVE_HOUR_UTIL=$(jq -r '.five_hour.utilization // empty' "$CACHE_FILE")
  FIVE_HOUR_RESET=$(jq -r '.five_hour.resets_at // empty' "$CACHE_FILE")
  SEVEN_DAY_UTIL=$(jq -r '.seven_day.utilization // empty' "$CACHE_FILE")

  if [ -n "$FIVE_HOUR_UTIL" ]; then
    FIVE_HOUR_INT=$(printf '%.0f' "$FIVE_HOUR_UTIL")

    RESET_STR=""
    if [ -n "$FIVE_HOUR_RESET" ]; then
      RESET_EPOCH=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$FIVE_HOUR_RESET" | sed 's/\.[0-9]*+.*//; s/\.[0-9]*-.*//')" +%s 2>/dev/null)
      if [ -n "$RESET_EPOCH" ]; then
        NOW_EPOCH=$(date +%s)
        DIFF=$((RESET_EPOCH - NOW_EPOCH))
        if [ "$DIFF" -gt 0 ]; then
          HOURS=$((DIFF / 3600))
          MINS=$(( (DIFF % 3600) / 60 ))
          if [ "$HOURS" -gt 0 ]; then
            RESET_STR=" resets ${HOURS}h${MINS}m"
          else
            RESET_STR=" resets ${MINS}m"
          fi
        fi
      fi
    fi

    SEVEN_DAY_STR=""
    if [ -n "$SEVEN_DAY_UTIL" ]; then
      SEVEN_DAY_INT=$(printf '%.0f' "$SEVEN_DAY_UTIL")
      SEVEN_DAY_STR=" | Week: ${SEVEN_DAY_INT}%"
    fi

    SESSION_INFO=" | 5h: ${FIVE_HOUR_INT}%${RESET_STR}${SEVEN_DAY_STR}"
  fi
fi

OUTPUT="Ctx: ${PERCENT_USED}% of ${TOTAL_K}k${SESSION_INFO}"

# Write status to a file so Neovim statusline can read it
echo "$OUTPUT" > "/tmp/claude_statusline_$(basename "$PWD").txt"

# Inside Neovim, hide Claude's own status line (Neovim shows it instead)
if [ -n "$NVIM" ]; then
  echo ""
else
  echo "$OUTPUT"
fi

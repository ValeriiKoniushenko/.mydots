#!/bin/bash
DATA=$(codex-check --auth ~/.codex/auth.json --json 2>/dev/null)
if [ -z "$DATA" ]; then
  echo "Codex: ?"
  exit 0
fi
FIVE_H=$(echo "$DATA" | jq -r '.[0].windows.primary.percentUsed // empty')
WEEKLY=$(echo "$DATA" | jq -r '.[0].windows.secondary.percentUsed // empty')
RESET_AT=$(echo "$DATA" | jq -r '.[0].windows.primary.resetsAt // empty')

if [ -z "$FIVE_H" ]; then
  echo "Codex: ?"
else
  if [ -n "$RESET_AT" ]; then
    RESET_LOCAL=$(date -d "$RESET_AT" "+%H:%M" 2>/dev/null)
  fi
  if [ -n "$RESET_LOCAL" ]; then
    echo "Codex: ${FIVE_H}% (${WEEKLY}%) | ${RESET_LOCAL} ⟳"
  else
    echo "Codex: ${FIVE_H}% (${WEEKLY}%)"
  fi
fi

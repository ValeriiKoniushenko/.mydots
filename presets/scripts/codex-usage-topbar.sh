#!/bin/bash
DATA=$(codex-check --auth ~/.codex/auth.json --json 2>/dev/null)
if [ -z "$DATA" ]; then
  echo "Codex: ?"
  exit 0
fi

FIVE_H=$(echo "$DATA" | jq -r '.[0].windows.primary.percentUsed // empty')
WEEKLY=$(echo "$DATA" | jq -r '.[0].windows.secondary.percentUsed // empty')

if [ -z "$FIVE_H" ]; then
  echo "Codex: ?"
else
  echo "Codex: ${FIVE_H}% / wk ${WEEKLY}%"
fi


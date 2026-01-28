#!/bin/bash
# Async title generation - MUST be run in background with &
# Usage: gen-title.sh <session_id> <instruction>
# Generates a short title via Claude, saves to title.txt, and auto-renames tmux window.

set -euo pipefail

SESSION_ID="$1"
INSTRUCTION="$2"
SESSIONS_DIR=".auto-dev/sessions"
SESSION_FILE=".auto-dev/tmux-session"
TITLE_FILE="$SESSIONS_DIR/$SESSION_ID/title.txt"

# Generate title via Claude
RAW_TITLE=$(claude -p "You are a title generator. Output ONLY a short task title in 3-5 words. No quotes, no period, no explanation. Just the title. Instruction: $INSTRUCTION" 2>/dev/null || echo "")
TITLE=$(echo "$RAW_TITLE" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r' | sed '/^$/d' | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [[ -z "$TITLE" ]]; then
    exit 0
fi

# Save to title.txt
echo "$TITLE" > "$TITLE_FILE"

# Auto-rename tmux window
if [[ -f "$SESSION_FILE" ]]; then
    SESSION_NAME=$(cat "$SESSION_FILE")
    SHORT_ID="${SESSION_ID:0:20}"
    WIN_IDX=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_index}|#{window_name}' 2>/dev/null | \
        while IFS='|' read -r idx name; do
            if [[ "$name" == "$SHORT_ID"* ]]; then echo "$idx"; break; fi
        done)
    if [[ -n "$WIN_IDX" ]]; then
        WIN_NAME=$(echo "$TITLE" | head -c 20 | tr ' ' '-' | tr -d '\n')
        tmux rename-window -t "$SESSION_NAME:$WIN_IDX" "$WIN_NAME"
    fi
fi

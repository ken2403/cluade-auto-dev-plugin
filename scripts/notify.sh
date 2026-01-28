#!/bin/bash
# Auto Dev Notification - Send macOS notifications
# Usage: notify.sh <title> <message> [session_id]

set -euo pipefail

TITLE="${1:-Auto Dev}"
MESSAGE="${2:-Notification}"
SESSION_ID="${3:-}"

# macOS notification
if command -v osascript &> /dev/null; then
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"Ping\""
fi

# Also try terminal-notifier if available (more features)
if command -v terminal-notifier &> /dev/null; then
    ARGS=(-title "$TITLE" -message "$MESSAGE" -sound "Ping")

    # Add action to open terminal if session_id provided
    if [[ -n "$SESSION_ID" ]]; then
        ARGS+=(-subtitle "Session: $SESSION_ID")
    fi

    terminal-notifier "${ARGS[@]}" 2>/dev/null || true
fi

# Log the notification
echo "[$(date -Iseconds)] NOTIFY: $TITLE - $MESSAGE" >> .auto-dev/notifications.log 2>/dev/null || true

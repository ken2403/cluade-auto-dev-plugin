#!/bin/bash
# Auto Dev Escalate - Write escalation and notify human
# Usage: escalate.sh <session_id> <summary> <details_json>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_ID="$1"
SUMMARY="$2"
DETAILS_JSON="${3:-{}}"

SESSION_DIR=".auto-dev/sessions/$SESSION_ID"
ESCALATIONS_DIR="$SESSION_DIR/escalations"

# Create escalations directory if not exists
mkdir -p "$ESCALATIONS_DIR"

# Generate escalation ID (timestamp-based)
ESCALATION_ID=$(date +%s)
ESCALATION_FILE="$ESCALATIONS_DIR/${ESCALATION_ID}.json"

# Write escalation file
cat > "$ESCALATION_FILE" << EOF
{
  "id": "$ESCALATION_ID",
  "timestamp": "$(date -Iseconds)",
  "summary": "$SUMMARY",
  "details": $DETAILS_JSON,
  "status": "pending",
  "answer": null,
  "answered_at": null
}
EOF

echo "Escalation written to: $ESCALATION_FILE"

# Send notification
bash "$SCRIPT_DIR/notify.sh" \
    "⚠️ Auto Dev: 判断が必要" \
    "$SUMMARY" \
    "$SESSION_ID"

# Return escalation ID for tracking
echo "$ESCALATION_ID"

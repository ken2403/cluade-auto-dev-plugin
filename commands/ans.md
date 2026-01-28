---
allowed-tools: Read, Write, Bash, Glob
argument-hint: SESSION_ID ["answer"]
description: Answer an escalation from CEO
model: haiku
---

# /ad:ans - Answer Escalation

Answer an escalation from CEO.

## Usage

```bash
/ad:ans SESSION_ID "answer"
/ad:ans SESSION_ID                    # List all escalations
/ad:ans SESSION_ID ESCALATION_ID "answer"  # Answer specific escalation
```

## Behavior

### Submit Answer (`/ad:ans SESSION_ID "answer"`)

1. Search for pending escalations in the session
2. Write answer to the latest escalation
3. Create answer file for CEO to detect
4. Record in notification log

### List Escalations (`/ad:ans SESSION_ID`)

Display all escalations for the specified session.

## Implementation

```bash
#!/bin/bash

SESSION_ID="$1"
ANSWER_OR_ESC_ID="$2"
ANSWER="$3"

SESSION_DIR=".auto-dev/sessions/$SESSION_ID"
ESCALATIONS_DIR="$SESSION_DIR/escalations"

# Validate session exists
if [[ ! -d "$SESSION_DIR" ]]; then
    echo "Error: Session $SESSION_ID not found"
    exit 1
fi

# Case 1: List escalations (no answer provided)
if [[ -z "$ANSWER_OR_ESC_ID" ]]; then
    echo "Escalations for session: $SESSION_ID"
    echo "=================================="
    echo ""

    for f in "$ESCALATIONS_DIR"/*.json; do
        if [[ -f "$f" && ! "$f" =~ -answer\.json$ ]]; then
            ESC_ID=$(jq -r '.id' "$f")
            SUMMARY=$(jq -r '.summary' "$f")
            STATUS=$(jq -r '.status' "$f")
            TIMESTAMP=$(jq -r '.timestamp' "$f")

            if [[ "$STATUS" == "pending" ]]; then
                echo "⚠️  [$ESC_ID] PENDING"
            else
                echo "✓  [$ESC_ID] $STATUS"
            fi
            echo "    $SUMMARY"
            echo "    Time: $TIMESTAMP"
            echo ""
        fi
    done
    exit 0
fi

# Case 2: Answer with escalation ID specified
if [[ -n "$ANSWER" ]]; then
    ESCALATION_ID="$ANSWER_OR_ESC_ID"
    ANSWER_TEXT="$ANSWER"
else
    # Case 3: Answer to latest pending escalation
    ANSWER_TEXT="$ANSWER_OR_ESC_ID"

    # Find latest pending escalation
    ESCALATION_ID=""
    for f in "$ESCALATIONS_DIR"/*.json; do
        if [[ -f "$f" && ! "$f" =~ -answer\.json$ ]]; then
            STATUS=$(jq -r '.status' "$f")
            if [[ "$STATUS" == "pending" ]]; then
                ESCALATION_ID=$(jq -r '.id' "$f")
            fi
        fi
    done

    if [[ -z "$ESCALATION_ID" ]]; then
        echo "Error: No pending escalations found"
        exit 1
    fi
fi

ESCALATION_FILE="$ESCALATIONS_DIR/${ESCALATION_ID}.json"
ANSWER_FILE="$ESCALATIONS_DIR/${ESCALATION_ID}-answer.json"

if [[ ! -f "$ESCALATION_FILE" ]]; then
    echo "Error: Escalation $ESCALATION_ID not found"
    exit 1
fi

# Write answer file (separate file for CEO to detect)
cat > "$ANSWER_FILE" << EOF
{
  "escalation_id": "$ESCALATION_ID",
  "answer": "$ANSWER_TEXT",
  "answered_at": "$(date -Iseconds)",
  "answered_by": "human"
}
EOF

# Update original escalation file
TMP_FILE=$(mktemp)
jq --arg answer "$ANSWER_TEXT" --arg time "$(date -Iseconds)" \
    '.status = "answered" | .answer = $answer | .answered_at = $time' \
    "$ESCALATION_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$ESCALATION_FILE"

echo "✓ Answer submitted for escalation $ESCALATION_ID"
echo ""
echo "Escalation: $(jq -r '.summary' "$ESCALATION_FILE")"
echo "Answer: $ANSWER_TEXT"
echo ""
echo "CEO will detect this answer and continue work."
```

## Answer File Format

Answers are written to two locations:

### 1. Answer File (for CEO detection)
```
.auto-dev/sessions/{session_id}/escalations/{escalation_id}-answer.json
```

```json
{
  "escalation_id": "1706234567",
  "answer": "TOTP only is fine. SMS can wait.",
  "answered_at": "2024-01-26T12:00:00+09:00",
  "answered_by": "human"
}
```

### 2. Original Escalation (updated)
```
.auto-dev/sessions/{session_id}/escalations/{escalation_id}.json
```

```json
{
  "id": "1706234567",
  "timestamp": "2024-01-26T11:55:00+09:00",
  "summary": "Decision needed on MFA implementation",
  "details": { ... },
  "status": "answered",      // pending → answered
  "answer": "TOTP only is fine",  // added
  "answered_at": "2024-01-26T12:00:00+09:00"  // added
}
```

## CEO Detection

CEO monitors for `-answer.json` files using `blackboard-watcher`:

```
Using blackboard-watcher to monitor:
  Directory: .auto-dev/sessions/{session_id}/escalations/
  Pattern: *-answer.json
  Action: When answer file appears, read it and continue work
```

## Examples

```bash
# List escalations
> /ad:ans abc123

Escalations for session: abc123
==================================

⚠️  [1706234567] PENDING
    Decision needed on MFA implementation
    Time: 2024-01-26T11:55:00+09:00

# Submit answer
> /ad:ans abc123 "TOTP only is fine. SMS can wait."

✓ Answer submitted for escalation 1706234567

Escalation: Decision needed on MFA implementation
Answer: TOTP only is fine. SMS can wait.

CEO will detect this answer and continue work.
```

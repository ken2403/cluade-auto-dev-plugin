# /ad:ans - Answer Escalation

エスカレーションに回答する。

## Usage

```bash
/ad:ans SESSION_ID "回答内容"
/ad:ans SESSION_ID                    # エスカレーション一覧を表示
/ad:ans SESSION_ID ESCALATION_ID "回答"  # 特定のエスカレーションに回答
```

## Behavior

### 回答を送信 (`/ad:ans SESSION_ID "回答"`)

1. セッションの pending エスカレーションを検索
2. 最新のエスカレーションに回答を書き込み
3. CEOが検知できるよう answer ファイルを作成
4. 通知ログに記録

### エスカレーション一覧 (`/ad:ans SESSION_ID`)

該当セッションの全エスカレーションを表示。

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

回答は2つの場所に書き込まれます：

### 1. Answer File (CEOが検知用)
```
.auto-dev/sessions/{session_id}/escalations/{escalation_id}-answer.json
```

```json
{
  "escalation_id": "1706234567",
  "answer": "TOTPのみでOK。SMSは後回しで。",
  "answered_at": "2024-01-26T12:00:00+09:00",
  "answered_by": "human"
}
```

### 2. Original Escalation (更新)
```
.auto-dev/sessions/{session_id}/escalations/{escalation_id}.json
```

```json
{
  "id": "1706234567",
  "timestamp": "2024-01-26T11:55:00+09:00",
  "summary": "MFAの実装方式について判断が必要",
  "details": { ... },
  "status": "answered",      // pending → answered
  "answer": "TOTPのみでOK",  // 追加
  "answered_at": "2024-01-26T12:00:00+09:00"  // 追加
}
```

## CEO Detection

CEOは `blackboard-watcher` で `-answer.json` ファイルの出現を監視します：

```
blackboard-watcher を使って監視:
  Directory: .auto-dev/sessions/{session_id}/escalations/
  Pattern: *-answer.json
  Action: 回答ファイルが出現したら読み込んで作業続行
```

## Examples

```bash
# エスカレーション一覧を見る
> /ad:ans abc123

Escalations for session: abc123
==================================

⚠️  [1706234567] PENDING
    MFAの実装方式について判断が必要
    Time: 2024-01-26T11:55:00+09:00

# 回答する
> /ad:ans abc123 "TOTPのみでOK。SMSは後回しで。"

✓ Answer submitted for escalation 1706234567

Escalation: MFAの実装方式について判断が必要
Answer: TOTPのみでOK。SMSは後回しで。

CEO will detect this answer and continue work.
```

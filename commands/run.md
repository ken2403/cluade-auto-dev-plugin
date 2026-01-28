# /ad:run - Auto Dev Command Center

Start a new autonomous development session or resume an existing one.

## Usage

```
/ad:run "instruction"     # Start new session with instruction
/ad:run --session ID      # Resume existing session
/ad:run                   # List sessions and choose to resume
```

## Behavior

### New Session (`/ad:run "instruction"`)

1. Generate unique session ID
2. Create new tmux window for this session
3. Set up session directory structure
4. Spawn CEO in the new window with the instruction
5. Return control immediately to Command Center

### Resume Session (`/ad:run --session ID`)

1. Find the session's tmux window
2. Restore session state from `session.json`
3. Respawn CEO with context
4. Return control immediately

### List Sessions (`/ad:run`)

Show all sessions with status and allow selection.

## Implementation

When this command is invoked, execute the following:

### Step 1: Parse Arguments

```
instruction = args[0] if args else None
session_id = flags.get('session') if flags else None
```

### Step 2: Handle Cases

#### Case A: New Session
```bash
# Generate session ID
SESSION_ID=$(date +%s | md5 | head -c 8)

# Create session directory
mkdir -p .auto-dev/sessions/$SESSION_ID/{blackboard,escalations,implementation,pr,logs}

# Save instruction
echo "$INSTRUCTION" > .auto-dev/sessions/$SESSION_ID/instruction.txt

# Initialize session state
cat > .auto-dev/sessions/$SESSION_ID/session.json << EOF
{
  "session_id": "$SESSION_ID",
  "instruction": "$INSTRUCTION",
  "status": "starting",
  "phase": "init",
  "started_at": "$(date -Iseconds)",
  "updated_at": "$(date -Iseconds)"
}
EOF

# Create tmux window
WINDOW_NUM=$(bash scripts/dashboard.sh ad_new_window "$SESSION_ID" "$INSTRUCTION")

# Spawn CEO in the new window
bash scripts/spinup.sh "$SESSION_ID" ceo \
  "Godからの指示: $INSTRUCTION。作業ディレクトリ: .auto-dev/sessions/$SESSION_ID/"

# Report to user
echo "Session $SESSION_ID started in tmux window $WINDOW_NUM"
echo "Use: tmux select-window -t auto-dev:$WINDOW_NUM"
```

#### Case B: Resume Session
```bash
# Find session directory
if [[ ! -d ".auto-dev/sessions/$SESSION_ID" ]]; then
  echo "Session $SESSION_ID not found"
  exit 1
fi

# Load session state
SESSION_JSON=$(cat .auto-dev/sessions/$SESSION_ID/session.json)
INSTRUCTION=$(echo $SESSION_JSON | jq -r '.instruction')
PHASE=$(echo $SESSION_JSON | jq -r '.phase')

# Find or create tmux window
WINDOW_NUM=$(bash scripts/dashboard.sh ad_find_window "$SESSION_ID")
if [[ -z "$WINDOW_NUM" ]]; then
  WINDOW_NUM=$(bash scripts/dashboard.sh ad_new_window "$SESSION_ID" "$INSTRUCTION")
fi

# Spawn CEO with resume context
bash scripts/spinup.sh "$SESSION_ID" ceo \
  "セッション再開。前回のフェーズ: $PHASE。作業ディレクトリ: .auto-dev/sessions/$SESSION_ID/。session.jsonとblackboard/を確認して続きを実行してください。"

# Report to user
echo "Session $SESSION_ID resumed in tmux window $WINDOW_NUM"
```

#### Case C: List Sessions
```bash
echo "Available Sessions:"
echo "==================="

for dir in .auto-dev/sessions/*/; do
  if [[ -d "$dir" ]]; then
    SID=$(basename "$dir")
    if [[ -f "${dir}session.json" ]]; then
      STATUS=$(jq -r '.status' "${dir}session.json")
      PHASE=$(jq -r '.phase' "${dir}session.json")
      INST=$(head -c 40 "${dir}instruction.txt")
      echo "  [$SID] $STATUS ($PHASE)"
      echo "    \"$INST...\""
    fi
  fi
done

echo ""
echo "To resume: /ad:run --session <ID>"
```

## Session Directory Structure

```
.auto-dev/sessions/{session_id}/
├── instruction.txt          # Original instruction from God
├── session.json             # Session state for recovery
├── blackboard/              # Inter-agent communication
│   ├── ceo-directive.json   # CEO's interpreted directive
│   ├── vp-product.json      # VP Product report
│   ├── vp-design.json       # VP Design report
│   ├── vp-engineering.json  # VP Engineering report
│   ├── pm-1.json            # PM-1 report
│   ├── pm-2.json            # PM-2 report
│   ├── ux.json              # UX report
│   ├── ia.json              # IA report
│   ├── dev-1.json           # Dev-1 report
│   ├── dev-2.json           # Dev-2 report
│   ├── qa-review.json       # QA Lead report
│   └── ceo-decision.json    # CEO final decision
├── escalations/             # Messages requiring God's attention
│   └── {timestamp}.json     # Individual escalation
├── implementation/          # Builder work
│   ├── tasks.json           # Implementation tasks
│   └── builder-{id}/        # Individual Builder work
├── pr/                      # PR artifacts
│   ├── spec-pr.json         # Spec PR info
│   ├── impl-pr.json         # Implementation PR info
│   └── sentinel-log.json    # Review Sentinel log
└── logs/                    # Agent logs (from tmux pipe-pane)
    ├── ceo.log
    ├── vp-product.log
    └── ...
```

## tmux Layout

After starting a session:

```
Window N: Session "{short_instruction}"
┌─────────────────────────────────────────┐
│                  CEO                     │  <- Initial pane
│                                          │
│  (CEO will split and spawn VPs as       │
│   needed based on the instruction)       │
│                                          │
└─────────────────────────────────────────┘
```

As CEO spawns VPs and they spawn members:

```
Window N: Session "{short_instruction}"
┌──────────┬──────────┬──────────┬──────────┐
│   CEO    │VP Product│VP Design │VP Eng    │
│          ├──────────┼──────────┤          │
│          │  PM-1    │   UX     │  Dev-1   │
│          │  PM-2    │   IA     │  Dev-2   │
└──────────┴──────────┴──────────┴──────────┘
```

## Important Notes

1. **Non-blocking**: This command spawns CEO and returns immediately
2. **Parallel sessions**: Multiple sessions can run simultaneously in different windows
3. **State persistence**: Sessions can be resumed after interruption
4. **Log capture**: All pane output is logged via tmux pipe-pane

## Examples

### Start a new feature
```
/ad:run "ユーザー認証にMFAを追加して"
```

### Quick fix
```
/ad:run "ログインページの404エラーを修正"
```

### Resume interrupted session
```
/ad:run --session a1b2c3d4
```

### Check available sessions
```
/ad:run
```

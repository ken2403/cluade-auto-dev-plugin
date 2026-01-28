---
allowed-tools: Read, Bash, Glob
argument-hint: [SESSION_ID]
description: Show status of all sessions and agents
model: haiku
---

# /ad:status - Auto Dev Status

Show status of all sessions and agents.

## Usage

```
/ad:status              # Show all sessions
/ad:status SESSION_ID   # Show detailed status for specific session
```

## Behavior

### All Sessions (`/ad:status`)

Display a summary of all sessions:

```
Auto Dev Sessions
=================

[a1b2c3d4] running (implementation)
  "Add MFA to user authentication..."
  Started: 2024-01-01 10:00
  Active agents: 3 (CEO, VP-Eng, Builder-1)
  Escalations: 0

[e5f6g7h8] paused (qa_review)
  "Fix 404 error on login page..."
  Started: 2024-01-01 09:30
  Active agents: 0
  Escalations: 1 ⚠️

[i9j0k1l2] completed (merged)
  "Update README..."
  Started: 2024-01-01 08:00
  Completed: 2024-01-01 08:45
  PR: #123 (merged)

Total: 3 sessions (1 running, 1 paused, 1 completed)
```

### Specific Session (`/ad:status SESSION_ID`)

Display detailed status:

```
Session: a1b2c3d4
==================

Instruction: "Add MFA to user authentication"
Status: running
Phase: implementation
Started: 2024-01-01 10:00:00
Updated: 2024-01-01 10:45:30

tmux Window: auto-dev-x1y2z3:2

Active Agents:
  - CEO (pane 0) - Monitoring implementation
  - VP Engineering (pane 3) - Coordinating Builders
  - Builder-1 (pane 4) - Implementing MFA service

Completed Reports:
  ✓ vp-product.json (10:15)
  ✓ vp-design.json (10:18)
  ✓ vp-engineering.json (10:22)
  ✓ pm-1.json, pm-2.json (10:12)
  ✓ ux.json, ia.json (10:14)
  ✓ dev-1.json, dev-2.json (10:20)

Pending:
  - QA review (waiting for implementation)
  - PR creation

Escalations: None

Logs:
  - logs/ceo.log (45KB)
  - logs/vp-engineering.log (23KB)
  - logs/builder-1.log (12KB)

Commands:
  View logs: /ad:logs a1b2c3d4 ceo
  Switch to window: tmux select-window -t auto-dev-x1y2z3:2
```

## Implementation

When this command is invoked:

### List All Sessions

```bash
echo "Auto Dev Sessions"
echo "================="
echo ""

TMUX_SESSION=$(cat .auto-dev/tmux-session 2>/dev/null || echo "auto-dev")
RUNNING=0
PAUSED=0
COMPLETED=0

for dir in .auto-dev/sessions/*/; do
  if [[ -d "$dir" ]]; then
    SID=$(basename "$dir")

    if [[ -f "${dir}session.json" ]]; then
      STATUS=$(jq -r '.status // "unknown"' "${dir}session.json")
      PHASE=$(jq -r '.phase // "unknown"' "${dir}session.json")
      STARTED=$(jq -r '.started_at // "unknown"' "${dir}session.json")

      # Count status
      case "$STATUS" in
        running|in_progress) ((RUNNING++)) ;;
        paused|interrupted) ((PAUSED++)) ;;
        completed|merged) ((COMPLETED++)) ;;
      esac

      # Get instruction preview
      INST=""
      if [[ -f "${dir}instruction.txt" ]]; then
        INST=$(head -c 40 "${dir}instruction.txt" | tr '\n' ' ')
      fi

      # Check for escalations
      ESC_COUNT=0
      if [[ -d "${dir}escalations" ]]; then
        ESC_COUNT=$(find "${dir}escalations" -name "*.json" | wc -l | tr -d ' ')
      fi
      ESC_WARN=""
      [[ $ESC_COUNT -gt 0 ]] && ESC_WARN="⚠️"

      # Count active agents (tmux panes)
      ACTIVE_AGENTS=0
      WINDOW=$(bash "$(cat .auto-dev/plugin-dir)/scripts/dashboard.sh" ad_find_window "$SID" 2>/dev/null)
      if [[ -n "$WINDOW" ]]; then
        ACTIVE_AGENTS=$(tmux list-panes -t "$TMUX_SESSION:$WINDOW" 2>/dev/null | wc -l | tr -d ' ')
      fi

      # Get PR info
      PR_INFO=""
      if [[ -f "${dir}pr/impl-pr.json" ]]; then
        PR_NUM=$(jq -r '.number // ""' "${dir}pr/impl-pr.json")
        PR_STATE=$(jq -r '.state // ""' "${dir}pr/impl-pr.json")
        [[ -n "$PR_NUM" ]] && PR_INFO="PR: #$PR_NUM ($PR_STATE)"
      fi

      # Display
      echo "[$SID] $STATUS ($PHASE)"
      echo "  \"$INST...\""
      echo "  Started: $STARTED"
      echo "  Active agents: $ACTIVE_AGENTS"
      [[ -n "$PR_INFO" ]] && echo "  $PR_INFO"
      echo "  Escalations: $ESC_COUNT $ESC_WARN"
      echo ""
    fi
  fi
done

echo "Total: $((RUNNING + PAUSED + COMPLETED)) sessions ($RUNNING running, $PAUSED paused, $COMPLETED completed)"
```

### Show Specific Session

```bash
SESSION_ID="$1"
SESSION_DIR=".auto-dev/sessions/$SESSION_ID"
TMUX_SESSION=$(cat .auto-dev/tmux-session 2>/dev/null || echo "auto-dev")

if [[ ! -d "$SESSION_DIR" ]]; then
  echo "Session $SESSION_ID not found"
  exit 1
fi

echo "Session: $SESSION_ID"
echo "=================="
echo ""

# Basic info
if [[ -f "${SESSION_DIR}/session.json" ]]; then
  STATUS=$(jq -r '.status' "${SESSION_DIR}/session.json")
  PHASE=$(jq -r '.phase' "${SESSION_DIR}/session.json")
  STARTED=$(jq -r '.started_at' "${SESSION_DIR}/session.json")
  UPDATED=$(jq -r '.updated_at' "${SESSION_DIR}/session.json")

  echo "Instruction: \"$(cat ${SESSION_DIR}/instruction.txt)\""
  echo "Status: $STATUS"
  echo "Phase: $PHASE"
  echo "Started: $STARTED"
  echo "Updated: $UPDATED"
  echo ""
fi

# tmux window
WINDOW=$(bash "$(cat .auto-dev/plugin-dir)/scripts/dashboard.sh" ad_find_window "$SESSION_ID" 2>/dev/null)
if [[ -n "$WINDOW" ]]; then
  echo "tmux Window: $TMUX_SESSION:$WINDOW"
  echo ""
  echo "Active Agents:"
  tmux list-panes -t "$TMUX_SESSION:$WINDOW" -F '  - #{pane_title} (pane #{pane_index})' 2>/dev/null
else
  echo "tmux Window: Not active"
fi
echo ""

# Blackboard reports
echo "Completed Reports:"
for f in "${SESSION_DIR}/blackboard/"*.json; do
  if [[ -f "$f" ]]; then
    NAME=$(basename "$f")
    MOD=$(stat -f '%Sm' -t '%H:%M' "$f" 2>/dev/null || stat -c '%y' "$f" 2>/dev/null | cut -d' ' -f2 | cut -d':' -f1,2)
    echo "  ✓ $NAME ($MOD)"
  fi
done
echo ""

# Escalations
echo "Escalations:"
ESC_COUNT=$(find "${SESSION_DIR}/escalations" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$ESC_COUNT" -gt 0 ]]; then
  for f in "${SESSION_DIR}/escalations/"*.json; do
    if [[ -f "$f" ]]; then
      SUMMARY=$(jq -r '.summary // "No summary"' "$f")
      echo "  ⚠️ $SUMMARY"
    fi
  done
else
  echo "  None"
fi
echo ""

# Logs
echo "Logs:"
for f in "${SESSION_DIR}/logs/"*.log; do
  if [[ -f "$f" ]]; then
    NAME=$(basename "$f")
    SIZE=$(du -h "$f" | cut -f1)
    echo "  - $NAME ($SIZE)"
  fi
done
```

## Output Format

The status output is designed to be:
- Scannable at a glance
- Actionable (shows what needs attention)
- Informative (shows progress)

Status indicators:
- `running` - Actively being worked on
- `paused` - Waiting for something (human input, external dependency)
- `completed` - Successfully finished
- `error` - Failed, needs attention
- `⚠️` - Has pending escalations

## Examples

```
> /ad:status

Auto Dev Sessions
=================

[a1b2c3d4] running (implementation)
  "Add MFA to user authentication..."
  Active agents: 3
  Escalations: 0

Total: 1 sessions (1 running)
```

```
> /ad:status a1b2c3d4

Session: a1b2c3d4
==================

Instruction: "Add MFA to user authentication"
Status: running
Phase: implementation
...
```

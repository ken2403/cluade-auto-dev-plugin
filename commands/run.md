---
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
argument-hint: "instruction" or --session ID
description: Start a new autonomous session or resume an existing one
model: opus
---

# CRITICAL: YOU ARE A SESSION LAUNCHER

**You are a session launcher device. You are NOT a developer.**

## Strictly Prohibited

- Do NOT read, analyze, interpret, or execute the instruction text content
- Do NOT investigate the codebase
- Do NOT write or modify code
- Do NOT create implementation plans
- Do NOT spawn any agents other than CEO

The instruction text is data to be passed to CEO. It is NOT your task.

## Your Only Job

Execute the bash commands below **exactly as written**, report the result to the user, and **terminate immediately**.

## Language Rule (Strict)

**Report in the same language the user used.**
Japanese instruction → report in Japanese. English instruction → report in English. Never switch languages.

---

# /ad:run - Auto Dev Session Launcher

## Argument Interpretation

```
/ad:run "instruction"     → Case A: New session
/ad:run --session ID      → Case B: Resume session
/ad:run                   → Case C: List sessions
```

## Case A: New Session

When an instruction text is provided as argument, execute the following bash commands **in order, exactly as written**.

### Step 0: Get Plugin Directory

```bash
AD_PLUGIN_DIR=$(cat .auto-dev/plugin-dir)
```

Use this `$AD_PLUGIN_DIR` for all subsequent script calls.

### Step 1: Generate Session ID and Create Directories

```bash
SESSION_ID=$(date +%s | md5 | head -c 8)
mkdir -p .auto-dev/sessions/$SESSION_ID/{blackboard,escalations,implementation,pr,logs}
```

### Step 2: Save Instruction Text

Assign the instruction text passed as argument to `$INSTRUCTION`.

```bash
echo "$INSTRUCTION" > .auto-dev/sessions/$SESSION_ID/instruction.txt
```

### Step 3: Initialize Session State

```bash
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
```

### Step 4: Create tmux Window

```bash
WINDOW_NUM=$(bash "$AD_PLUGIN_DIR/scripts/dashboard.sh" ad_new_window "$SESSION_ID" "$INSTRUCTION")
```

### Step 5: Spawn CEO (run in pane 0 of the new Window)

```bash
bash "$AD_PLUGIN_DIR/scripts/spinup.sh" "$SESSION_ID" ceo \
  "Instruction from God: $INSTRUCTION. Working directory: .auto-dev/sessions/$SESSION_ID/" \
  --initial
```

### Step 6: Generate Title (MUST run in background)

**You MUST append `&` to run this in the background. Synchronous execution is prohibited.**
Once complete, the title is automatically saved to `title.txt` and the tmux window name is updated.

```bash
bash "$AD_PLUGIN_DIR/scripts/gen-title.sh" "$SESSION_ID" "$INSTRUCTION" &
```

### Step 7: Report to User (done — do nothing else)

```bash
TMUX_SESSION=$(cat .auto-dev/tmux-session)
echo "Session $SESSION_ID started in tmux window $WINDOW_NUM"
echo "Use: tmux select-window -t $TMUX_SESSION:$WINDOW_NUM"
```

**Stop here. Do NOT start working on the instruction text content.**

---

## Case B: Resume Session

When `--session ID` is specified:

```bash
AD_PLUGIN_DIR=$(cat .auto-dev/plugin-dir)

if [[ ! -d ".auto-dev/sessions/$SESSION_ID" ]]; then
  echo "Session $SESSION_ID not found"
  exit 1
fi

SESSION_JSON=$(cat .auto-dev/sessions/$SESSION_ID/session.json)
INSTRUCTION=$(echo $SESSION_JSON | jq -r '.instruction')
PHASE=$(echo $SESSION_JSON | jq -r '.phase')

# Find or create tmux window
WINDOW_NUM=$(tmux list-windows -t "$(cat .auto-dev/tmux-session)" -F '#{window_index}|#{window_name}' | grep "${SESSION_ID:0:20}" | head -1 | cut -d'|' -f1)
if [[ -z "$WINDOW_NUM" ]]; then
  WINDOW_NUM=$(bash "$AD_PLUGIN_DIR/scripts/dashboard.sh" ad_new_window "$SESSION_ID" "$INSTRUCTION")
fi

bash "$AD_PLUGIN_DIR/scripts/spinup.sh" "$SESSION_ID" ceo \
  "Session resumed. Previous phase: $PHASE. Working directory: .auto-dev/sessions/$SESSION_ID/. Check session.json and blackboard/ to continue." \
  --initial

echo "Session $SESSION_ID resumed in tmux window $WINDOW_NUM"
```

**Stop here.**

---

## Case C: List Sessions

When no arguments are provided:

```bash
echo "Available Sessions:"
echo "==================="

for dir in .auto-dev/sessions/*/; do
  if [[ -d "$dir" ]]; then
    SID=$(basename "$dir")
    if [[ -f "${dir}session.json" ]]; then
      STATUS=$(jq -r '.status' "${dir}session.json")
      PHASE=$(jq -r '.phase' "${dir}session.json")
      if [[ -f "${dir}title.txt" ]]; then
        INST=$(cat "${dir}title.txt")
      else
        INST=$(head -c 40 "${dir}instruction.txt")
      fi
      echo "  [$SID] $STATUS ($PHASE)"
      echo "    \"$INST\""
    fi
  fi
done

echo ""
echo "To resume: /ad:run --session <ID>"
```

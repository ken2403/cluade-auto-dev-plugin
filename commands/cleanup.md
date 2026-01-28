---
allowed-tools: Read, Bash, Glob
argument-hint: [SESSION_ID] [--stale] [--all] [--dry-run]
description: Clean up completed sessions, worktrees, and tmux windows
model: haiku
---

# /ad:cleanup - Auto Dev Cleanup

Clean up completed sessions, worktrees, and tmux windows.

## Usage

```
/ad:cleanup              # Clean up all completed sessions
/ad:cleanup SESSION_ID   # Clean up specific session
/ad:cleanup --stale      # Clean up sessions older than 7 days
/ad:cleanup --all        # Clean up ALL sessions (dangerous!)
/ad:cleanup --dry-run    # Preview what would be cleaned
```

## Behavior

### Default (`/ad:cleanup`)

Clean up sessions with status `completed` or `merged`:
1. Kill the session's tmux window (if exists)
2. Remove the session's worktrees (if any)
3. Remove the session directory

### Specific Session (`/ad:cleanup SESSION_ID`)

Clean up a specific session regardless of status:
1. Kill the session's tmux window
2. Remove associated worktrees
3. Remove the session directory

### Stale Sessions (`/ad:cleanup --stale`)

Clean up sessions that haven't been updated in 7+ days:
1. Find sessions with `updated_at` older than 7 days
2. Apply full cleanup to each

### All Sessions (`/ad:cleanup --all`)

**DANGEROUS** - Clean up ALL sessions:
1. Requires confirmation
2. Removes all session data
3. Kills all session tmux windows (except Command Center)
4. Removes all worktrees

### Dry Run (`/ad:cleanup --dry-run`)

Preview what would be cleaned without actually cleaning:
1. List sessions that would be removed
2. List worktrees that would be removed
3. List tmux windows that would be killed

## Implementation

When this command is invoked:

```bash
#!/bin/bash

MODE="${1:-completed}"
DRY_RUN=false

# Parse arguments
case "$1" in
  --stale)   MODE="stale" ;;
  --all)     MODE="all" ;;
  --dry-run) DRY_RUN=true; MODE="${2:-completed}" ;;
  *)         [[ -n "$1" ]] && MODE="specific" && SESSION_ID="$1" ;;
esac

log_action() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] Would: $1"
  else
    echo "$1"
  fi
}

cleanup_session() {
  local sid="$1"
  local session_dir=".auto-dev/sessions/$sid"

  log_action "Clean up session: $sid"

  # Kill tmux window
  local window=$(bash scripts/dashboard.sh ad_find_window "$sid" 2>/dev/null)
  if [[ -n "$window" && "$window" != "0" ]]; then
    TMUX_SESSION=$(cat .auto-dev/tmux-session 2>/dev/null || echo "auto-dev")
    log_action "  Kill tmux window: $TMUX_SESSION:$window"
    [[ "$DRY_RUN" != "true" ]] && tmux kill-window -t "$TMUX_SESSION:$window" 2>/dev/null
  fi

  # Remove worktrees
  for wt in worktrees/*"$sid"*/; do
    if [[ -d "$wt" ]]; then
      log_action "  Remove worktree: $wt"
      if [[ "$DRY_RUN" != "true" ]]; then
        git worktree remove "$wt" --force 2>/dev/null || rm -rf "$wt"
      fi
    fi
  done

  # Remove session directory
  if [[ -d "$session_dir" ]]; then
    log_action "  Remove session directory: $session_dir"
    [[ "$DRY_RUN" != "true" ]] && rm -rf "$session_dir"
  fi
}

case "$MODE" in
  completed)
    echo "Cleaning up completed sessions..."
    echo ""
    for dir in .auto-dev/sessions/*/; do
      if [[ -d "$dir" && -f "${dir}session.json" ]]; then
        status=$(jq -r '.status // "unknown"' "${dir}session.json")
        if [[ "$status" == "completed" || "$status" == "merged" ]]; then
          cleanup_session "$(basename "$dir")"
        fi
      fi
    done
    ;;

  specific)
    if [[ -z "$SESSION_ID" ]]; then
      echo "Error: Session ID required"
      exit 1
    fi
    cleanup_session "$SESSION_ID"
    ;;

  stale)
    echo "Cleaning up stale sessions (>7 days old)..."
    echo ""
    CUTOFF=$(date -v-7d +%s 2>/dev/null || date -d '7 days ago' +%s)
    for dir in .auto-dev/sessions/*/; do
      if [[ -d "$dir" && -f "${dir}session.json" ]]; then
        updated=$(jq -r '.updated_at // "1970-01-01T00:00:00"' "${dir}session.json")
        updated_ts=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$updated" +%s 2>/dev/null || date -d "$updated" +%s 2>/dev/null || echo 0)
        if [[ "$updated_ts" -lt "$CUTOFF" ]]; then
          cleanup_session "$(basename "$dir")"
        fi
      fi
    done
    ;;

  all)
    if [[ "$DRY_RUN" != "true" ]]; then
      echo "WARNING: This will delete ALL sessions!"
      read -p "Type 'yes' to confirm: " confirm
      if [[ "$confirm" != "yes" ]]; then
        echo "Cancelled."
        exit 0
      fi
    fi
    echo "Cleaning up ALL sessions..."
    echo ""
    for dir in .auto-dev/sessions/*/; do
      if [[ -d "$dir" ]]; then
        cleanup_session "$(basename "$dir")"
      fi
    done
    ;;
esac

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "This was a dry run. No changes were made."
  echo "Remove --dry-run to actually clean up."
else
  echo ""
  echo "Cleanup complete."
fi
```

## What Gets Cleaned

### Session Directory
```
.auto-dev/sessions/{session_id}/
├── instruction.txt       ✗ Deleted
├── session.json          ✗ Deleted
├── blackboard/           ✗ Deleted
├── escalations/          ✗ Deleted
├── implementation/       ✗ Deleted
├── pr/                   ✗ Deleted
└── logs/                 ✗ Deleted
```

### Worktrees
```
worktrees/{session_id}-*   ✗ Removed via git worktree remove
```

### tmux Windows
```
auto-dev:{window_num}      ✗ Killed (except window 0 Command Center)
```

## Safety

### Protected Items
- Window 0 (Command Center) is never killed
- Running sessions are not cleaned by default
- Confirmation required for `--all`

### Recovery
- Worktrees can be recreated from git history
- Session logs are lost after cleanup
- Consider archiving important sessions before cleanup

## Examples

```bash
# Preview what would be cleaned
> /ad:cleanup --dry-run
[DRY RUN] Would: Clean up session: a1b2c3d4
[DRY RUN] Would:   Kill tmux window: auto-dev:2
[DRY RUN] Would:   Remove worktree: worktrees/a1b2c3d4-auth
[DRY RUN] Would:   Remove session directory: .auto-dev/sessions/a1b2c3d4

This was a dry run. No changes were made.

# Clean completed sessions
> /ad:cleanup
Cleaning up completed sessions...

Clean up session: a1b2c3d4
  Kill tmux window: auto-dev:2
  Remove worktree: worktrees/a1b2c3d4-auth
  Remove session directory: .auto-dev/sessions/a1b2c3d4

Cleanup complete.

# Clean specific session
> /ad:cleanup e5f6g7h8
Clean up session: e5f6g7h8
  Kill tmux window: auto-dev:3
  Remove session directory: .auto-dev/sessions/e5f6g7h8

Cleanup complete.

# Clean stale sessions
> /ad:cleanup --stale
Cleaning up stale sessions (>7 days old)...

Clean up session: old123
  Remove session directory: .auto-dev/sessions/old123

Cleanup complete.
```

## Warnings

- **Running sessions**: The cleanup will interrupt running sessions. Make sure to check `/ad:status` first.
- **Uncommitted work**: Worktree cleanup may lose uncommitted changes. Ensure important work is committed/pushed.
- **Logs**: Session logs are deleted. Save important logs before cleanup.

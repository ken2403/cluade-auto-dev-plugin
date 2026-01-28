#!/bin/bash
# Auto Dev Dashboard - tmux session management
# Usage: dashboard.sh <command> [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
SESSION_NAME="auto-dev"
SESSIONS_DIR=".auto-dev/sessions"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Check if tmux session exists
session_exists() {
    tmux has-session -t "$SESSION_NAME" 2>/dev/null
}

# Initialize Auto Dev tmux session with Command Center
ad_init() {
    if session_exists; then
        log_warn "Session '$SESSION_NAME' already exists. Attaching..."
        tmux attach-session -t "$SESSION_NAME"
        return
    fi

    log_info "Creating Auto Dev tmux session..."

    # Create session with window 0 as Command Center
    tmux new-session -d -s "$SESSION_NAME" -n "COMMAND-CENTER"

    # Set up Command Center layout
    # Layout: left 40% = adwatch, right top 80% = claude, right bottom 20% = free terminal
    #
    # ┌──────────┬─────────────────┐
    # │          │                 │
    # │          │  Claude (80%)   │
    # │ adwatch  │                 │
    # │  (40%)   ├─────────────────┤
    # │          │ Terminal (20%)  │
    # └──────────┴─────────────────┘

    # Split horizontally: left (pane 0) | right (pane 1)
    tmux split-window -h -t "$SESSION_NAME:0"
    tmux resize-pane -t "$SESSION_NAME:0.0" -p 40

    # Split right pane vertically: top (pane 1) | bottom (pane 2)
    tmux split-window -v -t "$SESSION_NAME:0.1"
    tmux resize-pane -t "$SESSION_NAME:0.1" -p 80

    # Pane 0 (left): adwatch
    tmux send-keys -t "$SESSION_NAME:0.0" "bash '$SCRIPT_DIR/adwatch.sh'" Enter

    # Pane 1 (right top): Claude CLI
    tmux send-keys -t "$SESSION_NAME:0.1" "claude --plugin-dir '$PLUGIN_DIR'" Enter

    # Pane 2 (right bottom): free terminal (no command)
    tmux select-pane -t "$SESSION_NAME:0.2"

    log_success "Auto Dev session created."
    log_info "Window 0: COMMAND-CENTER (left: adwatch, right-top: claude, right-bottom: terminal)"

    # Attach
    tmux attach-session -t "$SESSION_NAME"
}

# Create a new session window for a task
ad_new_window() {
    local session_id="$1"
    local instruction="$2"

    if ! session_exists; then
        log_error "Auto Dev tmux session not found. Run 'dashboard.sh ad_init' first."
        return 1
    fi

    # Find next window number
    local next_win=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_index}' | sort -n | tail -1)
    next_win=$((next_win + 1))

    # Create window with session name
    local win_name="${session_id:0:20}"
    tmux new-window -t "$SESSION_NAME:$next_win" -n "$win_name"

    # Set pane title
    tmux select-pane -t "$SESSION_NAME:$next_win.0" -T "CEO"

    # Enable logging for this pane
    local log_dir="$SESSIONS_DIR/$session_id/logs"
    mkdir -p "$log_dir"
    tmux pipe-pane -t "$SESSION_NAME:$next_win.0" -o "cat >> '$log_dir/ceo.log'"

    log_success "Created window $next_win for session $session_id"
    echo "$next_win"
}

# List all windows (sessions)
ad_list_windows() {
    if ! session_exists; then
        log_warn "Auto Dev tmux session not found."
        return 1
    fi

    echo "Auto Dev Windows:"
    echo "================="
    tmux list-windows -t "$SESSION_NAME" -F '#{window_index}: #{window_name} (#{window_panes} panes)'
}

# Switch to a specific window
ad_switch_window() {
    local window="$1"
    if ! session_exists; then
        log_error "Auto Dev tmux session not found."
        return 1
    fi
    tmux select-window -t "$SESSION_NAME:$window"
}

# Get window info
ad_window_info() {
    local window="$1"
    if ! session_exists; then
        return 1
    fi
    tmux list-panes -t "$SESSION_NAME:$window" -F '#{pane_index}: #{pane_title} (#{pane_pid})'
}

# Kill a window
ad_kill_window() {
    local window="$1"
    if ! session_exists; then
        return 1
    fi

    # Don't kill Command Center
    if [[ "$window" == "0" ]]; then
        log_error "Cannot kill Command Center (window 0)"
        return 1
    fi

    tmux kill-window -t "$SESSION_NAME:$window"
    log_success "Killed window $window"
}

# Kill entire session
ad_destroy() {
    if session_exists; then
        tmux kill-session -t "$SESSION_NAME"
        log_success "Auto Dev session destroyed"
    else
        log_warn "No Auto Dev session to destroy"
    fi
}

# Usage
usage() {
    cat <<EOF
Auto Dev Dashboard - tmux session management

Usage: dashboard.sh <command> [args]

Commands:
  ad_init                    Initialize Auto Dev tmux session
  ad_new_window <sid> <inst> Create new window for session
  ad_list_windows            List all windows
  ad_switch_window <num>     Switch to window
  ad_window_info <num>       Get window pane info
  ad_kill_window <num>       Kill a window (not window 0)
  ad_destroy                 Destroy entire tmux session

Environment:
  SESSION_NAME: $SESSION_NAME
  SESSIONS_DIR: $SESSIONS_DIR

EOF
}

# Main
case "${1:-}" in
    ad_init)        ad_init ;;
    ad_new_window)  ad_new_window "${2:-}" "${3:-}" ;;
    ad_list_windows) ad_list_windows ;;
    ad_switch_window) ad_switch_window "${2:-}" ;;
    ad_window_info) ad_window_info "${2:-}" ;;
    ad_kill_window) ad_kill_window "${2:-}" ;;
    ad_destroy)     ad_destroy ;;
    *)              usage ;;
esac

#!/bin/bash
# Auto Dev Spinup - Spawn claude CLI in tmux pane with role
# Usage: spinup.sh <session_id> <role> <task> [options]

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
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

usage() {
    cat <<EOF
Auto Dev Spinup - Spawn claude CLI agent in tmux pane

Usage: spinup.sh <session_id> <role> <task> [options]

Arguments:
  session_id    Session ID (matches tmux window)
  role          Role name (ceo, vp-product, pm-1, etc.)
  task          Task/instruction to pass to the agent

Options:
  -w, --window N      Target tmux window number (default: find by session_id)
  -t, --target PANE   Split from specific pane (default: current)
  -d, --direction DIR Split direction: h=horizontal, v=vertical (default: h)
  --model MODEL       Claude model to use (default: opus)
  --id ID             Instance ID suffix (for multiple same-role agents)

Environment:
  CLAUDE_BIN          Path to claude CLI (default: claude)
  PLUGIN_DIR          Plugin directory (default: auto-detected)

Examples:
  spinup.sh abc123 ceo "新機能を実装して"
  spinup.sh abc123 vp-product "要件定義をまとめて" --direction v
  spinup.sh abc123 pm-1 "ユーザーニーズを調査" --id a
  spinup.sh abc123 builder "APIエンドポイントを実装" --id 1

EOF
}

# Find window by session_id
find_window_by_session() {
    local session_id="$1"
    local short_id="${session_id:0:20}"

    tmux list-windows -t "$SESSION_NAME" -F '#{window_index}|#{window_name}' 2>/dev/null | \
        while IFS='|' read -r idx name; do
            if [[ "$name" == "$short_id"* ]]; then
                echo "$idx"
                return
            fi
        done
}

# Main
main() {
    local session_id=""
    local role=""
    local task=""
    local window=""
    local target_pane=""
    local direction="h"
    local model="opus"
    local instance_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -w|--window)
                window="$2"
                shift 2
                ;;
            -t|--target)
                target_pane="$2"
                shift 2
                ;;
            -d|--direction)
                direction="$2"
                shift 2
                ;;
            --model)
                model="$2"
                shift 2
                ;;
            --id)
                instance_id="$2"
                shift 2
                ;;
            *)
                if [[ -z "$session_id" ]]; then
                    session_id="$1"
                elif [[ -z "$role" ]]; then
                    role="$1"
                elif [[ -z "$task" ]]; then
                    task="$1"
                fi
                shift
                ;;
        esac
    done

    # Validate required args
    if [[ -z "$session_id" || -z "$role" || -z "$task" ]]; then
        log_error "Missing required arguments"
        usage
        exit 1
    fi

    # Check tmux session
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        log_error "Auto Dev tmux session not found. Run: bash scripts/dashboard.sh ad_init"
        exit 1
    fi

    # Find window if not specified
    if [[ -z "$window" ]]; then
        window=$(find_window_by_session "$session_id")
        if [[ -z "$window" ]]; then
            log_error "Window for session '$session_id' not found"
            exit 1
        fi
    fi

    # Check role file exists
    local role_file="$PLUGIN_DIR/roles/${role}.md"
    if [[ ! -f "$role_file" ]]; then
        log_error "Role file not found: $role_file"
        exit 1
    fi

    # Determine pane name
    local pane_name="$role"
    [[ -n "$instance_id" ]] && pane_name="${role}-${instance_id}"

    # Build target
    local target="$SESSION_NAME:$window"
    [[ -n "$target_pane" ]] && target="$target.$target_pane"

    # Set up split direction flag
    local split_flag="-h"
    [[ "$direction" == "v" ]] && split_flag="-v"

    # Create log directory
    local log_dir="$SESSIONS_DIR/$session_id/logs"
    mkdir -p "$log_dir"

    # Build claude command
    local claude_bin="${CLAUDE_BIN:-claude}"

    # Escape task for shell
    local escaped_task=$(printf '%s' "$task" | sed "s/'/'\\\\''/g")

    # Build the full command
    local cmd="$claude_bin --system-prompt '$role_file' -p '$escaped_task。
作業ディレクトリ: $SESSIONS_DIR/$session_id/
報告先: $SESSIONS_DIR/$session_id/blackboard/${pane_name}.json'"

    log_info "Spawning $pane_name in window $window..."

    # Split and run
    tmux split-window $split_flag -t "$target" "$cmd"

    # Get new pane ID
    local new_pane=$(tmux list-panes -t "$SESSION_NAME:$window" -F '#{pane_index}' | tail -1)

    # Set pane title
    tmux select-pane -t "$SESSION_NAME:$window.$new_pane" -T "$pane_name"

    # Enable logging
    tmux pipe-pane -t "$SESSION_NAME:$window.$new_pane" -o "cat >> '$log_dir/${pane_name}.log'"

    # Retile
    tmux select-layout -t "$SESSION_NAME:$window" tiled

    log_success "Spawned $pane_name (pane $new_pane) in window $window"
    echo "$new_pane"
}

main "$@"

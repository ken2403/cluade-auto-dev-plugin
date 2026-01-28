#!/bin/bash
# Auto Dev Spinup - Spawn claude CLI in tmux pane with role
# Usage: spinup.sh <session_id> <role> <task> [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
SESSIONS_DIR=".auto-dev/sessions"
SESSION_FILE=".auto-dev/tmux-session"

# Load session name from file
load_session_name() {
    if [[ -f "$SESSION_FILE" ]]; then
        SESSION_NAME=$(cat "$SESSION_FILE")
        return 0
    fi
    SESSION_NAME=""
    return 1
}
load_session_name || true

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
  --initial           Run in existing pane 0 (send-keys) instead of split-window

Environment:
  CLAUDE_BIN          Path to claude CLI (default: claude)
  PLUGIN_DIR          Plugin directory (default: auto-detected)

Examples:
  spinup.sh abc123 ceo "Implement a new feature"
  spinup.sh abc123 vp-product "Summarize requirements" --direction v
  spinup.sh abc123 pm-1 "Research user needs" --id a
  spinup.sh abc123 builder "Implement API endpoint" --id 1

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
    local initial=false

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
            --initial)
                initial=true
                shift
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

    # Escape task for shell (single quotes)
    local escaped_task=$(printf '%s' "$task" | sed "s/'/'\\\\''/g")

    # Generate launcher script to properly load role file contents
    # --system-prompt takes a STRING, not a file path.
    # The launcher reads the role file at runtime and passes contents as system prompt.
    # Launches in interactive mode so the agent is visible and responsive in the pane.
    local launcher="$log_dir/.launcher-${pane_name}.sh"
    cat > "$launcher" << LAUNCHER_EOF
#!/bin/bash
ROLE_FILE="$role_file"
ROLE_CONTENT=\$(cat "\$ROLE_FILE")
exec $claude_bin --dangerously-skip-permissions --system-prompt "\$ROLE_CONTENT"
LAUNCHER_EOF
    chmod +x "$launcher"

    # Initial prompt to send after interactive claude starts (must be single line
    # because tmux send-keys interprets newlines as Enter keystrokes)
    local initial_prompt="${escaped_task}. Working directory: $SESSIONS_DIR/$session_id/ | Report to: $SESSIONS_DIR/$session_id/blackboard/${pane_name}.json"

    local cmd="bash '$launcher'"

    log_info "Spawning $pane_name in window $window (role: $role_file)..."

    local new_pane
    if [[ "$initial" == "true" ]]; then
        # Use send-keys to run in existing pane 0 (no split)
        tmux send-keys -t "$SESSION_NAME:$window.0" "$cmd" Enter
        new_pane=0
    else
        # Split and run in new pane
        tmux split-window $split_flag -t "$target" "$cmd"
        new_pane=$(tmux list-panes -t "$SESSION_NAME:$window" -F '#{pane_index}' | tail -1)
    fi

    # Wait for claude CLI to start, then send the initial prompt
    # -l sends text literally (prevents tmux from interpreting special chars as key names)
    # Enter must be sent separately without -l so tmux interprets it as the Enter key
    (
        sleep 5
        tmux send-keys -l -t "$SESSION_NAME:$window.$new_pane" "$initial_prompt"
        sleep 0.2
        tmux send-keys -t "$SESSION_NAME:$window.$new_pane" Enter
    ) &

    # Set pane title
    tmux select-pane -t "$SESSION_NAME:$window.$new_pane" -T "$pane_name"

    # Enable logging
    tmux pipe-pane -t "$SESSION_NAME:$window.$new_pane" -o "cat >> '$log_dir/${pane_name}.log'"

    # Retile (skip for initial since there's only one pane)
    if [[ "$initial" != "true" ]]; then
        tmux select-layout -t "$SESSION_NAME:$window" tiled
    fi

    log_success "Spawned $pane_name (pane $new_pane) in window $window"
    echo "$new_pane"
}

main "$@"

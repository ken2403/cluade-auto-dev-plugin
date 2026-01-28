#!/bin/bash
# Auto Dev Teardown - Clean up panes, windows, worktrees, and sessions
# Usage: teardown.sh <command> [args]

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
WORKTREES_DIR="worktrees"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

usage() {
    cat <<EOF
Auto Dev Teardown - Clean up resources

Usage: teardown.sh <command> [args]

Commands:
  pane <session_id> <pane>     Kill a specific pane
  window <session_id>          Kill session window (and all panes)
  session <session_id>         Remove session data (keeps worktrees)
  worktree <session_id>        Remove session worktrees
  full <session_id>            Full cleanup: window + session + worktrees
  completed                    Clean up all completed sessions
  all                          Clean up all sessions (DANGEROUS)
  stale                        Clean up sessions older than 7 days

Options:
  -f, --force    Skip confirmation prompts
  --dry-run      Show what would be deleted without deleting

Examples:
  teardown.sh pane abc123 3          # Kill pane 3 in session abc123
  teardown.sh window abc123          # Kill window for abc123
  teardown.sh full abc123            # Full cleanup for abc123
  teardown.sh completed              # Clean all completed sessions
  teardown.sh stale --dry-run        # Preview stale cleanup

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

# Kill a specific pane
kill_pane() {
    local session_id="$1"
    local pane="$2"

    local window=$(find_window_by_session "$session_id")
    if [[ -z "$window" ]]; then
        log_error "Window for session '$session_id' not found"
        return 1
    fi

    if tmux kill-pane -t "$SESSION_NAME:$window.$pane" 2>/dev/null; then
        log_success "Killed pane $pane in window $window"
    else
        log_error "Failed to kill pane $pane"
        return 1
    fi
}

# Kill session window
kill_window() {
    local session_id="$1"

    local window=$(find_window_by_session "$session_id")
    if [[ -z "$window" ]]; then
        log_warn "Window for session '$session_id' not found"
        return 0
    fi

    if [[ "$window" == "0" ]]; then
        log_error "Cannot kill Command Center (window 0)"
        return 1
    fi

    if tmux kill-window -t "$SESSION_NAME:$window" 2>/dev/null; then
        log_success "Killed window $window for session $session_id"
    else
        log_error "Failed to kill window $window"
        return 1
    fi
}

# Remove session data
remove_session_data() {
    local session_id="$1"
    local dry_run="${2:-false}"
    local session_dir="$SESSIONS_DIR/$session_id"

    if [[ ! -d "$session_dir" ]]; then
        log_warn "Session directory not found: $session_dir"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] Would remove: $session_dir"
    else
        rm -rf "$session_dir"
        log_success "Removed session data: $session_dir"
    fi
}

# Remove worktrees for session
remove_worktrees() {
    local session_id="$1"
    local dry_run="${2:-false}"

    if [[ ! -d "$WORKTREES_DIR" ]]; then
        return 0
    fi

    # Find worktrees matching session pattern
    local found=false
    for wt in "$WORKTREES_DIR"/*"$session_id"*/; do
        if [[ -d "$wt" ]]; then
            found=true
            if [[ "$dry_run" == "true" ]]; then
                log_info "[DRY RUN] Would remove worktree: $wt"
            else
                # Try git worktree remove first
                local wt_name=$(basename "$wt")
                if git worktree remove "$wt" --force 2>/dev/null; then
                    log_success "Removed worktree: $wt_name"
                else
                    # Fallback to rm
                    rm -rf "$wt"
                    log_success "Removed worktree directory: $wt_name"
                fi
            fi
        fi
    done

    if [[ "$found" == "false" ]]; then
        log_info "No worktrees found for session $session_id"
    fi
}

# Full cleanup
full_cleanup() {
    local session_id="$1"
    local dry_run="${2:-false}"

    log_info "Full cleanup for session: $session_id"

    kill_window "$session_id" || true
    remove_worktrees "$session_id" "$dry_run"
    remove_session_data "$session_id" "$dry_run"

    log_success "Full cleanup completed for $session_id"
}

# Clean up completed sessions
cleanup_completed() {
    local dry_run="${1:-false}"

    if [[ ! -d "$SESSIONS_DIR" ]]; then
        log_info "No sessions directory"
        return 0
    fi

    local count=0
    for session_dir in "$SESSIONS_DIR"/*/; do
        if [[ -d "$session_dir" ]]; then
            local session_id=$(basename "$session_dir")
            local session_file="$session_dir/session.json"

            if [[ -f "$session_file" ]]; then
                local status=$(jq -r '.status // "unknown"' "$session_file" 2>/dev/null)

                if [[ "$status" == "completed" || "$status" == "merged" ]]; then
                    log_info "Cleaning up completed session: $session_id"
                    full_cleanup "$session_id" "$dry_run"
                    ((count++))
                fi
            fi
        fi
    done

    log_info "Cleaned up $count completed sessions"
}

# Clean up stale sessions (older than N days)
cleanup_stale() {
    local days="${1:-7}"
    local dry_run="${2:-false}"

    if [[ ! -d "$SESSIONS_DIR" ]]; then
        log_info "No sessions directory"
        return 0
    fi

    log_info "Cleaning up sessions older than $days days..."

    local count=0
    while IFS= read -r -d '' session_dir; do
        local session_id=$(basename "$session_dir")
        log_info "Stale session found: $session_id"
        full_cleanup "$session_id" "$dry_run"
        ((count++))
    done < <(find "$SESSIONS_DIR" -maxdepth 1 -mindepth 1 -type d -mtime "+$days" -print0)

    log_info "Cleaned up $count stale sessions"
}

# Clean up all sessions
cleanup_all() {
    local dry_run="${1:-false}"
    local force="${2:-false}"

    if [[ "$force" != "true" && "$dry_run" != "true" ]]; then
        log_warn "This will delete ALL sessions and worktrees!"
        read -p "Are you sure? (type 'yes' to confirm): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Cancelled"
            return 0
        fi
    fi

    if [[ ! -d "$SESSIONS_DIR" ]]; then
        log_info "No sessions directory"
        return 0
    fi

    for session_dir in "$SESSIONS_DIR"/*/; do
        if [[ -d "$session_dir" ]]; then
            local session_id=$(basename "$session_dir")
            full_cleanup "$session_id" "$dry_run"
        fi
    done

    log_success "All sessions cleaned up"
}

# Main
main() {
    local command=""
    local dry_run="false"
    local force="false"
    local args=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            *)
                if [[ -z "$command" ]]; then
                    command="$1"
                else
                    args+=("$1")
                fi
                shift
                ;;
        esac
    done

    case "$command" in
        pane)
            [[ ${#args[@]} -lt 2 ]] && { usage; exit 1; }
            kill_pane "${args[0]}" "${args[1]}"
            ;;
        window)
            [[ ${#args[@]} -lt 1 ]] && { usage; exit 1; }
            kill_window "${args[0]}"
            ;;
        session)
            [[ ${#args[@]} -lt 1 ]] && { usage; exit 1; }
            remove_session_data "${args[0]}" "$dry_run"
            ;;
        worktree)
            [[ ${#args[@]} -lt 1 ]] && { usage; exit 1; }
            remove_worktrees "${args[0]}" "$dry_run"
            ;;
        full)
            [[ ${#args[@]} -lt 1 ]] && { usage; exit 1; }
            full_cleanup "${args[0]}" "$dry_run"
            ;;
        completed)
            cleanup_completed "$dry_run"
            ;;
        stale)
            local days="${args[0]:-7}"
            cleanup_stale "$days" "$dry_run"
            ;;
        all)
            cleanup_all "$dry_run" "$force"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"

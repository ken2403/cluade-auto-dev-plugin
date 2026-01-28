#!/bin/bash
# Auto Dev Watch - Cross-window session monitor
# Displays real-time status of all sessions across tmux windows
# Uses fswatch for event-driven updates (falls back to polling if unavailable)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
SESSION_NAME="auto-dev"
SESSIONS_DIR=".auto-dev/sessions"
FALLBACK_INTERVAL=5  # Polling interval if fswatch not available

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Clear screen and move cursor to top
clear_screen() {
    printf "\033[2J\033[H"
}

# Get session status from session.json
get_session_status() {
    local session_id="$1"
    local session_file="$SESSIONS_DIR/$session_id/session.json"

    if [[ -f "$session_file" ]]; then
        jq -r '.status // "unknown"' "$session_file" 2>/dev/null || echo "unknown"
    else
        echo "no-state"
    fi
}

# Get active agents from blackboard
get_active_agents() {
    local session_id="$1"
    local blackboard_dir="$SESSIONS_DIR/$session_id/blackboard"

    if [[ -d "$blackboard_dir" ]]; then
        local count=$(find "$blackboard_dir" -name "*.json" -mmin -5 2>/dev/null | wc -l | tr -d ' ')
        echo "$count"
    else
        echo "0"
    fi
}

# Get instruction summary
get_instruction() {
    local session_id="$1"
    local inst_file="$SESSIONS_DIR/$session_id/instruction.txt"

    if [[ -f "$inst_file" ]]; then
        head -c 40 "$inst_file" | tr '\n' ' '
    else
        echo "-"
    fi
}

# Check for pending escalations
get_pending_escalations() {
    local session_id="$1"
    local esc_dir="$SESSIONS_DIR/$session_id/escalations"

    if [[ -d "$esc_dir" ]]; then
        # Count pending escalations (files without corresponding -answer.json)
        local pending=0
        for esc_file in "$esc_dir"/*.json; do
            if [[ -f "$esc_file" && ! "$esc_file" =~ -answer\.json$ ]]; then
                local answer_file="${esc_file%.json}-answer.json"
                if [[ ! -f "$answer_file" ]]; then
                    pending=$((pending + 1))
                fi
            fi
        done 2>/dev/null
        echo "$pending"
    else
        echo "0"
    fi
}

# Draw the dashboard
draw_dashboard() {
    clear_screen

    local mode_info="Event-driven"
    if [[ "${USE_POLLING:-false}" == "true" ]]; then
        mode_info="Polling (${FALLBACK_INTERVAL}s)"
    fi

    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                    AUTO DEV DASHBOARD                            ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check if tmux session exists
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}No Auto Dev session running.${NC}"
        echo "Run: bash scripts/dashboard.sh ad_init"
        return
    fi

    # List tmux windows
    echo -e "${BOLD}TMUX WINDOWS:${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────────${NC}"

    tmux list-windows -t "$SESSION_NAME" -F '#{window_index}|#{window_name}|#{window_panes}' 2>/dev/null | while IFS='|' read -r win_idx win_name pane_count; do
        if [[ "$win_idx" == "0" ]]; then
            echo -e "  ${GREEN}[$win_idx]${NC} ${BOLD}$win_name${NC} (Command Center) - $pane_count panes"
        else
            echo -e "  ${BLUE}[$win_idx]${NC} $win_name - $pane_count panes"
        fi
    done

    echo ""
    echo -e "${BOLD}SESSIONS:${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────────${NC}"
    printf "  ${DIM}%-15s %-12s %-8s %-6s %-30s${NC}\n" "SESSION_ID" "STATUS" "AGENTS" "ESC" "INSTRUCTION"
    echo -e "${DIM}  ─────────────── ──────────── ──────── ────── ──────────────────────────────${NC}"

    # List sessions from filesystem
    if [[ -d "$SESSIONS_DIR" ]]; then
        local has_sessions=false
        for session_dir in "$SESSIONS_DIR"/*/; do
            if [[ -d "$session_dir" ]]; then
                has_sessions=true
                local session_id=$(basename "$session_dir")
                local status=$(get_session_status "$session_id")
                local agents=$(get_active_agents "$session_id")
                local pending_esc=$(get_pending_escalations "$session_id")
                local inst=$(get_instruction "$session_id")

                # Color status
                local status_color=""
                case "$status" in
                    running|in_progress) status_color="${GREEN}" ;;
                    starting)            status_color="${CYAN}" ;;
                    paused)              status_color="${YELLOW}" ;;
                    completed)           status_color="${BLUE}" ;;
                    error)               status_color="${RED}" ;;
                    *)                   status_color="${DIM}" ;;
                esac

                # Color escalation - highlight pending
                local esc_display="$pending_esc"
                local esc_color="${NC}"
                if [[ "$pending_esc" -gt 0 ]]; then
                    esc_color="${RED}${BOLD}"
                    esc_display="⚠$pending_esc"
                fi

                printf "  %-15s ${status_color}%-12s${NC} %-8s ${esc_color}%-6s${NC} %-30s\n" \
                    "${session_id:0:15}" "$status" "$agents" "$esc_display" "${inst:0:30}"
            fi
        done
        if [[ "$has_sessions" == "false" ]]; then
            echo -e "  ${DIM}No sessions yet. Run /ad:run \"instruction\" to start.${NC}"
        fi
    else
        echo -e "  ${DIM}No sessions yet. Run /ad:run \"instruction\" to start.${NC}"
    fi

    echo ""
    echo -e "${DIM}Updated: $(date '+%H:%M:%S') | Mode: $mode_info | Ctrl+C to exit${NC}"
}

# Event-driven watch using fswatch
watch_with_fswatch() {
    # Initial draw
    draw_dashboard

    # Create sessions dir if not exists (so fswatch has something to watch)
    mkdir -p "$SESSIONS_DIR"

    # Watch for changes and redraw
    fswatch -r -l 0.5 --event Created --event Updated --event Removed --event Renamed \
        "$SESSIONS_DIR" 2>/dev/null | while read -r _; do
        # Debounce: wait a bit for batch changes
        sleep 0.3
        # Clear any queued events
        while read -r -t 0.1 _; do :; done
        draw_dashboard
    done
}

# Fallback polling mode
watch_with_polling() {
    export USE_POLLING=true
    while true; do
        draw_dashboard
        sleep "$FALLBACK_INTERVAL"
    done
}

# Main
main() {
    trap 'echo -e "\n${YELLOW}Exiting adwatch...${NC}"; exit 0' INT TERM

    # Check if fswatch is available
    if command -v fswatch &>/dev/null; then
        watch_with_fswatch
    else
        echo -e "${YELLOW}fswatch not found. Using polling mode.${NC}"
        echo -e "${DIM}Install fswatch for event-driven updates: brew install fswatch${NC}"
        sleep 2
        watch_with_polling
    fi
}

main

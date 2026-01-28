#!/bin/bash
# Auto Dev Watch - Cross-window session monitor
# Displays real-time status of all sessions across tmux windows

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
SESSION_NAME="auto-dev"
SESSIONS_DIR=".auto-dev/sessions"
REFRESH_INTERVAL=2

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
        local count=$(find "$blackboard_dir" -name "*.json" -mmin -5 | wc -l | tr -d ' ')
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

# Check for escalations
has_escalations() {
    local session_id="$1"
    local esc_dir="$SESSIONS_DIR/$session_id/escalations"

    if [[ -d "$esc_dir" ]]; then
        local count=$(find "$esc_dir" -name "*.json" | wc -l | tr -d ' ')
        [[ "$count" -gt 0 ]] && echo "YES" || echo "no"
    else
        echo "no"
    fi
}

# Draw the dashboard
draw_dashboard() {
    clear_screen

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
    printf "  ${DIM}%-15s %-12s %-8s %-6s %-30s${NC}\n" "SESSION_ID" "STATUS" "AGENTS" "ESC?" "INSTRUCTION"
    echo -e "${DIM}  ─────────────── ──────────── ──────── ────── ──────────────────────────────${NC}"

    # List sessions from filesystem
    if [[ -d "$SESSIONS_DIR" ]]; then
        for session_dir in "$SESSIONS_DIR"/*/; do
            if [[ -d "$session_dir" ]]; then
                local session_id=$(basename "$session_dir")
                local status=$(get_session_status "$session_id")
                local agents=$(get_active_agents "$session_id")
                local esc=$(has_escalations "$session_id")
                local inst=$(get_instruction "$session_id")

                # Color status
                local status_color=""
                case "$status" in
                    running)    status_color="${GREEN}" ;;
                    paused)     status_color="${YELLOW}" ;;
                    completed)  status_color="${BLUE}" ;;
                    error)      status_color="${RED}" ;;
                    *)          status_color="${DIM}" ;;
                esac

                # Color escalation
                local esc_color="${NC}"
                [[ "$esc" == "YES" ]] && esc_color="${RED}${BOLD}"

                printf "  %-15s ${status_color}%-12s${NC} %-8s ${esc_color}%-6s${NC} %-30s\n" \
                    "${session_id:0:15}" "$status" "$agents" "$esc" "${inst:0:30}"
            fi
        done
    else
        echo -e "  ${DIM}No sessions yet.${NC}"
    fi

    echo ""
    echo -e "${DIM}Last updated: $(date '+%Y-%m-%d %H:%M:%S') | Refresh: ${REFRESH_INTERVAL}s | Ctrl+C to exit${NC}"
}

# Main loop
main() {
    trap 'echo -e "\n${YELLOW}Exiting adwatch...${NC}"; exit 0' INT TERM

    while true; do
        draw_dashboard
        sleep "$REFRESH_INTERVAL"
    done
}

main

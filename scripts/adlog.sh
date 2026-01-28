#!/bin/bash
# Auto Dev Log Viewer - View agent logs
# Usage: adlog.sh <session_id> [agent_name] [--follow]

set -euo pipefail

SESSIONS_DIR=".auto-dev/sessions"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat <<EOF
Auto Dev Log Viewer

Usage: adlog.sh <session_id> [agent_name] [options]

Arguments:
  session_id    Session ID to view logs for
  agent_name    Specific agent (ceo, vp-product, pm-1, etc.)
                If omitted, lists available logs

Options:
  -f, --follow  Follow log output (like tail -f)
  -n, --lines N Show last N lines (default: 50)
  -l, --list    List all sessions with logs

Examples:
  adlog.sh abc123                  # List logs for session abc123
  adlog.sh abc123 ceo              # View CEO log
  adlog.sh abc123 ceo -f           # Follow CEO log
  adlog.sh abc123 vp-product -n 100 # Last 100 lines of VP Product
  adlog.sh --list                  # List all sessions

EOF
}

list_sessions() {
    echo -e "${BOLD}Sessions with logs:${NC}"
    echo ""

    if [[ ! -d "$SESSIONS_DIR" ]]; then
        echo -e "${DIM}No sessions directory found.${NC}"
        return
    fi

    for session_dir in "$SESSIONS_DIR"/*/; do
        if [[ -d "${session_dir}logs" ]]; then
            local session_id=$(basename "$session_dir")
            local log_count=$(find "${session_dir}logs" -name "*.log" 2>/dev/null | wc -l | tr -d ' ')

            if [[ "$log_count" -gt 0 ]]; then
                echo -e "  ${BLUE}$session_id${NC} ($log_count logs)"

                # Show title (prefer AI-generated title.txt)
                if [[ -f "${session_dir}title.txt" && -s "${session_dir}title.txt" ]]; then
                    local inst=$(head -c 60 "${session_dir}title.txt" | tr '\n\r' '  ' | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    echo -e "    ${DIM}\"$inst\"${NC}"
                elif [[ -f "${session_dir}instruction.txt" ]]; then
                    local inst=$(head -c 60 "${session_dir}instruction.txt" | tr '\n' ' ')
                    echo -e "    ${DIM}\"$inst\"${NC}"
                fi
            fi
        fi
    done
}

list_logs() {
    local session_id="$1"
    local log_dir="$SESSIONS_DIR/$session_id/logs"

    if [[ ! -d "$log_dir" ]]; then
        echo -e "${YELLOW}No logs directory for session: $session_id${NC}"
        return 1
    fi

    echo -e "${BOLD}Logs for session: $session_id${NC}"
    echo ""

    for log_file in "$log_dir"/*.log; do
        if [[ -f "$log_file" ]]; then
            local agent=$(basename "$log_file" .log)
            local size=$(du -h "$log_file" | cut -f1)
            local modified=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$log_file" 2>/dev/null || stat -c '%y' "$log_file" 2>/dev/null | cut -d'.' -f1)

            echo -e "  ${GREEN}$agent${NC}"
            echo -e "    Size: $size | Modified: $modified"
        fi
    done
}

view_log() {
    local session_id="$1"
    local agent_name="$2"
    local follow="${3:-false}"
    local lines="${4:-50}"

    local log_file="$SESSIONS_DIR/$session_id/logs/${agent_name}.log"

    if [[ ! -f "$log_file" ]]; then
        echo -e "${RED}Log not found: $log_file${NC}"
        return 1
    fi

    echo -e "${CYAN}═══ $agent_name log ═══${NC}"
    echo -e "${DIM}File: $log_file${NC}"
    echo ""

    if [[ "$follow" == "true" ]]; then
        tail -n "$lines" -f "$log_file"
    else
        tail -n "$lines" "$log_file"
    fi
}

# Parse arguments
main() {
    local session_id=""
    local agent_name=""
    local follow=false
    local lines=50

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -l|--list)
                list_sessions
                exit 0
                ;;
            -f|--follow)
                follow=true
                shift
                ;;
            -n|--lines)
                lines="$2"
                shift 2
                ;;
            *)
                if [[ -z "$session_id" ]]; then
                    session_id="$1"
                elif [[ -z "$agent_name" ]]; then
                    agent_name="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$session_id" ]]; then
        usage
        exit 1
    fi

    if [[ -z "$agent_name" ]]; then
        list_logs "$session_id"
    else
        view_log "$session_id" "$agent_name" "$follow" "$lines"
    fi
}

main "$@"

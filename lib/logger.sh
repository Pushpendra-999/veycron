#!/usr/bin/env bash
# ============================================================================
# logger.sh - Logging functions for veycron
# ============================================================================

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

CURRENT_LOG_LEVEL=${VEYCRON_LOG_LEVEL:-$LOG_LEVEL_INFO}

# ── Console logging ─────────────────────────────────────────────────────────

log_header() {
    echo ""
    echo -e "${BOLD}${CYAN}═══ $1 ═══${NC}"
    echo ""
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if (( CURRENT_LOG_LEVEL <= LOG_LEVEL_DEBUG )); then
        echo -e "${DIM}[DEBUG] $1${NC}"
    fi
}

log_step() {
    local step="$1"
    local total="$2"
    local message="$3"
    echo -e "${MAGENTA}[${step}/${total}]${NC} ${message}"
}

# ── File logging ─────────────────────────────────────────────────────────────

# Write to the main veycron log file
log_to_file() {
    local level="$1"
    local message="$2"
    local project="${3:-system}"
    local logfile="${VEYCRON_LOG_DIR}/${project}.log"

    ensure_dirs
    echo "[$(timestamp_iso)] [${level}] ${message}" >> "$logfile"
}

# Write to both console and file
log_both() {
    local level="$1"
    local message="$2"
    local project="${3:-system}"

    case "$level" in
        INFO)    log_info "$message" ;;
        SUCCESS) log_success "$message" ;;
        WARN)    log_warn "$message" ;;
        ERROR)   log_error "$message" ;;
    esac
    log_to_file "$level" "$message" "$project"
}

# ── Log viewer ───────────────────────────────────────────────────────────────

cmd_logs() {
    local project="${1:-}"

    if [[ -z "$project" ]]; then
        # Show all logs
        log_header "veycron Logs"
        if [[ -d "$VEYCRON_LOG_DIR" ]]; then
            local logfiles=("$VEYCRON_LOG_DIR"/*.log)
            if [[ -f "${logfiles[0]}" ]]; then
                echo -e "  ${BOLD}Available log files:${NC}"
                echo ""
                for f in "${logfiles[@]}"; do
                    local name
                    name="$(basename "$f" .log)"
                    local lines
                    lines="$(wc -l < "$f" | tr -d ' ')"
                    local size
                    size="$(du -h "$f" | cut -f1 | tr -d ' ')"
                    echo -e "    ${CYAN}${name}${NC} — ${lines} entries, ${size}"
                done
                echo ""
                echo -e "  ${DIM}Use 'veycron logs <project>' to view a specific log.${NC}"
            else
                log_info "No log files found."
            fi
        else
            log_info "Log directory not found. Run 'veycron init' first."
        fi
    else
        # Show specific project logs
        local logfile="${VEYCRON_LOG_DIR}/${project}.log"
        if [[ -f "$logfile" ]]; then
            log_header "Logs: ${project}"
            echo ""
            # Show last 50 lines by default
            tail -n 50 "$logfile" | while IFS= read -r line; do
                if [[ "$line" == *"[ERROR]"* ]]; then
                    echo -e "  ${RED}${line}${NC}"
                elif [[ "$line" == *"[WARN]"* ]]; then
                    echo -e "  ${YELLOW}${line}${NC}"
                elif [[ "$line" == *"[SUCCESS]"* ]]; then
                    echo -e "  ${GREEN}${line}${NC}"
                else
                    echo -e "  ${line}"
                fi
            done
            echo ""
            echo -e "  ${DIM}Showing last 50 entries. Full log: ${logfile}${NC}"
        else
            log_error "No logs found for project '${project}'."
            log_info "Available projects:"
            cmd_list_projects
        fi
    fi
}

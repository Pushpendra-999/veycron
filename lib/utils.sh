#!/usr/bin/env bash
# ============================================================================
# utils.sh - Utility functions for veycron
# Copyright (c) 2026 veycron
# All rights and ownership belong to https://github.com/Pushpendra-999/veycron.git
# ============================================================================

# ── Colors ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' BOLD='' DIM='' NC=''
fi

# ── Printing helpers ─────────────────────────────────────────────────────────
print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        ok)   echo -e "  ${GREEN}✔${NC} ${message}" ;;
        fail) echo -e "  ${RED}✘${NC} ${message}" ;;
        warn) echo -e "  ${YELLOW}⚠${NC} ${message}" ;;
        info) echo -e "  ${BLUE}ℹ${NC} ${message}" ;;
        *)    echo -e "  ${message}" ;;
    esac
}

print_separator() {
    echo -e "${DIM}$(printf '─%.0s' {1..60})${NC}"
}

print_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    cat <<'BANNER'
  ██╗   ██╗███████╗██╗   ██╗ ██████╗██████╗  ██████╗ ███╗   ██╗
  ██║   ██║██╔════╝╚██╗ ██╔╝██╔════╝██╔══██╗██╔═══██╗████╗  ██║
  ██║   ██║█████╗   ╚████╔╝ ██║     ██████╔╝██║   ██║██╔██╗ ██║
  ╚██╗ ██╔╝██╔══╝    ╚██╔╝  ██║     ██╔══██╗██║   ██║██║╚██╗██║
   ╚████╔╝ ███████╗   ██║   ╚██████╗██║  ██║╚██████╔╝██║ ╚████║
    ╚═══╝  ╚══════╝   ╚═╝    ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
BANNER
    echo -e "${NC}"
    echo -e "  ${DIM}Automated Database Backup to Cloudflare R2 — v${VEYCRON_VERSION}${NC}"
    echo -e "  ${DIM}Copyright (c) 2026 veycron — https://github.com/Pushpendra-999/veycron.git${NC}"
    echo ""
}

# ── Input helpers ────────────────────────────────────────────────────────────

# Prompt for required input
# Usage: prompt_required "Label" "variable_name" ["default_value"]
prompt_required() {
    local label="$1"
    local varname="$2"
    local default="${3:-}"
    local value=""

    while true; do
        if [[ -n "$default" ]]; then
            echo -en "  ${CYAN}▸${NC} ${label} ${DIM}[${default}]${NC}: "
        else
            echo -en "  ${CYAN}▸${NC} ${label}: "
        fi
        read -r value
        value="${value:-$default}"

        if [[ -n "$value" ]]; then
            eval "$varname=\$value"
            return 0
        fi
        echo -e "    ${RED}This field is required.${NC}"
    done
}

# Prompt for optional input
prompt_optional() {
    local label="$1"
    local varname="$2"
    local default="${3:-}"
    local value=""

    if [[ -n "$default" ]]; then
        echo -en "  ${CYAN}▸${NC} ${label} ${DIM}[${default}]${NC}: "
    else
        echo -en "  ${CYAN}▸${NC} ${label} ${DIM}(optional)${NC}: "
    fi
    read -r value
    value="${value:-$default}"
    eval "$varname=\$value"
}

# Prompt for secret input (no echo)
prompt_secret() {
    local label="$1"
    local varname="$2"
    local value=""

    while true; do
        echo -en "  ${CYAN}▸${NC} ${label}: "
        read -rs value
        echo ""
        if [[ -n "$value" ]]; then
            eval "$varname=\$value"
            return 0
        fi
        echo -e "    ${RED}This field is required.${NC}"
    done
}

# Prompt for yes/no
prompt_yesno() {
    local label="$1"
    local default="${2:-y}"
    local hint="Y/n"
    [[ "$default" == "n" ]] && hint="y/N"

    echo -en "  ${CYAN}▸${NC} ${label} ${DIM}[${hint}]${NC}: "
    read -r answer
    answer="${answer:-$default}"
    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

# Prompt for selection from list
prompt_select() {
    local label="$1"
    local varname="$2"
    shift 2
    local options=("$@")

    echo -e "  ${CYAN}▸${NC} ${label}:"
    local i=1
    for opt in "${options[@]}"; do
        echo -e "    ${BOLD}${i})${NC} ${opt}"
        ((i++))
    done

    local choice
    while true; do
        echo -en "  ${CYAN}▸${NC} Enter choice [1-${#options[@]}]: "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            eval "$varname=\${options[$((choice-1))]}"
            return 0
        fi
        echo -e "    ${RED}Invalid choice. Try again.${NC}"
    done
}

# ── Validation ───────────────────────────────────────────────────────────────

validate_uri() {
    local uri="$1"
    local db_type="$2"

    case "$db_type" in
        postgresql)
            if [[ "$uri" =~ ^postgres(ql)?:// ]]; then
                return 0
            fi
            ;;
        mongodb)
            if [[ "$uri" =~ ^mongodb(\+srv)?:// ]]; then
                return 0
            fi
            ;;
    esac
    return 1
}

validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

# ── Dependency checks ────────────────────────────────────────────────────────

check_dependency() {
    local cmd="$1"
    local level="${2:-required}"  # required or optional

    if command -v "$cmd" &>/dev/null; then
        local ver=""
        case "$cmd" in
            rclone)    ver="$(rclone --version 2>/dev/null | head -1)" ;;
            pg_dump)   ver="$(pg_dump --version 2>/dev/null | head -1)" ;;
            mongodump) ver="$(mongodump --version 2>/dev/null | head -1)" ;;
            jq)        ver="$(jq --version 2>/dev/null)" ;;
            *)         ver="found" ;;
        esac
        print_status "ok" "${cmd} ${DIM}(${ver})${NC}"
        return 0
    else
        if [[ "$level" == "required" ]]; then
            print_status "fail" "${cmd} — ${RED}not found (required)${NC}"
        else
            print_status "warn" "${cmd} — ${YELLOW}not found (optional)${NC}"
        fi
        return 1
    fi
}

# ── JSON helpers ─────────────────────────────────────────────────────────────

# Read a value from a JSON file
json_get() {
    local file="$1"
    local key="$2"
    jq -r "$key // empty" "$file" 2>/dev/null
}

# Set a value in a JSON file
json_set() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp
    tmp="$(mktemp)"
    jq "$key = \$val" --arg val "$value" "$file" > "$tmp" && mv "$tmp" "$file"
}

# ── Misc ─────────────────────────────────────────────────────────────────────

# Generate a timestamp for filenames
timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Generate ISO timestamp
timestamp_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Human-readable file size
human_size() {
    local bytes="$1"
    if (( bytes >= 1073741824 )); then
        echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
    elif (( bytes >= 1048576 )); then
        echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
    elif (( bytes >= 1024 )); then
        echo "$(echo "scale=2; $bytes/1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

# Ensure data directories exist
ensure_dirs() {
    mkdir -p "$VEYCRON_DATA_DIR" "$VEYCRON_LOG_DIR" "$VEYCRON_TMP_DIR" "$VEYCRON_PROJECTS_DIR"
    chmod 700 "$VEYCRON_DATA_DIR"
}

# Slugify a string for use as a project name
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

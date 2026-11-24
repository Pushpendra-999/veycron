#!/usr/bin/env bash
# ============================================================================
# cron.sh - Cron job management for veycron
# Copyright (c) 2026 veycron
# All rights and ownership belong to https://github.com/Pushpendra-999/veycron.git
# ============================================================================

VEYCRON_CRON_TAG="# veycron-managed"

# ── Get the absolute path to veycron binary ──────────────────────────────────

get_veycron_bin() {
    echo "${VEYCRON_HOME}/bin/veycron"
}

# ── Setup cron job ───────────────────────────────────────────────────────────

setup_cron_job() {
    local project_name="$1"
    local schedule="$2"

    local veycron_bin
    veycron_bin="$(get_veycron_bin)"

    # Build the cron command
    local cron_line="${schedule} ${veycron_bin} run ${project_name} >> ${VEYCRON_LOG_DIR}/${project_name}-cron.log 2>&1 ${VEYCRON_CRON_TAG}:${project_name}"

    # Remove any existing entry for this project
    remove_cron_job "$project_name"

    # Add new cron entry
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -

    log_debug "Cron job added for '${project_name}': ${schedule}"
    log_to_file "INFO" "Cron job set: ${schedule}" "$project_name"
}

# ── Remove cron job ─────────────────────────────────────────────────────────

remove_cron_job() {
    local project_name="$1"

    crontab -l 2>/dev/null | grep -v "${VEYCRON_CRON_TAG}:${project_name}" | crontab - 2>/dev/null || true
    log_debug "Cron job removed for '${project_name}'"
}

# ── Enable cron ──────────────────────────────────────────────────────────────

cmd_cron_enable() {
    local project_name="${1:-}"
    if [[ -z "$project_name" ]]; then
        log_error "Usage: veycron cron enable <project-name>"
        return 1
    fi

    if ! project_exists "$project_name"; then
        log_error "Project '${project_name}' not found."
        return 1
    fi

    local conf="${VEYCRON_PROJECTS_DIR}/${project_name}.json"
    local schedule
    schedule="$(json_get "$conf" '.schedule.cron')"

    setup_cron_job "$project_name" "$schedule"
    update_project_field "$project_name" '.schedule.enabled' 'true'

    log_success "Cron enabled for '${project_name}': ${schedule}"
    log_to_file "INFO" "Cron enabled" "$project_name"
}

# ── Disable cron ─────────────────────────────────────────────────────────────

cmd_cron_disable() {
    local project_name="${1:-}"
    if [[ -z "$project_name" ]]; then
        log_error "Usage: veycron cron disable <project-name>"
        return 1
    fi

    if ! project_exists "$project_name"; then
        log_error "Project '${project_name}' not found."
        return 1
    fi

    remove_cron_job "$project_name"
    update_project_field "$project_name" '.schedule.enabled' 'false'

    log_success "Cron disabled for '${project_name}'"
    log_to_file "INFO" "Cron disabled" "$project_name"
}

# ── Cron status ──────────────────────────────────────────────────────────────

cmd_cron_status() {
    log_header "Cron Job Status"

    local cron_entries
    cron_entries="$(crontab -l 2>/dev/null | grep "${VEYCRON_CRON_TAG}" || true)"

    if [[ -z "$cron_entries" ]]; then
        log_info "No veycron cron jobs found."
        return
    fi

    echo -e "  ${BOLD}Active cron jobs:${NC}"
    echo ""

    while IFS= read -r line; do
        local project_name schedule
        project_name="$(echo "$line" | grep -o "${VEYCRON_CRON_TAG}:[^ ]*" | cut -d: -f2)"
        schedule="$(echo "$line" | awk '{print $1, $2, $3, $4, $5}')"

        echo -e "    ${CYAN}${project_name}${NC}"
        echo -e "      Schedule: ${schedule}"
        echo -e "      ${DIM}$(describe_cron "$schedule")${NC}"
        echo ""
    done <<< "$cron_entries"
}

# ── Human-readable cron description ─────────────────────────────────────────

describe_cron() {
    local cron="$1"
    local min hour dom mon dow
    read -r min hour dom mon dow <<< "$cron"

    local desc=""

    # Time
    if [[ "$min" == "0" && "$hour" != "*" ]]; then
        desc="At ${hour}:00"
    elif [[ "$min" != "*" && "$hour" != "*" ]]; then
        desc="At ${hour}:$(printf '%02d' "$min")"
    elif [[ "$hour" == "*" && "$min" == "0" ]]; then
        desc="Every hour"
    elif [[ "$min" == "*/5" ]]; then
        desc="Every 5 minutes"
    elif [[ "$min" == "*/15" ]]; then
        desc="Every 15 minutes"
    elif [[ "$min" == "*/30" ]]; then
        desc="Every 30 minutes"
    elif [[ "$hour" == "*/2" ]]; then
        desc="Every 2 hours"
    elif [[ "$hour" == "*/6" ]]; then
        desc="Every 6 hours"
    elif [[ "$hour" == "*/12" ]]; then
        desc="Every 12 hours"
    else
        desc="Cron: ${cron}"
        echo "$desc"
        return
    fi

    # Day of week
    case "$dow" in
        0) desc="${desc}, Sundays" ;;
        1) desc="${desc}, Mondays" ;;
        5) desc="${desc}, Fridays" ;;
        1-5) desc="${desc}, weekdays" ;;
        0,6) desc="${desc}, weekends" ;;
        *) ;;
    esac

    # Day of month
    if [[ "$dom" == "1" && "$mon" == "*" ]]; then
        desc="${desc}, 1st of every month"
    fi

    echo "$desc"
}

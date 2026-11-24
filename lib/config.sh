#!/usr/bin/env bash
# ============================================================================
# config.sh - Configuration management for veycron
# ============================================================================

# ── Init command ─────────────────────────────────────────────────────────────

cmd_init() {
    print_banner
    log_header "Initializing veycron"

    # Create directories
    ensure_dirs
    log_success "Data directory created: ${VEYCRON_DATA_DIR}"
    log_success "Log directory created: ${VEYCRON_LOG_DIR}"
    log_success "Projects directory created: ${VEYCRON_PROJECTS_DIR}"

    # Create global config if not exists
    if [[ ! -f "$VEYCRON_CONFIG_FILE" ]]; then
        cat > "$VEYCRON_CONFIG_FILE" <<CONF
{
    "version": "${VEYCRON_VERSION}",
    "initialized_at": "$(timestamp_iso)",
    "smtp": {
        "configured": false,
        "host": "",
        "port": 587,
        "username": "",
        "password": "",
        "from_email": "",
        "tls": true
    },
    "notifications": {
        "on_success": true,
        "on_failure": true
    }
}
CONF
        chmod 600 "$VEYCRON_CONFIG_FILE"
        log_success "Global config created: ${VEYCRON_CONFIG_FILE}"
    else
        log_info "Global config already exists."
    fi

    # Check dependencies
    echo ""
    log_info "Checking dependencies..."
    echo ""
    local missing=false
    for dep in jq rclone crontab curl gzip; do
        if ! command -v "$dep" &>/dev/null; then
            print_status "fail" "${dep} not found"
            missing=true
        else
            print_status "ok" "${dep}"
        fi
    done

    # Check for at least one DB tool
    echo ""
    log_info "Database tools:"
    if command -v pg_dump &>/dev/null; then
        print_status "ok" "pg_dump (PostgreSQL)"
    else
        print_status "warn" "pg_dump not found — PostgreSQL backups unavailable"
    fi
    if command -v mongodump &>/dev/null; then
        print_status "ok" "mongodump (MongoDB)"
    else
        print_status "warn" "mongodump not found — MongoDB backups unavailable"
    fi

    echo ""
    if $missing; then
        log_warn "Some required dependencies are missing. Please install them."
        echo ""
        echo -e "  ${BOLD}Install on Ubuntu/Debian:${NC}"
        echo -e "    sudo apt update && sudo apt install -y jq rclone cron curl gzip"
        echo ""
        echo -e "  ${BOLD}Install on CentOS/RHEL:${NC}"
        echo -e "    sudo yum install -y jq rclone cronie curl gzip"
        echo ""
        echo -e "  ${BOLD}Install on macOS:${NC}"
        echo -e "    brew install jq rclone"
        echo ""
    else
        log_success "All required dependencies are installed!"
    fi

    echo ""
    log_success "veycron initialized successfully!"
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo -e "    1. Run ${CYAN}veycron new${NC} to create your first backup project"
    echo -e "    2. Run ${CYAN}veycron smtp setup${NC} to configure email notifications"
    echo -e "    3. Run ${CYAN}veycron menu${NC} to access the interactive menu"
    echo ""

    log_to_file "INFO" "veycron initialized" "system"
}

# ── Project configuration ────────────────────────────────────────────────────

# Create a new project config file
create_project_config() {
    local project_name="$1"
    local db_type="$2"
    local db_uri="$3"
    local db_name="$4"
    local r2_bucket="$5"
    local r2_access_key="$6"
    local r2_secret_key="$7"
    local r2_endpoint="$8"
    local r2_region="${9:-auto}"
    local schedule="${10:-0 2 * * *}"
    local retention="${11:-30}"
    local notify_emails="${12:-}"
    local compress="${13:-true}"

    local project_file="${VEYCRON_PROJECTS_DIR}/${project_name}.json"

    cat > "$project_file" <<PROJ
{
    "project_name": "${project_name}",
    "created_at": "$(timestamp_iso)",
    "updated_at": "$(timestamp_iso)",
    "database": {
        "type": "${db_type}",
        "uri": "${db_uri}",
        "name": "${db_name}"
    },
    "r2": {
        "bucket": "${r2_bucket}",
        "access_key_id": "${r2_access_key}",
        "secret_access_key": "${r2_secret_key}",
        "endpoint": "${r2_endpoint}",
        "region": "${r2_region}"
    },
    "schedule": {
        "cron": "${schedule}",
        "enabled": true
    },
    "backup": {
        "compress": ${compress},
        "retention_days": ${retention},
        "last_run": null,
        "last_status": null,
        "last_file": null,
        "last_size": null
    },
    "notifications": {
        "enabled": $([ -n "$notify_emails" ] && echo "true" || echo "false"),
        "emails": $(echo "$notify_emails" | jq -R 'split(",") | map(select(. != ""))' 2>/dev/null || echo "[]")
    }
}
PROJ
    chmod 600 "$project_file"
}

# Load project config
load_project() {
    local project_name="$1"
    local project_file="${VEYCRON_PROJECTS_DIR}/${project_name}.json"

    if [[ ! -f "$project_file" ]]; then
        log_error "Project '${project_name}' not found."
        return 1
    fi

    cat "$project_file"
}

# Check if project exists
project_exists() {
    local project_name="$1"
    [[ -f "${VEYCRON_PROJECTS_DIR}/${project_name}.json" ]]
}

# List all projects
get_project_list() {
    if [[ -d "$VEYCRON_PROJECTS_DIR" ]]; then
        find "$VEYCRON_PROJECTS_DIR" -name "*.json" -exec basename {} .json \; 2>/dev/null | sort
    fi
}

# Update a field in project config
update_project_field() {
    local project_name="$1"
    local field="$2"
    local value="$3"
    local project_file="${VEYCRON_PROJECTS_DIR}/${project_name}.json"

    if [[ ! -f "$project_file" ]]; then
        log_error "Project '${project_name}' not found."
        return 1
    fi

    local tmp
    tmp="$(mktemp)"
    jq "${field} = \$val | .updated_at = \$ts" \
        --arg val "$value" \
        --arg ts "$(timestamp_iso)" \
        "$project_file" > "$tmp" && mv "$tmp" "$project_file"
    chmod 600 "$project_file"
}

# ── New project wizard ───────────────────────────────────────────────────────

cmd_new_project() {
    ensure_dirs
    print_banner

    log_header "New Backup Project Setup"
    echo -e "  ${DIM}Follow the prompts to configure a new database backup.${NC}"
    echo ""

    # Step 1: Project name
    print_separator
    echo -e "  ${BOLD}Step 1: Project Details${NC}"
    echo ""
    local project_name=""
    while true; do
        prompt_required "Project name (e.g., my-app)" project_name
        project_name="$(slugify "$project_name")"
        if project_exists "$project_name"; then
            log_error "Project '${project_name}' already exists. Choose another name."
        else
            break
        fi
    done
    echo -e "    ${DIM}Slug: ${project_name}${NC}"

    # Step 2: Database configuration
    echo ""
    print_separator
    echo -e "  ${BOLD}Step 2: Database Configuration${NC}"
    echo ""

    local db_type=""
    prompt_select "Database type" db_type "postgresql" "mongodb"
    echo ""

    local db_uri=""
    while true; do
        prompt_secret "Database URI (connection string)"  db_uri
        if validate_uri "$db_uri" "$db_type"; then
            print_status "ok" "URI format valid"
            break
        else
            case "$db_type" in
                postgresql) log_error "Invalid URI. Expected format: postgresql://user:pass@host:5432/dbname" ;;
                mongodb)    log_error "Invalid URI. Expected format: mongodb://user:pass@host:27017/dbname" ;;
            esac
        fi
    done

    local db_name=""
    prompt_required "Database name to backup" db_name

    # Step 3: Cloudflare R2 configuration
    echo ""
    print_separator
    echo -e "  ${BOLD}Step 3: Cloudflare R2 Configuration${NC}"
    echo ""
    echo -e "  ${DIM}Find these in your Cloudflare dashboard → R2 → Manage R2 API Tokens${NC}"
    echo ""

    local r2_access_key="" r2_secret_key="" r2_endpoint="" r2_bucket="" r2_region=""

    prompt_required "R2 Access Key ID" r2_access_key
    prompt_secret "R2 Secret Access Key" r2_secret_key
    prompt_required "R2 Endpoint URL (e.g., https://<account-id>.r2.cloudflarestorage.com)" r2_endpoint
    prompt_required "R2 Bucket name" r2_bucket
    prompt_optional "R2 Region" r2_region "auto"

    # Step 4: Backup schedule
    echo ""
    print_separator
    echo -e "  ${BOLD}Step 4: Backup Schedule${NC}"
    echo ""
    echo -e "  ${DIM}Common schedules:${NC}"
    echo -e "    ${DIM}Every day at 2 AM:      0 2 * * *${NC}"
    echo -e "    ${DIM}Every 6 hours:           0 */6 * * *${NC}"
    echo -e "    ${DIM}Every day at midnight:   0 0 * * *${NC}"
    echo -e "    ${DIM}Every Sunday at 3 AM:    0 3 * * 0${NC}"
    echo ""

    local schedule=""
    prompt_optional "Cron schedule" schedule "0 2 * * *"

    local retention=""
    prompt_optional "Retention days (delete backups older than)" retention "30"

    local compress="true"
    if prompt_yesno "Compress backup with gzip?" "y"; then
        compress="true"
    else
        compress="false"
    fi

    # Step 5: Email notifications
    echo ""
    print_separator
    echo -e "  ${BOLD}Step 5: Email Notifications${NC}"
    echo ""

    local notify_emails=""
    if prompt_yesno "Enable email notifications?" "y"; then
        # Check if SMTP is configured
        if [[ -f "$VEYCRON_CONFIG_FILE" ]]; then
            local smtp_configured
            smtp_configured="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.configured')"
            if [[ "$smtp_configured" != "true" ]]; then
                log_warn "SMTP is not configured yet."
                if prompt_yesno "Configure SMTP now?" "y"; then
                    cmd_smtp_setup
                fi
            fi
        fi

        echo ""
        echo -e "  ${DIM}Enter email addresses (comma-separated):${NC}"
        prompt_required "Notification emails" notify_emails
    fi

    # Step 6: Review and confirm
    echo ""
    print_separator
    echo -e "  ${BOLD}Review Configuration${NC}"
    echo ""
    echo -e "    ${BOLD}Project:${NC}       ${project_name}"
    echo -e "    ${BOLD}DB Type:${NC}       ${db_type}"
    echo -e "    ${BOLD}DB Name:${NC}       ${db_name}"
    echo -e "    ${BOLD}R2 Bucket:${NC}     ${r2_bucket}"
    echo -e "    ${BOLD}R2 Endpoint:${NC}   ${r2_endpoint}"
    echo -e "    ${BOLD}Schedule:${NC}      ${schedule}"
    echo -e "    ${BOLD}Retention:${NC}     ${retention} days"
    echo -e "    ${BOLD}Compress:${NC}      ${compress}"
    echo -e "    ${BOLD}Notify:${NC}        ${notify_emails:-none}"
    echo ""

    if ! prompt_yesno "Save this configuration?" "y"; then
        log_warn "Setup cancelled."
        return 1
    fi

    # Save configuration
    create_project_config \
        "$project_name" "$db_type" "$db_uri" "$db_name" \
        "$r2_bucket" "$r2_access_key" "$r2_secret_key" "$r2_endpoint" \
        "$r2_region" "$schedule" "$retention" "$notify_emails" "$compress"

    log_success "Project '${project_name}' created!"

    # Configure rclone remote for this project
    setup_rclone_remote "$project_name" "$r2_access_key" "$r2_secret_key" "$r2_endpoint" "$r2_region"
    log_success "Rclone remote configured for '${project_name}'"

    # Setup cron job
    setup_cron_job "$project_name" "$schedule"
    log_success "Cron job scheduled: ${schedule}"

    log_to_file "INFO" "Project '${project_name}' created (${db_type}, bucket: ${r2_bucket})" "system"
    log_to_file "INFO" "Project initialized" "$project_name"

    echo ""
    echo -e "  ${GREEN}${BOLD}✔ Setup complete!${NC}"
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo -e "    • Run ${CYAN}veycron run ${project_name}${NC} to test a manual backup"
    echo -e "    • Run ${CYAN}veycron status${NC} to view all projects"
    echo -e "    • Run ${CYAN}veycron logs ${project_name}${NC} to view logs"
    echo ""
}

# ── List projects ────────────────────────────────────────────────────────────

cmd_list_projects() {
    ensure_dirs
    log_header "Configured Projects"

    local projects
    projects="$(get_project_list)"

    if [[ -z "$projects" ]]; then
        log_info "No projects configured yet."
        echo -e "  Run ${CYAN}veycron new${NC} to create your first backup project."
        return
    fi

    printf "  ${BOLD}%-20s %-12s %-20s %-16s %-10s${NC}\n" "PROJECT" "DB TYPE" "BUCKET" "SCHEDULE" "STATUS"
    print_separator

    while IFS= read -r name; do
        local conf="${VEYCRON_PROJECTS_DIR}/${name}.json"
        local db_type bucket schedule enabled last_status

        db_type="$(json_get "$conf" '.database.type')"
        bucket="$(json_get "$conf" '.r2.bucket')"
        schedule="$(json_get "$conf" '.schedule.cron')"
        enabled="$(json_get "$conf" '.schedule.enabled')"
        last_status="$(json_get "$conf" '.backup.last_status')"

        local status_icon="${DIM}—${NC}"
        case "$last_status" in
            success) status_icon="${GREEN}✔ ok${NC}" ;;
            failed)  status_icon="${RED}✘ fail${NC}" ;;
            running) status_icon="${YELLOW}⟳ run${NC}" ;;
        esac

        if [[ "$enabled" != "true" ]]; then
            status_icon="${DIM}disabled${NC}"
        fi

        printf "  %-20s %-12s %-20s %-16s " "$name" "$db_type" "$bucket" "$schedule"
        echo -e "$status_icon"
    done <<< "$projects"

    echo ""
}

# ── Status ───────────────────────────────────────────────────────────────────

cmd_status() {
    ensure_dirs
    print_banner
    log_header "System Status"

    # SMTP status
    if [[ -f "$VEYCRON_CONFIG_FILE" ]]; then
        local smtp_configured
        smtp_configured="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.configured')"
        if [[ "$smtp_configured" == "true" ]]; then
            local smtp_host
            smtp_host="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.host')"
            print_status "ok" "SMTP: Configured (${smtp_host})"
        else
            print_status "warn" "SMTP: Not configured"
        fi
    fi

    # Rclone
    if command -v rclone &>/dev/null; then
        print_status "ok" "Rclone: Installed"
    else
        print_status "fail" "Rclone: Not installed"
    fi

    # Cron
    if command -v crontab &>/dev/null; then
        local cron_count
        cron_count="$(crontab -l 2>/dev/null | grep -c 'veycron' || true)"
        print_status "ok" "Cron: ${cron_count} veycron job(s) active"
    else
        print_status "fail" "Cron: Not available"
    fi

    echo ""

    # List projects with detail
    cmd_list_projects
}

# ── Edit project ─────────────────────────────────────────────────────────────

cmd_edit_project() {
    local project_name="${1:-}"
    if [[ -z "$project_name" ]]; then
        log_error "Usage: veycron edit <project-name>"
        return 1
    fi

    if ! project_exists "$project_name"; then
        log_error "Project '${project_name}' not found."
        return 1
    fi

    local conf="${VEYCRON_PROJECTS_DIR}/${project_name}.json"

    log_header "Edit Project: ${project_name}"
    echo -e "  ${DIM}Press Enter to keep current value.${NC}"
    echo ""

    # Load current values
    local cur_schedule cur_retention cur_compress cur_emails
    cur_schedule="$(json_get "$conf" '.schedule.cron')"
    cur_retention="$(json_get "$conf" '.backup.retention_days')"
    cur_compress="$(json_get "$conf" '.backup.compress')"
    cur_emails="$(jq -r '.notifications.emails // [] | join(",")' "$conf")"

    local new_schedule="" new_retention=""
    prompt_optional "Cron schedule" new_schedule "$cur_schedule"
    prompt_optional "Retention days" new_retention "$cur_retention"

    local new_emails=""
    prompt_optional "Notification emails (comma-separated)" new_emails "$cur_emails"

    # Apply changes
    local tmp
    tmp="$(mktemp)"
    jq ".schedule.cron = \$sched | .backup.retention_days = (\$ret | tonumber) | .notifications.emails = (\$emails | split(\",\") | map(select(. != \"\"))) | .notifications.enabled = (\$emails | length > 0) | .updated_at = \$ts" \
        --arg sched "$new_schedule" \
        --arg ret "$new_retention" \
        --arg emails "$new_emails" \
        --arg ts "$(timestamp_iso)" \
        "$conf" > "$tmp" && mv "$tmp" "$conf"
    chmod 600 "$conf"

    # Update cron if schedule changed
    if [[ "$new_schedule" != "$cur_schedule" ]]; then
        remove_cron_job "$project_name"
        setup_cron_job "$project_name" "$new_schedule"
        log_success "Cron schedule updated."
    fi

    log_success "Project '${project_name}' updated!"
    log_to_file "INFO" "Project configuration updated" "$project_name"
}

# ── Delete project ───────────────────────────────────────────────────────────

cmd_delete_project() {
    local project_name="${1:-}"
    if [[ -z "$project_name" ]]; then
        log_error "Usage: veycron delete <project-name>"
        return 1
    fi

    if ! project_exists "$project_name"; then
        log_error "Project '${project_name}' not found."
        return 1
    fi

    echo ""
    log_warn "This will permanently delete project '${project_name}' and its cron job."
    if ! prompt_yesno "Are you sure?" "n"; then
        log_info "Cancelled."
        return 0
    fi

    # Remove cron job
    remove_cron_job "$project_name"

    # Remove rclone remote
    remove_rclone_remote "$project_name"

    # Remove project config
    rm -f "${VEYCRON_PROJECTS_DIR}/${project_name}.json"

    log_success "Project '${project_name}' deleted."
    log_to_file "INFO" "Project '${project_name}' deleted" "system"
}

#!/usr/bin/env bash
# ============================================================================
# smtp.sh - SMTP email configuration and sending for veycron
# ============================================================================

# ── SMTP Setup ───────────────────────────────────────────────────────────────

cmd_smtp_setup() {
    ensure_dirs
    log_header "SMTP Email Configuration"
    echo -e "  ${DIM}Configure email settings for backup notifications.${NC}"
    echo ""

    local host="" port="" username="" password="" from_email="" use_tls=""

    echo -e "  ${BOLD}Common SMTP servers:${NC}"
    echo -e "    ${DIM}Gmail:        smtp.gmail.com (port 587) — use App Password${NC}"
    echo -e "    ${DIM}Outlook:      smtp.office365.com (port 587)${NC}"
    echo -e "    ${DIM}SendGrid:     smtp.sendgrid.net (port 587)${NC}"
    echo -e "    ${DIM}AWS SES:      email-smtp.<region>.amazonaws.com (port 587)${NC}"
    echo -e "    ${DIM}Mailgun:      smtp.mailgun.org (port 587)${NC}"
    echo -e "    ${DIM}Zoho:         smtp.zoho.com (port 587)${NC}"
    echo ""

    # Load existing values as defaults
    local cur_host="" cur_port="" cur_username="" cur_from=""
    if [[ -f "$VEYCRON_CONFIG_FILE" ]]; then
        cur_host="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.host')"
        cur_port="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.port')"
        cur_username="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.username')"
        cur_from="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.from_email')"
    fi

    prompt_required "SMTP Host" host "$cur_host"
    prompt_optional "SMTP Port" port "${cur_port:-587}"
    prompt_required "SMTP Username" username "$cur_username"
    prompt_secret "SMTP Password"  password
    prompt_required "From email address" from_email "$cur_from"

    if prompt_yesno "Use TLS/STARTTLS?" "y"; then
        use_tls="true"
    else
        use_tls="false"
    fi

    # Save SMTP config
    local tmp
    tmp="$(mktemp)"
    jq '.smtp.configured = true |
        .smtp.host = $host |
        .smtp.port = ($port | tonumber) |
        .smtp.username = $user |
        .smtp.password = $pass |
        .smtp.from_email = $from |
        .smtp.tls = ($tls == "true")' \
        --arg host "$host" \
        --arg port "$port" \
        --arg user "$username" \
        --arg pass "$password" \
        --arg from "$from_email" \
        --arg tls "$use_tls" \
        "$VEYCRON_CONFIG_FILE" > "$tmp" && mv "$tmp" "$VEYCRON_CONFIG_FILE"
    chmod 600 "$VEYCRON_CONFIG_FILE"

    log_success "SMTP configuration saved!"
    log_to_file "INFO" "SMTP configured: ${host}:${port}" "system"

    echo ""
    if prompt_yesno "Send a test email now?" "y"; then
        local test_to=""
        prompt_required "Send test email to" test_to
        _send_email "$test_to" "veycron Test Email" \
            "This is a test email from veycron.\n\nIf you received this, your SMTP configuration is working correctly.\n\nTimestamp: $(timestamp_iso)"
        if [[ $? -eq 0 ]]; then
            log_success "Test email sent to ${test_to}!"
        else
            log_error "Failed to send test email. Check your SMTP settings."
        fi
    fi
}

# ── SMTP Status ──────────────────────────────────────────────────────────────

cmd_smtp_status() {
    log_header "SMTP Configuration Status"

    if [[ ! -f "$VEYCRON_CONFIG_FILE" ]]; then
        log_warn "veycron not initialized. Run 'veycron init' first."
        return 1
    fi

    local configured host port username from_email tls
    configured="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.configured')"

    if [[ "$configured" != "true" ]]; then
        print_status "warn" "SMTP: Not configured"
        echo ""
        echo -e "  Run ${CYAN}veycron smtp setup${NC} to configure email notifications."
        return
    fi

    host="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.host')"
    port="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.port')"
    username="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.username')"
    from_email="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.from_email')"
    tls="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.tls')"

    print_status "ok" "SMTP: Configured"
    echo ""
    echo -e "    ${BOLD}Host:${NC}      ${host}"
    echo -e "    ${BOLD}Port:${NC}      ${port}"
    echo -e "    ${BOLD}Username:${NC}  ${username}"
    echo -e "    ${BOLD}From:${NC}      ${from_email}"
    echo -e "    ${BOLD}TLS:${NC}       ${tls}"
    echo -e "    ${BOLD}Password:${NC}  ${DIM}********${NC}"
    echo ""

    # Show which projects have notifications enabled
    log_info "Projects with email notifications:"
    local projects
    projects="$(get_project_list)"
    if [[ -n "$projects" ]]; then
        while IFS= read -r name; do
            local conf="${VEYCRON_PROJECTS_DIR}/${name}.json"
            local notif_enabled emails
            notif_enabled="$(json_get "$conf" '.notifications.enabled')"
            emails="$(jq -r '.notifications.emails // [] | join(", ")' "$conf")"
            if [[ "$notif_enabled" == "true" ]]; then
                echo -e "    ${GREEN}✔${NC} ${name}: ${emails}"
            else
                echo -e "    ${DIM}—${NC} ${name}: ${DIM}notifications off${NC}"
            fi
        done <<< "$projects"
    else
        echo -e "    ${DIM}No projects configured.${NC}"
    fi
}

# ── SMTP Test ────────────────────────────────────────────────────────────────

cmd_smtp_test() {
    log_header "SMTP Test"

    if [[ ! -f "$VEYCRON_CONFIG_FILE" ]]; then
        log_error "veycron not initialized. Run 'veycron init' first."
        return 1
    fi

    local configured
    configured="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.configured')"
    if [[ "$configured" != "true" ]]; then
        log_error "SMTP not configured. Run 'veycron smtp setup' first."
        return 1
    fi

    local test_to=""
    prompt_required "Send test email to" test_to

    echo ""
    log_info "Sending test email to ${test_to}..."

    _send_email "$test_to" "veycron Test Email" \
        "Hello!\n\nThis is a test email from veycron.\nYour SMTP configuration is working correctly.\n\nServer: $(hostname -f 2>/dev/null || hostname)\nTimestamp: $(timestamp_iso)\n\n— veycron"

    if [[ $? -eq 0 ]]; then
        log_success "Test email sent successfully!"
    else
        log_error "Failed to send test email."
        log_info "Check your SMTP credentials and settings with 'veycron smtp status'"
    fi
}

# ── Internal: Send email via curl ────────────────────────────────────────────
# Uses curl with SMTP to send emails — no external mail tools needed.

_send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    local host port username password from_email tls
    host="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.host')"
    port="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.port')"
    username="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.username')"
    password="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.password')"
    from_email="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.from_email')"
    tls="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.tls')"

    local date_header
    date_header="$(date -R 2>/dev/null || date)"

    # Build email message
    local email_file
    email_file="$(mktemp)"

    cat > "$email_file" <<EMAIL
From: veycron <${from_email}>
To: ${to}
Subject: ${subject}
Date: ${date_header}
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

$(echo -e "$body")
EMAIL

    # Build curl command
    local curl_opts=(
        --url "smtp://${host}:${port}"
        --mail-from "$from_email"
        --mail-rcpt "$to"
        --upload-file "$email_file"
        --user "${username}:${password}"
        --silent
        --show-error
    )

    if [[ "$tls" == "true" ]]; then
        curl_opts+=(--ssl-reqd)
    fi

    if curl "${curl_opts[@]}" 2>&1; then
        rm -f "$email_file"
        return 0
    else
        local err=$?
        rm -f "$email_file"
        log_debug "curl SMTP exit code: ${err}"
        return 1
    fi
}

# ── Send backup notification ────────────────────────────────────────────────

send_notification() {
    local project_name="$1"
    local status="$2"       # success or failed
    local remote_file="$3"
    local file_size="$4"

    local conf="${VEYCRON_PROJECTS_DIR}/${project_name}.json"

    # Check if notifications are enabled for this project
    local notif_enabled
    notif_enabled="$(json_get "$conf" '.notifications.enabled')"
    if [[ "$notif_enabled" != "true" ]]; then
        log_debug "Notifications disabled for '${project_name}'"
        return 0
    fi

    # Check if SMTP is configured
    if [[ ! -f "$VEYCRON_CONFIG_FILE" ]]; then
        return 0
    fi
    local smtp_configured
    smtp_configured="$(json_get "$VEYCRON_CONFIG_FILE" '.smtp.configured')"
    if [[ "$smtp_configured" != "true" ]]; then
        log_debug "SMTP not configured — skipping notification"
        return 0
    fi

    # Check global notification preferences
    local notify_on_success notify_on_failure
    notify_on_success="$(json_get "$VEYCRON_CONFIG_FILE" '.notifications.on_success')"
    notify_on_failure="$(json_get "$VEYCRON_CONFIG_FILE" '.notifications.on_failure')"

    if [[ "$status" == "success" && "$notify_on_success" == "false" ]]; then
        return 0
    fi
    if [[ "$status" == "failed" && "$notify_on_failure" == "false" ]]; then
        return 0
    fi

    # Get recipients
    local emails
    emails="$(jq -r '.notifications.emails // [] | .[]' "$conf")"
    if [[ -z "$emails" ]]; then
        return 0
    fi

    # Build subject and body
    local db_type db_name bucket
    db_type="$(json_get "$conf" '.database.type')"
    db_name="$(json_get "$conf" '.database.name')"
    bucket="$(json_get "$conf" '.r2.bucket')"

    local status_emoji subject body
    if [[ "$status" == "success" ]]; then
        status_emoji="✅"
        subject="${status_emoji} [${project_name}] Backup Successful"
        body="Hello,\n\nThe scheduled database backup for project '${project_name}' completed successfully.\n\n"
        body+="── Details ──────────────────────────\n"
        body+="  Project:   ${project_name}\n"
        body+="  Database:  ${db_type} (${db_name})\n"
        body+="  File:      ${remote_file}\n"
        body+="  Size:      $(human_size "$file_size")\n"
        body+="  Bucket:    ${bucket}\n"
        body+="  Time:      $(timestamp_iso)\n"
        body+="  Server:    $(hostname -f 2>/dev/null || hostname)\n"
        body+="─────────────────────────────────────\n\n"
        body+="— veycron"
    else
        status_emoji="❌"
        subject="${status_emoji} [${project_name}] Backup FAILED"
        body="Hello,\n\n⚠️  The scheduled database backup for project '${project_name}' has FAILED.\n\n"
        body+="── Details ──────────────────────────\n"
        body+="  Project:   ${project_name}\n"
        body+="  Database:  ${db_type} (${db_name})\n"
        body+="  Time:      $(timestamp_iso)\n"
        body+="  Server:    $(hostname -f 2>/dev/null || hostname)\n"
        body+="─────────────────────────────────────\n\n"
        body+="Please check the logs:\n"
        body+="  veycron logs ${project_name}\n\n"
        body+="— veycron"
    fi

    # Send to each recipient
    while IFS= read -r email; do
        if [[ -n "$email" ]]; then
            log_debug "Sending notification to: ${email}"
            _send_email "$email" "$subject" "$body"
        fi
    done <<< "$emails"

    log_to_file "INFO" "Notification sent (${status}) to $(echo "$emails" | wc -l | tr -d ' ') recipient(s)" "$project_name"
}

#!/usr/bin/env bash
# ============================================================================
# backup.sh - Database backup logic for MongoDB and PostgreSQL
# Copyright (c) 2026 veycron
# All rights and ownership belong to https://github.com/Pushpendra-999/veycron.git
# ============================================================================

# ── Main backup runner ───────────────────────────────────────────────────────

cmd_run_backup() {
    local project_name="${1:-}"
    if [[ -z "$project_name" ]]; then
        log_error "Usage: veycron run <project-name>"
        return 1
    fi

    if ! project_exists "$project_name"; then
        log_error "Project '${project_name}' not found."
        log_info "Run 'veycron list' to see available projects."
        return 1
    fi

    local conf="${VEYCRON_PROJECTS_DIR}/${project_name}.json"
    local db_type db_uri db_name compress retention

    db_type="$(json_get "$conf" '.database.type')"
    db_uri="$(json_get "$conf" '.database.uri')"
    db_name="$(json_get "$conf" '.database.name')"
    compress="$(json_get "$conf" '.backup.compress')"
    retention="$(json_get "$conf" '.backup.retention_days')"

    log_header "Running Backup: ${project_name}"
    log_both "INFO" "Starting backup for '${project_name}' (${db_type})" "$project_name"

    # Mark as running
    update_project_field "$project_name" '.backup.last_status' 'running'
    update_project_field "$project_name" '.backup.last_run' "$(timestamp_iso)"

    # Create temp directory for this backup
    local backup_dir="${VEYCRON_TMP_DIR}/${project_name}"
    mkdir -p "$backup_dir"

    local ts
    ts="$(timestamp)"
    local backup_file=""
    local backup_success=false
    local backup_size=0

    # Perform database dump
    case "$db_type" in
        postgresql)
            backup_file="${backup_dir}/${project_name}_${ts}.sql"
            if dump_postgresql "$db_uri" "$db_name" "$backup_file" "$project_name"; then
                backup_success=true
            fi
            ;;
        mongodb)
            backup_file="${backup_dir}/${project_name}_${ts}"
            if dump_mongodb "$db_uri" "$db_name" "$backup_file" "$project_name"; then
                # mongodump creates a directory, archive it
                local archive="${backup_file}.archive"
                tar -cf "$archive" -C "$backup_dir" "$(basename "$backup_file")" 2>/dev/null
                rm -rf "$backup_file"
                backup_file="$archive"
                backup_success=true
            fi
            ;;
        *)
            log_both "ERROR" "Unknown database type: ${db_type}" "$project_name"
            update_project_field "$project_name" '.backup.last_status' 'failed'
            return 1
            ;;
    esac

    if ! $backup_success; then
        log_both "ERROR" "Database dump failed" "$project_name"
        update_project_field "$project_name" '.backup.last_status' 'failed'
        cleanup_tmp "$backup_dir"
        send_notification "$project_name" "failed" "" "0"
        return 1
    fi

    # Compress if enabled
    if [[ "$compress" == "true" ]] && [[ -f "$backup_file" ]]; then
        log_both "INFO" "Compressing backup..." "$project_name"
        gzip -f "$backup_file"
        backup_file="${backup_file}.gz"
    fi

    # Get file size
    if [[ -f "$backup_file" ]]; then
        backup_size="$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null || echo 0)"
        log_both "INFO" "Backup size: $(human_size "$backup_size")" "$project_name"
    fi

    # Upload to R2
    local year month
    year="$(date +%Y)"
    month="$(date +%m)"
    local remote_path="${project_name}/${year}/${month}/$(basename "$backup_file")"

    log_both "INFO" "Uploading to Cloudflare R2..." "$project_name"
    if upload_file_to_r2 "$project_name" "$backup_file" "$remote_path"; then
        log_both "SUCCESS" "Backup uploaded successfully!" "$project_name"
        update_project_field "$project_name" '.backup.last_status' 'success'
        update_project_field "$project_name" '.backup.last_file' "$remote_path"
        update_project_field "$project_name" '.backup.last_size' "$backup_size"

        # Cleanup old backups
        if [[ -n "$retention" ]] && [[ "$retention" -gt 0 ]]; then
            cleanup_old_backups "$project_name" "$retention"
        fi

        # Send success notification (non-blocking)
        send_notification "$project_name" "success" "$remote_path" "$backup_size" || true
    else
        log_both "ERROR" "Failed to upload backup to R2" "$project_name"
        update_project_field "$project_name" '.backup.last_status' 'failed'
        send_notification "$project_name" "failed" "" "$backup_size" || true
    fi

    # Cleanup temp files
    cleanup_tmp "$backup_dir"

    echo ""
    log_both "INFO" "Backup process complete" "$project_name"
}

# ── PostgreSQL dump ──────────────────────────────────────────────────────────

dump_postgresql() {
    local uri="$1"
    local db_name="$2"
    local output_file="$3"
    local project_name="$4"

    if ! command -v pg_dump &>/dev/null; then
        log_both "ERROR" "pg_dump not found. Install PostgreSQL client tools." "$project_name"
        return 1
    fi

    log_both "INFO" "Dumping PostgreSQL database: ${db_name}" "$project_name"

    if pg_dump "$uri" \
        --format=plain \
        --no-owner \
        --no-privileges \
        --verbose \
        --file="$output_file" \
        2>&1 | while IFS= read -r line; do
            log_to_file "DEBUG" "pg_dump: $line" "$project_name"
        done; then
        log_both "SUCCESS" "PostgreSQL dump complete: $(basename "$output_file")" "$project_name"
        return 0
    else
        log_both "ERROR" "pg_dump failed" "$project_name"
        return 1
    fi
}

# ── MongoDB dump ─────────────────────────────────────────────────────────────

dump_mongodb() {
    local uri="$1"
    local db_name="$2"
    local output_dir="$3"
    local project_name="$4"

    if ! command -v mongodump &>/dev/null; then
        log_both "ERROR" "mongodump not found. Install MongoDB database tools." "$project_name"
        return 1
    fi

    log_both "INFO" "Dumping MongoDB database: ${db_name}" "$project_name"

    if mongodump \
        --uri="$uri" \
        --db="$db_name" \
        --out="$output_dir" \
        --gzip \
        2>&1 | while IFS= read -r line; do
            log_to_file "DEBUG" "mongodump: $line" "$project_name"
        done; then
        log_both "SUCCESS" "MongoDB dump complete" "$project_name"
        return 0
    else
        log_both "ERROR" "mongodump failed" "$project_name"
        return 1
    fi
}

# ── Cleanup temp files ──────────────────────────────────────────────────────

cleanup_tmp() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        rm -rf "$dir"
        log_debug "Cleaned up temp directory: ${dir}"
    fi
}

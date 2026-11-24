#!/usr/bin/env bash
# ============================================================================
# rclone.sh - Rclone configuration for Cloudflare R2
# Copyright (c) 2026 veycron
# All rights and ownership belong to https://github.com/Pushpendra-999/veycron.git
# ============================================================================

RCLONE_CONFIG="${VEYCRON_DATA_DIR}/rclone.conf"
export RCLONE_CONFIG

# ── Setup rclone remote ─────────────────────────────────────────────────────

setup_rclone_remote() {
    local project_name="$1"
    local access_key="$2"
    local secret_key="$3"
    local endpoint="$4"
    local region="${5:-auto}"

    local remote_name="veycron-${project_name}"

    # Ensure config directory exists
    mkdir -p "$(dirname "$RCLONE_CONFIG")"
    touch "$RCLONE_CONFIG"
    chmod 600 "$RCLONE_CONFIG"

    # Remove existing remote if present
    rclone config delete "$remote_name" 2>/dev/null || true

    # Create new remote
    rclone config create "$remote_name" s3 \
        provider "Cloudflare" \
        access_key_id "$access_key" \
        secret_access_key "$secret_key" \
        endpoint "$endpoint" \
        region "$region" \
        acl "private" \
        no_check_bucket true \
        --config "$RCLONE_CONFIG" \
        2>/dev/null

    log_debug "Rclone remote '${remote_name}' configured"
}

# ── Remove rclone remote ────────────────────────────────────────────────────

remove_rclone_remote() {
    local project_name="$1"
    local remote_name="veycron-${project_name}"

    rclone config delete "$remote_name" --config "$RCLONE_CONFIG" 2>/dev/null || true
    log_debug "Rclone remote '${remote_name}' removed"
}

# ── Check if rclone is configured ───────────────────────────────────────────

rclone_configured() {
    [[ -f "$RCLONE_CONFIG" ]] && [[ -s "$RCLONE_CONFIG" ]]
}

# ── Upload file to R2 ───────────────────────────────────────────────────────

upload_to_r2() {
    local project_name="$1"
    local local_file="$2"
    local remote_path="$3"

    local remote_name="veycron-${project_name}"

    # Load project config
    local conf="${VEYCRON_PROJECTS_DIR}/${project_name}.json"
    local bucket
    bucket="$(json_get "$conf" '.r2.bucket')"

    local destination="${remote_name}:${bucket}/${remote_path}"

    log_debug "Uploading ${local_file} → ${destination}"

    if rclone copy "$local_file" "$(dirname "$destination")/" \
        --config "$RCLONE_CONFIG" \
        --progress \
        --transfers 1 \
        --s3-upload-cutoff 100M \
        --s3-chunk-size 50M \
        2>&1; then
        return 0
    else
        return 1
    fi
}

# Actually rclone copy needs the file name handled differently. Let me use
# copyto for single files.
upload_file_to_r2() {
    local project_name="$1"
    local local_file="$2"
    local remote_subpath="$3"  # e.g., "2024/01/backup.sql.gz"

    local remote_name="veycron-${project_name}"
    local conf="${VEYCRON_PROJECTS_DIR}/${project_name}.json"
    local bucket
    bucket="$(json_get "$conf" '.r2.bucket')"

    local destination="${remote_name}:${bucket}/${remote_subpath}"

    log_both "INFO" "Uploading to R2: ${destination}" "$project_name"

    if rclone copyto "$local_file" "$destination" \
        --config "$RCLONE_CONFIG" \
        --s3-upload-cutoff 100M \
        --s3-chunk-size 50M \
        --log-level INFO \
        2>&1; then
        log_both "SUCCESS" "Upload complete: ${destination}" "$project_name"
        return 0
    else
        log_both "ERROR" "Upload failed: ${destination}" "$project_name"
        return 1
    fi
}

# ── List files in R2 bucket ─────────────────────────────────────────────────

list_r2_files() {
    local project_name="$1"
    local prefix="${2:-}"

    local remote_name="veycron-${project_name}"
    local conf="${VEYCRON_PROJECTS_DIR}/${project_name}.json"
    local bucket
    bucket="$(json_get "$conf" '.r2.bucket')"

    rclone ls "${remote_name}:${bucket}/${prefix}" \
        --config "$RCLONE_CONFIG" 2>/dev/null
}

# ── Cleanup old backups in R2 ────────────────────────────────────────────────

cleanup_old_backups() {
    local project_name="$1"
    local retention_days="$2"

    local remote_name="veycron-${project_name}"
    local conf="${VEYCRON_PROJECTS_DIR}/${project_name}.json"
    local bucket
    bucket="$(json_get "$conf" '.r2.bucket')"

    log_both "INFO" "Cleaning up backups older than ${retention_days} days" "$project_name"

    rclone delete "${remote_name}:${bucket}/${project_name}/" \
        --config "$RCLONE_CONFIG" \
        --min-age "${retention_days}d" \
        2>&1

    log_both "INFO" "Cleanup complete" "$project_name"
}

# ── Test R2 connectivity ────────────────────────────────────────────────────

test_r2_connection() {
    local project_name="$1"

    local remote_name="veycron-${project_name}"
    local conf="${VEYCRON_PROJECTS_DIR}/${project_name}.json"
    local bucket
    bucket="$(json_get "$conf" '.r2.bucket')"

    if rclone lsd "${remote_name}:${bucket}" \
        --config "$RCLONE_CONFIG" \
        --max-depth 0 \
        2>/dev/null; then
        return 0
    else
        return 1
    fi
}

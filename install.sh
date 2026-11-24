#!/usr/bin/env bash
# ============================================================================
# veycron installer
# Copyright (c) 2026 veycron
# All rights and ownership belong to https://github.com/Pushpendra-999/veycron.git
# ============================================================================
# Install from GitHub:
#   curl -fsSL https://raw.githubusercontent.com/Pushpendra-999/veycron/main/install.sh | sudo bash
# ============================================================================

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────

REPO_URL="${VEYCRON_REPO_URL:-https://github.com/Pushpendra-999/veycron.git}"
INSTALL_DIR="${VEYCRON_INSTALL_DIR:-/opt/veycron}"
BIN_LINK="/usr/local/bin/veycron"
BRANCH="${VEYCRON_BRANCH:-main}"

# ── Colors ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Functions ────────────────────────────────────────────────────────────────

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This installer must be run as root (use sudo)."
        echo ""
        echo "  sudo bash install.sh"
        echo "  or"
        echo "  curl -fsSL https://raw.githubusercontent.com/Pushpendra-999/veycron/main/install.sh | sudo bash"
        exit 1
    fi
}

check_deps() {
    local missing=()
    for cmd in git bash jq curl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        error "Missing dependencies: ${missing[*]}"
        echo ""
        echo "  Install them first:"
        echo "    Ubuntu/Debian:  sudo apt install -y ${missing[*]}"
        echo "    CentOS/RHEL:    sudo yum install -y ${missing[*]}"
        echo "    macOS:          brew install ${missing[*]}"
        exit 1
    fi

    # Check for rclone
    if ! command -v rclone &>/dev/null; then
        warn "rclone is not installed. It is required for R2 uploads."
        echo ""
        echo -e "  Install rclone: ${CYAN}curl https://rclone.org/install.sh | sudo bash${NC}"
        echo ""
        read -rp "  Continue anyway? [y/N] " answer
        if [[ "${answer,,}" != "y" ]]; then
            exit 1
        fi
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
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
    echo -e "  ${DIM}Installer${NC}"
    echo -e "  ${DIM}Copyright (c) 2026 veycron — All rights belong to https://github.com/Pushpendra-999/veycron.git${NC}"
    echo ""

    check_root
    check_deps

    # ── Clone or update ──────────────────────────────────────────────────
    if [[ -d "$INSTALL_DIR" ]]; then
        info "Updating existing installation from ${REPO_URL}..."
        cd "$INSTALL_DIR"
        git fetch origin "$BRANCH" --quiet
        git reset --hard "origin/${BRANCH}" --quiet
        success "Updated to latest version."
    else
        info "Installing veycron from ${REPO_URL} to ${INSTALL_DIR}..."
        git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR" --quiet
        success "Repository cloned."
    fi

    # ── Set permissions ──────────────────────────────────────────────────
    chmod +x "${INSTALL_DIR}/bin/veycron"
    chmod -R 755 "${INSTALL_DIR}/lib/"

    # ── Create symlink ───────────────────────────────────────────────────
    ln -sf "${INSTALL_DIR}/bin/veycron" "$BIN_LINK"
    success "Symlinked: ${BIN_LINK} → ${INSTALL_DIR}/bin/veycron"

    # ── Create data directory ────────────────────────────────────────────
    mkdir -p /etc/veycron/{logs,tmp,projects}
    chmod 700 /etc/veycron
    success "Data directory created: /etc/veycron"

    # ── Done ─────────────────────────────────────────────────────────────
    echo ""
    echo -e "  ${GREEN}${BOLD}✔ veycron installed successfully!${NC}"
    echo -e "  ${DIM}Official repository: https://github.com/Pushpendra-999/veycron.git${NC}"
    echo ""
    echo -e "  ${BOLD}Get started:${NC}"
    echo -e "    ${CYAN}veycron init${NC}        Initialize the service"
    echo -e "    ${CYAN}veycron new${NC}         Create a new backup project"
    echo -e "    ${CYAN}veycron menu${NC}        Open interactive menu"
    echo -e "    ${CYAN}veycron policy${NC}      View copyright & policy terms"
    echo -e "    ${CYAN}veycron help${NC}        Show all commands"
    echo ""
}

main "$@"

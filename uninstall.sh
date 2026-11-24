#!/usr/bin/env bash
# ============================================================================
# veycron uninstaller
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="${VEYCRON_INSTALL_DIR:-/opt/veycron}"
BIN_LINK="/usr/local/bin/veycron"
DATA_DIR="/etc/veycron"

echo ""
echo -e "${YELLOW}${BOLD}veycron Uninstaller${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Must be run as root (use sudo)." >&2
    exit 1
fi

# Remove cron jobs
echo -e "${CYAN}[INFO]${NC} Removing veycron cron jobs..."
crontab -l 2>/dev/null | grep -v '# veycron-managed' | crontab - 2>/dev/null || true
echo -e "${GREEN}[OK]${NC} Cron jobs removed."

# Remove symlink
if [[ -L "$BIN_LINK" ]]; then
    rm -f "$BIN_LINK"
    echo -e "${GREEN}[OK]${NC} Symlink removed: ${BIN_LINK}"
fi

# Remove installation
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}[OK]${NC} Installation removed: ${INSTALL_DIR}"
fi

# Ask about data
echo ""
echo -e "${YELLOW}[WARN]${NC} Data directory: ${DATA_DIR}"
echo -e "  This contains your project configs, logs, and rclone config."
read -rp "  Delete data directory? [y/N] " answer

if [[ "${answer,,}" == "y" ]]; then
    rm -rf "$DATA_DIR"
    echo -e "${GREEN}[OK]${NC} Data directory removed."
else
    echo -e "${CYAN}[INFO]${NC} Data directory preserved at ${DATA_DIR}"
fi

echo ""
echo -e "${GREEN}${BOLD}✔ veycron uninstalled.${NC}"
echo ""

#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/install.sh [hambot|oled|both] [install_parent_dir]
# Defaults: target=both, install_parent_dir=$HOME
TARGET="${1:-both}"
INSTALL_PARENT_DIR="${2:-$HOME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$TARGET" in
  hambot)
    echo "==> Installing HamBot only..."
    "$SCRIPT_DIR/setup_hambot.sh" "$INSTALL_PARENT_DIR"
    ;;
  oled)
    echo "==> Installing OLED only..."
    "$SCRIPT_DIR/setup_oled.sh"
    ;;
  both)
    echo "==> Installing BOTH HamBot and OLED..."
    "$SCRIPT_DIR/setup_hambot.sh" "$INSTALL_PARENT_DIR"
    "$SCRIPT_DIR/setup_oled.sh"
    ;;
  *)
    echo "Usage: $0 [hambot|oled|both] [install_parent_dir]"
    exit 1
    ;;
esac

echo "==> Install complete for target: $TARGET"

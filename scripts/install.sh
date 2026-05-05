#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/install.sh [hambot|oled|depthai|both|all] [install_parent_dir]
# Defaults: target=both, install_parent_dir=$HOME
#
#   hambot  — HamBot repo + venv + .bashrc auto-activation
#   oled    — OLED display service (systemd + NetworkManager hook)
#   depthai — DepthAI/OAK camera udev rules + pip deps (requires hambot first)
#   both    — hambot + oled
#   all     — hambot + oled + depthai
TARGET="${1:-all}"
INSTALL_PARENT_DIR="${2:-$HOME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

copy_examples() {
    echo "==> Copying examples to ~/Desktop/Examples..."
    mkdir -p "$HOME/Desktop/Examples"
    cp -r "$SCRIPT_DIR/Examples/." "$HOME/Desktop/Examples/"
}

case "$TARGET" in
  hambot)
    echo "==> Installing HamBot only..."
    "$SCRIPT_DIR/setup_hambot.sh" "$INSTALL_PARENT_DIR"
    copy_examples
    ;;
  oled)
    echo "==> Installing OLED only..."
    "$SCRIPT_DIR/setup_oled.sh"
    ;;
  depthai)
    echo "==> Installing DepthAI only..."
    "$SCRIPT_DIR/setup_depthai.sh" "$INSTALL_PARENT_DIR"
    ;;
  both)
    echo "==> Installing BOTH HamBot and OLED..."
    "$SCRIPT_DIR/setup_hambot.sh" "$INSTALL_PARENT_DIR"
    "$SCRIPT_DIR/setup_oled.sh"
    copy_examples
    ;;
  all)
    echo "==> Installing ALL (HamBot, OLED, and DepthAI)..."
    "$SCRIPT_DIR/setup_hambot.sh" "$INSTALL_PARENT_DIR"
    "$SCRIPT_DIR/setup_oled.sh"
    "$SCRIPT_DIR/setup_depthai.sh" "$INSTALL_PARENT_DIR"
    copy_examples
    ;;
  *)
    echo "Usage: $0 [hambot|oled|depthai|both|all] [install_parent_dir]"
    exit 1
    ;;
esac

echo "==> Install complete for target: $TARGET"

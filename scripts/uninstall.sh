#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/uninstall.sh [hambot|oled|depthai|both|all] [install_parent_dir]
# Defaults: target=both, install_parent_dir=$HOME
TARGET="${1:-both}"
INSTALL_PARENT_DIR="${2:-$HOME}"

echo "==> Uninstall target: $TARGET"
echo "==> Using install parent dir: $INSTALL_PARENT_DIR"

# --- Common paths / markers used by setup scripts ---
HAMBOT_DIR="$INSTALL_PARENT_DIR/HamBot"
VENV_DIR="$HAMBOT_DIR/hambot_venv"
BASHRC="$HOME/.bashrc"
SNIPPET_TAG="# >>> HamBot global auto-activate >>>"
SNIPPET_END="# <<< HamBot global auto-activate <<<"

DEPTHAI_DIR="$INSTALL_PARENT_DIR/depthai-python"
VENV_DIR="$HAMBOT_DIR/hambot_venv"
UDEV_RULE="/etc/udev/rules.d/80-movidius.rules"

OLED_RUN_USER="hambot"
OLED_HOME="$(eval echo ~${OLED_RUN_USER} 2>/dev/null || echo "$HOME")"
OLED_REPO="$OLED_HOME/HamBot_OLED"
OLED_VENV="$OLED_REPO/.venv"
OLED_SERVICE="/etc/systemd/system/hambot_oled.service"
NM_DISPATCHER="/etc/NetworkManager/dispatcher.d/99-hambot-oled"

remove_hambot() {
  echo "==> Removing HamBot bash auto-activation snippet (if present) from $BASHRC"
  if [ -f "$BASHRC" ] && grep -qF "$SNIPPET_TAG" "$BASHRC"; then
    awk -v start="$SNIPPET_TAG" -v end="$SNIPPET_END" '
      $0==start {inblk=1; next}
      $0==end   {inblk=0; next}
      !inblk {print}
    ' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
  fi

  # Optional cleanup: remove repo & venv
  if [ -d "$HAMBOT_DIR" ]; then
    echo "==> Removing HamBot directory: $HAMBOT_DIR"
    rm -rf "$HAMBOT_DIR"
  fi
}

remove_oled() {
  # Stop/disable service if present
  if systemctl list-unit-files | grep -q "^hambot_oled.service"; then
    echo "==> Disabling and stopping hambot_oled.service"
    sudo systemctl disable hambot_oled.service || true
    sudo systemctl stop hambot_oled.service || true
  fi

  # Remove service file
  if [ -f "$OLED_SERVICE" ]; then
    echo "==> Removing $OLED_SERVICE"
    sudo rm -f "$OLED_SERVICE"
    sudo systemctl daemon-reload
  fi

  # Remove NM dispatcher hook
  if [ -f "$NM_DISPATCHER" ]; then
    echo "==> Removing $NM_DISPATCHER"
    sudo rm -f "$NM_DISPATCHER"
    sudo systemctl restart NetworkManager || true
  fi

  # Optional cleanup: remove repo & venv
  if [ -d "$OLED_REPO" ]; then
    echo "==> Removing OLED repo: $OLED_REPO"
    sudo rm -rf "$OLED_REPO"
  fi
}

remove_depthai() {
  # Remove udev rule
  if [ -f "$UDEV_RULE" ]; then
    echo "==> Removing udev rule: $UDEV_RULE"
    sudo rm -f "$UDEV_RULE"
    sudo udevadm control --reload-rules && sudo udevadm trigger
  fi

  # Remove depthai-python clone
  if [ -d "$DEPTHAI_DIR" ]; then
    echo "==> Removing depthai-python directory: $DEPTHAI_DIR"
    rm -rf "$DEPTHAI_DIR"
  fi

  # Uninstall pip packages from the venv if it exists
  if [ -f "$VENV_DIR/bin/activate" ]; then
    echo "==> Uninstalling depthai pip packages from $VENV_DIR..."
    # shellcheck disable=SC1090
    source "$VENV_DIR/bin/activate"
    pip uninstall -y depthai simplejpeg || true
  fi
}

case "$TARGET" in
  hambot)
    remove_hambot
    ;;
  oled)
    remove_oled
    ;;
  depthai)
    remove_depthai
    ;;
  both)
    remove_hambot
    remove_oled
    ;;
  all)
    remove_depthai
    remove_hambot
    remove_oled
    ;;
  *)
    echo "Usage: $0 [hambot|oled|depthai|both|all] [install_parent_dir]"
    exit 1
    ;;
esac

echo "==> Uninstall complete for target: $TARGET"
echo "Note: open a NEW terminal to ensure ~/.bashrc changes are applied."

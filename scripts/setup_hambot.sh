#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/setup_hambot.sh [install_parent_dir]
# Default parent dir is $HOME
INSTALL_PARENT_DIR="${1:-$HOME}"
HAMBOT_DIR="$INSTALL_PARENT_DIR/HamBot"
VENV_DIR="$HAMBOT_DIR/hambot_venv"

echo "==> Using install parent dir: $INSTALL_PARENT_DIR"
mkdir -p "$INSTALL_PARENT_DIR"

# 1) Clone or update the HamBot repo
if [ -d "$HAMBOT_DIR/.git" ]; then
  echo "==> HamBot already cloned. Pulling latest..."
  git -C "$HAMBOT_DIR" pull --ff-only
else
  echo "==> Cloning HamBot..."
  git clone https://github.com/biorobaw/HamBot "$HAMBOT_DIR"
fi

# 2) Create venv WITH system packages and install deps via pip install .
echo "==> Creating virtual environment with system packages..."
python3 -m venv --system-site-packages "$VENV_DIR"

echo "==> Activating venv and installing HamBot (robot_systems)..."
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip setuptools wheel
cd "$HAMBOT_DIR"
pip install .
cd - >/dev/null

# 3) Global auto-activation for interactive bash sessions
BASHRC="$HOME/.bashrc"
SNIPPET_TAG="# >>> HamBot global auto-activate >>>"
SNIPPET_END="# <<< HamBot global auto-activate <<<"

AUTO_SNIPPET=$(cat <<'EOF'
# >>> HamBot global auto-activate >>>
# On interactive bash shells, automatically activate the HamBot venv.
# Preserve system 'python3' and 'pip3' to NOT replace the default call to python3.
if [ -n "$PS1" ] && [ -t 0 ]; then
  HAMBOT_DIR="${HAMBOT_DIR:-$HOME/HamBot}"
  VENV_PATH="$HAMBOT_DIR/hambot_venv"
  if [ -d "$VENV_PATH" ]; then
    # Activate if not already active
    if [ -z "${VIRTUAL_ENV:-}" ] || [ "$VIRTUAL_ENV" != "$VENV_PATH" ]; then
      . "$VENV_PATH/bin/activate"
    fi
    # Keep system python3/pip3 as defaults
    if command -v /usr/bin/python3 >/dev/null 2>&1; then
      alias python3='/usr/bin/python3'
    fi
    if command -v /usr/bin/pip3 >/dev/null 2>&1; then
      alias pip3='/usr/bin/pip3'
    fi
  fi
fi
# <<< HamBot global auto-activate <<<
EOF
)

# Install or refresh the snippet in ~/.bashrc
if grep -qF "$SNIPPET_TAG" "$BASHRC" 2>/dev/null; then
  echo "==> Updating existing HamBot auto-activation snippet in $BASHRC"
  awk -v start="$SNIPPET_TAG" -v end="$SNIPPET_END" '
    $0==start {print; inblk=1; print ENVIRON["AUTO_SNIPPET"]; skip=1; next}
    $0==end   {inblk=0; next}
    !inblk {print}
  ' "$BASHRC" > "$BASHRC.tmp"
  mv "$BASHRC.tmp" "$BASHRC"
else
  echo "==> Adding HamBot auto-activation snippet to $BASHRC"
  {
    echo
    echo "$SNIPPET_TAG"
    echo "$AUTO_SNIPPET"
    echo "$SNIPPET_END"
  } >> "$BASHRC"
fi

echo "==> Done."
echo
echo "What this means:"
echo " - Every NEW interactive bash terminal will auto-activate $VENV_DIR."
echo " - 'python' and 'pip' will use the venv."
echo " - 'python3' and 'pip3' remain the system defaults (/usr/bin/python3, /usr/bin/pip3)."
echo " - To temporarily leave the venv in a session: 'deactivate'. It will re-activate next new terminal."

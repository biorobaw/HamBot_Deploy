#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/biorobaw/HamBot_OLED"
RUN_USER="hambot"
HOME_DIR="$(eval echo ~${RUN_USER})"
REPO_DIR="${HOME_DIR}/HamBot_OLED"
VENV_DIR="${REPO_DIR}/.venv"
VENV_ACTIVATE="${VENV_DIR}/bin/activate"
VENV_PY="${VENV_DIR}/bin/python"
PY_SCRIPT="${REPO_DIR}/src/hambot_oled/network_display.py"   # adjust if your repo's script has a different name


echo "[1/4] Clone OLED repo..."
if [[ -d "${REPO_DIR}" ]]; then
  echo "Repo already exists at ${REPO_DIR}, pulling latest..."
  sudo -u "${RUN_USER}" git -C "${REPO_DIR}" pull --ff-only
else
  cd "${HOME_DIR}"
  sudo -u "${RUN_USER}" git clone "${REPO_URL}"
fi

echo "[2/4] Create venv and install package..."
sudo -u "${RUN_USER}" python3 -m venv "${VENV_DIR}"
sudo -u "${RUN_USER}" bash -lc "
  cd '${REPO_DIR}' && \
  source '${VENV_ACTIVATE}' && \
  python -m pip install --upgrade pip wheel setuptools && \
  pip install .
"


echo "[3/4] Systemd one-shot boot service..."
DISPATCHER_SCRIPT="/etc/NetworkManager/dispatcher.d/99-hambot-oled"
sudo tee "$DISPATCHER_SCRIPT" > /dev/null <<'EOF'
#!/bin/sh
# Run once on each network state change (interface and status provided by NM)
exec __VENV_PY__ __PY_SCRIPT__
EOF
sudo sed -i "s|__VENV_PY__|${VENV_PY}|g" "$DISPATCHER_SCRIPT"
sudo sed -i "s|__PY_SCRIPT__|${PY_SCRIPT}|g" "$DISPATCHER_SCRIPT"
sudo chmod +x "$DISPATCHER_SCRIPT"
sudo systemctl restart NetworkManager


echo "[4/4] NetworkManager dispatcher hook..."
SYSTEMD_SERVICE="/etc/systemd/system/hambot_oled.service"
sudo tee "$SYSTEMD_SERVICE" > /dev/null <<EOF
[Unit]
Description=Run OLED network display once at boot
Wants=network-online.target
After=network-online.target
ConditionPathExists=/dev/i2c-1

[Service]
Type=oneshot
User=${RUN_USER}
WorkingDirectory=${REPO_DIR}
Environment=PYTHONUNBUFFERED=1
# Give the I2C device a couple seconds on slow boots
ExecStartPre=/bin/sh -c 'for i in 1 2 3; do [ -e /dev/i2c-1 ] && exit 0; sleep 1; done; exit 0'
ExecStart=${VENV_PY} ${PY_SCRIPT}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable hambot_oled.service
sudo systemctl start hambot_oled.service

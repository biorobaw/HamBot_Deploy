#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/biorobaw/HamBot_OLED"
RUN_USER="hambot"
HOME_DIR="$(eval echo ~${RUN_USER})"
REPO_DIR="${HOME_DIR}/HamBot_OLED"
VENV_DIR="${REPO_DIR}/.venv"
VENV_ACTIVATE="${VENV_DIR}/bin/activate"

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
  source '${VENV_ACTIVATE}' && \
  pip install --upgrade pip wheel setuptools && \
  cd '${REPO_DIR}'
  pip install .
"

echo "[3/4] Systemd one-shot boot service..."
SVC="/etc/systemd/system/hambot-oled-boot.service"
cat > "${SVC}" <<EOF
[Unit]
Description=HamBot OLED render once at boot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=${RUN_USER}
ExecStart=/bin/bash -lc 'source ${VENV_ACTIVATE} && hambot-oled --oneshot --iface wlan0'

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable hambot-oled-boot.service
systemctl start hambot-oled-boot.service || true

echo "[4/4] NetworkManager dispatcher hook..."
HOOK="/etc/NetworkManager/dispatcher.d/99-hambot-oled"
cat > "${HOOK}" <<EOF
#!/bin/sh
# OLED update on network state change
. ${VENV_ACTIVATE}
exec hambot-oled --oneshot --iface wlan0
EOF
chmod +x "${HOOK}"
systemctl restart NetworkManager || true

echo "Done. OLED repo at ${REPO_DIR}, venv at ${VENV_DIR}"
echo "Boot service: hambot-oled-boot.service"
echo "Dispatcher hook: ${HOOK}"
echo "Reboot may be required for group permissions if ${RUN_USER} wasn’t in 'i2c'."

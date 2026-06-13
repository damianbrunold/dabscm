#!/bin/sh
# Install and enable the systemd units for starter-login.
# Run as root (or with sudo) on the target host. Idempotent.
#
# Before running: edit the unit files for your User=, WorkingDirectory=,
# and the path to the scm binary in ExecStart.
set -eu

UNIT_DIR=/etc/systemd/system
SRC_DIR="$(cd "$(dirname "$0")/systemd" && pwd)"

for unit in starter-login.service \
            starter-login-health.service starter-login-health.timer \
            starter-login-restart.service starter-login-restart.timer; do
  cp "$SRC_DIR/$unit" "$UNIT_DIR/$unit"
done

systemctl daemon-reload
systemctl enable --now starter-login.service
systemctl enable --now starter-login-health.timer
systemctl enable --now starter-login-restart.timer

echo "Installed. Follow logs with: journalctl -u starter-login -f"

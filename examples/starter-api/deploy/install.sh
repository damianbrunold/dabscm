#!/bin/sh
# Install and enable the systemd units for starter-api.
# Run as root (or with sudo) on the target host. Idempotent.
#
# Before running: edit the unit files for your User=, WorkingDirectory=,
# and the path to the scm binary in ExecStart.
set -eu

UNIT_DIR=/etc/systemd/system
SRC_DIR="$(cd "$(dirname "$0")/systemd" && pwd)"

for unit in starter-api.service \
            starter-api-health.service starter-api-health.timer \
            starter-api-restart.service starter-api-restart.timer; do
  cp "$SRC_DIR/$unit" "$UNIT_DIR/$unit"
done

systemctl daemon-reload
systemctl enable --now starter-api.service
systemctl enable --now starter-api-health.timer
systemctl enable --now starter-api-restart.timer

echo "Installed. Follow logs with: journalctl -u starter-api -f"

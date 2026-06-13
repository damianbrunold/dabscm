#!/bin/sh
# Install and enable the systemd units for starter-admin.
# Run as root (or with sudo) on the target host. Idempotent.
#
# Before running: edit the unit files for your User=, WorkingDirectory=,
# and the path to the scm binary in ExecStart. Make sure PostgreSQL is
# reachable and config.scm is in place; the service runs migrations on start.
set -eu

UNIT_DIR=/etc/systemd/system
SRC_DIR="$(cd "$(dirname "$0")/systemd" && pwd)"

for unit in starter-admin.service \
            starter-admin-health.service starter-admin-health.timer \
            starter-admin-restart.service starter-admin-restart.timer; do
  cp "$SRC_DIR/$unit" "$UNIT_DIR/$unit"
done

systemctl daemon-reload
systemctl enable --now starter-admin.service
systemctl enable --now starter-admin-health.timer
systemctl enable --now starter-admin-restart.timer

echo "Installed. Follow logs with: journalctl -u starter-admin -f"

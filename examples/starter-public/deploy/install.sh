#!/bin/sh
# Install and enable the systemd units for starter-public.
# Run as root (or with sudo) on the target host. Idempotent.
#
# Before running: edit the unit files for your User=, WorkingDirectory=,
# and the path to the scm binary in ExecStart.
set -eu

UNIT_DIR=/etc/systemd/system
SRC_DIR="$(cd "$(dirname "$0")/systemd" && pwd)"

for unit in starter-public.service \
            starter-public-health.service starter-public-health.timer \
            starter-public-restart.service starter-public-restart.timer; do
  cp "$SRC_DIR/$unit" "$UNIT_DIR/$unit"
done

systemctl daemon-reload
systemctl enable --now starter-public.service
systemctl enable --now starter-public-health.timer
systemctl enable --now starter-public-restart.timer

echo "Installed. Follow logs with: journalctl -u starter-public -f"

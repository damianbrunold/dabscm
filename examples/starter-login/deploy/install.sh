#!/bin/sh
# Installs starter-login as a systemd service. Run as root on the target
# host from the app directory: sudo deploy/install.sh. Idempotent: rerun it
# to deploy a new version (the config in /etc is kept).
#
#   /opt/starter-login               the app (replaced on each install)
#   /etc/starter-login/config.scm    the config (created once, then yours)
#   /var/lib/starter-login            the user store (systemd StateDirectory)
#
# The service runs as the system user starter-login. Set SCM to the scm
# launcher if it is not /usr/local/bin/scm.
set -eu

APP=starter-login
SCM=${SCM:-/usr/local/bin/scm}
SRC="$(cd "$(dirname "$0")/.." && pwd)"

id -u "$APP" >/dev/null 2>&1 ||
  useradd --system --home-dir /nonexistent --no-create-home \
          --shell /usr/sbin/nologin "$APP"

# The app: code, static files and data, owned by root, readable by all.
rm -rf "/opt/$APP.new"
mkdir -p "/opt/$APP.new"
mkdir -p "/opt/$APP.new/data"
cp -r "$SRC/bin" "$SRC/src" "$SRC/static" "$SRC/deploy" \
      "$SRC/config.example.scm" "/opt/$APP.new/"
cp "$SRC/data/items.json" "/opt/$APP.new/data/"
rm -rf "/opt/$APP"
mv "/opt/$APP.new" "/opt/$APP"

# The config: created from config.example.scm on the first install only,
# with a fresh session secret, HTTPS-only cookies and the user store in
# /var/lib.
mkdir -p "/etc/$APP"
if [ ! -f "/etc/$APP/config.scm" ]; then
  "$SCM" "/opt/$APP/bin/init-config.scm" "/etc/$APP/config.scm"
  sed -i -e 's|^(define secure-cookies? #f)|(define secure-cookies? #t)|' \
         -e "s|^(define data-dir \"data\")|(define data-dir \"/var/lib/$APP\")|" \
         "/etc/$APP/config.scm"
fi
chown root:"$APP" "/etc/$APP/config.scm"
chmod 640 "/etc/$APP/config.scm"

for unit in "$APP.service" \
            "$APP-health.service" "$APP-health.timer" \
            "$APP-restart.service" "$APP-restart.timer"; do
  sed "s|/usr/local/bin/scm|$SCM|" "$SRC/deploy/systemd/$unit" \
    > "/etc/systemd/system/$unit"
done

systemctl daemon-reload
systemctl enable "$APP.service" "$APP-health.timer" "$APP-restart.timer"
systemctl restart "$APP.service"
systemctl start "$APP-health.timer" "$APP-restart.timer"

echo "Installed. Config: /etc/$APP/config.scm. Logs: journalctl -u $APP -f"
echo "Add a user: sudo -u $APP $SCM /opt/$APP/bin/user.scm --config /etc/$APP/config.scm add <name>"

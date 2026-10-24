# starter-login

A web app **with sign-in**. Everything in `starter-public` plus a login page,
sessions, and a profile page where the signed-in user can change their
password or sign out. Users are managed with a CLI; there is no public
sign-up.

Use it as a starting point for a small private app: an internal dashboard, a
single-team tool, anything behind a login but without per-user roles (for
roles and user management in the browser, see `starter-admin`).

## What it demonstrates

- **Password hashing** with `(scm crypto password)`: PBKDF2-SHA256, 600 000
  iterations, random salt, constant-time check. Signing in with an unknown
  username takes as long as with a wrong password, and older, weaker hashes
  are upgraded at the next sign-in (`src/app-auth.sld`).
- **Stateless sessions** with `(scm net http session)`: a signed cookie, no
  server-side store. The cookie is `HttpOnly`, `SameSite=Strict`, `Secure` in
  production, and scoped to the URL prefix.
- **Sessions that end when they should**: every request looks the user up
  again, and the cookie carries a stamp of the password hash, so deleting a
  user or changing a password ends their other sessions.
- **No CSRF tokens needed**: `SameSite=Strict` keeps the browser from sending
  the session cookie with a form another site submits.
- A **file-backed user store** (`users.scm` in `data-dir`, a plain Scheme
  datum) written atomically, by the CLI and the password-change handler.
- Failed sign-ins are slowed down and get one generic error message.
- From `starter-public`: the middleware stack (access log, strict CSP and
  other security headers, logged 500s), cache-busted static files,
  `light-dark()` theming without inline JavaScript, the URL prefix, the
  config created on the first run, and tests without a server.

## Layout

```
bin/server.scm        load the config, serve the app
bin/dev-server.scm    auto-reloading dev supervisor
bin/user.scm          add / passwd / delete / list users (CLI)
bin/init-config.scm   write a new config file (used by deploy/install.sh)
bin/gen-secret.scm    print a new session secret (for key rotation)
src/app-config.sld    config reading and first-run creation
src/app-site.sld      URL prefix: url, asset, cookie-path
src/app-users.sld     the user store
src/app-auth.sld      sign-in, sessions, password changes
src/app-views.sld     HTML rendering
src/app-web.sld       routes and middleware: make-app
config.example.scm    the config template, with every setting
data/items.json       sample data shown after sign-in
static/               CSS, theme scripts, favicon
tests/                test_pure_*.scm, run without a server
deploy/               systemd units, health probe, nginx example, install script
```

## Run

```sh
scm bin/user.scm add alice       # prompts for a password (at least 8 characters)
scm bin/server.scm               # http://127.0.0.1:8071
scm bin/dev-server.scm           # same, restarts when src/ or the config changes
```

The first run of either creates `config.scm` from `config.example.scm`, with
a fresh random `session-secret`. Then open the site, sign in as `alice`, and
try the Profile page.

## Test

```sh
for t in tests/test_*.scm; do scm "$t" || exit 1; done
```

## Adapt

- Add pages in `make-app` (`src/app-web.sld`) with `route!`, which adds the
  URL prefix. Wrap a handler in `signed-in` to require a session; it then
  receives the user entry as a third argument.
- Build links and redirects with `url` and asset links with `asset`.
- The user store is deliberately simple; swap `src/app-users.sld` for a
  database module when you outgrow a flat file (see `starter-admin`).
- To rotate the session secret, make `session-secret` a list with a new key
  (`scm bin/gen-secret.scm`) first; drop the old key once its sessions have
  expired.

## Deploy

The app binds loopback only; put a TLS-terminating reverse proxy in front
(`deploy/nginx.conf.example`). Then, on the server, from the app directory:

```sh
sudo deploy/install.sh               # SCM=/path/to/scm if not /usr/local/bin/scm
sudo -u starter-login /usr/local/bin/scm /opt/starter-login/bin/user.scm \
     --config /etc/starter-login/config.scm add alice
```

This copies the app to `/opt/starter-login` and creates
`/etc/starter-login/config.scm` on the first install, with a fresh secret,
`secure-cookies?` on, and the user store in `/var/lib/starter-login`. It adds
a `starter-login` system user and enables the service (`Restart=always`,
read-only file system except its state directory), a per-minute health probe
that restarts the app if `/healthz` fails twice, and a daily 04:00 restart.
Rerun it to deploy a new version; the config and users are kept.

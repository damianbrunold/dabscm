# starter-login

A web app **with authentication**. Everything in `starter-public` plus a login
page, sessions, and a profile page where the signed-in user can change their
password or log out. Users are created only with the CLI tools — there is no
public sign-up.

Use it as a starting point for a small private app: an internal dashboard, a
single-team tool, anything behind a login but without per-user roles (for roles
and self-service user management, see `starter-admin`).

## What it demonstrates

- **PBKDF2 password hashing** with a per-user random salt, stored as
  `pbkdf2$<iterations>$<salt>$<hash>`; verified in constant time
  (`src/app-auth.sld`).
- **Stateless sessions**: an HMAC-SHA256-signed cookie carrying
  `username|expiry` — no server-side session store. Cookies are `HttpOnly`,
  `SameSite=Strict`, and `Secure` in production.
- A **file-backed user store** (`data/users.scm`, a plain Scheme datum) written
  atomically and managed only by the CLI tools and the password-change handler.
- Login / logout / profile flows, with failed logins slowed down and given a
  generic error message.

## Layout

```
bin/server.scm        bootstrap: load config, build router, serve
bin/dev-server.scm    auto-reloading dev supervisor
bin/useradd.scm       add a user           (CLI)
bin/passwd.scm        reset a password     (CLI)
src/app-auth.sld      hashing + signed-cookie sessions
src/app-users.sld     the user store
src/app-views.sld     HTML rendering
src/app-routes.sld    router + static + server
config.example.scm    config (fallback when config.scm is absent)
data/users.scm        the credential store (created by the CLI)
data/items.json       sample data shown after login
static/               CSS + theme toggle
deploy/               systemd units, nginx example, install script
```

## Run

```sh
scm bin/useradd.scm alice          # prompts for a password (min 8 chars)
scm bin/server.scm                 # http://127.0.0.1:8082
scm bin/dev-server.scm             # same, auto-restart on file change
```

Then open the site, sign in as `alice`, and try the Profile page.

For production: copy `config.example.scm` to `config.scm`, generate a fresh
`cookie-secret`

```sh
scm -e '(import (scm crypto)) (display (base64-encode (random-bytes 32)))'
```

and set `secure-cookies?` to `#t` (requires HTTPS).

## Adapt

- Add protected routes by wrapping handlers with `require-auth` in
  `src/app-routes.sld`; the handler receives the username as a third argument.
- Replace the sample items page with your own content.
- The user store is deliberately simple; swap `src/app-users.sld` for a database
  module if you outgrow a flat file (see `starter-admin`).

## Deploy

App binds loopback only; front it with the TLS proxy in
`deploy/nginx.conf.example`, then:

```sh
sudo deploy/install.sh
```

Installs the service plus a per-minute `/healthz` probe (restarts on two
consecutive failures) and a daily 04:00 restart. Edit `User=`,
`WorkingDirectory=`, and the `ExecStart` scm path in the unit files first.

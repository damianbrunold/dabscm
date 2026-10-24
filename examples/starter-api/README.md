# starter-api

A **headless JSON/REST API** with bearer-token authentication: no HTML, no
cookies. Clients sign in to get a signed token and send it as
`Authorization: Bearer <token>` with every request. Includes a small CRUD
resource (`items`) stored in a Scheme data file.

Use it as a starting point for a backend behind a single-page app, a mobile
client, or service-to-service calls.

## What it demonstrates

- **Bearer tokens** with `(scm crypto token)`: signed, expiring, URL-safe,
  bound to the purpose `"api"`, no server-side store. Every request looks the
  user up again, and the token carries a stamp of the password hash, so
  deleting a user or changing a password revokes their tokens
  (`src/app-auth.sld`). `http-request-bearer-token` reads the header.
- **Password hashing** with `(scm crypto password)`, as in `starter-login`:
  a dummy check for unknown usernames and hash upgrades at sign-in.
- A **JSON request/response** style with one error envelope for everything,
  including unknown routes (404), wrong methods (405, with `Allow`) and
  internal errors (500, logged in full but answered generically)
  (`src/app-api.sld`).
- The middleware stack for an API: access log, `Cache-Control: no-store`,
  and security headers with `default-src 'none'`.
- **File-backed stores** with atomic, mutex-guarded writes
  (`src/app-users.sld`, `src/app-items.sld`); swap them for a database when
  you outgrow them.
- From `starter-public`: the URL prefix, the config created on the first
  run, and tests that call the app without a server.

## Endpoints

| Method | Path             | Auth | Body / result |
|--------|------------------|------|---------------|
| POST   | `/api/login`     | —    | `{username,password}` → `{token,token_type,expires_in}` |
| GET    | `/api/me`        | yes  | `{username}` |
| GET    | `/api/items`     | yes  | `[{id,name,count}, ...]` |
| POST   | `/api/items`     | yes  | `{name,count}` → `201 {id,name,count}` |
| GET    | `/api/items/:id` | yes  | `{id,name,count}` or `404` |
| DELETE | `/api/items/:id` | yes  | `204` or `404` |
| GET    | `/healthz`       | —    | `ok` |

Errors are always `{ "error": { "code": "...", "message": "..." } }`.

## Layout

```
bin/server.scm        load the config, serve the API
bin/dev-server.scm    auto-reloading dev supervisor
bin/user.scm          add / passwd / delete / list API users (CLI)
bin/init-config.scm   write a new config file (used by deploy/install.sh)
bin/gen-secret.scm    print a new token secret (for key rotation)
src/app-config.sld    config reading and first-run creation
src/app-users.sld     the user store
src/app-items.sld     the items store
src/app-auth.sld      sign-in and bearer tokens
src/app-api.sld       routes, JSON, error envelope, middleware: make-app
config.example.scm    the config template, with every setting
data/items.scm        sample items
tests/                test_pure_*.scm, run without a server
deploy/               systemd units, health probe, nginx example, install script
```

## Run

```sh
scm bin/user.scm add alice       # prompts for a password (at least 8 characters)
scm bin/server.scm               # http://127.0.0.1:8073
scm bin/dev-server.scm           # same, restarts when src/ or the config changes
```

The first run of either creates `config.scm` from `config.example.scm`, with
a fresh random `token-secret`. Try it:

```sh
TOKEN=$(curl -s -d '{"username":"alice","password":"<pw>"}' \
        http://127.0.0.1:8073/api/login | sed 's/.*"token":"\([^"]*\)".*/\1/')

curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8073/api/items
curl -s -H "Authorization: Bearer $TOKEN" -d '{"name":"Cogs","count":7}' \
     http://127.0.0.1:8073/api/items
```

## Test

```sh
for t in tests/test_*.scm; do scm "$t" || exit 1; done
```

## Adapt

- Add resources with `route!` in `make-app` (`src/app-api.sld`) and storage
  functions in a new `src/app-*.sld` module. Wrap a handler in `with-token`
  to require a token; it then receives the user entry as a third argument.
- Swap the file stores for a database module (see `starter-admin`) when a
  flat file no longer fits.
- The API sends no CORS headers: a browser app should be served from the
  same origin (e.g. behind the same reverse proxy). Add an
  `Access-Control-Allow-Origin` wrapper only for origins you trust.
- To rotate the token secret, make `token-secret` a list with a new key
  (`scm bin/gen-secret.scm`) first; drop the old key once its tokens have
  expired.

## Deploy

The API binds loopback only; put a TLS-terminating reverse proxy in front
(`deploy/nginx.conf.example`): clients send passwords and tokens, which must
not travel in the clear. Then, on the server, from the app directory:

```sh
sudo deploy/install.sh               # SCM=/path/to/scm if not /usr/local/bin/scm
sudo -u starter-api /usr/local/bin/scm /opt/starter-api/bin/user.scm \
     --config /etc/starter-api/config.scm add alice
```

This copies the app to `/opt/starter-api` and creates
`/etc/starter-api/config.scm` on the first install, with a fresh secret and
the data in `/var/lib/starter-api`. It adds a `starter-api` system user and
enables the service (`Restart=always`, read-only file system except its
state directory), a per-minute health probe that restarts the API if
`/healthz` fails twice, and a daily 04:00 restart. Rerun it to deploy a new
version; the config and data are kept.

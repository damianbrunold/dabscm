# starter-api

A **headless JSON/REST API** with bearer-token authentication — no HTML, no
sessions. Clients log in to get a signed token and send it as
`Authorization: Bearer <token>` on every request. Includes a small CRUD
resource (`items`) persisted to a Scheme data file.

Use it as a starting point for a backend behind a single-page app, a mobile
client, or service-to-service calls.

## What it demonstrates

- **Bearer tokens**: HMAC-SHA256-signed, stateless, with an expiry — verified in
  constant time (`src/app-auth.sld`).
- **PBKDF2 password hashing** for the user store.
- A clean **JSON request/response** style with a single error envelope and
  correct status codes (`src/app-api.sld`).
- A **file-backed store** with atomic, mutex-guarded writes
  (`src/app-store.sld`) — swap it for a database when you outgrow it.

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
bin/server.scm        bootstrap: load config, serve
bin/dev-server.scm    auto-reloading dev supervisor
bin/useradd.scm       add/update an API user (CLI)
src/app-auth.sld      hashing + bearer tokens
src/app-store.sld     user + item data files (atomic writes)
src/app-api.sld       routes, JSON, error envelope, server
config.example.scm    config (fallback when config.scm is absent)
data/users.scm        credential store (created by the CLI)
data/items.scm        the sample resource
deploy/               systemd units, nginx example, install script
```

## Run

```sh
scm bin/useradd.scm alice          # prompts for a password (min 8 chars)
scm bin/server.scm                 # http://127.0.0.1:8084
scm bin/dev-server.scm             # same, auto-restart on file change
```

Try it:

```sh
TOKEN=$(curl -s -d '{"username":"alice","password":"<pw>"}' \
        http://127.0.0.1:8084/api/login | sed 's/.*"token":"\([^"]*\)".*/\1/')

curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8084/api/items
curl -s -H "Authorization: Bearer $TOKEN" -d '{"name":"Cogs","count":7}' \
     http://127.0.0.1:8084/api/items
```

For production: copy `config.example.scm` to `config.scm`, generate a fresh
`token-secret`

```sh
scm -e '(import (scm crypto)) (display (base64-encode (random-bytes 32)))'
```

and serve over HTTPS (clients send credentials and tokens in the clear otherwise).

## Adapt

- Add resources by adding routes in `src/app-api.sld` and storage functions in
  `src/app-store.sld`.
- Protect a route by wrapping its handler with `with-auth`; the handler receives
  the authenticated subject (username) as a third argument.
- Swap `src/app-store.sld` for a database module (see `starter-admin`) when a
  flat file no longer fits.

## Deploy

App binds loopback only; front it with `deploy/nginx.conf.example`, then:

```sh
sudo deploy/install.sh
```

Installs the service plus a per-minute `/healthz` probe (restart after two
failures) and a daily 04:00 restart. Edit `User=`, `WorkingDirectory=`, and the
`ExecStart` scm path in the unit files first.

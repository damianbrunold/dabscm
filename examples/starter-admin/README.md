# starter-admin

A web app with **user and role management**, backed by **PostgreSQL** with
SQL migrations. Everything in `starter-login` plus: an admin console to add and
delete users, create roles, and assign/unassign roles — and a seeded first
admin. The privileged role is named `admin`.

Use it as a starting point for a multi-user application that needs accounts and
authorization and a real database.

## What it demonstrates

- **PostgreSQL access** through a connection pool with thin, fully
  parameterized query helpers — no string-built SQL (`src/app-db.sld`,
  `src/app-users.sld`).
- **Forward-only SQL migrations** applied automatically at startup and tracked
  in `schema_migrations` (`migrations/0001_init.sql`).
- **PBKDF2 password hashing** and **HMAC-signed session cookies** carrying the
  user id (`src/app-auth.sld`).
- **Role-based authorization**: `require-admin` gates the console; users can
  hold any number of roles (`users` / `roles` / `user_roles`).
- A self-service **profile** page (change password, log out), as in
  `starter-login`.

## Layout

```
bin/server.scm        load config, run migrations, serve
bin/dev-server.scm    auto-reloading dev supervisor
bin/seed-admin.scm    idempotent first-admin + "admin" role seed
src/app-db.sld        pool + query helpers + migration runner
src/app-auth.sld      hashing + signed-cookie sessions (carry user id)
src/app-users.sld     user / role / user-role queries + auth
src/app-views.sld     HTML rendering (login, home, profile, admin console)
src/app-routes.sld    router + handlers + static + server
migrations/           NNNN_*.sql, applied in order at startup
config.example.scm    config template (copy to config.scm)
static/               CSS + theme toggle
deploy/               systemd units (After=postgresql), nginx, install script
```

## Setup

1. Create a database and a login role for the app:

   ```sql
   CREATE ROLE starter_admin LOGIN PASSWORD 'choose-a-password';
   CREATE DATABASE starter_admin OWNER starter_admin;
   ```

2. Copy `config.example.scm` to `config.scm` and set the DB credentials, a
   fresh `cookie-secret`

   ```sh
   scm -e '(import (scm crypto)) (display (base64-encode (random-bytes 32)))'
   ```

   and the `admin-username` / `admin-password` to seed.

3. Seed the first admin (also runs migrations):

   ```sh
   scm bin/seed-admin.scm
   ```

## Run

```sh
scm bin/server.scm             # http://127.0.0.1:8083
scm bin/dev-server.scm         # same, auto-restart on file change
```

Sign in as the seeded admin, open the **Admin** console, and add users/roles.
Change the seeded admin password from the **Profile** page after first login.

## Adapt

- Add tables by dropping a new `migrations/NNNN_*.sql` file — it is applied on
  next start.
- Add queries in `src/app-users.sld` (or a new `src/app-*.sld` module) using the
  `db-rows` / `db-exec` helpers; always pass values as `$1, $2, ...` params.
- Gate routes with `require-auth` or `require-admin` in `src/app-routes.sld`.
  To use a different privileged role name, change `admin-role` there.

## Deploy

App binds loopback only; front it with `deploy/nginx.conf.example`, then:

```sh
sudo deploy/install.sh
```

The service unit orders after `postgresql.service` and runs migrations on every
start. It is paired with a per-minute `/healthz` probe (restart after two
failures) and a daily 04:00 restart. Edit `User=`, `WorkingDirectory=`, and the
`ExecStart` scm path in the unit files first.

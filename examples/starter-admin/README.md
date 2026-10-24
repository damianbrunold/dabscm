# starter-admin

A web app with **user and role management**, backed by **PostgreSQL** with
SQL migrations. Everything in `starter-login` plus an admin console to add and
delete users, create roles, and assign or remove them, and a script that
seeds the first admin. The privileged role is named `admin`.

Use it as a starting point for a multi-user application that needs accounts,
authorization and a real database.

## What it demonstrates

- **PostgreSQL access** through a connection pool with thin, fully
  parameterized query helpers: no string-built SQL (`src/app-db.sld`,
  `src/app-users.sld`).
- **Transactions** with `with-db-transaction` (on top of
  `with-pg-transaction`): creating a user together with the admin role, and
  seeding the first admin, happen completely or not at all.
- **Forward-only SQL migrations**, applied at every start and tracked in
  `schema_migrations` (`migrations/0001_init.sql`).
- **Role-based authorization**: `admin-only` gates the console; users can hold
  any number of roles (`users` / `roles` / `user_roles`). An admin cannot
  delete their own account or remove their own admin role.
- From `starter-login`: `(scm crypto password)` hashes with upgrades at
  sign-in and a dummy check for unknown usernames, signed-cookie sessions
  that end when the user is deleted or changes the password, and the profile
  page.
- From `starter-public`: the middleware stack (access log, strict CSP,
  logged 500s), cache-busted static files, `light-dark()` theming without
  inline JavaScript, the URL prefix, the config created on the first run,
  and tests that call the app without a server.

## Layout

```
bin/server.scm        load the config, run migrations, serve
bin/dev-server.scm    auto-reloading dev supervisor
bin/seed-admin.scm    create the first admin (prompts for a password)
bin/init-config.scm   write a new config file (used by deploy/install.sh)
bin/gen-secret.scm    print a new session secret (for key rotation)
src/app-config.sld    config reading and first-run creation
src/app-site.sld      URL prefix: url, asset, cookie-path
src/app-db.sld        pool, query helpers, transactions, migrations
src/app-users.sld     user / role / user-role queries
src/app-auth.sld      sign-in, sessions, password changes
src/app-views.sld     HTML rendering (login, home, profile, admin console)
src/app-web.sld       routes and middleware: make-app
migrations/           NNNN_*.sql, applied in order at startup
config.example.scm    the config template, with every setting
static/               CSS, theme scripts, favicon
tests/                test_pure_*.scm (no database), test_live_web.scm
deploy/               systemd units, health probe, nginx example, install script
```

## Setup

1. Create a database and a login role for the app:

   ```sql
   CREATE ROLE starter_admin LOGIN PASSWORD 'choose-a-password';
   CREATE DATABASE starter_admin OWNER starter_admin;
   ```

2. Create `config.scm`, with a fresh `session-secret`, and set
   `db-password` (and the other `db-` settings if needed) in it:

   ```sh
   scm bin/init-config.scm config.scm
   ```

3. Seed the first admin. This also applies the migrations:

   ```sh
   scm bin/seed-admin.scm admin       # prompts for a password
   ```

## Run

```sh
scm bin/server.scm             # http://127.0.0.1:8072
scm bin/dev-server.scm         # same, restarts when src/, migrations/ or the config change
```

Sign in as the seeded admin, open the **Admin** console, and add users and
roles.

## Test

```sh
for t in tests/test_pure_*.scm; do scm "$t" || exit 1; done
```

`tests/test_live_web.scm` runs the full flows against a real database. It
drops the app's tables first, so it only runs against a database whose name
ends in `_test`:

```sh
createdb -O starter_admin starter_admin_test
sed 's/(define db-name "starter_admin")/(define db-name "starter_admin_test")/' \
    config.scm > tests/test-config.scm
STARTER_ADMIN_TEST_CONFIG=tests/test-config.scm scm tests/test_live_web.scm
```

## Adapt

- Add tables with a new `migrations/NNNN_*.sql` file; it is applied at the
  next start.
- Add queries in `src/app-users.sld` (or a new `src/app-*.sld` module) with
  `db-rows` / `db-row` / `db-scalar` / `db-exec`; always pass values as
  `$1, $2, ...` parameters. Wrap statements that belong together in
  `with-db-transaction` and use its handle for each of them.
- Gate routes with `signed-in` or `admin-only` in `src/app-web.sld`. To use
  a different privileged role name, change `admin-role` there.

## Deploy

The app binds loopback only; put a TLS-terminating reverse proxy in front
(`deploy/nginx.conf.example`). Then, on the server, from the app directory:

```sh
sudo deploy/install.sh               # SCM=/path/to/scm if not /usr/local/bin/scm
```

This copies the app to `/opt/starter-admin` and adds a `starter-admin`
system user and the systemd units. The first install also creates
`/etc/starter-admin/config.scm` (fresh secret, `secure-cookies?` on) and
stops there: set the database settings, seed the admin and start the units
as it tells you. Later installs restart the service, which applies new
migrations. The service orders after `postgresql.service`; a per-minute
probe restarts it if `/healthz` fails twice, and a timer restarts it daily
at 04:00.

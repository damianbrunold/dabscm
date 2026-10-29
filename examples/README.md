# Examples

Sample programs and starter applications for dabscm.

## Starter applications

Self-contained web-app templates to **copy and adapt**. They share no code
with each other; the shared plumbing comes from dabscm libraries. They grow
in complexity:

| Directory | Tier | Storage | Port | Start here if you need… |
|-----------|------|---------|------|--------------------------|
| [`starter-public`](starter-public/) | Public, no auth | JSON file | 8070 | A read-only public page rendered from data |
| [`starter-login`](starter-login/) | Sign-in + profile | Scheme data file | 8071 | A private app behind a login, no roles |
| [`starter-admin`](starter-admin/) | User & role management | PostgreSQL + migrations | 8072 | Accounts, roles, and a real database |
| [`starter-api`](starter-api/) | Headless JSON/REST + bearer tokens | Scheme data files | 8073 | A backend for an SPA, mobile, or services |

Each builds on the one above it, so read them in order to see how a small app
grows into a database-backed, multi-user one.

Common to all of them:

- **Libraries, not copies**: `(scm net http static)` for static files with
  cache-busting URLs, `(scm net http middleware)` for the access log,
  security headers and logged 500s, `(scm crypto password)` for password
  hashes, `(scm net http session)` / `(scm crypto token)` for signed
  sessions and bearer tokens.
- **Security defaults**: a strict Content-Security-Policy (no inline
  scripts or styles), `HttpOnly` + `SameSite=Strict` + `Secure` cookies,
  PBKDF2 at 600 000 iterations with upgrades at sign-in, sessions that end
  when the user is deleted or changes the password, parameterized SQL, and
  static serving that refuses traversal and dot-files.
- **Layout**: `bin/server.scm` reads the config and serves `make-app` from
  `src/`; `make-app` returns the request handler, so `tests/` call it
  directly, with no server running.
- **Config** as a list of `(define name value)` forms, read as data. The
  first run creates `config.scm` from `config.example.scm` with a fresh
  secret. `url-prefix` mounts the app under a path.
- **Theming**: light/dark via `light-dark()` CSS tokens, following the OS
  unless the user pins a theme with the toggle.
- **Development**: `bin/dev-server.scm` restarts the app when a source file
  changes.
- **Deployment**: `deploy/install.sh` installs to `/opt/<app>`,
  `/etc/<app>/config.scm` and `/var/lib/<app>` under a system user, with a
  hardened systemd service, a health probe that reads the port from the
  config, and a daily restart.

To run one, see its own `README.md`, e.g.:

```sh
cd starter-public && scm bin/server.scm
```

To start a new application from a starter, let `scm new-app` copy and rename
it (see `(scm scaffold)`); it works from an installed dabscm, without this
repository:

```sh
scm new-app starter-admin ~/projects/ledger
```

The starters are built into dabscm as data: after changing one, run
`./builder.sh update-scheme-files.scm` to regenerate `(scm scaffold starters)`.

## Single-file snippets

Small standalone examples of individual libraries:

- [`test-webapp-hello-world.scm`](test-webapp-hello-world.scm) — the minimal
  HTTP server with routing.
- [`test-postgres.scm`](test-postgres.scm) — connecting to PostgreSQL, querying,
  and cursor streaming.
- [`zip-directory.scm`](zip-directory.scm) — zipping a directory with `(scm zip)`.

Run any of them with `scm <file>.scm`.

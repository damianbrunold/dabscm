# Examples

Sample programs and starter applications for dabscm.

## Starter applications

Self-contained web-app templates to **copy and adapt**. Each has no shared code,
its own `README.md`, light/dark theming, a `bin/dev-server.scm` hot-reload
supervisor, and a `deploy/` directory with systemd units (self-healing restart,
`/healthz` probe, daily restart). They grow in complexity:

| Directory | Tier | Storage | Start here if you need… |
|-----------|------|---------|--------------------------|
| [`starter-public`](starter-public/) | Public, no auth | JSON file | A read-only public page rendered from data |
| [`starter-login`](starter-login/) | Single sign-in + profile | Scheme data file | A private app behind a login, no roles |
| [`starter-admin`](starter-admin/) | User & role management | PostgreSQL + migrations | Accounts, roles, and a real database |
| [`starter-api`](starter-api/) | Headless JSON/REST + bearer tokens | Scheme data file | A backend for an SPA, mobile, or services |

Each builds on the one above it, so read them in order to see how a small app
grows into a database-backed, multi-user one.

Common to all of them: PBKDF2 password hashing (random salt, constant-time
compare), HMAC-signed cookies/tokens, hardened cookies (`HttpOnly`,
`SameSite=Strict`, `Secure`), parameterized SQL, and path-traversal-guarded
static serving.

To run one, see its own `README.md`, e.g.:

```sh
cd starter-public && scm main.scm
```

## Single-file snippets

Small standalone examples of individual libraries:

- [`test-webapp-hello-world.scm`](test-webapp-hello-world.scm) — the minimal
  HTTP server with routing.
- [`test-postgres.scm`](test-postgres.scm) — connecting to PostgreSQL, querying,
  and cursor streaming.
- [`zip-directory.scm`](zip-directory.scm) — zipping a directory with `(scm zip)`.

Run any of them with `scm <file>.scm`.

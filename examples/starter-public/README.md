# starter-public

A minimal **public** web app (no authentication): one page that renders a
table from a JSON file, with light/dark theming.

Use it as a starting point for any read-only public page: a status board, a
small catalogue, a landing page backed by data.

## What it demonstrates

- Routing, and serving static files with cache-busting URLs
  (`(scm net http route)`, `(scm net http static)`): `asset` emits
  `/static/css/app.css?v=<mtime>`, which browsers cache for a year; an edited
  file gets a new URL without a restart.
- The middleware stack from `(scm net http middleware)`: one access-log line
  per request, security headers with a strict Content-Security-Policy, and
  errors logged in full but shown to the visitor only as a generic 500 page.
- Safe, auto-escaping HTML rendering (`(scm html builder)`): data can never
  inject markup.
- No inline JavaScript or style attributes, as the CSP requires: all of it is
  under `static/`.
- Light/dark mode that follows the OS setting, with a toggle whose choice is
  remembered (`static/js/theme-init.js` applies it before the first paint, so
  there is no flash). The CSS defines each colour once, with `light-dark()`.
- Mounting under a URL prefix (`url-prefix` in the config).
- A config file read as data, created on the first run.
- Tests that call the app's handler directly, with no server running.
- A `/healthz` endpoint for the health probe.

## Layout

```
bin/server.scm        load the config, serve the app
bin/dev-server.scm    auto-reloading dev supervisor
bin/init-config.scm   write a new config file (used by deploy/install.sh)
src/app-config.sld    config reading and first-run creation
src/app-web.sld       routes, pages, middleware: make-app
config.example.scm    the config template, with every setting
data/items.json       the data shown in the table
static/css/app.css    theme tokens + layout
static/js/            theme-init.js (in <head>) and theme-toggle.js
tests/                test_pure_*.scm, run without a server
deploy/               systemd units, health probe, nginx example, install script
```

## Run

```sh
scm bin/server.scm               # http://127.0.0.1:8070
scm bin/dev-server.scm           # same, restarts when src/ or the config changes
```

The first run creates `config.scm` from `config.example.scm`; edit it to
change the host, port or URL prefix. `scm bin/server.scm path/to/config.scm`
uses another config file.

## Test

```sh
for t in tests/test_*.scm; do scm "$t" || exit 1; done
```

## Adapt

- Replace `data/items.json` and `items-table` in `src/app-web.sld` with your
  own data and markup.
- Add routes in `make-app` with `router-add!`; wrap paths in
  `(string-append prefix ...)` and build links with `url`, so the app keeps
  working under a prefix.
- Add assets under `static/` and link them with `(asset "path")`.

## Deploy

The app binds loopback only; put a TLS-terminating reverse proxy in front
(`deploy/nginx.conf.example`). Then, on the server, from the app directory:

```sh
sudo deploy/install.sh               # SCM=/path/to/scm if not /usr/local/bin/scm
```

This copies the app to `/opt/starter-public`, creates
`/etc/starter-public/config.scm` on the first install, adds a
`starter-public` system user, and enables three units: the service
(`Restart=always`, read-only file system), a per-minute health probe that
restarts the app if `/healthz` fails twice (it reads the port from the
config), and a daily 04:00 restart. Rerun it to deploy a new version; the
config is kept.

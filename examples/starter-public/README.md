# starter-public

A minimal **public** web app (no authentication) — a single page that renders
a table from a JSON file, with light/dark theming.

Use it as a starting point for any read-only public page: a status board, a
small catalogue, a landing page backed by data.

## What it demonstrates

- Routing and serving static CSS/JS (`(scm net http route)`).
- Reading and parsing JSON (`(scm json simple)`).
- Safe, auto-escaping HTML rendering (`(scm html builder)`) — user data can
  never inject markup.
- OS-aware light/dark mode: the theme defaults to the browser/OS setting and,
  once the user clicks the toggle, is remembered in `localStorage`. The choice
  is applied before first paint, so there is no flash.
- A `/healthz` endpoint for health checks.

## Layout

```
main.scm             everything: config load, routes, rendering
config.example.scm   http-host / http-port (fallback if config.scm absent)
data/items.json      the data shown in the table
static/app.css       theme tokens + layout
static/app.js        the theme toggle
bin/dev-server.scm   auto-reloading dev supervisor
deploy/              systemd units, nginx example, install script
```

## Run

```sh
scm main.scm                 # http://127.0.0.1:8080
scm bin/dev-server.scm       # same, auto-restart on file change
```

To change host/port, copy `config.example.scm` to `config.scm` and edit it
(the app prefers `config.scm` when present).

## Adapt

- Replace `data/items.json` and the `items-table` procedure with your own
  data and markup.
- Add routes with `router-add!`.
- Add assets under `static/` — they are served from `/static/...`.

## Deploy

The app binds loopback only; put a TLS-terminating reverse proxy in front
(`deploy/nginx.conf.example`). Then install the systemd units:

```sh
sudo deploy/install.sh
```

This enables three units: the service (`Restart=always`), a per-minute
health probe that restarts the app if `/healthz` fails twice, and a daily
04:00 restart. Edit `User=`, `WorkingDirectory=`, and the `ExecStart` scm
path in `deploy/systemd/*.service` for your host first.

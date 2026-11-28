---
title: "(scm scaffold): starting a web application with scm new-app"
part: libraries
order: 1031
libraries: (scm scaffold) (scm scaffold starters)
summary: The four starter applications and what each adds, creating one with scm new-app or new-app, how names are replaced, the layout of a generated app, running, testing, developing with auto-reload, configuration and deployment.
---
# (scm scaffold): starting a web application with scm new-app

The [web tutorials](scm-web-app.md) show the parts. A real application
also needs a configuration file, tests, an auto-reloading development
server, a systemd service and a reverse proxy configuration. dabscm comes
with four *starters*, complete small applications that have all of that,
and `scm new-app` copies one under the name of your application.

```scheme
(import (scheme base) (scheme file) (scheme write) (scm fs) (scm scaffold))
```

## The starters

```scheme
(starter-names)                             ;; => ("starter-public" "starter-login" "starter-admin" "starter-api")
```

| starter | what it is | data |
|---|---|---|
| `starter-public` | a public page rendered from data, no login | a JSON file |
| `starter-login` | a private app behind a login, with a profile page | a Scheme data file |
| `starter-admin` | users, roles and an admin area | PostgreSQL with migrations |
| `starter-api` | a JSON API with bearer tokens, for a single-page or mobile app | Scheme data files |

Each one builds on the one before. All of them use the libraries of the
web tutorials: the middleware stack, a strict Content-Security-Policy
(no inline scripts), signed sessions, password hashes that are upgraded
at sign-in, static files with cache-busting URLs, light and dark themes.

## Creating an application

From the command line, name the starter and the new directory; the last
part of the directory is the application's name:

```sh
scm new-app starter-login ~/projects/tea-notes
cd ~/projects/tea-notes
scm bin/server.scm              # http://127.0.0.1:8071
```

The same from Scheme, here into a temporary directory, with two small
helpers to look at the result:

```scheme
(define (string-prefix-of? prefix s)
  (and (<= (string-length prefix) (string-length s))
       (string=? prefix (substring s 0 (string-length prefix)))))

(define (filter-files keep? fs)
  (cond ((null? fs) '()) ((keep? (car fs)) (cons (car fs) (filter-files keep? (cdr fs))))
        (else (filter-files keep? (cdr fs)))))
```

```scheme
(define work (mktempdir '(prefix . "scaffold")))
(define app-dir (join-path work "tea-shop"))

(define files (new-app "starter-public" app-dir))
(length files)                              ;; => 23
(filter-files (lambda (f) (string-prefix-of? "deploy/systemd/" f)) files)
;; => ("deploy/systemd/tea-shop-health.service" "deploy/systemd/tea-shop-health.timer" "deploy/systemd/tea-shop-restart.service" "deploy/systemd/tea-shop-restart.timer" "deploy/systemd/tea-shop.service")
```

The starter's name is replaced everywhere, in file names and in file
contents, in each of its spellings:

```scheme
(app-name-variants "tea-shop")              ;; => ("tea-shop" "tea_shop" "Tea Shop" "TEA_SHOP")

(define (first-line path)
  (call-with-input-file (join-path app-dir path) read-line))
(first-line "README.md")                    ;; => "# tea-shop"
(first-line "config.example.scm")           ;; => ";; tea-shop configuration: a list of (define name value) forms, read"
```

So the service is `tea-shop.service`, the database user in
`starter-admin` `tea_shop`, the page title "Tea Shop" and the environment
variables `TEA_SHOP_…`. A third argument gives a name different from the
directory's. `new-app` refuses to overwrite:

```scheme
(new-app "starter-public" app-dir)          ;; => error
(new-app "starter-public" (join-path work "x") "Tea Shop") ;; => error
(new-app "starter-blog" (join-path work "blog")) ;; => error
(rm work 'recursive)
```

The name must be in kebab case (`tea-shop`), and the starter one of
`starter-names`. Files the starter's `.gitignore` lists, such as a local
`config.scm`, are not copied, and shell scripts come out executable.

## The layout

```text
bin/server.scm        reads the configuration, serves the app
bin/dev-server.scm    the same, restarted when a source file changes
bin/init-config.scm   writes a configuration with a fresh secret
src/app-config.sld    reads the configuration
src/app-web.sld       routes, pages, middleware: make-app
config.example.scm    every setting, documented
static/               CSS, scripts, icons
tests/                test_pure_*.scm, run without a server
deploy/               install script, systemd units, nginx example, health probe
```

`make-app` in `src/app-web.sld` returns the request handler. The server
passes it to `serve-forever`; the tests call it directly with requests
made by `make-http-request`, as the [server tutorial](scm-http-server.md)
does, so they need no server and no network.

## Running, testing, developing

```sh
scm bin/server.scm                                # uses config.scm, created on the first run
scm bin/dev-server.scm                            # restarts on changes to src/ or the config
for t in tests/test_*.scm; do scm "$t" || exit 1; done
```

The configuration is a list of `(define name value)` forms, read as data
rather than run:

```scheme no-test
(define http-host "127.0.0.1")
(define http-port 8070)
(define url-prefix "")          ; e.g. "/shop" to mount the app under a path
```

## Deploying

`deploy/install.sh` installs the application on a Linux server: the code
in `/opt/<app>`, the configuration in `/etc/<app>/config.scm`, data in
`/var/lib/<app>`, a system user, a hardened systemd service, a health
probe and a daily restart. `deploy/nginx.conf.example` puts nginx in
front for HTTPS. `(scm deb webapp)` packages the same layout as a
Debian package.

## Where next

- [HTTP servers](scm-http-server.md), [web applications](scm-web-app.md),
  [databases](scm-database.md), [crypto](scm-crypto.md).
- The starters' own README files explain each one in detail.
- Reference: `(scm scaffold)`.

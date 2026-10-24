# Web-app libraries for the starters (design draft)

## Status

Implemented in 1.16.0 (2d310f6) as designed; all open questions below
were answered with the recommended option. The splg apps may adopt the new
token format (a forced re-login is acceptable). Step 1 of the starter
rework (server error leak, status texts, router 405) shipped as 1.15.2
(c5bf9be). Deviation: the router drops empty path segments before the
static handler sees them, so `/static/a//b.css` serves `a/b.css`.

Step 2 done (673b68b, aea85cc, cab5d14): the four starters run on the
libraries, on ports 8070–8073 (8090 is taken by the splg website preview).
Found on the way and fixed in 1.16.1: HEAD requests (the router falls back
to the GET route and lists HEAD in Allow; the servers send no body),
parameterize on current-input/output/error-port, and Java read-password
losing piped input after the first line.

Step 3 done in splg (362d3dd4 licenses, f51420b6 + ae962cee portal,
bfac47fd + 1367b541 platform): password, token, session, static and
middleware libraries in use. Tokens: purpose "web" for the session
cookie, "api" for CLI bearer tokens, plus a passphrase stamp so a
passphrase change ends other sessions; everyone logs in once more after
the deploy. Licenses and platform have no inline scripts or on* handlers
left and send script-src 'self' (platform keeps 'unsafe-inline' for its
style attributes); portal keeps its own error wrapper (logs only the
condition kind, since messages may quote case input).

## Why

The same plumbing exists in seven copies: the four `examples/starter-*`
apps and the three splg apps (platform, licenses, portal). Every copy
re-implements password hashing, signed cookies, a static file handler with
its own content-type table, an access-log/error wrapper and (in portal)
security headers. The copies have drifted: different hash formats,
different token encodings, some with cache-busting and some without, and
only portal sets a CSP. These parts are generic and security-sensitive,
so they belong in dabscm, tested once. The starters then show the
libraries in use instead of carrying their own copies.

## Scope

Five new libraries and four small additions to existing ones. All of it is
plain Scheme on top of existing primitives (`(scm crypto)`, cookies, the
router), so there is no host code and no Java/C# divergence.

| Library | File | Replaces in the apps |
|---|---|---|
| `(scm crypto password)` | `scm-crypto-password.sld` | `hash-password` / `verify-password` / Werkzeug parsers |
| `(scm crypto token)` | `scm-crypto-token.sld` | `sign` / `verify` / `issue-token` / `verify-token` |
| `(scm net http session)` | `scm-net-http-session.sld` | session cookie set/clear/read helpers |
| `(scm net http static)` | `scm-net-http-static.sld` | static handler, mime table, `static-url` |
| `(scm net http middleware)` | `scm-net-http-middleware.sld` | `with-access-log`, error wrapper, security headers |

Additions: `router->handler` (route), `http-request-bearer-token`
(request), `http-request-form` (forms), `with-pg-transaction` (postgres).

What stays in the apps and starters (app conventions, not library
material): the URL prefix and the `(url ...)` helper, config loading, page
layout and the theme toggle, `js-script` with `data-*` attributes, flash
messages, nav permissions, i18n, RPC envelopes, background jobs.

## `(scm crypto password)`

```scheme
(password-hash plain)              ; -> "pbkdf2$600000$<salt-b64>$<hash-b64>"
(password-verify plain stored)     ; -> #t / #f, constant-time, never raises
(password-needs-rehash? stored)    ; -> #t if not native pbkdf2 at current cost
password-pbkdf2-iterations         ; parameter, default 600000
```

- **New hashes:** PBKDF2-HMAC-SHA256 with 600 000 iterations (the OWASP
  2023 figure), a 16-byte random salt and a 32-byte key. This is the same
  `pbkdf2$iter$salt$hash` string the starters, platform and licenses
  already store, so every existing hash still verifies. Measured on the
  JVM: about 150–190 ms per hash; 200 000 iterations (today's starters) is
  about 60 ms.
- **`password-verify` accepts:** native `pbkdf2$…`; Werkzeug
  `pbkdf2:sha256[:iter]$salt$hexhash`; Werkzeug
  `scrypt:n:r:p$salt$hexhash`. Werkzeug forms are verify-only; they let an
  app keep users imported from a Flask app (as platform and licenses do).
- **Unknown users:** `(password-verify plain #f)` hashes a dummy value at
  the current cost and returns #f. A login handler calls it with `#f` for
  an unknown username, so known and unknown users take the same time.
- **Upgrades on login:** `password-needs-rehash?` is #t for Werkzeug
  forms and for native hashes with fewer iterations than the parameter.
  After a successful login the app stores `(password-hash plain)`, which
  upgrades old hashes.
- **Tests:** the parameter lets them run at 1 000 iterations.

Rejected: scrypt as the default. Werkzeug's N=2^15 is below the OWASP
minimum (N=2^17 = 128 MiB per hash), and 128 MiB per concurrent login is
too much for a small JVM service.

## `(scm crypto token)`

```scheme
(token-sign secret datum max-age . opts)   ; -> string
(token-verify secret token . opts)         ; -> datum or #f, never raises
;; opts: ((purpose . "session"))
```

- **Datum:** any value that round-trips through `write`/`read` (strings,
  numbers, symbols, booleans, lists, alists), e.g.
  `((uid . 42) (name . "alice"))`. `max-age` is in seconds; `#f` means the
  token never expires.
- **Format:** `<b64url(write (exp . datum))>.<b64url(hmac)>` with
  `hmac = HMAC-SHA256(key, purpose "\n" payload-bytes)`. URL-safe base64
  without padding, so tokens fit in cookies, headers and URLs unchanged.
- **Safety:** the MAC is checked in constant time before the payload is
  `read`, so attacker bytes never reach the reader. The expiry is checked
  after that. Anything malformed returns #f.
- **purpose** binds a token to one use: a "session" token cannot be
  replayed as a "reset" or "api" token signed with the same key.
- **Secrets:** a bytevector or a base64 string. A list of secrets enables
  key rotation: `token-sign` uses the first, `token-verify` tries each.

This format differs from platform/licenses (standard base64 + hex MAC, no
purpose). Those apps keep their own until someone decides to migrate them;
switching logs everyone out once (and breaks issued CLI tokens).

## `(scm net http session)`

Signed-cookie sessions: no server-side store.

```scheme
(make-session-config cookie-name secret max-age . opts)
;; opts: ((path . "/") (secure? . #t) (purpose . "session"))
(session-ref cfg req)            ; -> datum or #f
(session-set-cookie cfg datum)   ; -> ("Set-Cookie" . "...")
(session-clear-cookie cfg)       ; -> ("Set-Cookie" . "...") expiring it
```

- Cookies use `format-set-cookie` and so are always `HttpOnly;
  SameSite=Strict`. `Secure` is on unless `(secure? . #f)`, for local HTTP
  only.
- `path` is how an app mounted under a URL prefix scopes its cookie
  (`"/licenses/"`).
- No CSRF tokens: `SameSite=Strict` already blocks cross-site form posts
  in every current browser, and the splg apps rely on the same. The
  starters' READMEs will say so.
- Revocation (a deleted or locked user) stays the app's job: look the
  user up on each request, as starter-admin and the splg apps do.

## `(scm net http static)`

```scheme
(mime-type path)                       ; -> "text/css; charset=utf-8", ...
(file-response path . opts)            ; -> 200 with mime type, or 404
(make-static-handler dir . opts)       ; -> router handler using the "*" param
(make-static-url dir base-url)         ; -> (lambda (rel) "/static/app.css?v=<mtime>")
;; opts: ((cache-control . "public, max-age=300"))
```

- **`mime-type` covers:** html css js mjs json map svg png jpg jpeg gif
  webp avif ico txt csv xml pdf zip woff woff2 wasm. Text types carry
  `charset=utf-8`; anything else is `application/octet-stream`.
- **Path rules:** the `*` capture arrives raw, so the handler
  percent-decodes it per segment, then rejects (404) empty, `.`, `..`,
  dot-files (`.env`, `.git`), and segments containing `\` or NUL. A
  directory is 404, not 403, so the response doesn't reveal what exists.
- **Caching:** a request with a `v=` query parameter (from
  `make-static-url`) gets `Cache-Control: public, max-age=31536000,
  immutable`; anything else gets the `cache-control` option. Every file
  response also has `ETag: W/"<mtime>-<size>"`, and a matching
  `If-None-Match` returns 304.
- Every response includes `X-Content-Type-Options: nosniff`.
- **`make-static-url`** stats the file on each call: an edited file gets
  a new URL with no restart. A missing file gets no `?v=`.
  `base-url` includes the app's prefix, e.g. `(make-static-url dir
  "/licenses/static")`.
- **`file-response`** is the same file serving for download routes that
  pick their own path (platform's report and job downloads).

## `(scm net http middleware)`

Server-level wrappers: each takes and returns a `(lambda (req) resp)`.
Combine them with `router->handler`:

```scheme
(serve-forever port
  (with-access-log
    (with-security-headers
      (with-error-handler (router->handler router) render-500)))
  0 host)
```

```scheme
(with-error-handler handler . render)    ; render: (lambda (req) resp), optional
(with-access-log handler . opts)         ; opts: ((log-url . proc))
(with-response-headers handler headers)  ; adds headers the response lacks
(with-security-headers handler . csp)    ; = with-response-headers + security-headers
security-headers                         ; the default alist
```

- **`with-error-handler`** catches any raise, and any return value that
  is not an http-response. It logs `ERROR [http] METHOD PATH raised:
  <message> <irritants>` through `(scm log)` (so `log-port` redirects it)
  and returns `(render req)`, or a plain-text 500 by default. The client
  never sees the error text. Since 1.15.2 the server itself also does the
  latter; the wrapper adds the app's own error page and the `(scm log)`
  format.
- **`with-access-log`** writes one `log-access` line per request (method,
  path, status, ms). By default it logs the **path without the query
  string**, because query strings carry search terms, filter values and
  sometimes tokens. `log-url` replaces that, e.g. portal's redaction of
  job ids, or `identity` to log full URLs. If the inner handler raises,
  it logs 500 and re-raises.
- **`security-headers`:**
  - `Content-Security-Policy: default-src 'self'; script-src 'self';
    style-src 'self'; img-src 'self' data:; connect-src 'self';
    form-action 'self'; frame-ancestors 'none'; base-uri 'none';
    object-src 'none'`
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy: same-origin`
  - `X-Frame-Options: DENY`

  This rules out inline scripts and inline styles. The starters will
  comply: theme JS moves to static files. An app that renders `style=`
  attributes, like platform, passes its own CSP adding `'unsafe-inline'`
  to `style-src`.
- **`with-response-headers`** never overwrites a header the handler set
  (case-insensitive), so one route can relax the CSP.

## Small additions to existing libraries

- `(scm net http route)`: `(router->handler router)` →
  `(lambda (req) (router-dispatch router req))`.
- `(scm net http request)`: `(http-request-bearer-token req)` → the token
  from `Authorization: Bearer …` (scheme case-insensitive, trimmed) or #f.
- `(scm net http forms)`: `(http-request-form req)` → the
  `application/x-www-form-urlencoded` body as an alist, `'()` when absent.
  Every app has its own `form-of` / `form-body` for this.
- `(scm database postgres)`: `(with-pg-transaction conn proc)` → BEGIN,
  `(proc conn)`, COMMIT; on a raise: ROLLBACK, then re-raise. Licenses'
  `with-db-tx` adds pool checkout on top of this.

## Tests

One `scm-tests/tests/tests_scm_<lib>.scm` per new library, run by both
hosts with no network:

- **password:** round trip at 1 000 iterations; the Werkzeug fixtures from
  `licenses/tests/test_pure_auth.scm`; malformed strings → #f; `#f` stored
  → #f; `needs-rehash?` cases.
- **token:** round trip; flipped payload or MAC byte → #f; expired → #f;
  wrong purpose → #f; rotation; junk input → #f.
- **session:** set-cookie attributes; a `Cookie` header fed back through
  `session-ref`; secure/no-secure; path.
- **static:** a temp dir served through `router-dispatch`; traversal
  (`..`, `%2e%2e`, `%2f`, backslash, dotfile) → 404; mime types; `v=` →
  immutable; ETag → 304.
- **middleware:** `log-port` parameterized to a string port; error text
  logged but absent from the body; query string dropped by default;
  existing headers kept.

## Rollout

1. Implement the libraries with docstrings, tests and regenerated docs;
   bump to **1.16.0** (new libraries).
2. Rework the starters on top of them: public → login → admin → api,
   each with `tests/` and the other review items (secret placeholder and
   first-run config, light-dark CSS, no inline JS, url-prefix, logging,
   ports 8070–8073, deploy units).
3. Optional, separate decision: move platform, licenses and portal onto
   the libraries. The static, middleware and password parts are drop-in;
   the token format change logs users out once.

## Open questions

1. Default password hash: PBKDF2-SHA256 at 600 000 iterations
   (recommended above) or scrypt?
2. Access log: path only by default, or full URL?
3. Default CSP without `'unsafe-inline'` for styles?
4. Static handler: refuse dot-files by default?

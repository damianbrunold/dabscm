# `(scm net http middleware)`

## Overview

`(scm net http middleware)` wraps a server handler — a procedure from
request to response — with the parts every web app needs: an error handler
that logs failures and answers with an error page, an access log, and
security headers. Each wrapper takes a handler and returns one, so they
nest around `(router->handler router)`.

`security-headers` is the default header alist added by
`with-security-headers`: a same-origin Content-Security-Policy (no inline
scripts or styles, no framing), `X-Content-Type-Options: nosniff`,
`Referrer-Policy: same-origin` and `X-Frame-Options: DENY`.

## Common uses

```scheme
(import (scm net http server) (scm net http route) (scm net http response)
        (scm net http middleware))

(define (error-page req)
  (html-response "<h1>Something went wrong</h1>"))

(serve-forever 8080
  (with-access-log
    (with-security-headers
      (with-error-handler (router->handler router) error-page)))
  0 "127.0.0.1")
```

Put `with-error-handler` innermost, so the access log records the 500 it
produces. Log lines go through `(scm log)`; the access log leaves out query
strings unless given a `log-url` option.


## Exports

### `security-headers`

*(no documentation)*

### `with-access-log`

```
Syntax: (with-access-log handler [opts])
Library: (scm net http middleware)
Description: Wraps handler so every request writes one log-access line:
  method, URL, status and duration in ms. By default the URL is logged
  without its query string, which can carry search terms or tokens; the
  option (log-url . proc) maps the request URL to the logged text instead
  (e.g. to redact ids, or values to log full URLs). If handler raises, the
  request is logged as 500 and the error is re-raised, so put
  with-error-handler inside this wrapper.
Example:
  (with-access-log handler `((log-url . ,(lambda (u) u))))
```

### `with-error-handler`

```
Syntax: (with-error-handler handler [render])
Library: (scm net http middleware)
Description: Wraps handler so that an error it raises, or a return value
  that is not an http-response, is logged with log-error (module "http":
  method, path without query string, message and irritants) and answered
  with (render req), or a plain-text 500 Internal Server Error when render
  is omitted or itself fails. The client never sees the error text.
Example:
  (with-error-handler (router->handler router)
    (lambda (req) (html-response "<h1>Something went wrong</h1>")))
```

### `with-response-headers`

```
Syntax: (with-response-headers handler headers)
Library: (scm net http middleware)
Description: Wraps handler so each response also carries the (name .
  value) pairs in headers, except those the response already sets
  (compared case-insensitively). A handler can therefore override a
  default, e.g. relax the Content-Security-Policy for one route.
Example:
  (with-response-headers handler '(("Cache-Control" . "no-store")))
```

### `with-security-headers`

```
Syntax: (with-security-headers handler [csp])
Library: (scm net http middleware)
Description: Wraps handler with with-response-headers and
  security-headers: a same-origin Content-Security-Policy (no inline
  scripts or styles, no framing), X-Content-Type-Options: nosniff,
  Referrer-Policy: same-origin and X-Frame-Options: DENY. csp, a string,
  replaces the default policy, e.g. to allow inline style attributes.
Example:
  (with-security-headers handler
    "default-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'")
```


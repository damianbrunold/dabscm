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

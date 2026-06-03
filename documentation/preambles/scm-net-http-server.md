## Overview

`(scm net http server)` is an HTTP server. A handler is a procedure that takes a
request and returns a response (see `(scm net http request)` and
`(scm net http response)`). `serve-forever` is the simplest entry point; for
routing several paths, layer `(scm net http route)` on top.

## Common uses

Serve a single handler:

```scheme
(import (scm net http server) (scm net http response))

(serve-forever 8080 (lambda (req) (http-ok "hello")))

;; with an explicit thread-pool size and bind address:
(serve-forever 8080 handler 16 "127.0.0.1")
```

Serve static files from a directory:

```scheme
(serve-directory ".")
```

`server-stop`, `server-wait`, and `server-install-shutdown-hook` manage a running
server's lifecycle.

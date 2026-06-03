# `(scm net http server)`

HTTP server — listen, accept, and serve requests

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


## Exports

### `serve-directory`

```
Syntax: (serve-directory [path [port]])
Library: (scm net http server)
Description: Starts an HTTP server that serves files from the given directory
  (default ".") on the given port (default 8080) and blocks indefinitely.
  Directory requests serve index.html if present, otherwise an HTML listing.
  Content-Type is inferred from the file extension. Path traversal via .. is
  rejected with 403. This procedure never returns normally.
Example:
  (serve-directory)
  (serve-directory ".")
  (serve-directory "." 8080)
```

### `serve-forever`

```
Syntax: (serve-forever port handler [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http server)
Description: Starts an HTTP server on port with the given handler and blocks
  indefinitely. handler receives each http-request and must return an http-response.
  Optional extra arguments forward to tcp-http-serve and configure: maximum
  concurrent worker threads (default 32; excess connections rejected with 503),
  bind host (default "0.0.0.0"), per-connection read timeout in ms (default 30000),
  maximum request body size in bytes (default 4194304; oversize rejected with 413),
  and graceful-stop drain period in ms (default 10000). 0 or omitted means default.
  Returns only if the server is stopped from another thread via server-stop.
Example:
  (serve-forever 8080 (lambda (req) (http-ok "hello")))
  (serve-forever 8080 handler 16 "127.0.0.1")
```

### `server-install-shutdown-hook`

```
Syntax: (server-install-shutdown-hook server [graceful-ms])
Library: (scm net http server)
Description: Installs an OS-level handler (JVM shutdown hook, fired on SIGINT and SIGTERM) that stops the given server with the configured graceful drain. Suitable for use under systemd, where SIGTERM should drain in-flight requests before the process exits. Returns #t.
Example:
  (define s (tcp-http-serve 8080 handler))
  (server-install-shutdown-hook s 5000)
  (server-wait s)
```

### `server-stop`

```
Syntax: (server-stop server [graceful-ms])
Library: (scm net http server)
Description: Stops a running HTTP server. Stops accepting new connections, then waits up to graceful-ms for in-flight requests to complete (default: the server's configured graceful-stop-ms). Returns #t once the listener has been closed.
Example:
  (server-stop s)
  (server-stop s 5000)
```

### `server-wait`

```
Syntax: (server-wait server)
Library: (scm net http server)
Description: Blocks the calling thread until the given HTTP server has stopped. Returns when the server's accept loop has exited, e.g. after server-stop.
Example:
  (server-wait s)
```

### `tcp-http-serve`

```
Syntax: (tcp-http-serve port handler [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http server)
Description: Starts an HTTP server on the given port. handler is called with each incoming http-request and must return an http-response. Returns a server object. Use server-stop to shut it down. Notes: Transfer-Encoding: chunked is not supported (501); requests larger than max-body-bytes are rejected with 413; per-connection read-timeout-ms guards against slow clients; max-threads bounds concurrency (excess connections are rejected with 503). 0 or omitted parameters use defaults: max-threads=32, host="0.0.0.0", read-timeout-ms=30000, max-body-bytes=4194304, graceful-stop-ms=10000.
Example:
  (define s (tcp-http-serve 8080 (lambda (req) (http-ok "Hello"))))
  (define s (tcp-http-serve 8080 handler 16 "127.0.0.1"))
```


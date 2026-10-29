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

## Large bodies

Request bodies arrive with `Content-Length` or `Transfer-Encoding: chunked`.
`max-body-bytes` (default 4 MB) caps them (413 above it); a body larger than
`spool-threshold-bytes` (default 1 MB) is written to a temporary file instead
of being kept in memory. `http-request-body-file` gives its path; move the
file to keep it, as it is deleted after the response:

```scheme
;; uploads up to 2 GB, spooled to disk above 1 MB
(tcp-http-serve 8080 handler 0 "127.0.0.1" 0 (* 2 1024 1024 1024))

(define (save-upload req dest)
  (let ((f (http-request-body-file req)))
    (if f
        (move-file f dest)
        (let ((p (open-binary-output-file dest)))
          (write-bytevector (http-request-body-bytes req) p)
          (close-port p)))))
```

Responses need not be in memory either: `make-http-file-response` sends (a
part of) a file from disk, and `file-response` in `(scm net http static)`
answers byte-range requests with it, so audio and video can seek.
`make-http-stream-response` calls a procedure with a port to the client,
for server-sent events or large generated downloads:

```scheme
(make-http-stream-response 200 '(("Content-Type" . "text/event-stream"))
  (lambda (port)
    (let loop ((i 0))
      (write-bytevector (string->utf8 (string-append "data: " (number->string i) "\n\n")) port)
      (flush-output-port port)
      (thread-sleep! 1)
      (loop (+ i 1)))))   ; ends with an error once the client is gone
```

A route can also turn its connection into a WebSocket: it returns
`http-websocket-upgrade` with a procedure, the server checks the upgrade
request and switches protocols, and the procedure talks over the socket
with `(scm net websocket)` until it returns:

```scheme
(http-websocket-upgrade
  (lambda (ws)
    (let loop ((m (ws-receive ws)))
      (when m (ws-send ws m) (loop (ws-receive ws))))))
```

Streamed responses and WebSockets hold a server thread while they run, so
`max-threads` bounds how many can be open at once.

# `(scm net websocket)`

WebSocket client and server — also in HTTP servers via http-websocket-upgrade

## Overview

`(scm net websocket)` speaks WebSocket (RFC 6455) on both sides of a
connection. A server gets its connections from an HTTP route that returns
`http-websocket-upgrade` (see `(scm net http response)`), or from a raw TCP
socket with `ws-accept`; a client opens one with `ws-connect`. Then
`ws-send`, `ws-receive` and `ws-close` exchange messages.

The protocol details are handled for you: pings are answered with pongs,
fragmented messages are joined, a close frame is answered, client frames are
masked (and a server refuses unmasked ones), and a message over 16 MB ends
the connection. One thread receives; any number of threads may send at the
same time, also while the receiver waits.

## Common uses

In an HTTP server, a route upgrades its connection:

```scheme
(import (scm net http server) (scm net http response) (scm net websocket))

(define (handler req)
  (http-websocket-upgrade
    (lambda (ws)
      (ws-send ws "welcome")
      (let loop ()
        (let ((m (ws-receive ws 30000)))   ; wait at most 30 s
          (cond ((not m) 'closed)            ; the client went away
                ((eq? m 'timeout)            ; quiet: still there?
                 (ws-send ws "ping")
                 (loop))
                (else (ws-send ws m) (loop))))))))

(serve-forever 8080 handler)
```

The handler runs on the server thread of that connection, which stays taken
until the handler returns: give `tcp-http-serve` enough `max-threads` for
the connections you expect. A client:

```scheme
(define ws (ws-connect "localhost" 8080 "/socket"))
(ws-receive ws)     ;; => "welcome"
(ws-send ws "hello")
(ws-receive ws)     ;; => "hello"
(ws-close ws)
```

`ws-receive` returns a string for a text message, a bytevector for a binary
one, `#f` once the connection has closed, and with a timeout the symbol
`timeout` when nothing arrived in time. `ws?` tests whether a value is a
WebSocket.


## Exports

### `ws-accept`

```
Syntax: (ws-accept socket)
Library: (scm net websocket)
Description: Performs a WebSocket server-side handshake (RFC 6455) on the given TCP socket. Returns a WebSocket object.
  In an HTTP server, use http-websocket-upgrade instead.
Example:
  (define ws (ws-accept sock))
```

### `ws-close`

```
Syntax: (ws-close ws)
Library: (scm net websocket)
Description: Sends a close frame (status 1000) and closes the WebSocket connection; a thread
  waiting in ws-receive gets #f.
Example:
  (ws-close ws)
```

### `ws-connect`

```
Syntax: (ws-connect host port path)
Library: (scm net websocket)
Description: Connects to a WebSocket server (RFC 6455 client handshake). Returns a WebSocket object.
Example:
  (define ws (ws-connect "localhost" 8080 "/ws"))
```

### `ws-receive`

```
Syntax: (ws-receive ws [timeout-ms])
Library: (scm net websocket)
Description: Waits for the next message from the WebSocket and returns it: a string for a text
  message, a bytevector for a binary one (fragmented messages are joined), or #f when the
  connection has closed (by the peer, an error, or a message over 16 MB). Pings are answered
  with pongs on the way. With timeout-ms, returns the symbol timeout if no message began
  within that time (the connection stays usable).
Example:
  (ws-receive ws) => "Hello!"
  (ws-receive ws 30000) => timeout
```

### `ws-send`

```
Syntax: (ws-send ws message)
Library: (scm net websocket)
Description: Sends a message over the WebSocket. message may be a string (text frame) or a bytevector
  (binary frame). Safe to call from several threads, also while another thread waits in ws-receive.
  Signals an error when the connection is closed.
Example:
  (ws-send ws "Hello!")
```

### `ws?`

```
Syntax: (ws? x)
Library: (scm net websocket)
Description: Returns #t if x is a WebSocket object.
Example:
  (ws? ws) => #t
```


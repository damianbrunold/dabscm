## Overview

`(scm net websocket)` provides WebSocket support for both sides of a connection:
upgrade an accepted server connection with `ws-accept`, or open a client
connection with `ws-connect`, then exchange messages with `ws-send` /
`ws-receive`.

## Common uses

Client:

```scheme
(import (scm net websocket))

(define ws (ws-connect "ws://example.com/socket"))
(ws-send ws "hello")
(ws-receive ws)     ;; => the next message
(ws-close ws)
```

On the server side, `ws-accept` upgrades an accepted TCP connection to a
WebSocket, after which the same `ws-send` / `ws-receive` / `ws-close` apply.
`ws?` tests whether a value is a WebSocket.

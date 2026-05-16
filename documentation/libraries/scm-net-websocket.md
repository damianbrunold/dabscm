# `(scm net websocket)`

WebSocket client and server support

## Exports

### `ws-accept`

```
Syntax: (ws-accept socket)
Library: (scm net websocket)
Description: Performs a WebSocket server-side handshake (RFC 6455) on the given TCP socket. Returns a WebSocket object.
Example:
  (define ws (ws-accept sock))
```

### `ws-close`

```
Syntax: (ws-close ws)
Library: (scm net websocket)
Description: Sends a close frame and closes the WebSocket connection.
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
Syntax: (ws-receive ws)
Library: (scm net websocket)
Description: Receives a message from the WebSocket. Returns a string for text frames, a bytevector for binary frames, or #f on close/error.
Example:
  (ws-receive ws) => "Hello!"
```

### `ws-send`

```
Syntax: (ws-send ws message)
Library: (scm net websocket)
Description: Sends a message over the WebSocket. message may be a string (text frame) or a bytevector (binary frame).
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


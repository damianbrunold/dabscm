# `(scm net sockets)`

TCP socket operations — listen, accept, connect

## Overview

`(scm net sockets)` provides TCP networking: listen for and accept connections,
connect out, and read/write through ordinary Scheme ports (textual or binary).
The `with-…` / `call-with-…` forms manage socket and listener lifetimes for you.

## Common uses

Connect to a server and write to it:

```scheme
(import (scm net sockets))

(with-tcp-connection "localhost" 8080
  (lambda (sock)
    (display "hi" (socket-output-port sock))))
```

Listen and accept:

```scheme
(call-with-tcp-server 8080
  (lambda (listener)
    (let ((sock (tcp-accept listener)))
      ;; talk to the client via (socket-input-port sock) / (socket-output-port sock)
      (socket-close sock))))
```

Binary ports are available via `socket-binary-input-port` /
`socket-binary-output-port` for non-text protocols.


## Exports

### `call-with-tcp-server`

```
Syntax: (call-with-tcp-server port proc)
Library: (scm net sockets)
Description: Creates a TCP listener on port, calls proc with it, then stops the
  listener even if proc raises an error. Returns the result of proc.
Example:
  (call-with-tcp-server 8080
    (lambda (listener) (tcp-accept listener)))
```

### `socket-binary-input-port`

```
Syntax: (socket-binary-input-port socket)
Library: (scm net sockets)
Description: Returns the binary input port for reading raw bytes from the socket.
Example:
  (read-u8 (socket-binary-input-port sock))
```

### `socket-binary-output-port`

```
Syntax: (socket-binary-output-port socket)
Library: (scm net sockets)
Description: Returns the binary output port for writing raw bytes to the socket.
Example:
  (write-u8 65 (socket-binary-output-port sock))
```

### `socket-close`

```
Syntax: (socket-close socket-or-listener)
Library: (scm net sockets)
Description: Closes a socket or TCP listener.
Example:
  (socket-close sock)
```

### `socket-input-port`

```
Syntax: (socket-input-port socket)
Library: (scm net sockets)
Description: Returns the textual input port for reading from the socket.
Example:
  (read-line (socket-input-port sock))
```

### `socket-output-port`

```
Syntax: (socket-output-port socket)
Library: (scm net sockets)
Description: Returns the textual output port for writing to the socket.
Example:
  (display "hello" (socket-output-port sock))
```

### `socket-read-line`

```
Syntax: (socket-read-line socket)
Library: (scm net sockets)
Description: Reads one line directly from the socket's raw underlying stream, byte
  by byte with no buffering, decoding the bytes as UTF-8. A trailing CR is dropped
  and the line is terminated by LF; the returned string does not include the line
  ending. Returns an end-of-file object if the stream is closed before any byte is
  read. Because it never buffers ahead, it is safe for line-oriented protocols (such
  as SMTP) where a buffered reader would consume bytes past a protocol boundary like
  a STARTTLS upgrade.
Example:
  (socket-read-line sock) => "220 mail.example.com ESMTP"
```

### `socket-starttls!`

```
Syntax: (socket-starttls! socket host)
Syntax: (socket-starttls! socket host verify?)
Library: (scm net sockets)
Description: Upgrades an already-connected plaintext socket to TLS in place (the
  STARTTLS mechanism of SMTP/IMAP/etc.). Wraps the socket's raw underlying stream in
  a TLS stream and rebuilds the socket's input and output ports over it, so subsequent
  socket-input-port / socket-output-port use the encrypted channel. host is the server
  name used for certificate validation. When verify? is omitted or true, the server
  certificate chain and host name are validated; #f disables validation (insecure).
  The pre-upgrade dialogue must be read with socket-read-line so no plaintext past the
  upgrade boundary is buffered. Returns the socket.
Example:
  (socket-starttls! sock "smtp.example.com")
```

### `socket?`

```
Syntax: (socket? x)
Library: (scm net sockets)
Description: Returns #t if x is a TCP socket.
Example:
  (socket? (tcp-connect "localhost" 8080)) => #t
```

### `tcp-accept`

```
Syntax: (tcp-accept listener)
Library: (scm net sockets)
Description: Accepts an incoming TCP connection on the listener. Blocks until a connection arrives.
Example:
  (define sock (tcp-accept listener))
```

### `tcp-connect`

```
Syntax: (tcp-connect host port)
Library: (scm net sockets)
Description: Connects to a TCP server at the given host and port. Returns a socket.
Example:
  (define sock (tcp-connect "localhost" 8080))
```

### `tcp-listen`

```
Syntax: (tcp-listen port)
Library: (scm net sockets)
Description: Creates a TCP listener on the given port and starts listening for connections.
Example:
  (define l (tcp-listen 8080))
```

### `tcp-listener?`

```
Syntax: (tcp-listener? x)
Library: (scm net sockets)
Description: Returns #t if x is a TCP listener.
Example:
  (tcp-listener? (tcp-listen 8080)) => #t
```

### `tls-connect`

```
Syntax: (tls-connect host port)
Syntax: (tls-connect host port verify?)
Library: (scm net sockets)
Description: Connects to a TCP server at host:port and immediately performs a TLS
  handshake (implicit TLS, as used by SMTPS on port 465 or HTTPS). Returns a socket
  whose ports read and write encrypted data transparently. When verify? is omitted or
  true, the server certificate chain and host name are validated; passing #f disables
  validation (insecure, for testing only).
Example:
  (define sock (tls-connect "smtp.example.com" 465))
```

### `with-tcp-connection`

```
Syntax: (with-tcp-connection host port proc)
Library: (scm net sockets)
Description: Connects to host:port, calls proc with the socket, then closes the
  socket even if proc raises an error. Returns the result of proc.
Example:
  (with-tcp-connection "localhost" 8080
    (lambda (sock) (display "hi" (socket-output-port sock))))
```


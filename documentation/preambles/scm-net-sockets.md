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

## Overview

`(scm net http response)` is the HTTP response value type plus a set of
constructors for common status codes. Server handlers return one of these; the
client returns one to you. There are ready-made helpers for typical responses
(`http-ok`, `http-not-found`, …) and content shortcuts (`html-response`,
`json-response`).

## Common uses

Build responses in a handler:

```scheme
(import (scm net http response))

(http-ok "Hello, world!")          ;; 200 with a text body
(http-not-found)                   ;; 404
(json-response '(("ok" . #t)))     ;; JSON body + Content-Type
(http-redirect "/login")           ;; 302 to a new location
```

Inspect a response (e.g. one returned by the client):

```scheme
(http-response-status resp)              ;; => 200
(http-response-header resp "Content-Type")
(http-response-body resp)
```

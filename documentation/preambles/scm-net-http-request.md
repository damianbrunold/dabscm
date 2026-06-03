## Overview

`(scm net http request)` is the HTTP request value type shared by the client and
server libraries: a method, URL, headers, and body, with constructors and
accessors. The client uses it to describe outgoing requests; a server handler
receives one as its argument.

## Common uses

```scheme
(import (scm net http request))

(define req (make-http-request "GET" "http://example.com/" '() #f))

(http-request-method req)        ;; => "GET"
(http-request-url req)           ;; => "http://example.com/"
(http-request-header req "Host") ;; => "example.com"  (case-insensitive lookup)
```

Use `http-request-body` for the body as text and `http-request-body-bytes` for
the raw bytevector (binary uploads).

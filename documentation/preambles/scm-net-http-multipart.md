## Overview

`(scm net http multipart)` parses `multipart/form-data` request bodies (RFC 7578)
— the format browsers use for file uploads. Each parsed part is an alist with the
keys `name`, `filename`, `content-type`, and `body`; `part-ref` reads a field
from a part.

## Common uses

Find the boundary from the `Content-Type` header, then parse the body:

```scheme
(import (scm net http multipart))

(multipart-boundary "multipart/form-data; boundary=abc123")  ;; => "abc123"

(define parts
  (parse-multipart body (multipart-boundary content-type)))

(part-ref (car parts) 'name)        ;; => "avatar"
(part-ref (car parts) 'filename)    ;; => "photo.png"
```

Use `parse-multipart` when each character of the body is one byte (text), and
`parse-multipart-bytes` when the body is a bytevector — the latter keeps binary
attachments (images, PDFs) intact.

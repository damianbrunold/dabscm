# `(scm net http multipart)`

multipart/form-data parsing (RFC 7578)

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


## Exports

### `multipart-boundary`

```
Syntax: (multipart-boundary content-type)
Library: (scm net http multipart)
Description: Extracts the boundary= parameter from a Content-Type header
  value. Returns the boundary string (without surrounding quotes), or #f
  if content-type is not multipart/form-data or has no boundary.
Example:
  (multipart-boundary "multipart/form-data; boundary=abc123") => "abc123"
  (multipart-boundary "text/plain") => #f
```

### `parse-multipart`

```
Syntax: (parse-multipart body boundary)
Library: (scm net http multipart)
Description: Parses a multipart/form-data body (passed as a byte-per-char
  string) with the given boundary string. Returns a list of part alists,
  each with keys 'name, 'filename (or #f), 'content-type (or #f), 'body.
  Use parse-multipart-bytes when handling binary uploads.
Example:
  (parse-multipart body (multipart-boundary (http-request-header req "Content-Type")))
```

### `parse-multipart-bytes`

```
Syntax: (parse-multipart-bytes body boundary)
Library: (scm net http multipart)
Description: Like parse-multipart but operates on a bytevector body. Part
  bodies in the result are bytevectors (subcopies of the input), so binary
  uploads (images, PDFs, ...) round-trip exactly.
Example:
  (parse-multipart-bytes (http-request-body-bytes req)
                         (multipart-boundary
                           (http-request-header req "Content-Type")))
```

### `part-ref`

```
Syntax: (part-ref part key)
Library: (scm net http multipart)
Description: Returns the value of key ('name, 'filename, 'content-type, 'body)
  in a part alist, or #f if missing.
Example:
  (part-ref p 'name) => "avatar"
  (part-ref p 'filename) => "face.png"
```


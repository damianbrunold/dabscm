# `(scm net http multipart)`

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


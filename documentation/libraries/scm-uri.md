# `(scm uri)`

URI percent-encoding and decoding

## Exports

### `percent-decode`

```
Syntax: (percent-decode s [plus-as-space?])
Library: (scm uri)
Description: Decodes percent-escaped UTF-8 in s. When plus-as-space? is
  true (the default), '+' is treated as space — appropriate for
  application/x-www-form-urlencoded bodies and query strings. Pass #f to
  preserve '+' literally (e.g. for URL path segments).
Example:
  (percent-decode "a%20b") => "a b"
  (percent-decode "a+b") => "a b"
  (percent-decode "a+b" #f) => "a+b"
```

### `percent-encode`

```
Syntax: (percent-encode s)
Library: (scm uri)
Description: Encodes string s as UTF-8 and percent-escapes every byte
  outside the RFC 3986 unreserved set (A-Z a-z 0-9 - _ . ~). Suitable for
  building query values and path segments.
Example:
  (percent-encode "a b/c") => "a%20b%2Fc"
  (percent-encode "hello") => "hello"
```


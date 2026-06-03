# `(scm uri)`

URI percent-encoding and decoding

## Overview

`(scm uri)` provides URI percent-encoding and decoding — the `%XX` escaping used
in query strings, form bodies, and path segments.

## Usage

```scheme
(import (scm uri))

(percent-encode "a b/c")   ;; => "a%20b%2Fc"
(percent-decode "a%20b")   ;; => "a b"
```

`percent-encode` leaves the RFC 3986 unreserved set (`A–Z a–z 0–9 - _ . ~`)
untouched and UTF-8-encodes everything else before escaping. `percent-decode`
reverses it, and by default also treats `+` as a space (the form-urlencoded
convention); pass `#f` as a second argument to keep `+` literal.


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


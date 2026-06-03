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

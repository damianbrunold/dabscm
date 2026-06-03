# `(scm net http cookies)`

HTTP cookie header parsing and Set-Cookie formatting

## Overview

`(scm net http cookies)` parses incoming `Cookie` headers and formats outgoing
`Set-Cookie` headers — the small pieces a web app needs for cookie handling.

## Common uses

Parse a request's `Cookie` header into an alist and look a value up:

```scheme
(import (scm net http cookies))

(parse-cookie-header "sid=abc; pref=dark")
;; => (("sid" . "abc") ("pref" . "dark"))

(cookie-ref '(("sid" . "abc")) "sid")   ;; => "abc"
```

Format a `Set-Cookie` value (name, value, max-age in seconds, path):

```scheme
(format-set-cookie "sid" "abc" 3600 "/")
```

Cookie values are not percent-decoded — many are opaque tokens, so the caller
decides whether decoding is appropriate.


## Exports

### `cookie-ref`

```
Syntax: (cookie-ref cookies name)
Library: (scm net http cookies)
Description: Returns the value of the named cookie in cookies (an alist from
  parse-cookie-header), or #f if missing.
Example:
  (cookie-ref '(("sid" . "abc")) "sid") => "abc"
```

### `format-set-cookie`

```
Syntax: (format-set-cookie name value max-age path [flag ...])
Library: (scm net http cookies)
Description: Builds a Set-Cookie header value. HttpOnly and SameSite=Strict
  are always emitted. The Secure attribute is added unless 'no-secure' is
  present in flags; this default is right for production but should be
  disabled for local HTTP development. max-age may be #f to omit the
  Max-Age attribute (session cookie).
Example:
  (format-set-cookie "sid" "abc" 3600 "/")
  => "sid=abc; Path=/; Max-Age=3600; HttpOnly; SameSite=Strict; Secure"
  (format-set-cookie "sid" "abc" #f "/" 'no-secure)
  => "sid=abc; Path=/; HttpOnly; SameSite=Strict"
```

### `parse-cookie-header`

```
Syntax: (parse-cookie-header header)
Library: (scm net http cookies)
Description: Parses an HTTP Cookie header value into an alist. Whitespace
  around names and values is trimmed. Values are NOT percent-decoded — the
  caller decides, because many cookie values are opaque tokens (base64,
  hex, signed blobs). #f or empty → '().
Example:
  (parse-cookie-header "sid=abc; pref=dark")
  => (("sid" . "abc") ("pref" . "dark"))
```


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

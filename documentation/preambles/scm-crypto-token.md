## Overview

`(scm crypto token)` makes signed, expiring, URL-safe tokens that carry a
small Scheme datum (an alist, a list, a string, …): for session cookies,
API bearer tokens, password-reset or download links. Tokens are signed with
HMAC-SHA256, not encrypted: the holder can read the datum but not change it.

A `purpose` option binds a token to one use, so a session token signed with
the same key is rejected as a reset token. A list of secrets enables key
rotation: the first signs, all of them verify.

## Common uses

```scheme
(import (scm crypto) (scm crypto token))

(define secret (base64-encode (random-bytes 32)))   ; keep in config

(define tok (token-sign secret '((uid . 42)) 3600 '((purpose . "api"))))
(token-verify secret tok '((purpose . "api")))      ;; => ((uid . 42))
(token-verify secret tok '((purpose . "reset")))    ;; => #f
```

Validate a configured secret at startup with `token-secrets`, which raises
for invalid base64 or a key shorter than 16 bytes. For browser sessions use
`(scm net http session)`, which wraps these tokens in cookies.

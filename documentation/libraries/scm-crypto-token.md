# `(scm crypto token)`

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


## Exports

### `token-secrets`

```
Syntax: (token-secrets secret)
Library: (scm crypto token)
Description: Normalises secret to a non-empty list of key bytevectors.
  secret is a bytevector, a base64 string, or a list of those (newest
  first, for key rotation). Raises an error for an empty list, invalid
  base64 or a key shorter than 16 bytes, so a bad configuration fails at
  startup rather than on the first request. token-sign and token-verify
  call it themselves; call it once at startup to validate a config value.
Example:
  (token-secrets (base64-encode (random-bytes 32))) => (#u8(...))
```

### `token-sign`

```
Syntax: (token-sign secret datum max-age [opts])
Library: (scm crypto token)
Description: Returns a signed, URL-safe token carrying datum, which must
  survive write/read (strings, numbers, symbols, booleans and lists of
  them; e.g. an alist) and must not be #f, which token-verify returns for
  a rejected token. max-age is the lifetime in seconds, or #f for no
  expiry. secret is as for token-secrets; the first key signs. opts is an
  alist: (purpose . string) binds the token to one use (default ""), so
  token-verify with another purpose rejects it. The datum is signed, not
  encrypted: anyone holding the token can read it.
Example:
  (token-sign key '((uid . 42)) 3600 '((purpose . "session")))
  => "KDE3NjE..."
```

### `token-verify`

```
Syntax: (token-verify secret token [opts])
Library: (scm crypto token)
Description: Returns the datum of token if it was made by token-sign with
  one of the keys in secret and the same purpose, and has not expired;
  otherwise #f. Never raises for a bad token (tampered, truncated, expired,
  wrong purpose, or not a token at all). opts as for token-sign.
Example:
  (token-verify key tok '((purpose . "session"))) => ((uid . 42))
  (token-verify key "garbage") => #f
```


## Overview

`(scm crypto)` collects cryptographic and encoding primitives: hashing (MD5,
SHA-1, SHA-256), HMAC and PBKDF2, symmetric ciphers (AES in CBC/GCM/ECB,
ChaCha20-Poly1305), RSA, secure random bytes, and Base64/hex helpers. Hash and
cipher functions operate on bytevectors.

## Common uses

Hash some bytes and render the digest as hex:

```scheme
(import (scm crypto))

(bytevector->hex (sha256-hash (string->utf8 "abc")))
;; => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

(bytevector->hex #u8(0 15 255))   ;; => "000fff"
(hex->bytevector "deadbeef")      ;; => #u8(222 173 190 239)
```

Base64 encode and decode (both work in terms of bytevectors):

```scheme
(base64-encode (string->utf8 "hi"))      ;; => "aGk="
(utf8->string (base64-decode "aGk="))    ;; => "hi"
```

Password hashing and constant-time comparison are available via
`pbkdf2-sha256` and `constant-time-bytevector=?`; `random-bytes` provides
cryptographically secure randomness.

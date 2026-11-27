---
title: (scm crypto): hashing, encryption, passwords, tokens
part: libraries
order: 1013
libraries: (scm crypto) (scm crypto password) (scm crypto token)
summary: Hashes and HMACs, hex and Base64, secure random values, authenticated encryption with AES-GCM and ChaCha20-Poly1305, key derivation, constant-time comparison; storing passwords; signed, expiring tokens.
---
# (scm crypto): hashing, encryption, passwords, tokens

```scheme
(import (scheme base) (scm crypto) (scm crypto password) (scm crypto token))
```

The rule of thumb: use the highest-level tool that fits. Passwords go
through `(scm crypto password)`, links and API keys through
`(scm crypto token)`, data through authenticated encryption (AES-GCM or
ChaCha20-Poly1305). The lower-level procedures are for protocols that
prescribe them.

## Hashes, hex and Base64

```scheme
(define (hex-of s) (bytevector->hex (sha256-hash (string->utf8 s))))
(hex-of "abc")
;; => "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
(bytevector-length (sha512-hash (string->utf8 "abc"))) ;; => 64
(md5-hash "abc")                                       ;; => "900150983cd24fb0d6963f7d28e17f72"
(string-length (sha1-hash "abc"))                      ;; => 40
(hex->bytevector "cafe")                               ;; => #u8(202 254)
(base64-encode (string->utf8 "Grüße"))                 ;; => "R3LDvMOfZQ=="
(utf8->string (base64-decode "R3LDvMOfZQ=="))          ;; => "Grüße"
```

The SHA-2 hashes (`sha224-hash` to `sha512-hash`) take a bytevector and
return a bytevector, so convert text with `string->utf8` and the result with
`bytevector->hex`. The older `md5-hash` and `sha1-hash` accept strings too
and return a hex string directly; use them only where a format requires
them, they are not secure any more.
`sha256-file` hashes a file without reading it into memory, for checksums
of downloads.

## HMAC: proving a message is authentic

An HMAC is a hash keyed with a secret; only someone with the key can
produce it. Webhooks and API signatures work this way:

```scheme
(define key (string->utf8 "shared-secret"))
(define (sign msg) (bytevector->hex (hmac-sha256 key (string->utf8 msg))))
(define sig (sign "amount=100&to=ada"))
(string=? sig (sign "amount=100&to=ada"))              ;; => #t
(string=? sig (sign "amount=900&to=ada"))              ;; => #f
(constant-time-bytevector=? (hex->bytevector sig)
                            (hex->bytevector (sign "amount=100&to=ada"))) ;; => #t
```

Compare secrets with `constant-time-bytevector=?`: an ordinary comparison
stops at the first difference, and the time it takes can leak how much of
a forged signature was right.

## Secure random values

```scheme
(bytevector-length (random-bytes 32))                  ;; => 32
(string-length (random-string "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" 20)) ;; => 20
```

`random-bytes` uses the operating system's secure generator; use it for
keys, salts and identifiers, never `random-integer`.

## Authenticated encryption

AES-GCM and ChaCha20-Poly1305 encrypt *and* detect tampering. Each message
needs a fresh nonce (12 bytes), never reused with the same key:

```scheme
(define k (random-bytes 32))
(define nonce (random-bytes 12))
(define plaintext (string->utf8 "meet at noon"))

(define sealed (aes-gcm-encrypt k nonce plaintext))
(utf8->string (aes-gcm-decrypt k nonce sealed))        ;; => "meet at noon"

(define tampered (bytevector-copy sealed))
(bytevector-u8-set! tampered 0 (modulo (+ 1 (bytevector-u8-ref tampered 0)) 256))
(guard (e (#t 'rejected)) (aes-gcm-decrypt k nonce tampered)) ;; => rejected

(define sealed2 (chacha20poly1305-encrypt k nonce plaintext))
(utf8->string (chacha20poly1305-decrypt k nonce sealed2)) ;; => "meet at noon"
```

A changed byte makes decryption fail instead of returning garbage. Store
the nonce next to the ciphertext; it need not be secret.

## Keys from passwords

A password is not a key. `pbkdf2-sha256` and `scrypt` derive one, slowly on
purpose, so guessing is expensive:

```scheme
(define salt (random-bytes 16))
(define key1 (pbkdf2-sha256 (string->utf8 "correct horse") salt 100000 32))
(bytevector-length key1)                               ;; => 32
(equal? key1 (pbkdf2-sha256 (string->utf8 "correct horse") salt 100000 32)) ;; => #t
```

## Storing passwords

`(scm crypto password)` does all of the above for passwords: random salt,
slow hashing, a self-describing result, constant-time verification:

```scheme
(define stored (password-hash "hunter2"))
(string? stored)                                       ;; => #t
(password-verify "hunter2" stored)                     ;; => #t
(password-verify "hunter3" stored)                     ;; => #f
(password-verify "anything" #f)                        ;; => #f
(boolean? (password-needs-rehash? stored))             ;; => #t
```

Store only the result of `password-hash`. `password-verify` with `#f`
(an unknown user) takes as long as a real check, so attackers cannot find
out which user names exist by timing. When `password-needs-rehash?` is true
(the hash used older settings), hash the password again at the next login.

## Signed, expiring tokens

`(scm crypto token)` makes tokens for password-reset links, e-mail
confirmations or API access: the data is signed, can expire, and is bound
to a purpose:

```scheme
(define secret (base64-encode (random-bytes 32)))     ; keep in the configuration

(define reset-token (token-sign secret '((user . 42)) 3600 '((purpose . "reset"))))
(string? reset-token)                                  ;; => #t
(token-verify secret reset-token '((purpose . "reset"))) ;; => ((user . 42))
(token-verify secret reset-token '((purpose . "login"))) ;; => #f
(token-verify (base64-encode (random-bytes 32)) reset-token '((purpose . "reset"))) ;; => #f
```

A token signed for one purpose is rejected for another, so a reset link
cannot be used as a login session. The 3600 is the lifetime in seconds.

## Where next

- `(scm net http session)` for login sessions in cookies.
- [SRFI 271](srfi-271.md) for random byte streams.
- Reference: `(scm crypto)`, `(scm crypto password)`, `(scm crypto token)`.

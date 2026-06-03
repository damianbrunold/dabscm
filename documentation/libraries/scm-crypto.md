# `(scm crypto)`

Cryptographic hashing and encoding utilities

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


## Exports

### `aes-cbc-decrypt`

```
Syntax: (aes-cbc-decrypt key iv ciphertext)
Library: (scm crypto)
Description: Decrypts ciphertext using AES-CBC with PKCS7 padding. key must be 16, 24, or 32 bytes; iv must be 16 bytes. Returns a bytevector.
Example:
  (aes-cbc-decrypt key iv ciphertext) => #u8(...)
```

### `aes-cbc-encrypt`

```
Syntax: (aes-cbc-encrypt key iv plaintext)
Library: (scm crypto)
Description: Encrypts plaintext using AES-CBC with PKCS7 padding. key must be 16, 24, or 32 bytes; iv must be 16 bytes. Returns a bytevector.
Example:
  (aes-cbc-encrypt key iv plaintext) => #u8(...)
```

### `aes-ecb-decrypt`

```
Syntax: (aes-ecb-decrypt key ciphertext)
Library: (scm crypto)
Description: Decrypts ciphertext using AES-ECB with PKCS7 padding. key must be 16, 24, or 32 bytes. Returns a bytevector.
Example:
  (aes-ecb-decrypt key ciphertext) => #u8(...)
```

### `aes-ecb-encrypt`

```
Syntax: (aes-ecb-encrypt key plaintext)
Library: (scm crypto)
Description: Encrypts plaintext using AES-ECB with PKCS7 padding. key must be 16, 24, or 32 bytes. Note: ECB mode is not semantically secure; prefer AES-CBC or AES-GCM. Returns a bytevector.
Example:
  (aes-ecb-encrypt key plaintext) => #u8(...)
```

### `aes-gcm-decrypt`

```
Syntax: (aes-gcm-decrypt key nonce ciphertext [aad])
Library: (scm crypto)
Description: Decrypts ciphertext using AES-GCM. key must be 16, 24, or 32 bytes; nonce must be 12 bytes. The ciphertext argument must include the 16-byte authentication tag appended at the end. Raises an error if authentication fails.
Example:
  (aes-gcm-decrypt key nonce ciphertext-with-tag) => #u8(...)
```

### `aes-gcm-encrypt`

```
Syntax: (aes-gcm-encrypt key nonce plaintext [aad])
Library: (scm crypto)
Description: Encrypts plaintext using AES-GCM. key must be 16, 24, or 32 bytes; nonce must be 12 bytes. Optional aad is additional authenticated data. Returns ciphertext concatenated with 16-byte authentication tag.
Example:
  (aes-gcm-encrypt key nonce plaintext) => #u8(...)
```

### `base64-decode`

```
Syntax: (base64-decode string)
Library: (scm crypto)
Description: Decodes a base64-encoded string and returns a bytevector.
Example:
  (base64-decode "SGVsbG8=") => #u8(72 101 108 108 111)
```

### `base64-encode`

```
Syntax: (base64-encode bytevector)
Library: (scm crypto)
Description: Returns the base64-encoded string of a bytevector.
Example:
  (base64-encode #u8(72 101 108 108 111)) => "SGVsbG8="
```

### `bytevector->hex`

```
Syntax: (bytevector->hex bv)
Library: (scm crypto)
Description: Returns the lowercase hexadecimal string representation of the
  bytevector bv (two hex digits per byte, no separators).
Example:
  (bytevector->hex #u8(0 15 255)) => "000fff"
```

### `chacha20poly1305-decrypt`

```
Syntax: (chacha20poly1305-decrypt key nonce ciphertext [aad])
Library: (scm crypto)
Description: Decrypts ciphertext using ChaCha20-Poly1305. key must be 32 bytes; nonce must be 12 bytes. The ciphertext argument must include the 16-byte authentication tag appended at the end. Raises an error if authentication fails.
Example:
  (chacha20poly1305-decrypt key nonce ciphertext-with-tag) => #u8(...)
```

### `chacha20poly1305-encrypt`

```
Syntax: (chacha20poly1305-encrypt key nonce plaintext [aad])
Library: (scm crypto)
Description: Encrypts plaintext using ChaCha20-Poly1305. key must be 32 bytes; nonce must be 12 bytes. Optional aad is additional authenticated data. Returns ciphertext concatenated with 16-byte authentication tag.
Example:
  (chacha20poly1305-encrypt key nonce plaintext) => #u8(...)
```

### `constant-time-bytevector=?`

```
Syntax: (constant-time-bytevector=? a b)
Library: (scm crypto)
Description: Compares two bytevectors in constant time relative to their
  length when equal-length. Returns #f for different lengths (this does
  leak length, just not content). Use for comparing MACs, password hashes,
  or any secret-derived bytes.
Example:
  (constant-time-bytevector=? #u8(1 2 3) #u8(1 2 3)) => #t
  (constant-time-bytevector=? #u8(1 2 3) #u8(1 2 4)) => #f
```

### `hex->bytevector`

```
Syntax: (hex->bytevector s)
Library: (scm crypto)
Description: Parses a hexadecimal string (case-insensitive, no separators)
  into a bytevector. Raises an error on odd length or non-hex characters.
Example:
  (hex->bytevector "000fff") => #u8(0 15 255)
  (hex->bytevector "DEADBEEF") => #u8(222 173 190 239)
```

### `hmac-sha256`

```
Syntax: (hmac-sha256 key data)
Library: (scm crypto)
Description: Computes HMAC-SHA256 of data using key. Both key and data must be bytevectors. Returns a bytevector.
Example:
  (hmac-sha256 key-bv data-bv) => #u8(...)
```

### `md5-hash`

```
Syntax: (md5-hash obj)
Library: (scm crypto)
Description: Returns the MD5 hash of obj as a lowercase hex string. Accepts strings, symbols, or bytevectors.
Example:
  (md5-hash "hello") => "5d41402abc4b2a76b9719d911017c592"
```

### `pbkdf2-sha256`

```
Syntax: (pbkdf2-sha256 password salt iterations length)
Library: (scm crypto)
Description: Derives a key using PBKDF2-HMAC-SHA256. Password is a string or bytevector, salt is a bytevector. Returns a bytevector of given length.
Example:
  (pbkdf2-sha256 "password" salt-bv 4096 32) => #u8(...)
```

### `random-bytes`

```
Syntax: (random-bytes n)
Library: (scm crypto)
Description: Returns a fresh bytevector of n cryptographically random bytes.
Example:
  (random-bytes 16) => #u8(...)
```

### `random-string`

```
Syntax: (random-string charset length)
Library: (scm crypto)
Description: Returns a random string of the given length drawn from charset,
  using random-bytes as the entropy source. Each output character is the
  byte taken modulo (string-length charset); for cryptographic uses prefer
  a charset length that is a power of two to avoid modulo bias, or a
  charset of length ≤ 64 (the bias is then ≲ 1 in 4 billion per char).
Example:
  (random-string "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" 6) ; e.g. "K3Z9PA"
  (random-string "0123456789abcdef" 32) ; 128 random bits as hex
```

### `rsa-decrypt`

```
Syntax: (rsa-decrypt private-key ciphertext)
Library: (scm crypto)
Description: Decrypts ciphertext using RSA with OAEP-SHA256 padding. private-key must be a bytevector in PKCS#8 DER format (as returned by rsa-generate-keypair). Returns a bytevector.
Example:
  (rsa-decrypt priv ciphertext) => #u8(...)
```

### `rsa-encrypt`

```
Syntax: (rsa-encrypt public-key plaintext)
Library: (scm crypto)
Description: Encrypts plaintext using RSA with OAEP-SHA256 padding. public-key must be a bytevector in SubjectPublicKeyInfo DER format (as returned by rsa-generate-keypair). Returns a bytevector.
Example:
  (rsa-encrypt pub plaintext) => #u8(...)
```

### `rsa-generate-keypair`

```
Syntax: (rsa-generate-keypair bits)
Library: (scm crypto)
Description: Generates an RSA key pair of the given bit size (e.g. 2048, 4096). Returns a list of two bytevectors: (list public-key private-key). The public key is in SubjectPublicKeyInfo DER format; the private key is in PKCS#8 DER format.
Example:
  (define kp (rsa-generate-keypair 2048))
  (define pub (car kp))
  (define priv (cadr kp))
```

### `sha1-hash`

```
Syntax: (sha1-hash obj)
Library: (scm crypto)
Description: Returns the SHA-1 hash of obj as a lowercase hex string. Accepts strings, symbols, or bytevectors.
Example:
  (sha1-hash "hello") => "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d"
```

### `sha256-hash`

```
Syntax: (sha256-hash obj)
Library: (scm crypto)
Description: Returns the SHA-256 hash of obj as a bytevector. Accepts strings, symbols, or bytevectors.
Example:
  (sha256-hash "hello") => #u8(...)
```

### `xor-key`

```
Syntax: (xor-key bv key)
Library: (scm crypto)
Description: Returns a new bytevector produced by XORing each byte of bv with the corresponding byte of key, cycling through key as needed.
Example:
  (xor-key data-bv key-bv) => #u8(...)
```


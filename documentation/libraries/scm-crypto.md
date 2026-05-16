# `(scm crypto)`

Cryptographic hashing and encoding utilities

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


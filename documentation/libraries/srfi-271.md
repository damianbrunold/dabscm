# `(srfi 271)`

SRFI-271 — Random ports: cryptographically random bytes as a binary input port

## Overview

SRFI-271 provides random data as binary input ports that never return an eof
object, so random bytes can be read with `read-u8`, `read-bytevector` and any
other procedure that takes a binary port. `(srfi 271)` is the same as
`(srfi 271 randomized)`: its ports deliver cryptographically random bytes from
the operating system (Java `SecureRandom`, .NET `RandomNumberGenerator`) and
have no observable state.

For reproducible byte streams with a saveable state, see
`(srfi 271 determinized)`.

## Common uses

```scheme
(import (srfi 271))

(define rp (make-random-port))
(read-bytevector 16 rp)     ;; => 16 random bytes, e.g. for a token or key
(read-u8 rp)                ;; => 0..255
(random-port? rp)           ;; => #t
```


## Exports

### `make-random-port`

```
Syntax: (make-random-port)
Library: (srfi 271 randomized), (srfi 271)
Description: Returns a new random port: a binary input port delivering an
  endless stream of cryptographically random bytes from the operating
  system's secure random number generator.  It never returns an eof object.
Example:
  (bytevector-length (read-bytevector 16 (make-random-port))) => 16
```

### `random-port?`

```
Syntax: (random-port? obj)
Library: (srfi 271 randomized), (srfi 271)
Description: Returns #t if obj is a random port made by make-random-port
  of this library, #f otherwise.
Example:
  (random-port? (make-random-port)) => #t
  (random-port? (open-input-bytevector #u8(1 2))) => #f
```


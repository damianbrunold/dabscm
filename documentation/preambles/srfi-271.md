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

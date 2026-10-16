# `(srfi 271 determinized chacha20)`

SRFI-271 — Determinized random ports using ChaCha20

## Overview

The ChaCha20 implementation behind `(srfi 271 determinized)`, under the name
the SRFI suggests for algorithm-specific libraries. A port delivers the
ChaCha20 keystream (20 rounds, all-zero nonce) of a 256-bit key; for the first
2^32 blocks it equals RFC 8439 ChaCha20 with an all-zero nonce. Its state is
the vector `#(chacha20 key counter offset)`: the 32-byte key, the keystream
block and the byte within that block that will be read next.


## Exports

### `make-random-port`

*(no documentation)*

### `random-port-initialization-error?`

```
Syntax: (random-port-initialization-error? obj)
Library: (srfi 271 determinized)
Description: Returns #t if obj is the object raised by make-random-port when
  the initializer port does not deliver enough usable data (fewer than 32
  bytes, or 32 zero bytes), #f otherwise.
Example:
  (guard (e ((random-port-initialization-error? e) 'too-short))
    (make-random-port (open-input-bytevector #u8(1 2 3)))) => too-short
```

### `random-port-state`

```
Syntax: (random-port-state random-port)
Library: (srfi 271 determinized)
Description: Returns the current state of random-port.  Passing it to
  make-random-port creates a port that delivers the same bytes as
  random-port does from now on.  A byte returned by peek-u8 but not yet
  read counts as not consumed.
Example:
  (let* ((p (make-random-port))
         (q (make-random-port (random-port-state p))))
    (equal? (read-bytevector 8 p) (read-bytevector 8 q))) => #t
```

### `random-port-state=?`

```
Syntax: (random-port-state=? state1 state2 ...)
Library: (srfi 271 determinized)
Description: Returns #t if all the given random port states are equal.
  Ports created from equal states produce identical byte sequences.
Example:
  (let ((p (make-random-port)))
    (random-port-state=? (random-port-state p) (random-port-state p))) => #t
```

### `random-port-state?`

```
Syntax: (random-port-state? obj)
Library: (srfi 271 determinized)
Description: Returns #t if obj is a valid random port state, i.e. a vector
  #(chacha20 key counter offset) with key a bytevector of 32 bytes that are
  not all zero, counter an exact integer in [0, 2^63) and offset an exact
  integer in [0, 63].
Example:
  (random-port-state? (vector 'chacha20 (make-bytevector 32 1) 0 0)) => #t
```

### `random-port?`

```
Syntax: (random-port? obj)
Library: (srfi 271 determinized)
Description: Returns #t if obj is a random port made by make-random-port of
  this library, #f otherwise.
Example:
  (random-port? (make-random-port)) => #t
```


# `(srfi 271 determinized)`

SRFI-271 — Determinized random ports: seedable ports with saveable state (ChaCha20)

## Overview

The determinized random ports of SRFI-271: seedable binary input ports whose
byte stream is fully determined by their state. A state can be taken from a
port at any time, written out, read back, and passed to `make-random-port` to
resume the exact same stream. The algorithm is ChaCha20 (a 256-bit key, see
`(srfi 271 determinized chacha20)`); a state is the vector
`#(chacha20 key counter offset)`.

## Common uses

```scheme
(import (srfi 271 determinized))

;; Seed from 32 bytes of any binary input port...
(define p (make-random-port (open-input-bytevector (make-bytevector 32 7))))
(read-bytevector 4 p)               ;; => always the same bytes

;; ...or from a cryptographically random port (no argument).
(define q (make-random-port))

;; Save and resume.
(define state (random-port-state q))
(define q2 (make-random-port state))
(equal? (read-bytevector 8 q) (read-bytevector 8 q2))   ;; => #t
```

If the initializer port delivers fewer than 32 bytes, or only zero bytes,
`make-random-port` raises an object satisfying
`random-port-initialization-error?`.


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


# `(srfi 271 randomized)`

SRFI-271 — Randomized random ports (same as (srfi 271))

## Overview

The randomized random ports of SRFI-271: binary input ports delivering an
endless stream of cryptographically random bytes from the operating system's
secure random number generator. `(srfi 271)` exports the same procedures.

```scheme
(import (srfi 271 randomized))

(read-bytevector 32 (make-random-port))
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


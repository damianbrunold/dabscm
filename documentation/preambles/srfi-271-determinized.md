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

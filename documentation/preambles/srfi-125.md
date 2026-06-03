## Overview

SRFI-125 provides intermediate hash tables built on SRFI-128 comparators, with a
broad operation set: mapping, folding, and set-like combinations. Use it when you
want comparator-driven tables or the richer API; for simple `eq?`/`equal?` tables
SRFI-69 is lighter.

## Common uses

```scheme
(import (srfi 128) (srfi 125))

(define h (make-hash-table (make-default-comparator)))
(hash-table-set! h 1 "one")
(hash-table-ref/default h 1 #f)        ;; => "one"

(hash-table-update!/default h 2 (lambda (v) (+ v 1)) 0)
(hash-table-ref/default h 2 #f)        ;; => 1
```

It also offers `hash-table-map`, `hash-table-fold`, `hash-table-count`, and
`hash-table-union!`/`hash-table-intersection!` style operations.

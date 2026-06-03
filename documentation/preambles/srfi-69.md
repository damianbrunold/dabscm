## Overview

SRFI-69 provides basic hash tables, keyed with `eq?`, `eqv?`, or `equal?`. It's the
simplest of the hash-table SRFIs; for comparator-based tables with richer
operations see SRFI-125.

## Common uses

```scheme
(import (srfi 69))

(define h (make-hash-table equal?))
(hash-table-set! h "a" 1)
(hash-table-ref h "a" (lambda () 'missing))   ;; => 1
(hash-table-ref/default h "z" 'none)          ;; => none
(hash-table-keys h)                            ;; => ("a")
```

`hash-table-update!`, `hash-table-delete!`, `hash-table-walk`, and
`hash-table->alist` cover the usual operations.

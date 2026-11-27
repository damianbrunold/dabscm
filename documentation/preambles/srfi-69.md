## Overview

SRFI-69 provides basic hash tables. It's the simplest of the hash-table SRFIs; for
comparator-based tables with richer operations see SRFI-125.

A table's equivalence is one of `equal?` (the default), `eqv?`, `eq?`,
`string=?`, `string-ci=?`, `char=?`, `char-ci=?` or `=`; the table hashes as
that equivalence needs, so a hash function given to `make-hash-table` is only
kept for `hash-table-hash-function`. Another predicate is an error, since a
table cannot call it. Keys of another type compare as with `equal?`
(`string-ci=?`, `=`) or `eqv?` (`char-ci=?`).

## Common uses

```scheme
(import (srfi 69))

(define h (make-hash-table equal?))
(hash-table-set! h "a" 1)
(hash-table-ref h "a" (lambda () 'missing))   ;; => 1
(hash-table-ref/default h "z" 'none)          ;; => none
(hash-table-keys h)                            ;; => ("a")
```

```scheme
(define ci (make-hash-table string-ci=? string-ci-hash))
(hash-table-set! ci "Zurich" 1)
(hash-table-ref/default ci "ZURICH" #f)        ;; => 1
(define n (alist->hash-table '((1 . one)) =))
(hash-table-ref/default n 1.0 #f)              ;; => one
```

`hash-table-update!`, `hash-table-delete!`, `hash-table-walk`, and
`hash-table->alist` cover the usual operations.

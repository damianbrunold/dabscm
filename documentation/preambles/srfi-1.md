## Overview

SRFI-1 is the comprehensive list library: constructors, folds and reductions,
searching and filtering, take/drop, association-list and set operations, and much
more. It is the go-to library for list processing (preferred over `(scm list)`).

## Common uses

```scheme
(import (srfi 1))

(iota 3)                       ;; => (0 1 2)
(fold + 0 '(1 2 3))            ;; => 6
(take '(1 2 3 4) 2)           ;; => (1 2)
(filter even? '(1 2 3 4))     ;; => (2 4)
(any odd? '(2 4 5))           ;; => #t
(delete-duplicates '(1 1 2 3 3))   ;; => (1 2 3)
```

It also provides `map`/`for-each` variants, `append-map`, `partition`,
`find`, `count`, `last`, `zip`/`unzip`, and the `lset-*` set operations.

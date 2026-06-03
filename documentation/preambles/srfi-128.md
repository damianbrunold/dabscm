## Overview

SRFI-128 provides comparators: bundles of a type test, an equality predicate, an
ordering predicate, and a hash function. They give a single value that fully
describes how to compare and hash a kind of data — used by hash tables (SRFI-125)
and ordered collections.

## Common uses

```scheme
(import (srfi 128))

(define c (make-comparator number? = < #f))   ;; type=, equal=, order=, hash=
(comparator? c)                                ;; => #t
(=? c 3 3)                                      ;; => #t
(<? c 1 2)                                      ;; => #t
```

`make-default-comparator` returns a general-purpose comparator, and there are
predefined comparators and combinators for building comparators over compound data.

## Overview

`(scm dict)` is a simple mutable dictionary (associative map) with a small,
readable API. For richer hash-table functionality (custom comparators, folding,
set operations) see `(srfi 69)` and `(srfi 125)`; `(scm dict)` is handy when you
just want a quick mutable key/value store.

## Common uses

```scheme
(import (scm dict))

(define d (make-dict))
(dict-put d "a" 1)
(dict-put d "b" 2)

(dict-get d "a")        ;; => 1
(dict-size d)           ;; => 2
(dict-contains d "b")   ;; => #t
(dict-keys d)           ;; => ("a" "b")
(dict-values d)         ;; => (1 2)
```

`dict-entries` returns the key/value pairs, and `dict-clear` empties the
dictionary in place.

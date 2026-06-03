## Overview

SRFI-95 provides sorting and merging for lists and vectors with a polymorphic
`sort` (and the destructive `sort!`), plus `merge` and a key-extraction option.

## Common uses

```scheme
(import (srfi 95))

(sort '(3 1 2) <)                 ;; => (1 2 3)
(sort (vector 3 1 2) <)           ;; => #(1 2 3)

;; sort by a key
(sort '("bbb" "a" "cc") < string-length)   ;; => ("a" "cc" "bbb")

(merge '(1 3 5) '(2 4 6) <)       ;; => (1 2 3 4 5 6)
```

`sort` returns a new sequence; `sort!` may rearrange its argument in place. The
optional third argument to comparisons is a key procedure applied before comparing.

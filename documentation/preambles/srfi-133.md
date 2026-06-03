## Overview

SRFI-133 is a comprehensive vector library: the higher-order operations,
searching, folding, and copying you expect for lists, but for vectors.

## Common uses

```scheme
(import (srfi 133))

(vector-map + (vector 1 2 3) (vector 10 20 30))   ;; => #(11 22 33)
(vector-fold + 0 (vector 1 2 3 4))                ;; => 10
(vector-for-each display (vector 1 2 3))          ;; prints 123
(vector-count even? (vector 1 2 3 4))             ;; => 2
```

It also provides `vector-append`, `vector-copy`/`vector-copy!`, `vector-reverse`,
`vector-index`, and many more vector operations.

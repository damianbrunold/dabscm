## Overview

SRFI-111 provides boxes: simple mutable single-value containers. A box holds one
value you can read with `unbox` and replace with `set-box!` — handy for shared
mutable state without defining a record.

## Common uses

```scheme
(import (srfi 111))

(define b (box 10))
(unbox b)         ;; => 10
(set-box! b 20)
(unbox b)         ;; => 20
(box? b)          ;; => #t
```

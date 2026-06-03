## Overview

SRFI-151 provides bitwise operations on exact integers: boolean logic, shifts, bit
field manipulation, and bit-level folds and counts.

## Common uses

```scheme
(import (srfi 151))

(bitwise-and 6 3)        ;; => 2
(bitwise-ior 4 1)        ;; => 5
(bitwise-xor 5 3)        ;; => 6
(arithmetic-shift 1 4)   ;; => 16   (shift left by 4)
(arithmetic-shift 16 -2) ;; => 4    (shift right)
(bit-count 7)            ;; => 3
```

It also includes `bitwise-not`, bit-field operations (`bit-field`,
`bit-field-set`), and tests like `bit-set?`.

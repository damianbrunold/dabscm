## Overview

SRFI-26 provides `cut` and `cute`, compact syntax for partial application: write a
specialized procedure by marking the "holes" with `<>` instead of writing a full
lambda.

## Common uses

```scheme
(import (srfi 26))

(map (cut * 2 <>) '(1 2 3))        ;; => (2 4 6)
(map (cut cons <> '()) '(a b c))   ;; => ((a) (b) (c))

((cut + 1 <>) 10)                  ;; => 11
```

`<...>` collects the rest of the arguments. `cute` is like `cut` but evaluates the
non-hole subexpressions once, up front (useful when they're expensive or
effectful).

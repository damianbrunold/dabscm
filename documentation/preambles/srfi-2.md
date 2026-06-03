## Overview

SRFI-2 provides `and-let*`, a hybrid of `and` and `let*`: it binds variables in
sequence, short-circuiting to `#f` as soon as a binding (or a bare test) is false.
It's a tidy way to write guarded, sequential computations.

## Common uses

```scheme
(import (srfi 2))

(and-let* ((x 5)
           ((> x 0)))      ;; a bare test clause
  (* x x))                 ;; => 25

(and-let* ((p (assq 'b '((a . 1) (b . 2))))
           (v (cdr p)))
  (* v 10))                ;; => 20
```

If any binding's value is `#f` (or a test clause is false), the whole form returns
`#f` without evaluating the body.

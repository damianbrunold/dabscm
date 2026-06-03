## Overview

`(scheme case-lambda)` provides `case-lambda`, which builds a procedure that
dispatches on the number of arguments it receives — a clean way to write
arity-overloaded procedures.

## Common uses

```scheme
(import (scheme base) (scheme case-lambda))

(define greet
  (case-lambda
    (()      "hello")
    ((name)  (string-append "hello, " name))
    ((g name) (string-append g ", " name))))

(greet)              ;; => "hello"
(greet "Ada")        ;; => "hello, Ada"
(greet "hi" "Ada")   ;; => "hi, Ada"
```

Each clause is `(formals body …)`; the first whose formals accept the actual
argument count is used.

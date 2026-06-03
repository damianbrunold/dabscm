# `(scheme case-lambda)`

Case-lambda for multi-arity procedures

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


## Exports

### `case-lambda`

```
Syntax: (case-lambda (formals body ...) ...)
Library: (scheme case-lambda)
Description: Returns a procedure that, when called, selects the first clause
whose formals specification is compatible with the number of actual arguments
and evaluates the body expressions of that clause in a new environment where
the formals are bound to the actual arguments. Raises an error if no clause
matches. This allows a single procedure to accept different numbers of
arguments.
Example:
  (define f
    (case-lambda
      ((x)   (* x x))
      ((x y) (+ x y))))
  (f 5)   => 25
  (f 3 4) => 7
```


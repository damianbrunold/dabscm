# `(scheme case-lambda)`

Case-lambda for multi-arity procedures

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


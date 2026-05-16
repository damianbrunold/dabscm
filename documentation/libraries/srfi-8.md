# `(srfi 8)`

SRFI-8 — receive: binding multiple values

## Exports

### `receive`

```
Syntax: (receive formals expression body ...)
Library: (srfi 8)
Description: SRFI-8 receive. Binds the values returned by expression to
formals (like lambda parameter list), then evaluates body.
Example:
  (receive (q r) (floor/ 17 5) (list q r)) => (3 2)
```


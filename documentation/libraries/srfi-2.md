# `(srfi 2)`

SRFI-2 — and-let*: short-circuiting let

## Exports

### `and-let*`

```
Syntax: (and-let* ((var expr) ...) body ...)
Library: (srfi 2)
Description: Like let*, but short-circuits on #f. Each clause can be (var expr)
to bind var, (expr) to test expr without binding, or a bare var to test it.
Example:
  (and-let* ((x 5) (y (* x 2))) y) => 10
  (and-let* ((x #f) (y 1)) y) => #f
```


# `(scm macro)`

Non-standard macros and meta-programming utilities

## Exports

### `define-if-not-bound`

```
Syntax: (define-if-not-bound name value)
Library: (scm macro)
Description: Defines name to value only if name is not already bound in
the current module. Useful for conditional initialization.
Example:
  (define-if-not-bound my-var 42)
```

### `macroexpand`

```
Syntax: (macroexpand expr)
Library: (scm core)
Description: Fully expands all macros in expr using the Dybvig expander.
Returns a plain S-expression with all macros expanded.
Example:
  (macroexpand '(and 1 2 3)) => (if 1 (and 2 3) #f)
```

### `pretty-print`

```
Syntax: (pretty-print expr port?)
Library: (scm macro)
Description: Prints expr in a human-readable indented format to port
(default: current-output-port). Follows a line-width of 79 characters.
Example:
  (pretty-print '(define (f x) (+ x 1)))
```


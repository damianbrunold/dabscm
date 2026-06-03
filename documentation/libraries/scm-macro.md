# `(scm macro)`

Non-standard macros and meta-programming utilities

## Overview

`(scm macro)` provides metaprogramming conveniences: expand macros to see what
they produce, pretty-print s-expressions, and define a binding only if it isn't
already bound.

## Common uses

Expand a macro one level to inspect its output:

```scheme
(import (scm macro))

(macroexpand '(when #t 1 2))   ;; => (if #t (begin 1 2))
```

Pretty-print a datum, and define a fallback binding:

```scheme
(pretty-print '(a (b c) (d (e f))))
(define-if-not-bound my-var 42)   ;; defines my-var only if undefined
```


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


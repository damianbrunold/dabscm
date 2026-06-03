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

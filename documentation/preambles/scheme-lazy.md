## Overview

`(scheme lazy)` provides lazy evaluation through promises: `delay` defers a
computation, and `force` runs it once and caches the result. `delay-force`
(a.k.a. `lazy`) supports building iterative lazy algorithms without growing the
stack.

## Common uses

```scheme
(import (scheme base) (scheme lazy))

(define p (delay (begin (display "computing\n") 42)))
(force p)   ;; prints "computing", returns 42
(force p)   ;; => 42   (cached; does not recompute)

(promise? p)            ;; => #t
(force (make-promise 5)) ;; => 5
```

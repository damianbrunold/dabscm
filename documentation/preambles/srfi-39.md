## Overview

SRFI-39 provides parameter objects: dynamically-scoped, mutable cells created with
`make-parameter` and rebound for the dynamic extent of a body with `parameterize`.
In R7RS this is part of `(scheme base)`; this library re-exports it.

## Common uses

```scheme
(import (srfi 39))

(define verbose (make-parameter #f))

(verbose)                       ;; => #f   (call with no args to read)
(parameterize ((verbose #t))
  (verbose))                    ;; => #t   (rebound inside the body)
(verbose)                       ;; => #f   (restored afterwards)
```

`make-parameter` can take a converter that is applied to every value bound to the
parameter.

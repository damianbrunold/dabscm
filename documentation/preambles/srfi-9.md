## Overview

SRFI-9 provides `define-record-type` for defining new record types with a
constructor, a type predicate, and field accessors (and optional mutators). In
R7RS this is part of `(scheme base)`; this library re-exports it for SRFI-9
compatibility.

## Common uses

```scheme
(import (srfi 9))

(define-record-type point
  (make-point x y)     ;; constructor
  point?               ;; predicate
  (x point-x)          ;; field + accessor
  (y point-y))

(define p (make-point 3 4))
(point? p)      ;; => #t
(point-x p)     ;; => 3
```

Add a setter by writing `(x point-x set-point-x!)` for a mutable field.

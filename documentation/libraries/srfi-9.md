# `(srfi 9)`

SRFI-9 — Record types (re-export from scheme base)

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


## Exports

### `define-record-type`

```
Syntax: (define-record-type <type> (<constructor> <field-name> ...) <predicate> (<field-name> <accessor> <modifier>) ...)
Library: (scheme base), (srfi 9)
Description: Defines a new record type. <type> is bound to the record type descriptor.
<constructor> is bound to a procedure that creates instances with the specified fields
initialized from the corresponding arguments. <predicate> is bound to a procedure that
returns #t for instances of this type. Each field clause binds <accessor> to a procedure
that retrieves the field value; an optional <modifier> is bound to a procedure that sets it.
Example:
  (define-record-type <point>
    (make-point x y)
    point?
    (x point-x)
    (y point-y point-set-y!))
  (define p (make-point 1 2))
  (point? p) => #t
  (point-x p) => 1
  (point-set-y! p 42)
  (point-y p) => 42
```


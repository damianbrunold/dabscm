# `(srfi 9)`

SRFI-9 — Record types (re-export from scheme base)

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


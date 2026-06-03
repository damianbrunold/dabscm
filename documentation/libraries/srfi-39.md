# `(srfi 39)`

SRFI-39 — Parameter objects (re-export from scheme base)

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


## Exports

### `make-parameter`

```
Syntax: (make-parameter init)
       (make-parameter init converter)
Library: (scheme base)
Description: Returns a newly allocated parameter object, which is a procedure
  that accepts zero or one argument. When called with no argument, the
  parameter object returns its current value. When called with one argument,
  the parameter is set to the new value after passing it through the optional
  converter procedure. The converter is applied to init to produce the initial
  value.
Example:
  (define p (make-parameter 10))
  (p)      => 10
  (p 20)
  (p)      => 20
  (define q (make-parameter 10 (lambda (x) (* x 2))))
  (q)      => 20
```

### `parameterize`

```
Syntax: (parameterize ((param val) ...) body ...)
Library: (scheme base)
Description: A parameterize expression is used to change the values returned
  by specified parameter objects during the evaluation of the body. Each param
  expression must evaluate to a parameter object. For each parameter binding,
  the parameter object is called with the new value to update it. After the
  body forms are evaluated (even via continuations or exceptions), each
  parameter is restored to its previous value via dynamic-wind.
  The result of the parameterize expression is the value of the last body form.
Example:
  (define p (make-parameter 1))
  (parameterize ((p 2))
    (p)) => 2
  (p) => 1
```


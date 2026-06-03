# `(scm doc)`

Documentation access

## Overview

`(scm doc)` gives programmatic access to the interpreter's built-in
documentation: the docstrings attached to procedures and the info text of
primitives. It's what tooling (and this reference generator) uses to read a
binding's documentation.

## Common uses

```scheme
(import (scm doc))

(display (procedure-doc 'car))
;; Syntax: (car pair)
;; Library: (scheme base)
;; Description: Returns the car of pair. ...
```

`procedure-doc` returns the documentation string for a symbol (or `#f` if none).
`doc` is the underlying primitive it builds on.


## Exports

### `doc`

```
Syntax: (doc obj)
Library: (scm core)
Description: Prints documentation for obj to the current output port. obj may be
  a procedure, primitive, macro, or symbol naming one. Returns unspecified.
Example:
  (doc car) => prints documentation for car
```

### `procedure-doc`

```
Syntax: (procedure-doc obj)
Library: (scm core)
Description: Returns the documentation string for obj as a Scheme string, or #f
  if no documentation is available. obj may be a procedure, primitive, macro,
  or symbol naming one.
Example:
  (string? (procedure-doc car)) => #t
```


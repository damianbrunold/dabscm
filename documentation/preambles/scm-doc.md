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

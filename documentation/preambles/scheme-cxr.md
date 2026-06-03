## Overview

`(scheme cxr)` provides the compositions of `car` and `cdr` two to four levels
deep — `caar`, `cadr`, `cddr`, … up to `cddddr`. (The two-level `caar`/`cadr`/…
are also in `(scheme base)`; this library adds the three- and four-level forms.)

## Common uses

Each name reads right-to-left: `caddr` is `(car (cdr (cdr x)))` — the third
element of a list.

```scheme
(import (scheme base) (scheme cxr))

(cadr   '(1 2 3 4))   ;; => 2
(caddr  '(1 2 3 4))   ;; => 3
(cadddr '(1 2 3 4))   ;; => 4
(cddr   '(1 2 3 4))   ;; => (3 4)
```

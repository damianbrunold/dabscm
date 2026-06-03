## Overview

SRFI-8 provides `receive`, concise syntax for binding the multiple values returned
by an expression — much tidier than `call-with-values` with an explicit lambda.

## Common uses

```scheme
(import (srfi 8))

(receive (q r) (floor/ 17 5)
  (list q r))                    ;; => (3 2)
```

The formals work like a lambda's, so you can capture a fixed number of values or
gather the rest with a dotted/rest parameter.

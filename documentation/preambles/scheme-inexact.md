## Overview

`(scheme inexact)` provides the transcendental and inexact numeric operations:
the trig and exponential/log functions, `sqrt`, and the predicates for special
values (`nan?`, `infinite?`, `finite?`).

## Common uses

```scheme
(import (scheme base) (scheme inexact))

(sqrt 2)            ;; => 1.4142135623730951
(sin 0)             ;; => 0.0
(exp 1)             ;; => 2.718281828459045
(log 100 10)        ;; => 2.0   (log base 10)

(nan? +nan.0)       ;; => #t
(infinite? +inf.0)  ;; => #t
(finite? 1.0)       ;; => #t
```

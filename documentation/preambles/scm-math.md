## Overview

`(scm math)` collects a few math constants and numeric helpers that aren't part
of the standard numeric tower.

## Common uses

```scheme
(import (scm math))

PI              ;; => 3.141592653589793
E               ;; => 2.718281828459045
(factorial 5)   ;; => 120
(sign -5)       ;; => -1
(sign 0)        ;; => 0
(magnitude -3)  ;; => 3
```

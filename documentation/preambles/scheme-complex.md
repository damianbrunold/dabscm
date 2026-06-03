## Overview

`(scheme complex)` provides the operations specific to complex numbers:
constructing them from rectangular or polar form and pulling out their parts.

## Common uses

```scheme
(import (scheme base) (scheme complex))

(make-rectangular 3 4)   ;; => 3+4i
(real-part 3+4i)         ;; => 3
(imag-part 3+4i)         ;; => 4
(magnitude 3+4i)         ;; => 5.0
(angle 0+1i)             ;; => 1.5707963267948966  (π/2)
```

`make-polar` builds a complex number from a magnitude and angle.

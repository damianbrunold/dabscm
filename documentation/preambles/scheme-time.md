## Overview

`(scheme time)` provides the R7RS time primitives: the current wall-clock time in
seconds, and a high-resolution monotonic "jiffy" counter for measuring elapsed
time.

## Common uses

```scheme
(import (scheme base) (scheme time))

(current-second)        ;; => seconds since the epoch (an inexact number)

;; measure elapsed time
(let ((start (current-jiffy)))
  (do-some-work)
  (/ (- (current-jiffy) start) (jiffies-per-second)))   ;; => elapsed seconds
```

`jiffies-per-second` gives the resolution of the jiffy clock.

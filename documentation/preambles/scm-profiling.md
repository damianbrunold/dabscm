## Overview

`(scm profiling)` measures where time goes: instrument procedures, run your
workload, then read or print a report of call counts and timings. Uninstrument to
restore normal execution.

## Common uses

```scheme
(import (scm profiling))

(profile-reset!)
(profile-instrument!)      ;; start collecting
;; ... run the code you want to measure ...
(profile-report)           ;; print a report
(profile-uninstrument!)    ;; stop collecting
```

`profile-data` returns the raw measurements if you'd rather format them yourself.

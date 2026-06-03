# `(scheme time)`

Timestamps and time formatting

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


## Exports

### `current-jiffy`

```
Syntax: (%jiffy)
Library: (scm core)
Description: Internal primitive. Returns the number of microseconds elapsed since the Unix epoch (1970-01-01 00:00:00 UTC).
Example:
  (%jiffy) => 1700000000000000
```

### `current-second`

```
Syntax: (current-second)
Library: (scheme time)
Description: Returns an inexact real number representing the current time
measured in seconds since the Unix epoch (January 1, 1970 00:00:00 UTC).
The value is derived from current-jiffy divided by jiffies-per-second.
Example:
  (current-second) => 1710000000.123456
```

### `jiffies-per-second`

```
Syntax: (jiffies-per-second)
Library: (scheme time)
Description: Returns the number of jiffies per second as an exact integer.
A jiffy is an implementation-defined unit of time. In this implementation
one jiffy equals one microsecond, so jiffies-per-second returns 1000000.
Example:
  (jiffies-per-second) => 1000000
```


## Overview

SRFI-19 is the time and date library: time and date data types, conversions
between them (and Julian Day / Modified Julian Day), and flexible parsing and
formatting. For lightweight epoch-seconds work see `(scm datetime)`; reach for
SRFI-19 when you need full calendar/timezone handling.

## Common uses

```scheme
(import (srfi 19))

(define d (make-date 0 0 0 12 1 1 2024 0))   ;; nsec sec min hour day month year tz
(date->string d "~Y-~m-~d")                   ;; => "2024-01-01"

(current-date)        ;; the current date
(current-time)        ;; the current time
```

Conversions include `time->date`, `date->time-utc`, `date->julian-day`, and the
`string->date` parser with `~`-directives.

# `(srfi 19)`

SRFI-19 — Time data types and procedures: time, date, Julian Day, formatting

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


## Exports

### `add-duration`

```
Syntax: (add-duration time duration)
Library: (srfi 19)
Description: Returns a new time by adding a time-duration to time.
Example:
  (time-second (add-duration (make-time time-utc 0 100) (make-time time-duration 0 50))) => 150
```

### `add-duration!`

```
Syntax: (add-duration! time duration)
Library: (srfi 19)
Description: Like add-duration, but may modify and return time.
Example:
  (time-second (add-duration! (make-time time-utc 0 100) (make-time time-duration 0 50))) => 150
```

### `copy-time`

```
Syntax: (copy-time time)
Library: (srfi 19)
Description: Returns a new time object with the same type, second, and nanosecond as time.
Example:
  (let ((t (make-time time-utc 0 100))) (time=? t (copy-time t))) => #t
```

### `current-date`

```
Syntax: (current-date [tz-offset])
Library: (srfi 19)
Description: Returns the current date. If tz-offset is not given, the local timezone is used.
Example:
  (date? (current-date)) => #t
```

### `current-julian-day`

```
Syntax: (current-julian-day)
Library: (srfi 19)
Description: Returns the current Julian Day.
```

### `current-modified-julian-day`

```
Syntax: (current-modified-julian-day)
Library: (srfi 19)
Description: Returns the current Modified Julian Day.
```

### `current-time`

```
Syntax: (current-time [time-type])
Library: (srfi 19)
Description: Returns the current time as a time object. Default type is time-utc.
Example:
  (time? (current-time)) => #t
  (time-type (current-time time-tai)) => time-tai
```

### `date->julian-day`

```
Syntax: (date->julian-day date)
Library: (srfi 19)
Description: Returns the Julian Day for the given date as a real number.
Example:
  (date->julian-day (make-date 0 0 0 12 1 1 2000 0)) => 2451545
```

### `date->modified-julian-day`

```
Syntax: (date->modified-julian-day date)
Library: (srfi 19)
Description: Returns the Modified Julian Day for the given date.
Example:
  (date->modified-julian-day (make-date 0 0 0 12 1 1 2000 0)) => 51544.5
```

### `date->string`

```
Syntax: (date->string date [format-string])
Library: (srfi 19)
Description: Formats a date as a string. Uses ~-prefixed directives:
  ~Y year, ~m month, ~d day, ~H hour, ~M minute, ~S second, ~N nanosecond,
  ~z timezone, ~a abbreviated weekday, ~A full weekday, ~b abbreviated month,
  ~B full month, ~1 ISO date, ~2 ISO time+tz, ~3 ISO time, ~4 ISO date+time+tz,
  ~5 ISO date+time, ~~ literal tilde.
  Default format is "~c" (locale date and time).
Example:
  (date->string (make-date 0 30 15 14 28 3 2026 3600) "~Y-~m-~d") => "2026-03-28"
```

### `date->time-monotonic`

```
Syntax: (date->time-monotonic date)
Library: (srfi 19)
Description: Converts a date to a time-monotonic.
Example:
  (time-type (date->time-monotonic (current-date))) => time-monotonic
```

### `date->time-tai`

```
Syntax: (date->time-tai date)
Library: (srfi 19)
Description: Converts a date to a time-tai.
Example:
  (time-type (date->time-tai (current-date))) => time-tai
```

### `date->time-utc`

```
Syntax: (date->time-utc date)
Library: (srfi 19)
Description: Converts a date to a time-utc.
Example:
  (time-second (date->time-utc (make-date 0 0 0 0 1 1 1970 0))) => 0
```

### `date-day`

*(no documentation)*

### `date-hour`

*(no documentation)*

### `date-minute`

*(no documentation)*

### `date-month`

*(no documentation)*

### `date-nanosecond`

*(no documentation)*

### `date-second`

*(no documentation)*

### `date-week-day`

```
Syntax: (date-week-day date)
Library: (srfi 19)
Description: Returns the day of the week (0=Sunday, 6=Saturday).
Example:
  (date-week-day (make-date 0 0 0 0 28 3 2026 0)) => 6
```

### `date-week-number`

```
Syntax: (date-week-number date day-of-week-starting)
Library: (srfi 19)
Description: Returns the week number of the year. day-of-week-starting is 0 for Sunday, 1 for Monday.
Example:
  (date-week-number (make-date 0 0 0 0 1 1 2026 0) 0) => 0
```

### `date-year`

*(no documentation)*

### `date-year-day`

```
Syntax: (date-year-day date)
Library: (srfi 19)
Description: Returns the day of the year (1-366).
Example:
  (date-year-day (make-date 0 0 0 0 1 3 2000 0)) => 61
```

### `date-zone-offset`

*(no documentation)*

### `date?`

```
Syntax: (date? obj)
Library: (srfi 19)
Description: Returns #t if obj is a date object, #f otherwise.
Example:
  (date? (current-date)) => #t
```

### `julian-day->date`

```
Syntax: (julian-day->date jd [tz-offset])
Library: (srfi 19)
Description: Converts a Julian Day to a date.
Example:
  (date-year (julian-day->date 2451545 0)) => 2000
```

### `julian-day->time-monotonic`

```
Syntax: (julian-day->time-monotonic jd)
Library: (srfi 19)
Description: Converts a Julian Day to a time-monotonic.
```

### `julian-day->time-tai`

```
Syntax: (julian-day->time-tai jd)
Library: (srfi 19)
Description: Converts a Julian Day to a time-tai.
```

### `julian-day->time-utc`

```
Syntax: (julian-day->time-utc jd)
Library: (srfi 19)
Description: Converts a Julian Day to a time-utc.
Example:
  (time-second (julian-day->time-utc 2440587.5)) => 0
```

### `make-date`

```
Syntax: (make-date nanosecond second minute hour day month year zone-offset)
Library: (srfi 19)
Description: Creates a date object. All fields are integers. zone-offset is seconds from UTC.
Example:
  (date-year (make-date 0 30 15 14 28 3 2026 3600)) => 2026
```

### `make-time`

```
Syntax: (make-time type nanosecond second)
Library: (srfi 19)
Description: Creates a time object. type must be a time type constant (e.g. time-utc). second and nanosecond must be integers.
Example:
  (make-time time-utc 0 1000000000)
```

### `modified-julian-day->date`

```
Syntax: (modified-julian-day->date mjd [tz-offset])
Library: (srfi 19)
Description: Converts a Modified Julian Day to a date.
```

### `modified-julian-day->time-monotonic`

```
Syntax: (modified-julian-day->time-monotonic mjd)
Library: (srfi 19)
Description: Converts a Modified Julian Day to a time-monotonic.
```

### `modified-julian-day->time-tai`

```
Syntax: (modified-julian-day->time-tai mjd)
Library: (srfi 19)
Description: Converts a Modified Julian Day to a time-tai.
```

### `modified-julian-day->time-utc`

```
Syntax: (modified-julian-day->time-utc mjd)
Library: (srfi 19)
Description: Converts a Modified Julian Day to a time-utc.
```

### `set-time-nanosecond!`

*(no documentation)*

### `set-time-second!`

*(no documentation)*

### `set-time-type!`

*(no documentation)*

### `string->date`

```
Syntax: (string->date input-string template-string)
Library: (srfi 19)
Description: Parses a date string according to the template. Supported directives for parsing:
  ~Y year, ~m month, ~d day, ~H hour, ~M minute, ~S second, ~y 2-digit year,
  ~b/~B/~h month name, ~a/~A weekday name (consumed but ignored),
  ~e space-padded day, ~k space-padded hour, ~z timezone offset, ~~ literal tilde.
Example:
  (date-year (string->date "2026-03-28" "~Y-~m-~d")) => 2026
```

### `subtract-duration`

```
Syntax: (subtract-duration time duration)
Library: (srfi 19)
Description: Returns a new time by subtracting a time-duration from time.
Example:
  (time-second (subtract-duration (make-time time-utc 0 200) (make-time time-duration 0 50))) => 150
```

### `subtract-duration!`

```
Syntax: (subtract-duration! time duration)
Library: (srfi 19)
Description: Like subtract-duration, but may modify and return time.
Example:
  (time-second (subtract-duration! (make-time time-utc 0 200) (make-time time-duration 0 50))) => 150
```

### `time-difference`

```
Syntax: (time-difference t1 t2)
Library: (srfi 19)
Description: Returns a time-duration representing t1 - t2. Both must have the same time type.
Example:
  (time-second (time-difference (make-time time-utc 0 200) (make-time time-utc 0 100))) => 100
```

### `time-difference!`

```
Syntax: (time-difference! t1 t2)
Library: (srfi 19)
Description: Like time-difference, but may modify and return t1.
Example:
  (time-second (time-difference! (make-time time-utc 0 200) (make-time time-utc 0 100))) => 100
```

### `time-duration`

*(no documentation)*

### `time-monotonic`

*(no documentation)*

### `time-monotonic->date`

```
Syntax: (time-monotonic->date time [tz-offset])
Library: (srfi 19)
Description: Converts a time-monotonic to a date.
Example:
  (date? (time-monotonic->date (time-utc->time-monotonic (current-time)))) => #t
```

### `time-monotonic->julian-day`

```
Syntax: (time-monotonic->julian-day time)
Library: (srfi 19)
Description: Converts a time-monotonic to a Julian Day.
```

### `time-monotonic->modified-julian-day`

```
Syntax: (time-monotonic->modified-julian-day time)
Library: (srfi 19)
Description: Converts a time-monotonic to a Modified Julian Day.
```

### `time-monotonic->time-tai`

```
Syntax: (time-monotonic->time-tai time)
Library: (srfi 19)
Description: Converts a time-monotonic to time-tai (via UTC).
Example:
  (time-type (time-monotonic->time-tai (make-time time-monotonic 0 100))) => time-tai
```

### `time-monotonic->time-tai!`

```
Syntax: (time-monotonic->time-tai! time)
Library: (srfi 19)
Description: Like time-monotonic->time-tai, but may modify and return time.
```

### `time-monotonic->time-utc`

```
Syntax: (time-monotonic->time-utc time)
Library: (srfi 19)
Description: Converts a time-monotonic to time-utc (same value, different type).
Example:
  (time-type (time-monotonic->time-utc (make-time time-monotonic 0 100))) => time-utc
```

### `time-monotonic->time-utc!`

```
Syntax: (time-monotonic->time-utc! time)
Library: (srfi 19)
Description: Like time-monotonic->time-utc, but may modify and return time.
```

### `time-nanosecond`

*(no documentation)*

### `time-process`

*(no documentation)*

### `time-resolution`

```
Syntax: (time-resolution [time-type])
Library: (srfi 19)
Description: Returns the clock resolution in nanoseconds for the given time type.
Example:
  (time-resolution time-utc) => 100
```

### `time-second`

*(no documentation)*

### `time-tai`

*(no documentation)*

### `time-tai->date`

```
Syntax: (time-tai->date time [tz-offset])
Library: (srfi 19)
Description: Converts a time-tai to a date. Correctly handles leap seconds
  by producing date-second = 60 when the TAI time falls on a leap second.
Example:
  (date? (time-tai->date (time-utc->time-tai (current-time)))) => #t
```

### `time-tai->julian-day`

```
Syntax: (time-tai->julian-day time)
Library: (srfi 19)
Description: Converts a time-tai to a Julian Day.
```

### `time-tai->modified-julian-day`

```
Syntax: (time-tai->modified-julian-day time)
Library: (srfi 19)
Description: Converts a time-tai to a Modified Julian Day.
```

### `time-tai->time-monotonic`

```
Syntax: (time-tai->time-monotonic time)
Library: (srfi 19)
Description: Converts a time-tai to time-monotonic (via UTC).
Example:
  (time-type (time-tai->time-monotonic (make-time time-tai 0 100))) => time-monotonic
```

### `time-tai->time-monotonic!`

```
Syntax: (time-tai->time-monotonic! time)
Library: (srfi 19)
Description: Like time-tai->time-monotonic, but may modify and return time.
```

### `time-tai->time-utc`

```
Syntax: (time-tai->time-utc time)
Library: (srfi 19)
Description: Converts a time-tai to time-utc.
Example:
  (time-type (time-tai->time-utc (make-time time-tai 0 1500000037))) => time-utc
```

### `time-tai->time-utc!`

```
Syntax: (time-tai->time-utc! time)
Library: (srfi 19)
Description: Like time-tai->time-utc, but may modify and return time.
```

### `time-thread`

*(no documentation)*

### `time-type`

*(no documentation)*

### `time-utc`

*(no documentation)*

### `time-utc->date`

```
Syntax: (time-utc->date time [tz-offset])
Library: (srfi 19)
Description: Converts a time-utc to a date. If tz-offset is not given, the local timezone is used.
Example:
  (date-year (time-utc->date (make-time time-utc 0 946684800) 0)) => 2000
```

### `time-utc->julian-day`

```
Syntax: (time-utc->julian-day time)
Library: (srfi 19)
Description: Converts a time-utc to a Julian Day.
```

### `time-utc->modified-julian-day`

```
Syntax: (time-utc->modified-julian-day time)
Library: (srfi 19)
Description: Converts a time-utc to a Modified Julian Day.
```

### `time-utc->time-monotonic`

```
Syntax: (time-utc->time-monotonic time)
Library: (srfi 19)
Description: Converts a time-utc to time-monotonic (same value, different type).
Example:
  (time-type (time-utc->time-monotonic (make-time time-utc 0 100))) => time-monotonic
```

### `time-utc->time-monotonic!`

```
Syntax: (time-utc->time-monotonic! time)
Library: (srfi 19)
Description: Like time-utc->time-monotonic, but may modify and return time.
```

### `time-utc->time-tai`

```
Syntax: (time-utc->time-tai time)
Library: (srfi 19)
Description: Converts a time-utc to time-tai.
Example:
  (time-type (time-utc->time-tai (make-time time-utc 0 1500000000))) => time-tai
```

### `time-utc->time-tai!`

```
Syntax: (time-utc->time-tai! time)
Library: (srfi 19)
Description: Like time-utc->time-tai, but may modify and return time.
```

### `time<=?`

```
Syntax: (time<=? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 is before or equal to t2. Both must have the same time type.
Example:
  (time<=? (make-time time-utc 0 100) (make-time time-utc 0 100)) => #t
```

### `time<?`

```
Syntax: (time<? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 is before t2. Both must have the same time type.
Example:
  (time<? (make-time time-utc 0 100) (make-time time-utc 0 200)) => #t
```

### `time=?`

```
Syntax: (time=? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 and t2 represent the same time. Both must have the same time type.
Example:
  (time=? (make-time time-utc 0 100) (make-time time-utc 0 100)) => #t
```

### `time>=?`

```
Syntax: (time>=? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 is after or equal to t2. Both must have the same time type.
Example:
  (time>=? (make-time time-utc 0 100) (make-time time-utc 0 100)) => #t
```

### `time>?`

```
Syntax: (time>? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 is after t2. Both must have the same time type.
Example:
  (time>? (make-time time-utc 0 200) (make-time time-utc 0 100)) => #t
```

### `time?`

```
Syntax: (time? obj)
Library: (srfi 19)
Description: Returns #t if obj is a SRFI-19 time object, #f otherwise.
Example:
  (time? (current-time)) => #t
```


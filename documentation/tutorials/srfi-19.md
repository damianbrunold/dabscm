---
title: SRFI 19: time and dates
part: libraries
order: 19
libraries: (srfi 19)
summary: Time objects and their types, durations and differences, dates with fields and time zones, formatting and parsing with ~ directives, Julian days, week numbers; a meeting planner across time zones.
---
# SRFI 19: time and dates

SRFI 19 separates *times* (a point or a span, in seconds and nanoseconds)
from *dates* (year, month, day, hour … in a time zone). The
[dates and times](techniques-07-dates.md) chapter covers the everyday
tasks; this one goes through the library.

```scheme
(import (scheme base) (srfi 19))
```

## Times

A time has a type, seconds and nanoseconds:

```scheme
(define t (make-time time-utc 500000000 1700000000))
(time-type t)                         ;; => time-utc
(time-second t)                       ;; => 1700000000
(time-nanosecond t)                   ;; => 500000000
(time? (current-time))                ;; => #t
(eq? (time-type (current-time time-monotonic)) time-monotonic) ;; => #t
```

| type | meaning |
|---|---|
| `time-utc` | seconds since 1970-01-01 UTC (wall clock) |
| `time-tai` | atomic time, without leap-second jumps |
| `time-monotonic` | for measuring intervals; never goes backwards |
| `time-duration` | a span of time, not a point |

## Durations and differences

```scheme
(define start (make-time time-utc 0 1000))
(define end (make-time time-utc 250000000 1090))
(define d (time-difference end start))
(time-type d)                         ;; => time-duration
(time-second d)                       ;; => 90
(time-nanosecond d)                   ;; => 250000000

(define hour (make-time time-duration 0 3600))
(time-second (add-duration start hour))      ;; => 4600
(time-second (subtract-duration start hour)) ;; => -2600
(time<? start end)                    ;; => #t
```

## Dates

`make-date` takes nanoseconds, seconds, minutes, hours, day, month, year and
the zone offset in seconds east of UTC:

```scheme
(define landing (make-date 0 17 56 20 20 7 1969 0))   ; UTC
(date-year landing)                   ;; => 1969
(date-hour landing)                   ;; => 20
(date-week-day landing)               ;; => 0
(date-year-day landing)               ;; => 201
(date-zone-offset landing)            ;; => 0
```

Converting between times and dates, also into another zone:

```scheme
(define landing-utc (date->time-utc landing))
(time-second landing-utc)             ;; => -14180623
(define in-houston (time-utc->date landing-utc (* -5 3600)))
(list (date-hour in-houston) (date-minute in-houston)) ;; => (15 56)
```

The same moment is 20:56 in UTC and 15:56 in Houston (UTC−5 in July 1969).

## Formatting

`date->string` uses `~` directives:

```scheme
(date->string landing "~Y-~m-~d")     ;; => "1969-07-20"
(date->string landing "~H:~M:~S")     ;; => "20:56:17"
(date->string landing "~A ~d ~B ~Y")  ;; => "Sunday 20 July 1969"
(date->string landing "~a ~b ~e")     ;; => "Sun Jul 20"
(date->string landing "~5")           ;; => "1969-07-20T20:56:17"
(date->string landing "day ~j of the year") ;; => "day 201 of the year"
```

Common directives: `~Y` year, `~m` month, `~d` day, `~H` hour, `~M`
minute, `~S` second, `~A`/`~a` weekday name, `~B`/`~b` month name, `~j`
day of the year, `~z` zone offset, `~5` ISO 8601 date and time.

## Parsing

`string->date` reads a date with the same directives:

```scheme
(define d1 (string->date "2025-11-27 14:30" "~Y-~m-~d ~H:~M"))
(list (date-year d1) (date-month d1) (date-day d1) (date-hour d1)) ;; => (2025 11 27 14)
```

## Julian days

The Julian day number counts days since a fixed point in 4713 BC, which
makes it the easy way to compute with calendar days:

```scheme
(define (jd y m d) (exact (round (date->julian-day (make-date 0 0 0 12 d m y 0)))))
(jd 2000 1 1)                         ;; => 2451545
(- (jd 2025 12 24) (jd 2025 1 1))     ;; => 357
(date->string (julian-day->date 2451545 0) "~Y-~m-~d") ;; => "2000-01-01"
```

## Example: a meeting across time zones

When is 09:00 in Zürich (UTC+1 in winter) in New York (UTC−5) and Tokyo
(UTC+9)?

```scheme
(define zones '(("Zürich" . 3600) ("New York" . -18000) ("Tokyo" . 32400)))

(define (meeting-times y m d hour minute home-offset)
  (let ((t (date->time-utc (make-date 0 0 minute hour d m y home-offset))))
    (map (lambda (z)
           (cons (car z) (date->string (time-utc->date t (cdr z)) "~a ~H:~M")))
         zones)))

(meeting-times 2025 12 3 9 0 3600)
;; => (("Zürich" . "Wed 09:00") ("New York" . "Wed 03:00") ("Tokyo" . "Wed 17:00"))
```

Fixed offsets ignore daylight saving time; for dates in summer, use the
summer offsets.

## Where next

- [Dates and times](techniques-07-dates.md) for ISO 8601 and durations.
- Reference: `(srfi 19)`.

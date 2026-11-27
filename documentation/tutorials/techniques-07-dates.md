---
title: Dates and times
part: techniques
order: 7
libraries: (srfi 19) (scm datetime) (scm duration)
summary: Parsing and formatting ISO 8601 and RFC 822 timestamps, date arithmetic with Julian days, weekdays, durations, measuring elapsed time.
---
# Dates and times

Two libraries cover dates:

- `(scm datetime)` works with *epoch seconds* (seconds since 1970-01-01 UTC):
  parsing and formatting ISO 8601 and RFC 822 timestamps, as found in logs,
  APIs and feeds;
- `(srfi 19)` has date records with fields, formatting with `~` directives,
  Julian days for date arithmetic, and time differences.

`(scm duration)` reads and writes durations like `90m` or `2d`.

```scheme
(import (scheme base) (srfi 19) (scm datetime) (scm duration))
```

## Timestamps as epoch seconds

```scheme
(parse-iso8601 "2024-05-16T12:34:56Z")             ;; => 1715862896
(parse-iso8601 "2024-05-16T14:34:56+02:00")        ;; => 1715862896
(parse-rfc822 "Thu, 16 May 2024 12:34:56 +0000")   ;; => 1715862896
(format-iso8601 1715862896)                        ;; => "2024-05-16T12:34:56Z"
```

The two ISO strings above are the same moment written in two time zones,
so they give the same number. Epoch seconds are the easiest form to store,
compare and subtract:

```scheme
(define start (parse-iso8601 "2024-05-16T08:00:00Z"))
(define end (parse-iso8601 "2024-05-16T17:30:00Z"))
(- end start)                                      ;; => 34200
(/ (- end start) 3600)                             ;; => 19/2
(format-iso8601 (+ start (* 3 24 3600)))           ;; => "2024-05-19T08:00:00Z"
```

## Durations

```scheme
(parse-duration "90")                              ;; => 90
(parse-duration "15m")                             ;; => 900
(parse-duration "2h")                              ;; => 7200
(parse-duration "3d")                              ;; => 259200
(parse-duration "soon")                            ;; => #f
(format-duration 7200)                             ;; => "2h"
(format-duration 90)                               ;; => "90s"
```

Configuration files often give timeouts and intervals this way.

## Dates with fields: SRFI 19

`make-date` takes nanoseconds, seconds, minutes, hours, day, month, year and
the time-zone offset in seconds:

```scheme
(define launch (make-date 0 0 30 9 20 7 1969 0))

(date-year launch)                                 ;; => 1969
(date-month launch)                                ;; => 7
(date->string launch "~Y-~m-~d ~H:~M")             ;; => "1969-07-20 09:30"
(date-week-day launch)                             ;; => 0
(date->string launch "~A, ~d ~B ~Y")               ;; => "Sunday, 20 July 1969"
```

`date-week-day` counts from Sunday (0) to Saturday (6).

## Date arithmetic with Julian days

The *Julian day* counts days continuously, which turns date arithmetic into
integer arithmetic:

```scheme
(define (date->day d) (exact (floor (date->julian-day d))))
(define (ymd y m d) (make-date 0 0 0 12 d m y 0))

(- (date->day (ymd 2025 12 25)) (date->day (ymd 2025 11 27))) ;; => 28

(define (add-days d n)
  (julian-day->date (+ (date->julian-day d) n) 0))

(date->string (add-days (ymd 2024 2 27) 3) "~Y-~m-~d") ;; => "2024-03-01"
(date->string (add-days (ymd 2023 2 27) 3) "~Y-~m-~d") ;; => "2023-03-02"
```

The two results differ because 2024 is a leap year. Creating dates at noon
(hour 12) keeps rounding away from midnight boundaries.

### Example: working days

Count the weekdays between two dates, inclusive:

```scheme
(define (working-days from to)
  (let loop ((d from) (n 0))
    (if (> (date->day d) (date->day to))
        n
        (loop (add-days d 1)
              (if (memv (date-week-day d) '(0 6)) n (+ n 1))))))

(working-days (ymd 2025 12 1) (ymd 2025 12 31))   ;; => 23
```

### Example: age in years

```scheme
(define (age-on birth on)
  (let ((years (- (date-year on) (date-year birth))))
    (if (or (< (date-month on) (date-month birth))
            (and (= (date-month on) (date-month birth))
                 (< (date-day on) (date-day birth))))
        (- years 1)
        years)))

(age-on (ymd 1815 12 10) (ymd 1852 11 27))        ;; => 36
```

## Converting between the two

```scheme
(define (date->epoch d) (time-second (date->time-utc d)))
(define (epoch->date secs) (time-utc->date (make-time time-utc 0 secs) 0))

(date->epoch (ymd 2024 5 16))                      ;; => 1715860800
(date->string (epoch->date 1715862896) "~Y-~m-~d ~H:~M:~S") ;; => "2024-05-16 12:34:56"
```

## The current time and elapsed time

```scheme no-test
(now)                       ; epoch seconds, now
(current-date)              ; an SRFI 19 date in the local time zone
(date->string (current-date) "~Y-~m-~d")
```

To measure how long something takes, use `current-jiffy` from
`(scheme time)`:

```scheme
(import (scheme time))

(define (time-it thunk)
  (let ((start (current-jiffy)))
    (thunk)
    (/ (- (current-jiffy) start) (jiffies-per-second))))

(define (sum-below n) (let loop ((i 0) (s 0)) (if (= i n) s (loop (+ i 1) (+ s i)))))

(real? (time-it (lambda () (sum-below 100000))))   ;; => #t
```

## Where next

- [Structured data: JSON, XML, TOML, CSV](techniques-08-structured-data.md).
- [SRFI 19](srfi-19.md), `(scm datetime)`, `(scm duration)`.

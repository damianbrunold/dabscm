---
title: (scm datetime) and (scm duration): timestamps and durations
part: libraries
order: 1014
libraries: (scm datetime) (scm duration)
summary: Epoch seconds from ISO 8601, RFC 822 and compact formats, formatting, the clock (now, today, time, timestamps), durations like 15m and 2d; a feed-age filter.
---
# (scm datetime) and (scm duration): timestamps and durations

`(scm datetime)` works with timestamps as numbers: *epoch seconds*
(seconds since 1970-01-01 UTC) for exchange formats, and *timestamps* in
milliseconds for the clock. `(scm duration)` reads and writes durations.
For calendars and date arithmetic, see [SRFI 19](srfi-19.md) and the
[dates and times](techniques-07-dates.md) chapter.

```scheme
(import (scheme base) (scm datetime) (scm duration))
```

## Parsing

```scheme
(parse-iso8601 "2024-05-16T12:34:56Z")                 ;; => 1715862896
(parse-iso8601 "2024-05-16T14:34:56+02:00")            ;; => 1715862896
(parse-rfc822 "Thu, 16 May 2024 12:34:56 GMT")         ;; => 1715862896
(parse-pubdate "Thu, 16 May 2024 12:34:56 +0000")      ;; => 1715862896
(parse-pubdate "2024-05-16T12:34:56Z")                 ;; => 1715862896
(string->date-seconds "20240516123456")                ;; => 1715862896
(string->date-seconds "garbage")                       ;; => #f
```

- ISO 8601 is what JSON APIs use, RFC 822 what e-mail and RSS use;
- `parse-pubdate` accepts either, which is what feed readers need;
- `string->date-seconds` reads compact `yyyyMMddHHmmss` stamps (also
  shorter ones down to `yyyyMMdd`), common in file names and exports.

## Formatting

```scheme
(format-iso8601 1715862896)                            ;; => "2024-05-16T12:34:56Z"
(format-iso8601 0)                                     ;; => "1970-01-01T00:00:00Z"
```

## The clock

```scheme
(string-length (now))                                  ;; => 16
(string-length (today))                                ;; => 10
(string-length (today 'short))                         ;; => 8
(string-length (time))                                 ;; => 5
(integer? (timestamp))                                 ;; => #t
```

- `now` is the local date and time as `"2025-11-27 14:03"` (`'short`
  gives `"20251127-1403"`);
- `today` is the local date as `"2025-11-27"` (`'short` gives `"20251127"`,
  `'dmy` gives `"27.11.2025"`);
- `time` is the local time as `"14:03"`;
- `timestamp` is milliseconds (counted from the year 1, not 1970), for
  measuring and for `timestamp->string`.

For the current time in epoch seconds, use `current-second` from
`(scheme time)`:

```scheme
(import (scheme time))
(define (epoch-now) (exact (floor (current-second))))
(> (epoch-now) (parse-iso8601 "2024-01-01T00:00:00Z")) ;; => #t
```

## Durations

```scheme
(parse-duration "30")                                  ;; => 30
(parse-duration "15m")                                 ;; => 900
(parse-duration "12h")                                 ;; => 43200
(parse-duration "7d")                                  ;; => 604800
(parse-duration "1w")                                  ;; => #f
(format-duration 900)                                  ;; => "15m"
(format-duration 86400)                                ;; => "1d"
(format-duration 61)                                   ;; => "61s"
```

Units are `s`, `m`, `h` and `d`; a bare number is seconds.
`format-duration` picks the largest unit that divides evenly.

## Example: recent feed items

Keep the items of a feed that are newer than a configured age:

```scheme
(define items
  '(("Release 2.0" . "Thu, 16 May 2024 12:00:00 GMT")
    ("Bug fix" . "2024-05-15T09:30:00Z")
    ("Old news" . "Mon, 01 Jan 2024 08:00:00 GMT")))

(define (recent items max-age reference)
  (let ((limit (- reference (parse-duration max-age))))
    (filter-items (lambda (item) (>= (parse-pubdate (cdr item)) limit)) items)))

(define (filter-items keep? xs)
  (cond ((null? xs) '())
        ((keep? (car xs)) (cons (car xs) (filter-items keep? (cdr xs))))
        (else (filter-items keep? (cdr xs)))))

(map car (recent items "7d" (parse-iso8601 "2024-05-17T00:00:00Z")))
;; => ("Release 2.0" "Bug fix")
```

The reference time is a parameter, so the code can be tested without
depending on the real clock; in production, pass `(epoch-now)`.

## Where next

- [SRFI 19](srfi-19.md), [dates and times](techniques-07-dates.md), `(scm feed)`.
- Reference: `(scm datetime)`, `(scm duration)`.

(define-library (srfi 19)
  (import (scheme base) (scheme inexact) (scheme char) (scheme write))
  (export
    ;; Time type constants
    time-utc time-tai time-monotonic time-duration
    time-process time-thread
    ;; Time construction/predicate/accessors
    make-time time? time-type time-second time-nanosecond
    set-time-type! set-time-second! set-time-nanosecond!
    copy-time
    ;; Time comparisons
    time<=? time<? time=? time>=? time>?
    ;; Time arithmetic
    time-difference time-difference!
    add-duration add-duration!
    subtract-duration subtract-duration!
    ;; Date construction/predicate/accessors
    make-date date? date-nanosecond date-second date-minute date-hour
    date-day date-month date-year date-zone-offset
    date-year-day date-week-day date-week-number
    ;; Current time/date
    current-time current-date current-julian-day
    current-modified-julian-day time-resolution
    ;; Time conversions
    time-utc->time-tai time-utc->time-tai!
    time-utc->time-monotonic time-utc->time-monotonic!
    time-tai->time-utc time-tai->time-utc!
    time-tai->time-monotonic time-tai->time-monotonic!
    time-monotonic->time-utc time-monotonic->time-utc!
    time-monotonic->time-tai time-monotonic->time-tai!
    ;; Date/time conversions
    time-utc->date time-tai->date time-monotonic->date
    date->time-utc date->time-tai date->time-monotonic
    ;; Julian day conversions
    date->julian-day date->modified-julian-day
    time-utc->julian-day time-tai->julian-day time-monotonic->julian-day
    time-utc->modified-julian-day time-tai->modified-julian-day
    time-monotonic->modified-julian-day
    julian-day->time-utc julian-day->time-tai julian-day->time-monotonic
    julian-day->date
    modified-julian-day->time-utc modified-julian-day->time-tai
    modified-julian-day->time-monotonic
    modified-julian-day->date
    ;; Formatting
    date->string string->date)
  (begin

    ;; ======================================================================
    ;; Internal primitives
    ;; ======================================================================

    (define %current-nanosecond (%primitive "%current-nanosecond"))
    (define %local-tz-offset    (%primitive "%local-tz-offset"))
    (define %monotonic-nanosecond (%primitive "%monotonic-nanosecond"))
    (define %process-nanosecond (%primitive "%process-nanosecond"))
    (define %thread-nanosecond  (%primitive "%thread-nanosecond"))

    ;; ======================================================================
    ;; Time type constants
    ;; ======================================================================

    (define time-utc       'time-utc)
    (define time-tai       'time-tai)
    (define time-monotonic 'time-monotonic)
    (define time-duration  'time-duration)
    (define time-process   'time-process)
    (define time-thread    'time-thread)

    (define (%time-type? t)
      (or (eq? t time-utc) (eq? t time-tai) (eq? t time-monotonic)
          (eq? t time-duration) (eq? t time-process) (eq? t time-thread)))

    ;; ======================================================================
    ;; Time record type
    ;; ======================================================================

    (define-record-type <time>
      (%make-time type nanosecond second)
      %time?
      (type time-type set-time-type!)
      (nanosecond time-nanosecond set-time-nanosecond!)
      (second time-second set-time-second!))

    (define (time? obj)
      "Syntax: (time? obj)
Library: (srfi 19)
Description: Returns #t if obj is a SRFI-19 time object, #f otherwise.
Example:
  (time? (current-time)) => #t"
      (%time? obj))

    (define (make-time type nanosecond second)
      "Syntax: (make-time type nanosecond second)
Library: (srfi 19)
Description: Creates a time object. type must be a time type constant (e.g. time-utc). second and nanosecond must be integers.
Example:
  (make-time time-utc 0 1000000000)"
      (if (not (%time-type? type))
          (error "make-time: invalid time type" type))
      (%make-time type nanosecond second))

    (define (copy-time t)
      "Syntax: (copy-time time)
Library: (srfi 19)
Description: Returns a new time object with the same type, second, and nanosecond as time.
Example:
  (let ((t (make-time time-utc 0 100))) (time=? t (copy-time t))) => #t"
      (%make-time (time-type t) (time-nanosecond t) (time-second t)))

    ;; ======================================================================
    ;; Time comparisons
    ;; ======================================================================

    (define (%check-same-type t1 t2 who)
      (if (not (eq? (time-type t1) (time-type t2)))
          (error (string-append who ": time types differ")
                 (time-type t1) (time-type t2))))

    (define (time=? t1 t2)
      "Syntax: (time=? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 and t2 represent the same time. Both must have the same time type.
Example:
  (time=? (make-time time-utc 0 100) (make-time time-utc 0 100)) => #t"
      (%check-same-type t1 t2 "time=?")
      (and (= (time-second t1) (time-second t2))
           (= (time-nanosecond t1) (time-nanosecond t2))))

    (define (time<? t1 t2)
      "Syntax: (time<? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 is before t2. Both must have the same time type.
Example:
  (time<? (make-time time-utc 0 100) (make-time time-utc 0 200)) => #t"
      (%check-same-type t1 t2 "time<?")
      (or (< (time-second t1) (time-second t2))
          (and (= (time-second t1) (time-second t2))
               (< (time-nanosecond t1) (time-nanosecond t2)))))

    (define (time>? t1 t2)
      "Syntax: (time>? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 is after t2. Both must have the same time type.
Example:
  (time>? (make-time time-utc 0 200) (make-time time-utc 0 100)) => #t"
      (%check-same-type t1 t2 "time>?")
      (or (> (time-second t1) (time-second t2))
          (and (= (time-second t1) (time-second t2))
               (> (time-nanosecond t1) (time-nanosecond t2)))))

    (define (time<=? t1 t2)
      "Syntax: (time<=? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 is before or equal to t2. Both must have the same time type.
Example:
  (time<=? (make-time time-utc 0 100) (make-time time-utc 0 100)) => #t"
      (not (time>? t1 t2)))

    (define (time>=? t1 t2)
      "Syntax: (time>=? t1 t2)
Library: (srfi 19)
Description: Returns #t if t1 is after or equal to t2. Both must have the same time type.
Example:
  (time>=? (make-time time-utc 0 100) (make-time time-utc 0 100)) => #t"
      (not (time<? t1 t2)))

    ;; ======================================================================
    ;; Time arithmetic
    ;; ======================================================================

    (define %nano 1000000000)

    (define (%normalize-time! t)
      (let ((ns (time-nanosecond t))
            (s  (time-second t)))
        (cond
          ((>= ns %nano)
           (set-time-second! t (+ s (quotient ns %nano)))
           (set-time-nanosecond! t (remainder ns %nano)))
          ((< ns 0)
           (let* ((abs-ns (- ns))
                  (borrow (+ 1 (quotient abs-ns %nano))))
             (set-time-second! t (- s borrow))
             (set-time-nanosecond! t (+ ns (* borrow %nano)))))))
      t)

    (define (time-difference t1 t2)
      "Syntax: (time-difference t1 t2)
Library: (srfi 19)
Description: Returns a time-duration representing t1 - t2. Both must have the same time type.
Example:
  (time-second (time-difference (make-time time-utc 0 200) (make-time time-utc 0 100))) => 100"
      (%check-same-type t1 t2 "time-difference")
      (%normalize-time!
        (%make-time time-duration
                    (- (time-nanosecond t1) (time-nanosecond t2))
                    (- (time-second t1) (time-second t2)))))

    (define (time-difference! t1 t2)
      "Syntax: (time-difference! t1 t2)
Library: (srfi 19)
Description: Like time-difference, but may modify and return t1.
Example:
  (time-second (time-difference! (make-time time-utc 0 200) (make-time time-utc 0 100))) => 100"
      (%check-same-type t1 t2 "time-difference!")
      (set-time-type! t1 time-duration)
      (set-time-nanosecond! t1 (- (time-nanosecond t1) (time-nanosecond t2)))
      (set-time-second! t1 (- (time-second t1) (time-second t2)))
      (%normalize-time! t1))

    (define (add-duration t duration)
      "Syntax: (add-duration time duration)
Library: (srfi 19)
Description: Returns a new time by adding a time-duration to time.
Example:
  (time-second (add-duration (make-time time-utc 0 100) (make-time time-duration 0 50))) => 150"
      (if (not (eq? (time-type duration) time-duration))
          (error "add-duration: second argument must be time-duration" (time-type duration)))
      (%normalize-time!
        (%make-time (time-type t)
                    (+ (time-nanosecond t) (time-nanosecond duration))
                    (+ (time-second t) (time-second duration)))))

    (define (add-duration! t duration)
      "Syntax: (add-duration! time duration)
Library: (srfi 19)
Description: Like add-duration, but may modify and return time.
Example:
  (time-second (add-duration! (make-time time-utc 0 100) (make-time time-duration 0 50))) => 150"
      (if (not (eq? (time-type duration) time-duration))
          (error "add-duration!: second argument must be time-duration" (time-type duration)))
      (set-time-nanosecond! t (+ (time-nanosecond t) (time-nanosecond duration)))
      (set-time-second! t (+ (time-second t) (time-second duration)))
      (%normalize-time! t))

    (define (subtract-duration t duration)
      "Syntax: (subtract-duration time duration)
Library: (srfi 19)
Description: Returns a new time by subtracting a time-duration from time.
Example:
  (time-second (subtract-duration (make-time time-utc 0 200) (make-time time-duration 0 50))) => 150"
      (if (not (eq? (time-type duration) time-duration))
          (error "subtract-duration: second argument must be time-duration" (time-type duration)))
      (%normalize-time!
        (%make-time (time-type t)
                    (- (time-nanosecond t) (time-nanosecond duration))
                    (- (time-second t) (time-second duration)))))

    (define (subtract-duration! t duration)
      "Syntax: (subtract-duration! time duration)
Library: (srfi 19)
Description: Like subtract-duration, but may modify and return time.
Example:
  (time-second (subtract-duration! (make-time time-utc 0 200) (make-time time-duration 0 50))) => 150"
      (if (not (eq? (time-type duration) time-duration))
          (error "subtract-duration!: second argument must be time-duration" (time-type duration)))
      (set-time-nanosecond! t (- (time-nanosecond t) (time-nanosecond duration)))
      (set-time-second! t (- (time-second t) (time-second duration)))
      (%normalize-time! t))

    ;; ======================================================================
    ;; TAI-UTC Leap Second Table
    ;; ======================================================================

    ;; Each entry is (utc-seconds . cumulative-tai-offset)
    ;; utc-seconds is the UTC epoch second when the new offset took effect.
    ;; Data from IERS Bulletin C. Last leap second: 2017-01-01.
    (define %leap-second-table
      '((1483228800 . 37)   ;; 2017-01-01
        (1435708800 . 36)   ;; 2015-07-01
        (1341100800 . 35)   ;; 2012-07-01
        (1230768000 . 34)   ;; 2009-01-01
        (1136073600 . 33)   ;; 2006-01-01
        (915148800  . 32)   ;; 1999-01-01
        (867715200  . 31)   ;; 1997-07-01
        (820454400  . 30)   ;; 1996-01-01
        (773020800  . 29)   ;; 1994-07-01
        (741484800  . 28)   ;; 1993-07-01
        (709948800  . 27)   ;; 1992-07-01
        (662688000  . 26)   ;; 1991-01-01
        (631152000  . 25)   ;; 1990-01-01
        (567993600  . 24)   ;; 1988-01-01
        (489024000  . 23)   ;; 1985-07-01
        (425865600  . 22)   ;; 1983-07-01
        (394329600  . 21)   ;; 1982-07-01
        (362793600  . 20)   ;; 1981-07-01
        (315532800  . 19)   ;; 1980-01-01
        (283996800  . 18)   ;; 1979-01-01
        (252460800  . 17)   ;; 1978-01-01
        (220924800  . 16)   ;; 1977-01-01
        (189302400  . 15)   ;; 1976-01-01
        (157766400  . 14)   ;; 1975-01-01
        (126230400  . 13)   ;; 1974-01-01
        (94694400   . 12)   ;; 1973-01-01
        (78796800   . 11)   ;; 1972-07-01
        (63072000   . 10))) ;; 1972-01-01

    (define (%utc->tai-offset utc-second)
      ;; Returns the TAI-UTC offset for a given UTC second.
      (let loop ((table %leap-second-table))
        (cond
          ((null? table) 0)
          ((>= utc-second (caar table)) (cdar table))
          (else (loop (cdr table))))))

    (define (%tai->utc-offset tai-second)
      ;; Returns the TAI-UTC offset for a given TAI second.
      ;; Searches for the correct offset by checking the TAI equivalent.
      (let loop ((table %leap-second-table))
        (cond
          ((null? table) 0)
          ((>= tai-second (+ (caar table) (cdar table))) (cdar table))
          (else (loop (cdr table))))))

    ;; ======================================================================
    ;; Time type conversions
    ;; ======================================================================

    (define (time-utc->time-tai t)
      "Syntax: (time-utc->time-tai time)
Library: (srfi 19)
Description: Converts a time-utc to time-tai.
Example:
  (time-type (time-utc->time-tai (make-time time-utc 0 1500000000))) => time-tai"
      (let ((offset (%utc->tai-offset (time-second t))))
        (%make-time time-tai
                    (time-nanosecond t)
                    (+ (time-second t) offset))))

    (define (time-utc->time-tai! t)
      "Syntax: (time-utc->time-tai! time)
Library: (srfi 19)
Description: Like time-utc->time-tai, but may modify and return time."
      (let ((offset (%utc->tai-offset (time-second t))))
        (set-time-type! t time-tai)
        (set-time-second! t (+ (time-second t) offset))
        t))

    (define (time-tai->time-utc t)
      "Syntax: (time-tai->time-utc time)
Library: (srfi 19)
Description: Converts a time-tai to time-utc.
Example:
  (time-type (time-tai->time-utc (make-time time-tai 0 1500000037))) => time-utc"
      (let ((offset (%tai->utc-offset (time-second t))))
        (%make-time time-utc
                    (time-nanosecond t)
                    (- (time-second t) offset))))

    (define (time-tai->time-utc! t)
      "Syntax: (time-tai->time-utc! time)
Library: (srfi 19)
Description: Like time-tai->time-utc, but may modify and return time."
      (let ((offset (%tai->utc-offset (time-second t))))
        (set-time-type! t time-utc)
        (set-time-second! t (- (time-second t) offset))
        t))

    (define (time-utc->time-monotonic t)
      "Syntax: (time-utc->time-monotonic time)
Library: (srfi 19)
Description: Converts a time-utc to time-monotonic (same value, different type).
Example:
  (time-type (time-utc->time-monotonic (make-time time-utc 0 100))) => time-monotonic"
      (%make-time time-monotonic (time-nanosecond t) (time-second t)))

    (define (time-utc->time-monotonic! t)
      "Syntax: (time-utc->time-monotonic! time)
Library: (srfi 19)
Description: Like time-utc->time-monotonic, but may modify and return time."
      (set-time-type! t time-monotonic) t)

    (define (time-monotonic->time-utc t)
      "Syntax: (time-monotonic->time-utc time)
Library: (srfi 19)
Description: Converts a time-monotonic to time-utc (same value, different type).
Example:
  (time-type (time-monotonic->time-utc (make-time time-monotonic 0 100))) => time-utc"
      (%make-time time-utc (time-nanosecond t) (time-second t)))

    (define (time-monotonic->time-utc! t)
      "Syntax: (time-monotonic->time-utc! time)
Library: (srfi 19)
Description: Like time-monotonic->time-utc, but may modify and return time."
      (set-time-type! t time-utc) t)

    (define (time-tai->time-monotonic t)
      "Syntax: (time-tai->time-monotonic time)
Library: (srfi 19)
Description: Converts a time-tai to time-monotonic (via UTC).
Example:
  (time-type (time-tai->time-monotonic (make-time time-tai 0 100))) => time-monotonic"
      (time-utc->time-monotonic (time-tai->time-utc t)))

    (define (time-tai->time-monotonic! t)
      "Syntax: (time-tai->time-monotonic! time)
Library: (srfi 19)
Description: Like time-tai->time-monotonic, but may modify and return time."
      (time-tai->time-utc! t)
      (set-time-type! t time-monotonic)
      t)

    (define (time-monotonic->time-tai t)
      "Syntax: (time-monotonic->time-tai time)
Library: (srfi 19)
Description: Converts a time-monotonic to time-tai (via UTC).
Example:
  (time-type (time-monotonic->time-tai (make-time time-monotonic 0 100))) => time-tai"
      (time-utc->time-tai (time-monotonic->time-utc t)))

    (define (time-monotonic->time-tai! t)
      "Syntax: (time-monotonic->time-tai! time)
Library: (srfi 19)
Description: Like time-monotonic->time-tai, but may modify and return time."
      (set-time-type! t time-utc)
      (time-utc->time-tai! t))

    ;; ======================================================================
    ;; Current time
    ;; ======================================================================

    (define (current-time . args)
      "Syntax: (current-time [time-type])
Library: (srfi 19)
Description: Returns the current time as a time object. Default type is time-utc.
Example:
  (time? (current-time)) => #t
  (time-type (current-time time-tai)) => time-tai"
      (let ((type (if (null? args) time-utc (car args))))
        (cond
          ((eq? type time-utc)
           (let ((p (%current-nanosecond)))
             (%make-time time-utc (cdr p) (car p))))
          ((eq? type time-tai)
           (time-utc->time-tai (current-time time-utc)))
          ((eq? type time-monotonic)
           (let ((p (%monotonic-nanosecond)))
             (%make-time time-monotonic (cdr p) (car p))))
          ((eq? type time-process)
           (let ((p (%process-nanosecond)))
             (%make-time time-process (cdr p) (car p))))
          ((eq? type time-thread)
           (let ((p (%thread-nanosecond)))
             (%make-time time-thread (cdr p) (car p))))
          (else (error "current-time: invalid time type" type)))))

    (define (time-resolution . args)
      "Syntax: (time-resolution [time-type])
Library: (srfi 19)
Description: Returns the clock resolution in nanoseconds for the given time type.
Example:
  (time-resolution time-utc) => 100"
      (let ((type (if (null? args) time-utc (car args))))
        (cond
          ;; .NET ticks are 100ns; Java Instant has ~1ns on modern JVMs
          ((eq? type time-utc) 100)
          ((eq? type time-tai) 100)
          ((eq? type time-monotonic) 100)
          ((eq? type time-process) 100)
          ((eq? type time-thread) 100)
          ((eq? type time-duration) 100)
          (else (error "time-resolution: invalid time type" type)))))

    ;; ======================================================================
    ;; Date record type
    ;; ======================================================================

    (define-record-type <date>
      (%make-date nanosecond second minute hour day month year zone-offset)
      %date?
      (nanosecond date-nanosecond)
      (second     date-second)
      (minute     date-minute)
      (hour       date-hour)
      (day        date-day)
      (month      date-month)
      (year       date-year)
      (zone-offset date-zone-offset))

    (define (date? obj)
      "Syntax: (date? obj)
Library: (srfi 19)
Description: Returns #t if obj is a date object, #f otherwise.
Example:
  (date? (current-date)) => #t"
      (%date? obj))

    (define (make-date nanosecond second minute hour day month year zone-offset)
      "Syntax: (make-date nanosecond second minute hour day month year zone-offset)
Library: (srfi 19)
Description: Creates a date object. All fields are integers. zone-offset is seconds from UTC.
Example:
  (date-year (make-date 0 30 15 14 28 3 2026 3600)) => 2026"
      (%make-date nanosecond second minute hour day month year zone-offset))

    ;; ======================================================================
    ;; Julian Day calculations
    ;; ======================================================================

    ;; Gregorian date to Julian Day Number (integer, noon-based)
    ;; Using the algorithm from Meeus, "Astronomical Algorithms"
    (define (%encode-julian-day-number day month year)
      (let* ((a (quotient (- 14 month) 12))
             (y (+ year 4800 (- a)))
             (m (+ month (* 12 a) -3)))
        (+ day
           (quotient (+ (* 153 m) 2) 5)
           (* 365 y)
           (quotient y 4)
           (- (quotient y 100))
           (quotient y 400)
           -32045)))

    ;; Julian Day Number (integer) to Gregorian date (year month day)
    (define (%decode-julian-day-number jdn)
      (let* ((a (+ jdn 32044))
             (b (quotient (+ (* 4 a) 3) 146097))
             (c (- a (quotient (* 146097 b) 4)))
             (d (quotient (+ (* 4 c) 3) 1461))
             (e (- c (quotient (* 1461 d) 4)))
             (m (quotient (+ (* 5 e) 2) 153))
             (day   (+ e (- (quotient (+ (* 153 m) 2) 5)) 1))
             (month (+ m 3 (- (* 12 (quotient m 10)))))
             (year  (+ (* 100 b) d -4800 (quotient m 10))))
        (values year month day)))

    (define (date->julian-day d)
      "Syntax: (date->julian-day date)
Library: (srfi 19)
Description: Returns the Julian Day for the given date as a real number.
Example:
  (date->julian-day (make-date 0 0 0 12 1 1 2000 0)) => 2451545"
      (let* ((jdn (%encode-julian-day-number (date-day d) (date-month d) (date-year d)))
             (base (+ (- jdn 1/2)
                      (/ (- (date-hour d) (/ (date-zone-offset d) 3600)) 24)
                      (/ (date-minute d) 1440)
                      (/ (date-second d) 86400))))
        (if (zero? (date-nanosecond d))
            base
            (+ base (/ (date-nanosecond d) 86400000000000.0)))))

    (define (date->modified-julian-day d)
      "Syntax: (date->modified-julian-day date)
Library: (srfi 19)
Description: Returns the Modified Julian Day for the given date.
Example:
  (date->modified-julian-day (make-date 0 0 0 12 1 1 2000 0)) => 51544.5"
      (- (date->julian-day d) 4800001/2))

    ;; ======================================================================
    ;; Epoch and Julian Day constants
    ;; ======================================================================

    ;; Julian Day at Unix epoch (1970-01-01 00:00:00 UTC)
    (define %unix-epoch-jd 4881175/2)  ;; 2440587.5

    ;; ======================================================================
    ;; Date <-> Time conversions
    ;; ======================================================================

    (define (%time-utc->date-components utc-seconds utc-nanoseconds tz-offset)
      ;; Convert UTC epoch seconds + tz-offset to date components
      (let* ((local-seconds (+ utc-seconds tz-offset))
             (jd (+ %unix-epoch-jd (/ local-seconds 86400)))
             (jdn (exact (floor (+ jd 1/2))))  ;; JDN from JD (noon-based integer)
             (day-fraction (- jd (- jdn 1/2))) ;; fraction of day from midnight
             (day-seconds (exact (floor (* day-fraction 86400)))))
        (let-values (((year month day) (%decode-julian-day-number jdn)))
          (let* ((hour   (quotient day-seconds 3600))
                 (rem    (remainder day-seconds 3600))
                 (minute (quotient rem 60))
                 (second (remainder rem 60)))
            (%make-date utc-nanoseconds second minute hour day month year tz-offset)))))

    (define (time-utc->date t . args)
      "Syntax: (time-utc->date time [tz-offset])
Library: (srfi 19)
Description: Converts a time-utc to a date. If tz-offset is not given, the local timezone is used.
Example:
  (date-year (time-utc->date (make-time time-utc 0 946684800) 0)) => 2000"
      (let ((tz-offset (if (null? args) (%local-tz-offset) (car args))))
        (%time-utc->date-components (time-second t) (time-nanosecond t) tz-offset)))

    (define (time-tai->date t . args)
      "Syntax: (time-tai->date time [tz-offset])
Library: (srfi 19)
Description: Converts a time-tai to a date. Correctly handles leap seconds
  by producing date-second = 60 when the TAI time falls on a leap second.
Example:
  (date? (time-tai->date (time-utc->time-tai (current-time)))) => #t"
      (let* ((tz-offset (if (null? args) (%local-tz-offset) (car args)))
             (tai-second (time-second t))
             (tai-offset (%tai->utc-offset tai-second))
             (utc-second (- tai-second tai-offset))
             (utc-offset (%utc->tai-offset utc-second)))
        (if (> utc-offset tai-offset)
            ;; This TAI second is a leap second: display as second=60
            (let ((d (%time-utc->date-components (- utc-second 1)
                                                  (time-nanosecond t)
                                                  tz-offset)))
              (%make-date (date-nanosecond d) 60 (date-minute d)
                          (date-hour d) (date-day d) (date-month d)
                          (date-year d) (date-zone-offset d)))
            (%time-utc->date-components utc-second
                                         (time-nanosecond t)
                                         tz-offset))))

    (define (time-monotonic->date t . args)
      "Syntax: (time-monotonic->date time [tz-offset])
Library: (srfi 19)
Description: Converts a time-monotonic to a date.
Example:
  (date? (time-monotonic->date (time-utc->time-monotonic (current-time)))) => #t"
      (let ((utc (time-monotonic->time-utc t)))
        (apply time-utc->date utc args)))

    (define (date->time-utc d)
      "Syntax: (date->time-utc date)
Library: (srfi 19)
Description: Converts a date to a time-utc.
Example:
  (time-second (date->time-utc (make-date 0 0 0 0 1 1 1970 0))) => 0"
      (let* ((jd (date->julian-day d))
             (epoch-seconds (exact (round (* (- jd %unix-epoch-jd) 86400)))))
        (%make-time time-utc (date-nanosecond d) epoch-seconds)))

    (define (date->time-tai d)
      "Syntax: (date->time-tai date)
Library: (srfi 19)
Description: Converts a date to a time-tai.
Example:
  (time-type (date->time-tai (current-date))) => time-tai"
      (time-utc->time-tai (date->time-utc d)))

    (define (date->time-monotonic d)
      "Syntax: (date->time-monotonic date)
Library: (srfi 19)
Description: Converts a date to a time-monotonic.
Example:
  (time-type (date->time-monotonic (current-date))) => time-monotonic"
      (time-utc->time-monotonic (date->time-utc d)))

    ;; ======================================================================
    ;; Julian Day <-> Time conversions
    ;; ======================================================================

    (define (%jd->time-utc jd)
      (let* ((diff (- jd %unix-epoch-jd))
             (epoch-seconds (exact (floor (* diff 86400))))
             (frac-day (- diff (/ epoch-seconds 86400)))
             (nanos (exact (round (* frac-day 86400000000000.0)))))

        (%make-time time-utc nanos epoch-seconds)))

    (define (julian-day->time-utc jd)
      "Syntax: (julian-day->time-utc jd)
Library: (srfi 19)
Description: Converts a Julian Day to a time-utc.
Example:
  (time-second (julian-day->time-utc 2440587.5)) => 0"
      (%jd->time-utc jd))

    (define (julian-day->time-tai jd)
      "Syntax: (julian-day->time-tai jd)
Library: (srfi 19)
Description: Converts a Julian Day to a time-tai."
      (time-utc->time-tai (%jd->time-utc jd)))

    (define (julian-day->time-monotonic jd)
      "Syntax: (julian-day->time-monotonic jd)
Library: (srfi 19)
Description: Converts a Julian Day to a time-monotonic."
      (time-utc->time-monotonic (%jd->time-utc jd)))

    (define (julian-day->date jd . args)
      "Syntax: (julian-day->date jd [tz-offset])
Library: (srfi 19)
Description: Converts a Julian Day to a date.
Example:
  (date-year (julian-day->date 2451545 0)) => 2000"
      (let ((tz-offset (if (null? args) (%local-tz-offset) (car args))))
        (time-utc->date (%jd->time-utc jd) tz-offset)))

    (define (%time->jd t)
      ;; Use inexact for nanosecond contribution to avoid integer overflow
      ;; in exact rational arithmetic (86400000000000 as denominator overflows long).
      (let ((base (+ %unix-epoch-jd (/ (time-second t) 86400))))
        (if (zero? (time-nanosecond t))
            base
            (+ base (/ (time-nanosecond t) 86400000000000.0)))))

    (define (time-utc->julian-day t)
      "Syntax: (time-utc->julian-day time)
Library: (srfi 19)
Description: Converts a time-utc to a Julian Day."
      (%time->jd t))

    (define (time-tai->julian-day t)
      "Syntax: (time-tai->julian-day time)
Library: (srfi 19)
Description: Converts a time-tai to a Julian Day."
      (%time->jd (time-tai->time-utc t)))

    (define (time-monotonic->julian-day t)
      "Syntax: (time-monotonic->julian-day time)
Library: (srfi 19)
Description: Converts a time-monotonic to a Julian Day."
      (%time->jd (time-monotonic->time-utc t)))

    (define (time-utc->modified-julian-day t)
      "Syntax: (time-utc->modified-julian-day time)
Library: (srfi 19)
Description: Converts a time-utc to a Modified Julian Day."
      (- (time-utc->julian-day t) 4800001/2))

    (define (time-tai->modified-julian-day t)
      "Syntax: (time-tai->modified-julian-day time)
Library: (srfi 19)
Description: Converts a time-tai to a Modified Julian Day."
      (- (time-tai->julian-day t) 4800001/2))

    (define (time-monotonic->modified-julian-day t)
      "Syntax: (time-monotonic->modified-julian-day time)
Library: (srfi 19)
Description: Converts a time-monotonic to a Modified Julian Day."
      (- (time-monotonic->julian-day t) 4800001/2))

    (define (modified-julian-day->time-utc mjd)
      "Syntax: (modified-julian-day->time-utc mjd)
Library: (srfi 19)
Description: Converts a Modified Julian Day to a time-utc."
      (julian-day->time-utc (+ mjd 4800001/2)))

    (define (modified-julian-day->time-tai mjd)
      "Syntax: (modified-julian-day->time-tai mjd)
Library: (srfi 19)
Description: Converts a Modified Julian Day to a time-tai."
      (julian-day->time-tai (+ mjd 4800001/2)))

    (define (modified-julian-day->time-monotonic mjd)
      "Syntax: (modified-julian-day->time-monotonic mjd)
Library: (srfi 19)
Description: Converts a Modified Julian Day to a time-monotonic."
      (julian-day->time-monotonic (+ mjd 4800001/2)))

    (define (modified-julian-day->date mjd . args)
      "Syntax: (modified-julian-day->date mjd [tz-offset])
Library: (srfi 19)
Description: Converts a Modified Julian Day to a date."
      (apply julian-day->date (+ mjd 4800001/2) args))

    ;; ======================================================================
    ;; Current date, Julian Day
    ;; ======================================================================

    (define (current-date . args)
      "Syntax: (current-date [tz-offset])
Library: (srfi 19)
Description: Returns the current date. If tz-offset is not given, the local timezone is used.
Example:
  (date? (current-date)) => #t"
      (let ((tz-offset (if (null? args) (%local-tz-offset) (car args))))
        (time-utc->date (current-time time-utc) tz-offset)))

    (define (current-julian-day)
      "Syntax: (current-julian-day)
Library: (srfi 19)
Description: Returns the current Julian Day."
      (time-utc->julian-day (current-time time-utc)))

    (define (current-modified-julian-day)
      "Syntax: (current-modified-julian-day)
Library: (srfi 19)
Description: Returns the current Modified Julian Day."
      (time-utc->modified-julian-day (current-time time-utc)))

    ;; ======================================================================
    ;; Computed date accessors
    ;; ======================================================================

    (define (%leap-year? year)
      (and (zero? (modulo year 4))
           (or (not (zero? (modulo year 100)))
               (zero? (modulo year 400)))))

    (define %month-days
      '#(0 31 28 31 30 31 30 31 31 30 31 30 31))

    (define (%days-in-month month year)
      (if (and (= month 2) (%leap-year? year))
          29
          (vector-ref %month-days month)))

    (define (date-year-day d)
      "Syntax: (date-year-day date)
Library: (srfi 19)
Description: Returns the day of the year (1-366).
Example:
  (date-year-day (make-date 0 0 0 0 1 3 2000 0)) => 61"
      (let ((month (date-month d))
            (year  (date-year d)))
        (let loop ((m 1) (total 0))
          (if (= m month)
              (+ total (date-day d))
              (loop (+ m 1) (+ total (%days-in-month m year)))))))

    (define (date-week-day d)
      "Syntax: (date-week-day date)
Library: (srfi 19)
Description: Returns the day of the week (0=Sunday, 6=Saturday).
Example:
  (date-week-day (make-date 0 0 0 0 28 3 2026 0)) => 6"
      (let ((jdn (%encode-julian-day-number (date-day d) (date-month d) (date-year d))))
        (modulo (+ jdn 1) 7)))

    (define (date-week-number d day-of-week-starting)
      "Syntax: (date-week-number date day-of-week-starting)
Library: (srfi 19)
Description: Returns the week number of the year. day-of-week-starting is 0 for Sunday, 1 for Monday.
Example:
  (date-week-number (make-date 0 0 0 0 1 1 2026 0) 0) => 0"
      (let* ((yday (- (date-year-day d) 1))
             (wday (date-week-day d))
             (adjusted (modulo (+ wday (- 7 day-of-week-starting)) 7)))
        (quotient (+ yday (- 7 adjusted) 6) 7)))

    ;; ======================================================================
    ;; Date formatting
    ;; ======================================================================

    (define %weekday-names
      '#("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday"))

    (define %weekday-abbrevs
      '#("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat"))

    (define %month-names
      '#("" "January" "February" "March" "April" "May" "June"
         "July" "August" "September" "October" "November" "December"))

    (define %month-abbrevs
      '#("" "Jan" "Feb" "Mar" "Apr" "May" "Jun"
         "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))

    (define (%pad-zero n width)
      (let ((s (number->string n)))
        (let loop ((s s))
          (if (< (string-length s) width)
              (loop (string-append "0" s))
              s))))

    (define (%pad-space n width)
      (let ((s (number->string n)))
        (let loop ((s s))
          (if (< (string-length s) width)
              (loop (string-append " " s))
              s))))

    (define (%tz-offset->string offset)
      (if (zero? offset)
          "Z"
          (let* ((sign (if (negative? offset) "-" "+"))
                 (abs-off (abs offset))
                 (hours (quotient abs-off 3600))
                 (minutes (quotient (remainder abs-off 3600) 60)))
            (string-append sign (%pad-zero hours 2) (%pad-zero minutes 2)))))

    (define (%hour-12 h)
      (let ((h12 (modulo h 12)))
        (if (zero? h12) 12 h12)))

    (define (%am-pm h)
      (if (< h 12) "AM" "PM"))

    (define (%iso-week-number d)
      ;; ISO 8601 week number using the "nearest Thursday" method.
      ;; Weeks start on Monday; week 1 is the week containing Jan 4.
      (let* ((year (date-year d))
             (yday (date-year-day d))
             (wday (date-week-day d))  ;; 0=Sun, 6=Sat
             ;; Convert to ISO weekday: 1=Mon, 7=Sun
             (iso-wday (if (= wday 0) 7 wday))
             ;; Ordinal day of the Thursday in the same ISO week
             (thu-yday (+ yday (- 4 iso-wday)))
             (year-len (if (%leap-year? year) 366 365)))
        (cond
          ;; Thursday falls in previous year
          ((< thu-yday 1)
           (let* ((prev-len (if (%leap-year? (- year 1)) 366 365)))
             (+ 1 (quotient (- (+ thu-yday prev-len) 1) 7))))
          ;; Thursday falls in next year
          ((> thu-yday year-len) 1)
          ;; Normal case
          (else (+ 1 (quotient (- thu-yday 1) 7))))))

    (define (%date->epoch-seconds d)
      (let* ((jd (date->julian-day d))
             (diff (- jd %unix-epoch-jd)))
        (exact (round (* diff 86400)))))

    (define (%format-directive d ch)
      (cond
        ((char=? ch #\~) "~")
        ((char=? ch #\a) (vector-ref %weekday-abbrevs (date-week-day d)))
        ((char=? ch #\A) (vector-ref %weekday-names (date-week-day d)))
        ((char=? ch #\b) (vector-ref %month-abbrevs (date-month d)))
        ((char=? ch #\B) (vector-ref %month-names (date-month d)))
        ((char=? ch #\c) ;; locale date and time — use ISO-ish format
         (date->string d "~a ~b ~e ~H:~M:~S~z ~Y"))
        ((char=? ch #\d) (%pad-zero (date-day d) 2))
        ((char=? ch #\D) (date->string d "~m/~d/~y"))
        ((char=? ch #\e) (%pad-space (date-day d) 2))
        ((char=? ch #\f)
         (let ((s (+ (date-second d) (/ (date-nanosecond d) 1000000000.0))))
           (number->string (inexact s))))
        ((char=? ch #\h) (vector-ref %month-abbrevs (date-month d)))
        ((char=? ch #\H) (%pad-zero (date-hour d) 2))
        ((char=? ch #\I) (%pad-zero (%hour-12 (date-hour d)) 2))
        ((char=? ch #\j) (%pad-zero (date-year-day d) 3))
        ((char=? ch #\k) (%pad-space (date-hour d) 2))
        ((char=? ch #\l) (%pad-space (%hour-12 (date-hour d)) 2))
        ((char=? ch #\m) (%pad-zero (date-month d) 2))
        ((char=? ch #\M) (%pad-zero (date-minute d) 2))
        ((char=? ch #\n) "\n")
        ((char=? ch #\N) (%pad-zero (date-nanosecond d) 9))
        ((char=? ch #\p) (%am-pm (date-hour d)))
        ((char=? ch #\r) (date->string d "~I:~M:~S ~p"))
        ((char=? ch #\s) (number->string (%date->epoch-seconds d)))
        ((char=? ch #\S) (%pad-zero (date-second d) 2))
        ((char=? ch #\t) "\t")
        ((char=? ch #\T) (date->string d "~H:~M:~S"))
        ((char=? ch #\U) (%pad-zero (date-week-number d 0) 2))
        ((char=? ch #\V) (%pad-zero (%iso-week-number d) 2))
        ((char=? ch #\w) (number->string (date-week-day d)))
        ((char=? ch #\W) (%pad-zero (date-week-number d 1) 2))
        ((char=? ch #\x) (date->string d "~m/~d/~Y"))
        ((char=? ch #\X) (date->string d "~H:~M:~S"))
        ((char=? ch #\y) (%pad-zero (modulo (date-year d) 100) 2))
        ((char=? ch #\Y) (%pad-zero (date-year d) 4))
        ((char=? ch #\z) (%tz-offset->string (date-zone-offset d)))
        ((char=? ch #\Z) "")  ;; timezone name not available, return empty
        ((char=? ch #\1) (date->string d "~Y-~m-~d"))
        ((char=? ch #\2) (date->string d "~H:~M:~S~z"))
        ((char=? ch #\3) (date->string d "~H:~M:~S"))
        ((char=? ch #\4) (date->string d "~Y-~m-~dT~H:~M:~S~z"))
        ((char=? ch #\5) (date->string d "~Y-~m-~dT~H:~M:~S"))
        (else (error "date->string: unrecognized directive" (string #\~ ch)))))

    (define (date->string d . args)
      "Syntax: (date->string date [format-string])
Library: (srfi 19)
Description: Formats a date as a string. Uses ~-prefixed directives:
  ~Y year, ~m month, ~d day, ~H hour, ~M minute, ~S second, ~N nanosecond,
  ~z timezone, ~a abbreviated weekday, ~A full weekday, ~b abbreviated month,
  ~B full month, ~1 ISO date, ~2 ISO time+tz, ~3 ISO time, ~4 ISO date+time+tz,
  ~5 ISO date+time, ~~ literal tilde.
  Default format is \"~c\" (locale date and time).
Example:
  (date->string (make-date 0 30 15 14 28 3 2026 3600) \"~Y-~m-~d\") => \"2026-03-28\""
      (let ((fmt (if (null? args) "~c" (car args))))
        (let ((len (string-length fmt)))
          (let loop ((i 0) (result '()))
            (cond
              ((>= i len)
               (apply string-append (reverse result)))
              ((and (char=? (string-ref fmt i) #\~)
                    (< (+ i 1) len))
               (let ((directive (string-ref fmt (+ i 1))))
                 (loop (+ i 2)
                       (cons (%format-directive d directive) result))))
              (else
               (loop (+ i 1)
                     (cons (string (string-ref fmt i)) result))))))))

    ;; ======================================================================
    ;; Date parsing (string->date)
    ;; ======================================================================

    (define (%parse-integer str pos len n)
      ;; Parse n digits from str starting at pos. Returns (value . new-pos).
      (let loop ((i 0) (val 0) (p pos))
        (if (or (= i n) (>= p len))
            (cons val p)
            (let ((ch (string-ref str p)))
              (if (char-numeric? ch)
                  (loop (+ i 1)
                        (+ (* val 10) (- (char->integer ch) (char->integer #\0)))
                        (+ p 1))
                  (cons val p))))))

    (define (%parse-integer-flex str pos len)
      ;; Parse as many digits as available. Returns (value . new-pos).
      (let loop ((val 0) (p pos) (found #f))
        (if (>= p len)
            (cons val p)
            (let ((ch (string-ref str p)))
              (if (char-numeric? ch)
                  (loop (+ (* val 10) (- (char->integer ch) (char->integer #\0)))
                        (+ p 1)
                        #t)
                  (cons val p))))))

    (define (%skip-spaces str pos len)
      (let loop ((p pos))
        (if (and (< p len) (char=? (string-ref str p) #\space))
            (loop (+ p 1))
            p)))

    (define (%string-ci-prefix? prefix str pos)
      ;; Check if str starting at pos begins with prefix (case-insensitive).
      ;; Returns new position if match, #f otherwise.
      (let ((plen (string-length prefix))
            (slen (string-length str)))
        (if (> (+ pos plen) slen)
            #f
            (let loop ((i 0))
              (if (= i plen)
                  (+ pos plen)
                  (if (char-ci=? (string-ref prefix i) (string-ref str (+ pos i)))
                      (loop (+ i 1))
                      #f))))))

    (define (%parse-month-name str pos)
      ;; Parse month name (full or abbreviated). Returns (month . new-pos) or error.
      (let loop ((m 1))
        (if (> m 12)
            (error "string->date: unrecognized month name" (substring str pos (min (+ pos 10) (string-length str))))
            (let ((full-match (%string-ci-prefix? (vector-ref %month-names m) str pos))
                  (abbr-match (%string-ci-prefix? (vector-ref %month-abbrevs m) str pos)))
              (cond
                (full-match (cons m full-match))
                (abbr-match (cons m abbr-match))
                (else (loop (+ m 1))))))))

    (define (%parse-weekday-name str pos)
      ;; Parse weekday name (full or abbreviated). Returns (wday . new-pos).
      (let loop ((w 0))
        (if (> w 6)
            (error "string->date: unrecognized weekday name" (substring str pos (min (+ pos 10) (string-length str))))
            (let ((full-match (%string-ci-prefix? (vector-ref %weekday-names w) str pos))
                  (abbr-match (%string-ci-prefix? (vector-ref %weekday-abbrevs w) str pos)))
              (cond
                (full-match (cons w full-match))
                (abbr-match (cons w abbr-match))
                (else (loop (+ w 1))))))))

    (define (%parse-tz-offset str pos len)
      ;; Parse timezone offset like +0100, -0530, or Z.  Returns (offset-seconds . new-pos).
      (if (>= pos len)
          (cons 0 pos)
          (let ((sign-char (string-ref str pos)))
            (if (or (char=? sign-char #\Z) (char=? sign-char #\z))
                (cons 0 (+ pos 1))
                (let* ((sign (cond ((char=? sign-char #\+) 1)
                                   ((char=? sign-char #\-) -1)
                                   (else (error "string->date: expected +/-/Z in timezone" sign-char))))
                       (hm (%parse-integer str (+ pos 1) len 4))
                       (val (car hm))
                       (hours (quotient val 100))
                       (minutes (remainder val 100)))
                  (cons (* sign (+ (* hours 3600) (* minutes 60)))
                        (cdr hm)))))))

    (define (string->date str template)
      "Syntax: (string->date input-string template-string)
Library: (srfi 19)
Description: Parses a date string according to the template. Supported directives for parsing:
  ~Y year, ~m month, ~d day, ~H hour, ~M minute, ~S second, ~y 2-digit year,
  ~b/~B/~h month name, ~a/~A weekday name (consumed but ignored),
  ~e space-padded day, ~k space-padded hour, ~z timezone offset, ~~ literal tilde.
Example:
  (date-year (string->date \"2026-03-28\" \"~Y-~m-~d\")) => 2026"
      (let ((slen (string-length str))
            (tlen (string-length template)))
        (let loop ((si 0) (ti 0)
                   (nanosecond 0) (second 0) (minute 0) (hour 0)
                   (day 1) (month 1) (year 1970) (zone-offset 0))
          (cond
            ((>= ti tlen)
             (%make-date nanosecond second minute hour day month year zone-offset))
            ((and (char=? (string-ref template ti) #\~)
                  (< (+ ti 1) tlen))
             (let ((directive (string-ref template (+ ti 1))))
               (cond
                 ((char=? directive #\~)
                  ;; literal tilde
                  (if (and (< si slen) (char=? (string-ref str si) #\~))
                      (loop (+ si 1) (+ ti 2)
                            nanosecond second minute hour day month year zone-offset)
                      (error "string->date: expected ~ in input")))
                 ((char=? directive #\Y)
                  (let ((r (%parse-integer str si slen 4)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute hour day month (car r) zone-offset)))
                 ((char=? directive #\y)
                  (let* ((r (%parse-integer str si slen 2))
                         (yr (+ (car r) (if (< (car r) 70) 2000 1900))))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute hour day month yr zone-offset)))
                 ((char=? directive #\m)
                  (let ((r (%parse-integer str si slen 2)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute hour day (car r) year zone-offset)))
                 ((char=? directive #\d)
                  (let ((r (%parse-integer str si slen 2)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute hour (car r) month year zone-offset)))
                 ((char=? directive #\e)
                  (let* ((p (%skip-spaces str si slen))
                         (r (%parse-integer-flex str p slen)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute hour (car r) month year zone-offset)))
                 ((char=? directive #\H)
                  (let ((r (%parse-integer str si slen 2)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute (car r) day month year zone-offset)))
                 ((char=? directive #\k)
                  (let* ((p (%skip-spaces str si slen))
                         (r (%parse-integer-flex str p slen)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute (car r) day month year zone-offset)))
                 ((char=? directive #\M)
                  (let ((r (%parse-integer str si slen 2)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second (car r) hour day month year zone-offset)))
                 ((char=? directive #\S)
                  (let ((r (%parse-integer str si slen 2)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond (car r) minute hour day month year zone-offset)))
                 ((or (char=? directive #\b)
                      (char=? directive #\B)
                      (char=? directive #\h))
                  (let ((r (%parse-month-name str si)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute hour day (car r) year zone-offset)))
                 ((or (char=? directive #\a)
                      (char=? directive #\A))
                  ;; Weekday name — parse and discard (date is determined by Y/m/d)
                  (let ((r (%parse-weekday-name str si)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute hour day month year zone-offset)))
                 ((char=? directive #\z)
                  (let ((r (%parse-tz-offset str si slen)))
                    (loop (cdr r) (+ ti 2)
                          nanosecond second minute hour day month year (car r))))
                 (else
                  (error "string->date: unsupported directive for parsing"
                         (string #\~ directive))))))
            (else
             ;; literal character match
             (if (and (< si slen)
                      (char=? (string-ref str si) (string-ref template ti)))
                 (loop (+ si 1) (+ ti 1)
                       nanosecond second minute hour day month year zone-offset)
                 (error "string->date: input does not match template"
                        (if (< si slen) (string-ref str si) "end of input")
                        (string-ref template ti))))))))

    )) ;; end define-library

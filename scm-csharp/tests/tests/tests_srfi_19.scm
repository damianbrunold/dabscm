(import (scheme base)
        (scm test)
        (srfi 18)
        (srfi 19))

(test-runner-factory scm-test-runner)

(test-begin "srfi-19")

;; ======================================================================
;; Time construction and predicates
;; ======================================================================

;; time? and make-time
(test-group "time? and make-time"
  (test-equal #t (time? (make-time time-utc 0 100)))
  (test-equal #f (time? 42))
  (test-equal #f (time? "hello"))
  (test-equal #f (time? '())))

;; time accessors
(test-group "time accessors"
  (test-equal 'time-utc (time-type (make-time time-utc 123 456)))
  (test-equal 456 (time-second (make-time time-utc 123 456)))
  (test-equal 123 (time-nanosecond (make-time time-utc 123 456))))

;; time type constants
(test-group "time type constants"
  (test-equal 'time-tai (time-type (make-time time-tai 0 0)))
  (test-equal 'time-monotonic (time-type (make-time time-monotonic 0 0)))
  (test-equal 'time-duration (time-type (make-time time-duration 0 0)))
  (test-equal 'time-process (time-type (make-time time-process 0 0)))
  (test-equal 'time-thread (time-type (make-time time-thread 0 0))))

;; copy-time
(test-group "copy-time"
  (test-equal #t
    (let ((t (make-time time-utc 500 1000)))
      (let ((t2 (copy-time t)))
        (and (time=? t t2)
             (not (eq? t t2)))))))

;; ======================================================================
;; Time mutators
;; ======================================================================

;; set-time-type!, set-time-second!, set-time-nanosecond!
(test-group "time mutators"
  (define t (make-time time-utc 100 200))
  (test-equal 'time-tai (begin (set-time-type! t time-tai) (time-type t)))
  (test-equal 999 (begin (set-time-second! t 999) (time-second t)))
  (test-equal 888 (begin (set-time-nanosecond! t 888) (time-nanosecond t))))

;; ======================================================================
;; Time comparisons
;; ======================================================================

;; time=?
(test-group "time=?"
  (test-equal #t (time=? (make-time time-utc 0 100) (make-time time-utc 0 100)))
  (test-equal #f (time=? (make-time time-utc 0 100) (make-time time-utc 0 200)))
  (test-equal #f (time=? (make-time time-utc 1 100) (make-time time-utc 0 100))))

;; time<?
(test-group "time<?"
  (test-equal #t (time<? (make-time time-utc 0 100) (make-time time-utc 0 200)))
  (test-equal #f (time<? (make-time time-utc 0 200) (make-time time-utc 0 100)))
  (test-equal #f (time<? (make-time time-utc 0 100) (make-time time-utc 0 100)))
  (test-equal #t (time<? (make-time time-utc 0 100) (make-time time-utc 1 100)))
  (test-equal #t (time<? (make-time time-utc 999999999 100) (make-time time-utc 0 101))))

;; time>?
(test-group "time>?"
  (test-equal #t (time>? (make-time time-utc 0 200) (make-time time-utc 0 100)))
  (test-equal #f (time>? (make-time time-utc 0 100) (make-time time-utc 0 200))))

;; time<=? and time>=?
(test-group "time<=? and time>=?"
  (test-equal #t (time<=? (make-time time-utc 0 100) (make-time time-utc 0 100)))
  (test-equal #t (time<=? (make-time time-utc 0 100) (make-time time-utc 0 200)))
  (test-equal #f (time<=? (make-time time-utc 0 200) (make-time time-utc 0 100)))
  (test-equal #t (time>=? (make-time time-utc 0 100) (make-time time-utc 0 100)))
  (test-equal #t (time>=? (make-time time-utc 0 200) (make-time time-utc 0 100)))
  (test-equal #f (time>=? (make-time time-utc 0 100) (make-time time-utc 0 200))))

;; ======================================================================
;; Time arithmetic
;; ======================================================================

;; time-difference
(test-group "time-difference"
  (test-equal 100
    (let ((d (time-difference (make-time time-utc 0 200) (make-time time-utc 0 100))))
      (time-second d)))
  (test-equal 'time-duration
    (let ((d (time-difference (make-time time-utc 0 200) (make-time time-utc 0 100))))
      (time-type d)))
  (test-equal 200000000
    (let ((d (time-difference (make-time time-utc 500000000 200) (make-time time-utc 300000000 200))))
      (time-nanosecond d))))

;; time-difference with borrow
(test-group "time-difference with borrow"
  (test-equal (list 0 800000000)
    (let ((d (time-difference (make-time time-utc 100000000 200) (make-time time-utc 300000000 199))))
      (list (time-second d) (time-nanosecond d)))))

;; add-duration
(test-group "add-duration"
  (test-equal (list 110 500000000 'time-utc)
    (let* ((t (make-time time-utc 0 100))
           (d (make-time time-duration 500000000 10))
           (r (add-duration t d)))
      (list (time-second r) (time-nanosecond r) (time-type r)))))

;; subtract-duration
(test-group "subtract-duration"
  (test-equal (list 150 500000000)
    (let* ((t (make-time time-utc 500000000 200))
           (d (make-time time-duration 0 50))
           (r (subtract-duration t d)))
      (list (time-second r) (time-nanosecond r)))))

;; time-difference! (mutating)
(test-group "time-difference!"
  (test-equal (list 'time-duration 200)
    (let ((t1 (make-time time-utc 0 300))
          (t2 (make-time time-utc 0 100)))
      (time-difference! t1 t2)
      (list (time-type t1) (time-second t1)))))

;; ======================================================================
;; Current time
;; ======================================================================

;; current-time returns time objects
(test-group "current-time"
  (test-equal #t (time? (current-time)))
  (test-equal 'time-utc (time-type (current-time)))
  (test-equal 'time-tai (time-type (current-time time-tai)))
  (test-equal 'time-monotonic (time-type (current-time time-monotonic)))
  (test-equal 'time-process (time-type (current-time time-process)))
  (test-equal 'time-thread (time-type (current-time time-thread)))
  (test-equal #t (> (time-second (current-time)) 0)))

;; ======================================================================
;; Date construction and accessors
;; ======================================================================

;; date? and accessors
(test-group "date? and accessors"
  (define d (make-date 123456789 30 15 14 28 3 2026 3600))
  (test-equal #t (date? d))
  (test-equal 123456789 (date-nanosecond d))
  (test-equal 30 (date-second d))
  (test-equal 15 (date-minute d))
  (test-equal 14 (date-hour d))
  (test-equal 28 (date-day d))
  (test-equal 3 (date-month d))
  (test-equal 2026 (date-year d))
  (test-equal 3600 (date-zone-offset d)))

;; date?
(test-group "date?"
  (test-equal #t (date? (current-date)))
  (test-equal #f (date? 42)))

;; ======================================================================
;; Computed date accessors
;; ======================================================================

;; date-year-day
(test-group "date-year-day"
  ;; March 1 in a leap year (2000)
  (test-equal 61 (date-year-day (make-date 0 0 0 0 1 3 2000 0)))
  ;; Jan 1
  (test-equal 1 (date-year-day (make-date 0 0 0 0 1 1 2026 0)))
  ;; Dec 31 non-leap
  (test-equal 365 (date-year-day (make-date 0 0 0 0 31 12 2026 0))))

;; date-week-day
(test-group "date-week-day"
  ;; 2026-03-28 is a Saturday (6)
  (test-equal 6 (date-week-day (make-date 0 0 0 0 28 3 2026 0)))
  ;; 2000-01-01 was a Saturday (6)
  (test-equal 6 (date-week-day (make-date 0 0 0 0 1 1 2000 0)))
  ;; 1970-01-01 was a Thursday (4)
  (test-equal 4 (date-week-day (make-date 0 0 0 0 1 1 1970 0))))

;; date-week-number
(test-group "date-week-number"
  (test-equal #t (integer? (date-week-number (make-date 0 0 0 0 28 3 2026 0) 0))))

;; ======================================================================
;; Date <-> Time conversions
;; ======================================================================

;; date->time-utc
(test-group "date->time-utc"
  ;; Unix epoch date -> time-utc
  (test-equal 0 (time-second (date->time-utc (make-date 0 0 0 0 1 1 1970 0))))
  ;; 2000-01-01 00:00:00 UTC = 946684800
  (test-equal 946684800 (time-second (date->time-utc (make-date 0 0 0 0 1 1 2000 0)))))

;; time-utc->date round-trip
(test-group "time-utc->date round-trip"
  (test-equal (list 2000 1 1 0 0 0)
    (let* ((t (make-time time-utc 0 946684800))
           (d (time-utc->date t 0)))
      (list (date-year d) (date-month d) (date-day d)
            (date-hour d) (date-minute d) (date-second d)))))

;; time-utc->date with timezone offset
(test-group "time-utc->date with timezone offset"
  (test-equal (list 1 3600)
    (let* ((t (make-time time-utc 0 946684800))
           (d (time-utc->date t 3600)))  ;; UTC+1
      (list (date-hour d) (date-zone-offset d)))))

;; date->time-utc->date round-trip
(test-group "date->time-utc->date round-trip"
  (test-equal (list 2023 6 15 14 30 45)
    (let* ((d1 (make-date 0 45 30 14 15 6 2023 -18000))
           (t  (date->time-utc d1))
           (d2 (time-utc->date t -18000)))
      (list (date-year d2) (date-month d2) (date-day d2)
            (date-hour d2) (date-minute d2) (date-second d2)))))

;; ======================================================================
;; UTC <-> TAI conversions
;; ======================================================================

;; UTC->TAI and TAI->UTC
(test-group "UTC <-> TAI conversions"
  ;; UTC->TAI adds leap seconds (post-2017: offset = 37)
  (test-equal 37
    (let* ((t-utc (make-time time-utc 0 1500000000))
           (t-tai (time-utc->time-tai t-utc)))
      (- (time-second t-tai) (time-second t-utc))))
  ;; TAI->UTC removes leap seconds
  (test-equal 1500000000
    (let* ((t-tai (make-time time-tai 0 1500000037))
           (t-utc (time-tai->time-utc t-tai)))
      (time-second t-utc)))
  ;; Pre-1972: no leap seconds
  (test-equal 0
    (let* ((t-utc (make-time time-utc 0 0))
           (t-tai (time-utc->time-tai t-utc)))
      (- (time-second t-tai) (time-second t-utc)))))

;; ======================================================================
;; Julian Day conversions
;; ======================================================================

;; date->julian-day
(test-group "date->julian-day"
  ;; J2000.0 = 2000-01-01 12:00:00 UTC = JD 2451545.0
  (test-equal 2451545 (date->julian-day (make-date 0 0 0 12 1 1 2000 0)))
  ;; Unix epoch = JD 2440587.5
  (test-equal 4881175/2 (date->julian-day (make-date 0 0 0 0 1 1 1970 0))))

;; julian-day->date round-trip
(test-group "julian-day->date round-trip"
  (test-equal (list 2000 1 1 12)
    (let ((d (julian-day->date 2451545 0)))
      (list (date-year d) (date-month d) (date-day d) (date-hour d)))))

;; Modified Julian Day
(test-group "modified julian day"
  ;; MJD = JD - 2400000.5
  (test-equal 103089/2 (date->modified-julian-day (make-date 0 0 0 12 1 1 2000 0))))

;; ======================================================================
;; date->string formatting
;; ======================================================================

;; basic directives
(test-group "date->string basic directives"
  (define d (make-date 123000000 30 15 14 5 3 2026 3600))
  (test-equal "2026" (date->string d "~Y"))
  (test-equal "03" (date->string d "~m"))
  (test-equal "05" (date->string d "~d"))
  (test-equal "14" (date->string d "~H"))
  (test-equal "15" (date->string d "~M"))
  (test-equal "30" (date->string d "~S"))
  (test-equal "123000000" (date->string d "~N")))

;; ISO date and weekday/month names
(test-group "date->string ISO date and names"
  (define d (make-date 0 0 0 0 28 3 2026 0))
  (test-equal "2026-03-28" (date->string d "~1"))
  (test-equal "Sat" (date->string d "~a"))
  (test-equal "Saturday" (date->string d "~A"))
  (test-equal "Mar" (date->string d "~b"))
  (test-equal "March" (date->string d "~B")))

;; timezone and combined
(test-group "date->string timezone and combined"
  (define d (make-date 0 45 30 9 7 6 2023 -18000))
  (test-equal "-0500" (date->string d "~z"))
  (test-equal "2023-06-07T09:30:45-0500" (date->string d "~Y-~m-~dT~H:~M:~S~z"))
  (test-equal "23" (date->string d "~y")))

;; AM/PM and 12-hour format
(test-group "date->string AM/PM"
  (define d (make-date 0 0 0 15 1 1 2026 0))
  (test-equal "PM" (date->string d "~p"))
  (test-equal "AM" (date->string (make-date 0 0 0 9 1 1 2026 0) "~p"))
  (test-equal "03" (date->string d "~I"))
  (test-equal "12" (date->string (make-date 0 0 0 0 1 1 2026 0) "~I")))

;; escape tilde and literal text
(test-group "date->string escape and literal"
  (test-equal "~" (date->string (make-date 0 0 0 0 1 1 2026 0) "~~"))
  (test-equal "Year: 2026" (date->string (make-date 0 0 0 0 1 1 2026 0) "Year: ~Y")))

;; ======================================================================
;; string->date parsing
;; ======================================================================

;; basic date parsing
(test-group "string->date basic"
  (test-equal (list 2026 3 28)
    (let ((d (string->date "2026-03-28" "~Y-~m-~d")))
      (list (date-year d) (date-month d) (date-day d)))))

;; date-time parsing
(test-group "string->date date-time"
  (test-equal (list 2026 3 28 14 30 45)
    (let ((d (string->date "2026-03-28T14:30:45" "~Y-~m-~dT~H:~M:~S")))
      (list (date-year d) (date-month d) (date-day d)
            (date-hour d) (date-minute d) (date-second d)))))

;; timezone parsing
(test-group "string->date timezone"
  (test-equal 3600
    (let ((d (string->date "2026-03-28T14:30:45+0100" "~Y-~m-~dT~H:~M:~S~z")))
      (date-zone-offset d)))
  (test-equal -18000
    (let ((d (string->date "2026-03-28T14:30:45-0500" "~Y-~m-~dT~H:~M:~S~z")))
      (date-zone-offset d))))

;; 2-digit year parsing
(test-group "string->date 2-digit year"
  (test-equal 2026 (date-year (string->date "26-03-28" "~y-~m-~d")))
  (test-equal 1999 (date-year (string->date "99-12-31" "~y-~m-~d"))))

;; month name parsing
(test-group "string->date month name"
  (test-equal 3 (date-month (string->date "March 28, 2026" "~B ~d, ~Y")))
  (test-equal 6 (date-month (string->date "Jun 15, 2023" "~b ~d, ~Y"))))

;; ======================================================================
;; SRFI-18 interop
;; ======================================================================

;; SRFI-18 time? works with SRFI-19 types
(test-group "SRFI-18 interop"
  (test-equal #t (time? (current-time)))
  (test-equal #t (> (time->seconds (current-time)) 0))
  (test-equal #t (time? (seconds->time 100.0)))
  (test-equal #t (> (time->seconds (seconds->time 123.456)) 123)))

;; ======================================================================
;; time-resolution
;; ======================================================================

;; time-resolution returns a positive integer
(test-group "time-resolution"
  (test-equal #t (> (time-resolution time-utc) 0))
  (test-equal #t (> (time-resolution time-monotonic) 0)))

;; ======================================================================
;; current-date
;; ======================================================================

;; current-date returns a date
(test-group "current-date"
  (test-equal #t (date? (current-date)))
  (test-equal #t (date? (current-date 0)))
  (test-equal #t (> (date-year (current-date)) 2024)))

;; ======================================================================
;; current-julian-day / current-modified-julian-day
;; ======================================================================

;; current-julian-day is a reasonable number
(test-group "current-julian-day"
  (test-equal #t (> (inexact (current-julian-day)) 2451545.0))
  (test-equal #t (> (inexact (current-modified-julian-day)) 51544.0)))

;; ======================================================================
;; Tests adapted from SRFI-19 reference test suite
;; ======================================================================

;; ----------------------------------------------------------------------
;; TAI-UTC leap second boundary tests
;; Tests all leap second boundaries with checks at: exact boundary,
;; 1 second before, 1 second after, and ~15 days later.
;; Adapted from the SRFI-19 reference implementation test suite.
;; ----------------------------------------------------------------------

(test-group "TAI-UTC leap second boundaries"
  (define (test-utc-tai-edge utc tai-diff tai-last-diff)
    ;; At the boundary
    (let* ((utc-basic (make-time time-utc 0 utc))
           (tai-basic (make-time time-tai 0 (+ utc tai-diff)))
           (utc->tai-basic (time-utc->time-tai utc-basic))
           (tai->utc-basic (time-tai->time-utc tai-basic)))
      (test-equal #t (time=? utc-basic tai->utc-basic))
      (test-equal #t (time=? tai-basic utc->tai-basic)))
    ;; One second before
    (let* ((utc-before (make-time time-utc 0 (- utc 1)))
           (tai-before (make-time time-tai 0 (- (+ utc tai-last-diff) 1)))
           (utc->tai-before (time-utc->time-tai utc-before))
           (tai->utc-before (time-tai->time-utc tai-before)))
      (test-equal #t (time=? utc-before tai->utc-before))
      (test-equal #t (time=? tai-before utc->tai-before)))
    ;; One second after
    (let* ((utc-after (make-time time-utc 0 (+ utc 1)))
           (tai-after (make-time time-tai 0 (+ (+ utc tai-diff) 1)))
           (utc->tai-after (time-utc->time-tai utc-after))
           (tai->utc-after (time-tai->time-utc tai-after)))
      (test-equal #t (time=? utc-after tai->utc-after))
      (test-equal #t (time=? tai-after utc->tai-after)))
    ;; ~15 days later with half-second nanoseconds
    (let* ((shy (* 15 24 60 60))
           (hs (/ (expt 10 9) 2))
           (utc-later (make-time time-utc hs (+ utc shy)))
           (tai-later (make-time time-tai hs (+ (+ utc tai-diff) shy)))
           (utc->tai-later (time-utc->time-tai utc-later))
           (tai->utc-later (time-tai->time-utc tai-later)))
      (test-equal #t (time=? utc-later tai->utc-later))
      (test-equal #t (time=? tai-later utc->tai-later))))

  ;; All leap second boundaries from 1972 through 1999
  (test-utc-tai-edge 915148800  32 31)
  (test-utc-tai-edge 867715200  31 30)
  (test-utc-tai-edge 820454400  30 29)
  (test-utc-tai-edge 773020800  29 28)
  (test-utc-tai-edge 741484800  28 27)
  (test-utc-tai-edge 709948800  27 26)
  (test-utc-tai-edge 662688000  26 25)
  (test-utc-tai-edge 631152000  25 24)
  (test-utc-tai-edge 567993600  24 23)
  (test-utc-tai-edge 489024000  23 22)
  (test-utc-tai-edge 425865600  22 21)
  (test-utc-tai-edge 394329600  21 20)
  (test-utc-tai-edge 362793600  20 19)
  (test-utc-tai-edge 315532800  19 18)
  (test-utc-tai-edge 283996800  18 17)
  (test-utc-tai-edge 252460800  17 16)
  (test-utc-tai-edge 220924800  16 15)
  (test-utc-tai-edge 189302400  15 14)
  (test-utc-tai-edge 157766400  14 13)
  (test-utc-tai-edge 126230400  13 12)
  (test-utc-tai-edge 94694400   12 11)
  (test-utc-tai-edge 78796800   11 10)
  (test-utc-tai-edge 63072000   10 0)
  ;; At and near the epoch
  (test-utc-tai-edge 0   0 0)
  (test-utc-tai-edge 10  0 0)
  ;; A recent time (well past the last leap second)
  (test-utc-tai-edge 1045789645 32 32))

;; ----------------------------------------------------------------------
;; TAI-Date conversions (leap second 60)
;; Tests from the reference suite verifying that time-tai->date produces
;; date-second = 60 at leap second boundaries.
;; The 1998-12-31 leap second: UTC 915148800
;; ----------------------------------------------------------------------

(test-group "TAI-Date leap second conversions"
  ;; 1998-12-31 23:59:58 UTC (29 seconds into TAI offset)
  (let ((d (time-tai->date (make-time time-tai 0 (+ 915148800 29)) 0)))
    (test-equal 1998 (date-year d))
    (test-equal 12 (date-month d))
    (test-equal 31 (date-day d))
    (test-equal 23 (date-hour d))
    (test-equal 59 (date-minute d))
    (test-equal 58 (date-second d)))
  ;; 1998-12-31 23:59:59 UTC
  (let ((d (time-tai->date (make-time time-tai 0 (+ 915148800 30)) 0)))
    (test-equal 59 (date-second d))
    (test-equal 59 (date-minute d)))
  ;; 1998-12-31 23:59:60 UTC (the leap second itself)
  (let ((d (time-tai->date (make-time time-tai 0 (+ 915148800 31)) 0)))
    (test-equal 60 (date-second d))
    (test-equal 59 (date-minute d)))
  ;; 1999-01-01 00:00:00 UTC
  (let ((d (time-tai->date (make-time time-tai 0 (+ 915148800 32)) 0)))
    (test-equal 1999 (date-year d))
    (test-equal 1 (date-month d))
    (test-equal 1 (date-day d))
    (test-equal 0 (date-hour d))
    (test-equal 0 (date-minute d))
    (test-equal 0 (date-second d))))

;; ----------------------------------------------------------------------
;; Date-UTC conversions (leap second 60)
;; Tests from the reference suite verifying that date->time-utc handles
;; date-second = 60 correctly.
;; ----------------------------------------------------------------------

(test-group "Date-UTC leap second conversions"
  (test-equal (- 915148800 2)
    (time-second (date->time-utc (make-date 0 58 59 23 31 12 1998 0))))
  (test-equal (- 915148800 1)
    (time-second (date->time-utc (make-date 0 59 59 23 31 12 1998 0))))
  ;; second=60 maps to the same UTC instant as second=0 of the next minute
  (test-equal 915148800
    (time-second (date->time-utc (make-date 0 60 59 23 31 12 1998 0))))
  (test-equal 915148800
    (time-second (date->time-utc (make-date 0 0 0 0 1 1 1999 0))))
  (test-equal (+ 915148800 1)
    (time-second (date->time-utc (make-date 0 1 0 0 1 1 1999 0)))))

;; ----------------------------------------------------------------------
;; TZ offset conversion test from reference suite
;; ----------------------------------------------------------------------

(test-group "TZ offset conversions"
  (let ((ct-utc (make-time time-utc 6320000 1045944859))
        (ct-tai (make-time time-tai 6320000 1045944891))
        (cd (make-date 6320000 19 14 15 22 2 2003 -18000)))
    (test-equal #t (time=? ct-utc (date->time-utc cd)))
    (test-equal #t (time=? ct-tai (date->time-tai cd)))))

;; ----------------------------------------------------------------------
;; Format directives ~2, ~3, ~4, ~5 (ISO 8601 formats)
;; Adapted from the reference test suite.
;; ----------------------------------------------------------------------

(test-group "date->string ISO format directives"
  (define d (make-date 0 1 2 3 4 5 2006 0))
  (define d-zero-o-clock (make-date 0 0 0 0 1 9 2018 0))
  ;; ~2 = ISO time with timezone
  (test-equal "03:02:01Z" (date->string d "~2"))
  ;; ~3 = ISO time without timezone
  (test-equal "03:02:01" (date->string d "~3"))
  ;; ~4 = ISO date+time with timezone
  (test-equal "2006-05-04T03:02:01Z" (date->string d "~4"))
  ;; ~5 = ISO date+time without timezone
  (test-equal "2006-05-04T03:02:01" (date->string d "~5"))
  ;; ~I at midnight should be 12
  (test-equal "12" (date->string d-zero-o-clock "~I")))

;; ----------------------------------------------------------------------
;; ~z timezone formatting: Z for zero offset
;; ----------------------------------------------------------------------

(test-group "date->string ~z zero offset"
  (test-equal "Z" (date->string (make-date 0 0 0 0 1 1 2026 0) "~z"))
  (test-equal "+0100" (date->string (make-date 0 0 0 0 1 1 2026 3600) "~z"))
  (test-equal "-0500" (date->string (make-date 0 0 0 0 1 1 2026 -18000) "~z")))

;; ----------------------------------------------------------------------
;; string->date with Z timezone
;; ----------------------------------------------------------------------

(test-group "string->date Z timezone"
  (test-equal 0
    (date-zone-offset (string->date "2026-01-01T00:00:00Z" "~Y-~m-~dT~H:~M:~S~z")))
  ;; Round-trip: date->string with ~z -> string->date
  (test-equal (list 2026 1 1 0 0 0 0)
    (let* ((d1 (make-date 0 0 0 0 1 1 2026 0))
           (s (date->string d1 "~Y-~m-~dT~H:~M:~S~z"))
           (d2 (string->date s "~Y-~m-~dT~H:~M:~S~z")))
      (list (date-year d2) (date-month d2) (date-day d2)
            (date-hour d2) (date-minute d2) (date-second d2)
            (date-zone-offset d2)))))

;; ----------------------------------------------------------------------
;; ~k and ~l space-padded hour formats
;; Adapted from the reference test suite.
;; ----------------------------------------------------------------------

(test-group "date->string ~k and ~l"
  (define d (make-date 0 1 2 3 4 5 2006 0))
  (define d-zero (make-date 0 0 0 0 1 9 2018 0))
  ;; ~k = 24-hour with leading space
  (test-equal " 3" (date->string d "~k"))
  ;; ~l = 12-hour with leading space
  (test-equal " 3" (date->string d "~l"))
  ;; ~l at midnight = 12
  (test-equal "12" (date->string d-zero "~l")))

;; ----------------------------------------------------------------------
;; ISO 8601 week number (~V)
;; Adapted from the reference test suite. Tests year-boundary edge cases
;; where weeks can belong to the previous or next year.
;; ----------------------------------------------------------------------

(test-group "date->string ~V ISO week number"
  (define (week-of y m d)
    (date->string (make-date 0 0 0 0 d m y 0) "~V"))

  ;; 2020-2021 boundary: 2020 has week 53
  (test-equal "53" (week-of 2020 12 31))  ; Thursday
  (test-equal "53" (week-of 2021 1 1))    ; Friday (still week 53 of 2020)
  (test-equal "53" (week-of 2021 1 3))    ; Sunday (still week 53 of 2020)
  (test-equal "01" (week-of 2021 1 4))    ; Monday = week 1 of 2021

  ;; 2019-2020 boundary: 2020 week 1 starts on 2019-12-30
  (test-equal "52" (week-of 2019 12 29))  ; Sunday = week 52 of 2019
  (test-equal "01" (week-of 2019 12 30))  ; Monday = week 1 of 2020
  (test-equal "01" (week-of 2019 12 31))  ; Tuesday = week 1 of 2020
  (test-equal "01" (week-of 2020 1 1))    ; Wednesday = week 1 of 2020

  ;; 2016-2017 boundary
  (test-equal "52" (week-of 2016 12 31))  ; Saturday
  (test-equal "52" (week-of 2017 1 1))    ; Sunday (still week 52 of 2016)
  (test-equal "01" (week-of 2017 1 2))    ; Monday = week 1 of 2017
  (test-equal "01" (week-of 2017 1 8))    ; Sunday = week 1 of 2017
  (test-equal "02" (week-of 2017 1 9))    ; Monday = week 2 of 2017

  ;; 2014-2015 boundary: 2015 week 1 starts on 2014-12-29
  (test-equal "52" (week-of 2014 12 28))  ; Sunday = week 52 of 2014
  (test-equal "01" (week-of 2014 12 29))  ; Monday = week 1 of 2015
  (test-equal "01" (week-of 2014 12 30))  ; Tuesday
  (test-equal "01" (week-of 2014 12 31))  ; Wednesday
  (test-equal "01" (week-of 2015 1 1))    ; Thursday
  (test-equal "01" (week-of 2015 1 2))    ; Friday
  (test-equal "01" (week-of 2015 1 3))    ; Saturday
  (test-equal "01" (week-of 2015 1 4))    ; Sunday
  (test-equal "02" (week-of 2015 1 5)))   ; Monday = week 2 of 2015

(test-end "srfi-19")

(define-library (scm datetime)
  (import (scm core)
          (scheme base)
          (scheme cxr)
          (srfi 1)
          (srfi 13)
          (scm string))
  (export string->date-days
          string->date-seconds
          timestamp
          timestamp->string
          parse-rfc822
          parse-iso8601
          parse-pubdate
          format-iso8601
          today
          now
          time)
  (begin
    (define string->date-days (%primitive "string->date-days"))
    (define string->date-seconds (%primitive "string->date-seconds"))
    (define timestamp (%primitive "timestamp"))
    (define timestamp->string (%primitive "timestamp->string"))
    (define %local-tz-offset (%primitive "%local-tz-offset"))

    ;; ============================================================
    ;; RFC 822 / ISO 8601 parsing helpers
    ;;
    ;; Both parsers return Unix seconds (integer), or #f if the input
    ;; is unparseable. They do not validate calendar bounds beyond
    ;; what the conversion needs, so 'Feb 30' will produce some value
    ;; — callers that need strict validation should run an additional
    ;; check.
    ;; ============================================================

    (define (digit? c) (and (char>=? c #\0) (char<=? c #\9)))

    (define (parse-int s start end)
      ;; Returns the integer value of s[start..end] or #f on failure.
      (cond
        ((or (< end start) (> end (string-length s))) #f)
        ((= end start) 0)
        (else
         (let loop ((i start) (acc 0))
           (cond
             ((= i end) acc)
             ((digit? (string-ref s i))
              (loop (+ i 1) (+ (* acc 10)
                               (- (char->integer (string-ref s i))
                                  (char->integer #\0)))))
             (else #f))))))

    (define month-table
      '(("Jan" . 1) ("Feb" . 2) ("Mar" . 3) ("Apr" . 4)
        ("May" . 5) ("Jun" . 6) ("Jul" . 7) ("Aug" . 8)
        ("Sep" . 9) ("Oct" . 10) ("Nov" . 11) ("Dec" . 12)))

    (define (month-number name)
      (let ((p (assoc (substring name 0 (min 3 (string-length name)))
                      month-table)))
        (and p (cdr p))))

    (define (leap-year? y)
      (and (zero? (modulo y 4))
           (or (not (zero? (modulo y 100)))
               (zero? (modulo y 400)))))

    (define non-leap-cumulative
      '#(0 31 59 90 120 151 181 212 243 273 304 334))

    (define leap-cumulative
      '#(0 31 60 91 121 152 182 213 244 274 305 335))

    (define (days-before-month month year)
      ;; Cumulative days in `year` before the given (1-based) month.
      (vector-ref (if (leap-year? year) leap-cumulative non-leap-cumulative)
                  (- month 1)))

    (define (days-before-year y)
      ;; Days from 1970-01-01 to Jan 1 of y. Handles 1970..2200 cleanly.
      (let loop ((yr 1970) (acc 0))
        (cond
          ((= yr y) acc)
          (else (loop (+ yr 1) (+ acc (if (leap-year? yr) 366 365)))))))

    (define (to-unix year month day hour minute second tz-offset-minutes)
      ;; tz-offset-minutes is the offset from UTC, so subtract it.
      (and year month day
           (let ((days (+ (days-before-year year)
                          (days-before-month month year)
                          (- day 1))))
             (- (+ (* days 86400)
                   (* hour 3600)
                   (* minute 60)
                   second)
                (* tz-offset-minutes 60)))))

    (define (parse-tz s)
      ;; Returns minutes east of UTC. Handles "Z", "+HH:MM", "-HHMM",
      ;; "GMT", "UT", "UTC", and the legacy zone names from RFC 822
      ;; (EST, EDT, CST, CDT, MST, MDT, PST, PDT). Unknown → 0.
      (cond
        ((or (string=? s "") (string=? s "Z")
             (string=? s "GMT") (string=? s "UT") (string=? s "UTC"))
         0)
        ((or (char=? (string-ref s 0) #\+)
             (char=? (string-ref s 0) #\-))
         (let* ((sign (if (char=? (string-ref s 0) #\+) 1 -1))
                (rest (substring s 1 (string-length s)))
                (rest (if (string-index rest #\:)
                          (string-append (substring rest 0 (string-index rest #\:))
                                         (substring rest (+ 1 (string-index rest #\:))
                                                    (string-length rest)))
                          rest)))
           (cond
             ((>= (string-length rest) 4)
              (let ((h (parse-int rest 0 2))
                    (m (parse-int rest 2 4)))
                (if (and h m) (* sign (+ (* h 60) m)) 0)))
             ((>= (string-length rest) 2)
              (let ((h (parse-int rest 0 2)))
                (if h (* sign (* h 60)) 0)))
             (else 0))))
        ((string=? s "EST") -300) ((string=? s "EDT") -240)
        ((string=? s "CST") -360) ((string=? s "CDT") -300)
        ((string=? s "MST") -420) ((string=? s "MDT") -360)
        ((string=? s "PST") -480) ((string=? s "PDT") -420)
        (else 0)))

    (define (parse-rfc822 s)
      "Syntax: (parse-rfc822 s)
Library: (scm datetime)
Description: Parses an RFC 822 / RFC 2822 date string (e.g. used by RSS 2.0
  pubDate elements) and returns Unix seconds, or #f on failure. The leading
  day-of-week prefix is optional. Two-digit years are mapped to 20XX.
Example:
  (parse-rfc822 \"Thu, 16 May 2024 12:34:56 +0200\") => 1715855696
  (parse-rfc822 \"16 May 2024 12:34:56 GMT\")       => 1715862896
  (parse-rfc822 \"bogus\") => #f"
      (cond
        ((or (not (string? s)) (string=? s "")) #f)
        (else
         (let* ((s (string-trim-both s))
                (comma (string-index s #\,))
                (rest  (if comma
                           (string-trim-both
                             (substring s (+ comma 1) (string-length s)))
                           s))
                (parts (filter (lambda (p) (not (string=? p "")))
                               (string-split rest " "))))
           (and (>= (length parts) 5)
                (let* ((day   (parse-int (car parts) 0 (string-length (car parts))))
                       (mon   (month-number (cadr parts)))
                       (year  (let ((y (parse-int (caddr parts) 0
                                                   (string-length (caddr parts)))))
                                (cond
                                  ((not y) #f)
                                  ((< y 100) (+ y 2000))
                                  (else y))))
                       (time-parts (string-split (cadddr parts) ":"))
                       (hour   (and (>= (length time-parts) 1)
                                    (parse-int (list-ref time-parts 0) 0
                                               (string-length (list-ref time-parts 0)))))
                       (minute (and (>= (length time-parts) 2)
                                    (parse-int (list-ref time-parts 1) 0
                                               (string-length (list-ref time-parts 1)))))
                       (second (cond ((>= (length time-parts) 3)
                                      (parse-int (list-ref time-parts 2) 0
                                                 (string-length (list-ref time-parts 2))))
                                     (else 0)))
                       (tz     (parse-tz (list-ref parts 4))))
                  (to-unix year mon day (or hour 0) (or minute 0)
                           (or second 0) tz)))))))

    (define (parse-iso8601 s)
      "Syntax: (parse-iso8601 s)
Library: (scm datetime)
Description: Parses an ISO 8601 / RFC 3339 date string (e.g. used by Atom
  feeds) and returns Unix seconds, or #f on failure. Accepts date-only
  ('2024-05-16'), date+time with 'T' or space separator, and a trailing
  timezone offset (Z, +02:00, -0500). Fractional seconds are ignored.
Example:
  (parse-iso8601 \"2024-05-16T12:34:56Z\")      => 1715862896
  (parse-iso8601 \"2024-05-16T14:34:56+02:00\") => 1715862896
  (parse-iso8601 \"2024-05-16\")                => 1715817600
  (parse-iso8601 \"bogus\") => #f"
      (cond
        ((or (not (string? s)) (string=? s "")) #f)
        (else
         (let ((s (string-trim-both s)))
           (and (>= (string-length s) 10)
                (char=? (string-ref s 4) #\-)
                (let* ((year (parse-int s 0 4))
                       (mon  (parse-int s 5 7))
                       (day  (parse-int s 8 10)))
                  (cond
                    ((not (and year mon day)) #f)
                    ((<= (string-length s) 10)
                     (to-unix year mon day 0 0 0 0))
                    ((or (char=? (string-ref s 10) #\T)
                         (char=? (string-ref s 10) #\space))
                     (let* ((hour   (parse-int s 11 13))
                            (minute (parse-int s 14 16))
                            (second (parse-int s 17 19))
                            (tz-start
                              (let loop ((i 19))
                                (cond
                                  ((>= i (string-length s)) (string-length s))
                                  (else
                                    (let ((c (string-ref s i)))
                                      (cond
                                        ((or (char=? c #\+) (char=? c #\-)
                                             (char=? c #\Z))
                                         i)
                                        (else (loop (+ i 1))))))))))
                       (to-unix year mon day (or hour 0) (or minute 0)
                                (or second 0)
                                (parse-tz (substring s tz-start (string-length s))))))
                    (else #f))))))))

    (define (parse-pubdate s)
      "Syntax: (parse-pubdate s)
Library: (scm datetime)
Description: Best-effort date parser for feed pubdates. Tries ISO 8601 first
  if s looks ISO-shaped (hyphen at position 4), otherwise RFC 822. Falls
  back to the other format on failure. Returns Unix seconds, or #f.
Example:
  (parse-pubdate \"2024-05-16T12:34:56Z\")             => 1715862896
  (parse-pubdate \"Thu, 16 May 2024 12:34:56 +0000\")  => 1715862896
  (parse-pubdate \"\") => #f"
      (cond
        ((or (not s) (not (string? s)) (string=? s "")) #f)
        ((and (>= (string-length s) 5)
              (char=? (string-ref s 4) #\-))
         (or (parse-iso8601 s) (parse-rfc822 s)))
        (else (or (parse-rfc822 s) (parse-iso8601 s)))))

    ;; ============================================================
    ;; ISO 8601 formatting
    ;; ============================================================

    (define (pad2 n)
      (let ((s (number->string n)))
        (cond ((< n 10) (string-append "0" s)) (else s))))

    (define (pad4 n)
      (let* ((s (number->string n))
             (l (string-length s)))
        (cond
          ((>= l 4) s)
          ((= l 3) (string-append "0" s))
          ((= l 2) (string-append "00" s))
          (else    (string-append "000" s)))))

    (define (unix->ymd-hms u)
      ;; Returns (values year month day hour minute second) for unix
      ;; seconds u, in UTC. u must be a non-negative integer.
      (let* ((day-num  (quotient u 86400))
             (time     (modulo u 86400))
             (hour     (quotient time 3600))
             (minute   (quotient (modulo time 3600) 60))
             (second   (modulo time 60)))
        (let yr-loop ((yr 1970) (remaining day-num))
          (let ((yr-days (if (leap-year? yr) 366 365)))
            (cond
              ((< remaining yr-days)
               (let mo-loop ((mo 1))
                 (let* ((cumul (days-before-month mo yr))
                        (next-cumul (if (= mo 12)
                                        (if (leap-year? yr) 366 365)
                                        (days-before-month (+ mo 1) yr))))
                   (cond
                     ((< remaining next-cumul)
                      (values yr mo (+ (- remaining cumul) 1)
                              hour minute second))
                     (else (mo-loop (+ mo 1)))))))
              (else (yr-loop (+ yr 1) (- remaining yr-days))))))))

    (define (format-iso8601 u)
      "Syntax: (format-iso8601 unix-seconds)
Library: (scm datetime)
Description: Formats a Unix-seconds integer as an ISO 8601 UTC string
  ('YYYY-MM-DDTHH:MM:SSZ'). Negative inputs (pre-1970) are not supported.
Example:
  (format-iso8601 1715862896) => \"2024-05-16T12:34:56Z\"
  (format-iso8601 (parse-iso8601 \"2024-05-16T14:34:56+02:00\"))
    => \"2024-05-16T12:34:56Z\""
      (cond
        ((or (not (integer? u)) (negative? u))
         (error "format-iso8601: expected non-negative integer" u))
        (else
         (call-with-values (lambda () (unix->ymd-hms u))
           (lambda (y mo d h m s)
             (string-append (pad4 y) "-" (pad2 mo) "-" (pad2 d) "T"
                            (pad2 h) ":" (pad2 m) ":" (pad2 s) "Z"))))))

    ;; ============================================================
    ;; Current local date/time helpers
    ;; ============================================================

    (define (local-ymd-hms)
      ;; Returns (values y mo d h m s) for the local wall-clock time.
      (let ((local (+ (quotient (timestamp) 1000) (%local-tz-offset))))
        (unix->ymd-hms local)))

    (define (today . opts)
      "Syntax: (today)
Syntax: (today format)
Library: (scm datetime)
Description: Returns the current local date as a string. Default format is
  ISO 'YYYY-MM-DD'. format='short returns 'YYYYMMDD' (no separators);
  format='dmy returns 'DD.MM.YYYY'.
Example:
  (today)        => \"2026-05-27\"
  (today 'short) => \"20260527\"
  (today 'dmy)   => \"27.05.2026\""
      (call-with-values local-ymd-hms
        (lambda (y mo d h m s)
          (let ((fmt (if (null? opts) 'iso (car opts))))
            (cond
              ((eq? fmt 'iso)
               (string-append (pad4 y) "-" (pad2 mo) "-" (pad2 d)))
              ((eq? fmt 'short)
               (string-append (pad4 y) (pad2 mo) (pad2 d)))
              ((eq? fmt 'dmy)
               (string-append (pad2 d) "." (pad2 mo) "." (pad4 y)))
              (else (error "today: unknown format" fmt)))))))

    (define (now . opts)
      "Syntax: (now)
Syntax: (now format)
Library: (scm datetime)
Description: Returns the current local date and time as a string. Time is
  24-hour. Default format is ISO 'YYYY-MM-DD HH:MM'. format='short returns
  'YYYYMMDD-HHMM'; format='dmyhs returns 'DD.MM.YYYY HH.MM'.
Example:
  (now)        => \"2026-05-27 07:32\"
  (now 'short) => \"20260527-0732\"
  (now 'dmyhm) => \"27.05.2026 07:32\""
      (call-with-values local-ymd-hms
        (lambda (y mo d h m s)
          (let ((fmt (if (null? opts) 'iso (car opts))))
            (cond
              ((eq? fmt 'iso)
               (string-append (pad4 y) "-" (pad2 mo) "-" (pad2 d) " "
                              (pad2 h) ":" (pad2 m)))
              ((eq? fmt 'short)
               (string-append (pad4 y) (pad2 mo) (pad2 d) "-"
                              (pad2 h) (pad2 m)))
              ((eq? fmt 'dmyhm)
               (string-append (pad2 d) "." (pad2 mo) "." (pad4 y) " "
                              (pad2 h) ":" (pad2 m)))
              (else (error "now: unknown format" fmt)))))))

    (define (time . opts)
      "Syntax: (time)
Syntax: (time format)
Library: (scm datetime)
Description: Returns the current local time as a string. Time is 24-hour.
  Default format is ISO 'HH:MM'. format='short returns 'HHMM'.
Example:
  (time)        => \"07:32\"
  (time 'short) => \"0732\""
      (call-with-values local-ymd-hms
        (lambda (y mo d h m s)
          (let ((fmt (if (null? opts) 'iso (car opts))))
            (cond
              ((eq? fmt 'iso)
               (string-append (pad2 h) ":" (pad2 m)))
              ((eq? fmt 'short)
               (string-append (pad2 h) (pad2 m)))
              (else (error "time: unknown format" fmt)))))))
))

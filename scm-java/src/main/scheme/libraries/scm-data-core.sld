(define-library (scm data core)
  (import (scheme base)
          (scheme char)
          (srfi 1)
          (srfi 13))
  (export na
          na?
          day?
          ymd->day
          day->ymd
          day-number
          day-from-number
          day-year
          day-month
          day-weekday
          string->day
          day->string
          value-type
          column-type
          parse-cell
          infer-column)
  (begin

    ;; ================================================================
    ;; (scm data core) — the shared base of the (scm data …) libraries:
    ;; the missing value NA, the calendar date type used in data frames
    ;; ("day": a date without time, stored as days since 1970-01-01),
    ;; value/column type detection and string-to-value parsing used by
    ;; the readers (CSV, XLSX, SQL results).
    ;;
    ;; Column types: int, real, string, bool, date, symbol, list,
    ;; mixed (several of these) and na (nothing but NA).
    ;; ================================================================

    (define-record-type <na> (make-na) na-object?)

    (define na (make-na))

    (define (na? x)
      "Syntax: (na? x)
Library: (scm data core)
Description: True if x is the missing value na. Data frames use na for
  missing cells; aggregates skip it, arithmetic with it yields na.
Example:
  (na? na) => #t
  (na? 0)  => #f"
      (eq? x na))

    ;; --- dates ------------------------------------------------------

    (define-record-type <day> (make-day n) day? (n day-number))

    (define (day-from-number n)
      "Syntax: (day-from-number n)
Library: (scm data core)
Description: The date n days after 1970-01-01 (n may be negative).
Example:
  (day->string (day-from-number 0)) => \"1970-01-01\""
      (make-day n))

    ;; days-from-civil / civil-from-days (H. Hinnant), proleptic Gregorian
    (define (ymd->day y m d)
      "Syntax: (ymd->day year month day)
Library: (scm data core)
Description: The date for a year, month (1-12) and day of month.
Example:
  (day-number (ymd->day 1970 1 2)) => 1"
      (let* ((y (if (<= m 2) (- y 1) y))
             (era (floor-quotient y 400))
             (yoe (- y (* era 400)))
             (mp (modulo (+ m 9) 12))
             (doy (+ (quotient (+ (* 153 mp) 2) 5) (- d 1)))
             (doe (+ (* yoe 365) (quotient yoe 4) (- (quotient yoe 100)) doy)))
        (make-day (+ (* era 146097) doe -719468))))

    (define (day->ymd day)
      "Syntax: (day->ymd day)
Library: (scm data core)
Description: The list (year month day-of-month) of a date.
Example:
  (day->ymd (ymd->day 2024 2 29)) => (2024 2 29)"
      (let* ((z (+ (day-number day) 719468))
             (era (floor-quotient z 146097))
             (doe (- z (* era 146097)))
             (yoe (quotient (- doe (quotient doe 1460) (- (quotient doe 36524))
                               (quotient doe 146096))
                            365))
             (y (+ yoe (* era 400)))
             (doy (- doe (- (+ (* 365 yoe) (quotient yoe 4)) (quotient yoe 100))))
             (mp (quotient (+ (* 5 doy) 2) 153))
             (d (+ (- doy (quotient (+ (* 153 mp) 2) 5)) 1))
             (m (if (< mp 10) (+ mp 3) (- mp 9))))
        (list (if (<= m 2) (+ y 1) y) m d)))

    (define (day-year day) (car (day->ymd day)))
    (define (day-month day) (cadr (day->ymd day)))

    (define (day-weekday day)
      "Syntax: (day-weekday day)
Library: (scm data core)
Description: ISO weekday of a date: 1 = Monday … 7 = Sunday.
Example:
  (day-weekday (ymd->day 2026 10 30)) => 5"
      (+ 1 (modulo (+ (day-number day) 3) 7)))

    (define (digits? s start end)
      (and (<= end (string-length s))
           (let loop ((i start))
             (or (= i end)
                 (and (char-numeric? (string-ref s i)) (loop (+ i 1)))))))

    (define (string->day s)
      "Syntax: (string->day s)
Library: (scm data core)
Description: Parses an ISO date \"YYYY-MM-DD\" (also \"YYYYMMDD\" and the
  Swiss \"DD.MM.YYYY\"); returns #f when s is not such a date.
Example:
  (day->ymd (string->day \"11.03.2024\")) => (2024 3 11)"
      (define (mk y m d)
        (and (<= 1 m 12) (<= 1 d 31)
             (let ((day (ymd->day y m d)))
               (and (equal? (day->ymd day) (list y m d)) day))))
      (define (num a b) (string->number (substring s a b)))
      (let ((n (string-length s)))
        (cond
         ((and (= n 10) (digits? s 0 4) (char=? (string-ref s 4) #\-)
               (digits? s 5 7) (char=? (string-ref s 7) #\-) (digits? s 8 10))
          (mk (num 0 4) (num 5 7) (num 8 10)))
         ((and (= n 10) (digits? s 0 2) (char=? (string-ref s 2) #\.)
               (digits? s 3 5) (char=? (string-ref s 5) #\.) (digits? s 6 10))
          (mk (num 6 10) (num 3 5) (num 0 2)))
         ((and (= n 8) (digits? s 0 8))
          (mk (num 0 4) (num 4 6) (num 6 8)))
         (else #f))))

    (define (pad2 n) (if (< n 10) (string-append "0" (number->string n)) (number->string n)))

    (define (day->string day . style)
      "Syntax: (day->string day [style])
Library: (scm data core)
Description: Formats a date. style is iso (default, \"2024-03-11\") or
  dmy (\"11.03.2024\").
Example:
  (day->string (ymd->day 2024 3 11) 'dmy) => \"11.03.2024\""
      (let* ((ymd (day->ymd day))
             (y (number->string (car ymd))))
        (if (and (pair? style) (eq? (car style) 'dmy))
            (string-append (pad2 (caddr ymd)) "." (pad2 (cadr ymd)) "." y)
            (string-append y "-" (pad2 (cadr ymd)) "-" (pad2 (caddr ymd))))))

    ;; --- types ------------------------------------------------------

    (define (value-type x)
      "Syntax: (value-type x)
Library: (scm data core)
Description: The data type of one value: na, int (exact integer), real
  (any other real number), string, bool, date, symbol, list or other.
Example:
  (value-type 1.5) => real"
      (cond ((na? x) 'na)
            ((and (exact-integer? x)) 'int)
            ((real? x) 'real)
            ((string? x) 'string)
            ((boolean? x) 'bool)
            ((day? x) 'date)
            ((symbol? x) 'symbol)
            ((list? x) 'list)
            (else 'other)))

    (define (column-type v)
      "Syntax: (column-type vector)
Library: (scm data core)
Description: The type of a column: the common value-type of its non-NA
  values; int and real together give real; na if all are NA, mixed if
  the values have different types.
Example:
  (column-type (vector 1 2.5 na)) => real"
      (let loop ((i 0) (t 'na))
        (if (= i (vector-length v))
            t
            (let ((u (value-type (vector-ref v i))))
              (loop (+ i 1)
                    (cond ((eq? u 'na) t)
                          ((eq? t 'na) u)
                          ((eq? t u) t)
                          ((and (memq t '(int real)) (memq u '(int real))) 'real)
                          (else 'mixed)))))))

    ;; --- parsing strings --------------------------------------------

    (define default-na-strings '("" "NA" "N/A" "NULL" "null" "#N/A"))

    (define (parse-number s decimal)
      (let* ((t (string-trim-both s))
             (t (if (char=? decimal #\.) t (string-map (lambda (c) (if (char=? c decimal) #\. c)) t))))
        (and (> (string-length t) 0)
             (let ((c (string-ref t 0)))
               (or (char-numeric? c) (memv c '(#\- #\+ #\.))))
             (not (string-index t #\/))
             (let ((n (string->number t)))
               (and n (real? n) n)))))

    (define (parse-cell s type . opts)
      "Syntax: (parse-cell string type [decimal-char])
Library: (scm data core)
Description: Converts a string to a value of the given column type (int,
  real, bool, date, symbol, string). Returns na when the string can't be
  read as that type. decimal-char (default #\\.) is the decimal separator.
Example:
  (parse-cell \"1,5\" 'real #\\,) => 1.5"
      (let ((decimal (if (pair? opts) (car opts) #\.)))
        (case type
          ((int) (let ((n (parse-number s decimal)))
                   (if (and n (exact-integer? n)) n na)))
          ((real) (let ((n (parse-number s decimal)))
                    (if n (if (exact? n) (inexact n) n) na)))
          ((bool) (cond ((member s '("TRUE" "true" "True" "t" "1" "yes" "ja")) #t)
                        ((member s '("FALSE" "false" "False" "f" "0" "no" "nein")) #f)
                        (else na)))
          ((date) (or (string->day (string-trim-both s)) na))
          ((symbol) (string->symbol s))
          (else s))))

    (define (infer-column strings . opts)
      "Syntax: (infer-column string-vector [na-strings [decimal-char]])
Library: (scm data core)
Description: Guesses the type of a column of strings and converts it:
  int if every non-missing cell is an integer, else real if all are
  numbers (a value with a leading zero such as \"007\" is a code, and
  keeps the column a string), else bool (TRUE/FALSE, or t/f as Postgres sends them), else date (ISO or DD.MM.YYYY), else
  string. Cells in na-strings (default \"\", NA, N/A, NULL, #N/A) become
  na. Returns the converted vector.
Example:
  (infer-column (vector \"1\" \"\" \"3\")) => #(1 na 3)"
      (let* ((na-strings (if (pair? opts) (car opts) default-na-strings))
             (decimal (if (and (pair? opts) (pair? (cdr opts))) (cadr opts) #\.))
             (n (vector-length strings))
             (missing? (lambda (s) (or (not (string? s)) (member s na-strings))))
             (all? (lambda (pred)
                     (let loop ((i 0))
                       (or (= i n)
                           (let ((s (vector-ref strings i)))
                             (and (or (missing? s) (pred s)) (loop (+ i 1))))))))
             ;; "007", "0815": codes/IDs, not numbers -- keep the zeros
             (leading-zero? (lambda (s)
                              (let ((t (string-trim-both s)))
                                (and (> (string-length t) 1)
                                     (char=? (string-ref t 0) #\0)
                                     (char-numeric? (string-ref t 1))))))
             (number-ok? (lambda (s) (and (not (leading-zero? s)) (parse-number s decimal))))
             (type (cond
                    ((all? (lambda (s) (let ((x (number-ok? s)))
                                         (and x (exact-integer? x)))))
                     'int)
                    ((all? number-ok?) 'real)
                    ((all? (lambda (s) (member s '("TRUE" "FALSE" "true" "false" "True" "False"
                                                   "t" "f"))))
                     'bool)
                    ((all? string->day) 'date)
                    (else 'string))))
        (vector-map (lambda (s)
                      (if (missing? s)
                          (if (and (eq? type 'string) (string? s) (not (member s na-strings))) s na)
                          (parse-cell s type decimal)))
                    strings)))))

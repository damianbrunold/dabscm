(define-library (scm data format)
  (import (scheme base)
          (scheme write)
          (only (srfi 1) every fold)
          (srfi 13)
          (scm data core))
  (export data-locale
          na-string
          fmt-num
          fmt-int
          fmt-pct
          fmt-pct-change
          fmt-si
          fmt-date
          fmt-value)
  (begin

    ;; ================================================================
    ;; (scm data format) — number, percent and date formatting for
    ;; reports, tables and chart axes. Rounds half away from zero.
    ;; The parameter data-locale holds the separators:
    ;;   ((thousands . "'") (decimal . "."))   ; default, Swiss style
    ;; e.g. (parameterize ((data-locale '((thousands . ",") (decimal . "."))))
    ;;        (fmt-num 1234.5 1))  => "1,234.5"
    ;; na formats as (na-string), default "NA".
    ;; ================================================================

    (define data-locale
      (make-parameter '((thousands . "'") (decimal . "."))))

    (define na-string (make-parameter "NA"))

    (define (loc key)
      (let ((p (assq key (data-locale)))) (if p (cdr p) "")))

    ;; digits of the exact integer n (>= 0) grouped by threes
    (define (group-thousands digits sep)
      (let ((n (string-length digits)))
        (if (or (<= n 3) (string=? sep ""))
            digits
            (let loop ((i (- n 3)) (acc (list (substring digits (- n 3) n))))
              (if (<= i 3)
                  (apply string-append (substring digits 0 i)
                         (map (lambda (s) (string-append sep s)) acc))
                  (loop (- i 3) (cons (substring digits (- i 3) i) acc)))))))

    (define (fmt-num x . opts)
      "Syntax: (fmt-num x [decimals [thousands?]])
Library: (scm data format)
Description: Formats a number with a fixed number of decimals (default 0)
  and thousands separators from data-locale (pass #f as thousands? to
  leave them out). na gives (na-string).
Example:
  (fmt-num 24973.25 1) => \"24'973.3\"
  (fmt-num -0.04 1)    => \"0.0\""
      (let ((decimals (if (pair? opts) (car opts) 0))
            (thousands? (if (and (pair? opts) (pair? (cdr opts))) (cadr opts) #t)))
        (cond
         ((na? x) (na-string))
         ((not (real? x)) (error "fmt-num: not a number" x))
         ((and (inexact? x) (not (= x x))) "NaN")
         ((and (inexact? x) (or (= x +inf.0) (= x -inf.0))) (if (> x 0) "Inf" "-Inf"))
         (else
          (let* ((scale (expt 10 decimals))
                 (e (exact x))
                 (neg (< e 0))
                 (r (floor (+ (* (abs e) scale) 1/2)))
                 (int-part (quotient r scale))
                 (frac-part (remainder r scale))
                 (int-str (group-thousands (number->string int-part)
                                           (if thousands? (loc 'thousands) "")))
                 (frac-str (if (= decimals 0)
                               ""
                               (string-append (loc 'decimal)
                                              (string-pad (number->string frac-part)
                                                          decimals #\0)))))
            (string-append (if (and neg (> r 0)) "-" "") int-str frac-str))))))

    (define (fmt-int x)
      "Syntax: (fmt-int x)
Library: (scm data format)
Description: (fmt-num x 0): rounded, with thousands separators.
Example:
  (fmt-int 1234567) => \"1'234'567\""
      (fmt-num x 0))

    (define (fmt-pct x . opts)
      "Syntax: (fmt-pct fraction [decimals])
Library: (scm data format)
Description: Formats a fraction as percent with a space before % (default
  1 decimal).
Example:
  (fmt-pct 0.2345) => \"23.5 %\""
      (if (na? x)
          (na-string)
          (string-append (fmt-num (* 100 x) (if (pair? opts) (car opts) 1)) " %")))

    (define (fmt-pct-change a b . opts)
      "Syntax: (fmt-pct-change from to [decimals])
Library: (scm data format)
Description: The relative change from a to b as a signed percent (default
  0 decimals); \"n/a\" when a is 0 and b is not.
Example:
  (fmt-pct-change 20316 24973) => \"+23 %\""
      (let ((decimals (if (pair? opts) (car opts) 0)))
        (cond
         ((or (na? a) (na? b)) (na-string))
         ((zero? a) (if (zero? b) (string-append (fmt-num 0 decimals) " %") "n/a"))
         (else
          (let* ((p (* 100 (- (/ b a) 1)))
                 (s (fmt-num p decimals))
                 (zero (fmt-num 0 decimals)))
            (string-append (if (and (> p 0) (not (string=? s zero))) "+" "")
                           (if (string=? s (string-append "-" zero)) zero s)
                           " %"))))))

    (define (fmt-si x . opts)
      "Syntax: (fmt-si x [decimals])
Library: (scm data format)
Description: Short form with k / M / G suffix (default 1 decimal), for
  axis labels.
Example:
  (fmt-si 12345) => \"12.3k\""
      (let ((d (if (pair? opts) (car opts) 1)))
        (cond ((na? x) (na-string))
              ((>= (abs x) 1e9) (string-append (fmt-num (/ x 1e9) d #f) "G"))
              ((>= (abs x) 1e6) (string-append (fmt-num (/ x 1e6) d #f) "M"))
              ((>= (abs x) 1e3) (string-append (fmt-num (/ x 1e3) d #f) "k"))
              ((integer? x) (fmt-num x 0 #f))
              (else (fmt-num x d #f)))))

    (define (fmt-date day . style)
      "Syntax: (fmt-date day [style])
Library: (scm data format)
Description: Formats a date: iso (default, 2024-03-11) or dmy (11.03.2024).
Example:
  (fmt-date (ymd->day 2024 3 11) 'dmy) => \"11.03.2024\""
      (if (na? day) (na-string) (apply day->string day style)))

    ;; shortest readable form of a real: up to 4 decimals, trailing zeros cut
    (define (short-real x)
      (let* ((s (fmt-num x 4 #f))
             (dec (loc 'decimal)))
        (if (string-index s (string-ref dec 0))
            (let* ((t (string-trim-right s #\0)))
              (if (string-suffix? dec t) (substring t 0 (- (string-length t) (string-length dec))) t))
            s)))

    (define (fmt-value x)
      "Syntax: (fmt-value x)
Library: (scm data format)
Description: Generic display form of a cell value, used when printing data
  frames: integers plain, reals with up to 4 decimals, dates ISO, strings
  as they are, na as (na-string), lists and other values written.
Example:
  (fmt-value 2.50) => \"2.5\""
      (cond ((na? x) (na-string))
            ((string? x) x)
            ((exact-integer? x) (number->string x))
            ((and (real? x) (inexact? x) (not (= x x))) "NaN")
            ((real? x) (if (or (= x +inf.0) (= x -inf.0)) (if (> x 0) "Inf" "-Inf") (short-real x)))
            ((boolean? x) (if x "TRUE" "FALSE"))
            ((day? x) (day->string x))
            ((symbol? x) (symbol->string x))
            ;; a geometry of (scm geo): its type and size, not its coordinates
            ((and (pair? x) (memq (car x) '(polygon polyline multipoint)) (list? (cdr x)) (every vector? (cdr x)))
             (let ((parts (length (cdr x)))
                   (points (fold (lambda (v n) (+ n (if (eq? (car x) 'multipoint) 1 (quotient (vector-length v) 2)))) 0 (cdr x))))
               (string-append "<" (symbol->string (car x)) " "
                              (if (eq? (car x) 'multipoint)
                                  (string-append (number->string points) " pt")
                                  (string-append (number->string parts) (if (eq? (car x) 'polygon) " rings " " paths ")
                                                 (number->string points) " pt"))
                              ">")))
            (else (let ((p (open-output-string))) (write x p) (get-output-string p)))))))

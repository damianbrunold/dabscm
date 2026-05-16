(define-library (scm duration)
  (import (scm core) (scheme base) (srfi 13))
  (export parse-duration
          format-duration)
  (begin

    (define (parse-duration s)
      "Syntax: (parse-duration s)
Library: (scm duration)
Description: Parses a duration string into a non-negative integer number of
  seconds. Accepts a bare integer (interpreted as seconds), or an integer
  suffixed with one of s/m/h/d (seconds/minutes/hours/days). Returns #f
  if s is not a string, is empty, or does not parse.
Example:
  (parse-duration \"30\")  => 30
  (parse-duration \"30s\") => 30
  (parse-duration \"10m\") => 600
  (parse-duration \"3h\")  => 10800
  (parse-duration \"1d\")  => 86400
  (parse-duration \"x\")   => #f"
      (cond
        ((not (string? s)) #f)
        ((string=? s "") #f)
        (else
         (let* ((s     (string-trim-both s))
                (n     (string-length s))
                (last  (string-ref s (- n 1)))
                (digits (cond
                          ((or (char=? last #\s) (char=? last #\m)
                               (char=? last #\h) (char=? last #\d))
                           (substring s 0 (- n 1)))
                          (else s)))
                (num   (string->number digits))
                (mult  (cond
                         ((char=? last #\m) 60)
                         ((char=? last #\h) 3600)
                         ((char=? last #\d) 86400)
                         (else 1))))
           (cond
             ((and num (integer? num) (>= num 0))
              (* (exact num) mult))
             (else #f))))))

    (define (format-duration seconds)
      "Syntax: (format-duration seconds)
Library: (scm duration)
Description: Human-readable inverse of parse-duration. Emits a d/h/m suffix
  when seconds divides evenly by 86400/3600/60; otherwise emits a plain
  seconds value with the s suffix. Non-integer or negative input is
  rendered as the integer itself (or empty string for non-numbers).
Example:
  (format-duration 3600)  => \"1h\"
  (format-duration 86400) => \"1d\"
  (format-duration 90)    => \"90s\"
  (format-duration 0)     => \"0s\""
      (cond
        ((not (and (integer? seconds) (>= seconds 0)))
         (cond ((integer? seconds) (number->string seconds))
               (else "")))
        ((and (> seconds 0) (zero? (modulo seconds 86400)))
         (string-append (number->string (quotient seconds 86400)) "d"))
        ((and (> seconds 0) (zero? (modulo seconds 3600)))
         (string-append (number->string (quotient seconds 3600)) "h"))
        ((and (> seconds 0) (zero? (modulo seconds 60)))
         (string-append (number->string (quotient seconds 60)) "m"))
        (else (string-append (number->string seconds) "s"))))
))

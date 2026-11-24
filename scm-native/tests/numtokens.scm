;; Tokens that start like a number read as the JVM implementation's tokenizer
;; reads them: a number, an error ("2026-01-01": an invalid complex number) or
;; a symbol (the whole token: "1.2.3", "1.5x")
(import (scheme base) (scheme read) (scheme write))
(define (show s)
  (write (list s (guard (e (#t (list 'error (error-object-message e))))
                   (let ((p (open-input-string s)))
                     (let loop ((acc '()))
                       (let ((x (read p)))
                         (if (eof-object? x) (reverse acc) (loop (cons x acc)))))))))
  (newline))
(for-each show
          '("2026-01-01" "1+" "12abc" "1.2.3" "-x" "+5" "1e" "0x10" "123." "1/2/3"
            "1+2i" "1-2.5i" "+i" "-i" "-2i" "+inf.0" "-nan.0" "1e10" "1.5e-3" ".5"
            "-.5" "..." "+" "-" "1/2" "1d3" "3f2" "1@0" "1a" "(1.2.3 x)" "(1 2.5abc)"
            "12.5abc" "1e+5" "007"))

;; Strings, bignums, rationals, flonums, closures, vectors, records,
;; hash tables, string conversions
(import (scheme base) (scheme write) (scheme char) (srfi 69) (soak lib))

(define (iota-list n) (let loop ((i n) (acc '())) (if (= i 0) acc (loop (- i 1) (cons i acc)))))

(define-record-type point (make-point x y) point? (x point-x) (y point-y))

(soak "alloc"
      (lambda (round)
        (let ((h (make-hash-table equal?)))
          (do ((i 0 (+ i 1))) ((= i (scale 5000)))
            (hash-table-set! h (number->string i) (make-point i (expt 3 (+ 40 (modulo i 50)))))
            (string-upcase (string-append "abc" (number->string (/ i 7)) "äöü"))
            (utf8->string (string->utf8 (make-string 20 #\λ)))
            (inexact (/ i 3))
            ((lambda (f) (f i)) (lambda (x) (lambda () x)))
            (list->vector (iota-list 20)))
          (hash-table-walk h (lambda (k v) (point-x v))))))


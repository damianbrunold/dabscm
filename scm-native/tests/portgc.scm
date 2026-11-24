;; Ports made while the nursery is full: opening a port registered it with
;; the collector before its port object was allocated, so a collection at
;; that allocation freed the port (found with SCM_NATIVE_GC_STRESS)
(import (scheme base) (scheme write))
(define (count-chars n)
  (let loop ((i 0) (acc 0))
    (if (= i n)
        acc
        (let ((p (open-input-string "abc")))
          (read-char p)
          (loop (+ i 1) (+ acc (if (char=? (read-char p) #\b) 1 0)))))))
(write (count-chars 2000000))
(newline)
(define (count-bytes n)
  (let loop ((i 0) (acc 0))
    (if (= i n)
        acc
        (let ((p (open-input-bytevector (bytevector 1 2 3))))
          (loop (+ i 1) (+ acc (read-u8 p)))))))
(write (count-bytes 1000000))
(newline)

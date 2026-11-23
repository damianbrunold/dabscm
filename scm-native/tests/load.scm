;; load without an environment evaluates in the program's module, as on
;; the JVM: definitions in the loaded file set the program's globals (a
;; configuration file read with load), and new names are visible to later
;; loads.
(import (scheme base) (scheme file) (scheme load) (scheme write))

(define file "load-test-config.scm")
(call-with-output-file file
  (lambda (p)
    (write '(define port 8089) p)
    (write '(define greeting (string-append "hello " "world")) p)
    (write '(define (twice x) (* 2 x)) p)
    (write '(define extra 'only-in-config) p)))
(load file)
(write (list port greeting (twice 21)))
(newline)
(call-with-output-file file
  (lambda (p) (write '(define port (list extra port)) p)))
(load file)
(write port)
(newline)
(delete-file file)

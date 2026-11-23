;; Programs run and captured, started and waited for
(import (scheme base) (scheme write) (scm system) (soak lib))

(soak "processes"
      (lambda (round)
        (do ((i 0 (+ i 1))) ((= i (scale 50)))
          (run-program/capture (list "echo" (number->string i)))
          (process-wait (start-program (list "true"))))))

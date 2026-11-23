;; An error a primitive raises in a thread goes to the thread's handlers
;; (a guard there catches it), as one in the main thread
(import (scheme base) (scheme write) (srfi 18) (scm io))
(write (guard (e (#t (list 'caught (error-object-message e)))) (read-data (open-input-string "#0=(a . #0#)")))) (newline)
(define t (make-thread (lambda () (guard (e (#t 'caught-in-thread)) (read-data (open-input-string "#0=(a . #0#)"))))))
(thread-start! t)
(write (thread-join! t)) (newline)
(write (guard (e (#t 'caught-deep)) (read-data (open-input-string (string-append (make-string 200000 #\() (make-string 200000 #\))))))) (newline)

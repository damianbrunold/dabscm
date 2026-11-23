;; Connections closed, and dropped without closing; their text and binary
;; ports; listeners dropped
(import (scheme base) (scheme write) (scm net sockets) (soak lib))

(define port-number 18451)
(define listener (tcp-listen port-number))

(define (exchange i close?)
  (let* ((c (tcp-connect "127.0.0.1" port-number))
         (s (tcp-accept listener))
         (text (number->string i)))
    (write-string text (socket-output-port c))
    (newline (socket-output-port c))
    (flush-output-port (socket-output-port c))
    (let ((line (read-line (socket-input-port s))))
      (write-bytevector (string->utf8 line) (socket-binary-output-port s))
      (flush-output-port (socket-binary-output-port s))
      (socket-close s)
      (let ((back (read-bytevector 100 (socket-binary-input-port c))))
        (when close? (socket-close c))
        (unless (equal? (utf8->string back) text) (error "wrong answer" text back))))))

(soak "sockets"
      (lambda (round)
        (do ((i 0 (+ i 1))) ((= i (scale 500)))
          (exchange i (even? i)))
        (do ((i 0 (+ i 1))) ((= i 5))
          (tcp-listen (+ port-number 1 (* 5 round) i)))))

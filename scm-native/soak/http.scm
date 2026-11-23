;; An HTTP server and the client: requests over new connections
(import (scheme base) (scheme write) (scm net http client) (scm net http server)
        (scm net http response) (soak lib))

(define port-number 18471)
(define server
  (tcp-http-serve port-number
                  (lambda (req) (text-response (make-string 2000 #\x)))
                  0 "127.0.0.1"))

(soak "http"
      (lambda (round)
        (do ((i 0 (+ i 1))) ((= i (scale 300)))
          (http-get (string-append "http://127.0.0.1:" (number->string port-number) "/x")))))

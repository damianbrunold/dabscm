(define-library (scm net sockets)
  (import (scm core) (scheme base))
  (export tcp-listen
          tcp-accept
          tcp-connect
          socket-close
          socket-input-port
          socket-output-port
          socket-binary-input-port
          socket-binary-output-port
          socket?
          tcp-listener?
          tls-connect
          socket-starttls!
          socket-read-line
          with-tcp-connection
          call-with-tcp-server)
  (begin
    (define tcp-listen               (%primitive "tcp-listen"))
    (define tcp-accept               (%primitive "tcp-accept"))
    (define tcp-connect              (%primitive "tcp-connect"))
    (define tls-connect              (%primitive "tls-connect"))
    (define socket-starttls!         (%primitive "socket-starttls!"))
    (define socket-read-line         (%primitive "socket-read-line"))
    (define socket-close             (%primitive "socket-close"))
    (define socket-input-port        (%primitive "socket-input-port"))
    (define socket-output-port       (%primitive "socket-output-port"))
    (define socket-binary-input-port  (%primitive "socket-binary-input-port"))
    (define socket-binary-output-port (%primitive "socket-binary-output-port"))
    (define socket?                  (%primitive "socket?"))
    (define tcp-listener?            (%primitive "tcp-listener?"))

    (define (with-tcp-connection host port proc)
      "Syntax: (with-tcp-connection host port proc)
Library: (scm net sockets)
Description: Connects to host:port, calls proc with the socket, then closes the
  socket even if proc raises an error. Returns the result of proc.
Example:
  (with-tcp-connection \"localhost\" 8080
    (lambda (sock) (display \"hi\" (socket-output-port sock))))"
      (let ((sock (tcp-connect host port)))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc sock))
          (lambda () (socket-close sock)))))

    (define (call-with-tcp-server port proc)
      "Syntax: (call-with-tcp-server port proc)
Library: (scm net sockets)
Description: Creates a TCP listener on port, calls proc with it, then stops the
  listener even if proc raises an error. Returns the result of proc.
Example:
  (call-with-tcp-server 8080
    (lambda (listener) (tcp-accept listener)))"
      (let ((listener (tcp-listen port)))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc listener))
          (lambda () (socket-close listener)))))))

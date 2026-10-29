;; WebSockets in tcp-http-serve (http-websocket-upgrade) and the frame
;; protocol of (scm net websocket): echo with ws-connect, a greeting sent
;; right after the handshake, receive timeouts, refused handshakes, and raw
;; frames for fragmentation, pings, close and protocol errors.

(import (scheme base)
        (scheme write)
        (scm test)
        (scm string)
        (srfi 18)
        (scm net sockets)
        (scm net http request)
        (scm net http response)
        (scm net http server)
        (scm net websocket))

(test-runner-factory scm-test-runner)

(test-begin "scm-websocket-upgrade")

(define port 18741)

(define (echo ws)
  (let loop ((m (ws-receive ws)))
    (when (and m (not (eq? m 'timeout)))
      (ws-send ws m)
      (loop (ws-receive ws)))))

(define handler-done #f)

(define (handler req)
  (let ((path (http-request-url req)))
    (cond
      ((string=? path "/echo") (http-websocket-upgrade echo))
      ((string=? path "/hello")
       (http-websocket-upgrade (lambda (ws) (ws-send ws "hi") (echo ws))
                               '(("Sec-WebSocket-Protocol" . "folien"))))
      ((string=? path "/bye")
       (http-websocket-upgrade (lambda (ws) (ws-receive ws) (set! handler-done 'returned))))
      ((string=? path "/fail")
       (http-websocket-upgrade (lambda (ws) (error "handler failed on purpose"))))
      (else (http-ok "plain")))))

(define server (tcp-http-serve port handler))

(define (retry thunk)
  (let loop ((n 0))
    (if (< n 5)
        (guard (e (#t (thread-sleep! 0.1) (loop (+ n 1)))) (thunk))
        (thunk))))

(define (has? s x) (and (string-contains-from s x 0) #t))

;; --- with the client of (scm net websocket) -----------------------------

(test-group "echo"
  (let ((ws (retry (lambda () (ws-connect "127.0.0.1" port "/echo")))))
    (test-assert (ws? ws))
    (ws-send ws "Grüezi")
    (test-equal "Grüezi" (ws-receive ws))
    (ws-send ws (bytevector 1 2 3 255))
    (test-equal (bytevector 1 2 3 255) (ws-receive ws))
    (let ((big (make-string 200000 #\x)))
      (ws-send ws big)
      (test-equal "a 200 kB message" 200000 (string-length (ws-receive ws))))
    (test-equal "nothing within the timeout" 'timeout (ws-receive ws 200))
    (ws-send ws "still there")
    (test-equal "usable after a timeout" "still there" (ws-receive ws))
    (ws-close ws)
    (test-equal "closed" #f (ws-receive ws))))

(test-group "a greeting right after the handshake"
  (let ((ws (ws-connect "127.0.0.1" port "/hello")))
    (test-equal "hi" (ws-receive ws))
    (ws-send ws "x")
    (test-equal "x" (ws-receive ws))
    (ws-close ws)))

(test-group "the handler returns when the client closes"
  (let ((ws (ws-connect "127.0.0.1" port "/bye")))
    (ws-close ws)
    (let loop ((n 0))
      (when (and (not handler-done) (< n 50)) (thread-sleep! 0.05) (loop (+ n 1))))
    (test-equal 'returned handler-done)))

(test-group "a failing handler closes the connection"
  (let ((ws (ws-connect "127.0.0.1" port "/fail")))
    (test-equal #f (ws-receive ws 5000))))

(test-error "ws-connect to a plain route" (ws-connect "127.0.0.1" port "/plain"))

;; --- raw sockets ------------------------------------------------------------

(define (connect) (tcp-connect "127.0.0.1" port))
(define (out s) (socket-binary-output-port s))
(define (in s) (socket-binary-input-port s))

(define (send-bytes s bv)
  (write-bytevector bv (out s))
  (flush-output-port (out s)))

;; The response head up to the empty line, as a string.
(define (read-head s)
  (let loop ((acc '()))
    (let ((b (read-u8 (in s))))
      (if (eof-object? b)
          (list->string (map integer->char (reverse acc)))
          (let ((acc (cons b acc)))
            (if (and (>= (length acc) 4) (equal? (list-head acc 4) '(10 13 10 13)))
                (list->string (map integer->char (reverse acc)))
                (loop acc)))))))

(define (list-head l n) (if (= n 0) '() (cons (car l) (list-head (cdr l) (- n 1)))))

(define (handshake path . extra)
  (let ((s (connect)))
    (send-bytes s (string->utf8
                   (string-append "GET " path " HTTP/1.1\r\nHost: x\r\n"
                                  (apply string-append extra) "\r\n")))
    (cons s (read-head s))))

(define upgrade-headers
  (list "Upgrade: websocket\r\n" "Connection: keep-alive, Upgrade\r\n"
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" "Sec-WebSocket-Version: 13\r\n"))

;; A client frame: masked with key 1 2 3 4 unless mask? is #f.
(define (frame opcode fin? payload . mask?)
  (let* ((mask? (or (null? mask?) (car mask?)))
         (n (bytevector-length payload))
         (key (bytevector 1 2 3 4))
         (body (if mask?
                   (let ((b (bytevector-copy payload)))
                     (do ((i 0 (+ i 1))) ((= i n) b)
                       (bytevector-u8-set! b i (bitwise-xor (bytevector-u8-ref b i)
                                                            (bytevector-u8-ref key (modulo i 4))))))
                   payload)))
    (bytevector-append (bytevector (+ (if fin? 128 0) opcode) (+ (if mask? 128 0) n))
                       (if mask? key (bytevector))
                       body)))

(define (bitwise-xor a b)
  (let loop ((a a) (b b) (bit 1) (r 0))
    (if (and (= a 0) (= b 0))
        r
        (loop (quotient a 2) (quotient b 2) (* bit 2)
              (if (= (modulo (+ a b) 2) 1) (+ r bit) r)))))

;; A server frame: (opcode . payload).
(define (read-frame s)
  (let* ((b0 (read-u8 (in s))))
    (if (eof-object? b0)
        b0
        (let* ((b1 (read-u8 (in s)))
               (n (bitwise-and-127 b1))
               (n (cond ((= n 126) (+ (* 256 (read-u8 (in s))) (read-u8 (in s))))
                        (else n))))
          (cons (modulo b0 16) (if (= n 0) (bytevector) (read-bytevector n (in s))))))))

(define (bitwise-and-127 b) (modulo b 128))

(test-group "handshake"
  (let ((r (apply handshake "/hello" upgrade-headers)))
    (test-assert (has? (cdr r) "HTTP/1.1 101 Switching Protocols"))
    ;; RFC 6455's example key and its accept value
    (test-assert (has? (cdr r) "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo="))
    (test-assert (has? (cdr r) "Sec-WebSocket-Protocol: folien"))
    (test-equal (cons 1 (string->utf8 "hi")) (read-frame (car r)))
    (close-port (out (car r))))
  (test-assert "no key: 400"
    (has? (cdr (handshake "/echo" "Upgrade: websocket\r\n" "Connection: Upgrade\r\n"
                          "Sec-WebSocket-Version: 13\r\n"))
          "HTTP/1.1 400"))
  (let ((r (handshake "/echo" "Upgrade: websocket\r\n" "Connection: Upgrade\r\n"
                      "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" "Sec-WebSocket-Version: 8\r\n")))
    (test-assert "another version: 426" (has? (cdr r) "HTTP/1.1 426"))
    (test-assert (has? (cdr r) "Sec-WebSocket-Version: 13")))
  (test-assert "not an upgrade: 400" (has? (cdr (handshake "/echo")) "HTTP/1.1 400")))

(test-group "fragments, ping, close"
  (let* ((s (car (apply handshake "/echo" upgrade-headers))))
    (send-bytes s (frame 1 #f (string->utf8 "Hel")))
    (send-bytes s (frame 9 #t (string->utf8 "p")))
    (send-bytes s (frame 0 #t (string->utf8 "lo")))
    (test-equal "the pong" (cons 10 (string->utf8 "p")) (read-frame s))
    (test-equal "the joined message" (cons 1 (string->utf8 "Hello")) (read-frame s))
    (send-bytes s (frame 8 #t (bytevector 3 232)))
    (test-equal "the close is answered" (cons 8 (bytevector 3 232)) (read-frame s))))

(test-group "unmasked client frames are refused"
  (let* ((s (car (apply handshake "/echo" upgrade-headers))))
    (send-bytes s (frame 1 #t (string->utf8 "x") #f))
    (test-equal "close 1002" (cons 8 (bytevector 3 234)) (read-frame s))))

(server-stop server)

(test-end "scm-websocket-upgrade")

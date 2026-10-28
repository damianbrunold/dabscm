(import (scheme base)
        (scheme write)
        (scm test)
        (scm io)
        (scm string)
        (srfi 18)
        (scm net sockets)
        (scm net http request)
        (scm net http response)
        (scm net http client)
        (scm net http server)
        (scm net websocket))

(test-runner-factory scm-test-runner)

(test-begin "net")

;;; ---- Type predicate tests (no I/O) ----
(test-group "type-predicates"
  (test-equal #f (socket? 42))
  (test-equal #f (socket? "x"))
  (test-equal #f (tcp-listener? #f))
  (test-equal #f (tcp-listener? 0))
  (test-equal #f (http-request? "x"))
  (test-equal #f (http-request? 42))
  (test-equal #t (http-request? (make-http-request "GET" "/" '() #f)))
  (test-equal #f (http-response? 42))
  (test-equal #t (http-response? (make-http-response 200 '() "ok")))
  (test-equal #f (thread? 42))
  (test-equal #f (mutex? 42))
  (test-equal #f (ws? 42)))

;;; ---- HTTP request accessor tests (no I/O) ----
(test-group "http-request-accessors"
  (test-equal "POST" (http-request-method (make-http-request "POST" "/api" '() "body")))
  (test-equal "/path" (http-request-url (make-http-request "GET" "/path" '() #f)))
  (test-equal #f (http-request-body (make-http-request "GET" "/" '() #f)))
  (test-equal "hello" (http-request-body (make-http-request "POST" "/" '() "hello")))
  (test-equal '() (http-request-headers (make-http-request "GET" "/" '() #f)))
  (test-equal "example.com"
    (http-request-header
      (make-http-request "GET" "/" '(("Host" . "example.com")) #f)
      "Host"))
  (test-equal #f
    (http-request-header
      (make-http-request "GET" "/" '(("Host" . "example.com")) #f)
      "Missing")))

(test-group "http-request-bearer-token"
  (define (bearer value)
    (http-request-bearer-token
      (make-http-request "GET" "/" (if value (list (cons "Authorization" value)) '()) #f)))
  (test-equal "abc.def" (bearer "Bearer abc.def"))
  (test-equal "abc" (bearer "  bearer   abc  "))
  (test-equal "abc" (bearer "BEARER abc"))
  (test-equal #f (bearer #f))
  (test-equal #f (bearer "Bearer "))
  (test-equal #f (bearer "Bearerabc"))
  (test-equal #f (bearer "Basic dXNlcjpwYXNz")))

;;; ---- HTTP response accessor tests (no I/O) ----
(test-group "http-response-accessors"
  (test-equal 404 (http-response-status (make-http-response 404 '() "Not Found")))
  (test-equal "Hello" (http-response-body (make-http-response 200 '() "Hello")))
  (test-equal 200 (http-response-status (http-ok "hi")))
  (test-equal "hello" (http-response-body (http-ok "hello")))
  (test-equal 404 (http-response-status (http-not-found)))
  (test-equal "Not Found" (http-response-body (http-not-found)))
  (test-equal 400 (http-response-status (http-bad-request "bad")))
  (test-equal 500 (http-response-status (http-internal-error "err"))))

;;; ---- Thread tests (no network) ----
(test-group "threads"
  (test-equal 3 (thread-join! (thread-start! (make-thread (lambda () (+ 1 2))))))
  (test-equal 42 (thread-join! (thread-start! (make-thread (lambda () (* 6 7))))))
  (test-equal 1
    (let ((m (make-mutex))
          (result 0))
      (let ((t (make-thread (lambda ()
                              (dynamic-wind
                                (lambda () (mutex-lock! m))
                                (lambda () (set! result (+ result 1)))
                                (lambda () (mutex-unlock! m)))))))
        (thread-start! t)
        (thread-join! t)
        result)))
  (test-equal #t (thread? (make-thread (lambda () 1))))
  (test-equal #t (mutex? (make-mutex))))

;;; ---- Loopback integration tests (wrapped in guard) ----
(test-group "loopback-integration"
  (test-equal 200
    (guard (exn (#t #f))
      (let* ((server (tcp-http-serve 18099
                       (lambda (req)
                         (http-ok (string-append "got " (http-request-url req))))))
             (resp (begin
                     ;; Give server a moment to start
                     (let loop ((n 0))
                       (if (< n 3)
                         (guard (e (#t (loop (+ n 1))))
                           (let ((r (http-get "http://localhost:18099/")))
                             r))
                         (http-get "http://localhost:18099/")))
                   )))
        (server-stop server)
        (http-response-status resp))))
  (test-equal "pong"
    (guard (exn (#t #f))
      (let* ((server (tcp-http-serve 18098
                       (lambda (req) (http-ok "pong"))))
             (resp (begin
                     (let loop ((n 0))
                       (if (< n 3)
                         (guard (e (#t (loop (+ n 1))))
                           (http-get "http://localhost:18098/ping"))
                         (http-get "http://localhost:18098/ping")))))
             (_ (server-stop server)))
        (http-response-body resp))))
  ;; A bytevector body is sent byte for byte (no UTF-8 round trip), and a
  ;; caller-supplied Content-Type reaches the server.
  (test-equal "application/octet-stream 0,255,128,10"
    (guard (exn (#t #f))
      (let* ((server (tcp-http-serve 18097
                       (lambda (req)
                         (let ((bv (http-request-body-bytes req)))
                           (http-ok
                            (string-append
                             (http-request-header req "Content-Type") " "
                             (number->string (bytevector-u8-ref bv 0)) ","
                             (number->string (bytevector-u8-ref bv 1)) ","
                             (number->string (bytevector-u8-ref bv 2)) ","
                             (number->string (bytevector-u8-ref bv 3))))))))
             (send (lambda ()
                     (http-send
                      (make-http-request
                       "PUT" "http://localhost:18097/bin"
                       '(("Content-Type" . "application/octet-stream"))
                       (bytevector 0 255 128 10)))))
             (resp (let loop ((n 0))
                     (if (< n 3)
                         (guard (e (#t (loop (+ n 1)))) (send))
                         (send))))
             (_ (server-stop server)))
        (http-response-body resp))))
  ;; http-get-bytevector keeps a binary body as it arrived: bytes that are
  ;; not valid UTF-8 survive.
  (test-equal (bytevector 80 75 3 4 0 255 128 10)
    (guard (exn (#t #f))
      (let* ((server (tcp-http-serve 18087
                       (lambda (req)
                         (make-http-response 200 '(("Content-Type" . "application/zip"))
                                             (bytevector 80 75 3 4 0 255 128 10)))))
             (get (lambda () (http-get-bytevector "http://localhost:18087/a.zip")))
             (resp (let loop ((n 0))
                     (if (< n 3)
                         (guard (e (#t (loop (+ n 1)))) (get))
                         (get))))
             (_ (server-stop server)))
        (http-response-body resp))))
  ;; Redirects are followed, by every client call (the C# client always
  ;; did; Java needs Redirect.NORMAL).
  (test-equal '((200 . "moved") (200 . #u8(109 111 118 101 100)) (200 . "moved"))
    (guard (exn (#t #f))
      (let* ((server (tcp-http-serve 18093
                       (lambda (req)
                         (if (string=? (http-request-url req) "/old")
                             (http-redirect "/new")
                             (http-ok "moved")))))
             (retry (lambda (thunk)
                      (let loop ((n 0))
                        (if (< n 3)
                            (guard (e (#t (loop (+ n 1)))) (thunk))
                            (thunk)))))
             (rs (map (lambda (thunk)
                        (let ((r (retry thunk)))
                          (cons (http-response-status r) (http-response-body r))))
                      (list
                       (lambda () (http-get "http://localhost:18093/old"))
                       (lambda () (http-get-bytevector "http://localhost:18093/old"))
                       (lambda ()
                         (http-send (make-http-request
                                     "GET" "http://localhost:18093/old" '() #f)))))))
        (server-stop server)
        rs)))
  ;; follow-redirects? #f (6th make-http-request argument): http-send
  ;; returns the 3xx with its headers.
  (test-equal '(303 "/new" "a=1")
    (guard (exn (#t #f))
      (let* ((server (tcp-http-serve 18094
                       (lambda (req)
                         (if (string=? (http-request-url req) "/old")
                             (make-http-response 303 '(("Location" . "/new")
                                                       ("Set-Cookie" . "a=1"))
                                                 "")
                             (http-ok "moved")))))
             (send (lambda ()
                     (http-send (make-http-request
                                 "POST" "http://localhost:18094/old" '() "x" 600 #f))))
             (r (let loop ((n 0))
                  (if (< n 3)
                      (guard (e (#t (loop (+ n 1)))) (send))
                      (send)))))
        (server-stop server)
        (list (http-response-status r)
              (http-response-header r "Location")
              (http-response-header r "Set-Cookie")))))
  ;; A refused connection names its cause instead of "null" (nothing
  ;; listens on 18092).
  (test-equal '(#t #t #t #t)
    (map (lambda (thunk)
           (guard (e ((error-object? e)
                      (let ((m (error-object-message e)))
                        (not (string=? (substring m (- (string-length m) 4)
                                                  (string-length m))
                                       "null")))))
             (thunk)
             'no-error))
         (list
          (lambda () (http-get "http://localhost:18092/"))
          (lambda () (http-get-bytevector "http://localhost:18092/"))
          (lambda () (http-post "http://localhost:18092/" "x"))
          (lambda () (http-send (make-http-request "GET" "http://localhost:18092/" '() #f)))))))

;;; ---- Response bodies: text decoded, anything else kept as bytes ----
(test-group "response-bodies"
  ;; A PNG signature is not valid UTF-8: decoded as text it came back
  ;; corrupted. Whatever the call, a body that is not text arrives as the
  ;; bytes that were sent; text is decoded by its charset, UTF-8 or not,
  ;; and Content-Type is among the headers on both implementations.
  (let* ((png (bytevector 137 80 78 71 13 10 26 10 0 255))
         (server (tcp-http-serve 18089
                   (lambda (req)
                     (let ((url (http-request-url req)))
                       (cond
                        ((string=? url "/latin1")
                         (make-http-response 200 '(("Content-Type" . "text/plain; charset=iso-8859-1"))
                                             (bytevector 90 252 114 105 99 104)))
                        ((string=? url "/json")
                         (make-http-response 200 '(("Content-Type" . "application/json"))
                                             "{\"a\":\"\x00e4;\"}"))
                        (else
                         (make-http-response 200 '(("Content-Type" . "image/png")) png)))))))
         (retry (lambda (thunk)
                  (let loop ((n 0))
                    (if (< n 3)
                        (guard (e (#t (loop (+ n 1)))) (thunk))
                        (thunk)))))
         (body (lambda (thunk) (guard (e (#t (list 'error e))) (http-response-body (retry thunk)))))
         (results
          (list
           (body (lambda () (http-get "http://localhost:18089/a.png")))
           (body (lambda () (http-post "http://localhost:18089/a.png" "x")))
           (body (lambda () (http-send (make-http-request "GET" "http://localhost:18089/a.png" '() #f))))
           (body (lambda () (http-get "http://localhost:18089/latin1")))
           (body (lambda () (http-get "http://localhost:18089/json")))
           (guard (e (#t #f))
             (http-response-header (retry (lambda () (http-get "http://localhost:18089/a.png")))
                                   "Content-Type")))))
    (server-stop server)
    (test-equal png (list-ref results 0))
    (test-equal png (list-ref results 1))
    (test-equal png (list-ref results 2))
    (test-equal "Z\x00fc;rich" (list-ref results 3))
    (test-equal "{\"a\":\"\x00e4;\"}" (list-ref results 4))
    (test-equal "image/png" (list-ref results 5))))

;;; ---- Hardening tests (max-body, 503 saturation, host bind) ----
(test-group "hardening"
  ;; 413 Payload Too Large: max-body-bytes=8 rejects a 100-byte body.
  (test-equal 413
    (guard (exn (#t -1))
      (let* ((server (tcp-http-serve 18086
                                     (lambda (req) (http-ok "should-not-run"))
                                     0   ; max-threads (default)
                                     ""  ; host (default)
                                     30000
                                     8)) ; max-body-bytes
             (resp (let loop ((n 0))
                     (if (< n 3)
                         (guard (e (#t (loop (+ n 1))))
                           (http-post "http://localhost:18086/"
                                      "01234567890123456789"
                                      '(("Content-Type" . "text/plain"))))
                         (http-post "http://localhost:18086/"
                                    "01234567890123456789"
                                    '(("Content-Type" . "text/plain")))))))
        (server-stop server 0)
        (http-response-status resp))))
  ;; Bind host: 127.0.0.1-only server reachable via localhost.
  (test-equal "loopback-only"
    (guard (exn (#t #f))
      (let* ((server (tcp-http-serve 18096
                                     (lambda (req) (http-ok "loopback-only"))
                                     0
                                     "127.0.0.1"))
             (resp (let loop ((n 0))
                     (if (< n 3)
                         (guard (e (#t (loop (+ n 1))))
                           (http-get "http://127.0.0.1:18096/"))
                         (http-get "http://127.0.0.1:18096/"))))
             (_ (server-stop server 0)))
        (http-response-body resp))))
  ;; A raising handler yields a bare 500: the error message (which may
  ;; quote request data or secrets) goes to the server log, not the client.
  (test-equal '(500 "Internal Server Error")
    (guard (exn (#t #f))
      (let* ((server (tcp-http-serve 18085
                                     (lambda (req) (error "secret" "hunter2"))
                                     0
                                     "127.0.0.1"))
             (resp (let loop ((n 0))
                     (if (< n 3)
                         (guard (e (#t (loop (+ n 1))))
                           (http-get "http://127.0.0.1:18085/"))
                         (http-get "http://127.0.0.1:18085/"))))
             (_ (server-stop server 0)))
        (list (http-response-status resp) (http-response-body resp)))))
  ;; HEAD: the full headers (Content-Length of the body) but no body.
  (test-equal '(#t #t)
    (guard (exn (#t #f))
      (let* ((server (tcp-http-serve 18088
                                     (lambda (req) (http-ok "hello body"))
                                     0
                                     "127.0.0.1"))
             (raw (let loop ((n 0))
                    (guard (e (#t (if (< n 3) (begin (thread-sleep! 0.2) (loop (+ n 1))) (raise e))))
                      (with-tcp-connection "127.0.0.1" 18088
                        (lambda (sock)
                          (let ((out (socket-output-port sock)))
                            (write-string "HEAD / HTTP/1.1\r\nHost: x\r\n\r\n" out)
                            (flush-output-port out))
                          (let ((in (socket-input-port sock)))
                            (let read-all ((acc '()))
                              (let ((c (read-char in)))
                                (if (eof-object? c)
                                    (list->string (reverse acc))
                                    (read-all (cons c acc)))))))))))
             (_ (server-stop server 0))
             (n (string-length raw))
             (end "\r\n\r\n"))
        (list (and (string-contains-from raw "Content-Length: 10" 0) #t)
              ;; the response ends right after the blank line
              (and (>= n 4) (string=? (substring raw (- n 4) n) end)))))))

(test-group "http-response-helpers"
  (test-equal 401 (http-response-status (http-unauthorized)))
  (test-equal "Unauthorized" (http-response-body (http-unauthorized)))
  (test-equal "please log in" (http-response-body (http-unauthorized "please log in")))
  (test-equal 403 (http-response-status (http-forbidden)))
  (test-equal "Forbidden" (http-response-body (http-forbidden)))
  (test-equal "admin only" (http-response-body (http-forbidden "admin only")))
  (test-equal 302 (http-response-status (http-redirect "/x")))
  (test-equal "/x" (http-response-header (http-redirect "/x") "Location"))
  (test-equal 303 (http-response-status (http-see-other "/y")))
  (test-equal "/y" (http-response-header (http-see-other "/y") "Location"))
  (test-equal 301 (http-response-status (http-permanent-redirect "/z")))
  (test-equal "/z" (http-response-header (http-permanent-redirect "/z") "Location"))
  (test-equal "text/html; charset=utf-8"
              (http-response-header (html-response "<p/>") "Content-Type"))
  (test-equal "<p/>" (http-response-body (html-response "<p/>")))
  (test-equal "application/json; charset=utf-8"
              (http-response-header (json-response "{}") "Content-Type"))
  (test-equal "text/plain; charset=utf-8"
              (http-response-header (text-response "hi") "Content-Type")))

(test-end "net")

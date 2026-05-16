(import (scheme base)
        (scheme write)
        (scm test)
        (scm io)
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
        (http-response-body resp)))))

;;; ---- Hardening tests (max-body, 503 saturation, host bind) ----
(test-group "hardening"
  ;; 413 Payload Too Large: max-body-bytes=8 rejects a 100-byte body.
  (test-equal 413
    (guard (exn (#t -1))
      (let* ((server (tcp-http-serve 18097
                                     (lambda (req) (http-ok "should-not-run"))
                                     0   ; max-threads (default)
                                     ""  ; host (default)
                                     30000
                                     8)) ; max-body-bytes
             (resp (let loop ((n 0))
                     (if (< n 3)
                         (guard (e (#t (loop (+ n 1))))
                           (http-post "http://localhost:18097/"
                                      "01234567890123456789"
                                      '(("Content-Type" . "text/plain"))))
                         (http-post "http://localhost:18097/"
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
        (http-response-body resp)))))

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

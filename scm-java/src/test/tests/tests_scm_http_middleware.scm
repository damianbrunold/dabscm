(import (scheme base)
        (scm string)
        (scm log)
        (scm net http request)
        (scm net http response)
        (scm net http middleware)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-http-middleware")

(define (req url) (make-http-request "GET" url '() #f))

;; Runs thunk with (scm log) output captured; returns (result . log-text).
(define (with-log thunk)
  (let ((p (open-output-string)))
    (let ((r (parameterize ((log-port p)) (thunk))))
      (cons r (get-output-string p)))))

(define (contains? s part) (and (string-contains-from s part 0) #t))

(define (boom r) (error "db password is" "hunter2"))
(define (ok r) (http-ok "fine"))

(test-group "with-error-handler"
  (let* ((out (with-log (lambda () ((with-error-handler boom) (req "/x?token=abc")))))
         (resp (car out)))
    (test-equal 500 (http-response-status resp))
    (test-equal "Internal Server Error" (http-response-body resp))
    (test-assert "logged" (contains? (cdr out) "ERROR [http] GET /x raised: db password is \"hunter2\""))
    (test-assert "no query in log" (not (contains? (cdr out) "token=abc"))))
  ;; custom error page keeps its body and headers but is always a 500
  (let ((resp (car (with-log
                    (lambda ()
                      ((with-error-handler boom (lambda (r) (html-response "<h1>Oops</h1>")))
                       (req "/")))))))
    (test-equal 500 (http-response-status resp))
    (test-equal "<h1>Oops</h1>" (http-response-body resp)))
  ;; a failing error page falls back to the plain 500
  (test-equal "Internal Server Error"
    (http-response-body
     (car (with-log (lambda () ((with-error-handler boom boom) (req "/")))))))
  ;; non-response return values
  (let ((out (with-log (lambda () ((with-error-handler (lambda (r) 'oops)) (req "/y"))))))
    (test-equal 500 (http-response-status (car out)))
    (test-assert (contains? (cdr out) "did not return an http-response")))
  ;; raising a non-condition
  (test-equal 500 (http-response-status
                   (car (with-log (lambda () ((with-error-handler (lambda (r) (raise 'x))) (req "/")))))))
  ;; normal responses pass through, nothing logged
  (let ((out (with-log (lambda () ((with-error-handler ok) (req "/"))))))
    (test-equal "fine" (http-response-body (car out)))
    (test-equal "" (cdr out))))

(test-group "with-access-log"
  (let ((out (with-log (lambda () ((with-access-log ok) (req "/a/b?q=secret"))))))
    (test-equal "fine" (http-response-body (car out)))
    (test-assert (contains? (cdr out) "INFO  [http] GET /a/b -> 200 ("))
    (test-assert (not (contains? (cdr out) "secret"))))
  (let ((out (with-log (lambda ()
                         ((with-access-log ok `((log-url . ,(lambda (u) u))))
                          (req "/a?q=1"))))))
    (test-assert (contains? (cdr out) "GET /a?q=1 -> 200")))
  ;; inner raise: logged as 500, re-raised
  (let* ((p (open-output-string))
         (raised (parameterize ((log-port p))
                   (guard (e (#t 'reraised))
                     ((with-access-log boom) (req "/z"))))))
    (test-equal 'reraised raised)
    (test-assert (contains? (get-output-string p) "GET /z -> 500")))
  ;; the intended nesting: error handler inside the access log
  (let ((out (with-log (lambda () ((with-access-log (with-error-handler boom)) (req "/n"))))))
    (test-equal 500 (http-response-status (car out)))
    (test-assert (contains? (cdr out) "GET /n -> 500"))))

(test-group "with-response-headers / with-security-headers"
  (let ((resp ((with-security-headers ok) (req "/"))))
    (test-assert (contains? (http-response-header resp "Content-Security-Policy")
                            "frame-ancestors 'none'"))
    (test-equal "nosniff" (http-response-header resp "X-Content-Type-Options"))
    (test-equal "DENY" (http-response-header resp "X-Frame-Options"))
    (test-equal "same-origin" (http-response-header resp "Referrer-Policy"))
    (test-equal "fine" (http-response-body resp)))
  ;; a header the handler set wins (case-insensitive)
  (let ((resp ((with-security-headers
                (lambda (r) (make-http-response 200 '(("content-security-policy" . "mine")) "")))
               (req "/"))))
    (test-equal "mine" (http-response-header resp "Content-Security-Policy")))
  ;; custom CSP
  (test-equal "default-src 'none'"
    (http-response-header ((with-security-headers ok "default-src 'none'") (req "/"))
                          "Content-Security-Policy"))
  (test-equal 4 (length security-headers))
  (test-equal "no-store"
    (http-response-header ((with-response-headers ok '(("Cache-Control" . "no-store"))) (req "/"))
                          "Cache-Control")))

(test-end "scm-http-middleware")

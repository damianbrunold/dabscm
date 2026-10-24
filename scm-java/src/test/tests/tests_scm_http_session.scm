(import (scheme base)
        (scm crypto)
        (scm string)
        (scm net http request)
        (scm net http session)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-http-session")

(define secret (base64-encode (random-bytes 32)))
(define cfg (make-session-config "app_session" secret 3600))
(define dev (make-session-config "app_session" secret 3600
                                 '((path . "/app/") (secure? . #f))))

;; "name=value; attr; ..." -> value
(define (cookie-value header)
  (let* ((first (car (string-split-char header #\;)))
         (eq (let loop ((i 0))
               (if (char=? (string-ref first i) #\=) i (loop (+ i 1))))))
    (substring first (+ eq 1) (string-length first))))

(define (request-with-cookie value)
  (make-http-request "GET" "/" (list (cons "Cookie" (string-append "other=1; app_session=" value))) #f))

(test-group "set-cookie header"
  (let ((h (session-set-cookie cfg '((uid . 7)))))
    (test-equal "Set-Cookie" (car h))
    (test-assert (string-contains-from (cdr h) "; Path=/;" 0))
    (test-assert (string-contains-from (cdr h) "Max-Age=3600" 0))
    (test-assert (string-contains-from (cdr h) "HttpOnly" 0))
    (test-assert (string-contains-from (cdr h) "SameSite=Strict" 0))
    (test-assert (string-contains-from (cdr h) "Secure" 0)))
  (let ((h (session-set-cookie dev 'x)))
    (test-assert (string-contains-from (cdr h) "; Path=/app/;" 0))
    (test-assert (not (string-contains-from (cdr h) "Secure" 0)))))

(test-group "session-ref"
  (let ((value (cookie-value (cdr (session-set-cookie cfg '((uid . 7)))))))
    (test-equal '((uid . 7)) (session-ref cfg (request-with-cookie value)))
    ;; another secret, or another purpose, rejects it
    (test-equal #f (session-ref (make-session-config "app_session"
                                                     (base64-encode (random-bytes 32)) 3600)
                                (request-with-cookie value)))
    (test-equal #f (session-ref (make-session-config "app_session" secret 3600
                                                     '((purpose . "other")))
                                (request-with-cookie value))))
  (test-equal #f (session-ref cfg (make-http-request "GET" "/" '() #f)))
  (test-equal #f (session-ref cfg (request-with-cookie "forged.value"))))

(test-group "session-clear-cookie"
  (let ((h (session-clear-cookie cfg)))
    (test-equal "" (cookie-value (cdr h)))
    (test-assert (string-contains-from (cdr h) "Max-Age=0" 0))))

(test-group "bad secret fails at configuration time"
  (test-error (make-session-config "s" "REPLACE_WITH_BASE64_SECRET" 60)))

(test-equal 3600 (session-config-max-age cfg))

(test-end "scm-http-session")

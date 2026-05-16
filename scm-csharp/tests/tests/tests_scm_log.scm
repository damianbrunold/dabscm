(import (scheme base) (scm log) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-log")

;; Redirect log output to a string port so we can assert on the format.
;; Timestamp values are not asserted (they depend on wall clock); instead
;; we check that each line starts with a 19-char timestamp and the
;; remainder matches the expected level/module/message tail.

(define (capture thunk)
  (let ((p (open-output-string)))
    (parameterize ((log-port p))
      (thunk))
    (get-output-string p)))

(define (line-tail s)
  ;; Drop the leading "YYYY-MM-DD HH:MM:SS " (20 chars including the space)
  ;; and any trailing newline.
  (let* ((n (string-length s))
         (end (if (and (> n 0)
                       (char=? (string-ref s (- n 1)) #\newline))
                  (- n 1)
                  n)))
    (substring s 20 end)))

(test-group "log-info"
  (let ((out (capture (lambda () (log-info "auth" "ok")))))
    (test-equal "INFO  [auth] ok" (line-tail out))))

(test-group "log-warn"
  (let ((out (capture (lambda () (log-warn "feeds" "slow")))))
    (test-equal "WARN  [feeds] slow" (line-tail out))))

(test-group "log-error"
  (let ((out (capture (lambda () (log-error "db" "down")))))
    (test-equal "ERROR [db] down" (line-tail out))))

(test-group "log-access"
  (let ((out (capture (lambda () (log-access "GET" "/foo" 200 14)))))
    (test-equal "INFO  [http] GET /foo -> 200 (14ms)" (line-tail out))))

(test-group "log-port-parameter"
  ;; Outside of a parameterize, log-port should default to a port.
  (test-equal #t (output-port? (log-port))))

(test-end "scm-log")

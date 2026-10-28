(define-library (scm net http middleware)
  (import (scm core)
          (scheme base)
          (scheme char)
          (scheme time)
          (scheme write)
          (scm log)
          (scm net http request)
          (scm net http response)
          (scm net http route))
  (export with-error-handler
          with-access-log
          with-response-headers
          with-security-headers
          security-headers)
  (begin

    ;; Each wrapper takes a server-level handler (lambda (req) resp) and
    ;; returns one, so they nest around (router->handler router):
    ;;
    ;;   (with-access-log
    ;;     (with-security-headers
    ;;       (with-error-handler (router->handler router) render-500)))

    (define (internal-error)
      (make-http-response 500 '(("Content-Type" . "text/plain; charset=utf-8"))
                          "Internal Server Error"))

    (define (describe-condition e)
      (let ((p (open-output-string)))
        (cond
          ((error-object? e)
           (display (error-object-message e) p)
           (for-each (lambda (x) (write-char #\space p) (write x p))
                     (error-object-irritants e)))
          (else (write e p)))
        (get-output-string p)))

    (define (request-label req)
      (string-append (http-request-method req) " "
                     (url-path (http-request-url req))))

    (define (with-error-handler handler . render)
      "Syntax: (with-error-handler handler [render])
Library: (scm net http middleware)
Description: Wraps handler so that an error it raises, or a return value
  that is not an http-response, is logged with log-error (module \"http\":
  method, path without query string, message and irritants) and answered
  with (render req), or a plain-text 500 Internal Server Error when render
  is omitted or itself fails. The client never sees the error text.
Example:
  (with-error-handler (router->handler router)
    (lambda (req) (html-response \"<h1>Something went wrong</h1>\")))"
      (let ((render (and (pair? render) (car render))))
        (define (fail req detail)
          (log-error "http" (string-append (request-label req) " " detail))
          (if render
              (guard (e (#t (log-error "http" (string-append
                                               "error page failed: "
                                               (describe-condition e)))
                            (internal-error)))
                (let ((resp (render req)))
                  (if (http-response? resp)
                      (http-response-with-headers resp 500 (http-response-headers resp))
                      (internal-error))))
              (internal-error)))
        (lambda (req)
          (let ((outcome
                 (guard (e (#t (cons 'raised e)))
                   (cons 'returned (handler req)))))
            (cond
              ((eq? (car outcome) 'raised)
               (fail req (string-append "raised: " (describe-condition (cdr outcome)))))
              ((http-response? (cdr outcome)) (cdr outcome))
              (else (fail req "handler did not return an http-response")))))))

    (define (elapsed-ms start)
      (quotient (* 1000 (- (current-jiffy) start)) (jiffies-per-second)))

    (define (with-access-log handler . opts)
      "Syntax: (with-access-log handler [opts])
Library: (scm net http middleware)
Description: Wraps handler so every request writes one log-access line:
  method, URL, status and duration in ms. By default the URL is logged
  without its query string, which can carry search terms or tokens; the
  option (log-url . proc) maps the request URL to the logged text instead
  (e.g. to redact ids, or values to log full URLs). If handler raises, the
  request is logged as 500 and the error is re-raised, so put
  with-error-handler inside this wrapper.
Example:
  (with-access-log handler `((log-url . ,(lambda (u) u))))"
      (let* ((opts (if (pair? opts) (car opts) '()))
             (log-url (let ((p (assq 'log-url opts)))
                        (if p (cdr p) url-path))))
        (lambda (req)
          (let ((start (current-jiffy))
                (method (http-request-method req))
                (shown (log-url (http-request-url req))))
            (guard (e (#t (log-access method shown 500 (elapsed-ms start))
                          (raise e)))
              (let ((resp (handler req)))
                (log-access method shown
                            (if (http-response? resp) (http-response-status resp) 500)
                            (elapsed-ms start))
                resp))))))

    (define (has-header? headers name)
      (let loop ((hs headers))
        (and (pair? hs)
             (or (string-ci=? (car (car hs)) name)
                 (loop (cdr hs))))))

    (define (with-response-headers handler headers)
      "Syntax: (with-response-headers handler headers)
Library: (scm net http middleware)
Description: Wraps handler so each response also carries the (name .
  value) pairs in headers, except those the response already sets
  (compared case-insensitively). A handler can therefore override a
  default, e.g. relax the Content-Security-Policy for one route.
Example:
  (with-response-headers handler '((\"Cache-Control\" . \"no-store\")))"
      (lambda (req)
        (let ((resp (handler req)))
          (if (not (http-response? resp))
              resp
              (let* ((own (http-response-headers resp))
                     (extra (let loop ((hs headers) (acc '()))
                              (cond
                                ((null? hs) (reverse acc))
                                ((has-header? own (car (car hs))) (loop (cdr hs) acc))
                                (else (loop (cdr hs) (cons (car hs) acc)))))))
                (if (null? extra)
                    resp
                    (http-response-with-headers resp (http-response-status resp)
                                                (append own extra))))))))

    (define security-headers
      '(("Content-Security-Policy"
         . "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'; object-src 'none'")
        ("X-Content-Type-Options" . "nosniff")
        ("Referrer-Policy" . "same-origin")
        ("X-Frame-Options" . "DENY")))

    (define (with-security-headers handler . csp)
      "Syntax: (with-security-headers handler [csp])
Library: (scm net http middleware)
Description: Wraps handler with with-response-headers and
  security-headers: a same-origin Content-Security-Policy (no inline
  scripts or styles, no framing), X-Content-Type-Options: nosniff,
  Referrer-Policy: same-origin and X-Frame-Options: DENY. csp, a string,
  replaces the default policy, e.g. to allow inline style attributes.
Example:
  (with-security-headers handler
    \"default-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'\")"
      (with-response-headers
       handler
       (if (pair? csp)
           (cons (cons "Content-Security-Policy" (car csp))
                 (cdr security-headers))
           security-headers)))
))

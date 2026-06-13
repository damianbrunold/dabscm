;; (app auth) — password hashing and stateless signed-cookie sessions.
;;
;; Same scheme as starter-login, except the session token carries the user
;; *id* (a stable database key) rather than the username. This module is
;; deliberately database-free: it only encodes/decodes and verifies tokens.
;; The route layer turns an id into a user record via (app users), which
;; keeps the dependency one-way and avoids a cycle.

(define-library (app auth)
  (import (scheme base)
          (scheme time)
          (scm crypto)
          (scm net http request)
          (scm net http response)
          (scm net http cookies)
          (srfi 13))
  (export hash-password
          verify-password
          make-auth
          token-user-id
          login-redirect
          logout-redirect)
  (begin

    (define pbkdf2-iterations 200000)

    (define (hash-password plain)
      "Syntax: (hash-password plain)
Library: (app auth)
Description: Returns pbkdf2$<iter>$<salt-b64>$<hash-b64> for the password."
      (let* ((salt (random-bytes 16))
             (dk (pbkdf2-sha256 (string->utf8 plain) salt pbkdf2-iterations 32)))
        (string-append "pbkdf2$" (number->string pbkdf2-iterations) "$"
                       (base64-encode salt) "$" (base64-encode dk))))

    (define (split-fields s)
      (let loop ((i 0) (start 0) (acc '()))
        (cond
          ((= i (string-length s))
           (reverse (cons (substring s start i) acc)))
          ((char=? (string-ref s i) #\$)
           (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
          (else (loop (+ i 1) start acc)))))

    (define (verify-password plain stored)
      "Syntax: (verify-password plain stored)
Library: (app auth)
Description: Constant-time check of plaintext against a pbkdf2$... string."
      (let ((parts (split-fields stored)))
        (and (= (length parts) 4)
             (string=? (car parts) "pbkdf2")
             (let* ((iter (string->number (list-ref parts 1)))
                    (salt (base64-decode (list-ref parts 2)))
                    (want (base64-decode (list-ref parts 3))))
               (and iter
                    (constant-time-bytevector=?
                     (pbkdf2-sha256 (string->utf8 plain) salt iter
                                    (bytevector-length want))
                     want))))))

    (define-record-type auth
      (auth* cookie-name secret max-age secure?)
      auth?
      (cookie-name auth-cookie-name)
      (secret auth-secret)
      (max-age auth-max-age)
      (secure? auth-secure?))

    (define (make-auth cookie-name secret-b64 max-age secure?)
      "Syntax: (make-auth cookie-name secret-b64 max-age secure?)
Library: (app auth)
Description: Session config. secret-b64 is base64 of the HMAC signing key."
      (auth* cookie-name (base64-decode secret-b64) max-age secure?))

    (define (now) (exact (round (current-second))))

    (define (sign auth user-id)
      (let* ((payload (string-append user-id "|"
                                     (number->string (+ (now) (auth-max-age auth)))))
             (pb (string->utf8 payload)))
        (string-append (base64-encode pb) "."
                       (bytevector->hex (hmac-sha256 (auth-secret auth) pb)))))

    (define (token-user-id auth req)
      "Syntax: (token-user-id auth req)
Library: (app auth)
Description: Returns the user id (a string) from the request's valid,
  unexpired session cookie, or #f."
      (let ((token (cookie-ref
                    (parse-cookie-header (http-request-header req "Cookie"))
                    (auth-cookie-name auth))))
        (and (string? token)
             (let ((dot (string-index token #\.)))
               (and dot
                    (guard (e (#t #f))
                      (let* ((pb (base64-decode (substring token 0 dot)))
                             (got (hex->bytevector
                                   (substring token (+ dot 1) (string-length token))))
                             (calc (hmac-sha256 (auth-secret auth) pb)))
                        (and (constant-time-bytevector=? calc got)
                             (let* ((payload (utf8->string pb))
                                    (bar (string-index payload #\|))
                                    (uid (substring payload 0 bar))
                                    (exp (string->number
                                          (substring payload (+ bar 1)
                                                     (string-length payload)))))
                               (and exp (> exp (now)) uid))))))))))

    (define (set-cookie auth value max-age)
      (apply format-set-cookie (auth-cookie-name auth) value max-age "/"
             (if (auth-secure? auth) '() '(no-secure))))

    (define (login-redirect auth user-id location)
      "Syntax: (login-redirect auth user-id location)
Library: (app auth)
Description: 303 redirect to location, setting a session cookie for user-id."
      (make-http-response 303
        (list (cons "Location" location)
              (cons "Set-Cookie" (set-cookie auth (sign auth user-id)
                                             (auth-max-age auth))))
        ""))

    (define (logout-redirect auth location)
      "Syntax: (logout-redirect auth location)
Library: (app auth)
Description: 303 redirect to location that clears the session cookie."
      (make-http-response 303
        (list (cons "Location" location)
              (cons "Set-Cookie" (set-cookie auth "" 0)))
        ""))))

;; (app auth) — password hashing and stateless bearer tokens for a JSON API.
;;
;; Passwords: PBKDF2-HMAC-SHA256 with a per-user random salt, stored as
;; pbkdf2$<iter>$<salt-b64>$<hash-b64>. Tokens: a base64 payload
;; ("subject|expiry") plus an HMAC-SHA256 signature, sent by the client in
;; the Authorization: Bearer header. No server-side token store.

(define-library (app auth)
  (import (scheme base)
          (scheme time)
          (scheme char)
          (scm crypto)
          (scm net http request)
          (srfi 13))
  (export hash-password
          verify-password
          make-auth auth-max-age
          issue-token token-subject
          bearer-token)
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
      (auth* secret max-age)
      auth?
      (secret auth-secret)
      (max-age auth-max-age))

    (define (make-auth secret-b64 max-age)
      "Syntax: (make-auth secret-b64 max-age)
Library: (app auth)
Description: Token config. secret-b64 is base64 of the HMAC signing key;
  max-age is the token lifetime in seconds."
      (auth* (base64-decode secret-b64) max-age))

    (define (now) (exact (round (current-second))))

    (define (issue-token auth subject)
      "Syntax: (issue-token auth subject)
Library: (app auth)
Description: Returns a signed bearer token for subject, valid for max-age."
      (let* ((payload (string-append subject "|"
                                     (number->string (+ (now) (auth-max-age auth)))))
             (pb (string->utf8 payload)))
        (string-append (base64-encode pb) "."
                       (bytevector->hex (hmac-sha256 (auth-secret auth) pb)))))

    (define (token-subject auth token)
      "Syntax: (token-subject auth token)
Library: (app auth)
Description: Returns the subject of a valid, unexpired token, or #f."
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
                                  (sub (substring payload 0 bar))
                                  (exp (string->number
                                        (substring payload (+ bar 1)
                                                   (string-length payload)))))
                             (and exp (> exp (now)) sub)))))))))

    (define (bearer-token req)
      "Syntax: (bearer-token req)
Library: (app auth)
Description: Returns the token from an 'Authorization: Bearer <token>'
  header, or #f if absent/malformed."
      (let ((h (http-request-header req "Authorization")))
        (and h
             (let ((h* (string-trim h)))
               (and (>= (string-length h*) 7)
                    (string-ci=? (substring h* 0 7) "Bearer ")
                    (string-trim (substring h* 7 (string-length h*))))))))))

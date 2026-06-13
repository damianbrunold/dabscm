;; (app auth) — password hashing and stateless signed-cookie sessions.
;;
;; Passwords are stored as PBKDF2-HMAC-SHA256 with a per-user random salt,
;; in the self-describing string  pbkdf2$<iterations>$<salt-b64>$<hash-b64>.
;; Sessions are stateless: the cookie carries "username|expiry" plus an
;; HMAC-SHA256 signature, so no server-side session store is needed. The
;; signature is verified in constant time and the expiry is enforced.

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
          current-user
          login-redirect
          logout-redirect)
  (begin

    (define pbkdf2-iterations 200000)
    (define salt-bytes 16)
    (define key-bytes 32)

    ;; --- password hashing ---------------------------------------------

    (define (hash-password plain)
      "Syntax: (hash-password plain)
Library: (app auth)
Description: Returns a PBKDF2 hash string for the plaintext password,
  with a fresh random salt. Store this verbatim; verify with verify-password."
      (let* ((salt (random-bytes salt-bytes))
             (dk (pbkdf2-sha256 (string->utf8 plain) salt
                                pbkdf2-iterations key-bytes)))
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
Description: Checks plaintext against a stored pbkdf2$... string (as
  produced by hash-password). Constant-time comparison. Returns a boolean."
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

    ;; --- session record -----------------------------------------------

    (define-record-type auth
      (auth* cookie-name secret max-age secure?)
      auth?
      (cookie-name auth-cookie-name)
      (secret auth-secret)        ; bytevector
      (max-age auth-max-age)
      (secure? auth-secure?))

    (define (make-auth cookie-name secret-b64 max-age secure?)
      "Syntax: (make-auth cookie-name secret-b64 max-age secure?)
Library: (app auth)
Description: Builds the session config. secret-b64 is the base64 of the
  HMAC signing key (generate with random-bytes). max-age is in seconds;
  secure? adds the Secure cookie attribute (disable for local HTTP)."
      (auth* cookie-name (base64-decode secret-b64) max-age secure?))

    (define (now) (exact (round (current-second))))

    ;; --- token sign / verify ------------------------------------------

    (define (sign auth username)
      (let* ((payload (string-append username "|"
                                     (number->string (+ (now) (auth-max-age auth)))))
             (pb (string->utf8 payload)))
        (string-append (base64-encode pb) "."
                       (bytevector->hex (hmac-sha256 (auth-secret auth) pb)))))

    (define (verify auth token)
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
                                  (user (substring payload 0 bar))
                                  (exp (string->number
                                        (substring payload (+ bar 1)
                                                   (string-length payload)))))
                             (and exp (> exp (now)) user)))))))))

    ;; --- request helpers ----------------------------------------------

    (define (current-user auth req)
      "Syntax: (current-user auth req)
Library: (app auth)
Description: Returns the authenticated username from the request's session
  cookie, or #f if absent/invalid/expired."
      (let ((tok (cookie-ref
                  (parse-cookie-header (http-request-header req "Cookie"))
                  (auth-cookie-name auth))))
        (and tok (verify auth tok))))

    (define (set-cookie auth value max-age)
      (apply format-set-cookie (auth-cookie-name auth) value max-age "/"
             (if (auth-secure? auth) '() '(no-secure))))

    (define (login-redirect auth username location)
      "Syntax: (login-redirect auth username location)
Library: (app auth)
Description: 303 redirect to location that also sets a fresh session cookie
  for username. Use after a successful login."
      (make-http-response 303
        (list (cons "Location" location)
              (cons "Set-Cookie" (set-cookie auth (sign auth username)
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

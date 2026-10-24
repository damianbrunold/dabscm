(define-library (scm net http session)
  (import (scm core)
          (scheme base)
          (scm crypto token)
          (scm net http request)
          (scm net http cookies))
  (export make-session-config
          session-config?
          session-config-max-age
          session-ref
          session-set-cookie
          session-clear-cookie)
  (begin

    ;; Stateless sessions: the cookie holds a (scm crypto token) token,
    ;; so there is no server-side store. Cookies are always HttpOnly and
    ;; SameSite=Strict (format-set-cookie), which also keeps cross-site
    ;; form posts from carrying the session.

    (define-record-type session-config
      (%make-session-config name keys max-age path secure? purpose)
      session-config?
      (name    session-config-name)
      (keys    session-config-keys)
      (max-age session-config-max-age)
      (path    session-config-path)
      (secure? session-config-secure?)
      (purpose session-config-purpose))

    (define (opt-ref opts key default)
      (let ((p (assq key opts)))
        (if p (cdr p) default)))

    (define (make-session-config cookie-name secret max-age . opts)
      "Syntax: (make-session-config cookie-name secret max-age [opts])
Library: (scm net http session)
Description: Builds the configuration for signed-cookie sessions.
  secret is a bytevector, a base64 string, or a list of them (newest
  first) as for token-secrets; an invalid or short secret raises here, at
  startup. max-age is the session lifetime in seconds. opts is an alist:
  (path . \"/\") scopes the cookie (use \"/prefix/\" when the app is
  mounted under a URL prefix), (secure? . #t) sets the Secure attribute
  (set #f only for local HTTP), (purpose . \"session\") is the token
  purpose.
Example:
  (make-session-config \"app_session\" secret (* 60 60 12)
                       '((path . \"/app/\") (secure? . #f)))"
      (let ((opts (if (pair? opts) (car opts) '())))
        (%make-session-config cookie-name
                              (token-secrets secret)
                              max-age
                              (opt-ref opts 'path "/")
                              (opt-ref opts 'secure? #t)
                              (opt-ref opts 'purpose "session"))))

    (define (session-ref cfg req)
      "Syntax: (session-ref cfg req)
Library: (scm net http session)
Description: Returns the datum stored in req's session cookie, or #f if
  there is no cookie or it is invalid or expired.
Example:
  (session-ref cfg req) => ((uid . 42) (name . \"alice\"))"
      (let ((tok (cookie-ref (parse-cookie-header (http-request-header req "Cookie"))
                             (session-config-name cfg))))
        (and tok
             (token-verify (session-config-keys cfg) tok
                           (list (cons 'purpose (session-config-purpose cfg)))))))

    (define (cookie-header cfg value max-age)
      (cons "Set-Cookie"
            (apply format-set-cookie (session-config-name cfg) value max-age
                   (session-config-path cfg)
                   (if (session-config-secure? cfg) '() '(no-secure)))))

    (define (session-set-cookie cfg datum)
      "Syntax: (session-set-cookie cfg datum)
Library: (scm net http session)
Description: Returns a (\"Set-Cookie\" . value) header pair that starts a
  session carrying datum (see token-sign for what datum may be). Add it to
  the response, typically the redirect after a successful login.
Example:
  (make-http-response 303
    (list (cons \"Location\" \"/\") (session-set-cookie cfg '((uid . 42))))
    \"\")"
      (cookie-header cfg
                     (token-sign (session-config-keys cfg) datum
                                 (session-config-max-age cfg)
                                 (list (cons 'purpose (session-config-purpose cfg))))
                     (session-config-max-age cfg)))

    (define (session-clear-cookie cfg)
      "Syntax: (session-clear-cookie cfg)
Library: (scm net http session)
Description: Returns a (\"Set-Cookie\" . value) header pair that removes
  the session cookie (logout).
Example:
  (make-http-response 303
    (list (cons \"Location\" \"/login\") (session-clear-cookie cfg)) \"\")"
      (cookie-header cfg "" 0))
))

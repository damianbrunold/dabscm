;; (app web) — routes, request handlers and the middleware stack.
;;
;; make-app returns the server-level handler (lambda (req) resp): bin/server.scm
;; serves it, and the tests call it directly with a request.
;;
;; Forms need no CSRF token: the session cookie is SameSite=Strict, so the
;; browser never sends it with a request that another site started.

(define-library (app web)
  (import (scheme base)
          (srfi 18)
          (scm io)
          (scm json simple)
          (scm net http request)
          (scm net http response)
          (scm net http route)
          (scm net http forms)
          (scm net http static)
          (scm net http session)
          (scm net http middleware)
          (app site)
          (app users)
          (app auth)
          (app views))
  (export make-app)
  (begin

    (define cookie-name "starter_login_session")

    (define (load-items path)
      (vector->list (json-parse (read-file-string path))))

    (define (setting settings key)
      (let ((p (assq key settings)))
        (if p (cdr p) (error "make-app: missing setting" key))))

    ;; 303 to a path in the app, optionally with header pairs (cookies).
    (define (redirect path . headers)
      (make-http-response 303 (cons (cons "Location" (url path)) headers) ""))

    ;; A failed password check costs the client half a second, which slows
    ;; down guessing.
    (define (penalty) (thread-sleep! 0.5))

    (define (make-app settings)
      "Syntax: (make-app settings)
Library: (app web)
Description: Builds the app's request handler. settings is an alist:
  url-prefix, static-dir, items-file, users-file (absolute paths),
  session-secret, session-max-age (seconds), secure-cookies?."
      (let* ((site (make-site (setting settings 'url-prefix)
                              (setting settings 'static-dir)))
             (prefix (site-prefix site))
             (auth (make-auth
                    (make-session-config
                     cookie-name
                     (setting settings 'session-secret)
                     (setting settings 'session-max-age)
                     `((path . ,(cookie-path site))
                       (secure? . ,(setting settings 'secure-cookies?))))
                    (setting settings 'users-file)))
             (items-file (setting settings 'items-file))
             (router (make-router)))

        (define (route! method path handler)
          (router-add! router method (string-append prefix path) handler))

        ;; Runs handler with the signed-in user as a third argument, or
        ;; sends the browser to the sign-in page.
        (define (signed-in handler)
          (lambda (req params)
            (let ((user (session-user auth req)))
              (if user (handler req params user) (redirect "/login")))))

        (route! "GET" "/static/*" (make-static-handler (setting settings 'static-dir)))

        (route! "GET" "/"
          (signed-in
            (lambda (req params user)
              (html-response (home-page (user-name user) (load-items items-file))))))

        (route! "GET" "/login"
          (lambda (req params)
            (if (session-user auth req)
                (redirect "/")
                (html-response (login-page #f)))))

        (route! "POST" "/login"
          (lambda (req params)
            (let* ((form (http-request-form req))
                   (user (sign-in auth (form-ref form "username" "")
                                  (form-ref form "password" ""))))
              (if user
                  (redirect "/" (start-session auth user))
                  (begin (penalty) (html-response (login-page #t)))))))

        (route! "POST" "/logout"
          (lambda (req params) (redirect "/login" (end-session auth))))

        (route! "GET" "/profile"
          (signed-in
            (lambda (req params user)
              (let ((done? (assoc "updated" (url-query-params (http-request-url req)))))
                (html-response
                 (profile-page (user-name user)
                               (and done? '(success . "Password updated."))))))))

        (route! "POST" "/profile/password"
          (signed-in
            (lambda (req params user)
              (let* ((form (http-request-form req))
                     (new (form-ref form "new" ""))
                     (fail (lambda (text)
                             (html-response
                              (profile-page (user-name user) (cons 'error text))))))
                (cond
                  ((not (sign-in auth (user-name user) (form-ref form "current" "")))
                   (penalty)
                   (fail "Current password is incorrect."))
                  ((< (string-length new) min-password-length)
                   (fail "New password must be at least 8 characters."))
                  ((not (string=? new (form-ref form "confirm" "")))
                   (fail "New passwords do not match."))
                  (else
                   ;; The new hash ends all other sessions; this browser
                   ;; gets a fresh cookie.
                   (let ((user (change-password! auth user new)))
                     (redirect "/profile?updated" (start-session auth user)))))))))

        ;; Outside the prefix: the health probe talks to the app directly.
        (router-add! router "GET" "/healthz"
          (lambda (req params) (text-response "ok\n")))

        ;; Outermost first: log every request, add the security headers,
        ;; make the site current for url/asset, and turn errors into a
        ;; logged 500 page.
        (with-access-log
         (with-security-headers
          (with-site site
           (with-error-handler (router->handler router)
                               (lambda (req) (html-response (error-page)))))))))))

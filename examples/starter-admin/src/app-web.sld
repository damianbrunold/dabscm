;; (app web) — routes, request handlers and the middleware stack.
;;
;; make-app returns the server-level handler (lambda (req) resp): bin/server.scm
;; serves it, and the tests call it directly with a request.
;;
;; The privileged role is "admin"; bin/seed-admin.scm creates it and grants
;; it to the first user. Forms need no CSRF token: the session cookie is
;; SameSite=Strict, so the browser never sends it with a request that
;; another site started.

(define-library (app web)
  (import (scheme base)
          (srfi 18)
          (scm crypto password)
          (scm net http request)
          (scm net http response)
          (scm net http route)
          (scm net http forms)
          (scm net http static)
          (scm net http session)
          (scm net http middleware)
          (app site)
          (app db)
          (app users)
          (app auth)
          (app views))
  (export make-app admin-role)
  (begin

    (define admin-role "admin")
    (define cookie-name "starter_admin_session")

    (define (setting settings key)
      (let ((p (assq key settings)))
        (if p (cdr p) (error "make-app: missing setting" key))))

    ;; 303 to a path in the app, optionally with header pairs (cookies).
    (define (redirect path . headers)
      (make-http-response 303 (cons (cons "Location" (url path)) headers) ""))

    ;; A failed password check costs the client half a second, which slows
    ;; down guessing.
    (define (penalty) (thread-sleep! 0.5))

    (define (id->string x) (if (number? x) (number->string x) x))

    ;; Admin console results travel across the POST/redirect/GET as a code
    ;; in the query string: /admin?m=<code>.
    (define notices
      '(("user-created"   success . "User created.")
        ("user-deleted"   success . "User deleted.")
        ("role-created"   success . "Role created.")
        ("role-assigned"  success . "Role assigned.")
        ("role-removed"   success . "Role removed.")
        ("dup-user"       error   . "That username is already taken.")
        ("bad-username"   error   . "Invalid username (letters, digits, . _ -).")
        ("short-password" error   . "Password must be at least 8 characters.")
        ("bad-role"       error   . "Invalid role name.")
        ("self-delete"    error   . "You cannot delete your own account.")
        ("self-admin"     error   . "You cannot remove your own admin role.")))

    (define (notice-from-query req)
      (let* ((q (url-query-params (http-request-url req)))
             (code (assoc "m" q))
             (n (and code (assoc (cdr code) notices))))
        (and n (cons (cadr n) (cddr n)))))

    (define (to-admin code) (redirect (string-append "/admin?m=" code)))

    (define (make-app settings)
      "Syntax: (make-app settings)
Library: (app web)
Description: Builds the app's request handler. settings is an alist:
  url-prefix, static-dir (absolute path), db (from make-db),
  session-secret, session-max-age (seconds), secure-cookies?."
      (let* ((site (make-site (setting settings 'url-prefix)
                              (setting settings 'static-dir)))
             (prefix (site-prefix site))
             (db (setting settings 'db))
             (auth (make-auth
                    (make-session-config
                     cookie-name
                     (setting settings 'session-secret)
                     (setting settings 'session-max-age)
                     `((path . ,(cookie-path site))
                       (secure? . ,(setting settings 'secure-cookies?))))
                    db))
             (router (make-router)))

        (define (route! method path handler)
          (router-add! router method (string-append prefix path) handler))

        (define (admin? user)
          (user-has-role? db (col user "id") admin-role))

        ;; Runs handler with the signed-in user row as a third argument, or
        ;; sends the browser to the sign-in page.
        (define (signed-in handler)
          (lambda (req params)
            (let ((user (session-user auth req)))
              (if user (handler req params user) (redirect "/login")))))

        (define (admin-only handler)
          (signed-in
            (lambda (req params user)
              (if (admin? user)
                  (handler req params user)
                  (http-forbidden "Admins only")))))

        (route! "GET" "/static/*" (make-static-handler (setting settings 'static-dir)))

        (route! "GET" "/"
          (signed-in
            (lambda (req params user)
              (let ((roles (user-role-names db (col user "id"))))
                (html-response
                 (home-page (col user "username") roles
                            (and (member admin-role roles) #t)))))))

        ;; --- sign-in ---

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

        ;; --- profile ---

        (route! "GET" "/profile"
          (signed-in
            (lambda (req params user)
              (let ((done? (assoc "updated" (url-query-params (http-request-url req)))))
                (html-response
                 (profile-page (col user "username") (admin? user)
                               (and done? '(success . "Password updated."))))))))

        (route! "POST" "/profile/password"
          (signed-in
            (lambda (req params user)
              (let* ((form (http-request-form req))
                     (new (form-ref form "new" ""))
                     (fail (lambda (text)
                             (html-response
                              (profile-page (col user "username") (admin? user)
                                            (cons 'error text))))))
                (cond
                  ((not (sign-in auth (col user "username") (form-ref form "current" "")))
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

        ;; --- admin console ---

        (route! "GET" "/admin"
          (admin-only
            (lambda (req params user)
              (html-response
               (admin-page (col user "username") (col user "id")
                           (list-users db) (list-roles db)
                           (all-user-roles db) (notice-from-query req))))))

        (route! "POST" "/admin/users"
          (admin-only
            (lambda (req params user)
              (let* ((form (http-request-form req))
                     (username (form-ref form "username" ""))
                     (password (form-ref form "password" "")))
                (cond
                  ((not (valid-username? username)) (to-admin "bad-username"))
                  ((< (string-length password) min-password-length)
                   (to-admin "short-password"))
                  ((find-user-by-name db username) (to-admin "dup-user"))
                  (else
                   ;; The user and the admin role together, or neither.
                   (with-db-transaction db
                     (lambda (tx)
                       (let ((id (create-user! tx username (password-hash password))))
                         (when (form-ref form "admin" #f)
                           (create-role! tx admin-role)
                           (assign-role-by-name! tx id admin-role)))))
                   (to-admin "user-created")))))))

        (route! "POST" "/admin/users/:id/delete"
          (admin-only
            (lambda (req params user)
              (if (equal? (params-ref params "id") (id->string (col user "id")))
                  (to-admin "self-delete")
                  (begin
                    (delete-user! db (params-ref params "id"))
                    (to-admin "user-deleted"))))))

        (route! "POST" "/admin/roles"
          (admin-only
            (lambda (req params user)
              (let ((name (form-ref (http-request-form req) "name" "")))
                (if (valid-role-name? name)
                    (begin (create-role! db name) (to-admin "role-created"))
                    (to-admin "bad-role"))))))

        (route! "POST" "/admin/users/:id/roles"
          (admin-only
            (lambda (req params user)
              (assign-role! db (params-ref params "id")
                            (form-ref (http-request-form req) "role_id" ""))
              (to-admin "role-assigned"))))

        (route! "POST" "/admin/users/:id/roles/:rid/delete"
          (admin-only
            (lambda (req params user)
              (let ((uid (params-ref params "id"))
                    (rid (params-ref params "rid")))
                ;; Keep at least the admin who is doing this.
                (if (and (equal? uid (id->string (col user "id")))
                         (equal? (role-name db rid) admin-role))
                    (to-admin "self-admin")
                    (begin
                      (unassign-role! db uid rid)
                      (to-admin "role-removed")))))))

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

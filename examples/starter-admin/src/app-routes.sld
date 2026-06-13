;; (app routes) — router, request handlers, static files, server start.
;; The privileged role is "admin"; seed-admin.scm creates it and grants it
;; to the seeded user.

(define-library (app routes)
  (import (scheme base)
          (scheme write)
          (scheme time)
          (scheme file)
          (scm net http request)
          (scm net http response)
          (scm net http route)
          (scm net http forms)
          (scm fs)
          (srfi 13)
          (srfi 18)
          (app db)
          (app auth)
          (app users)
          (app views))
  (export make-app-config serve)
  (begin

    (define admin-role "admin")

    (define-record-type app-config
      (make-app-config host port static-dir db auth)
      app-config?
      (host cfg-host)
      (port cfg-port)
      (static-dir cfg-static-dir)
      (db cfg-db)
      (auth cfg-auth))

    ;; --- static files -------------------------------------------------

    (define (content-type-for path)
      (cond ((string-suffix? ".css" path) "text/css; charset=utf-8")
            ((string-suffix? ".js" path)  "application/javascript; charset=utf-8")
            ((string-suffix? ".svg" path) "image/svg+xml")
            ((string-suffix? ".png" path) "image/png")
            ((string-suffix? ".ico" path) "image/x-icon")
            (else "application/octet-stream")))

    (define (safe-rel? rel)
      (and rel (> (string-length rel) 0)
           (not (char=? (string-ref rel 0) #\/))
           (not (string-contains rel ".."))))

    (define (read-file-bytes path)
      (let* ((port (open-binary-input-file path))
             (bv (read-bytevector (file-size path) port)))
        (close-input-port port)
        (if (eof-object? bv) (bytevector) bv)))

    (define (static-handler C)
      (lambda (req params)
        (let ((rel (params-ref params "*")))
          (if (not (safe-rel? rel))
              (http-forbidden)
              (let ((full (string-append (cfg-static-dir C) "/" rel)))
                (if (and (file-exists? full) (not (directory-exists? full)))
                    (make-http-response
                     200 (list (cons "Content-Type" (content-type-for full)))
                     (read-file-bytes full))
                    (http-not-found)))))))

    ;; --- helpers ------------------------------------------------------

    (define (form-of req) (parse-www-form (or (http-request-body req) "")))

    (define (require-auth C handler)
      (lambda (req params)
        (let* ((uid (token-user-id (cfg-auth C) req))
               (user (and uid (load-user (cfg-db C) uid))))
          (if user (handler req params user) (http-see-other "/login")))))

    (define (admin? C user)
      (user-has-role? (cfg-db C) (col user "id") admin-role))

    (define (require-admin C handler)
      (require-auth C
        (lambda (req params user)
          (if (admin? C user)
              (handler req params user)
              (http-forbidden "Admins only")))))

    ;; flash messages are passed across the POST/redirect/GET via the query
    ;; string: ?m=<ok-code> or ?e=<error-code>.
    (define notices
      '(("user-created"     success . "User created.")
        ("user-deleted"     success . "User deleted.")
        ("role-created"     success . "Role created.")
        ("role-assigned"    success . "Role assigned.")
        ("role-removed"     success . "Role removed.")
        ("dup-user"         error   . "That username is already taken.")
        ("bad-username"     error   . "Invalid username (letters, digits, . _ - ).")
        ("short-password"   error   . "Password must be at least 8 characters.")
        ("bad-role"         error   . "Invalid role name.")))

    (define (notice-from-query req)
      (let* ((q (url-query-params (http-request-url req)))
             (code (or (and (assoc "m" q) (cdr (assoc "m" q)))
                       (and (assoc "e" q) (cdr (assoc "e" q))))))
        (and code
             (let ((n (assoc code notices)))
               (and n (cons (cadr n) (cddr n)))))))

    (define (to-admin kind code)
      (http-see-other (string-append "/admin?" kind "=" code)))

    ;; --- server -------------------------------------------------------

    (define (serve C)
      (let ((db (cfg-db C))
            (auth (cfg-auth C))
            (router (make-router)))

        (router-add! router "GET" "/healthz"
          (lambda (req params) (text-response "ok\n")))
        (router-add! router "GET" "/static/*" (static-handler C))

        (router-add! router "GET" "/"
          (require-auth C
            (lambda (req params user)
              (let ((roles (user-role-names db (col user "id"))))
                (html-response
                 (home-page (col user "username") roles
                            (and (member admin-role roles) #t)))))))

        ;; --- auth ---
        (router-add! router "GET" "/login"
          (lambda (req params)
            (if (token-user-id auth req)
                (http-see-other "/")
                (html-response (login-page #f)))))

        (router-add! router "POST" "/login"
          (lambda (req params)
            (let* ((form (form-of req))
                   (user (authenticate db (form-ref form "username" "")
                                       (form-ref form "password" ""))))
              (if user
                  (login-redirect auth (col user "id") "/")
                  (begin (thread-sleep! 0.5)
                         (html-response (login-page #t)))))))

        (router-add! router "POST" "/logout"
          (lambda (req params) (logout-redirect auth "/login")))

        ;; --- profile ---
        (router-add! router "GET" "/profile"
          (require-auth C
            (lambda (req params user)
              (html-response
               (profile-page (col user "username") (admin? C user) #f)))))

        (router-add! router "POST" "/profile/password"
          (require-auth C
            (lambda (req params user)
              (let* ((form (form-of req))
                     (current (form-ref form "current" ""))
                     (new (form-ref form "new" ""))
                     (confirm (form-ref form "confirm" ""))
                     (name (col user "username"))
                     (adm (admin? C user)))
                (cond
                  ((not (verify-password current (col user "pass_hash")))
                   (thread-sleep! 0.5)
                   (html-response
                    (profile-page name adm (cons 'error "Current password is incorrect."))))
                  ((< (string-length new) 8)
                   (html-response
                    (profile-page name adm (cons 'error "New password must be at least 8 characters."))))
                  ((not (string=? new confirm))
                   (html-response
                    (profile-page name adm (cons 'error "New passwords do not match."))))
                  (else
                   (db-exec db "UPDATE users SET pass_hash = $1 WHERE id = $2"
                            (hash-password new) (col user "id"))
                   (html-response
                    (profile-page name adm (cons 'success "Password updated.")))))))))

        ;; --- admin console ---
        (router-add! router "GET" "/admin"
          (require-admin C
            (lambda (req params user)
              (html-response
               (admin-page (col user "username") (col user "id")
                           (list-users db) (list-roles db)
                           (all-user-roles db) (notice-from-query req))))))

        (router-add! router "POST" "/admin/users"
          (require-admin C
            (lambda (req params user)
              (let* ((form (form-of req))
                     (username (form-ref form "username" ""))
                     (password (form-ref form "password" "")))
                (cond
                  ((not (valid-username? username)) (to-admin "e" "bad-username"))
                  ((< (string-length password) 8) (to-admin "e" "short-password"))
                  (else
                   (guard (e (#t (to-admin "e" "dup-user")))  ; unique violation
                     (create-user! db username password)
                     (to-admin "m" "user-created"))))))))

        (router-add! router "POST" "/admin/users/:id/delete"
          (require-admin C
            (lambda (req params user)
              (delete-user! db (params-ref params "id"))
              (to-admin "m" "user-deleted"))))

        (router-add! router "POST" "/admin/roles"
          (require-admin C
            (lambda (req params user)
              (let ((name (form-ref (form-of req) "name" "")))
                (if (valid-role-name? name)
                    (begin (create-role! db name) (to-admin "m" "role-created"))
                    (to-admin "e" "bad-role"))))))

        (router-add! router "POST" "/admin/users/:id/roles"
          (require-admin C
            (lambda (req params user)
              (assign-role! db (params-ref params "id")
                            (form-ref (form-of req) "role_id" ""))
              (to-admin "m" "role-assigned"))))

        (router-add! router "POST" "/admin/users/:id/roles/:rid/delete"
          (require-admin C
            (lambda (req params user)
              (unassign-role! db (params-ref params "id") (params-ref params "rid"))
              (to-admin "m" "role-removed"))))

        (display (string-append "starter-admin listening on http://"
                                (cfg-host C) ":"
                                (number->string (cfg-port C)) "\n"))
        (run-app-with-router router (cfg-port C) 0 (cfg-host C))))))

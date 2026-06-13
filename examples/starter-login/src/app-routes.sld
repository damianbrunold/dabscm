;; (app routes) — wires the router, serves static files, and starts the
;; HTTP server. Holds the runtime config record built by bin/server.scm.

(define-library (app routes)
  (import (scheme base)
          (scheme write)
          (scheme file)
          (scheme time)
          (scm net http request)
          (scm net http response)
          (scm net http route)
          (scm net http forms)
          (scm json simple)
          (scm io)
          (scm fs)
          (srfi 13)
          (srfi 18)
          (app auth)
          (app users)
          (app views))
  (export make-app-config serve)
  (begin

    (define-record-type app-config
      (make-app-config host port static-dir data-file users-file)
      app-config?
      (host cfg-host)
      (port cfg-port)
      (static-dir cfg-static-dir)
      (data-file cfg-data-file)
      (users-file cfg-users-file))

    ;; --- data ---------------------------------------------------------

    (define (load-items cfg)
      (guard (e (#t '()))
        (vector->list (json-parse (read-file-string (cfg-data-file cfg))))))

    ;; --- static files -------------------------------------------------

    (define (content-type-for path)
      (cond ((string-suffix? ".css" path)  "text/css; charset=utf-8")
            ((string-suffix? ".js" path)   "application/javascript; charset=utf-8")
            ((string-suffix? ".svg" path)  "image/svg+xml")
            ((string-suffix? ".png" path)  "image/png")
            ((string-suffix? ".ico" path)  "image/x-icon")
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

    (define (static-handler cfg)
      (lambda (req params)
        (let ((rel (params-ref params "*")))
          (if (not (safe-rel? rel))
              (http-forbidden)
              (let ((full (string-append (cfg-static-dir cfg) "/" rel)))
                (if (and (file-exists? full) (not (directory-exists? full)))
                    (make-http-response
                     200 (list (cons "Content-Type" (content-type-for full)))
                     (read-file-bytes full))
                    (http-not-found)))))))

    ;; --- auth guard ---------------------------------------------------

    ;; Wraps a handler so it only runs when authenticated; the handler is
    ;; called with an extra trailing argument, the username.
    (define (require-auth auth handler)
      (lambda (req params)
        (let ((user (current-user auth req)))
          (if user (handler req params user) (http-see-other "/login")))))

    (define (form-of req)
      (parse-www-form (or (http-request-body req) "")))

    ;; --- server -------------------------------------------------------

    (define (serve cfg auth)
      (let ((router (make-router)))

        (router-add! router "GET" "/healthz"
          (lambda (req params) (text-response "ok\n")))

        (router-add! router "GET" "/static/*" (static-handler cfg))

        (router-add! router "GET" "/"
          (require-auth auth
            (lambda (req params user)
              (html-response (home-page user (load-items cfg))))))

        (router-add! router "GET" "/login"
          (lambda (req params)
            (if (current-user auth req)
                (http-see-other "/")
                (html-response (login-page #f)))))

        (router-add! router "POST" "/login"
          (lambda (req params)
            (let* ((form (form-of req))
                   (username (form-ref form "username" ""))
                   (password (form-ref form "password" ""))
                   (user (find-user (load-users (cfg-users-file cfg)) username)))
              (if (and user (verify-password password (user-hash user)))
                  (login-redirect auth username "/")
                  (begin
                    (thread-sleep! 0.5)   ; slow down credential guessing
                    (html-response (login-page #t)))))))

        (router-add! router "POST" "/logout"
          (lambda (req params) (logout-redirect auth "/login")))

        (router-add! router "GET" "/profile"
          (require-auth auth
            (lambda (req params user)
              (html-response (profile-page user #f)))))

        (router-add! router "POST" "/profile/password"
          (require-auth auth
            (lambda (req params user)
              (let* ((form (form-of req))
                     (current (form-ref form "current" ""))
                     (new (form-ref form "new" ""))
                     (confirm (form-ref form "confirm" ""))
                     (users (load-users (cfg-users-file cfg)))
                     (entry (find-user users user)))
                (cond
                  ((not (and entry (verify-password current (user-hash entry))))
                   (thread-sleep! 0.5)
                   (html-response
                    (profile-page user (cons 'error "Current password is incorrect."))))
                  ((< (string-length new) 8)
                   (html-response
                    (profile-page user (cons 'error "New password must be at least 8 characters."))))
                  ((not (string=? new confirm))
                   (html-response
                    (profile-page user (cons 'error "New passwords do not match."))))
                  (else
                   (save-users! (cfg-users-file cfg)
                                (upsert-user users user (hash-password new)
                                             (exact (round (current-second)))))
                   (html-response
                    (profile-page user (cons 'success "Password updated.")))))))))

        (display (string-append "starter-login listening on http://"
                                (cfg-host cfg) ":"
                                (number->string (cfg-port cfg)) "\n"))
        (run-app-with-router router (cfg-port cfg) 0 (cfg-host cfg))))))

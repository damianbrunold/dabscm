;; Usage: scm bin/server.scm [config-path]
;;
;; Loads config, applies any pending migrations, then starts the webapp.

(import (scheme base)
        (scheme write)
        (scheme load)
        (scheme process-context)
        (scm module)
        (scm fs))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app db) (app auth) (app routes))

(define cfg-path
  (let ((args (cdr (command-line))))
    (cond ((pair? args) (car args))
          ((file-exists? (string-append root "/config.scm"))
           (string-append root "/config.scm"))
          (else (string-append root "/config.example.scm")))))

(load cfg-path)

(define (abs-path p)
  (if (and (> (string-length p) 0) (char=? (string-ref p 0) #\/))
      p (string-append root "/" p)))

(define db
  (make-db db-host db-port db-user db-password db-name db-pool-capacity))

(migrate! db (abs-path migrations-dir))

(define auth
  (make-auth cookie-name cookie-secret session-max-age secure-cookies?))

(serve (make-app-config http-host http-port (abs-path static-dir) db auth))

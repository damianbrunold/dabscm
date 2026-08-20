;; Usage: scm bin/seed-admin.scm [config-path]
;;
;; Idempotently sets up the first admin: applies migrations, ensures the
;; "admin" role exists, and creates the admin user (from config) with that
;; role if it is not already present. Safe to run repeatedly.

(import (scheme base)
        (scheme write)
        (scheme load)
        (scheme process-context)
        (scm module)
        (scm fs))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app db) (app auth) (app users))

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
(create-role! db "admin")

(if (find-user-by-name db admin-username)
    (begin (display "admin user already exists: ")
           (display admin-username) (newline))
    (let ((id (create-user! db admin-username admin-password)))
      (assign-role-by-name! db id "admin")
      (display "created admin user: ") (display admin-username) (newline)))

;; Tests against a real PostgreSQL database: sign-in, sessions, the admin
;; console, transactions. They DROP the app's tables first, so they only run
;; against a database whose name ends in "_test", given by a config file:
;;
;;   STARTER_ADMIN_TEST_CONFIG=tests/test-config.scm scm tests/test_live_web.scm
;;
;; (a copy of config.scm with db-name "starter_admin_test"). Without the
;; variable the tests are skipped.

(import (scheme base)
        (scheme process-context)
        (scheme write)
        (scm module)
        (scm fs)
        (scm log)
        (scm string)
        (scm test)
        (scm crypto)
        (scm crypto password)
        (scm net http request)
        (scm net http response))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app config) (app db) (app users) (app web))

(test-runner-factory scm-test-runner)
(test-begin "starter-admin web (live database)")

(define config-path (get-environment-variable "STARTER_ADMIN_TEST_CONFIG"))

(define (run-tests cfg)
  (define fast-iterations 1000)
  (define db
    (make-db (config-ref cfg 'db-host "127.0.0.1") (config-ref cfg 'db-port 5432)
             (config-ref cfg 'db-user "") (config-ref cfg 'db-password "")
             (config-ref cfg 'db-name "") 2))
  (define app
    (make-app `((url-prefix . "")
                (static-dir . ,(string-append root "/static"))
                (db . ,db)
                (session-secret . ,(base64-encode (random-bytes 32)))
                (session-max-age . 3600)
                (secure-cookies? . #f))))
  (define (send method url cookie . form)
    (parameterize ((log-port (open-output-string))
                   (password-pbkdf2-iterations fast-iterations))
      (app (make-http-request
            method url
            (append (if cookie (list (cons "Cookie" cookie)) '())
                    (if (pair? form)
                        '(("Content-Type" . "application/x-www-form-urlencoded"))
                        '()))
            (if (pair? form) (car form) #f)))))
  (define (location r) (http-response-header r "Location"))
  (define (body r)
    (let ((b (http-response-body r)))
      (if (bytevector? b) (utf8->string b) b)))
  (define (has? s part) (and (string? s) (string-contains-from s part 0) #t))
  (define (cookie-of r)
    (let ((h (http-response-header r "Set-Cookie")))
      (and h (car (string-split-char h #\;)))))
  (define (sign-in name password)
    (cookie-of (send "POST" "/login" #f
                     (string-append "username=" name "&password=" password))))
  (define (user-id name) (let ((id (col (find-user-by-name db name) "id")))
                           (if (number? id) (number->string id) id)))

  ;; A fresh schema, and an admin as bin/seed-admin.scm makes one.
  (db-exec db "DROP TABLE IF EXISTS user_roles, roles, users, schema_migrations")
  (parameterize ((log-port (open-output-string)))
    (migrate! db (string-append root "/migrations")))
  (with-db-transaction db
    (lambda (tx)
      (create-role! tx admin-role)
      (assign-role-by-name!
       tx
       (create-user! tx "root"
                     (parameterize ((password-pbkdf2-iterations fast-iterations))
                       (password-hash "rootpassword")))
       admin-role)))

  (let ((admin (sign-in "root" "rootpassword")))
    (test-group "admin signs in"
      (test-assert admin)
      (test-assert (has? (body (send "GET" "/" admin)) "Welcome, root"))
      (test-equal 200 (http-response-status (send "GET" "/admin" admin))))

    (test-group "create users"
      (test-equal "/admin?m=user-created"
        (location (send "POST" "/admin/users" admin "username=bob&password=bobpassword")))
      (test-equal "/admin?m=dup-user"
        (location (send "POST" "/admin/users" admin "username=bob&password=bobpassword")))
      (test-equal "/admin?m=bad-username"
        (location (send "POST" "/admin/users" admin "username=b+b&password=bobpassword")))
      (test-equal "/admin?m=short-password"
        (location (send "POST" "/admin/users" admin "username=eve&password=short")))
      (test-equal "/admin?m=user-created"
        (location (send "POST" "/admin/users" admin "username=ann&password=annpassword&admin=1")))
      (test-equal '("admin") (user-role-names db (user-id "ann")))
      (test-equal '() (user-role-names db (user-id "bob")))
      (test-assert (has? (body (send "GET" "/admin?m=user-created" admin)) "User created.")))

    (test-group "a failed transaction leaves nothing behind"
      (test-error
       (with-db-transaction db
         (lambda (tx)
           (create-user! tx "ghost" "x")
           (error "boom"))))
      (test-equal #f (find-user-by-name db "ghost")))

    (test-group "non-admins are kept out"
      (let ((bob (sign-in "bob" "bobpassword")))
        (test-equal 200 (http-response-status (send "GET" "/" bob)))
        (test-equal 403 (http-response-status (send "GET" "/admin" bob)))
        (test-equal 403 (http-response-status
                         (send "POST" "/admin/roles" bob "name=hackers")))
        (test-assert (not (has? (body (send "GET" "/" bob)) "/admin\"")))))

    (test-group "roles"
      (test-equal "/admin?m=role-created"
        (location (send "POST" "/admin/roles" admin "name=editor")))
      (test-equal "/admin?m=bad-role"
        (location (send "POST" "/admin/roles" admin "name=a+b")))
      (let ((rid (let ((r (assoc "editor" (map (lambda (r) (cons (col r "name") (col r "id")))
                                               (list-roles db)))))
                   (if (number? (cdr r)) (number->string (cdr r)) (cdr r)))))
        (send "POST" (string-append "/admin/users/" (user-id "bob") "/roles") admin
              (string-append "role_id=" rid))
        (test-equal '("editor") (user-role-names db (user-id "bob")))
        (send "POST" (string-append "/admin/users/" (user-id "bob") "/roles/" rid "/delete") admin)
        (test-equal '() (user-role-names db (user-id "bob")))))

    (test-group "an admin cannot lock themselves out"
      (let ((admin-rid (let ((id (db-scalar db "SELECT id FROM roles WHERE name = $1" admin-role)))
                         (if (number? id) (number->string id) id))))
        (test-equal "/admin?m=self-admin"
          (location (send "POST" (string-append "/admin/users/" (user-id "root")
                                                "/roles/" admin-rid "/delete")
                          admin)))
        (test-equal "/admin?m=self-delete"
          (location (send "POST" (string-append "/admin/users/" (user-id "root") "/delete")
                          admin)))))

    (test-group "sessions end with the user or the password"
      (let ((bob (sign-in "bob" "bobpassword"))
            (bob2 (sign-in "bob" "bobpassword")))
        (let ((fresh (cookie-of (send "POST" "/profile/password" bob
                                      "current=bobpassword&new=bobsnewpass&confirm=bobsnewpass"))))
          (test-assert fresh)
          (test-equal "/login" (location (send "GET" "/" bob2)))
          (test-equal 200 (http-response-status (send "GET" "/" fresh)))
          (send "POST" (string-append "/admin/users/" (user-id "bob") "/delete") admin)
          (test-equal #f (find-user-by-name db "bob"))
          (test-equal "/login" (location (send "GET" "/" fresh))))))

    (test-group "outdated hashes are upgraded at sign-in"
      (parameterize ((password-pbkdf2-iterations 500))
        (create-user! db "old" (password-hash "oldpassword")))
      (test-assert (sign-in "old" "oldpassword"))
      (test-assert
       (not (parameterize ((password-pbkdf2-iterations fast-iterations))
              (password-needs-rehash? (col (find-user-by-name db "old") "pass_hash"))))))))

(cond
  ((not config-path)
   (display "skipped: set STARTER_ADMIN_TEST_CONFIG to a config for a *_test database\n"))
  (else
   (let* ((cfg (read-config config-path))
          (name (config-ref cfg 'db-name "")))
     (if (and (>= (string-length name) 5)
              (string=? (substring name (- (string-length name) 5) (string-length name))
                        "_test"))
         (run-tests cfg)
         (error "refusing to run: db-name must end in _test" name)))))

(test-end "starter-admin web (live database)")

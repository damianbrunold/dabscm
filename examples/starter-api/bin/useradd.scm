;; Usage: scm bin/useradd.scm <username> [password]
;;
;; Adds (or updates) an API user. If no password is given it is prompted for
;; twice, read without echoing (via (scm terminal) read-password).

(import (scheme base)
        (scheme write)
        (scheme load)
        (scheme process-context)
        (scm module)
        (scm fs)
        (scm terminal)
        (scheme time))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app auth) (app store))

(load (let ((c (string-append root "/config.scm")))
        (if (file-exists? c) c (string-append root "/config.example.scm"))))

(define users-path
  (let ((p users-file))
    (if (char=? (string-ref p 0) #\/) p (string-append root "/" p))))

(define (fail msg) (display msg) (newline) (exit 1))

;; Read a password without echoing the typed characters.
(define (ask-password s)
  (let ((p (read-password s)))
    (if (eof-object? p) (fail "aborted") p)))

(define args (cdr (command-line)))
(when (null? args)
  (fail "usage: scm bin/useradd.scm <username> [password]"))

(define username (car args))
(unless (valid-username? username)
  (fail "invalid username (allowed: letters, digits, . _ -, max 64)"))

(define password
  (if (pair? (cdr args))
      (cadr args)
      (let ((a (ask-password "Password: ")))
        (let ((b (ask-password "Confirm:  ")))
          (unless (string=? a b) (fail "passwords do not match"))
          a))))

(when (< (string-length password) 8)
  (fail "password must be at least 8 characters"))

(define users (load-users users-path))
(save-users! users-path
             (upsert-user users username (hash-password password)
                          (exact (round (current-second)))))
(display (string-append (if (find-user users username) "updated" "added")
                        " user: " username "\n"))

;; Usage: scm bin/user.scm [--config path] add <username>
;;        scm bin/user.scm [--config path] passwd <username>
;;        scm bin/user.scm [--config path] delete <username>
;;        scm bin/user.scm [--config path] list
;;
;; Manages the user store. There is no sign-up page: users exist only once
;; added here. Passwords are prompted for twice and read without echo.
;; Changing or deleting a user revokes their tokens.

(import (scheme base)
        (scheme write)
        (scheme process-context)
        (scm module)
        (scm fs)
        (scm terminal))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (scm crypto password) (app config) (app users) (app auth))

(define (fail msg) (display msg (current-error-port)) (newline (current-error-port)) (exit 1))

(define usage
  "usage: scm bin/user.scm [--config path] add|passwd|delete <username> | list")

(define args (cdr (command-line)))
(define config-args
  (if (and (pair? args) (string=? (car args) "--config") (pair? (cdr args)))
      (list (cadr args))
      '()))
(define command-args (if (null? config-args) args (cddr args)))

(define cfg (load-config root config-args))
(define users-file
  (string-append (resolve-path root (config-ref cfg 'data-dir "data")) "/users.scm"))

(define (ask-new-password)
  (let* ((a (read-password "Password: "))
         (b (if (eof-object? a) a (read-password "Confirm:  "))))
    (cond ((or (eof-object? a) (eof-object? b)) (fail "aborted"))
          ((not (string=? a b)) (fail "passwords do not match"))
          ((< (string-length a) min-password-length)
           (fail "password must be at least 8 characters"))
          (else a))))

(define (the-name)
  (if (and (pair? (cdr command-args)) (null? (cddr command-args)))
      (cadr command-args)
      (fail usage)))

(if (null? command-args)
    (fail usage)
    (let ((cmd (car command-args)))
      (cond
        ((string=? cmd "add")
         (let ((name (the-name)))
           (unless (valid-username? name)
             (fail "invalid username (letters, digits, . _ -; at most 64)"))
           (when (find-user users-file name)
             (fail (string-append "user exists: " name " (use passwd)")))
           (save-user! users-file name (password-hash (ask-new-password)))
           (display (string-append "added " name "\n"))))
        ((string=? cmd "passwd")
         (let ((name (the-name)))
           (unless (find-user users-file name) (fail (string-append "no such user: " name)))
           (save-user! users-file name (password-hash (ask-new-password)))
           (display (string-append "password changed for " name "\n"))))
        ((string=? cmd "delete")
         (let ((name (the-name)))
           (unless (find-user users-file name) (fail (string-append "no such user: " name)))
           (delete-user! users-file name)
           (display (string-append "deleted " name "\n"))))
        ((string=? cmd "list")
         (for-each (lambda (u) (display (user-name u)) (newline))
                   (load-users users-file)))
        (else (fail usage)))))

;; (scm scaffold) — new applications from the starters in examples/.
;;
;; `scm new-app <starter> <dir> [name]` copies a starter (starter-public,
;; starter-login, starter-admin, starter-api) into dir and renames it:
;; every spelling of the starter's name in paths and file contents
;; ("starter-admin", "starter_admin", "Starter Admin", "STARTER_ADMIN")
;; becomes the same spelling of the new name. The starters' files come
;; from (scm scaffold starters), which update-scheme-files.scm generates
;; from examples/, so this works from the jar and the .NET build alike.

(define-library (scm scaffold)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (scheme write)
          (scm fs)
          (scm string)
          (scm scaffold starters))
  (export starter-names
          new-app
          new-app-command
          app-name-variants)
  (begin

    (define (starter-names)
      "Syntax: (starter-names)
Library: (scm scaffold)
Description: The names of the starters new-app can copy, simplest first.
Example:
  (starter-names) => (\"starter-public\" \"starter-login\" \"starter-admin\" \"starter-api\")"
      (map car starter-files))

    (define (valid-name? name)
      (and (string? name)
           (<= 1 (string-length name) 64)
           (char-lower-case? (string-ref name 0))
           (let loop ((i 0) (prev #\a))
             (or (= i (string-length name))
                 (let ((c (string-ref name i)))
                   (and (or (char-lower-case? c) (char-numeric? c)
                            (and (char=? c #\-) (not (char=? prev #\-))
                                 (< i (- (string-length name) 1))))
                        (char<? c #\x80)
                        (loop (+ i 1) c)))))))

    (define (split-dashes s)
      (let loop ((i 0) (start 0) (acc '()))
        (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
              ((char=? (string-ref s i) #\-) (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
              (else (loop (+ i 1) start acc)))))

    (define (join words sep)
      (if (null? words)
          ""
          (let loop ((ws (cdr words)) (acc (car words)))
            (if (null? ws) acc (loop (cdr ws) (string-append acc sep (car ws)))))))

    (define (capitalize w)
      (if (string=? w "")
          w
          (string-append (string (char-upcase (string-ref w 0))) (substring w 1 (string-length w)))))

    (define (app-name-variants name)
      "Syntax: (app-name-variants name)
Library: (scm scaffold)
Description: The spellings of a kebab-case app name that new-app
  replaces, in this order: kebab, snake, title and upper case.
Example:
  (app-name-variants \"my-app\") => (\"my-app\" \"my_app\" \"My App\" \"MY_APP\")"
      (let ((words (split-dashes name)))
        (list name
              (join words "_")
              (join (map capitalize words) " ")
              (string-upcase (join words "_")))))

    (define (rename-all s from to)
      (let loop ((s s) (from from) (to to))
        (if (null? from)
            s
            (loop (string-replace-all s (car from) (car to)) (cdr from) (cdr to)))))

    (define (empty-or-missing? dir)
      (or (not (path-exists? dir))
          (and (directory-exists? dir)
               (null? (directory-files dir))
               (null? (directory-directories dir)))))

    (define (string-suffix? suffix s)
      (let ((n (string-length s)) (k (string-length suffix)))
        (and (>= n k) (string=? (substring s (- n k) n) suffix))))

    (define (new-app starter dir . name)
      "Syntax: (new-app starter dir [name])
Library: (scm scaffold)
Description: Copies the starter (one of (starter-names)) into the new or
  empty directory dir and renames it to name, a kebab-case name (default:
  the last component of dir). Shell scripts are made executable. Returns
  the list of files written, relative to dir. Signals an error for an
  unknown starter, an invalid name or a directory that is not empty.
Example:
  (new-app \"starter-admin\" \"/home/me/projects/ledger\")
  => (\".gitignore\" \"README.md\" \"bin/server.scm\" ...)"
      (let* ((name (if (pair? name) (car name) (base-name (normalized-path (absolute-path dir)))))
             (files (assoc starter starter-files)))
        (cond
          ((not files)
           (error "new-app: unknown starter (expected one of starter-names)" starter))
          ((not (valid-name? name))
           (error "new-app: the name must be kebab case (a-z, 0-9, single dashes)" name))
          ((not (empty-or-missing? dir))
           (error "new-app: the directory exists and is not empty" dir))
          (else
           (let ((from (app-name-variants starter))
                 (to (app-name-variants name)))
             (map (lambda (file)
                    (let* ((rel (rename-all (car file) from to))
                           (path (join-path dir rel)))
                      (make-directory (directory-name path))
                      (call-with-output-file path
                        (lambda (port) (write-string (rename-all (cdr file) from to) port)))
                      (when (string-suffix? ".sh" rel) (chmod path "755"))
                      rel))
                  (cdr files)))))))

    (define (usage port)
      (display "Usage: scm new-app <starter> <dir> [name]\n" port)
      (display "Copies a starter application into dir and renames it to name\n" port)
      (display "(kebab case; default: the directory's name). Starters:\n" port)
      (for-each (lambda (s) (display (string-append "  " s "\n") port)) (starter-names)))

    (define (new-app-command args)
      "Syntax: (new-app-command args)
Library: (scm scaffold)
Description: The `scm new-app` command: args are the command-line
  arguments after \"new-app\". Prints what it did, or the usage, and
  returns the exit code."
      (if (not (<= 2 (length args) 3))
          (begin (usage (current-error-port)) 2)
          (guard (e ((error-object? e)
                     (display (string-append "scm " (error-object-message e)) (current-error-port))
                     (for-each (lambda (x) (display " " (current-error-port)) (write x (current-error-port)))
                               (error-object-irritants e))
                     (newline (current-error-port))
                     1))
            (let* ((files (apply new-app args))
                   (dir (cadr args)))
              (display (string-append "Created " dir " from " (car args)
                                      " (" (number->string (length files)) " files).\n"))
              (display (string-append "Next: cd " dir " and follow README.md.\n"))
              0))))))

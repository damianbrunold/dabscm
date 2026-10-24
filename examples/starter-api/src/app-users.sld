;; (app users) — the user store, a plain Scheme data file.
;;
;; users.scm holds one datum: a list of (username hash created) entries. It
;; is written by the CLI (bin/user.scm) and by the app (password changes,
;; hash upgrades), never by hand. Writes go through a temp file + rename so
;; a reader never sees a half-written file, and a mutex serializes the
;; app's own writes. (The CLI is a separate process; the last write wins.)
;;
;; This module is storage only; passwords and sessions live in (app auth).

(define-library (app users)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (scheme read)
          (scheme time)
          (scheme write)
          (scm fs)
          (srfi 18))
  (export load-users
          find-user
          user-name
          user-hash
          user-created
          save-user!
          delete-user!
          valid-username?)
  (begin

    (define (user-name u) (car u))
    (define (user-hash u) (cadr u))
    (define (user-created u) (caddr u))

    (define (load-users path)
      "Syntax: (load-users path)
Library: (app users)
Description: The list of (username hash created) entries in path, or '()
  if the file does not exist yet."
      (if (file-exists? path)
          (let ((datum (call-with-input-file path read)))
            (if (eof-object? datum) '() datum))
          '()))

    (define (find-user path name)
      "Syntax: (find-user path name)
Library: (app users)
Description: The (username hash created) entry for name, or #f."
      (assoc name (load-users path)))

    (define write-lock (make-mutex))

    (define (update-users! path proc)
      (dynamic-wind
        (lambda () (mutex-lock! write-lock))
        (lambda ()
          (let ((dir (directory-name path))
                (tmp (string-append path ".tmp")))
            (unless (directory-exists? dir) (make-directory dir))
            (call-with-output-file tmp
              (lambda (p) (write (proc (load-users path)) p) (newline p)))
            (move-file tmp path)))
        (lambda () (mutex-unlock! write-lock))))

    (define (save-user! path name hash)
      "Syntax: (save-user! path name hash)
Library: (app users)
Description: Stores hash for name: replaces the entry (keeping its created
  time) or appends a new one."
      (update-users! path
        (lambda (users)
          (let loop ((us users))
            (cond
              ((null? us)
               (list (list name hash (exact (floor (current-second))))))
              ((string=? (user-name (car us)) name)
               (cons (list name hash (user-created (car us))) (cdr us)))
              (else (cons (car us) (loop (cdr us)))))))))

    (define (delete-user! path name)
      "Syntax: (delete-user! path name)
Library: (app users)
Description: Removes name's entry, if there is one."
      (update-users! path
        (lambda (users)
          (let loop ((us users))
            (cond ((null? us) '())
                  ((string=? (user-name (car us)) name) (cdr us))
                  (else (cons (car us) (loop (cdr us)))))))))

    (define (valid-username? s)
      "Syntax: (valid-username? s)
Library: (app users)
Description: True if s is 1-64 characters of letters, digits and . _ -"
      (and (string? s)
           (<= 1 (string-length s) 64)
           (let loop ((i 0))
             (or (= i (string-length s))
                 (let ((c (string-ref s i)))
                   (and (or (char-alphabetic? c) (char-numeric? c)
                            (memv c '(#\. #\_ #\-)))
                        (loop (+ i 1))))))))))

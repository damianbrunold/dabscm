;; (app users) — the user store, a plain Scheme data file.
;;
;; data/users.scm holds one datum: a list of (username hash created) entries.
;; It is written only by the CLI tools (bin/useradd.scm, bin/passwd.scm) and
;; the profile password-change handler — never edited by hand. Writes go
;; through a temp file + rename so a reader never sees a half-written file.
;;
;; This module is storage only; password hashing lives in (app auth) so the
;; two concerns stay independent.

(define-library (app users)
  (import (scheme base)
          (scheme read)
          (scheme char)
          (scheme file)
          (scheme write)
          (scm fs)
          (srfi 13))
  (export load-users
          save-users!
          find-user
          user-name
          user-hash
          upsert-user
          valid-username?)
  (begin

    (define (load-users path)
      "Syntax: (load-users path)
Library: (app users)
Description: Reads the user list from path, or '() if the file is absent
  or empty."
      (if (file-exists? path)
          (let ((datum (call-with-input-file path read)))
            (if (eof-object? datum) '() datum))
          '()))

    (define (save-users! path users)
      "Syntax: (save-users! path users)
Library: (app users)
Description: Atomically writes the user list to path (temp file + rename)."
      (let ((tmp (string-append path ".tmp")))
        (call-with-output-file tmp
          (lambda (p) (write users p) (newline p)))
        (move-file tmp path)))

    (define (make-user name hash created) (list name hash created))
    (define (user-name u) (car u))
    (define (user-hash u) (cadr u))

    (define (find-user users name)
      "Syntax: (find-user users name)
Library: (app users)
Description: Returns the (name hash created) entry for name, or #f."
      (cond ((null? users) #f)
            ((string=? (user-name (car users)) name) (car users))
            (else (find-user (cdr users) name))))

    (define (upsert-user users name hash created)
      "Syntax: (upsert-user users name hash created)
Library: (app users)
Description: Returns users with name's entry replaced (preserving its
  original created stamp) or appended if new."
      (cond
        ((null? users) (list (make-user name hash created)))
        ((string=? (user-name (car users)) name)
         (cons (make-user name hash (list-ref (car users) 2)) (cdr users)))
        (else (cons (car users) (upsert-user (cdr users) name hash created)))))

    (define (valid-username? s)
      "Syntax: (valid-username? s)
Library: (app users)
Description: True if s is 1-64 chars of [A-Za-z0-9._-]. Restricting the
  charset keeps usernames safe to embed in signed tokens and file data."
      (and (string? s)
           (<= 1 (string-length s) 64)
           (string-every
            (lambda (c)
              (or (char-alphabetic? c) (char-numeric? c)
                  (memv c '(#\. #\_ #\-))))
            s)))))

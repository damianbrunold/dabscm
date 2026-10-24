;; (app auth) — sign-in, sessions and password changes.
;;
;; Passwords are hashed with (scm crypto password): PBKDF2-SHA256 with a
;; random salt, verified in constant time. A sign-in with an unknown username
;; does the same hashing work as one with a wrong password, so response
;; times do not reveal which usernames exist. Hashes made with fewer
;; iterations than the current default are upgraded at the next sign-in.
;;
;; Sessions are signed cookies from (scm net http session): no server-side
;; store. The cookie carries the username and a stamp derived from the
;; password hash, and every request looks the user up again: deleting a
;; user or changing a password ends that user's other sessions.

(define-library (app auth)
  (import (scheme base)
          (scm crypto)
          (scm crypto password)
          (scm net http session)
          (app users))
  (export make-auth
          sign-in
          session-user
          start-session
          end-session
          change-password!
          min-password-length)
  (begin

    (define min-password-length 8)

    (define-record-type auth
      (%make-auth session users-file)
      auth?
      (session auth-session)
      (users-file auth-users-file))

    (define (make-auth session-config users-file)
      "Syntax: (make-auth session-config users-file)
Library: (app auth)
Description: Ties a (scm net http session) config to the user store."
      (%make-auth session-config users-file))

    ;; Changes whenever the password (and so the hash) changes.
    (define (password-stamp hash)
      (base64-encode (bytevector-copy (sha256-hash (string->utf8 hash)) 0 12)))

    (define (sign-in auth username password)
      "Syntax: (sign-in auth username password)
Library: (app auth)
Description: The user entry if password is right for username, else #f.
  Upgrades an outdated password hash on success."
      (let* ((path (auth-users-file auth))
             (user (find-user path username)))
        (cond
          ((not (password-verify password (and user (user-hash user)))) #f)
          ((password-needs-rehash? (user-hash user))
           (save-user! path username (password-hash password))
           (find-user path username))
          (else user))))

    (define (session-user auth req)
      "Syntax: (session-user auth req)
Library: (app auth)
Description: The signed-in user's entry, or #f if there is no valid session
  or the user was deleted or changed the password since."
      (let ((s (session-ref (auth-session auth) req)))
        (and (pair? s)
             (let* ((name (assq 'user s))
                    (stamp (assq 'stamp s))
                    (user (and name (string? (cdr name))
                               (find-user (auth-users-file auth) (cdr name)))))
               (and user stamp
                    (equal? (cdr stamp) (password-stamp (user-hash user)))
                    user)))))

    (define (start-session auth user)
      "Syntax: (start-session auth user)
Library: (app auth)
Description: The Set-Cookie header pair that signs user in."
      (session-set-cookie (auth-session auth)
                          `((user . ,(user-name user))
                            (stamp . ,(password-stamp (user-hash user))))))

    (define (end-session auth)
      "Syntax: (end-session auth)
Library: (app auth)
Description: The Set-Cookie header pair that signs out."
      (session-clear-cookie (auth-session auth)))

    (define (change-password! auth user new-password)
      "Syntax: (change-password! auth user new-password)
Library: (app auth)
Description: Stores a new hash for user and returns the updated entry.
  Other sessions of the user end; start a new one for this browser."
      (save-user! (auth-users-file auth) (user-name user) (password-hash new-password))
      (find-user (auth-users-file auth) (user-name user)))))

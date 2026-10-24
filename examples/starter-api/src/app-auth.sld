;; (app auth) — sign-in and bearer tokens for the JSON API.
;;
;; Passwords: (scm crypto password), as in starter-login, with a dummy
;; check for unknown usernames and hash upgrades at sign-in.
;;
;; Tokens: (scm crypto token), signed and expiring, with the purpose "api"
;; so that no other token made with the same key passes as one. No server-
;; side store. A token carries the username and a stamp of the password
;; hash, and every request looks the user up again: deleting a user or
;; changing a password revokes their tokens.

(define-library (app auth)
  (import (scheme base)
          (scm crypto)
          (scm crypto password)
          (scm crypto token)
          (app users))
  (export make-auth
          auth-max-age
          sign-in
          issue-token
          token-user
          min-password-length)
  (begin

    (define min-password-length 8)

    (define token-options '((purpose . "api")))

    (define-record-type auth
      (%make-auth keys max-age users-file)
      auth?
      (keys auth-keys)
      (max-age auth-max-age)
      (users-file auth-users-file))

    (define (make-auth secret max-age users-file)
      "Syntax: (make-auth secret max-age users-file)
Library: (app auth)
Description: Token settings: secret (base64, or a list for key rotation),
  token lifetime in seconds, and the user store. A bad secret raises here,
  at startup."
      (%make-auth (token-secrets secret) max-age users-file))

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

    (define (issue-token auth user)
      "Syntax: (issue-token auth user)
Library: (app auth)
Description: A bearer token for user, valid for the configured lifetime."
      (token-sign (auth-keys auth)
                  `((sub . ,(user-name user))
                    (stamp . ,(password-stamp (user-hash user))))
                  (auth-max-age auth)
                  token-options))

    (define (token-user auth token)
      "Syntax: (token-user auth token)
Library: (app auth)
Description: The user entry for a valid, unexpired token, or #f (also when
  the user was deleted or changed the password since)."
      (let ((t (and token (token-verify (auth-keys auth) token token-options))))
        (and (pair? t)
             (let* ((sub (assq 'sub t))
                    (stamp (assq 'stamp t))
                    (user (and sub (string? (cdr sub))
                               (find-user (auth-users-file auth) (cdr sub)))))
               (and user stamp
                    (equal? (cdr stamp) (password-stamp (user-hash user)))
                    user)))))))

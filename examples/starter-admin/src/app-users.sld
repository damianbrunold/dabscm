;; (app users) — user, role, and user-role queries plus authentication.
;; All SQL is parameterized through (app db). Hashing is delegated to
;; (app auth). Row values come back as alists keyed by column name; use
;; (col row "name") to read a field.

(define-library (app users)
  (import (scheme base)
          (scheme char)
          (srfi 13)
          (app db)
          (app auth))
  (export col
          valid-username? valid-role-name?
          find-user-by-name load-user authenticate
          list-users all-user-roles create-user! delete-user!
          list-roles create-role!
          assign-role! assign-role-by-name! unassign-role!
          user-role-names user-has-role?)
  (begin

    (define (col row name) (cdr (assoc name row)))

    ;; ids arrive from forms and from the db as strings; bigint columns
    ;; compare fine either way, but coercing keeps the SQL unambiguous.
    (define (->int x) (if (string? x) (string->number x) x))

    (define (valid-name? s)
      (and (string? s)
           (<= 1 (string-length s) 64)
           (string-every
            (lambda (c)
              (or (char-alphabetic? c) (char-numeric? c)
                  (memv c '(#\. #\_ #\-))))
            s)))
    (define valid-username? valid-name?)
    (define valid-role-name? valid-name?)

    ;; --- users --------------------------------------------------------

    (define (find-user-by-name cfg name)
      (db-row cfg "SELECT id, username, pass_hash FROM users WHERE username = $1"
              name))

    (define (load-user cfg id)
      (db-row cfg "SELECT id, username, pass_hash FROM users WHERE id = $1"
              (->int id)))

    (define (authenticate cfg username password)
      "Syntax: (authenticate cfg username password)
Library: (app users)
Description: Returns the user row alist if the password matches, else #f."
      (let ((u (find-user-by-name cfg username)))
        (and u (verify-password password (col u "pass_hash")) u)))

    (define (list-users cfg)
      "Syntax: (list-users cfg)
Library: (app users)
Description: All users, ordered by username. Pair with all-user-roles to
  attach each user's roles."
      (db-rows cfg
        "SELECT id, username, created_at FROM users ORDER BY username"))

    (define (all-user-roles cfg)
      "Syntax: (all-user-roles cfg)
Library: (app users)
Description: Every (user_id, role_id, name) assignment, so callers can group
  roles by user without an N+1 query."
      (db-rows cfg
        (string-append
         "SELECT ur.user_id, r.id AS role_id, r.name "
         "FROM user_roles ur JOIN roles r ON r.id = ur.role_id "
         "ORDER BY r.name")))

    (define (create-user! cfg username password)
      "Syntax: (create-user! cfg username password)
Library: (app users)
Description: Inserts a user and returns the new id (a string). Raises on a
  duplicate username (unique violation)."
      (db-scalar cfg
        "INSERT INTO users (username, pass_hash) VALUES ($1, $2) RETURNING id"
        username (hash-password password)))

    (define (delete-user! cfg id)
      (db-exec cfg "DELETE FROM users WHERE id = $1" (->int id)))

    ;; --- roles --------------------------------------------------------

    (define (list-roles cfg)
      (db-rows cfg "SELECT id, name FROM roles ORDER BY name"))

    (define (create-role! cfg name)
      "Syntax: (create-role! cfg name)
Library: (app users)
Description: Inserts a role; no-op if it already exists."
      (db-exec cfg
        "INSERT INTO roles (name) VALUES ($1) ON CONFLICT (name) DO NOTHING"
        name))

    (define (assign-role! cfg user-id role-id)
      (db-exec cfg
        (string-append "INSERT INTO user_roles (user_id, role_id) "
                       "VALUES ($1, $2) ON CONFLICT DO NOTHING")
        (->int user-id) (->int role-id)))

    (define (assign-role-by-name! cfg user-id role-name)
      (db-exec cfg
        (string-append
         "INSERT INTO user_roles (user_id, role_id) "
         "SELECT $1, id FROM roles WHERE name = $2 ON CONFLICT DO NOTHING")
        (->int user-id) role-name))

    (define (unassign-role! cfg user-id role-id)
      (db-exec cfg "DELETE FROM user_roles WHERE user_id = $1 AND role_id = $2"
               (->int user-id) (->int role-id)))

    (define (user-role-names cfg user-id)
      "Syntax: (user-role-names cfg user-id)
Library: (app users)
Description: List of the user's role-name strings."
      (map (lambda (r) (col r "name"))
           (db-rows cfg
             (string-append
              "SELECT r.name FROM roles r "
              "JOIN user_roles ur ON ur.role_id = r.id "
              "WHERE ur.user_id = $1 ORDER BY r.name")
             (->int user-id))))

    (define (user-has-role? cfg user-id name)
      "Syntax: (user-has-role? cfg user-id name)
Library: (app users)
Description: True if the user holds the named role."
      (and (db-row cfg
             (string-append
              "SELECT 1 FROM user_roles ur "
              "JOIN roles r ON r.id = ur.role_id "
              "WHERE ur.user_id = $1 AND r.name = $2")
             (->int user-id) name)
           #t))))

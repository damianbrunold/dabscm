;; (app views) — HTML rendering. All dynamic values flow through the
;; auto-escaping (scm html builder); only fixed strings (the SVG icons) are
;; emitted raw. No inline scripts or style attributes: the
;; Content-Security-Policy forbids them.

(define-library (app views)
  (import (scheme base)
          (scm html builder)
          (app site)
          (app users))            ; col
  (export login-page home-page profile-page admin-page error-page)
  (begin

    (define theme-icons
      (raw (string-append
            "<svg class=\"i-sun\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4\"/></svg>"
            "<svg class=\"i-moon\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" aria-hidden=\"true\"><path d=\"M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z\"/></svg>")))

    ;; who: #f when signed out, else (username admin?).
    (define (page title who body)
      (string-append
       (html->string
        (html5
         '(@ (lang "en"))
         `(head
           (meta (@ (charset "utf-8")))
           (meta (@ (name "viewport") (content "width=device-width, initial-scale=1")))
           (title ,(string-append title " · Starter Admin"))
           (link (@ (rel "icon") (href ,(asset "favicon.svg"))))
           (link (@ (rel "stylesheet") (href ,(asset "css/app.css"))))
           (script (@ (src ,(asset "js/theme-init.js"))))
           (script (@ (src ,(asset "js/theme-toggle.js")) (defer #t))))
         `(body
           (header (@ (class "app-header"))
             (h1 (a (@ (href ,(url "/"))) "Starter Admin"))
             (nav (@ (class "nav"))
               ;; The username links to the profile page, which is where
               ;; signing out lives. Admins also get the console.
               ,@(if who
                     `(,@(if (cadr who) `((a (@ (href ,(url "/admin"))) "Admin")) '())
                       (a (@ (href ,(url "/profile")) (class "who")) ,(car who)))
                     '())
               (button (@ (class "icon-btn js-theme-toggle") (type "button")
                          (aria-label "Toggle dark mode"))
                 ,theme-icons)))
           (main ,body))))
       "\n"))

    ;; msg: #f, or (kind . text) with kind 'error or 'success.
    (define (notice msg)
      (if msg
          `(p (@ (class ,(string-append "notice " (symbol->string (car msg)))))
              ,(cdr msg))
          ""))

    (define (login-page error?)
      (page "Sign in" #f
        `(section (@ (class "card narrow"))
           (h2 "Sign in")
           ,(notice (and error? '(error . "Invalid username or password.")))
           (form (@ (method "post") (action ,(url "/login")))
             (label "Username"
               (input (@ (name "username") (autocomplete "username")
                         (autofocus #t) (required #t))))
             (label "Password"
               (input (@ (name "password") (type "password")
                         (autocomplete "current-password") (required #t))))
             (button (@ (type "submit") (class "primary")) "Sign in")))))

    (define (comma-list items)
      (let loop ((xs items) (acc ""))
        (cond ((null? xs) acc)
              ((string=? acc "") (loop (cdr xs) (car xs)))
              (else (loop (cdr xs) (string-append acc ", " (car xs)))))))

    (define (home-page username roles admin?)
      (page "Home" (list username admin?)
        `(section
           (h2 "Welcome, " ,username)
           (p "Your roles: "
              ,(if (null? roles) '(em "none") (comma-list roles)))
           ,(if admin?
                `(p (a (@ (href ,(url "/admin"))) "Open the admin console →"))
                ""))))

    (define (profile-page username admin? msg)
      (page "Profile" (list username admin?)
        `(section (@ (class "card narrow"))
           (h2 "Profile")
           ,(notice msg)
           (p "Change the password for " (strong ,username) ".")
           (form (@ (method "post") (action ,(url "/profile/password")))
             (label "Current password"
               (input (@ (name "current") (type "password")
                         (autocomplete "current-password") (required #t))))
             (label "New password"
               (input (@ (name "new") (type "password") (minlength "8")
                         (autocomplete "new-password") (required #t))))
             (label "Confirm new password"
               (input (@ (name "confirm") (type "password") (minlength "8")
                         (autocomplete "new-password") (required #t))))
             (button (@ (type "submit") (class "primary")) "Update password"))
           (form (@ (method "post") (action ,(url "/logout")) (class "logout-form"))
             (button (@ (type "submit")) "Sign out")))))

    ;; --- admin console ------------------------------------------------

    (define (id->string x) (if (number? x) (number->string x) x))

    (define (role-chip user-id assignment)
      ;; assignment: alist (user_id role_id name); removed via a small form.
      `(form (@ (method "post")
                (action ,(url (string-append "/admin/users/" user-id "/roles/"
                                             (id->string (col assignment "role_id"))
                                             "/delete")))
                (class "chip"))
         (span ,(col assignment "name"))
         (button (@ (class "chip-x") (type "submit") (title "Remove role")
                    (aria-label ,(string-append "Remove role " (col assignment "name"))))
                 "×")))

    (define (assign-form user-id roles)
      `(form (@ (method "post")
                (action ,(url (string-append "/admin/users/" user-id "/roles")))
                (class "assign"))
         (select (@ (name "role_id") (aria-label "Role"))
           ,@(map (lambda (r)
                    `(option (@ (value ,(id->string (col r "id")))) ,(col r "name")))
                  roles))
         (button (@ (type "submit")) "Assign")))

    (define (user-row user roles assignments self-id)
      (let* ((uid (id->string (col user "id")))
             (self? (string=? uid self-id))
             (mine (let loop ((as assignments))
                     (cond ((null? as) '())
                           ((string=? (id->string (col (car as) "user_id")) uid)
                            (cons (car as) (loop (cdr as))))
                           (else (loop (cdr as)))))))
        `(tr
          (td ,(col user "username")
              ,(if self? '(span (@ (class "muted")) " (you)") ""))
          (td (div (@ (class "chips"))
                ,@(if (null? mine)
                      '((span (@ (class "muted")) "—"))
                      (map (lambda (a) (role-chip uid a)) mine))))
          (td ,(if (null? roles) "" (assign-form uid roles)))
          (td ,(if self?
                   ""                   ; never offer to delete yourself
                   `(form (@ (method "post")
                             (action ,(url (string-append "/admin/users/" uid "/delete")))
                             (class "inline"))
                      (button (@ (class "danger") (type "submit")) "Delete")))))))

    (define (admin-page username self-id users roles assignments msg)
      (page "Admin" (list username #t)
        `(section
           (h2 "Users")
           ,(notice msg)
           (table (@ (class "data"))
             (thead (tr (th "User") (th "Roles") (th "Assign") (th "")))
             (tbody
              ,@(map (lambda (u) (user-row u roles assignments (id->string self-id)))
                     users)))

           (h3 "Add user")
           (form (@ (method "post") (action ,(url "/admin/users")) (class "row-form"))
             (input (@ (name "username") (placeholder "username")
                       (aria-label "Username") (required #t)))
             (input (@ (name "password") (type "password") (minlength "8")
                       (autocomplete "new-password")
                       (placeholder "password (min 8)") (aria-label "Password")
                       (required #t)))
             (label (@ (class "check"))
               (input (@ (type "checkbox") (name "admin") (value "1")))
               " admin")
             (button (@ (type "submit") (class "primary")) "Create user"))

           (h2 "Roles")
           ,(if (null? roles)
                '(p (@ (class "muted")) "No roles yet.")
                `(ul (@ (class "roles"))
                   ,@(map (lambda (r) `(li ,(col r "name"))) roles)))
           (h3 "Add role")
           (form (@ (method "post") (action ,(url "/admin/roles")) (class "row-form"))
             (input (@ (name "name") (placeholder "role name")
                       (aria-label "Role name") (required #t)))
             (button (@ (type "submit") (class "primary")) "Create role")))))

    (define (error-page)
      (page "Error" #f
        '(section (h2 "Something went wrong")
                  (p "The error has been logged."))))))

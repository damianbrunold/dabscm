;; (app views) — HTML rendering. All dynamic values flow through the
;; auto-escaping (scm html builder); only fixed strings (icons, the theme
;; boot script) are emitted raw.

(define-library (app views)
  (import (scheme base)
          (scm html builder)
          (srfi 1)                ; filter
          (srfi 13)
          (app users))            ; col
  (export login-page home-page profile-page admin-page)
  (begin

    (define theme-boot-script
      (raw (string-append
            "(function(){var t=localStorage.getItem('theme');"
            "if(!t)t=matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light';"
            "document.documentElement.setAttribute('data-theme',t);})();")))

    (define (theme-toggle)
      `(button (@ (id "theme-toggle") (class "icon-btn")
                  (type "button") (aria-label "Toggle dark mode"))
         ,(raw "<svg class=\"i-sun\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4\"/></svg>")
         ,(raw "<svg class=\"i-moon\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z\"/></svg>")))

    ;; nav: #f when logged out, else (list username admin?).
    (define (page title nav body)
      (string-append
       (html->string
        (html5
         `(head
           (meta (@ (charset "utf-8")))
           (meta (@ (name "viewport") (content "width=device-width, initial-scale=1")))
           (title ,title)
           (script ,theme-boot-script)
           (link (@ (rel "stylesheet") (href "/static/app.css")))
           (script (@ (src "/static/app.js") (defer #t))))
         `(body
           (header (@ (class "app-header"))
             (h1 (a (@ (href "/")) "Starter Admin"))
             (nav (@ (class "nav"))
               ;; The app title (left) links home; the username links to the
               ;; profile page, which is where logging out lives. Admins also
               ;; get a direct link to the console.
               ,@(if nav
                     `(,@(if (cadr nav) `((a (@ (href "/admin")) "Admin")) '())
                       (a (@ (href "/profile") (class "who")) ,(car nav)))
                     '())
               ,(theme-toggle)))
           (main ,body))))
       "\n"))

    (define (notice msg)
      (if msg
          `(p (@ (class ,(string-append "notice " (symbol->string (car msg)))))
              ,(cdr msg))
          ""))

    (define (login-page error?)
      (page "Sign in" #f
        `(section (@ (class "card narrow"))
           (h2 "Sign in")
           ,(if error? `(p (@ (class "notice error")) "Invalid username or password.") "")
           (form (@ (method "post") (action "/login"))
             (label "Username"
               (input (@ (name "username") (autocomplete "username")
                         (autofocus #t) (required #t))))
             (label "Password"
               (input (@ (name "password") (type "password")
                         (autocomplete "current-password") (required #t))))
             (button (@ (type "submit") (class "primary")) "Sign in")))))

    (define (home-page username roles admin?)
      (page "Home" (list username admin?)
        `(section
           (h2 "Welcome, " ,username)
           (p "Your roles: "
              ,(if (null? roles) `(em "none") (string-join roles ", ")))
           ,(if admin?
                `(p (a (@ (href "/admin")) "Open the admin console →"))
                ""))))

    (define (profile-page username admin? msg)
      (page "Profile" (list username admin?)
        `(section (@ (class "card narrow"))
           (h2 "Profile")
           ,(notice msg)
           (p "Change the password for " (strong ,username) ".")
           (form (@ (method "post") (action "/profile/password"))
             (label "Current password"
               (input (@ (name "current") (type "password")
                         (autocomplete "current-password") (required #t))))
             (label "New password"
               (input (@ (name "new") (type "password")
                         (autocomplete "new-password") (required #t))))
             (label "Confirm new password"
               (input (@ (name "confirm") (type "password")
                         (autocomplete "new-password") (required #t))))
             (button (@ (type "submit") (class "primary")) "Update password"))
           (form (@ (method "post") (action "/logout") (class "logout-form"))
             (button (@ (type "submit")) "Log out")))))

    ;; --- admin console ------------------------------------------------

    (define (role-chip user-id assignment)
      ;; assignment: alist (user_id role_id name) — unassign via small form.
      `(form (@ (method "post")
                (action ,(string-append "/admin/users/" user-id "/roles/"
                                        (col assignment "role_id") "/delete"))
                (class "chip"))
         (span ,(col assignment "name"))
         (button (@ (class "chip-x") (type "submit") (title "Remove role")) "×")))

    (define (assign-form user-id roles)
      `(form (@ (method "post")
                (action ,(string-append "/admin/users/" user-id "/roles"))
                (class "assign"))
         (select (@ (name "role_id"))
           ,@(map (lambda (r)
                    `(option (@ (value ,(col r "id"))) ,(col r "name")))
                  roles))
         (button (@ (type "submit")) "Assign")))

    (define (user-row user roles assignments self-id)
      (let* ((uid (col user "id"))
             (mine (filter (lambda (a) (string=? (col a "user_id") uid)) assignments)))
        `(tr
          (td ,(col user "username")
              ,(if (string=? uid self-id) `(span (@ (class "you")) " (you)") ""))
          (td (div (@ (class "chips"))
                ,@(if (null? mine)
                      `((span (@ (class "muted")) "—"))
                      (map (lambda (a) (role-chip uid a)) mine))))
          (td ,(assign-form uid roles))
          (td ,(if (string=? uid self-id)
                   ""   ; never offer to delete yourself
                   `(form (@ (method "post")
                             (action ,(string-append "/admin/users/" uid "/delete"))
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
              ,@(map (lambda (u) (user-row u roles assignments self-id)) users)))

           (h3 "Add user")
           (form (@ (method "post") (action "/admin/users") (class "row-form"))
             (input (@ (name "username") (placeholder "username") (required #t)))
             (input (@ (name "password") (type "password")
                       (placeholder "password (min 8)") (required #t)))
             (button (@ (type "submit") (class "primary")) "Create user"))

           (h2 "Roles")
           ,(if (null? roles)
                `(p (@ (class "muted")) "No roles yet.")
                `(ul (@ (class "roles"))
                   ,@(map (lambda (r) `(li ,(col r "name"))) roles)))
           (h3 "Add role")
           (form (@ (method "post") (action "/admin/roles") (class "row-form"))
             (input (@ (name "name") (placeholder "role name") (required #t)))
             (button (@ (type "submit") (class "primary")) "Create role")))))))

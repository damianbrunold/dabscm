;; (app views) — HTML rendering. All dynamic values flow through the
;; auto-escaping (scm html builder), so user data can never inject markup.
;; Only fixed strings (the SVG icons) are emitted raw. No inline scripts or
;; style attributes: the Content-Security-Policy forbids them.

(define-library (app views)
  (import (scheme base)
          (scm html builder)
          (scm json simple)
          (app site))
  (export login-page home-page profile-page error-page)
  (begin

    (define theme-icons
      (raw (string-append
            "<svg class=\"i-sun\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4\"/></svg>"
            "<svg class=\"i-moon\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" aria-hidden=\"true\"><path d=\"M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z\"/></svg>")))

    ;; who: #f when signed out, otherwise the username (links to the
    ;; profile page, which is where signing out lives).
    (define (page title who body)
      (string-append
       (html->string
        (html5
         '(@ (lang "en"))
         `(head
           (meta (@ (charset "utf-8")))
           (meta (@ (name "viewport") (content "width=device-width, initial-scale=1")))
           (title ,(string-append title " · Starter Login"))
           (link (@ (rel "icon") (href ,(asset "favicon.svg"))))
           (link (@ (rel "stylesheet") (href ,(asset "css/app.css"))))
           (script (@ (src ,(asset "js/theme-init.js"))))
           (script (@ (src ,(asset "js/theme-toggle.js")) (defer #t))))
         `(body
           (header (@ (class "app-header"))
             (h1 (a (@ (href ,(url "/"))) "Starter Login"))
             (nav (@ (class "nav"))
               ,@(if who
                     `((a (@ (href ,(url "/profile")) (class "who")) ,who))
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

    (define (items-table items)
      `(table (@ (class "data"))
         (thead (tr (th "Name") (th (@ (class "num")) "Count")))
         (tbody
          ,@(map (lambda (it)
                   `(tr (td ,(json-ref it "name" ""))
                        (td (@ (class "num"))
                            ,(number->string (json-ref it "count" 0)))))
                 items))))

    (define (home-page username items)
      (page "Home" username
        `(section
           (p "Signed in as " (strong ,username) ".")
           ,(items-table items))))

    (define (profile-page username msg)
      (page "Profile" username
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

    (define (error-page)
      (page "Error" #f
        '(section (h2 "Something went wrong")
                  (p "The error has been logged."))))))

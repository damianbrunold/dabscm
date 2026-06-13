;; (app views) — HTML rendering. All dynamic values flow through the
;; auto-escaping (scm html builder), so user data can never inject markup.
;; Inline strings opted into raw output (SVG icons, the theme boot script)
;; are produced here, never from user input.

(define-library (app views)
  (import (scheme base)
          (scm html builder)
          (scm json simple))
  (export login-page home-page profile-page)
  (begin

    ;; Applied before first paint so the page never flashes the wrong theme.
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

    ;; nav: #f when logged out, otherwise the username (shows links + logout).
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
             (h1 (a (@ (href "/")) "Starter Login"))
             (nav (@ (class "nav"))
               ;; The app title (left) links home; the username links to the
               ;; profile page, which is where logging out lives.
               ,@(if nav
                     `((a (@ (href "/profile") (class "who")) ,nav))
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
             (button (@ (type "submit")) "Log out")))))))

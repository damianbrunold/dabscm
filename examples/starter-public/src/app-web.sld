;; (app web) — the whole web app: routes, page rendering, middleware.
;;
;; make-app returns the server-level handler (lambda (req) resp), so
;; bin/server.scm only has to serve it and the tests can call it directly
;; with a request, no socket involved.
;;
;; Pages follow a strict Content-Security-Policy (see security-headers in
;; (scm net http middleware)): no inline <script> and no style="" attributes.
;; All JavaScript and CSS lives under static/.

(define-library (app web)
  (import (scheme base)
          (scm io)
          (scm json simple)
          (scm html builder)
          (scm net http request)
          (scm net http response)
          (scm net http route)
          (scm net http static)
          (scm net http middleware))
  (export make-app)
  (begin

    ;; --- URL prefix ---------------------------------------------------

    ;; The app can be mounted under a path ("/inventory"), with the reverse
    ;; proxy passing paths through unchanged. Every route and every link
    ;; goes through url / asset, which read the current site.
    (define-record-type site
      (make-site prefix static-url)
      site?
      (prefix site-prefix)
      (static-url site-static-url))

    (define current-site (make-parameter #f))

    ;; "" or "/" -> ""; "inventory/" -> "/inventory"
    (define (normalize-prefix p)
      (let* ((s (if (and (> (string-length p) 0) (char=? (string-ref p 0) #\/))
                    p
                    (string-append "/" p)))
             (n (string-length s)))
        (if (char=? (string-ref s (- n 1)) #\/)
            (substring s 0 (- n 1))
            s)))

    (define (url path) (string-append (site-prefix (current-site)) path))

    ;; /static/<rel>?v=<mtime>: browsers cache it for a year, and an edited
    ;; file gets a new URL without a restart.
    (define (asset rel) ((site-static-url (current-site)) rel))

    ;; --- data ---------------------------------------------------------

    ;; Read on each request so edits show up without a restart. json-parse
    ;; turns a JSON array of objects into a vector of alists.
    (define (load-items data-file)
      (vector->list (json-parse (read-file-string data-file))))

    ;; --- HTML ---------------------------------------------------------

    ;; Both icons are always in the page; the CSS shows the one that fits
    ;; the active theme. Fixed markup, so raw is safe here.
    (define theme-icons
      (raw (string-append
            "<svg class=\"i-sun\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4\"/></svg>"
            "<svg class=\"i-moon\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" aria-hidden=\"true\"><path d=\"M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z\"/></svg>")))

    (define (page title body)
      (string-append
       (html->string
        (html5
         '(@ (lang "en"))
         `(head
           (meta (@ (charset "utf-8")))
           (meta (@ (name "viewport") (content "width=device-width, initial-scale=1")))
           (title ,title)
           (link (@ (rel "icon") (href ,(asset "favicon.svg"))))
           (link (@ (rel "stylesheet") (href ,(asset "css/app.css"))))
           ;; Not deferred: applies a remembered theme before first paint.
           (script (@ (src ,(asset "js/theme-init.js"))))
           (script (@ (src ,(asset "js/theme-toggle.js")) (defer #t))))
         `(body
           (header (@ (class "app-header"))
             (h1 (a (@ (href ,(url "/"))) "Inventory"))
             (button (@ (class "icon-btn js-theme-toggle") (type "button")
                        (aria-label "Toggle dark mode"))
               ,theme-icons))
           (main ,body))))
       "\n"))

    ;; Values go through the auto-escaping builder: data can never inject
    ;; markup.
    (define (items-table items)
      `(table (@ (class "data"))
         (thead (tr (th "Name") (th (@ (class "num")) "Count")))
         (tbody
          ,@(map (lambda (it)
                   `(tr (td ,(json-ref it "name" ""))
                        (td (@ (class "num"))
                            ,(number->string (json-ref it "count" 0)))))
                 items))))

    (define (error-page req)
      (html-response
       (page "Error" '(section (h2 "Something went wrong")
                               (p "The error has been logged.")))))

    ;; --- app ----------------------------------------------------------

    (define (setting settings key)
      (let ((p (assq key settings)))
        (if p (cdr p) (error "make-app: missing setting" key))))

    (define (make-app settings)
      "Syntax: (make-app settings)
Library: (app web)
Description: Builds the app's request handler. settings is an alist with
  url-prefix (\"\" at the host root), static-dir and data-file (absolute
  paths)."
      (let* ((prefix (normalize-prefix (setting settings 'url-prefix)))
             (static-dir (setting settings 'static-dir))
             (data-file (setting settings 'data-file))
             (site (make-site prefix
                              (make-static-url static-dir
                                               (string-append prefix "/static"))))
             (router (make-router)))

        (router-add! router "GET" (string-append prefix "/")
          (lambda (req params)
            (html-response (page "Inventory" (items-table (load-items data-file))))))

        (router-add! router "GET" (string-append prefix "/static/*")
          (make-static-handler static-dir))

        ;; Outside the prefix: the health probe talks to the app directly.
        (router-add! router "GET" "/healthz"
          (lambda (req params) (text-response "ok\n")))

        ;; Outermost first: log every request, add the security headers,
        ;; make the site current for url/asset, and turn errors into a
        ;; logged 500 page.
        (let ((handler (with-error-handler (router->handler router) error-page)))
          (with-access-log
           (with-security-headers
            (lambda (req)
              (parameterize ((current-site site))
                (handler req))))))))))

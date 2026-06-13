;; starter-public — a public single-page web app (no authentication).
;;
;; Renders a small table from data/items.json. Demonstrates the pieces you
;; need for almost any page: routing, serving static CSS/JS, reading and
;; parsing JSON, safe (auto-escaping) HTML rendering, and OS-aware
;; light/dark theming that the user can override (persisted in
;; localStorage). Everything lives in this one file so it reads top to
;; bottom and is easy to copy as a starting point.
;;
;; Run:  scm main.scm
;; Dev:  scm bin/dev-server.scm     (restarts on file change)

(import (scheme base)
        (scheme write)
        (scheme load)
        (scheme file)
        (scheme process-context)
        (scm net http response)
        (scm net http route)
        (scm json simple)
        (scm html builder)
        (scm io)
        (scm fs)
        (srfi 13))

;; --- project root + configuration -----------------------------------

;; command-line arg 0 is this script's path; resolve the project root from
;; it so the app can be launched from any working directory.
(define root
  (directory-name (absolute-path (car (command-line)))))

(define (in-root . parts)
  (apply string-append root "/" parts))

;; Load config.scm if present, else fall back to the committed example so
;; the app runs out of the box. config.scm is for local/production overrides.
(load (let ((c (in-root "config.scm")))
        (if (file-exists? c) c (in-root "config.example.scm"))))

;; --- data -------------------------------------------------------------

;; Read + parse the JSON data file on each request so edits show up without
;; a restart. json-parse turns a JSON array of objects into a vector of
;; alists: #( (("name" . "Widgets") ("count" . 42)) ... ).
(define (load-items)
  (vector->list (json-parse (read-file-string (in-root "data/items.json")))))

;; --- HTML rendering ---------------------------------------------------

;; Applied before first paint so the page never flashes the wrong theme.
;; Wrapped in (raw ...) because the HTML builder escapes <script> bodies.
(define theme-boot-script
  (raw (string-append
        "(function(){var t=localStorage.getItem('theme');"
        "if(!t)t=matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light';"
        "document.documentElement.setAttribute('data-theme',t);})();")))

(define (theme-toggle)
  ;; One button; CSS shows the sun in dark mode and the moon in light mode.
  `(button (@ (id "theme-toggle") (class "icon-btn")
              (type "button") (aria-label "Toggle dark mode"))
     ,(raw "<svg class=\"i-sun\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4\"/></svg>")
     ,(raw "<svg class=\"i-moon\" viewBox=\"0 0 24 24\" width=\"20\" height=\"20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z\"/></svg>")))

(define (page title body)
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
         (h1 ,title)
         ,(theme-toggle))
       (main ,body))))
   "\n"))

(define (items-table items)
  `(table (@ (class "data"))
     (thead (tr (th "Name") (th (@ (class "num")) "Count")))
     (tbody
      ,@(map (lambda (it)
               `(tr (td ,(json-ref it "name" ""))
                    (td (@ (class "num"))
                        ,(number->string (json-ref it "count" 0)))))
             items))))

;; --- static files -----------------------------------------------------

(define (content-type-for path)
  (cond ((string-suffix? ".css" path)  "text/css; charset=utf-8")
        ((string-suffix? ".js" path)   "application/javascript; charset=utf-8")
        ((string-suffix? ".svg" path)  "image/svg+xml")
        ((string-suffix? ".png" path)  "image/png")
        ((string-suffix? ".ico" path)  "image/x-icon")
        ((string-suffix? ".json" path) "application/json; charset=utf-8")
        (else "application/octet-stream")))

;; Reject absolute paths and any ".." segment so a request can never escape
;; the static directory.
(define (safe-rel? rel)
  (and rel
       (> (string-length rel) 0)
       (not (char=? (string-ref rel 0) #\/))
       (not (string-contains rel ".."))))

(define (read-file-bytes path)
  (let* ((port (open-binary-input-file path))
         (bv (read-bytevector (file-size path) port)))
    (close-input-port port)
    (if (eof-object? bv) (bytevector) bv)))

(define (static-handler req params)
  (let ((rel (params-ref params "*")))
    (if (not (safe-rel? rel))
        (http-forbidden "forbidden")
        (let ((full (in-root "static/" rel)))
          (if (and (file-exists? full) (not (directory-exists? full)))
              (make-http-response
               200
               (list (cons "Content-Type" (content-type-for full)))
               (read-file-bytes full))
              (http-not-found))))))

;; --- routes + server --------------------------------------------------

(define (home-handler req params)
  (html-response
   (page "Inventory" (items-table (load-items)))))

(define router (make-router))
(router-add! router "GET" "/" home-handler)
(router-add! router "GET" "/static/*" static-handler)
(router-add! router "GET" "/healthz" (lambda (req params) (text-response "ok\n")))

(display (string-append "starter-public listening on http://"
                        http-host ":" (number->string http-port) "\n"))
(run-app-with-router router http-port 0 http-host)

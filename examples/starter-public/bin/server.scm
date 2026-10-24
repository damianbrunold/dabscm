;; Usage: scm bin/server.scm [config-path]
;;
;; Reads the config (config-path, or else config.scm, which the first run
;; creates from config.example.scm) and serves the app.

(import (scheme base)
        (scheme process-context)
        (scm module)
        (scm fs)
        (scm log)
        (scm net http server))

;; Resolve the project root from this script's path so it runs from anywhere,
;; and make src/ importable.
(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app config) (app web))

(define cfg (load-config root (cdr (command-line))))
(define host (config-ref cfg 'http-host "127.0.0.1"))
(define port (config-ref cfg 'http-port 8070))
(define prefix (config-ref cfg 'url-prefix ""))

(define app
  (make-app
   `((url-prefix . ,prefix)
     (static-dir . ,(resolve-path root (config-ref cfg 'static-dir "static")))
     (data-file  . ,(resolve-path root (config-ref cfg 'data-file "data/items.json"))))))

(log-info "app" (string-append "starter-public listening on http://" host ":"
                               (number->string port) prefix "/"))
(serve-forever port app 0 host)

;; Usage: scm bin/server.scm [config-path]
;;
;; Reads the config (config-path, or else config.scm, which the first run
;; creates from config.example.scm with a fresh secret) and serves the app.

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
(define port (config-ref cfg 'http-port 8071))
(define prefix (config-ref cfg 'url-prefix ""))
(define (path key default) (resolve-path root (config-ref cfg key default)))

(define app
  (make-app
   `((url-prefix      . ,prefix)
     (static-dir      . ,(path 'static-dir "static"))
     (items-file      . ,(path 'items-file "data/items.json"))
     (users-file      . ,(string-append (path 'data-dir "data") "/users.scm"))
     (session-secret  . ,(config-secret cfg 'session-secret))
     (session-max-age . ,(config-ref cfg 'session-max-age (* 60 60 24 7)))
     (secure-cookies? . ,(config-ref cfg 'secure-cookies? #t)))))

(log-info "app" (string-append "starter-login listening on http://" host ":"
                               (number->string port) prefix "/"))
(serve-forever port app 0 host)

;; Usage: scm bin/server.scm [config-path]
;;
;; Reads the config (config-path, or else config.scm, which the first run
;; creates from config.example.scm with a fresh secret) and serves the API.

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

(import (app config) (app api))

(define cfg (load-config root (cdr (command-line))))
(define host (config-ref cfg 'http-host "127.0.0.1"))
(define port (config-ref cfg 'http-port 8073))
(define prefix (config-ref cfg 'url-prefix ""))
(define data-dir (resolve-path root (config-ref cfg 'data-dir "data")))

(define app
  (make-app
   `((url-prefix    . ,prefix)
     (users-file    . ,(string-append data-dir "/users.scm"))
     (items-file    . ,(string-append data-dir "/items.scm"))
     (token-secret  . ,(config-secret cfg 'token-secret))
     (token-max-age . ,(config-ref cfg 'token-max-age (* 60 60 12))))))

(log-info "app" (string-append "starter-api listening on http://" host ":"
                               (number->string port) prefix "/api/"))
(serve-forever port app 0 host)

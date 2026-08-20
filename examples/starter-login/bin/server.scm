;; Usage: scm bin/server.scm [config-path]
;;
;; Reads config (config.scm, or the path given as argv, falling back to
;; config.example.scm) and starts the webapp. The config file is plain
;; Scheme — see config.example.scm for the expected bindings.

(import (scheme base)
        (scheme write)
        (scheme load)
        (scheme process-context)
        (scm module)
        (scm fs))

;; Resolve the project root from this script's path so it runs from anywhere.
(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))

;; Make src/ importable, then load the app modules.
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app auth) (app routes))

(define cfg-path
  (let ((args (cdr (command-line))))
    (cond ((pair? args) (car args))
          ((file-exists? (string-append root "/config.scm"))
           (string-append root "/config.scm"))
          (else (string-append root "/config.example.scm")))))

(load cfg-path)

(define (abs-path p)
  (if (and (> (string-length p) 0) (char=? (string-ref p 0) #\/))
      p
      (string-append root "/" p)))

(define auth
  (make-auth cookie-name cookie-secret session-max-age secure-cookies?))

(define cfg
  (make-app-config http-host http-port
                   (abs-path static-dir)
                   (abs-path data-file)
                   (abs-path users-file)))

(serve cfg auth)

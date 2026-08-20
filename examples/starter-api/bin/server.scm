;; Usage: scm bin/server.scm [config-path]
;;
;; Reads config (config.scm, or the path given as argv, falling back to
;; config.example.scm) and starts the JSON API.

(import (scheme base)
        (scheme write)
        (scheme load)
        (scheme process-context)
        (scm module)
        (scm fs))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))
(module-search-path! (cons (string-append root "/src") (module-search-path)))

(import (app auth) (app api))

(define cfg-path
  (let ((args (cdr (command-line))))
    (cond ((pair? args) (car args))
          ((file-exists? (string-append root "/config.scm"))
           (string-append root "/config.scm"))
          (else (string-append root "/config.example.scm")))))

(load cfg-path)

(define (abs-path p)
  (if (and (> (string-length p) 0) (char=? (string-ref p 0) #\/))
      p (string-append root "/" p)))

(define auth (make-auth token-secret token-max-age))

(serve (make-api-config http-host http-port auth
                        (abs-path users-file)
                        (abs-path items-file)))

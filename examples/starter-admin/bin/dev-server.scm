;; Development supervisor: restarts bin/server.scm whenever a watched file
;; changes (all .sld under src/, bin/server.scm, the config, and migrations),
;; and auto-retries on a backoff if it exits on its own.
;;
;; Usage: scm bin/dev-server.scm

(import (scheme base)
        (scheme process-context)
        (scm fs)
        (scm reloader))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))

(define (watched)
  (append (files-with-suffix (string-append root "/src") ".sld")
          (files-with-suffix (string-append root "/migrations") ".sql")
          (list (string-append root "/bin/server.scm")
                (string-append root "/config.scm")
                (string-append root "/config.example.scm"))))

(supervise (list "scm" (string-append root "/bin/server.scm"))
           watched
           `((label . "starter-admin")
             (work-dir . ,root)
             (root . ,root)))

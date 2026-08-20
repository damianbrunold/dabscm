;; Development supervisor: runs main.scm and restarts it whenever a source
;; file changes (main.scm, config.scm, or anything under static/). Also
;; auto-retries on a backoff if the server exits on its own. In-flight
;; requests are dropped on restart, like Flask's reloader.
;;
;; Usage: scm bin/dev-server.scm

(import (scheme base)
        (scheme process-context)
        (scm fs)
        (scm reloader))

(define root
  (directory-name (directory-name (absolute-path (car (command-line))))))

(define (watched)
  (append (list (string-append root "/main.scm")
                (string-append root "/config.scm"))
          (files-with-suffix (string-append root "/static") "")))

(supervise (list "scm" (string-append root "/main.scm"))
           watched
           `((label . "starter-public")
             (work-dir . ,root)
             (root . ,root)))

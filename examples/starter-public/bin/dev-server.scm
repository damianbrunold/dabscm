;; Development supervisor: runs bin/server.scm and restarts it whenever a
;; source file changes (src/*.sld, bin/server.scm, config.scm). Also
;; auto-retries on a backoff if the server exits on its own. In-flight
;; requests are dropped on restart, like Flask's reloader.
;;
;; Static files and data/items.json need no restart: they are read from
;; disk on each request.
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
          (list (string-append root "/bin/server.scm")
                (string-append root "/config.scm"))))

(supervise (list "scm" (string-append root "/bin/server.scm"))
           watched
           `((label . "starter-public")
             (work-dir . ,root)
             (root . ,root)))

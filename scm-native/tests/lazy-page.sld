;; for tests/lazyimport.scm: reads the setting when it is initialized
(define-library (lazy page)
  (import (scheme base) (scheme write) (lazy prefix))
  (export page-url)
  (begin
    (display "init (lazy page)")
    (newline)
    (define page-url (string-append (current-prefix) "/page"))))

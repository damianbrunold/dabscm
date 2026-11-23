;; Libraries start at the import that brings them in, as on the JVM: code
;; before a later import (here: a setting) is seen by the libraries it
;; imports (platform/bin/server.scm sets the URL prefix before importing
;; the libraries that read it).
(import (scheme base) (scheme write))
(display "program starts")
(newline)
(import (lazy prefix))
(set-prefix! "/splg")
(import (lazy page))
(write page-url)
(newline)
(import (lazy prefix))
(write (current-prefix))
(newline)

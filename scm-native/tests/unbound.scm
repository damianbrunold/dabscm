;; Optional settings of a configuration: a reference to a global that was
;; never defined raises an error a guard can catch (the webapps read
;; optional config keys this way).
(import (scheme base) (scheme write))
(define prefix (guard (e (#t "default")) url-prefix))
(write prefix)
(newline)
(define defined-later 'set)
(write (guard (e (#t 'unset)) defined-later))
(newline)

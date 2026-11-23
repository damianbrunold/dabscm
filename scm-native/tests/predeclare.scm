;; A library's procedure definitions are visible in its whole body, also
;; where the name is imported and the use comes first (splg's test library
;; defines its own list->string this way).
(import (scheme base) (scheme write) (predeclare lib))
(write (show '(a b c)))
(newline)
(write (own-early))
(newline)
(write (list->string (list #\x #\y)))
(newline)

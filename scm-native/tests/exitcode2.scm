;; set-exit-code! takes precedence over the program's value
(import (scheme base) (scheme process-context) (scheme write))
(set-exit-code! 4)
(display "exiting with 4")
(newline)
3

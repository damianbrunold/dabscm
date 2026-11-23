;; A program's last value is its exit code when it is an integer, as for a
;; script on the JVM (run-grouper.scm returns 2, 3, 5, ... this way).
(import (scheme base) (scheme write))
(display "exiting with 3")
(newline)
(+ 1 2)

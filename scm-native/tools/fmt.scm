;; scm fmt as a native program: scm scm-native/scmc.scm scm-native/tools/fmt.scm -o fmt
(import (scheme base) (scheme process-context) (scm source format))
(exit (fmt-command (cdr (command-line))))

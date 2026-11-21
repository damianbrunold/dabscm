;; scm lint as a native program: scm scm-native/scmc.scm scm-native/tools/lint.scm -o lint
(import (scheme base) (scheme process-context) (scm source lint))
(exit (lint-command (cdr (command-line))))

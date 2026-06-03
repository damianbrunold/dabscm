## Overview

`(scheme process-context)` connects a program to its operating-system process: the
command-line arguments, environment variables, and process exit.

## Common uses

```scheme
(import (scheme base) (scheme process-context))

(command-line)                       ;; => ("script.scm" "arg1" "arg2")
(get-environment-variable "HOME")    ;; => "/home/you" (or #f)
(get-environment-variables)          ;; => (("HOME" . "...") ...)

(exit 0)        ;; exit cleanly with a status code
```

`emergency-exit` exits immediately without running outstanding cleanup (dynamic-wind
after-thunks).

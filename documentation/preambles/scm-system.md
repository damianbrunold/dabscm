## Overview

`(scm system)` is the interface to the operating system: running external
programs (and capturing their output), environment variables, process inspection
and control, simple option parsing, and parallel execution.

## Common uses

Run external commands:

```scheme
(import (scm system))

(run "ls" "-l")                           ;; run a program
(run-program/capture (list "echo" "hi"))  ;; run, capturing stdout
(sh "date" "+%Y")                         ;; => "2026\n"  (stdout as a string)
```

Environment and processes:

```scheme
(get-environment-variable "HOME")
(env-list)            ;; all environment variables
(ps)                  ;; process list
```

`run-parallel` maps a procedure over inputs using threads:

```scheme
(run-parallel (lambda (x) (* x x)) '(1 2 3 4))   ;; => (1 4 9 16)
```

`getopt` parses command-line option lists; see also the higher-level
`(scm args)`.

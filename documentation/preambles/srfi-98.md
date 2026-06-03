## Overview

SRFI-98 provides access to operating-system environment variables.

## Common uses

```scheme
(import (srfi 98))

(get-environment-variable "HOME")    ;; => "/home/you"  (or #f if unset)
(get-environment-variables)          ;; => (("HOME" . "/home/you") ...)
```

`get-environment-variable` returns a single value (or `#f`), and
`get-environment-variables` returns the whole environment as an alist.

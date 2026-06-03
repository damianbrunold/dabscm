## Overview

SRFI-28 provides basic format strings: `format` builds a string by substituting
values into a template with simple directives — `~a` (display), `~s` (write), `~%`
(newline), and `~~` (a literal tilde).

## Common uses

```scheme
(import (srfi 28))

(format "~a-~a" 1 2)              ;; => "1-2"
(format "Hello, ~a!~%" "world")  ;; => "Hello, world!\n"
(format "~s" "quoted")           ;; => "\"quoted\""
```

For more directives (numeric bases, padding, pretty-printing) see SRFI-48, whose
`format` is compatible and adds a destination argument.

## Overview

`(scm io)` adds I/O conveniences on top of the R7RS ports: string/bytevector
capture, `format`-style output, and a few port utilities. Its `format` is shared
with SRFI-28 and SRFI-48.

## Common uses

Capture output into a string or bytevector:

```scheme
(import (scm io))

(call-with-output-string
  (lambda (p) (display "hi " p) (display 42 p)))    ;; => "hi 42"

(call-with-output-bytevector
  (lambda (p) (write-bytevector #u8(1 2 3) p)))     ;; => #u8(1 2 3)
```

Formatted strings — the first argument is the destination (`#f` for a string, or
a port):

```scheme
(format #f "~a + ~a = ~a" 1 2 3)    ;; => "1 + 2 = 3"
```

`read-chars` reads a fixed number of characters, `with-input-from-string` rebinds
the current input port, and `port-position` / `flush` round things out.

## Overview

`(scheme file)` provides file-based ports: open files for input or output (textual
or binary), the `call-with-…` / `with-…` forms that manage a port's lifetime, and
file existence/deletion.

## Common uses

```scheme
(import (scheme base) (scheme file))

;; write a file
(call-with-output-file "greeting.txt"
  (lambda (p) (write-string "hello" p)))

;; read it back
(call-with-input-file "greeting.txt"
  (lambda (p) (read-line p)))        ;; => "hello"

(file-exists? "greeting.txt")        ;; => #t
(delete-file "greeting.txt")
```

`with-input-from-file` / `with-output-to-file` rebind the current ports for the
duration of a thunk; `open-binary-input-file` / `open-binary-output-file` open
byte streams.

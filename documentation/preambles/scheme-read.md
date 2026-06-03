## Overview

`(scheme read)` provides `read`, the datum reader: it parses one S-expression of
external representation from a textual input port into a Scheme value, returning
the eof object at end of input.

## Common uses

```scheme
(import (scheme base) (scheme read))

(read (open-input-string "(1 2 3)"))   ;; => (1 2 3)
(read (open-input-string "\"hi\""))    ;; => "hi"

;; read every datum from a port
(let loop ((p (open-input-string "1 2 3")) (acc '()))
  (let ((x (read p)))
    (if (eof-object? x) (reverse acc) (loop p (cons x acc)))))   ;; => (1 2 3)
```

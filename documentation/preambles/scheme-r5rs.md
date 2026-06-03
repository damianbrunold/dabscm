## Overview

`(scheme r5rs)` is the R5RS compatibility library: a single import that provides
the procedures and syntax of the older R5RS standard, for running legacy code with
minimal changes. It bundles the familiar arithmetic, list, character, string, and
control operations under one name.

## Common uses

```scheme
(import (scheme r5rs))

(map (lambda (x) (* x x)) '(1 2 3))     ;; => (1 4 9)
(assoc 'b '((a . 1) (b . 2)))           ;; => (b . 2)
(call-with-current-continuation
  (lambda (k) (+ 1 (k 41))))            ;; => 41
```

New code should prefer `(scheme base)` and the other R7RS libraries; reach for
`(scheme r5rs)` when porting existing R5RS programs.

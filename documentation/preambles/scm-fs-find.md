## Overview

`(scm fs-find)` provides higher-level filesystem traversal and reporting, modelled
on familiar Unix tools: `find-file`, `du`, `df`, `tree`, and `xargs`.

## Common uses

Find files matching criteria (name globs, type, or an arbitrary predicate):

```scheme
(import (scm fs-find))

(find-file "." '(name . "*.scm") '(type . file))
(find-file "/var/log" `(predicate . ,(lambda (p) (> (file-size p) 1024))))
```

Disk usage and free space:

```scheme
(du "/var/log")    ;; total size under a directory
(df "/")           ;; free space on a filesystem
```

`tree` renders a directory tree, and `xargs` applies a procedure across a list of
paths.

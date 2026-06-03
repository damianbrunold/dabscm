## Overview

`(scm glob)` provides filename globbing — matching paths against shell-style
wildcard patterns (`*`, `?`, character classes) and expanding a pattern against
the filesystem.

## Common uses

Test a name against a pattern:

```scheme
(import (scm glob))

(glob-match? "*.scm" "foo.scm")   ;; => #t
(glob-match? "*.scm" "foo.txt")   ;; => #f
```

Expand a pattern against the filesystem (results are sorted):

```scheme
(glob "src/*.scm")   ;; => ("src/bar.scm" "src/foo.scm")
```

## Overview

`(scm text)` is a toolbox of Unix-style text utilities — `grep`, `sed`, `awk`,
`cut`, `sort-lines`, `head`, `tail`, `uniq`, `wc`, `tr`, `diff`, `cat`, `tee`,
`hexdump`. Each takes a *source* that may be a filename string, a list of strings
(one per line), or an input port, so you can pipe data through them in Scheme.
Where a matching native tool is on PATH it may be used; pass `'pure` to force the
pure-Scheme path.

## Common uses

Working on a list of lines (no files needed):

```scheme
(import (scm text))

(grep "b" '("alpha" "beta" "bravo"))         ;; => ("beta" "bravo")
(sort-lines '("charlie" "alpha" "bravo"))    ;; => ("alpha" "bravo" "charlie")
(sed "a" "A" '("banana") 'pure)              ;; => ("bAnana")
```

Or against a file:

```scheme
(grep "ERROR" "log.txt" 'ignore-case 'line-number)
```

Options are trailing symbols (e.g. `'ignore-case`, `'invert-match`,
`'line-number`, `'count`) mirroring the familiar command-line flags.

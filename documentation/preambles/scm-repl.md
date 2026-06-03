## Overview

`(scm repl)` provides the support a REPL or editor integration needs:
identifier completion, syntax information, and a short info line for a binding. It
powers interactive features rather than being used in scripts.

## Common uses

```scheme
(import (scm repl))

(repl-completions "appen")   ;; => ("append")   completions for a prefix
(repl-info-line 'car)        ;; a one-line summary for a binding
(repl-core-form-names)       ;; the names of the core special forms
```

`repl-syntax-info` returns structured syntax details for a symbol.

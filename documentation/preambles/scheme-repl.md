## Overview

`(scheme repl)` provides `interaction-environment` — the mutable environment the
REPL evaluates in, suitable as the environment argument to `eval`.

## Common uses

```scheme
(import (scheme base) (scheme eval) (scheme repl))

(eval '(+ 1 2) (interaction-environment))   ;; => 3
```

Use it when you want `eval` to run in the same environment as the interactive
session (seeing its definitions) rather than a fresh one.

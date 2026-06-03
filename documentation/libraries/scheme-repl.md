# `(scheme repl)`

REPL environment access

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


## Exports

### `interaction-environment`

```
Syntax: (interaction-environment)
Library: (scheme repl)
Description: Returns the environment specifier for the interactive REPL
environment, which in this implementation is (user main). This environment
includes all standard bindings and is the namespace in which the REPL
evaluates expressions. The returned specifier can be passed to eval.
Example:
  (interaction-environment) => (user main)
  (eval '(+ 1 2) (interaction-environment)) => 3
```


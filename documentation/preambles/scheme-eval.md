## Overview

`(scheme eval)` evaluates data as code: `eval` runs an expression in a given
environment, and `environment` builds an environment from a set of import specs.

## Common uses

```scheme
(import (scheme base) (scheme eval))

(eval '(+ 1 2 3)
      (environment '(scheme base)))   ;; => 6
```

The environment argument controls which bindings the evaluated expression can see;
construct it from the libraries you want to expose.

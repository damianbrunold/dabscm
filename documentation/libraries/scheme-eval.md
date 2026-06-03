# `(scheme eval)`

Evaluation of Scheme expressions

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


## Exports

### `environment`

```
Syntax: (environment lib ...)
Library: (scheme eval)
Description: Returns an environment specifier suitable for use with eval. Each lib must be a library name. With no arguments, returns the scm core environment.
Example:
  (eval '(+ 1 2) (environment '(scheme base))) => 3
```

### `eval`

```
Syntax: (eval expr) (eval expr environment)
Library: (scheme eval)
Description: Evaluates expr in the given environment specifier. If no environment is given, evaluates in the scm core environment.
Example:
  (eval '(+ 1 2) (environment '(scheme base))) => 3
```


# `(scheme eval)`

Evaluation of Scheme expressions

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


# `(srfi 98)`

SRFI-98 — Environment variables

## Exports

### `get-environment-variable`

```
Syntax: (get-environment-variable name)
Library: (srfi 98)
Description: Returns the value of the named environment variable as a string,
or #f if the variable is not defined in the current environment. name must be
a string.
Example:
  (get-environment-variable "HOME") => "/home/user"
  (get-environment-variable "UNDEFINED_VAR") => #f
```

### `get-environment-variables`

```
Syntax: (get-environment-variables)
Library: (srfi 98)
Description: Returns an association list of all environment variables as
(name . value) pairs where both name and value are strings. The order of
the pairs is unspecified.
Example:
  (list? (get-environment-variables)) => #t
  (assoc "HOME" (get-environment-variables)) => ("HOME" . "/home/user")
```


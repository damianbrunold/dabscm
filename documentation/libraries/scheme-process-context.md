# `(scheme process-context)`

Process exit and context

## Overview

`(scheme process-context)` connects a program to its operating-system process: the
command-line arguments, environment variables, and process exit.

## Common uses

```scheme
(import (scheme base) (scheme process-context))

(command-line)                       ;; => ("script.scm" "arg1" "arg2")
(get-environment-variable "HOME")    ;; => "/home/you" (or #f)
(get-environment-variables)          ;; => (("HOME" . "...") ...)

(exit 0)        ;; exit cleanly with a status code
```

`emergency-exit` exits immediately without running outstanding cleanup (dynamic-wind
after-thunks).


## Exports

### `command-line`

```
Syntax: (command-line)
Library: (scheme process-context)
Description: Returns the command line passed to the process as a list of strings. The first element is typically the program name.
Example:
  (command-line) => ("prog" "arg1" "arg2")
```

### `emergency-exit`

```
Syntax: (exit) (exit obj)
Library: (scheme process-context)
Description: Terminates the current program. If obj is an exact integer, it is used as the exit code. Without an argument, exits with code 1.
Example:
  (exit)
  (exit 0)
```

### `exit`

```
Syntax: (exit) (exit obj)
Library: (scheme process-context)
Description: Terminates the current program. If obj is an exact integer, it is used as the exit code. Without an argument, exits with code 1.
Example:
  (exit)
  (exit 0)
```

### `get-environment-variable`

```
Syntax: (get-environment-variable name)
Library: (scm system) (scheme process-context) (srfi 98)
Description: Returns the value of the environment variable named name as a string, or #f if it is not set.
Example:
  (get-environment-variable "HOME") => "/home/user"
  (get-environment-variable "UNDEFINED_VAR") => #f
```

### `get-environment-variables`

```
Syntax: (get-environment-variables)
Library: (scheme process-context)
Description: Returns an association list of all environment variables as (name . value) pairs, where both are strings.
Example:
  (assoc "HOME" (get-environment-variables)) => ("HOME" . "/home/user")
```

### `set-exit-code!`

```
Syntax: (set-exit-code! code)
Library: (scheme process-context)
Description: Records the exit code the process should return when the
  current script finishes, without terminating immediately (unlike exit).
  The standalone script runner honours this after the script completes.
  code must be an exact integer. Returns an unspecified value.
Example:
  (set-exit-code! 1)
```


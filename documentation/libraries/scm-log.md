# `(scm log)`

Structured single-line logging

## Overview

`(scm log)` is structured single-line logging. Each entry is one line of the form
`YYYY-MM-DD HH:MM:SS LEVEL [module] message`, written to the port returned by the
`log-port` parameter (the current error port by default).

## Common uses

```scheme
(import (scm log))

(log-info  "auth"  "login ok for user 42")
(log-warn  "feeds" "fetch timed out, will retry")
(log-error "db"    "connection refused")
```

The first argument is a short module/category tag, the second the message.
`log-access` writes access-log style entries. Redirect output by parameterizing
`log-port` — handy for tests or for sending logs to a file:

```scheme
(parameterize ((log-port (current-output-port)))
  (log-info "demo" "hello"))
```


## Exports

### `log-access`

```
Syntax: (log-access method url status duration-ms)
Library: (scm log)
Description: Writes a single access log line: an INFO line in the http
  module of the form 'METHOD URL -> STATUS (Nms)'. status and duration-ms
  are integers.
Example:
  (log-access "GET" "/notes/42" 200 14)
```

### `log-error`

```
Syntax: (log-error module msg)
Library: (scm log)
Description: Writes a single ERROR-level log line tagged with module.
Example:
  (log-error "db" "connection refused")
```

### `log-info`

```
Syntax: (log-info module msg)
Library: (scm log)
Description: Writes a single INFO-level log line tagged with module to
  (log-port). module and msg are strings.
Example:
  (log-info "auth" "login ok for user 42")
```

### `log-port`

*(no documentation)*

### `log-warn`

```
Syntax: (log-warn module msg)
Library: (scm log)
Description: Writes a single WARN-level log line tagged with module.
Example:
  (log-warn "feeds" "fetch timed out, will retry")
```


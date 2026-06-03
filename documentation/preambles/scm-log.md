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

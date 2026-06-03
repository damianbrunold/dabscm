## Overview

`(scm database sqlserver)` is a Microsoft SQL Server client. Its API mirrors
`(scm database postgres)` with an `ss-` prefix: connect, run queries and
statements, read results as rows or alists, and stream large results with
cursors.

## Common uses

```scheme
(import (scm database sqlserver))

(with-ss-connection "localhost" 1433 "user" "pass" "db"
  (lambda (conn)
    (define res (ss-query conn "SELECT id, name FROM users"))
    (ss-result->alist-list res)))
```

`ss-exec` runs non-row statements; `ss-result-columns` / `ss-result-rows` read a
result directly; and `ss-cursor-open` / `ss-cursor-fetch` / `ss-cursor-for-each`
iterate large result sets.

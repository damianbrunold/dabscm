## Overview

`(scm database postgres)` is a PostgreSQL client: connect, run queries and
statements (with parameter binding), read results as rows or alists, and stream
large results with server-side cursors. The `with-…` forms manage connection and
query lifetimes.

## Common uses

```scheme
(import (scm database postgres))

(with-pg-connection "localhost" 5432 "user" "pass" "db"
  (lambda (conn)
    ;; parameterized query — $1, $2, ... placeholders
    (define res (pg-query conn "SELECT id, name FROM users WHERE id = $1" 42))
    (pg-result->alist-list res)))   ;; => ((("id" . 42) ("name" . "Ada")))
```

`pg-exec` runs statements that don't return rows; `pg-result-columns` /
`pg-result-rows` access a result directly; and `pg-cursor-open` /
`pg-cursor-fetch` / `pg-cursor-for-each` iterate large result sets without loading
them all at once. See `(scm database migrations)` to apply schema migrations.

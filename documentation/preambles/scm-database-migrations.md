## Overview

`(scm database migrations)` is a forward-only SQL migration runner. It applies the
`.sql` files in a directory in lexical order (conventionally `NNNN_name.sql`),
records each applied file in a tracking table so it never runs twice, and wraps
each migration in its own transaction. It is database-agnostic: you supply two
callbacks that talk to your actual connection, so it works with PostgreSQL, SQL
Server, SQLite, or an in-memory test database.

## Common uses

```scheme
(import (scm database migrations) (scm database postgres))

(with-pg-connection "localhost" 5432 "user" "pass" "db"
  (lambda (conn)
    (run-migrations!
      (lambda (sql) (pg-exec conn sql))                 ;; exec-sql!
      (lambda (sql) (pg-result-rows (pg-query conn sql))) ;; query-rows
      "db/migrations")))
```

`migrations-applied` and `migrations-pending` report which migrations have run and
which are outstanding. Options (an alist) let you customize the tracking table
name and its `CREATE TABLE` statement.

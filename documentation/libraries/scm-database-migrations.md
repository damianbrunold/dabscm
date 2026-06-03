# `(scm database migrations)`

Forward-only SQL migration runner

## Exports

### `migrations-applied`

```
Syntax: (migrations-applied exec-sql! query-rows [options])
Library: (scm database migrations)
Description: Returns the list of filenames already recorded as applied in the
  tracking table, in their insertion order from the database. The tracking
  table is created if it does not already exist. exec-sql! is a procedure
  that runs one SQL statement; query-rows is a procedure that runs one
  query and returns a list of row vectors. options is an optional alist
  with keys 'table-name and 'create-table-sql (see run-migrations!).
Example:
  (migrations-applied
    (lambda (sql) (pg-exec conn sql))
    (lambda (sql) (pg-result-rows (pg-query conn sql))))
  => ("0001_init.sql" "0002_users.sql")
```

### `migrations-pending`

```
Syntax: (migrations-pending exec-sql! query-rows dir [options])
Library: (scm database migrations)
Description: Returns the list of .sql filenames in dir (lexical order) that
  have not yet been applied. Use this to preview what run-migrations!
  would do. See run-migrations! for the options alist.
Example:
  (migrations-pending exec-sql! query-rows "./migrations")
  => ("0003_add_index.sql")
```

### `run-migrations!`

```
Syntax: (run-migrations! exec-sql! query-rows dir [options])
Library: (scm database migrations)
Description: Applies pending .sql migrations from dir in lexical order.
  Each migration runs inside its own transaction (BEGIN / COMMIT /
  ROLLBACK on failure). The tracking table is created if it does not
  exist. Idempotent: already-applied files are skipped silently.
  options is an alist with keys:
    'table-name        — tracking table name (default "schema_migrations")
    'create-table-sql  — full CREATE TABLE statement for the tracking
                         table (override for non-PostgreSQL databases)
    'log-proc          — (lambda (msg) ...) called once per applied file
                         and once at end of run. Default: no logging.
Example:
  (run-migrations!
    (lambda (sql) (pg-exec conn sql))
    (lambda (sql) (pg-result-rows (pg-query conn sql)))
    "./migrations"
    '((log-proc ,(lambda (m) (display m) (newline)))))
```


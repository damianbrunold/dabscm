# `(scm database postgres)`

PostgreSQL database connectivity

## Exports

### `make-pg-pool`

```
Syntax: (make-pg-pool host port user password database capacity)
Library: (scm database postgres)
Description: Creates an empty pg connection pool. Connections are created
  lazily on first checkout, up to capacity. Use with-pg-pool-connection
  to borrow a connection, and pg-pool-close-all! to tear it down.
Example:
  (define pool (make-pg-pool "localhost" 5432 "u" "p" "db" 8))
```

### `pg-close`

```
Syntax: (pg-close conn)
Library: (scm database postgres)
Description: Closes the TCP connection to the PostgreSQL server.
Example:
  (pg-close conn)
```

### `pg-connect`

```
Syntax: (pg-connect host port user password database)
Library: (scm database postgres)
Description: Opens a TCP connection to a PostgreSQL server and performs authentication.
  Supports trust, MD5, and SCRAM-SHA-256 authentication. Returns a connection object.
Example:
  (define conn (pg-connect "localhost" 5432 "alice" "secret" "mydb"))
```

### `pg-cursor-close`

```
Syntax: (pg-cursor-close cursor)
Library: (scm database postgres)
Description: Closes the cursor and commits the transaction. Returns #t. Safe to call
  multiple times; subsequent calls are no-ops.
Example:
  (pg-cursor-close cur)
```

### `pg-cursor-columns`

```
Syntax: (pg-cursor-columns cursor)
Library: (scm database postgres)
Description: Returns the column name vector for the cursor, or #f before the first fetch.
Example:
  (pg-cursor-columns cur) => #("id" "name")
```

### `pg-cursor-fetch`

```
Syntax: (pg-cursor-fetch cursor [n])
Library: (scm database postgres)
Description: Fetches up to n rows from cursor (default 1). Returns a list of row vectors.
  Returns an empty list when the cursor is exhausted.
Example:
  (pg-cursor-fetch cur 100)
```

### `pg-cursor-for-each`

```
Syntax: (pg-cursor-for-each cursor proc [batch-size])
Library: (scm database postgres)
Description: Calls proc on each row vector from cursor in batches (default 100).
  Automatically closes the cursor when all rows are consumed.
Example:
  (pg-cursor-for-each cur (lambda (row) (display (vector-ref row 0))) 50)
```

### `pg-cursor-open`

```
Syntax: (pg-cursor-open conn sql)
Library: (scm database postgres)
Description: Opens a server-side cursor for the given SQL query. Returns a cursor object.
  The query runs inside a transaction; call pg-cursor-close when done.
Example:
  (define cur (pg-cursor-open conn "SELECT id, name FROM users ORDER BY id"))
```

### `pg-exec`

```
Syntax: (pg-exec conn sql [param ...])
Library: (scm database postgres)
Description: Executes a SQL statement and discards the result. Suitable
  for DDL and DML statements such as CREATE TABLE, INSERT, UPDATE, and
  DELETE.

  If params are supplied, the sql string is a template with $1, $2, ...
  placeholders substituted via pg-format-sql.
Example:
  (pg-exec conn "INSERT INTO users (name) VALUES ('alice')")
  (pg-exec conn "INSERT INTO users (name, age) VALUES ($1, $2)"
           "Ada" 36)
```

### `pg-format-sql`

```
Syntax: (pg-format-sql sql params)
Library: (scm database postgres)
Description: Returns sql with $1, $2, ... placeholders substituted by
  the corresponding (1-indexed) values from the params list, each
  converted to a properly-escaped SQL literal. Substitution is skipped
  inside string literals, quoted identifiers, comments, and dollar-
  quoted strings. Raises on $0, $N out of range, or a param of an
  unsupported type.
Example:
  (pg-format-sql "WHERE slug = $1 AND age > $2" '("a'b" 18))
  => "WHERE slug = 'a''b' AND age > 18"
```

### `pg-pool-checkin`

```
Syntax: (pg-pool-checkin pool conn ok?)
Library: (scm database postgres)
Description: Returns conn to the pool. If ok? is #t, the connection
  goes back on the idle list. If #f, the connection is closed and
  discarded — use this when an exception suggests the connection is
  in an unknown state. Prefer with-pg-pool-connection.
```

### `pg-pool-checkout`

```
Syntax: (pg-pool-checkout pool)
Library: (scm database postgres)
Description: Borrows a connection from the pool. If an idle connection
  is available, returns it immediately. Otherwise, opens a new one (up
  to capacity), or waits on the pool's condition variable until a
  checkin frees one up. Prefer with-pg-pool-connection — it handles
  the matching checkin under exceptions.
```

### `pg-pool-close-all!`

```
Syntax: (pg-pool-close-all! pool)
Library: (scm database postgres)
Description: Marks the pool as shut down and closes every idle
  connection. Connections currently checked out will be closed when
  they are checked back in. Subsequent checkouts raise.
```

### `pg-pool?`

*(no documentation)*

### `pg-query`

```
Syntax: (pg-query conn sql [param ...])
Library: (scm database postgres)
Description: Executes a SQL query and returns a result object containing
  column names and rows. Use pg-result-columns and pg-result-rows to
  access the result.

  If params are supplied, the sql string is treated as a template with
  $1, $2, ... placeholders that are substituted with the corresponding
  param values. See pg-format-sql for the conversion rules. With no
  params, sql is sent verbatim.
Example:
  (pg-query conn "SELECT * FROM users")
  (pg-query conn "SELECT * FROM users WHERE id = $1" 42)
  (pg-query conn "SELECT * FROM users WHERE name = $1 AND age > $2"
            "Ada" 30)
```

### `pg-quote-int`

```
Syntax: (pg-quote-int n)
Library: (scm database postgres)
Description: Returns the decimal representation of an integer n, validated as
  integer. Accepts an integer or a numeric string. Raises an error for any
  other input, preventing callers from accidentally splicing arbitrary text
  through what was intended to be a numeric parameter.
Example:
  (pg-quote-int 42)   => "42"
  (pg-quote-int "42") => "42"
  (pg-quote-int "x") raises an error
```

### `pg-quote-literal`

```
Syntax: (pg-quote-literal s)
Library: (scm database postgres)
Description: Returns s wrapped in single quotes with internal single quotes doubled — the SQL standard string-literal escape, safe under PostgreSQL's default standard_conforming_strings=on (backslashes stay literal). Use for any user-controlled string interpolated into SQL.
Example:
  (pg-quote-literal "O'Brien") => "'O''Brien'"
```

### `pg-result->alist-list`

```
Syntax: (pg-result->alist-list result)
Library: (scm database postgres)
Description: Converts a query result to a list of association lists, one per row.
  Each alist maps column name strings to value strings (or #f for NULL).
Example:
  (pg-result->alist-list result) => (("id" . "1") ("name" . "alice")) ...)
```

### `pg-result-columns`

```
Syntax: (pg-result-columns result)
Library: (scm database postgres)
Description: Returns the column name vector from a query result.
Example:
  (pg-result-columns result) => #("id" "name")
```

### `pg-result-rows`

```
Syntax: (pg-result-rows result)
Library: (scm database postgres)
Description: Returns the list of row vectors from a query result. Each row is a vector of
  string values, or #f for NULL values.
Example:
  (pg-result-rows result) => (#("1" "alice") #("2" "bob"))
```

### `with-pg-connection`

```
Syntax: (with-pg-connection host port user password database proc)
Library: (scm database postgres)
Description: Opens a connection, calls (proc conn), and closes the connection on exit,
  even if an exception is raised.
Example:
  (with-pg-connection "localhost" 5432 "user" "pass" "db"
    (lambda (conn) (display (pg-result->alist-list (pg-query conn "SELECT 1")))))
```

### `with-pg-pool-connection`

```
Syntax: (with-pg-pool-connection pool proc)
Library: (scm database postgres)
Description: Checks out a connection, calls (proc conn), and checks
  it back in. On normal return, the connection is returned to the
  idle list. On exception, the connection is closed (not pooled) and
  the exception is re-raised — assumes the connection's state is
  suspect.
Example:
  (with-pg-pool-connection pool
    (lambda (c) (pg-result-rows (pg-query c "SELECT 1"))))
```

### `with-pg-query`

```
Syntax: (with-pg-query host port user password database sql proc)
Library: (scm database postgres)
Description: Opens a connection and cursor, calls (proc conn cursor), and closes both
  on exit, even if an exception is raised.
Example:
  (with-pg-query "localhost" 5432 "user" "pass" "db" "SELECT * FROM t"
    (lambda (conn cursor) (pg-cursor-for-each cursor display)))
```


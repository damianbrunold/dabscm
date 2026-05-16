# `(scm database sqlserver)`

SQL Server database connectivity

## Exports

### `ss-close`

```
Syntax: (ss-close conn)
Library: (scm database sqlserver)
Description: Closes the TCP connection to the SQL Server.
Example:
  (ss-close conn)
```

### `ss-connect`

```
Syntax: (ss-connect host port user password database)
Library: (scm database sqlserver)
Description: Opens a TDS connection to SQL Server, performs TLS negotiation (via tds-connect),
  and completes Login7 SQL Server authentication. Returns a connection vector #(in out sock).
Example:
  (define conn (ss-connect "localhost" 1433 "sa" "Password123!" "master"))
```

### `ss-cursor-close`

```
Syntax: (ss-cursor-close cursor)
Library: (scm database sqlserver)
Description: Closes the cursor, deallocates it, and commits the transaction. Returns #t.
  Safe to call multiple times; subsequent calls are no-ops.
Example:
  (ss-cursor-close cur)
```

### `ss-cursor-columns`

```
Syntax: (ss-cursor-columns cursor)
Library: (scm database sqlserver)
Description: Returns the column name vector for the cursor, or #f before the first fetch.
Example:
  (ss-cursor-columns cur) => #("id" "name")
```

### `ss-cursor-fetch`

```
Syntax: (ss-cursor-fetch cursor [n])
Library: (scm database sqlserver)
Description: Fetches up to n rows from the cursor (default 1). Returns a list of row vectors.
  Returns an empty list when the cursor is exhausted.
Example:
  (ss-cursor-fetch cur 100)
```

### `ss-cursor-for-each`

```
Syntax: (ss-cursor-for-each cursor proc [batch-size])
Library: (scm database sqlserver)
Description: Calls proc on each row vector from the cursor in batches (default 100).
  Automatically closes the cursor when all rows are consumed.
Example:
  (ss-cursor-for-each cur (lambda (row) (display (vector-ref row 0))) 50)
```

### `ss-cursor-open`

```
Syntax: (ss-cursor-open conn sql)
Library: (scm database sqlserver)
Description: Opens a server-side cursor for the given SQL query using DECLARE CURSOR
  inside a transaction. Returns a cursor object. Call ss-cursor-close when done.
Example:
  (define cur (ss-cursor-open conn "SELECT id, name FROM users ORDER BY id"))
```

### `ss-exec`

```
Syntax: (ss-exec conn sql)
Library: (scm database sqlserver)
Description: Executes a SQL statement and discards the result. Suitable for DDL and DML.
Example:
  (ss-exec conn "CREATE TABLE #t (id INT, name NVARCHAR(50))")
```

### `ss-query`

```
Syntax: (ss-query conn sql)
Library: (scm database sqlserver)
Description: Executes a SQL query and returns a result object #(cols rows). Use
  ss-result-columns and ss-result-rows to access the result.
Example:
  (define result (ss-query conn "SELECT id, name FROM users"))
```

### `ss-result->alist-list`

```
Syntax: (ss-result->alist-list result)
Library: (scm database sqlserver)
Description: Converts a query result to a list of association lists, one per row.
  Each alist maps column name strings to value strings (or #f for NULL).
Example:
  (ss-result->alist-list result) => (("id" . "1") ("name" . "alice")) ...)
```

### `ss-result-columns`

```
Syntax: (ss-result-columns result)
Library: (scm database sqlserver)
Description: Returns the column name vector from a query result.
Example:
  (ss-result-columns result) => #("id" "name")
```

### `ss-result-rows`

```
Syntax: (ss-result-rows result)
Library: (scm database sqlserver)
Description: Returns the list of row vectors from a query result. Each row is a vector of
  string values, or #f for NULL values.
Example:
  (ss-result-rows result) => (#("1" "alice") #("2" "bob"))
```

### `with-ss-connection`

```
Syntax: (with-ss-connection host port user password database proc)
Library: (scm database sqlserver)
Description: Opens a SQL Server connection, calls (proc conn), and closes the connection
  on exit even if an exception is raised.
Example:
  (with-ss-connection "localhost" 1433 "sa" "pass" "master"
    (lambda (conn) (ss-result->alist-list (ss-query conn "SELECT 1 AS n"))))
```

### `with-ss-query`

```
Syntax: (with-ss-query host port user password database sql proc)
Library: (scm database sqlserver)
Description: Opens a connection and cursor, calls (proc conn cursor), and closes both
  on exit even if an exception is raised.
Example:
  (with-ss-query "localhost" 1433 "sa" "pass" "master" "SELECT * FROM t"
    (lambda (conn cursor) (ss-cursor-for-each cursor display)))
```


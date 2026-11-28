---
title: "(scm database postgres), sqlserver and migrations: SQL databases"
part: libraries
order: 1030
libraries: (scm database postgres) (scm database sqlserver) (scm database migrations)
summary: Connecting to PostgreSQL, queries with parameters and how they are quoted, rows as vectors or alists, statements, transactions, connection pools for servers, cursors for large results, SQL Server with the same API, schema migrations (tested against an in-memory stand-in).
---
# (scm database postgres), sqlserver and migrations: SQL databases

| library | does |
|---|---|
| `(scm database postgres)` | PostgreSQL client, `pg-` procedures |
| `(scm database sqlserver)` | Microsoft SQL Server client, the same API with `ss-` |
| `(scm database migrations)` | applies `.sql` schema changes in order, once each |

Both clients are written in Scheme over plain sockets, so they need no
driver installed. Most examples need a running database and are shown
only; the parts that work without one (building SQL, migrations) are
tested.

```scheme
(import (scheme base) (scheme file) (scheme write) (only (srfi 13) string-prefix? string-index)
        (scm fs) (scm database postgres) (scm database sqlserver) (scm database migrations))
```

## Connecting and querying

```scheme no-test
(define conn (pg-connect "localhost" 5432 "teashop" "secret" "teashop"))

(define res (pg-query conn "SELECT id, name, kg FROM teas ORDER BY name"))
(pg-result-columns res)          ; => ("id" "name" "kg")
(pg-result-rows res)             ; => (#(3 "Assam" 12) #(1 "Sencha" 40))
(pg-result->alist-list res)      ; => ((("id" . 3) ("name" . "Assam") ("kg" . 12)) ...)

(pg-close conn)
```

- Rows are vectors in column order, or alists keyed by column name.
- Values come back as Scheme values: integers, strings, `#t`/`#f`, and
  the symbol `null` for SQL NULL.
- `with-pg-connection` closes the connection however the procedure ends.
- Passwords are checked with SCRAM-SHA-256 (the PostgreSQL default), MD5,
  or trust.

## Parameters

Values go into a query as `$1`, `$2` … placeholders, never by pasting
strings together:

```scheme no-test
(pg-query conn "SELECT * FROM teas WHERE origin = $1 AND kg >= $2" "Japan" 10)
(pg-exec conn "INSERT INTO teas (name, origin, kg) VALUES ($1, $2, $3)" "Gyokuro" "Japan" 5)
```

The client turns each value into a correctly quoted SQL literal.
`pg-format-sql` shows the SQL that is sent:

```scheme
(pg-format-sql "SELECT * FROM teas WHERE name = $1 AND kg > $2 AND organic = $3"
               '("Lu'an Melon Seed" 2.5 #t))
;; => "SELECT * FROM teas WHERE name = 'Lu''an Melon Seed' AND kg > 2.5 AND organic = TRUE"

(pg-format-sql "INSERT INTO photos VALUES ($1, $2, $3)" (list 'null #f (bytevector 1 2)))
;; => "INSERT INTO photos VALUES (NULL, FALSE, '\\x0102'::bytea)"

(pg-format-sql "SELECT * FROM teas WHERE id IN $1" '((3 5 8)))
;; => "SELECT * FROM teas WHERE id IN (3, 5, 8)"
```

The quote in "Lu'an" is doubled, so a name can never end the string and
start a command of its own (SQL injection). A list becomes a
parenthesised list, for `IN`. Placeholders inside strings and comments
are left alone, and a missing parameter is an error:

```scheme
(pg-format-sql "SELECT '$1 each', $1 -- $2 not used" '(4))
;; => "SELECT '$1 each', 4 -- $2 not used"
(pg-format-sql "SELECT $2" '(7))           ;; => error
(pg-quote-literal "O'Brien")                ;; => "'O''Brien'"
(pg-quote-int "42; DROP TABLE teas")        ;; => error
```

`pg-quote-literal` and `pg-quote-int` are for the rare SQL that has to be
built by hand.

## Transactions

`with-pg-transaction` runs a procedure between `BEGIN` and `COMMIT`; if it
raises, the transaction is rolled back and the error raised again, so
either all statements take effect or none:

```scheme no-test
(define (sell! conn tea kg)
  (with-pg-transaction conn
    (lambda (c)
      (let ((left (vector-ref (car (pg-result-rows (pg-query c "SELECT kg FROM teas WHERE name = $1 FOR UPDATE" tea))) 0)))
        (when (< left kg) (error "not enough in stock" tea left))
        (pg-exec c "UPDATE teas SET kg = kg - $1 WHERE name = $2" kg tea)
        (pg-exec c "INSERT INTO sales (tea, kg) VALUES ($1, $2)" tea kg)))))
```

## Servers: a connection pool

Opening a connection takes a network round trip or several, and the login.
A web server keeps a few open in a pool and lends them to requests:

```scheme no-test
(define pool (make-pg-pool "localhost" 5432 "teashop" (get-environment-variable "PGPASSWORD") "teashop" 8))

(define (teas-from origin)
  (with-pg-pool-connection pool
    (lambda (c)
      (pg-result->alist-list (pg-query c "SELECT name, kg FROM teas WHERE origin = $1" origin)))))

;; at shutdown
(pg-pool-close-all! pool)
```

At most 8 connections are opened, on demand. A connection whose procedure
raised is closed instead of returned, as its state is unknown.

## Large results: cursors

`pg-query` reads the whole result into memory. A cursor fetches it in
batches, for exports and reports over millions of rows:

```scheme no-test
(with-pg-transaction conn
  (lambda (c)
    (let ((cur (pg-cursor-open c "SELECT * FROM sales WHERE sold_at >= $1" "2025-01-01")))
      (pg-cursor-for-each cur (lambda (row) (write-csv-row row)) 1000))))
```

(PostgreSQL cursors live inside a transaction.)

## SQL Server

`(scm database sqlserver)` has the same procedures with `ss-` instead of
`pg-`. The port may be a named instance, looked up through the SQL Server
Browser; the connection is encrypted with TLS by default:

```scheme no-test
(define conn (ss-connect "dbhost" "SQLEXPRESS" "report" "secret" "Sales"))
(ss-result->alist-list (ss-query conn "SELECT TOP 10 name, kg FROM dbo.teas WHERE origin = $1" "Japan"))
(ss-close conn)
```

T-SQL literals are written differently: strings get an `N` prefix
(Unicode), booleans are bits:

```scheme
(ss-format-sql "SELECT * FROM teas WHERE name = $1 AND organic = $2" '("Lu'an" #t))
;; => "SELECT * FROM teas WHERE name = N'Lu''an' AND organic = 1"
(ss-sql-literal "Grüße")                    ;; => "N'Grüße'"
```

## Migrations

A database schema changes as the program does. The usual way to keep
every copy (development, test, production) in step is a directory of
numbered SQL files, applied in order, each exactly once:

```scheme
(define migrations (mktempdir '(prefix . "migrations")))
(define (migration! name sql)
  (call-with-output-file (join-path migrations name) (lambda (p) (write-string sql p))))

(migration! "0001_teas.sql" "CREATE TABLE teas (id serial PRIMARY KEY, name text NOT NULL, kg int NOT NULL);")
(migration! "0002_origin.sql" "ALTER TABLE teas ADD COLUMN origin text;")
```

`run-migrations!` takes two procedures, one that runs a statement and one
that runs a query and returns its rows as vectors, so it works with any
database. With PostgreSQL:

```scheme no-test
(run-migrations! (lambda (sql) (pg-exec conn sql))
                 (lambda (sql) (pg-result-rows (pg-query conn sql)))
                 "db/migrations")
```

To see what it does, here is a stand-in that only records the statements
and remembers the bookkeeping table `schema_migrations`:

```scheme
(define executed '())                       ; every statement, newest first
(define applied '())                        ; what schema_migrations holds

(define (between-quotes s)
  (let* ((i (string-index s #\')) (j (string-index s #\' (+ i 1))))
    (substring s (+ i 1) j)))

(define (fake-exec! sql)
  (set! executed (cons sql executed))
  (when (string-prefix? "INSERT INTO schema_migrations" sql)
    (set! applied (append applied (list (between-quotes sql))))))

(define (fake-rows sql)
  (if (string-prefix? "SELECT filename FROM schema_migrations" sql)
      (map vector applied)
      '()))

(migrations-pending fake-exec! fake-rows migrations) ;; => ("0001_teas.sql" "0002_origin.sql")

(define messages '())
(run-migrations! fake-exec! fake-rows migrations `((log-proc . ,(lambda (m) (set! messages (cons m messages))))))
applied                                     ;; => ("0001_teas.sql" "0002_origin.sql")
(migrations-pending fake-exec! fake-rows migrations) ;; => ()
(reverse messages)                          ;; => ("applying 0001_teas.sql" "applying 0002_origin.sql" "migrations complete")
```

Each file ran in a transaction of its own, together with the line that
records it:

```scheme
(define (statements) (reverse executed))
(define (only-main sql) (not (string-prefix? "CREATE TABLE IF NOT EXISTS schema_migrations" sql)))
(let loop ((ss (statements)) (acc '()))
  (cond ((null? ss) (reverse acc))
        ((only-main (car ss)) (loop (cdr ss) (cons (car ss) acc)))
        (else (loop (cdr ss) acc))))
;; => ("BEGIN" "CREATE TABLE teas (id serial PRIMARY KEY, name text NOT NULL, kg int NOT NULL);" "INSERT INTO schema_migrations (filename) VALUES ('0001_teas.sql')" "COMMIT" "BEGIN" "ALTER TABLE teas ADD COLUMN origin text;" "INSERT INTO schema_migrations (filename) VALUES ('0002_origin.sql')" "COMMIT")
```

Running again does nothing; a new file is applied on the next run:

```scheme
(run-migrations! fake-exec! fake-rows migrations)
(length applied)                            ;; => 2
(migration! "0003_stock_index.sql" "CREATE INDEX teas_name ON teas (name);")
(run-migrations! fake-exec! fake-rows migrations)
applied                                     ;; => ("0001_teas.sql" "0002_origin.sql" "0003_stock_index.sql")
(rm migrations 'recursive)
```

- Never edit a migration that has run anywhere: add a new one.
- Name files with a fixed-width number, so that their order as strings
  is their order as numbers (`0010` after `0009`).
- A failing migration is rolled back and stops the run, so the schema is
  never half-changed (PostgreSQL rolls back DDL too; some databases
  don't).
- Run the migrations when the program starts, before it serves requests.

## Where next

- [Web applications](scm-web-app.md) and the `starter-admin` and
  `starter-api` starters of [scaffold](scm-scaffold.md), which come with a
  database, a pool and migrations.
- `(scm data)` data frames for analysing query results.
- Reference: `(scm database postgres)`, `(scm database sqlserver)`,
  `(scm database migrations)`.

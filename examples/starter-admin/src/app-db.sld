;; (app db) — database access: a pooled connection plus thin query helpers
;; and the migration runner. Every query is parameterized ($1, $2, ...);
;; values are never spliced into SQL strings, so there is no injection
;; surface. Higher layers call db-rows / db-exec and never touch the driver.

(define-library (app db)
  (import (scheme base)
          (scheme write)
          (scm database postgres)
          (rename (scm database migrations)
                  (run-migrations! pg-migrations-run!)))
  (export make-db with-db db-rows db-row db-exec db-scalar migrate!)
  (begin

    (define-record-type db
      (db* pool)
      db?
      (pool db-pool))

    (define (make-db host port user password database . opt)
      "Syntax: (make-db host port user password database [pool-capacity])
Library: (app db)
Description: Creates a pooled database handle. Pass it to the query helpers."
      (db* (make-pg-pool host port user password database
                         (if (pair? opt) (car opt) 8))))

    (define (with-db cfg proc)
      "Syntax: (with-db cfg proc)
Library: (app db)
Description: Borrows a pooled connection, calls (proc conn), and returns it
  to the pool afterwards (even on error)."
      (with-pg-pool-connection (db-pool cfg) proc))

    (define (db-rows cfg sql . params)
      "Syntax: (db-rows cfg sql [param ...])
Library: (app db)
Description: Runs a parameterized query and returns the rows as a list of
  alists keyed by column name (cdr/assoc to read a column)."
      (with-db cfg
        (lambda (c) (pg-result->alist-list (apply pg-query c sql params)))))

    (define (db-row cfg sql . params)
      "Syntax: (db-row cfg sql [param ...])
Library: (app db)
Description: Like db-rows but returns the first row alist, or #f if none."
      (let ((rows (apply db-rows cfg sql params)))
        (and (pair? rows) (car rows))))

    (define (db-scalar cfg sql . params)
      "Syntax: (db-scalar cfg sql [param ...])
Library: (app db)
Description: Returns the first column of the first row (e.g. a count or a
  RETURNING id), or #f if the query produced no rows."
      (let ((row (apply db-row cfg sql params)))
        (and row (cdr (car row)))))

    (define (db-exec cfg sql . params)
      "Syntax: (db-exec cfg sql [param ...])
Library: (app db)
Description: Runs a parameterized statement (INSERT/UPDATE/DELETE/DDL) and
  discards the result."
      (with-db cfg (lambda (c) (apply pg-exec c sql params))))

    (define (migrate! cfg dir)
      "Syntax: (migrate! cfg dir)
Library: (app db)
Description: Applies pending .sql migrations from dir in lexical order,
  each in its own transaction. Idempotent."
      (with-db cfg
        (lambda (conn)
          (pg-migrations-run!
            (lambda (sql) (pg-exec conn sql))
            (lambda (sql) (pg-result-rows (pg-query conn sql)))
            dir
            `((log-proc ,(lambda (m)
                           (display "[migrate] ") (display m) (newline))))))))))

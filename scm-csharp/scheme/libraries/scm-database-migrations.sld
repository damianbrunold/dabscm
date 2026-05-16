(define-library (scm database migrations)
  (import (scm core)
          (scheme base)
          (scheme file)
          (srfi 1)
          (srfi 132)
          (scm fs))
  (export run-migrations!
          migrations-applied
          migrations-pending)
  (begin

    ;; ============================================================
    ;; Generic forward-only SQL migration runner.
    ;;
    ;; Migrations are .sql files in a directory, applied in lexical order
    ;; (the conventional naming is NNNN_name.sql). Each applied filename
    ;; is recorded in a tracking table so it is never re-run.
    ;;
    ;; The runner is database-agnostic: callers provide two callbacks,
    ;; `exec-sql!' and `query-rows', that wrap their actual connection.
    ;; This keeps the library independent of any particular driver and
    ;; makes it usable with postgres, sqlserver, sqlite, or any in-memory
    ;; database used in tests.
    ;;
    ;; Each migration runs inside its own transaction (BEGIN / COMMIT /
    ;; ROLLBACK). Multi-statement migrations are passed as one string to
    ;; `exec-sql!' — the driver must be able to execute a script. The
    ;; built-in pg-exec on (scm database postgres) does this.
    ;; ============================================================

    (define default-table-name "schema_migrations")

    ;; Default DDL targets PostgreSQL (timestamptz, now()). Drivers for
    ;; other databases pass an alternative via the create-table-sql
    ;; option below; the value should be a complete CREATE TABLE
    ;; statement and is interpolated only once.
    (define (default-create-table-sql table-name)
      (string-append
        "CREATE TABLE IF NOT EXISTS " table-name " (\n"
        "  filename text PRIMARY KEY,\n"
        "  applied_at timestamptz NOT NULL DEFAULT now()\n"
        ")"))

    ;; --- file helpers ---

    (define (read-file-string path)
      (call-with-input-file path
        (lambda (port)
          (let ((out (open-output-string)))
            (let loop ()
              (let ((c (read-char port)))
                (cond
                  ((eof-object? c) (get-output-string out))
                  (else (write-char c out) (loop)))))))))

    (define (sql-files dir)
      ;; Sorted list of "NNNN_name.sql" filenames (no path).
      (let* ((all (directory-files dir))
             (sql (filter (lambda (f)
                            (let ((n (string-length f)))
                              (and (>= n 4)
                                   (string=? (substring f (- n 4) n) ".sql"))))
                          all)))
        (list-sort string<? sql)))

    ;; --- options handling ---

    (define (opt opts key default)
      (let ((p (assq key opts)))
        (cond (p (cadr p)) (else default))))

    (define (resolve-options opts)
      (let* ((table (opt opts 'table-name default-table-name))
             (ddl   (opt opts 'create-table-sql (default-create-table-sql table)))
             (log   (opt opts 'log-proc (lambda (msg) #f))))
        (values table ddl log)))

    ;; --- SQL string-literal escape used only for filenames ---
    ;; (filenames are matched to the .sql files on disk, so they're
    ;; already constrained — but quoting keeps the runner self-contained
    ;; without depending on (scm database postgres).)

    (define (quote-filename s)
      (let* ((n (string-length s))
             (out (open-output-string)))
        (write-char #\' out)
        (let loop ((i 0))
          (cond
            ((= i n) (write-char #\' out) (get-output-string out))
            (else
             (let ((c (string-ref s i)))
               (cond ((char=? c #\') (write-string "''" out))
                     (else           (write-char c out)))
               (loop (+ i 1))))))))

    ;; --- public API ---

    (define (migrations-applied exec-sql! query-rows . opts)
      "Syntax: (migrations-applied exec-sql! query-rows [options])
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
  => (\"0001_init.sql\" \"0002_users.sql\")"
      (call-with-values (lambda () (resolve-options (if (null? opts) '() (car opts))))
        (lambda (table ddl log)
          (exec-sql! ddl)
          (let ((rows (query-rows
                        (string-append "SELECT filename FROM " table))))
            (map (lambda (row) (vector-ref row 0)) rows)))))

    (define (migrations-pending exec-sql! query-rows dir . opts)
      "Syntax: (migrations-pending exec-sql! query-rows dir [options])
Library: (scm database migrations)
Description: Returns the list of .sql filenames in dir (lexical order) that
  have not yet been applied. Use this to preview what run-migrations!
  would do. See run-migrations! for the options alist.
Example:
  (migrations-pending exec-sql! query-rows \"./migrations\")
  => (\"0003_add_index.sql\")"
      (let ((applied (apply migrations-applied exec-sql! query-rows opts))
            (files   (sql-files dir)))
        (filter (lambda (f) (not (member f applied string=?))) files)))

    (define (run-migrations! exec-sql! query-rows dir . opts)
      "Syntax: (run-migrations! exec-sql! query-rows dir [options])
Library: (scm database migrations)
Description: Applies pending .sql migrations from dir in lexical order.
  Each migration runs inside its own transaction (BEGIN / COMMIT /
  ROLLBACK on failure). The tracking table is created if it does not
  exist. Idempotent: already-applied files are skipped silently.
  options is an alist with keys:
    'table-name        — tracking table name (default \"schema_migrations\")
    'create-table-sql  — full CREATE TABLE statement for the tracking
                         table (override for non-PostgreSQL databases)
    'log-proc          — (lambda (msg) ...) called once per applied file
                         and once at end of run. Default: no logging.
Example:
  (run-migrations!
    (lambda (sql) (pg-exec conn sql))
    (lambda (sql) (pg-result-rows (pg-query conn sql)))
    \"./migrations\"
    '((log-proc ,(lambda (m) (display m) (newline)))))"
      (when (not (directory-exists? dir))
        (error "run-migrations!: migrations directory does not exist" dir))
      (call-with-values (lambda () (resolve-options (if (null? opts) '() (car opts))))
        (lambda (table ddl log)
          (exec-sql! ddl)
          (let ((applied (let ((rows (query-rows
                                       (string-append "SELECT filename FROM " table))))
                           (map (lambda (row) (vector-ref row 0)) rows)))
                (files   (sql-files dir)))
            (for-each
              (lambda (f)
                (cond
                  ((member f applied string=?) #f) ; skip silently
                  (else
                   (let ((sql (read-file-string
                                (string-append dir "/" f))))
                     (log (string-append "applying " f))
                     (exec-sql! "BEGIN")
                     (guard (exn (#t
                                  (guard (e (#t #f)) (exec-sql! "ROLLBACK"))
                                  (raise exn)))
                       (exec-sql! sql)
                       ;; Plain INSERT: the runner skips already-applied
                       ;; files above, so we never try to re-insert.
                       (exec-sql!
                         (string-append
                           "INSERT INTO " table " (filename) VALUES ("
                           (quote-filename f) ")"))
                       (exec-sql! "COMMIT"))))))
              files)
            (log "migrations complete")))))
))

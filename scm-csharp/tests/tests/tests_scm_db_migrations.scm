(import (scheme base) (scheme file) (scheme write) (scheme time)
        (srfi 1)
        (scm fs)
        (scm database migrations)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-db-migrations")

;; ---------------------------------------------------------------
;; In-memory fake "database" — the migration runner is generic over
;; exec-sql! / query-rows callbacks, so we plug in these closures and
;; never touch a real driver in tests.
;; ---------------------------------------------------------------

(define *applied* '())
(define *exec-log* '())

(define (reset-state!)
  (set! *applied* '())
  (set! *exec-log* '()))

(define (begins-with? s prefix)
  (and (>= (string-length s) (string-length prefix))
       (string=? (substring s 0 (string-length prefix)) prefix)))

;; Find the substring between matching single quotes — used to extract
;; the filename from a generated INSERT statement. Returns #f if no
;; quoted segment is present.
(define (between-quotes s)
  (let* ((n (string-length s)))
    (let loop ((i 0) (first #f))
      (cond
        ((= i n) #f)
        ((char=? (string-ref s i) #\')
         (cond
           (first (substring s (+ first 1) i))
           (else (loop (+ i 1) i))))
        (else (loop (+ i 1) first))))))

(define (fake-exec! sql)
  (set! *exec-log* (cons sql *exec-log*))
  (cond
    ((begins-with? sql "INSERT INTO schema_migrations")
     (let ((name (between-quotes sql)))
       (when name (set! *applied* (cons name *applied*)))))
    (else #f)))

(define (fake-query-rows sql)
  (cond
    ((begins-with? sql "SELECT filename FROM schema_migrations")
     (map (lambda (f) (vector f)) (reverse *applied*)))
    (else '())))

;; ---------------------------------------------------------------
;; Migration fixture: temp dir with three .sql files.
;; ---------------------------------------------------------------

(define tmpdir
  (let ((d (string-append "/tmp/scm-migrations-test-"
                          (number->string (modulo (current-jiffy) 1000000)))))
    (when (directory-exists? d) (delete-directory d))
    (make-directory d)
    d))

(define (write-fixture name content)
  (call-with-output-file (string-append tmpdir "/" name)
    (lambda (p) (write-string content p))))

(write-fixture "0001_init.sql"   "CREATE TABLE t (id int);")
(write-fixture "0002_data.sql"   "INSERT INTO t VALUES (1);")
(write-fixture "0003_index.sql"  "CREATE INDEX ix_t ON t (id);")
;; Non-.sql files should be ignored.
(write-fixture "README"          "ignored")

(test-group "migrations-applied creates the tracking table"
  (reset-state!)
  (let ((rows (migrations-applied fake-exec! fake-query-rows)))
    (test-equal '() rows)
    (test-equal #t (begins-with? (last *exec-log*) "CREATE TABLE IF NOT EXISTS"))))

(test-group "migrations-pending lists all .sql files initially"
  (reset-state!)
  (let ((pending (migrations-pending fake-exec! fake-query-rows tmpdir)))
    (test-equal '("0001_init.sql" "0002_data.sql" "0003_index.sql") pending)))

(test-group "run-migrations! applies all and records each"
  (reset-state!)
  (run-migrations! fake-exec! fake-query-rows tmpdir)
  (test-equal '("0001_init.sql" "0002_data.sql" "0003_index.sql")
              (reverse *applied*))
  (test-equal 3 (length (filter (lambda (s) (string=? s "BEGIN")) *exec-log*)))
  (test-equal 3 (length (filter (lambda (s) (string=? s "COMMIT")) *exec-log*))))

(test-group "run-migrations! is idempotent (skips already-applied)"
  ;; Don't reset — state carries over from the previous group. A second
  ;; run should not produce any new BEGIN/COMMIT pair.
  (let ((begins-before  (length (filter (lambda (s) (string=? s "BEGIN")) *exec-log*)))
        (commits-before (length (filter (lambda (s) (string=? s "COMMIT")) *exec-log*))))
    (run-migrations! fake-exec! fake-query-rows tmpdir)
    (test-equal begins-before  (length (filter (lambda (s) (string=? s "BEGIN")) *exec-log*)))
    (test-equal commits-before (length (filter (lambda (s) (string=? s "COMMIT")) *exec-log*)))
    (test-equal '("0001_init.sql" "0002_data.sql" "0003_index.sql")
                (reverse *applied*))))

(define failing-rolled-back? #f)
(define (failing-exec! sql)
  (cond
    ((string=? sql "ROLLBACK") (set! failing-rolled-back? #t))
    ((string=? sql "INSERT INTO t VALUES (1);")
     (error "simulated failure"))
    (else (fake-exec! sql))))

(test-group "run-migrations! rolls back on failure"
  (reset-state!)
  (set! failing-rolled-back? #f)
  (guard (exn (#t #t))
    (run-migrations! failing-exec! fake-query-rows tmpdir))
  (test-equal #t failing-rolled-back?)
  ;; First migration was applied and recorded; second failed and was not.
  (test-equal '("0001_init.sql") (reverse *applied*)))

(define (capture-exec! sql) (set! *exec-log* (cons sql *exec-log*)))
(define (empty-rows _) '())

(test-group "options: custom table name"
  (reset-state!)
  (migrations-applied capture-exec! empty-rows '((table-name "_mig")))
  (test-equal #t
    (begins-with? (last *exec-log*) "CREATE TABLE IF NOT EXISTS _mig ")))

(test-group "options: custom create-table-sql"
  (reset-state!)
  (migrations-applied capture-exec! empty-rows
    '((create-table-sql "CREATE TABLE mig_custom (filename text)")))
  (test-equal "CREATE TABLE mig_custom (filename text)"
              (last *exec-log*)))

(define logs '())
(define (log m) (set! logs (cons m logs)))

(test-group "options: log-proc receives each applied filename"
  (reset-state!)
  (set! logs '())
  (run-migrations! fake-exec! fake-query-rows tmpdir
    `((log-proc ,log)))
  (test-equal '("applying 0001_init.sql"
                "applying 0002_data.sql"
                "applying 0003_index.sql"
                "migrations complete")
              (reverse logs)))

(test-group "missing directory raises"
  (test-equal #t
    (guard (exn (#t #t))
      (run-migrations! fake-exec! fake-query-rows
                       "/tmp/this-directory-should-not-exist-xyz")
      #f)))

(test-end "scm-db-migrations")

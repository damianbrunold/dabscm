(import (scheme base) (scheme process-context) (scm database sqlserver) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-db-sqlserver")

;; The pure parameter-formatting helpers are always tested. The network
;; tests run only when SCM_TEST_MSSQL is set to "host:port:user:password",
;; e.g. against the official container:
;;   podman run -d -e ACCEPT_EULA=Y -e 'MSSQL_SA_PASSWORD=...' -p 14330:1433 \
;;     mcr.microsoft.com/mssql/server:2022-latest
;;   SCM_TEST_MSSQL='127.0.0.1:14330:sa:...' scm tests_scm_db_sqlserver.scm

(test-group "ss-sql-literal"
  (test-equal "N''" (ss-sql-literal ""))
  (test-equal "N'O''Brien'" (ss-sql-literal "O'Brien"))
  (test-equal "N'Zürich'" (ss-sql-literal "Zürich"))
  (test-equal "N'a;b--c'" (ss-sql-literal "a;b--c"))
  (test-equal "42" (ss-sql-literal 42))
  (test-equal "-7" (ss-sql-literal -7))
  (test-equal "1.5" (ss-sql-literal 1.5))
  (test-equal "1" (ss-sql-literal #t))
  (test-equal "0" (ss-sql-literal #f))
  (test-equal "NULL" (ss-sql-literal 'null))
  (test-equal "0x00FF" (ss-sql-literal (bytevector 0 255)))
  (test-equal "(NULL)" (ss-sql-literal '()))
  (test-equal "(N'1', N'2')" (ss-sql-literal '("1" "2")))
  (test-equal "(1, 2, 3)" (ss-sql-literal '(1 2 3)))
  (test-equal #t (guard (e (#t #t)) (ss-sql-literal 'foo) #f)))

(test-group "ss-format-sql"
  (test-equal "SELECT 1" (ss-format-sql "SELECT 1" '()))
  (test-equal "WHERE a = 2024 AND b IN (N'1', N'x''y')"
    (ss-format-sql "WHERE a = $1 AND b IN $2" '(2024 ("1" "x'y"))))
  ;; $10 is one placeholder, not $1 followed by 0
  (test-equal "N'j'"
    (ss-format-sql "$10" '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j")))
  ;; placeholders in literals, quoted identifiers and comments are left alone
  (test-equal "SELECT '$1', N'$1 ''$1''', \"$1\", [$1], 5 -- $1\n/* $1 */"
    (ss-format-sql "SELECT '$1', N'$1 ''$1''', \"$1\", [$1], $1 -- $1\n/* $1 */" '(5)))
  (test-equal "SELECT $ AS x" (ss-format-sql "SELECT $ AS x" '()))
  (test-equal #t (guard (e (#t #t)) (ss-format-sql "$2" '(1)) #f))
  (test-equal #t (guard (e (#t #t)) (ss-format-sql "$0" '(1)) #f)))

(define mssql-env (get-environment-variable "SCM_TEST_MSSQL"))

(define (split-colon s)
  (let loop ((i 0) (start 0) (acc '()))
    (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
          ((and (char=? (string-ref s i) #\:) (< (length acc) 3))
           (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
          (else (loop (+ i 1) start acc)))))

(when (and mssql-env (not (string=? mssql-env "")))
  (let* ((parts (split-colon mssql-env))
         (host (list-ref parts 0))
         (port (string->number (list-ref parts 1)))
         (user (list-ref parts 2))
         (pw   (list-ref parts 3))
         (conn (ss-connect host port user pw "master")))
    (define (q sql . ps) (ss-result-rows (apply ss-query conn sql ps)))
    (test-group "live: types"
      (test-equal '(#("1")) (q "SELECT 1 AS a"))
      (test-equal '(#("Zürich €")) (q "SELECT CAST(N'Zürich €' AS varchar(20))"))
      (test-equal '(#("1.5" "-0.5")) (q "SELECT CAST(1.5 AS float), CAST(-0.5 AS real)"))
      (test-equal '(#("12.345" "3" "1")) (q "SELECT CAST(12.345 AS decimal(10,3)), CAST(3 AS bigint), CAST(1 AS bit)"))
      (test-equal '(#("2024-02-29" "2024-02-29 13:45:00"))
        (q "SELECT CAST('2024-02-29' AS date), CAST('2024-02-29T13:45:00' AS datetime)"))
      (test-equal '(#("2024-02-29 13:45:00.0000000"))
        (q "SELECT CAST('2024-02-29T13:45:00' AS datetime2)"))
      (test-equal 10000
        (string-length (vector-ref (car (q "SELECT REPLICATE(CAST(N'ab' AS nvarchar(max)), 5000)")) 0)))
      (test-equal '(#("a")) (q "SELECT CAST('a' AS text)"))
      (test-equal '(#("a😀b")) (q "SELECT $1" "a😀b")))
    (test-group "live: nulls (NBCROW)"
      (test-equal '(#(#f #f #f #f #f #f #f #f #f "5"))
        (q "SELECT CAST(NULL AS int),CAST(NULL AS int),CAST(NULL AS int),CAST(NULL AS int),CAST(NULL AS int),CAST(NULL AS int),CAST(NULL AS int),CAST(NULL AS int),CAST(NULL AS nvarchar(10)), 5")))
    (test-group "live: params, ORDER BY, many rows"
      (test-equal '(#("1") #("3"))
        (q "SELECT v FROM (VALUES (N'1'),(N'2'),(N'3')) t(v) WHERE v IN $1 ORDER BY v" '("1" "3")))
      (test-equal '(#("O'Brien")) (q "SELECT $1" "O'Brien"))
      ;; batches spanning several TDS packets (one TLS record per packet)
      (test-equal '(#("1"))
        (q (string-append "SELECT 1 /*" (make-string 20000 #\space) "*/")))
      (test-equal 20000
        (length (q "SELECT TOP 20000 a.object_id FROM sys.all_objects a CROSS JOIN sys.all_objects b"))))
    (test-group "live: errors"
      (test-equal 8134
        (guard (e (#t (car (error-object-irritants e)))) (q "SELECT 1/0") #f))
      ;; the connection stays usable after an error
      (test-equal '(#("2")) (q "SELECT 2")))
    (test-group "live: cursor + transaction descriptor"
      (let ((cur (ss-cursor-open conn "SELECT v FROM (VALUES (1),(2),(3),(4),(5)) t(v)")))
        (test-equal '(#("1") #("2") #("3")) (ss-cursor-fetch cur 3))
        (test-equal '(#("4") #("5")) (ss-cursor-fetch cur 3))
        (test-equal '() (ss-cursor-fetch cur 3))
        (ss-cursor-close cur))
      (test-equal '(#("0")) (q "SELECT @@TRANCOUNT")))
    (ss-close conn)
    (test-group "live: login failure"
      (test-equal 18456
        (guard (e (#t (car (error-object-irritants e))))
          (ss-connect host port user (string-append pw "-wrong") "master")
          #f)))))

(test-end "scm-db-sqlserver")

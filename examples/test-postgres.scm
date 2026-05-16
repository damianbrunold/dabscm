(import (scheme base)
        (scheme write)
        (scm database postgres))

(let* ((query "select * from thetable limit 5;")
       (conn   (pg-connect "localhost" 5432 "theuser" "thepassword" "thedatabase"))
       (result (pg-query conn query)))
  (display (pg-result-columns result)) (newline)
  (for-each
   (lambda (row)
     (write row)
     (newline))
   (pg-result->alist-list result))
  (pg-close conn))

;; Cursor example: stream rows in batches of 10
(let ((conn (pg-connect "localhost" 5432 "theuser" "thepassword" "thedatabase")))
  (let ((cur (pg-cursor-open conn "SELECT * FROM thetable ORDER BY 1")))
    (display "columns: ") (display (pg-cursor-columns cur)) (newline)
    (pg-cursor-for-each cur
                        (lambda (row) (write row) (newline))
                        10))
  (pg-close conn))

;; Cursor example: manual fetch loop
(let ((conn (pg-connect "localhost" 5432 "theuser" "thepassword" "thedatabase")))
  (let ((cur (pg-cursor-open conn "SELECT * FROM thetable ORDER BY 1")))
    (let loop ()
      (let ((rows (pg-cursor-fetch cur 5)))
        (if (not (null? rows))
            (begin
              (for-each (lambda (row) (write row) (newline)) rows)
              (loop)))))
    (pg-cursor-close cur))
  (pg-close conn))

;; with-pg-connection: auto-close connection even on error
(with-pg-connection "localhost" 5432 "theuser" "thepassword" "thedatabase"
  (lambda (conn)
    (display (pg-result->alist-list (pg-query conn "SELECT * FROM thetable LIMIT 5")))
    (newline)))

;; with-pg-query: auto-close connection and cursor even on error
(with-pg-query "localhost" 5432 "theuser" "thepassword" "thedatabase"
               "SELECT * FROM thetable ORDER BY 1"
  (lambda (conn cursor)
    (pg-cursor-for-each cursor (lambda (row) (write row) (newline)) 10)))


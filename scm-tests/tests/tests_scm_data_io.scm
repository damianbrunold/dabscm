(import (scheme base) (scheme file) (scm fs)
        (scm data core) (scm data frame) (scm data io) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-io")

(define dir (mktempdir))
(define (tmp name) (join-path dir name))
(define (spit path s) (call-with-output-file path (lambda (p) (write-string s p))))
(define (slurp path) (call-with-input-file path (lambda (p) (read-string 100000 p))))

(test-group "read-csv"
  (spit (tmp "a.csv")
        "id;name;pts;d\r\n1;\"Muster; Hans\";1,5;2024-03-11\r\n2;\"multi\nline \"\"q\"\"\";;11.03.2025\r\n")
  (let ((df (read-csv (tmp "a.csv") 'decimal #\,)))
    (test-equal '(id name pts d) (df-names df))
    (test-equal '((id . int) (name . string) (pts . real) (d . date)) (df-types df))
    (test-equal "Muster; Hans" (df-ref df 0 'name))
    (test-equal "multi\nline \"q\"" (df-ref df 1 'name))
    (test-assert (na? (df-ref df 1 'pts))))
  ;; separator detection, col-types, no header, n-max, skip
  (let ((df (read-csv-string "a,b\n007,x\n8,y\n")))
    (test-equal 'string (cdr (assq 'a (df-types df)))))
  (let ((df (read-csv-string "a,b\n1,x\n2,y\n" 'col-types '((a . string)))))
    (test-equal "1" (df-ref df 0 'a)))
  (let ((df (read-csv-string "1\t2\n3\t4\n" 'header #f)))
    (test-equal '(X1 X2) (df-names df))
    (test-equal 2 (df-nrow df)))
  (test-equal 1 (df-nrow (read-csv-string "a\n1\n2\n3\n" 'n-max 1)))
  (test-equal '(a) (df-names (read-csv-string "# comment\na\n1\n" 'skip 1)))
  (test-equal '(x y) (df-names (read-csv-string "a,b\n1,2\n" 'names '(x y))))
  ;; BOM and empty lines
  (test-equal '(a) (df-names (read-csv-string (string #\xFEFF #\a #\newline #\1 #\newline #\newline)))))

(test-group "write-csv round trip"
  (let* ((df (tibble (id 1 2) (name "a;b" "c\"d") (x 1.5 na)))
         (s (df->csv-string df 'sep #\; 'decimal #\,)))
    (test-equal "id;name;x\r\n1;\"a;b\";1,5\r\n2;\"c\"\"d\";\r\n" s)
    (write-csv df (tmp "b.csv") 'sep #\; 'decimal #\,)
    (let ((back (read-csv (tmp "b.csv") 'decimal #\,)))
      (test-equal (df->rows df) (df->rows back)))))

(test-group "csv-for-each"
  (spit (tmp "c.csv") "k,v\na,1\nb,2\n")
  (let ((acc '()))
    (csv-for-each (tmp "c.csv") (lambda (r) (set! acc (cons (cdr (assq 'v r)) acc))))
    (test-equal '("2" "1") acc)))

(test-group "xlsx"
  (let ((df (tibble (splg "BEW8" "GYN2") (pts 6441 1728.5) (n 1 na))))
    (write-xlsx (list (cons "Points" df) (cons "Other" (tibble (x 1 2)))) (tmp "p.xlsx"))
    (let ((back (read-xlsx (tmp "p.xlsx"))))
      (test-equal '(splg pts n) (df-names back))
      (test-equal "GYN2" (df-ref back 1 'splg))
      (test-equal 1728.5 (df-ref back 1 'pts))
      (test-assert (na? (df-ref back 1 'n))))
    (test-equal #(1 2) (df-column (read-xlsx (tmp "p.xlsx") 'sheet "Other") 'x))
    (test-equal #(1 2) (df-column (read-xlsx (tmp "p.xlsx") 'sheet 2) 'x))))

(test-group "json"
  (let ((df (tibble (a 1 2) (b "x" na) (l '(1 2) '()))))
    (write-json-records df (tmp "r.json"))
    (test-equal "[{\"a\":1,\"b\":\"x\",\"l\":[1,2]},{\"a\":2,\"b\":null,\"l\":[]}]\n"
                (slurp (tmp "r.json")))
    (let ((back (read-json-records (tmp "r.json"))))
      (test-equal (df->rows df) (df->rows back)))
    (write-jsonl df (tmp "r.jsonl"))
    (test-equal (df->rows df) (df->rows (read-jsonl (tmp "r.jsonl"))))))

(test-group "sexp lines"
  (spit (tmp "s.scm")
        (string-append
         "((burnr \"1\") (splg BEW8) (lgs BEW8 BP) (operateure (\"g1\" BEW8 1.0)))\n"
         "((burnr \"2\") (splg GYN2) (lgs GYN2) (operateure (\"g1\" GYN2 0.5) (\"g2\" GYN2 0.5)))\n"
         "((burnr \"3\") (splg BP))\n"))
  (let ((df (read-sexp-lines (tmp "s.scm"))))
    (test-equal '(burnr splg lgs operateure) (df-names df))
    (test-equal '(BEW8 BP) (df-ref df 0 'lgs))
    (test-equal 'GYN2 (df-ref df 1 'lgs))
    (test-assert (na? (df-ref df 2 'operateure))))
  (let ((df (read-sexp-lines (tmp "s.scm") 'list-cols '(lgs operateure) 'add '((year . 2024)))))
    (test-equal '(GYN2) (df-ref df 1 'lgs))
    (test-equal '(("g1" BEW8 1.0)) (df-ref df 0 'operateure))
    (test-equal '() (df-ref df 2 'operateure))
    (test-equal #(2024 2024 2024) (df-column df 'year)))
  (let ((df (read-sexp-lines (tmp "s.scm")
                             'map (lambda (d) (and (not (equal? (cadr (assq 'splg d)) 'BP))
                                                   (list (cons 'b (cadr (assq 'burnr d)))))))))
    (test-equal #("1" "2") (df-column df 'b)))
  (let ((df (tibble (a 1 na) (l '(x y) '()))))
    (write-sexp-lines df (tmp "w.scm"))
    (test-equal "((a 1) (l x y))\n((l))\n" (slurp (tmp "w.scm")))))

(test-group "query results"
  (let ((df (query-result->df (vector #("id" "name" "ok") (list #("1" "a" "t") #("2" #f "f"))))))
    (test-equal '((id . int) (name . string) (ok . bool)) (df-types df))
    (test-assert (na? (df-ref df 1 'name)))))

(test-end "scm-data-io")

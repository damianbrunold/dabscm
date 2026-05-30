;; Tests for (scm store) -- the on-disk indexed record store, and the
;; (scm random access) primitives it is built on.

(import (scheme base)
        (scheme write)
        (scheme file)
        (scm test)
        (scm random access)
        (scm store))

(test-runner-factory scm-test-runner)

(test-begin "store")

(define tmp "tests_store_tmp.store")
(define tmp-raf "tests_store_tmp.raf")

(define (cleanup)
  (when (file-exists? tmp) (delete-file tmp))
  (when (file-exists? tmp-raf) (delete-file tmp-raf)))

(cleanup)

;; ---------------------------------------------------------------
;; (scm random access) primitives
;; ---------------------------------------------------------------

(let ((f (open-random-access-file tmp-raf 'write)))
  (test-assert "random-access-file?" (random-access-file? f))
  (test-equal "write returns count" 5 (random-access-file-write! f 0 #u8(10 20 30 40 50)))
  ;; positioned write past end leaves a zero gap
  (test-equal "write at offset" 5 (random-access-file-write! f 100 (string->utf8 "hello")))
  (test-equal "size after sparse write" 105 (random-access-file-size f))
  (test-equal "positioned read" #u8(30 40 50) (random-access-file-read f 2 3))
  (test-equal "read utf8 region" "hello" (utf8->string (random-access-file-read f 100 5)))
  (test-equal "read past eof is empty" #u8() (random-access-file-read f 1000 8))
  ;; sub-range write
  (test-equal "write sub-range" 2 (random-access-file-write! f 0 #u8(1 2 3 4) 1 3))
  (test-equal "read back sub-range" #u8(2 3 30) (random-access-file-read f 0 3))
  (random-access-file-truncate! f 5)
  (test-equal "size after truncate" 5 (random-access-file-size f))
  (close-random-access-file f))
(test-equal "reopen read-only sees data" #u8(2 3 30 40 50)
            (call-with-random-access-file tmp-raf 'read
              (lambda (g) (random-access-file-read g 0 5))))

;; ---------------------------------------------------------------
;; Store: build a small SPLG-shaped dataset
;; ---------------------------------------------------------------
;; scalar fields: burnr, splg ; multi fields: quer, errors

(define (build!)
  (let ((w (store-writer-open tmp '(burnr splg) '(quer errors))))
    ;; rowid 0
    (store-writer-add! w '((burnr . "100") (splg . "A1") (note . "first"))
                       '((burnr . "100") (splg . "A1")
                         (quer . ("x" "y")) (errors . ())))
    ;; rowid 1
    (store-writer-add! w '((burnr . "100") (splg . "B2") (note . "second"))
                       '((burnr . "100") (splg . "B2")
                         (quer . ("y" "z")) (errors . ("E1"))))
    ;; rowid 2
    (store-writer-add! w '((burnr . "200") (splg . "A1") (note . "third"))
                       '((burnr . "200") (splg . "A1")
                         (quer . ("x")) (errors . ("E1" "E2"))))
    ;; rowid 3
    (store-writer-add! w '((burnr . "200") (splg . "A1") (note . "fourth"))
                       '((burnr . "200") (splg . "A1")
                         (quer . ()) (errors . ())))
    (store-writer-close w)))

(build!)

(define s (store-open tmp))

(test-equal "store-count" 4 (store-count s))

;; payload round-trips (including a value not indexed: note)
(test-equal "store-ref 0" '((burnr . "100") (splg . "A1") (note . "first")) (store-ref s 0))
(test-equal "store-ref 3" '((burnr . "200") (splg . "A1") (note . "fourth")) (store-ref s 3))

;; distinct scalar values, sorted
(test-equal "distinct splg" '("A1" "B2") (store-field-values s 'splg))
(test-equal "distinct burnr" '("100" "200") (store-field-values s 'burnr))
(test-equal "distinct quer (multi)" '("x" "y" "z") (store-field-values s 'quer))

;; equality on scalar field
(test-equal "eq splg A1" '(0 2 3) (store-query s '((eq splg "A1"))))
(test-equal "eq burnr 200" '(2 3) (store-query s '((eq burnr "200"))))
(test-equal "eq splg missing" '() (store-query s '((eq splg "ZZ"))))

;; membership on multi field
(test-equal "in quer x" '(0 2) (store-query s '((in quer ("x")))))
(test-equal "in quer x or z" '(0 1 2) (store-query s '((in quer ("x" "z")))))
(test-equal "present errors" '(1 2) (store-query s '((present errors))))

;; AND of clauses
(test-equal "splg A1 AND burnr 200" '(2 3)
            (store-query s '((eq splg "A1") (eq burnr "200"))))
(test-equal "splg A1 AND in quer x" '(0 2)
            (store-query s '((eq splg "A1") (in quer ("x")))))

;; counts
(test-equal "count splg A1" 3 (store-count-matching s '((eq splg "A1"))))
(test-equal "count no clauses = total" 4 (store-count-matching s '()))

;; pagination -- unfiltered fast path
(test-equal "page all 0/2" '(0 1) (store-page s '() 0 2))
(test-equal "page all 2/2" '(2 3) (store-page s '() 2 2))
(test-equal "page all offset past end" '() (store-page s '() 10 5))

;; pagination -- filtered
(test-equal "page filtered" '(0) (store-page s '((eq splg "A1")) 0 1))
(test-equal "page filtered offset" '(2 3) (store-page s '((eq splg "A1")) 1 5))

;; page records returns (rowid . payload)
(test-equal "page-records"
            '((2 . ((burnr . "200") (splg . "A1") (note . "third")))
              (3 . ((burnr . "200") (splg . "A1") (note . "fourth"))))
            (store-page-records s '((eq splg "A1")) 1 5))

(store-close s)

;; ---------------------------------------------------------------
;; Larger dataset: exercises multi-byte offsets and binary search
;; ---------------------------------------------------------------
(cleanup)
(let ((w (store-writer-open tmp '(grp) '(tags))))
  (let loop ((i 0))
    (when (< i 500)
      (store-writer-add! w
        (list (cons 'i i) (cons 'pad (make-string 50 #\x)))
        (list (cons 'grp (number->string (modulo i 7)))
              (cons 'tags (list (number->string (modulo i 13))
                                (number->string (modulo i 17))))))
      (loop (+ i 1))))
  (store-writer-close w))

(define s2 (store-open tmp))
(test-equal "large store-count" 500 (store-count s2))
(test-equal "large store-ref 250 payload i"
            250 (cdr (assq 'i (store-ref s2 250))))
;; group 0 = multiples of 7 in [0,500): 0,7,...,497 -> 72 of them
(test-equal "large count grp 0" 72 (store-count-matching s2 '((eq grp "0"))))
;; distinct grp values 0..6
(test-equal "large distinct grp" '("0" "1" "2" "3" "4" "5" "6")
            (store-field-values s2 'grp))
;; membership: tags contains "0" -> i mod 13 = 0 or i mod 17 = 0
(test-assert "large in tags 0 nonempty"
             (pair? (store-query s2 '((in tags ("0"))))))
;; AND across scalar+multi
(test-assert "large grp0 AND tags0 subset of grp0"
             (let ((a (store-query s2 '((eq grp "0") (in tags ("0")))))
                   (b (store-query s2 '((eq grp "0")))))
               (let contains-all ((xs a))
                 (or (null? xs)
                     (and (memv (car xs) b) (contains-all (cdr xs)))))))
(store-close s2)

(cleanup)
(test-end "store")

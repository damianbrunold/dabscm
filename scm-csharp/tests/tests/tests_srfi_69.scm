(import (scheme base)
        (scheme char)
        (srfi 69)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "srfi-69")

;; make-hash-table, hash-table?
(test-group "predicates"
  (test-assert (hash-table? (make-hash-table equal?)))
  (test-equal #f (hash-table? '())))

;; ref and ref/default
(test-group "ref"
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (test-equal 1 (hash-table-ref ht 'a))
  (test-equal 99 (hash-table-ref/default ht 'b 99)))

(test-group "ref-default"
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'b 2)
  (test-equal 2 (hash-table-ref/default ht 'b 0)))

;; exists?
(test-group "exists"
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (test-equal #t (hash-table-exists? ht 'x))
  (test-equal #f (hash-table-exists? ht 'y)))

;; delete!
(test-group "delete"
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table-delete! ht 'x)
  (test-equal #f (hash-table-exists? ht 'x)))

;; size, keys, values, ->alist
(test-group "size-keys-values"
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-set! ht 'b 2)
  (test-equal 2 (hash-table-size ht))
  (test-equal 2 (length (hash-table-keys ht)))
  (test-equal 2 (length (hash-table-values ht)))
  (test-equal 2 (length (hash-table->alist ht))))

;; walk
(test-group "walk"
  (define ht (make-hash-table equal?))
  (define total 0)
  (hash-table-set! ht 'a 10)
  (hash-table-walk ht (lambda (k v) (set! total (+ total v))))
  (test-equal 10 total))

;; fold
(test-group "fold"
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-set! ht 'b 2)
  (hash-table-set! ht 'c 3)
  (test-equal 6 (hash-table-fold ht (lambda (k v acc) (+ v acc)) 0)))

;; merge!
(test-group "merge"
  (define ht1 (make-hash-table equal?))
  (define ht2 (make-hash-table equal?))
  (hash-table-set! ht1 'a 1)
  (hash-table-set! ht2 'b 2)
  (hash-table-merge! ht1 ht2)
  (test-equal 2 (hash-table-ref/default ht1 'b 0))
  (test-equal 1 (hash-table-ref/default ht1 'a 0)))

;; update!
(test-group "update"
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 5)
  (hash-table-update! ht 'x (lambda (v) (+ v 1)))
  (test-equal 6 (hash-table-ref ht 'x)))

;; update!/default
(test-group "update-default"
  (define ht (make-hash-table equal?))
  (hash-table-update!/default ht 'y (lambda (v) (+ v 100)) 0)
  (test-equal 100 (hash-table-ref ht 'y)))

;; copy
(test-group "copy"
  (define ht (make-hash-table equal?))
  (define ht2 #f)
  (hash-table-set! ht 'a 1)
  (set! ht2 (hash-table-copy ht))
  (hash-table-set! ht2 'b 2)
  (test-equal 1 (hash-table-ref ht2 'a))
  (test-equal #f (hash-table-exists? ht 'b)))

;; hash functions
(test-group "hash-functions"
  (test-assert (integer? (hash 'foo)))
  (test-assert (integer? (hash "hello")))
  (test-assert (integer? (hash 42)))
  (test-assert (integer? (string-hash "hello")))
  (test-assert (= (string-hash "hello") (string-ci-hash "HELLO")))
  (test-assert (integer? (hash-by-identity 'foo))))

;; hash with bound
(test-group "hash-bound"
  (test-assert (< (hash 'foo 100) 100))
  (test-assert (< (string-hash "hello" 256) 256)))

;; the equivalences a table supports natively
(test-group "equivalences"
  (let ((ht (make-hash-table string-ci=? string-ci-hash)))
    (hash-table-set! ht "Zurich" 1)
    (test-equal 1 (hash-table-ref/default ht "ZURICH" #f))
    (hash-table-set! ht "zurich" 2)
    (test-equal 1 (hash-table-size ht))
    (test-equal 2 (hash-table-ref ht "ZuRiCh"))
    (hash-table-delete! ht "ZURICH")
    (test-equal 0 (hash-table-size ht)))
  (let ((ht (make-hash-table char-ci=?)))
    (hash-table-set! ht #\a 1)
    (test-equal 1 (hash-table-ref/default ht #\A #f)))
  (let ((ht (make-hash-table =)))
    (hash-table-set! ht 1 'one)
    (test-equal 'one (hash-table-ref/default ht 1.0 #f))
    (test-equal 'one (hash-table-ref/default ht 2/2 #f))
    (hash-table-set! ht 0.5 'half)
    (test-equal 'half (hash-table-ref/default ht 1/2 #f))
    (test-equal 2 (hash-table-size ht)))
  (let ((ht (make-hash-table string=? string-hash)))
    (hash-table-set! ht (string #\a) 1)
    (test-equal 1 (hash-table-ref/default ht "a" #f))
    (test-equal #f (hash-table-ref/default ht "A" #f)))
  (let ((ht (make-hash-table eqv?)))
    (hash-table-set! ht 1 'one)
    (test-equal #f (hash-table-ref/default ht 1.0 #f)))
  ;; keys of another type compare with equal? / eqv?
  (let ((ht (make-hash-table string-ci=?)))
    (hash-table-set! ht '(1 2) 'l)
    (test-equal 'l (hash-table-ref/default ht (list 1 2) #f)))
  ;; another predicate: an error, not a silent equal?
  (test-error (make-hash-table (lambda (a b) (equal? a b))))
  ;; extra arguments (e.g. a size hint) are accepted
  (test-assert (hash-table? (make-hash-table equal? hash 100))))

(test-group "equivalence-and-hash-function"
  ;; the default: equal? and hash (a primitive is compared by behaviour:
  ;; it need not be eq? to itself across libraries)
  (test-equal #t ((hash-table-equivalence-function (make-hash-table)) '(1 "a") (list 1 "a")))
  (test-eq hash (hash-table-hash-function (make-hash-table)))
  (let ((e eq?))
    (test-eq e (hash-table-equivalence-function (make-hash-table e))))
  (test-eq hash-by-identity (hash-table-hash-function (make-hash-table eq?)))
  (test-eq string-ci=? (hash-table-equivalence-function (make-hash-table string-ci=?)))
  (test-eq string-ci-hash (hash-table-hash-function (make-hash-table string-ci=?)))
  (let ((h (lambda (x . b) 0)))
    (test-eq h (hash-table-hash-function (make-hash-table equal? h))))
  ;; a copy keeps both
  (test-eq string-ci=?
           (hash-table-equivalence-function
            (hash-table-copy (make-hash-table string-ci=?)))))

(test-group "alist->hash-table"
  (let ((ht (alist->hash-table '((a . 1) (b . 2) (a . 3)))))
    (test-equal 2 (hash-table-size ht))
    (test-equal 1 (hash-table-ref ht 'a)))
  (let ((ht (alist->hash-table '(("A" . 1)) string-ci=?)))
    (test-equal 1 (hash-table-ref/default ht "a" #f))
    (test-eq string-ci=? (hash-table-equivalence-function ht))))

(test-group "ref-with-thunk"
  (let ((ht (make-hash-table)))
    (hash-table-set! ht 'a 1)
    (test-equal 1 (hash-table-ref ht 'a (lambda () 0)))
    (test-equal 0 (hash-table-ref ht 'b (lambda () 0)))
    (test-equal 'x (hash-table-ref ht 'b (lambda () 'x)))
    (test-error (hash-table-ref ht 'b))))

(test-group "copy-mutable"
  (let* ((ht (make-hash-table))
         (c (hash-table-copy ht #t)))
    (hash-table-set! c 'a 1)
    (test-equal 1 (hash-table-size c))
    (test-equal 0 (hash-table-size ht))
    (test-equal 0 (hash-table-size (hash-table-copy ht #f)))))

(test-group "hash-numbers"
  (test-assert (= (hash 1) (hash 1.0)))
  (test-assert (integer? (hash +nan.0)))
  (test-assert (integer? (hash +inf.0)))
  (test-assert (< (hash 1.5 10) 10)))

(test-end "srfi-69")

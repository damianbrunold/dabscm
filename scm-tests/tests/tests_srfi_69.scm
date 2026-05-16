(import (scheme base)
        (scm test)
        (srfi 69))

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

(test-end "srfi-69")

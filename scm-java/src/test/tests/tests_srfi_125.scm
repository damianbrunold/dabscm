(import (scheme base)
        (scheme cxr)
        (scm test)
        (srfi 125)
        (srfi 128))

(test-runner-factory scm-test-runner)

(test-begin "srfi-125")

;; make-hash-table with comparator
(test-group "make-hash-table"
  (test-equal #t (hash-table? (make-hash-table (make-default-comparator))))
  (test-equal #f (hash-table? '())))

;; basic set and ref
(test-group "hash-table-set!/ref"
  (define ht (make-hash-table (make-default-comparator)))
  (hash-table-set! ht 'a 1)
  (test-equal 1 (hash-table-ref ht 'a))
  (test-equal 99 (hash-table-ref/default ht 'b 99)))

;; hash-table constructor with key-value pairs
(test-group "hash-table constructor"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (test-equal 3 (hash-table-size ht))
  (test-equal 1 (hash-table-ref ht 'a))
  (test-equal 2 (hash-table-ref ht 'b))
  (test-equal 3 (hash-table-ref ht 'c)))

;; alist->hash-table (first association wins)
(test-group "alist->hash-table"
  (define ht (alist->hash-table '((a . 1) (b . 2) (a . 99)) (make-default-comparator)))
  (test-equal 1 (hash-table-ref ht 'a))
  (test-equal 2 (hash-table-ref ht 'b))
  (test-equal 2 (hash-table-size ht)))

;; hash-table-unfold
(test-group "hash-table-unfold"
  (define ht (hash-table-unfold (lambda (s) (> s 3))
                                (lambda (s) (values s (* s 10)))
                                (lambda (s) (+ s 1))
                                1
                                (make-default-comparator)))
  (test-equal 10 (hash-table-ref ht 1))
  (test-equal 20 (hash-table-ref ht 2))
  (test-equal 30 (hash-table-ref ht 3))
  (test-equal 3 (hash-table-size ht)))

;; hash-table-contains?
(test-group "hash-table-contains?"
  (define ht (hash-table (make-default-comparator) 'a 1))
  (test-equal #t (hash-table-contains? ht 'a))
  (test-equal #f (hash-table-contains? ht 'b)))

;; hash-table-empty?
(test-group "hash-table-empty?"
  (test-equal #t (hash-table-empty? (make-hash-table (make-default-comparator))))
  (test-equal #f (hash-table-empty? (hash-table (make-default-comparator) 'a 1))))

;; hash-table=?
(test-group "hash-table=?"
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2))
  (define ht2 (hash-table (make-default-comparator) 'a 1 'b 2))
  (define ht3 (hash-table (make-default-comparator) 'a 1 'b 3))
  (test-equal #t (hash-table=? (make-default-comparator) ht1 ht2))
  (test-equal #f (hash-table=? (make-default-comparator) ht1 ht3)))

;; hash-table-mutable?
(test-group "hash-table-mutable?"
  (test-equal #t (hash-table-mutable? (make-hash-table (make-default-comparator)))))

;; hash-table-ref with failure and success thunks
(test-group "hash-table-ref with thunks"
  (define ht (hash-table (make-default-comparator) 'a 1))
  (test-equal 1 (hash-table-ref ht 'a))
  (test-equal 42 (hash-table-ref ht 'b (lambda () 42)))
  (test-equal 10 (hash-table-ref ht 'a #f (lambda (v) (* v 10)))))

;; hash-table-intern!
(test-group "hash-table-intern!"
  (define ht (make-hash-table (make-default-comparator)))
  (test-equal 42 (hash-table-intern! ht 'a (lambda () 42)))
  (test-equal 42 (hash-table-ref ht 'a))
  (test-equal 42 (hash-table-intern! ht 'a (lambda () 99))))

;; hash-table-update!
(test-group "hash-table-update!"
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-update! ht 'a (lambda (v) (+ v 1)))
  (test-equal 2 (hash-table-ref ht 'a))
  (hash-table-update! ht 'b (lambda (v) (+ v 10)) (lambda () 0))
  (test-equal 10 (hash-table-ref ht 'b)))

;; hash-table-update!/default
(test-group "hash-table-update!/default"
  (define ht (make-hash-table (make-default-comparator)))
  (hash-table-update!/default ht 'x (lambda (v) (+ v 1)) 0)
  (test-equal 1 (hash-table-ref ht 'x))
  (hash-table-update!/default ht 'x (lambda (v) (+ v 1)) 0)
  (test-equal 2 (hash-table-ref ht 'x)))

;; hash-table-pop!
(test-group "hash-table-pop!"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (test-equal #t
    (let-values (((k v) (hash-table-pop! ht)))
      (and (or (eq? k 'a) (eq? k 'b))
           (or (= v 1) (= v 2)))))
  (test-equal 1 (hash-table-size ht)))

;; hash-table-clear!
(test-group "hash-table-clear!"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-clear! ht)
  (test-equal 0 (hash-table-size ht))
  (test-equal #t (hash-table-empty? ht)))

;; hash-table-entries
(test-group "hash-table-entries"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (test-equal #t
    (let-values (((keys vals) (hash-table-entries ht)))
      (and (= (length keys) 2) (= (length vals) 2)))))

;; hash-table-find
(test-group "hash-table-find"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (test-equal 3 (hash-table-find (lambda (k v) (and (> v 2) v)) ht (lambda () #f)))
  (test-equal 'nope (hash-table-find (lambda (k v) (and (> v 10) v)) ht (lambda () 'nope))))

;; hash-table-count
(test-group "hash-table-count"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (test-equal 2 (hash-table-count (lambda (k v) (> v 1)) ht))
  (test-equal 3 (hash-table-count (lambda (k v) #t) ht))
  (test-equal 0 (hash-table-count (lambda (k v) #f) ht)))

;; hash-table-map
(test-group "hash-table-map"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (define ht2 (hash-table-map (lambda (v) (* v 10)) (make-default-comparator) ht))
  (test-equal 10 (hash-table-ref ht2 'a))
  (test-equal 20 (hash-table-ref ht2 'b)))

;; hash-table-for-each
(test-group "hash-table-for-each"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (define total 0)
  (hash-table-for-each (lambda (k v) (set! total (+ total v))) ht)
  (test-equal 3 total))

;; hash-table-map!
(test-group "hash-table-map!"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-map! (lambda (k v) (* v 10)) ht)
  (test-equal 10 (hash-table-ref ht 'a))
  (test-equal 20 (hash-table-ref ht 'b)))

;; hash-table-map->list
(test-group "hash-table-map->list"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (define result (hash-table-map->list (lambda (k v) v) ht))
  (test-equal 2 (length result)))

;; hash-table-fold (SRFI-125 argument order)
(test-group "hash-table-fold"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (test-equal 3 (hash-table-fold (lambda (k v acc) (+ v acc)) 0 ht)))

;; hash-table-prune!
(test-group "hash-table-prune!"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (hash-table-prune! (lambda (k v) (> v 1)) ht)
  (test-equal 1 (hash-table-size ht))
  (test-equal 1 (hash-table-ref ht 'a)))

;; hash-table-copy
(test-group "hash-table-copy"
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (define ht2 (hash-table-copy ht))
  (test-equal 1 (hash-table-ref ht2 'a))
  (hash-table-set! ht2 'c 3)
  (test-equal #f (hash-table-contains? ht 'c)))

;; hash-table-empty-copy
(test-group "hash-table-empty-copy"
  (define ht (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table-empty-copy ht))
  (test-equal #t (hash-table-empty? ht2))
  (test-equal #t (hash-table? ht2)))

;; hash-table-union! (does not overwrite existing)
(test-group "hash-table-union!"
  (define ht1 (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table (make-default-comparator) 'a 99 'b 2))
  (hash-table-union! ht1 ht2)
  (test-equal 1 (hash-table-ref ht1 'a))
  (test-equal 2 (hash-table-ref ht1 'b))
  (test-equal 2 (hash-table-size ht1)))

;; hash-table-intersection!
(test-group "hash-table-intersection!"
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (define ht2 (hash-table (make-default-comparator) 'a 10 'c 30))
  (hash-table-intersection! ht1 ht2)
  (test-equal 2 (hash-table-size ht1))
  (test-equal #t (hash-table-contains? ht1 'a))
  (test-equal #t (hash-table-contains? ht1 'c))
  (test-equal #f (hash-table-contains? ht1 'b)))

;; hash-table-difference!
(test-group "hash-table-difference!"
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (define ht2 (hash-table (make-default-comparator) 'b 20))
  (hash-table-difference! ht1 ht2)
  (test-equal 2 (hash-table-size ht1))
  (test-equal #t (hash-table-contains? ht1 'a))
  (test-equal #t (hash-table-contains? ht1 'c))
  (test-equal #f (hash-table-contains? ht1 'b)))

;; hash-table-xor!
(test-group "hash-table-xor!"
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2))
  (define ht2 (hash-table (make-default-comparator) 'b 20 'c 3))
  (hash-table-xor! ht1 ht2)
  (test-equal 2 (hash-table-size ht1))
  (test-equal #t (hash-table-contains? ht1 'a))
  (test-equal #t (hash-table-contains? ht1 'c))
  (test-equal #f (hash-table-contains? ht1 'b)))

;; hash-table-comparator
(test-group "hash-table-comparator"
  (define c (make-default-comparator))
  (define ht (make-hash-table c))
  (test-equal #t (comparator? (hash-table-comparator ht)))
  (test-assert (procedure? (hash-table-equivalence-function ht)))
  (test-assert (procedure? (hash-table-hash-function ht))))

;; hash-table with eq-comparator
(test-group "hash-table with eq-comparator"
  (define ht (make-hash-table (make-eq-comparator)))
  (hash-table-set! ht 'a 1)
  (test-equal 1 (hash-table-ref ht 'a)))

;; hash-table with eqv-comparator
(test-group "hash-table with eqv-comparator"
  (define ht (make-hash-table (make-eqv-comparator)))
  (hash-table-set! ht 42 "hello")
  (test-equal "hello" (hash-table-ref ht 42)))

;; hash-table-delete!
(test-group "hash-table-delete!"
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-delete! ht 'a)
  (test-equal #t (hash-table-empty? ht)))

;; hash-table->alist
(test-group "hash-table->alist"
  (define ht (hash-table (make-default-comparator) 'a 1))
  (test-equal 1 (length (hash-table->alist ht)))
  (test-equal 1 (cdar (hash-table->alist ht))))

(test-end "srfi-125")

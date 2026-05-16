(import (scheme base)
        (scm test)
        (srfi 128))

(test-runner-factory scm-test-runner)

(test-begin "srfi-128")

;; comparator construction and predicate
(test-group "comparator construction"
  (test-equal #t (comparator? (make-comparator string? string=? string<? string-hash)))
  (test-equal #f (comparator? 42))
  (test-equal #f (comparator? '())))

;; comparator-ordered? and comparator-hashable?
(test-group "comparator-ordered? and comparator-hashable?"
  (define c (make-comparator string? string=? string<? string-hash))
  (define c2 (make-comparator string? string=? #f #f))
  (test-equal #t (comparator-ordered? c))
  (test-equal #t (comparator-hashable? c))
  (test-equal #f (comparator-ordered? c2))
  (test-equal #f (comparator-hashable? c2)))

;; comparator-test-type and check-type
(test-group "comparator-test-type and check-type"
  (define c (make-comparator string? string=? string<? string-hash))
  (test-equal #t (comparator-test-type c "hello"))
  (test-equal #f (comparator-test-type c 42))
  (test-equal #t (comparator-check-type c "hello")))

;; make-eq-comparator
(test-group "make-eq-comparator"
  (define c (make-eq-comparator))
  (test-equal #t (comparator? (make-eq-comparator)))
  (test-equal #t ((comparator-equality-predicate c) 'a 'a))
  (test-equal #f ((comparator-equality-predicate c) 'a 'b)))

;; make-eqv-comparator
(test-group "make-eqv-comparator"
  (define c (make-eqv-comparator))
  (test-equal #t (comparator? (make-eqv-comparator)))
  (test-equal #t ((comparator-equality-predicate c) 42 42))
  (test-equal #f ((comparator-equality-predicate c) 42 43)))

;; make-equal-comparator
(test-group "make-equal-comparator"
  (define c (make-equal-comparator))
  (test-equal #t (comparator? (make-equal-comparator)))
  (test-equal #t ((comparator-equality-predicate c) '(1 2 3) '(1 2 3)))
  (test-equal #f ((comparator-equality-predicate c) '(1 2) '(1 3)))
  (test-equal #t (comparator-hashable? c)))

;; make-default-comparator type test
(test-group "make-default-comparator type test"
  (define c (make-default-comparator))
  (test-equal #t (comparator-test-type c 42))
  (test-equal #t (comparator-test-type c "hello"))
  (test-equal #t (comparator-test-type c 'sym))
  (test-equal #t (comparator-test-type c #\a))
  (test-equal #t (comparator-test-type c #t))
  (test-equal #t (comparator-test-type c '()))
  (test-equal #t (comparator-test-type c '(1 2)))
  (test-equal #t (comparator-test-type c #(1 2))))

;; default comparator equality
(test-group "default comparator equality"
  (define c (make-default-comparator))
  (test-equal #t (=? c 1 1))
  (test-equal #f (=? c 1 2))
  (test-equal #t (=? c "abc" "abc"))
  (test-equal #f (=? c "abc" "def"))
  (test-equal #t (=? c 'foo 'foo))
  (test-equal #f (=? c 'foo 'bar))
  (test-equal #t (=? c #\a #\a))
  (test-equal #t (=? c #t #t))
  (test-equal #f (=? c #t #f))
  (test-equal #t (=? c '() '()))
  (test-equal #t (=? c '(1 2) '(1 2)))
  (test-equal #t (=? c #(1 2) #(1 2))))

;; default comparator ordering
(test-group "default comparator ordering"
  (define c (make-default-comparator))
  (test-equal #t (<? c 1 2))
  (test-equal #f (<? c 2 1))
  (test-equal #t (<? c "abc" "def"))
  (test-equal #f (<? c "def" "abc"))
  (test-equal #t (<? c 'abc 'def))
  (test-equal #t (<? c #\a #\b))
  (test-equal #t (<? c #f #t))
  (test-equal #f (<? c #t #f)))

;; cross-type ordering (by type index)
(test-group "cross-type ordering"
  (define c (make-default-comparator))
  (test-equal #t (<? c '() #t))
  (test-equal #t (<? c #t #\a))
  (test-equal #t (<? c 1 "hello"))
  (test-equal #t (<? c "hello" 'sym)))

;; comparison predicates with multiple args
(test-group "comparison predicates with multiple args"
  (define c (make-default-comparator))
  (test-equal #t (=? c 1 1 1))
  (test-equal #f (=? c 1 1 2))
  (test-equal #t (<? c 1 2 3))
  (test-equal #f (<? c 1 2 2))
  (test-equal #t (>? c 3 2 1))
  (test-equal #f (>? c 3 2 2))
  (test-equal #t (<=? c 1 1 2))
  (test-equal #f (<=? c 1 2 1))
  (test-equal #t (>=? c 3 3 1))
  (test-equal #f (>=? c 1 3 3)))

;; hash functions
(test-group "hash functions"
  (test-equal #t (integer? (boolean-hash #t)))
  (test-equal #t (= (boolean-hash #t) (boolean-hash #t)))
  (test-equal #t (integer? (char-hash #\a)))
  (test-equal #t (= (char-hash #\a) (char-hash #\a)))
  (test-equal #t (= (char-ci-hash #\A) (char-ci-hash #\a)))
  (test-equal #t (integer? (number-hash 42)))
  (test-equal #t (= (number-hash 42) (number-hash 42)))
  (test-equal #t (integer? (string-hash "hello")))
  (test-equal #t (= (string-hash "abc") (string-hash "abc")))
  (test-equal #t (= (string-ci-hash "Hello") (string-ci-hash "hello")))
  (test-equal #t (integer? (symbol-hash 'foo)))
  (test-equal #t (= (symbol-hash 'bar) (symbol-hash 'bar))))

;; default-hash
(test-group "default-hash"
  (test-equal #t (integer? (default-hash 42)))
  (test-equal #t (integer? (default-hash "hello")))
  (test-equal #t (integer? (default-hash 'foo)))
  (test-equal #t (integer? (default-hash '(1 2 3))))
  (test-equal #t (integer? (default-hash #(1 2 3))))
  (test-equal #t (= (default-hash "abc") (default-hash "abc"))))

;; hash-bound and hash-salt
(test-group "hash-bound and hash-salt"
  (test-equal #t (> (hash-bound) 0))
  (test-equal #t (integer? (hash-salt))))

;; comparator-if<=>
(test-group "comparator-if<=>"
  (define c (make-default-comparator))
  (test-equal 'less (comparator-if<=> c 1 2 'less 'equal 'greater))
  (test-equal 'equal (comparator-if<=> c 2 2 'less 'equal 'greater))
  (test-equal 'greater (comparator-if<=> c 3 2 'less 'equal 'greater)))

;; default-comparator binding
(test-group "default-comparator binding"
  (test-equal #t (comparator? default-comparator))
  (test-equal #t (=? default-comparator 1 1))
  (test-equal #t (<? default-comparator 1 2)))

;; make-pair-comparator
(test-group "make-pair-comparator"
  (define c (make-pair-comparator (make-default-comparator) (make-default-comparator)))
  (test-equal #t (=? c '(1 . 2) '(1 . 2)))
  (test-equal #f (=? c '(1 . 2) '(1 . 3)))
  (test-equal #t (<? c '(1 . 2) '(2 . 1)))
  (test-equal #t (comparator-hashable? c)))

;; make-list-comparator
(test-group "make-list-comparator"
  (define c (make-list-comparator (make-default-comparator) list? null? car cdr))
  (test-equal #t (=? c '(1 2 3) '(1 2 3)))
  (test-equal #f (=? c '(1 2) '(1 3)))
  (test-equal #t (<? c '(1 2) '(1 3)))
  (test-equal #t (<? c '(1) '(1 2)))
  (test-equal #t (comparator-hashable? c)))

;; make-vector-comparator
(test-group "make-vector-comparator"
  (define c (make-vector-comparator (make-default-comparator) vector? vector-length vector-ref))
  (test-equal #t (=? c #(1 2 3) #(1 2 3)))
  (test-equal #f (=? c #(1 2) #(1 3)))
  (test-equal #t (<? c #(1 2) #(1 3)))
  (test-equal #t (<? c #(1) #(1 2)))
  (test-equal #t (comparator-hashable? c)))

;; make-comparator with #t for equality uses equal?
(test-group "make-comparator with #t equality"
  (define c (make-comparator (lambda (x) #t) #t #f #f))
  (test-equal #t ((comparator-equality-predicate c) '(1 2) '(1 2))))

;; pair ordering in default comparator
(test-group "pair ordering in default comparator"
  (define c (make-default-comparator))
  (test-equal #t (<? c '(1 . 2) '(2 . 1)))
  (test-equal #t (<? c '(1 . 1) '(1 . 2)))
  (test-equal #t (=? c '(1 . 2) '(1 . 2))))

;; vector ordering in default comparator
(test-group "vector ordering in default comparator"
  (define c (make-default-comparator))
  (test-equal #t (<? c #(1 2) #(1 3)))
  (test-equal #t (<? c #(1) #(1 2)))
  (test-equal #t (=? c #(1 2) #(1 2))))

(test-end "srfi-128")

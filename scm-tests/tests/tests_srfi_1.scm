(import (scheme base)
        (scheme cxr)
        (scm test)
        (srfi 1))

(test-runner-factory scm-test-runner)

(test-begin "srfi-1")

;; Constructors
(test-group "constructors"
  (test-equal '(1 2 3) (xcons '(2 3) 1))
  (test-equal '(0 1 4 9 16) (list-tabulate 5 (lambda (i) (* i i))))
  (test-equal '(x x x) (make-list 3 'x))
  (test-equal '(#f #f #f) (make-list 3))
  (test-equal '(0 1 2 3 4) (iota 5))
  (test-equal '(1 2 3 4 5) (iota 5 1))
  (test-equal '(0 2 4 6 8) (iota 5 0 2))
  (test-equal '(1 2 3 4 5) (cons* 1 2 3 '(4 5)))
  (test-equal 'a (cons* 'a)))

;; Selectors
(test-group "selectors"
  (test-equal 'c (third '(a b c d e)))
  (test-equal 'd (fourth '(a b c d e)))
  (test-equal 'e (fifth '(a b c d e)))
  (test-equal 'f (sixth '(a b c d e f)))
  (test-equal 'g (seventh '(a b c d e f g)))
  (test-equal 'h (eighth '(a b c d e f g h)))
  (test-equal 'i (ninth '(a b c d e f g h i)))
  (test-equal 'j (tenth '(a b c d e f g h i j)))
  (test-equal 3 (last '(1 2 3)))
  (test-equal '(3) (last-pair '(1 2 3)))
  (test-equal '(a b c) (take '(a b c d e) 3))
  (test-equal '(c d e) (drop '(a b c d e) 2))
  (test-equal '(d e) (take-right '(a b c d e) 2))
  (test-equal '(a b c) (drop-right '(a b c d e) 2))
  (test-equal '((a b) (c d e)) (call-with-values (lambda () (split-at '(a b c d e) 2)) list))
  (test-equal '(a b) (call-with-values (lambda () (car+cdr '(a . b))) list)))

;; Predicates
(test-group "predicates"
  (test-equal #t (proper-list? '(1 2 3)))
  (test-equal #f (proper-list? '(1 . 2)))
  (test-equal #t (proper-list? '()))
  (test-equal #t (dotted-list? '(1 . 2)))
  (test-equal #f (dotted-list? '(1 2)))
  (test-equal #t (not-pair? 5))
  (test-equal #f (not-pair? '(1 2)))
  (test-equal #t (null-list? '()))
  (test-equal #f (null-list? '(1)))
  (test-equal 3 (length+ '(1 2 3))))

;; fold, reduce, any, every
(test-group "fold, reduce, any, every"
  (test-equal 15 (fold + 0 '(1 2 3 4 5)))
  (test-equal '(3 2 1) (fold cons '() '(1 2 3)))
  (test-equal '(1 2 3) (fold-right cons '() '(1 2 3)))
  (test-equal 15 (reduce + 0 '(1 2 3 4 5)))
  (test-equal 0 (reduce + 0 '()))
  (test-equal 6 (reduce-right + 0 '(1 2 3)))
  (test-equal #t (any odd? '(2 4 5 6)))
  (test-equal #f (any odd? '(2 4 6)))
  (test-equal #t (every odd? '(1 3 5)))
  (test-equal #f (every odd? '(1 3 4))))

;; find, filter, partition, remove, count
(test-group "find, filter, partition, remove, count"
  (test-equal 5 (find odd? '(2 4 5 6)))
  (test-equal #f (find odd? '(2 4 6)))
  (test-equal '(1 3 5) (filter odd? '(1 2 3 4 5)))
  (test-equal '((1 3 5) (2 4)) (call-with-values (lambda () (partition odd? '(1 2 3 4 5))) list))
  (test-equal '(2 4) (remove odd? '(1 2 3 4 5)))
  (test-equal 3 (count odd? '(1 2 3 4 5)))
  (test-equal 3 (count < '(1 2 3) '(2 3 4))))

;; Searching
(test-group "searching"
  (test-equal '(4 1 5 9) (find-tail even? '(3 1 4 1 5 9)))
  (test-equal '(1 3 5) (take-while odd? '(1 3 5 2 4)))
  (test-equal '(2 4) (drop-while odd? '(1 3 5 2 4)))
  (test-equal '((1 3 5) (2 4)) (call-with-values (lambda () (span odd? '(1 3 5 2 4))) list))
  (test-equal '((1 3 5) (2 4)) (call-with-values (lambda () (break even? '(1 3 5 2 4))) list))
  (test-equal 2 (list-index even? '(3 1 4 1 5 9)))
  (test-equal #f (list-index even? '(3 1 5 9))))

;; append, reverse, map variants
(test-group "append, reverse, map variants"
  (test-equal '(1 2 3 4 5 6) (concatenate '((1 2) (3 4) (5 6))))
  (test-equal '(1 2 3 4 5 6) (append-reverse '(3 2 1) '(4 5 6)))
  (test-equal '(1 1 2 4 3 9) (append-map (lambda (x) (list x (* x x))) '(1 2 3)))
  (test-equal '() (append-map (lambda (x) (list x)) '()))
  (test-equal '(10 30 50) (filter-map (lambda (x) (and (odd? x) (* x 10))) '(1 2 3 4 5)))
  (test-equal '((1 a) (2 b) (3 c)) (zip '(1 2 3) '(a b c)))
  (test-equal '((1 a x) (2 b y) (3 c z)) (zip '(1 2 3) '(a b c) '(x y z))))

;; unfold
(test-group "unfold"
  (test-equal '(1 2 3 4 5) (unfold (lambda (x) (> x 5)) (lambda (x) x) (lambda (x) (+ x 1)) 1))
  (test-equal '(1 2 3 4 5) (unfold-right (lambda (x) (< x 1)) (lambda (x) x) (lambda (x) (- x 1)) 5)))

;; pair-fold, pair-for-each
(test-group "pair-fold, pair-for-each"
  (test-equal '(c b a) (pair-fold (lambda (p acc) (cons (car p) acc)) '() '(a b c)))
  (test-equal '(a b c) (pair-fold-right (lambda (p acc) (cons (car p) acc)) '() '(a b c))))

;; delete, delete-duplicates
(test-group "delete, delete-duplicates"
  (test-equal '(1 2 4 5) (delete 3 '(1 2 3 4 3 5)))
  (test-equal '(1 2 4 5) (delete 3 '(1 2 3 4 3 5) =))
  (test-equal '(1 2 3 4) (delete-duplicates '(1 2 1 3 2 4 3))))

;; alist operations
(test-group "alist operations"
  (test-equal '((a . 1) (b . 2)) (alist-cons 'a 1 '((b . 2))))
  (test-equal '((a . 1) (b . 2)) (alist-copy '((a . 1) (b . 2))))
  (test-equal '((a . 1) (c . 4)) (alist-delete 'b '((a . 1) (b . 2) (b . 3) (c . 4)))))

;; unzip
(test-group "unzip"
  (test-equal '(1 2 3) (unzip1 '((1 a) (2 b) (3 c))))
  (test-equal '((1 2 3) (a b c)) (call-with-values (lambda () (unzip2 '((1 a) (2 b) (3 c)))) list))
  (test-equal '((1 2 3) (a b c) (x y z)) (call-with-values (lambda () (unzip3 '((1 a x) (2 b y) (3 c z)))) list)))

;; list=, list-copy
(test-group "list=, list-copy"
  (test-equal #t (list= equal? '(1 2 3) '(1 2 3)))
  (test-equal #f (list= equal? '(1 2 3) '(1 2 4)))
  (test-equal #t (list= equal? '(1 2 3) '(1 2 3) '(1 2 3)))
  (test-equal '(1 2 3) (list-copy '(1 2 3))))

;; lset operations
(test-group "lset operations"
  (test-equal '(4 1 2 3) (lset-adjoin equal? '(1 2 3) 3 4))
  (test-equal #t (lset<= equal? '(1 2) '(1 2 3)))
  (test-equal #f (lset<= equal? '(1 2 3) '(1 2)))
  (test-equal #t (lset= equal? '(1 2 3) '(3 2 1)))
  (test-equal #t (lset= equal? (lset-union equal? '(1 2 3) '(2 3 4)) '(1 2 3 4)))
  (test-equal '(2 4) (lset-intersection equal? '(1 2 3 4) '(2 4 6)))
  (test-equal '(1 3) (lset-difference equal? '(1 2 3 4) '(2 4)))
  (test-equal #t (lset= equal? (lset-xor equal? '(1 2 3) '(2 3 4)) '(1 4)))
  (test-equal '((1 3) (2 4)) (call-with-values (lambda () (lset-diff+intersection equal? '(1 2 3 4) '(2 4))) list))
  (test-equal '() (lset-union equal?))
  (test-equal '() (lset-xor equal?))
  (test-equal #t (lset= equal? (lset-union equal? '(a b) '(b c) '(c d)) '(a b c d)))
  (test-equal #t (lset= equal? (lset-xor equal? '(a b c) '(a b d)) '(c d))))

;; Re-exports from (scheme base) / (scheme cxr) accessible via (srfi 1)
(test-group "re-exported base procedures"
  (test-equal '(1 . 2) (cons 1 2))
  (test-equal '(1 2 3) (list 1 2 3))
  (test-equal #t (pair? '(1)))
  (test-equal #t (null? '()))
  (test-equal 'a (car '(a b)))
  (test-equal '(b) (cdr '(a b)))
  (test-equal 'b (list-ref '(a b c) 1))
  (test-equal 3 (length '(1 2 3)))
  (test-equal '(1 2 3 4) (append '(1 2) '(3 4)))
  (test-equal '(3 2 1) (reverse '(1 2 3)))
  (test-equal '(2 4 6) (map (lambda (x) (* x 2)) '(1 2 3)))
  ;; cxr re-exports
  (test-equal 'a (caaar '(((a)))))
  (test-equal '(e) (cddddr '(a b c d e))))

;; Multi-list pair-fold-right
(test-group "multi-list pair-fold-right"
  ;; pair-fold-right with single list
  (test-equal '(a b c) (pair-fold-right (lambda (p acc) (cons (car p) acc)) '() '(a b c)))
  ;; pair-fold-right with multiple lists
  (test-equal '(11 22 33) (pair-fold-right (lambda (p1 p2 acc) (cons (+ (car p1) (car p2)) acc)) '() '(1 2 3) '(10 20 30))))

;; (srfi 132) list-sort
(test-group "list-sort"
  (import (srfi 132))
  ;; list-sort from (srfi 132)
  (test-equal '(1 1 3 4 5 9) (list-sort < '(3 1 4 1 5 9)))
  (test-equal '("apple" "banana" "cherry") (list-sort string<? '("banana" "apple" "cherry")))
  (test-equal '() (list-sort < '())))

(test-end "srfi-1")

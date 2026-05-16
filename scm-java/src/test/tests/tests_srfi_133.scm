(import (except (scheme base) vector-copy vector-fill!)
        (scm test)
        (srfi 133))

(test-runner-factory scm-test-runner)

(test-begin "srfi-133")

;; Constructors - basic
(test-group "constructors - basic"
  (test-equal #t (vector? (make-vector 3)))
  (test-equal #t (vector? (vector 1 2 3)))
  (test-equal 5 (vector-length (make-vector 5)))
  (test-equal #(1 2 3) (vector 1 2 3))
  (test-equal #() (vector)))

;; Constructors - vector-unfold
(test-group "constructors - vector-unfold"
  (test-equal #(0 1 2 3 4) (vector-unfold (lambda (i) i) 5))
  (test-equal #(0 1 2 3 4) (vector-unfold (lambda (i x) (values x (+ x 1))) 5 0))
  (test-equal #(1 2 4 8 16) (vector-unfold (lambda (i x) (values x (* x 2))) 5 1))
  (test-equal #() (vector-unfold (lambda (i) i) 0)))

;; Constructors - vector-unfold-right
(test-group "constructors - vector-unfold-right"
  (test-equal #(0 1 2 3 4) (vector-unfold-right (lambda (i) i) 5))
  (test-equal #(4 3 2 1 0) (vector-unfold-right (lambda (i x) (values x (+ x 1))) 5 0))
  (test-equal #() (vector-unfold-right (lambda (i) i) 0)))

;; Constructors - vector-copy
(test-group "constructors - vector-copy"
  (test-equal #(a b c d e) (vector-copy '#(a b c d e)))
  (test-equal #(c d) (vector-copy '#(a b c d e) 2 4))
  (test-equal #(a b c x x) (vector-copy '#(a b c) 0 5 'x))
  (test-equal #(a b c d e) (vector-copy '#(a b c d e) 0)))

;; Constructors - vector-reverse-copy
(test-group "constructors - vector-reverse-copy"
  (test-equal #(e d c b a) (vector-reverse-copy '#(a b c d e)))
  (test-equal #(d c b) (vector-reverse-copy '#(a b c d e) 1 4))
  (test-equal #() (vector-reverse-copy '#(a b c d e) 0 0)))

;; Constructors - vector-append, vector-concatenate, vector-append-subvectors
(test-group "constructors - vector-append and friends"
  (test-equal #(a b c d) (vector-append '#(a b) '#(c d)))
  (test-equal #(a b c) (vector-append '#(a) '#() '#(b c)))
  (test-equal #(a b c d) (vector-concatenate '(#(a b) #(c d))))
  (test-equal #() (vector-concatenate '()))
  (test-equal #(a b g h) (vector-append-subvectors '#(a b c d e) 0 2 '#(f g h) 1 3))
  (test-equal #(a b c) (vector-append-subvectors '#(a b c) 0 3)))

;; Predicates
(test-group "predicates"
  (test-equal #t (vector? '#(1 2 3)))
  (test-equal #f (vector? '()))
  (test-equal #t (vector-empty? '#()))
  (test-equal #f (vector-empty? '#(1)))
  (test-equal #t (vector= eq? '#(a b c) '#(a b c)))
  (test-equal #f (vector= eq? '#(a b) '#(a b c)))
  (test-equal #t (vector= eq? '#() '#()))
  (test-equal #t (vector= eq?))
  (test-equal #t (vector= eq? '#(a)))
  (test-equal #t (vector= equal? '#(1 2) '#(1 2) '#(1 2)))
  (test-equal #f (vector= equal? '#(1 2) '#(1 3) '#(1 2))))

;; Selectors
(test-group "selectors"
  (test-equal 'b (vector-ref '#(a b c) 1))
  (test-equal 3 (vector-length '#(a b c)))
  (test-equal 0 (vector-length '#())))

;; Iteration - vector-fold
(test-group "iteration - vector-fold"
  (test-equal 15 (vector-fold (lambda (i sum x) (+ sum x)) 0 '#(1 2 3 4 5)))
  (test-equal '(c b a) (vector-fold (lambda (i acc x) (cons x acc)) '() '#(a b c)))
  (test-equal 2 (vector-fold (lambda (i count x y) (if (equal? x y) (+ count 1) count))
                 0 '#(a b c) '#(a x c)))
  (test-equal 0 (vector-fold (lambda (i sum x) (+ sum x)) 0 '#())))

;; Iteration - vector-fold-right
(test-group "iteration - vector-fold-right"
  (test-equal '(a b c) (vector-fold-right (lambda (i tail x) (cons x tail)) '() '#(a b c)))
  (test-equal 6 (vector-fold-right (lambda (i sum x) (+ sum x)) 0 '#(1 2 3)))
  (test-equal '() (vector-fold-right (lambda (i acc x) (cons x acc)) '() '#())))

;; Iteration - vector-map, vector-map!, vector-for-each
(test-group "iteration - vector-map and friends"
  (test-equal #(11 22 33) (vector-map + '#(1 2 3) '#(10 20 30)))
  (test-equal #(1 4 9 16) (vector-map (lambda (x) (* x x)) '#(1 2 3 4)))
  (test-equal #(1 4 9)
    (let ((v (vector 1 2 3)))
      (vector-map! (lambda (x) (* x x)) v)
      v))
  (test-equal #(11 22 33)
    (let ((v (vector 1 2 3)))
      (vector-map! + v '#(10 20 30))
      v))
  (test-equal '(c b a)
    (let ((acc '()))
      (vector-for-each (lambda (x) (set! acc (cons x acc))) '#(a b c))
      acc)))

;; Iteration - vector-count
(test-group "iteration - vector-count"
  (test-equal 2 (vector-count even? '#(1 2 3 4 5)))
  (test-equal 2 (vector-count equal? '#(a b c) '#(a x c)))
  (test-equal 0 (vector-count even? '#())))

;; Iteration - vector-cumulate
(test-group "iteration - vector-cumulate"
  (test-equal #(1 3 6 10) (vector-cumulate + 0 '#(1 2 3 4)))
  (test-equal #(1 2 6 24) (vector-cumulate * 1 '#(1 2 3 4)))
  (test-equal #() (vector-cumulate + 0 '#())))

;; Searching - vector-index
(test-group "searching - vector-index"
  (test-equal 1 (vector-index even? '#(1 2 3 4)))
  (test-equal #f (vector-index even? '#(1 3 5)))
  (test-equal 0 (vector-index < '#(1 5 3) '#(2 4 6)))
  (test-equal #f (vector-index even? '#())))

;; Searching - vector-index-right
(test-group "searching - vector-index-right"
  (test-equal 3 (vector-index-right even? '#(1 2 3 4)))
  (test-equal #f (vector-index-right even? '#(1 3 5)))
  (test-equal #f (vector-index-right even? '#())))

;; Searching - vector-skip, vector-skip-right
(test-group "searching - vector-skip"
  (test-equal 2 (vector-skip odd? '#(1 3 2 4)))
  (test-equal #f (vector-skip even? '#(2 4 6)))
  (test-equal 3 (vector-skip-right odd? '#(1 3 2 4)))
  (test-equal #f (vector-skip-right even? '#(2 4 6))))

;; Searching - vector-binary-search
(test-group "searching - vector-binary-search"
  (test-equal 2 (vector-binary-search '#(1 3 5 7 9) 5 (lambda (a b) (- a b))))
  (test-equal #f (vector-binary-search '#(1 3 5 7 9) 4 (lambda (a b) (- a b))))
  (test-equal 0 (vector-binary-search '#(1 3 5 7 9) 1 (lambda (a b) (- a b))))
  (test-equal 4 (vector-binary-search '#(1 3 5 7 9) 9 (lambda (a b) (- a b))))
  (test-equal #f (vector-binary-search '#() 1 (lambda (a b) (- a b)))))

;; Searching - vector-any, vector-every
(test-group "searching - vector-any and vector-every"
  (test-equal #t (vector-any even? '#(1 2 3)))
  (test-equal #f (vector-any even? '#(1 3 5)))
  (test-equal #f (vector-any even? '#()))
  (test-equal #t (vector-every even? '#(2 4 6)))
  (test-equal #f (vector-every even? '#(2 3 6)))
  (test-equal #t (vector-every even? '#())))

;; Searching - vector-partition
(test-group "searching - vector-partition"
  (test-equal '(#(2 4) #(1 3 5))
    (call-with-values (lambda () (vector-partition even? '#(1 2 3 4 5))) list))
  (test-equal '(#() #())
    (call-with-values (lambda () (vector-partition even? '#())) list)))

;; Mutators - vector-set!, vector-swap!
(test-group "mutators - vector-set! and vector-swap!"
  (test-equal #(a x c)
    (let ((v (vector 'a 'b 'c)))
      (vector-set! v 1 'x)
      v))
  (test-equal #(c b a)
    (let ((v (vector 'a 'b 'c)))
      (vector-swap! v 0 2)
      v)))

;; Mutators - vector-fill!
(test-group "mutators - vector-fill!"
  (test-equal #(0 0 0 0 0)
    (let ((v (vector 1 2 3 4 5)))
      (vector-fill! v 0)
      v))
  (test-equal #(1 0 0 0 5)
    (let ((v (vector 1 2 3 4 5)))
      (vector-fill! v 0 1 4)
      v)))

;; Mutators - vector-reverse!
(test-group "mutators - vector-reverse!"
  (test-equal #(5 4 3 2 1)
    (let ((v (vector 1 2 3 4 5)))
      (vector-reverse! v)
      v))
  (test-equal #(1 4 3 2 5)
    (let ((v (vector 1 2 3 4 5)))
      (vector-reverse! v 1 4)
      v))
  (test-equal #(1)
    (let ((v (vector 1)))
      (vector-reverse! v)
      v)))

;; Mutators - vector-copy!
(test-group "mutators - vector-copy!"
  (test-equal #(a x y d e)
    (let ((v (vector 'a 'b 'c 'd 'e)))
      (vector-copy! v 1 '#(x y z) 0 2)
      v)))

;; Mutators - vector-reverse-copy!
(test-group "mutators - vector-reverse-copy!"
  (test-equal #(x c b a x)
    (let ((v (vector 'x 'x 'x 'x 'x)))
      (vector-reverse-copy! v 1 '#(a b c) 0 3)
      v))
  (test-equal #(c b a)
    (let ((v (vector 'x 'x 'x)))
      (vector-reverse-copy! v 0 '#(a b c))
      v)))

;; Mutators - vector-unfold!, vector-unfold-right!
(test-group "mutators - vector-unfold! and vector-unfold-right!"
  (test-equal #(0 1 4 9 0)
    (let ((v (make-vector 5 0)))
      (vector-unfold! (lambda (i) (* i i)) v 1 4)
      v))
  (test-equal #(100 110 120 130 140)
    (let ((v (make-vector 5 0)))
      (vector-unfold! (lambda (i x) (values x (+ x 10))) v 0 5 100)
      v))
  (test-equal #(0 1 4 9 0)
    (let ((v (make-vector 5 0)))
      (vector-unfold-right! (lambda (i) (* i i)) v 1 4)
      v)))

;; Conversion
(test-group "conversion"
  (test-equal '(a b c) (vector->list '#(a b c)))
  (test-equal '(b c) (vector->list '#(a b c d e) 1 3))
  (test-equal '(e d c b a) (reverse-vector->list '#(a b c d e)))
  (test-equal '(d c b) (reverse-vector->list '#(a b c d e) 1 4))
  (test-equal '() (reverse-vector->list '#()))
  (test-equal #(a b c) (list->vector '(a b c)))
  (test-equal #() (list->vector '()))
  (test-equal #(c b a) (reverse-list->vector '(a b c)))
  (test-equal #() (reverse-list->vector '()))
  (test-equal "abc" (vector->string '#(#\a #\b #\c)))
  (test-equal #(#\a #\b #\c) (string->vector "abc")))

(test-end "srfi-133")

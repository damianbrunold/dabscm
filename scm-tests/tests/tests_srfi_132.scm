(import (scheme base)
        (scm test)
        (srfi 132))

(test-runner-factory scm-test-runner)

(test-begin "srfi-132")

;; list-sorted?
(test-group "list-sorted?"
  (test-equal #t (list-sorted? < '()))
  (test-equal #t (list-sorted? < '(1)))
  (test-equal #t (list-sorted? < '(1 2 3)))
  (test-equal #t (list-sorted? < '(1 1 2)))
  (test-equal #f (list-sorted? < '(3 1 2)))
  (test-equal #f (list-sorted? < '(1 3 2)))
  (test-equal #t (list-sorted? > '(3 2 1)))
  (test-equal #f (list-sorted? > '(1 2 3)))
  (test-equal #t (list-sorted? string<? '("a" "b" "c")))
  (test-equal #f (list-sorted? string<? '("b" "a" "c"))))

;; vector-sorted?
(test-group "vector-sorted?"
  (test-equal #t (vector-sorted? < #()))
  (test-equal #t (vector-sorted? < #(1)))
  (test-equal #t (vector-sorted? < #(1 2 3)))
  (test-equal #t (vector-sorted? < #(1 1 2)))
  (test-equal #f (vector-sorted? < #(3 1 2)))
  (test-equal #t (vector-sorted? < #(1 3 2 4) 2 4))
  (test-equal #t (vector-sorted? < #(5 1 2 3 0) 1 4))
  (test-equal #t (vector-sorted? < #(1 3 2) 0 2)))

;; list-sort
(test-group "list-sort"
  (test-equal '() (list-sort < '()))
  (test-equal '(1) (list-sort < '(1)))
  (test-equal '(1 1 3 4 5 9) (list-sort < '(3 1 4 1 5 9)))
  (test-equal '(9 5 4 3 1 1) (list-sort > '(3 1 4 1 5 9)))
  (test-equal '("apple" "banana" "cherry") (list-sort string<? '("banana" "apple" "cherry")))
  ;; stability: equal elements maintain relative order
  (test-equal '(a c b d)
    (map car (list-sort (lambda (a b) (< (cdr a) (cdr b)))
                        '((a . 1) (b . 2) (c . 1) (d . 2)))))
  ;; stability with larger list (5+ elements exercises tortoise-and-hare split)
  (test-equal '(a b c d e)
    (map car (list-sort (lambda (a b) (< (cdr a) (cdr b)))
                        '((a . 1) (b . 1) (c . 1) (d . 1) (e . 1)))))
  (test-equal '(b d f a c e g)
    (map car (list-sort (lambda (a b) (< (cdr a) (cdr b)))
                        '((a . 2) (b . 1) (c . 2) (d . 1) (e . 2) (f . 1) (g . 2))))))

;; list-stable-sort, list-sort!, list-stable-sort!
(test-group "list-stable-sort and destructive variants"
  (test-equal '(1 1 3 4 5) (list-stable-sort < '(3 1 4 1 5)))
  (test-equal '(1 1 3 4 5) (list-sort! < '(3 1 4 1 5)))
  (test-equal '(1 1 3 4 5) (list-stable-sort! < '(3 1 4 1 5))))

;; vector-sort
(test-group "vector-sort"
  (test-equal #() (vector-sort < #()))
  (test-equal #(1) (vector-sort < #(1)))
  (test-equal #(1 1 3 4 5 9) (vector-sort < #(3 1 4 1 5 9)))
  (test-equal #(5 4 3 1 1) (vector-sort > #(3 1 4 1 5)))
  (test-equal #(1 3 4) (vector-sort < #(5 3 1 4 2) 1 4))
  (test-equal #(7 8 9) (vector-sort < #(9 8 7 6 5) 0 3))
  ;; original not modified
  (test-equal #(3 1 2) (let ((v #(3 1 2))) (vector-sort < v) v)))

;; vector-stable-sort
(test-group "vector-stable-sort"
  (test-equal #(1 1 3 4 5) (vector-stable-sort < #(3 1 4 1 5)))
  ;; stability
  (test-equal '(a c b d)
    (let ((v (vector-stable-sort (lambda (a b) (< (cdr a) (cdr b)))
                                  (vector '(a . 1) '(b . 2) '(c . 1) '(d . 2)))))
      (vector->list (vector-map car v)))))

;; vector-sort!, vector-stable-sort!
(test-group "vector-sort! and vector-stable-sort!"
  (test-equal #(1 1 3 4 5) (let ((v (vector 3 1 4 1 5))) (vector-sort! < v) v))
  (test-equal #(1 2 3 4 5) (let ((v (vector 5 4 3 2 1))) (vector-sort! < v) v))
  (test-equal #(1 2 3) (let ((v (vector 1 2 3))) (vector-sort! < v) v))
  (test-equal #(5 1 3 4 2) (let ((v (vector 5 3 1 4 2))) (vector-sort! < v 1 4) v))
  ;; vector-stable-sort!
  (test-equal #(1 1 3 4 5) (let ((v (vector 3 1 4 1 5))) (vector-stable-sort! < v) v)))

;; list-merge
(test-group "list-merge"
  (test-equal '(1 2 3 4 5 6) (list-merge < '(1 3 5) '(2 4 6)))
  (test-equal '(1 2 3) (list-merge < '() '(1 2 3)))
  (test-equal '(1 2 3) (list-merge < '(1 2 3) '()))
  (test-equal '() (list-merge < '() '()))
  (test-equal '(1 2 2 3) (list-merge < '(1 2) '(2 3)))
  (test-equal '(1 1 1 1 1) (list-merge < '(1 1 1) '(1 1))))

;; list-merge!
(test-group "list-merge!"
  (test-equal '(1 2 3 4 5 6) (list-merge! < (list 1 3 5) (list 2 4 6)))
  (test-equal '(1 2 3) (list-merge! < (list) (list 1 2 3)))
  (test-equal '(1 2 3) (list-merge! < (list 1 2 3) (list)))
  (test-equal '() (list-merge! < (list) (list)))
  (test-equal '(1 2 2 3) (list-merge! < (list 1 2) (list 2 3))))

;; vector-merge
(test-group "vector-merge"
  (test-equal #(1 2 3 4 5 6) (vector-merge < #(1 3 5) #(2 4 6)))
  (test-equal #(1 2 3) (vector-merge < #() #(1 2 3)))
  (test-equal #(1 2 3) (vector-merge < #(1 2 3) #()))
  (test-equal #() (vector-merge < #() #()))
  (test-equal #(1 2 2 3) (vector-merge < #(1 2) #(2 3)))
  ;; with subranges
  (test-equal #(1 2 3 4 5 6) (vector-merge < #(9 1 3 5 9) #(9 2 4 6 9) 1 4 1 4)))

;; vector-merge!
(test-group "vector-merge!"
  (test-equal #(1 2 3 4 5 6)
    (let ((v (make-vector 6)))
      (vector-merge! < v #(1 3 5) #(2 4 6))
      v))
  (test-equal #(0 1 2 3 4 5 6 0)
    (let ((v (make-vector 8 0)))
      (vector-merge! < v #(1 3 5) #(2 4 6) 1)
      v)))

;; list-delete-neighbor-dups
(test-group "list-delete-neighbor-dups"
  (test-equal '() (list-delete-neighbor-dups = '()))
  (test-equal '(1) (list-delete-neighbor-dups = '(1)))
  (test-equal '(1 2 3 4) (list-delete-neighbor-dups = '(1 1 2 3 3 3 4)))
  (test-equal '(1 2 3) (list-delete-neighbor-dups = '(1 2 3)))
  (test-equal '(1) (list-delete-neighbor-dups = '(1 1 1 1))))

;; list-delete-neighbor-dups!
(test-group "list-delete-neighbor-dups!"
  (test-equal '(1 2 3 4) (list-delete-neighbor-dups! = (list 1 1 2 3 3 3 4)))
  (test-equal '() (list-delete-neighbor-dups! = (list)))
  (test-equal '(1) (list-delete-neighbor-dups! = (list 1)))
  (test-equal '(1) (list-delete-neighbor-dups! = (list 1 1 1))))

;; vector-delete-neighbor-dups
(test-group "vector-delete-neighbor-dups"
  (test-equal #() (vector-delete-neighbor-dups = #()))
  (test-equal #(1) (vector-delete-neighbor-dups = #(1)))
  (test-equal #(1 2 3 4) (vector-delete-neighbor-dups = #(1 1 2 3 3 4)))
  (test-equal #(1 2 3) (vector-delete-neighbor-dups = #(1 2 3)))
  (test-equal #(1) (vector-delete-neighbor-dups = #(1 1 1)))
  ;; with subrange
  (test-equal #(1 2) (vector-delete-neighbor-dups = #(9 1 1 2 9) 1 4)))

;; vector-delete-neighbor-dups! returns new end index
(test-group "vector-delete-neighbor-dups!"
  (test-equal 4
    (let ((v (vector 1 1 2 3 3 4)))
      (vector-delete-neighbor-dups! = v)))
  (test-equal 3
    (let ((v (vector 1 2 3)))
      (vector-delete-neighbor-dups! = v)))
  (test-equal 1
    (let ((v (vector 1 1 1)))
      (vector-delete-neighbor-dups! = v)))
  ;; verify elements are compacted
  (test-equal '(1 2 3 4)
    (let ((v (vector 1 1 2 3 3 4)))
      (let ((newend (vector-delete-neighbor-dups! = v)))
        (list (vector-ref v 0) (vector-ref v 1) (vector-ref v 2) (vector-ref v 3))))))

;; vector-select! - k-th smallest (0-indexed)
(test-group "vector-select!"
  (test-equal 1 (vector-select! < (vector 3 1 4 1 5) 0))
  (test-equal 1 (vector-select! < (vector 3 1 4 1 5) 1))
  (test-equal 3 (vector-select! < (vector 3 1 4 1 5) 2))
  (test-equal 5 (vector-select! < (vector 3 1 4 1 5) 4))
  (test-equal 3 (vector-select! < (vector 5 4 3 2 1) 2))
  (test-equal 42 (vector-select! < (vector 42) 0))
  ;; with subrange
  (test-equal 3 (vector-select! < (vector 9 3 1 4 9) 1 1 4)))

;; vector-separate! - k smallest in first k positions
(test-group "vector-separate!"
  (test-equal '(1 2)
    (let ((v (vector 5 3 1 4 2)))
      (vector-separate! < v 2)
      (let ((first-two (list (vector-ref v 0) (vector-ref v 1))))
        (list-sort < first-two))))
  (test-equal '(1 2 3)
    (let ((v (vector 5 3 1 4 2)))
      (vector-separate! < v 3)
      (let ((first-three (list (vector-ref v 0) (vector-ref v 1) (vector-ref v 2))))
        (list-sort < first-three)))))

;; vector-find-median
(test-group "vector-find-median"
  ;; odd length
  (test-equal 3 (vector-find-median < #(3 1 4 1 5) 0))
  ;; even length, no mean
  (test-equal 3 (vector-find-median < #(3 1 4 5) 0))
  ;; even length, with mean
  (test-equal 7/2 (vector-find-median < #(3 1 4 5) 0 (lambda (a b) (/ (+ a b) 2))))
  ;; empty
  (test-equal 'none (vector-find-median < #() 'none))
  ;; single element
  (test-equal 42 (vector-find-median < #(42) 0))
  ;; original not modified
  (test-equal #(3 1 2) (let ((v #(3 1 2))) (vector-find-median < v 0) v)))

;; vector-find-median!
(test-group "vector-find-median!"
  ;; odd length
  (test-equal 3 (vector-find-median! < (vector 3 1 4 1 5) 0))
  ;; even length with mean
  (test-equal 7/2 (vector-find-median! < (vector 3 1 4 5) 0 (lambda (a b) (/ (+ a b) 2))))
  ;; empty
  (test-equal 'none (vector-find-median! < (vector) 'none))
  ;; vector is sorted after call
  (test-equal #(1 2 3) (let ((v (vector 3 1 2))) (vector-find-median! < v 0) v))
  ;; two elements
  (test-equal 1 (vector-find-median! < (vector 2 1) 0))
  (test-equal 3/2 (vector-find-median! < (vector 2 1) 0 (lambda (a b) (/ (+ a b) 2)))))

;; --- Additional edge case tests ---

(test-group "sorted and reverse-sorted input"
  ;; already sorted
  (test-equal '(1 2 3 4 5) (list-sort < '(1 2 3 4 5)))
  (test-equal #(1 2 3 4 5) (vector-sort < #(1 2 3 4 5)))
  ;; reverse sorted
  (test-equal '(1 2 3 4 5 6 7 8 9 10) (list-sort < '(10 9 8 7 6 5 4 3 2 1)))
  (test-equal #(1 2 3 4 5 6 7 8 9 10) (vector-sort < #(10 9 8 7 6 5 4 3 2 1)))
  ;; all equal
  (test-equal '(5 5 5 5 5) (list-sort < '(5 5 5 5 5)))
  (test-equal #(5 5 5 5 5) (vector-sort < #(5 5 5 5 5))))

(test-group "larger inputs"
  ;; 20-element list sort
  (test-equal '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)
    (list-sort < '(17 4 12 8 20 1 15 6 19 3 11 7 16 2 14 9 18 5 13 10)))
  ;; 20-element vector sort
  (test-equal #(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)
    (vector-sort < #(17 4 12 8 20 1 15 6 19 3 11 7 16 2 14 9 18 5 13 10)))
  ;; partially sorted (natural runs)
  (test-equal '(1 2 3 4 5 6 7 8 9 10)
    (list-sort < '(1 2 3 8 9 10 4 5 6 7)))
  (test-equal #(1 2 3 4 5 6 7 8 9 10)
    (vector-sort < #(1 2 3 8 9 10 4 5 6 7))))

(test-group "list-sort! returns proper list"
  (test-equal #t (list? (list-sort! < (list 3 1 2))))
  (test-equal #t (list? (list-sort! < (list))))
  (test-equal #t (list? (list-sort! < (list 1)))))

(test-group "stability across natural runs"
  ;; elements with same key spanning different natural runs
  (test-equal '(a1 a2 b1 b2 c1 c2)
    (map car
      (list-sort (lambda (a b) (string<? (cdr a) (cdr b)))
                 '((a1 . "a") (b1 . "b") (c1 . "c") (a2 . "a") (b2 . "b") (c2 . "c")))))
  ;; vector stability across runs
  (test-equal '(a1 a2 b1 b2)
    (let ((v (vector-sort (lambda (a b) (< (cdr a) (cdr b)))
                          (vector '(a1 . 1) '(b1 . 2) '(a2 . 1) '(b2 . 2)))))
      (vector->list (vector-map car v)))))

(test-group "vector-sort! full range via explicit bounds"
  (test-equal #(1 2 3) (let ((v (vector 3 1 2))) (vector-sort! < v 0 3) v)))

(test-group "vector-select! two-element cases"
  (test-equal 1 (vector-select! < (vector 2 1) 0))
  (test-equal 2 (vector-select! < (vector 2 1) 1)))

(test-group "vector-separate! edge cases"
  ;; k = 0 should be no-op
  (test-equal 5 (let ((v (vector 5 3 1 4 2)))
                  (vector-separate! < v 0)
                  (vector-length v)))
  ;; k = n - all elements should end up sorted-ish
  (test-equal '(1 2 3 4 5)
    (let ((v (vector 5 3 1 4 2)))
      (vector-separate! < v 5)
      (list-sort < (vector->list v)))))

(test-group "list-delete-neighbor-dups additional"
  (test-equal '(1 2) (list-delete-neighbor-dups = '(1 1 1 1 1 2 2 2 2 2)))
  (test-equal '(1 2 1) (list-delete-neighbor-dups = '(1 1 2 2 1 1))))

(test-end "srfi-132")

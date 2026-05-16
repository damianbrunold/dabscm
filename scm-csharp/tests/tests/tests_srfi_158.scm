(import (scheme base)
        (scm test)
        (srfi 158))

(test-runner-factory scm-test-runner)

(test-begin "srfi-158")

;;; Generator constructors

;; generator - basic
(test-group "generator - basic"
  (test-equal '() (generator->list (generator)))
  (test-equal '(1 2 3) (generator->list (generator 1 2 3))))

;; circular + gtake
(test-group "circular-generator"
  (test-equal '(1 2 3 1 2 3 1)
    (generator->list (gtake (circular-generator 1 2 3) 7))))

;; make-iota-generator
(test-group "make-iota-generator"
  (test-equal '(0 1 2 3 4) (generator->list (make-iota-generator 5)))
  (test-equal '(10 11 12 13 14) (generator->list (make-iota-generator 5 10)))
  (test-equal '(0 2 4 6 8) (generator->list (make-iota-generator 5 0 2)))
  (test-equal '() (generator->list (make-iota-generator 0))))

;; make-range-generator
(test-group "make-range-generator"
  (test-equal '(3 4 5 6 7) (generator->list (make-range-generator 3 8)))
  (test-equal '(0 3 6 9) (generator->list (make-range-generator 0 10 3)))
  (test-equal '() (generator->list (make-range-generator 5 5))))

;; make-coroutine-generator
(test-group "make-coroutine-generator"
  (test-equal '(1 2 3)
    (generator->list (make-coroutine-generator
      (lambda (yield) (yield 1) (yield 2) (yield 3)))))
  (test-equal '()
    (generator->list (make-coroutine-generator
      (lambda (yield)))))
  (test-equal '(0 1 2 3 4)
    (generator->list (make-coroutine-generator
      (lambda (yield)
        (let loop ((i 0))
          (when (< i 5) (yield i) (loop (+ i 1)))))))))

;; list->generator
(test-group "list->generator"
  (test-equal '(a b c) (generator->list (list->generator '(a b c))))
  (test-equal '() (generator->list (list->generator '()))))

;; vector->generator
(test-group "vector->generator"
  (test-equal '(a b c d e) (generator->list (vector->generator '#(a b c d e))))
  (test-equal '(c d e) (generator->list (vector->generator '#(a b c d e) 2)))
  (test-equal '(b c) (generator->list (vector->generator '#(a b c d e) 1 3))))

;; reverse-vector->generator
(test-group "reverse-vector->generator"
  (test-equal '(e d c b a)
    (generator->list (reverse-vector->generator '#(a b c d e))))
  (test-equal '(d c b)
    (generator->list (reverse-vector->generator '#(a b c d e) 1 4))))

;; string->generator
(test-group "string->generator"
  (test-equal '(#\a #\b #\c) (generator->list (string->generator "abc")))
  (test-equal '(#\b #\c) (generator->list (string->generator "abcde" 1 3))))

;; bytevector->generator
(test-group "bytevector->generator"
  (test-equal '(10 20 30) (generator->list (bytevector->generator #u8(10 20 30))))
  (test-equal '(20 30)
    (generator->list (bytevector->generator #u8(10 20 30 40 50) 1 3))))

;; make-for-each-generator
(test-group "make-for-each-generator"
  (test-equal '(a b c)
    (generator->list (make-for-each-generator for-each '(a b c)))))

;; make-unfold-generator
(test-group "make-unfold-generator"
  (test-equal '(1 4 9 16 25)
    (generator->list (make-unfold-generator
      (lambda (s) (> s 5))
      (lambda (s) (* s s))
      (lambda (s) (+ s 1))
      1))))

;;; Generator operations

;; gcons*
(test-group "gcons*"
  (test-equal '(a b 1 2 3)
    (generator->list (gcons* 'a 'b (generator 1 2 3)))))

;; gappend
(test-group "gappend"
  (test-equal '(1 2 3 4)
    (generator->list (gappend (generator 1 2) (generator 3 4))))
  (test-equal '(1 2)
    (generator->list (gappend (generator) (generator 1) (generator) (generator 2))))
  (test-equal '() (generator->list (gappend))))

;; gflatten
(test-group "gflatten"
  (test-equal '(1 2 3 4 5)
    (generator->list (gflatten (generator '(1 2) '() '(3 4 5))))))

;; ggroup
(test-group "ggroup"
  (test-equal '((1 2) (3 4) (5))
    (generator->list (ggroup (generator 1 2 3 4 5) 2)))
  (test-equal '((1 2) (3 4) (5 0))
    (generator->list (ggroup (generator 1 2 3 4 5) 2 0)))
  (test-equal '((1 2) (3 4))
    (generator->list (ggroup (generator 1 2 3 4) 2)))
  (test-equal '()
    (generator->list (ggroup (generator) 3))))

;; gmerge
(test-group "gmerge"
  (test-equal '(1 2 3 4 5 6)
    (generator->list (gmerge < (generator 1 3 5) (generator 2 4 6))))
  (test-equal '(1 2 3 4 5 6 7 8 9)
    (generator->list (gmerge < (generator 1 4 7) (generator 2 5 8) (generator 3 6 9))))
  (test-equal '(1 2)
    (generator->list (gmerge < (generator) (generator 1 2)))))

;; gmap
(test-group "gmap"
  (test-equal '(1 4 9 16 25)
    (generator->list (gmap (lambda (x) (* x x)) (generator 1 2 3 4 5))))
  (test-equal '(11 22 33)
    (generator->list (gmap + (generator 1 2 3) (generator 10 20 30))))
  (test-equal '(11 22)
    (generator->list (gmap + (generator 1 2) (generator 10 20 30)))))

;; gcombine
(test-group "gcombine"
  ;; running squares
  (test-equal '(1 4 9 16 25)
    (generator->list (gcombine
      (lambda (x s) (values (* x x) (+ s x)))
      0 (generator 1 2 3 4 5))))
  ;; running sum
  (test-equal '(1 3 6 10 15)
    (generator->list (gcombine
      (lambda (x s) (values (+ x s) (+ x s)))
      0 (generator 1 2 3 4 5)))))

;; gfilter
(test-group "gfilter"
  (test-equal '(1 3 5)
    (generator->list (gfilter odd? (generator 1 2 3 4 5))))
  (test-equal '()
    (generator->list (gfilter even? (generator 1 3 5)))))

;; gremove
(test-group "gremove"
  (test-equal '(2 4)
    (generator->list (gremove odd? (generator 1 2 3 4 5)))))

;; gstate-filter
(test-group "gstate-filter"
  (test-equal '(a c e)
    (generator->list (gstate-filter
      (lambda (s v) (values (+ s 1) (even? s)))
      0 (generator 'a 'b 'c 'd 'e)))))

;; gtake
(test-group "gtake"
  (test-equal '(1 2 3)
    (generator->list (gtake (generator 1 2 3 4 5) 3)))
  (test-equal '(1 2 0 0)
    (generator->list (gtake (generator 1 2) 4 0)))
  (test-equal '()
    (generator->list (gtake (generator 1 2 3) 0))))

;; gdrop
(test-group "gdrop"
  (test-equal '(4 5)
    (generator->list (gdrop (generator 1 2 3 4 5) 3)))
  (test-equal '(1 2 3)
    (generator->list (gdrop (generator 1 2 3) 0)))
  (test-equal '()
    (generator->list (gdrop (generator 1 2) 5))))

;; gtake-while
(test-group "gtake-while"
  (test-equal '(1 2 3)
    (generator->list (gtake-while (lambda (x) (< x 4))
      (generator 1 2 3 4 5)))))

;; gdrop-while
(test-group "gdrop-while"
  (test-equal '(3 4 5)
    (generator->list (gdrop-while (lambda (x) (< x 3))
      (generator 1 2 3 4 5)))))

;; gdelete
(test-group "gdelete"
  (test-equal '(1 2 4 5)
    (generator->list (gdelete 3 (generator 1 2 3 4 3 5)))))

;; gdelete-neighbor-dups
(test-group "gdelete-neighbor-dups"
  (test-equal '(1 2 3 4)
    (generator->list (gdelete-neighbor-dups
      (generator 1 1 2 3 3 3 4))))
  (test-equal '()
    (generator->list (gdelete-neighbor-dups (generator)))))

;; gindex
(test-group "gindex"
  (test-equal '(a c e)
    (generator->list (gindex (generator 'a 'b 'c 'd 'e)
                             (generator 0 2 4)))))

;; gselect
(test-group "gselect"
  (test-equal '(a c e)
    (generator->list (gselect (generator 'a 'b 'c 'd 'e)
                              (generator #t #f #t #f #t)))))

;;; Generator consumers

;; generator->list with k
(test-group "generator->list with k"
  (test-equal '(1 2 3) (generator->list (generator 1 2 3 4 5) 3))
  (test-equal '() (generator->list (generator) 5)))

;; generator->reverse-list
(test-group "generator->reverse-list"
  (test-equal '(3 2 1) (generator->reverse-list (generator 1 2 3)))
  (test-equal '(3 2 1) (generator->reverse-list (generator 1 2 3 4 5) 3)))

;; generator->vector
(test-group "generator->vector"
  (test-equal #(1 2 3) (generator->vector (generator 1 2 3)))
  (test-equal #(1 2 3) (generator->vector (generator 1 2 3 4 5) 3))
  (test-equal #() (generator->vector (generator))))

;; generator->vector!
(test-group "generator->vector!"
  (test-equal #(0 a b c 0)
    (let ((v (make-vector 5 0)))
      (generator->vector! v 1 (generator 'a 'b 'c))
      v))
  (test-equal 3 (generator->vector! (make-vector 5 0) 0 (generator 1 2 3))))

;; generator->string
(test-group "generator->string"
  (test-equal "abc" (generator->string (generator #\a #\b #\c)))
  (test-equal "abc" (generator->string (generator #\a #\b #\c #\d #\e) 3)))

;; generator-fold
(test-group "generator-fold"
  (test-equal 15 (generator-fold + 0 (generator 1 2 3 4 5)))
  (test-equal '(3 2 1) (generator-fold cons '() (generator 1 2 3)))
  (test-equal 0 (generator-fold + 0 (generator))))

;; generator-for-each
(test-group "generator-for-each"
  (test-equal 15
    (let ((sum 0))
      (generator-for-each (lambda (x) (set! sum (+ sum x)))
        (generator 1 2 3 4 5))
      sum)))

;; generator-map->list
(test-group "generator-map->list"
  (test-equal '(1 4 9 16 25)
    (generator-map->list (lambda (x) (* x x)) (generator 1 2 3 4 5)))
  (test-equal '(11 22 33)
    (generator-map->list + (generator 1 2 3) (generator 10 20 30))))

;; generator-find
(test-group "generator-find"
  (test-equal 6 (generator-find even? (generator 1 3 5 6 7)))
  (test-equal #f (generator-find even? (generator 1 3 5))))

;; generator-count
(test-group "generator-count"
  (test-equal 2 (generator-count even? (generator 1 2 3 4 5))))

;; generator-any
(test-group "generator-any"
  (test-equal #t (generator-any odd? (generator 2 4 6 7 8)))
  (test-equal #f (generator-any odd? (generator 2 4 6))))

;; generator-every
(test-group "generator-every"
  (test-equal #t (generator-every odd? (generator 1 3 5 7)))
  (test-equal #f (generator-every odd? (generator 1 3 4 5)))
  (test-equal #t (generator-every odd? (generator))))

;;; Accumulators

;; make-accumulator
(test-group "make-accumulator"
  (test-equal '(1 2 3)
    (let ((a (make-accumulator cons '() reverse)))
      (a 1) (a 2) (a 3) (a (eof-object)))))

;; count-accumulator
(test-group "count-accumulator"
  (test-equal 3
    (let ((a (count-accumulator)))
      (a 'x) (a 'y) (a 'z) (a (eof-object)))))

;; list-accumulator
(test-group "list-accumulator"
  (test-equal '(1 2 3)
    (let ((a (list-accumulator)))
      (a 1) (a 2) (a 3) (a (eof-object)))))

;; reverse-list-accumulator
(test-group "reverse-list-accumulator"
  (test-equal '(3 2 1)
    (let ((a (reverse-list-accumulator)))
      (a 1) (a 2) (a 3) (a (eof-object)))))

;; vector-accumulator
(test-group "vector-accumulator"
  (test-equal #(1 2 3)
    (let ((a (vector-accumulator)))
      (a 1) (a 2) (a 3) (a (eof-object)))))

;; reverse-vector-accumulator
(test-group "reverse-vector-accumulator"
  (test-equal #(3 2 1)
    (let ((a (reverse-vector-accumulator)))
      (a 1) (a 2) (a 3) (a (eof-object)))))

;; vector-accumulator!
(test-group "vector-accumulator!"
  (test-equal #(0 a b c 0)
    (let* ((v (make-vector 5 0))
           (a (vector-accumulator! v 1)))
      (a 'a) (a 'b) (a 'c) (a (eof-object)))))

;; string-accumulator
(test-group "string-accumulator"
  (test-equal "abc"
    (let ((a (string-accumulator)))
      (a #\a) (a #\b) (a #\c) (a (eof-object)))))

;; bytevector-accumulator
(test-group "bytevector-accumulator"
  (test-equal #u8(1 2 3)
    (let ((a (bytevector-accumulator)))
      (a 1) (a 2) (a 3) (a (eof-object)))))

;; bytevector-accumulator!
(test-group "bytevector-accumulator!"
  (test-equal #u8(0 10 20 30 0)
    (let* ((bv (make-bytevector 5 0))
           (a (bytevector-accumulator! bv 1)))
      (a 10) (a 20) (a 30) (a (eof-object)))))

;; sum-accumulator
(test-group "sum-accumulator"
  (test-equal 15
    (let ((a (sum-accumulator)))
      (a 1) (a 2) (a 3) (a 4) (a 5) (a (eof-object)))))

;; product-accumulator
(test-group "product-accumulator"
  (test-equal 24
    (let ((a (product-accumulator)))
      (a 1) (a 2) (a 3) (a 4) (a (eof-object)))))

;;; Integration tests

;; pipeline: filter -> map -> list
(test-group "pipeline: filter -> map -> list"
  (test-equal '(1 9 25 49 81)
    (generator->list
      (gmap (lambda (x) (* x x))
        (gfilter odd? (list->generator '(1 2 3 4 5 6 7 8 9 10)))))))

;; ggroup then gflatten is identity
(test-group "ggroup then gflatten is identity"
  (test-equal '(1 2 3 4 5 6)
    (generator->list
      (gflatten (ggroup (generator 1 2 3 4 5 6) 2)))))

(test-end "srfi-158")

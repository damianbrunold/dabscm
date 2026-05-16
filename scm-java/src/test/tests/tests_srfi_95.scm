(import (scheme base)
        (scm test)
        (srfi 95))

(test-runner-factory scm-test-runner)

(test-begin "srfi-95")

;; sorted? - lists
(test-group "sorted-lists"
  (test-equal #t (sorted? '() <))
  (test-equal #t (sorted? '(1) <))
  (test-equal #t (sorted? '(1 2 3) <))
  (test-equal #t (sorted? '(1 1 2) <))
  (test-equal #f (sorted? '(3 1 2) <))
  (test-equal #f (sorted? '(1 3 2) <))
  (test-equal #t (sorted? '(3 2 1) >))
  (test-equal #t (sorted? '("a" "b" "c") string<?))
  (test-equal #f (sorted? '("b" "a" "c") string<?)))

;; sorted? - vectors
(test-group "sorted-vectors"
  (test-equal #t (sorted? #() <))
  (test-equal #t (sorted? #(1) <))
  (test-equal #t (sorted? #(1 2 3) <))
  (test-equal #f (sorted? #(3 1 2) <))
  (test-equal #t (sorted? #(1 1 2) <)))

;; sorted? - strings
(test-group "sorted-strings"
  (test-equal #t (sorted? "" char<?))
  (test-equal #t (sorted? "a" char<?))
  (test-equal #t (sorted? "abc" char<?))
  (test-equal #f (sorted? "cba" char<?))
  (test-equal #t (sorted? "aab" char<?)))

;; sorted? - with key
(test-group "sorted-key"
  (test-equal #t (sorted? '((a . 1) (b . 2) (c . 3)) < cdr))
  (test-equal #f (sorted? '((a . 3) (b . 1) (c . 2)) < cdr))
  (test-equal #t (sorted? #((a . 1) (b . 2) (c . 3)) < cdr))
  (test-equal #f (sorted? "cab" < char->integer))
  (test-equal #t (sorted? "abc" < char->integer)))

;; sort - lists
(test-group "sort-lists"
  (test-equal '() (sort '() <))
  (test-equal '(1) (sort '(1) <))
  (test-equal '(1 1 3 4 5 9) (sort '(3 1 4 1 5 9) <))
  (test-equal '(9 5 4 3 1 1) (sort '(3 1 4 1 5 9) >))
  (test-equal '("apple" "banana" "cherry") (sort '("banana" "apple" "cherry") string<?)))

;; sort - vectors
(test-group "sort-vectors"
  (test-equal #() (sort #() <))
  (test-equal #(1) (sort #(1) <))
  (test-equal #(1 1 3 4 5) (sort #(3 1 4 1 5) <))
  (test-equal #(3 2 1) (sort #(3 1 2) >))
  ;; original not modified
  (test-equal #(3 1 2) (let ((v #(3 1 2))) (sort v <) v)))

;; sort - strings
(test-group "sort-strings"
  (test-equal "" (sort "" char<?))
  (test-equal "a" (sort "a" char<?))
  (test-equal "abc" (sort "cab" char<?))
  (test-equal "uvwxyz" (sort "zyxwvu" char<?))
  (test-equal "ehllo" (sort "hello" char<?)))

;; sort - with key function
(test-group "sort-key"
  (test-equal '((b . 1) (a . 2) (c . 3)) (sort '((a . 2) (b . 1) (c . 3)) < cdr))
  (test-equal #((b . 1) (a . 2) (c . 3)) (sort #((a . 2) (b . 1) (c . 3)) < cdr))
  (test-equal '("fig" "kiwi" "apple" "banana") (sort '("banana" "fig" "apple" "kiwi") < string-length)))

;; sort - stability with 5+ elements
(test-group "sort-stability"
  (test-equal '(a b c d e)
    (map car (sort '((a . 1) (b . 1) (c . 1) (d . 1) (e . 1)) < cdr)))
  (test-equal '(b d f a c e g)
    (map car (sort '((a . 2) (b . 1) (c . 2) (d . 1) (e . 2) (f . 1) (g . 2))
                   < cdr)))
  ;; 8 elements, all equal keys
  (test-equal '(a b c d e f g h)
    (map car (sort '((a . 1) (b . 1) (c . 1) (d . 1) (e . 1) (f . 1) (g . 1) (h . 1))
                   < cdr)))
  ;; stability with key function and 7 elements
  (test-equal '(b d g a e c f)
    (map car (sort '((a . 2) (b . 1) (c . 3) (d . 1) (e . 2) (f . 3) (g . 1))
                   < cdr))))

;; sort - vector stability with 5+ elements
(test-group "sort-vector-stability"
  (test-equal '(b d f a c e g)
    (vector->list
      (vector-map car
        (sort (vector '(a . 2) '(b . 1) '(c . 2) '(d . 1) '(e . 2) '(f . 1) '(g . 2))
              < cdr)))))

;; sort! - lists
(test-group "sort!-lists"
  (test-equal '(1 1 3 4 5) (sort! (list 3 1 4 1 5) <))
  (test-equal '() (sort! (list) <))
  (test-equal '(1) (sort! (list 1) <)))

;; sort! - vectors (in-place)
(test-group "sort!-vectors"
  (test-equal #(1 1 3 4 5) (let ((v (vector 3 1 4 1 5))) (sort! v <) v))
  (test-equal #(1 2 3 4 5) (let ((v (vector 5 4 3 2 1))) (sort! v <) v))
  (test-equal #(1 2 3) (let ((v (vector 1 2 3))) (sort! v <) v)))

;; sort! - strings
(test-group "sort!-strings"
  (test-equal "abc" (sort! "cab" char<?))
  (test-equal "" (sort! "" char<?)))

;; sort! - with key
(test-group "sort!-key"
  (test-equal '((b . 1) (a . 2) (c . 3)) (sort! (list '(a . 2) '(b . 1) '(c . 3)) < cdr))
  (test-equal #((b . 1) (a . 2) (c . 3))
    (let ((v (vector '(a . 2) '(b . 1) '(c . 3)))) (sort! v < cdr) v)))

;; merge
(test-group "merge"
  (test-equal '(1 2 3 4 5 6) (merge '(1 3 5) '(2 4 6) <))
  (test-equal '(1 2 3) (merge '() '(1 2 3) <))
  (test-equal '(1 2 3) (merge '(1 2 3) '() <))
  (test-equal '() (merge '() '() <))
  (test-equal '(1 2 2 3) (merge '(1 2) '(2 3) <))
  (test-equal '(1 1 1 1 1) (merge '(1 1 1) '(1 1) <)))

;; merge - with key
(test-group "merge-key"
  (test-equal '((a . 1) (c . 2) (b . 3) (d . 4))
    (merge '((a . 1) (b . 3)) '((c . 2) (d . 4)) < cdr))
  ;; stability: equal keys preserve list1-before-list2 order
  (test-equal '((a . 1) (c . 1) (b . 2) (d . 2))
    (merge '((a . 1) (b . 2)) '((c . 1) (d . 2)) < cdr)))

;; merge!
(test-group "merge!"
  (test-equal '(1 2 3 4 5 6) (merge! (list 1 3 5) (list 2 4 6) <))
  (test-equal '(1 2 3) (merge! (list) (list 1 2 3) <))
  (test-equal '(1 2 3) (merge! (list 1 2 3) (list) <))
  (test-equal '() (merge! (list) (list) <))
  (test-equal '(1 2 2 3) (merge! (list 1 2) (list 2 3) <)))

;; merge! - with key
(test-group "merge!-key"
  (test-equal '((a . 1) (c . 2) (b . 3) (d . 4))
    (merge! (list '(a . 1) '(b . 3)) (list '(c . 2) '(d . 4)) < cdr)))

(test-end "srfi-95")

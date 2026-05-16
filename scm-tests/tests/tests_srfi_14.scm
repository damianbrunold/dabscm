(import (scheme base)
        (scheme char)
        (scm test)
        (srfi 14))

(test-runner-factory scm-test-runner)

(test-begin "srfi-14")

(test-group "Construction and membership"
  (test-equal #t (char-set-contains? (char-set #\a #\b #\c) #\b))
  (test-equal #f (char-set-contains? (char-set #\a #\b #\c) #\d))
  (test-equal #t (char-set? char-set:letter))
  (test-equal #f (char-set? "not a char-set")))

(test-group "Equality / Subset"
  (test-equal #t (char-set= (char-set #\a #\b) (char-set #\b #\a)))
  (test-equal #f (char-set= (char-set #\a) (char-set #\b)))
  (test-equal #t (char-set<= (char-set #\a) (char-set #\a #\b)))
  (test-equal #f (char-set<= (char-set #\a #\b) (char-set #\a))))

(test-group "Set operations"
  (test-equal #t (char-set-contains? (char-set-adjoin (char-set #\a) #\b #\c) #\b))
  (test-equal #f (char-set-contains? (char-set-delete (char-set #\a #\b #\c) #\b) #\b))
  (test-equal #t (char-set-contains? (char-set-complement (char-set #\a #\b)) #\c))
  (test-equal #f (char-set-contains? (char-set-complement (char-set #\a #\b)) #\a)))

(test-group "Union, intersection, difference"
  (test-equal #t (char-set-contains? (char-set-union (char-set #\a #\b) (char-set #\c #\d)) #\c))
  (test-equal #t (char-set-contains? (char-set-intersection (char-set #\a #\b #\c) (char-set #\b #\c #\d)) #\b))
  (test-equal #f (char-set-contains? (char-set-intersection (char-set #\a #\b #\c) (char-set #\b #\c #\d)) #\a))
  (test-equal #t (char-set-contains? (char-set-difference (char-set #\a #\b #\c) (char-set #\b #\c)) #\a))
  (test-equal #f (char-set-contains? (char-set-difference (char-set #\a #\b #\c) (char-set #\b #\c)) #\b)))

(test-group "Xor and diff+intersection"
  (test-equal #t (char-set= (char-set-xor (char-set #\a #\b) (char-set #\b #\c))
                       (char-set #\a #\c)))
  (test-equal '((#\a) (#\b #\c))
        (call-with-values
          (lambda ()
            (char-set-diff+intersection (char-set #\a #\b #\c) (char-set #\b #\c #\d)))
          (lambda (diff inter)
            (list (char-set->list diff) (char-set->list inter))))))

(test-group "Fold, for-each, map"
  (test-equal 3 (char-set-fold (lambda (c acc) (+ acc 1)) 0 (char-set #\a #\b #\c)))
  (test-equal 3 (char-set-size (char-set #\a #\b #\c)))
  (test-equal 26 (char-set-count char-upper-case? char-set:letter)))

(test-group "every / any"
  (test-equal #t (char-set-every char-alphabetic? (char-set #\a #\b #\c)))
  (test-equal #f (char-set-every char-alphabetic? (char-set #\a #\1)))
  (test-equal #t (char-set-any char-upper-case? (char-set #\a #\B #\c)))
  (test-equal #f (char-set-any char-upper-case? (char-set #\a #\b #\c))))

(test-group "Conversion"
  (test-equal '(#\a #\b #\c) (char-set->list (char-set #\a #\b #\c)))
  (test-equal #t (char-set-contains? (list->char-set '(#\a #\b #\c)) #\b))
  (test-equal #t (char-set-contains? (string->char-set "abc") #\b))
  (test-equal #t (char-set-contains? (->char-set "abc") #\b))
  (test-equal #t (char-set-contains? (->char-set #\a) #\a)))

(test-group "Cursors"
  (test-equal #t (end-of-char-set? (char-set-cursor char-set:empty)))
  (test-equal #\a (let* ((cs (char-set #\a))
                   (cur (char-set-cursor cs)))
              (char-set-ref cs cur))))

(test-group "Unfold and ucs-range"
  (test-equal #t (char-set-contains?
             (char-set-unfold (lambda (x) (> x 5))
                              integer->char
                              (lambda (x) (+ x 1))
                              0)
             (integer->char 3)))
  (test-equal 26 (char-set-size (ucs-range->char-set 65 91)))
  (test-equal #t (char-set-contains? (ucs-range->char-set 65 91) #\A)))

(test-group "Predefined sets"
  (test-equal #t (char-set-contains? char-set:letter #\a))
  (test-equal #f (char-set-contains? char-set:letter #\1))
  (test-equal #t (char-set-contains? char-set:digit #\5))
  (test-equal #t (char-set-contains? char-set:whitespace #\space))
  (test-equal #t (char-set-contains? char-set:upper-case #\A))
  (test-equal #t (char-set-contains? char-set:lower-case #\a))
  (test-equal #t (char-set-contains? char-set:hex-digit #\f))
  (test-equal #f (char-set-contains? char-set:hex-digit #\g))
  (test-equal #f (char-set-contains? char-set:empty #\a))
  (test-equal #t (char-set-contains? char-set:full #\a)))

(test-end "srfi-14")

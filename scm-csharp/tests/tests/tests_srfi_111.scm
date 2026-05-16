(import (scheme base)
        (scm test)
        (srfi 111))

(test-runner-factory scm-test-runner)

(test-begin "srfi-111")

;; box construction and predicate
(test-assert (box? (box 42)))
(test-equal #f (box? 42))
(test-equal #f (box? '()))

;; unbox
(test-equal 42 (unbox (box 42)))
(test-equal "hello" (unbox (box "hello")))
(test-equal '(1 2 3) (unbox (box '(1 2 3))))

;; set-box! mutates the box
(test-group "set-box!"
  (define b (box 10))
  (test-equal 10 (unbox b))
  (test-equal 20 (begin (set-box! b 20) (unbox b)))
  (test-equal '(a b c) (begin (set-box! b '(a b c)) (unbox b))))

;; box with boolean and null
(test-equal #t (unbox (box #t)))
(test-equal #f (unbox (box #f)))
(test-equal '() (unbox (box '())))

(test-end "srfi-111")

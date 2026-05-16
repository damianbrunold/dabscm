(import (scheme base) (scheme write) (srfi 64))

;; Test runner creation and predicates
(test-group
  (=> (test-runner? (test-runner-simple)) #t)
  (=> (test-runner? (test-runner-null)) #t)
  (=> (test-runner? 42) #f)
  (=> (test-runner? "hello") #f))

;; Test runner initial state
(test-group
  (define r (test-runner-null))
  (=> (test-runner-pass-count r) 0)
  (=> (test-runner-fail-count r) 0)
  (=> (test-runner-xfail-count r) 0)
  (=> (test-runner-xpass-count r) 0)
  (=> (test-runner-skip-count r) 0)
  (=> (test-runner-test-name r) "")
  (=> (test-runner-group-stack r) '())
  (=> (test-runner-group-path r) '()))

;; test-begin pushes and test-end pops
(test-group
  (define r (test-runner-null))
  (define stack-after-begin #f)
  (define path-after-begin #f)
  (define stack-after-nested #f)
  (define path-after-nested #f)
  (define stack-after-inner-end #f)
  (parameterize ((test-runner-current r))
    (test-begin "outer")
    (set! stack-after-begin (test-runner-group-stack r))
    (set! path-after-begin (test-runner-group-path r))
    (test-begin "inner")
    (set! stack-after-nested (test-runner-group-stack r))
    (set! path-after-nested (test-runner-group-path r))
    (test-end "inner")
    (set! stack-after-inner-end (test-runner-group-stack r))
    (test-end "outer"))
  (=> stack-after-begin '("outer"))
  (=> path-after-begin '("outer"))
  (=> stack-after-nested '("inner" "outer"))
  (=> path-after-nested '("outer" "inner"))
  (=> stack-after-inner-end '("outer"))
  (=> (test-runner-group-stack r) '()))

;; test macro - passing tests
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "basics")
    (test-equal 7 (+ 3 4))
    (test-equal 'a (car '(a b c)))
    (test-equal '(1 2 3) (list 1 2 3))
    (test-end "basics"))
  (=> (test-runner-pass-count r) 3)
  (=> (test-runner-fail-count r) 0))

;; test macro - failing test
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "fail")
    (test-equal 7 (+ 3 3))
    (test-end "fail"))
  (=> (test-runner-pass-count r) 0)
  (=> (test-runner-fail-count r) 1))

;; test with name
;; TODO disabled
#;(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "named")
    (test-equal "addition" 7 (+ 3 4))
    (test-end "named"))
  (=> (test-runner-pass-count r) 1)
  (=> (test-runner-test-name r) "addition"))

;; test-assert
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "assert")
    (test-assert (> 3 2))
    (test-assert (< 3 2))
    (test-assert "named-assert" (> 10 5))
    (test-end "assert"))
  (=> (test-runner-pass-count r) 2)
  (=> (test-runner-fail-count r) 1))

;; test-equal, test-eqv, test-eq
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "comparators")
    (test-equal '(1 2 3) (list 1 2 3))
    (test-eqv 42 42)
    (test-eq #t #t)
    (test-end "comparators"))
  (=> (test-runner-pass-count r) 3))

;; test-approximate
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "approximate")
    (test-approximate 3.14 3.14159 0.01)
    (test-approximate 3.14 3.2 0.01)
    (test-end "approximate"))
  (=> (test-runner-pass-count r) 1)
  (=> (test-runner-fail-count r) 1))

;; test-error
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "errors")
    (test-error (error "boom"))
    (test-error (+ 1 2))
    (test-end "errors"))
  (=> (test-runner-pass-count r) 1)
  (=> (test-runner-fail-count r) 1))

;; test-skip
;; TODO disabled
#;(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "skip")
    (test-skip (test-match-nth 0 1))
    (test-equal 7 (+ 3 4))
    (test-equal 8 (+ 3 5))
    (test-end "skip"))
  (=> (test-runner-skip-count r) 1)
  (=> (test-runner-pass-count r) 1))

;; test-expect-fail
;; TODO disabled
#;(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "xfail")
    (test-expect-fail (test-match-nth 0 1))
    (test-equal 999 (+ 3 4))
    (test-end "xfail"))
  (=> (test-runner-xfail-count r) 1)
  (=> (test-runner-fail-count r) 0))

;; test-expect-fail with unexpected pass (xpass)
;; TODO disabled
#;(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "xpass")
    (test-expect-fail (test-match-nth 0 1))
    (test-equal 7 (+ 3 4))
    (test-end "xpass"))
  (=> (test-runner-xpass-count r) 1)
  (=> (test-runner-pass-count r) 0))

;; test-group macro
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "isolation")
    (test-group "inner"
      (define x 42)
      (test-equal 42 x))
    (test-end "isolation"))
  (=> (test-runner-pass-count r) 1))

;; test-result-kind
(test-group
  (define r (test-runner-null))
  (define kind-after-pass #f)
  (define kind-after-fail #f)
  (parameterize ((test-runner-current r))
    (test-begin "result-kind")
    (test-equal 7 (+ 3 4))
    (set! kind-after-pass (test-result-kind r))
    (test-equal 999 (+ 3 4))
    (set! kind-after-fail (test-result-kind r))
    (test-end "result-kind"))
  (=> kind-after-pass 'pass)
  (=> kind-after-fail 'fail))

;; test-passed?
;; TODO disabled
#;(test-group
  (define r (test-runner-null))
  (define passed-after-pass #f)
  (define passed-after-fail #f)
  (parameterize ((test-runner-current r))
    (test-begin "passed?")
    (test-equal 7 (+ 3 4))
    (set! passed-after-pass (test-passed? r))
    (test-equal 999 (+ 3 4))
    (set! passed-after-fail (test-passed? r))
    (test-end "passed?"))
  (=> passed-after-pass #t)
  (=> passed-after-fail #f))

;; test handles exceptions in expr
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "exception-in-expr")
    (test-equal 42 (error "oops"))
    (test-end "exception-in-expr"))
  (=> (test-runner-fail-count r) 1)
  (=> (test-runner-pass-count r) 0))

;; test-with-runner
(test-group
  (define r (test-runner-null))
  (test-with-runner r
    (test-begin "with-runner")
    (test-equal 7 (+ 3 4))
    (test-end "with-runner"))
  (=> (test-runner-pass-count r) 1))

;; test-runner-factory
(test-group
  (=> (procedure? (test-runner-factory)) #t)
  (=> (test-runner? ((test-runner-factory))) #t))

;; test-match-name
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "match-name")
    (test-skip (test-match-name "skip-me"))
    (test-equal "skip-me" 7 (+ 3 4))
    (test-equal "keep-me" 7 (+ 3 4))
    (test-end "match-name"))
  (=> (test-runner-skip-count r) 1)
  (=> (test-runner-pass-count r) 1))

;; Counter tracking
(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "counter-tracking")
    (test-equal 1 1)
    (test-equal 2 2)
    (test-equal 3 3)
    (test-equal 4 4)
    (test-equal 5 5)
    (test-equal 999 0)
    (test-end "counter-tracking"))
  (=> (test-runner-pass-count r) 5)
  (=> (test-runner-fail-count r) 1))

;; test-error with named test
;; TODO disabled
#;(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "named-error")
    (test-error "should-error" #t (error "boom"))
    (test-end "named-error"))
  (=> (test-runner-pass-count r) 1)
  (=> (test-runner-test-name r) "should-error"))

;; test-result-ref
;; TODO disabled
#;(test-group
  (define r (test-runner-null))
  (parameterize ((test-runner-current r))
    (test-begin "result-ref")
    (test-equal 7 (+ 3 4))
    (test-end "result-ref"))
  (=> (test-result-ref r 'expected-value) 7))

;; Auto-create runner: verify test-begin creates a runner when none exists.
;; Use a null runner factory to avoid printing a summary to stdout.
(test-group
  (define created-runner #f)
  (parameterize ((test-runner-current #f)
                 (test-runner-factory test-runner-null))
    (test-begin "auto-create")
    (set! created-runner (test-runner-current))
    (test-equal 7 (+ 3 4))
    (test-end "auto-create"))
  (=> (test-runner? created-runner) #t))

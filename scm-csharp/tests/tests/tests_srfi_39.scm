(import (scheme base)
        (scm test)
        (srfi 39))

(test-runner-factory scm-test-runner)

(test-begin "srfi-39")

(test-group "basic"
  (define p (make-parameter 10))
  (test-equal 10 (p))
  (test-equal 20 (parameterize ((p 20)) (p)))
  (test-equal 10 (p)))

(test-group "nested"
  (define q (make-parameter 1))
  (test-equal 3 (parameterize ((q 2))
            (parameterize ((q 3))
              (q))))
  (test-equal 2 (parameterize ((q 2))
            (parameterize ((q 3))
              (q))
            (q)))
  (test-equal 1 (q)))

(test-group "continuation-escape"
  (define r (make-parameter 100))
  (test-equal 'escaped
    (call-with-current-continuation
      (lambda (k)
        (parameterize ((r 999))
          (k 'escaped))
        (r)))))

(test-group "converter"
  (define pos (make-parameter -5 abs))
  (test-equal 5 (pos))
  (test-equal 10 (parameterize ((pos -10)) (pos))))

(test-group "multiple-params"
  (define a (make-parameter 1))
  (define b (make-parameter 2))
  (test-equal 30 (parameterize ((a 10) (b 20))
             (+ (a) (b))))
  (test-equal '(1 2) (list (a) (b))))

(test-end "srfi-39")

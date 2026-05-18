(import (scheme base)
        (scm test)
        (srfi 18)
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

;; Regression for the threading-shared-bindings rework: parameters must
;; be per-thread so parameterize's prologue/epilogue can't race across
;; threads. Pre-fix, `val` lived inside a closure environment shared
;; across every thread, and concurrent parameterize would clobber each
;; other's restore values. See notes/threading-shared-bindings.md.
(test-group "parameterize is per-thread"
  (define tp (make-parameter 100))
  (define m (make-mutex))
  (define seen '())
  (define ts
    (map (lambda (i)
           (let ((my-val (* (+ i 1) 10)))
             (let ((t (make-thread
                        (lambda ()
                          (parameterize ((tp my-val))
                            (thread-sleep! 0.03)
                            (mutex-lock! m)
                            (set! seen (cons (tp) seen))
                            (mutex-unlock! m))))))
               (thread-start! t) t)))
         '(0 1 2 3)))
  (for-each thread-join! ts)
  ;; Each thread observes its own parameterized value.
  (test-equal '(10 20 30 40)
    (let sort ((xs seen))
      (cond ((or (null? xs) (null? (cdr xs))) xs)
            (else (let ((m (apply min xs)))
                    (cons m (sort (let drop ((ys xs))
                                    (cond ((null? ys) '())
                                          ((= (car ys) m) (cdr ys))
                                          (else (cons (car ys) (drop (cdr ys)))))))))))))
  ;; Primordial thread's view of the parameter is unaffected.
  (test-equal 100 (tp)))

(test-end "srfi-39")

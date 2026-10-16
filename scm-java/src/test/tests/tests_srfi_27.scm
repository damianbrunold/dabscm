(import (scheme base)
        (scheme read)
        (scheme write)
        (scm test)
        (srfi 27))

(test-runner-factory scm-test-runner)

(test-begin "srfi-27")

(define (write->read obj)
  (let ((out (open-output-string)))
    (write obj out)
    (read (open-input-string (get-output-string out)))))

(define (draw-list rand n k)
  (let loop ((i 0) (acc '()))
    (if (= i k) (reverse acc) (loop (+ i 1) (cons (rand n) acc)))))

(test-group "random sources"
  (test-assert (random-source? default-random-source))
  (test-assert (random-source? (make-random-source)))
  (test-assert (not (random-source? 42)))
  (test-assert (not (random-source? (vector 1 2 3)))))

;; Values computed independently from the MRG32k3a definition (L'Ecuyer)
;; and the reference implementation's initial state A^16.
(test-group "reference sequence"
  (let ((s (make-random-source)))
    (test-equal '(lecuyer-mrg32k3a 1062452522 2961816100 342112271
                                   2854655037 3321940838 3542344109)
                (random-source-state-ref s))
    (test-equal '(85 28 73) (draw-list (random-source-make-integers s) 100 3))))

(test-group "random-integer"
  (test-assert (let loop ((i 0))
                 (or (= i 1000)
                     (and (< -1 (random-integer 10) 10) (loop (+ i 1))))))
  (test-equal 0 (random-integer 1))
  (test-assert (exact-integer? (random-integer 4294967087)))
  ;; bignum range
  (let ((big (expt 10 40)))
    (test-assert (let loop ((i 0))
                   (or (= i 100)
                       (let ((x (random-integer big)))
                         (and (exact-integer? x) (<= 0 x) (< x big)
                              (loop (+ i 1)))))))
    ;; values above the generator's range m1 must actually occur
    (test-assert (let loop ((i 0))
                   (and (< i 100)
                        (or (> (random-integer big) 4294967087)
                            (loop (+ i 1)))))))
  (test-error (random-integer 0))
  (test-error (random-integer -5))
  (test-error (random-integer 2.0))
  ;; every value of a small range shows up
  (let ((seen (make-vector 6 #f)))
    (do ((i 0 (+ i 1))) ((= i 600))
      (vector-set! seen (random-integer 6) #t))
    (test-equal #(#t #t #t #t #t #t) seen)))

(test-group "random-real"
  (test-assert (let loop ((i 0))
                 (or (= i 1000)
                     (let ((x (random-real)))
                       (and (inexact? x) (< 0 x 1) (loop (+ i 1)))))))
  (let ((sum (let loop ((i 0) (sum 0.0))
               (if (= i 10000) sum (loop (+ i 1) (+ sum (random-real)))))))
    (test-assert (< 0.48 (/ sum 10000) 0.52))))

(test-group "random-source-make-reals with unit"
  (let ((s (make-random-source)))
    (let ((coarse (random-source-make-reals s 0.1))
          (fine (random-source-make-reals s 1e-20)))
      (test-assert (< 0 (coarse) 1))
      (test-assert (let loop ((i 0))
                     (or (= i 100)
                         (let ((x (fine)))
                           (and (< 0 x 1) (loop (+ i 1))))))))
    (test-error (random-source-make-reals s 0))
    (test-error (random-source-make-reals s 1))
    (test-error (random-source-make-reals s 1.5))))

(test-group "state save and restore"
  (let* ((s (make-random-source))
         (rand (random-source-make-integers s)))
    (rand 100)
    (let* ((state (random-source-state-ref s))
           (a (draw-list rand 1000000 5)))
      (random-source-state-set! s state)
      (test-equal a (draw-list rand 1000000 5))
      ;; the external state survives write/read
      (random-source-state-set! s (write->read state))
      (test-equal a (draw-list rand 1000000 5))
      ;; a state can be transferred to another source
      (let ((t (make-random-source)))
        (random-source-state-set! t state)
        (test-equal a (draw-list (random-source-make-integers t) 1000000 5)))))
  (let ((s (make-random-source)))
    (test-error (random-source-state-set! s 'nonsense))
    (test-error (random-source-state-set! s '(lecuyer-mrg32k3a 0 0 0 1 1 1)))
    (test-error (random-source-state-set! s '(lecuyer-mrg32k3a 1 1 1 1 1)))
    (test-error (random-source-state-set! s '(lecuyer-mrg32k3a 4294967087 1 1 1 1 1)))
    (test-error (random-source-state-set! s '(other 1 1 1 1 1 1)))))

(test-group "generators share the source state"
  (let* ((s (make-random-source))
         (r1 (random-source-make-integers s))
         (r2 (random-source-make-integers s))
         (t (make-random-source))
         (r3 (random-source-make-integers t)))
    (let* ((a (r1 1000000))
           (b (r2 1000000)))
      (test-equal (list a b) (list (r3 1000000) (r3 1000000))))))

(test-group "pseudo-randomize!"
  (let ((a (make-random-source))
        (b (make-random-source)))
    (random-source-pseudo-randomize! a 1 2)
    (test-equal '(lecuyer-mrg32k3a 1250826159 3004357423 431373563
                                   3322526864 623307378 2983662421)
                (random-source-state-ref a))
    (random-source-pseudo-randomize! b 1 2)
    (test-equal (draw-list (random-source-make-integers a) 1000000 10)
                (draw-list (random-source-make-integers b) 1000000 10))
    ;; different (i, j) give different streams
    (random-source-pseudo-randomize! a 0 0)
    (random-source-pseudo-randomize! b 0 1)
    (test-assert (not (equal? (random-source-state-ref a)
                              (random-source-state-ref b))))
    ;; (0, 0) is the initial state of a fresh source
    (test-equal (random-source-state-ref (make-random-source))
                (random-source-state-ref a))
    (test-error (random-source-pseudo-randomize! a -1 0))
    (test-error (random-source-pseudo-randomize! a 0 1.5))))

(test-group "randomize!"
  (let ((a (make-random-source))
        (b (make-random-source)))
    (random-source-randomize! a)
    (random-source-randomize! b)
    (test-assert (not (equal? (random-source-state-ref a)
                              (random-source-state-ref b))))
    (test-assert (not (equal? (random-source-state-ref a)
                              (random-source-state-ref (make-random-source)))))
    ;; the randomized state is valid
    (let ((c (make-random-source)))
      (random-source-state-set! c (random-source-state-ref a))
      (test-assert (< ((random-source-make-reals c)) 1)))))

(test-end "srfi-27")

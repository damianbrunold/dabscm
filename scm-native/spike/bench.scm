;; The spike benchmarks on the JVM/.NET implementations, for comparison.
(import (scheme base) (scheme write) (scheme time))

(define (fib n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
(define (tak x y z) (if (not (< y x)) z
  (tak (tak (- x 1) y z) (tak (- y 1) z x) (tak (- z 1) x y))))
(define (ctak x y z) (call/cc (lambda (k) (ctak-aux k x y z))))
(define (ctak-aux k x y z)
  (if (not (< y x)) (k z)
      (call/cc (lambda (k)
        (ctak-aux k
          (call/cc (lambda (k) (ctak-aux k (- x 1) y z)))
          (call/cc (lambda (k) (ctak-aux k (- y 1) z x)))
          (call/cc (lambda (k) (ctak-aux k (- z 1) x y))))))))
(define (mk n) (if (= n 0) '() (cons n (mk (- n 1)))))
(define (sum l acc) (if (null? l) acc (sum (cdr l) (+ acc (car l)))))

(define (bench name reps thunk)
  (thunk) (thunk) ; warm up (JIT)
  (let ((t0 (current-jiffy)))
    (let loop ((i 0) (r #f))
      (if (< i reps)
          (loop (+ i 1) (thunk))
          (let ((ms (/ (* 1000.0 (- (current-jiffy) t0)) (jiffies-per-second))))
            (display name) (display ": ") (display r) (display "  ")
            (display (/ ms reps)) (display " ms/run") (newline))))))

(bench "fib 30" 5 (lambda () (fib 30)))
(bench "tak 18 12 6" 200 (lambda () (tak 18 12 6)))
(bench "ctak 18 12 6" 20 (lambda () (ctak 18 12 6)))
(bench "mk+sum 1e6" 20 (lambda () (sum (mk 1000000) 0)))

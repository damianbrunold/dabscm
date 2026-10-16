;;; SRFI 194: Random data generators
;;;
;;; Port of the SRFI 194 reference implementation (194-impl.scm,
;;; zipf-zri.scm, sphere.scm), MIT licensed:
;;;   SPDX-FileCopyrightText: 2020 Arvydas Silanskas
;;;   SPDX-FileCopyrightText: 2020 Bradley Lucier
;;;   SPDX-FileCopyrightText: 2020 Linas Vepštas
;;;   SPDX-FileCopyrightText: 2024 Bradley J Lucier
;;;
;;; Generators are SRFI 158 generators (thunks); the randomness comes from
;;; SRFI 27 random sources.  Every generator captures the value of
;;; current-random-source when it is created.

(define-library (srfi 194)
  (import (scheme base)
          (scheme case-lambda)
          (scheme inexact)
          (scheme complex)
          (only (srfi 133) vector-fold vector-every)
          (srfi 27)
          (only (srfi 158) generator->string))
  (export clamp-real-number

          current-random-source
          with-random-source

          make-random-integer-generator
          make-random-u1-generator
          make-random-u8-generator make-random-s8-generator
          make-random-u16-generator make-random-s16-generator
          make-random-u32-generator make-random-s32-generator
          make-random-u64-generator make-random-s64-generator
          make-random-boolean-generator
          make-random-char-generator
          make-random-string-generator
          make-random-real-generator
          make-random-rectangular-generator
          make-random-polar-generator

          make-bernoulli-generator
          make-binomial-generator
          make-categorical-generator
          make-normal-generator
          make-exponential-generator
          make-geometric-generator
          make-poisson-generator
          make-zipf-generator
          make-sphere-generator
          make-ellipsoid-generator
          make-ball-generator

          make-random-source-generator
          gsampling)
  (begin

    (define PI (* 4 (atan 1.0)))

    ;;; ============================================================
    ;;; Random sources
    ;;; ============================================================

    (define current-random-source (make-parameter default-random-source))

    (define (with-random-source random-source thunk)
      "Syntax: (with-random-source random-source thunk)
Library: (srfi 194)
Description: Calls thunk with current-random-source bound to the SRFI 27
  random-source.  Generators created inside thunk draw from that source.
Example:
  (let ((s (make-random-source)))
    (random-source-pseudo-randomize! s 0 1)
    (with-random-source s
      (lambda () ((make-random-integer-generator 0 10)))))  => 0..9"
      (unless (random-source? random-source)
        (error "with-random-source: expected random source" random-source))
      (parameterize ((current-random-source random-source))
        (thunk)))

    ;; Consecutive substreams of the s'th SRFI 27 stream; see L'Ecuyer,
    ;; Simard, Chen, Kelton, Operations Research 50 (2002), 1073-1075.
    (define (make-random-source-generator s)
      "Syntax: (make-random-source-generator i)
Library: (srfi 194)
Description: Returns a generator of fresh SRFI 27 random sources.  The n-th
  source returned (counting from 0) is a new random source pseudo-randomized
  with (random-source-pseudo-randomize! source i n), so the sources are
  deterministic and independent of each other.
Example:
  (let ((g (make-random-source-generator 0)))
    (random-source? (g))) => #t"
      (if (not (and (exact-integer? s) (not (negative? s))))
          (error "make-random-source-generator: expected non-negative exact integer" s)
          (let ((substream 0))
            (lambda ()
              (let ((new-source (make-random-source)))
                (random-source-pseudo-randomize! new-source s substream)
                (set! substream (+ substream 1))
                new-source)))))

    ;;; ============================================================
    ;;; Uniform distributions
    ;;; ============================================================

    (define (make-random-integer-generator low-bound up-bound)
      "Syntax: (make-random-integer-generator lower-bound upper-bound)
Library: (srfi 194)
Description: Returns a generator of exact integers uniformly distributed in
  [lower-bound, upper-bound).  Both bounds must be exact integers and the
  interval must not be empty.
Example:
  (<= 1 ((make-random-integer-generator 1 7)) 6) => #t"
      (unless (exact-integer? low-bound)
        (error "make-random-integer-generator: expected exact integer for lower bound" low-bound))
      (unless (exact-integer? up-bound)
        (error "make-random-integer-generator: expected exact integer for upper bound" up-bound))
      (unless (< low-bound up-bound)
        (error "make-random-integer-generator: upper bound should be greater than lower bound"
               low-bound up-bound))
      (let ((rand-int-proc (random-source-make-integers (current-random-source)))
            (range (- up-bound low-bound)))
        (lambda ()
          (+ low-bound (rand-int-proc range)))))

    (define (make-random-u1-generator)
      "Syntax: (make-random-u1-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers 0 or 1.
Example:
  (<= 0 ((make-random-u1-generator)) 1) => #t"
      (make-random-integer-generator 0 2))

    (define (make-random-u8-generator)
      "Syntax: (make-random-u8-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [0, 255].
Example:
  (<= 0 ((make-random-u8-generator)) 255) => #t"
      (make-random-integer-generator 0 256))

    (define (make-random-s8-generator)
      "Syntax: (make-random-s8-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [-128, 127].
Example:
  (<= -128 ((make-random-s8-generator)) 127) => #t"
      (make-random-integer-generator -128 128))

    (define (make-random-u16-generator)
      "Syntax: (make-random-u16-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [0, 2^16 - 1].
Example:
  (<= 0 ((make-random-u16-generator)) 65535) => #t"
      (make-random-integer-generator 0 65536))

    (define (make-random-s16-generator)
      "Syntax: (make-random-s16-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [-2^15, 2^15 - 1].
Example:
  (<= -32768 ((make-random-s16-generator)) 32767) => #t"
      (make-random-integer-generator -32768 32768))

    (define (make-random-u32-generator)
      "Syntax: (make-random-u32-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [0, 2^32 - 1].
Example:
  (< ((make-random-u32-generator)) (expt 2 32)) => #t"
      (make-random-integer-generator 0 (expt 2 32)))

    (define (make-random-s32-generator)
      "Syntax: (make-random-s32-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [-2^31, 2^31 - 1].
Example:
  (< ((make-random-s32-generator)) (expt 2 31)) => #t"
      (make-random-integer-generator (- (expt 2 31)) (expt 2 31)))

    (define (make-random-u64-generator)
      "Syntax: (make-random-u64-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [0, 2^64 - 1].
Example:
  (< ((make-random-u64-generator)) (expt 2 64)) => #t"
      (make-random-integer-generator 0 (expt 2 64)))

    (define (make-random-s64-generator)
      "Syntax: (make-random-s64-generator)
Library: (srfi 194)
Description: Returns a generator of uniformly distributed integers in
  [-2^63, 2^63 - 1].
Example:
  (< ((make-random-s64-generator)) (expt 2 63)) => #t"
      (make-random-integer-generator (- (expt 2 63)) (expt 2 63)))

    (define (clamp-real-number lower-bound upper-bound value)
      "Syntax: (clamp-real-number lower-bound upper-bound value)
Library: (srfi 194)
Description: Returns value clamped to the closed interval
  [lower-bound, upper-bound].  Not a generator.  Mixing exact and inexact
  arguments may give surprising results.
Example:
  (clamp-real-number 0.0 1.0 1.5) => 1.0"
      (cond ((not (real? lower-bound))
             (error "clamp-real-number: expected real number for lower bound" lower-bound))
            ((not (real? upper-bound))
             (error "clamp-real-number: expected real number for upper bound" upper-bound))
            ((not (<= lower-bound upper-bound))
             (error "clamp-real-number: lower bound must be <= upper bound"
                    lower-bound upper-bound))
            ((< value lower-bound) lower-bound)
            ((> value upper-bound) upper-bound)
            (else value)))

    (define (make-random-real-generator low-bound up-bound)
      "Syntax: (make-random-real-generator lower-bound upper-bound)
Library: (srfi 194)
Description: Returns a generator of inexact reals uniformly distributed in
  [lower-bound, upper-bound].  The bounds must be finite reals with
  lower-bound < upper-bound.
Example:
  (<= 1.0 ((make-random-real-generator 1.0 2.0)) 2.0) => #t"
      (unless (and (real? low-bound) (finite? low-bound))
        (error "make-random-real-generator: expected finite real number for lower bound" low-bound))
      (unless (and (real? up-bound) (finite? up-bound))
        (error "make-random-real-generator: expected finite real number for upper bound" up-bound))
      (unless (< low-bound up-bound)
        (error "make-random-real-generator: lower bound must be < upper bound"
               low-bound up-bound))
      (let ((rand-real-proc (random-source-make-reals (current-random-source))))
        (lambda ()
          (let ((t (rand-real-proc)))
            ;; Unlike low + t*(up - low), this cannot round out of range.
            (+ (* t low-bound)
               (* (- 1.0 t) up-bound))))))

    (define (make-random-rectangular-generator
             real-lower-bound real-upper-bound
             imag-lower-bound imag-upper-bound)
      "Syntax: (make-random-rectangular-generator real-lower-bound real-upper-bound
                                           imag-lower-bound imag-upper-bound)
Library: (srfi 194)
Description: Returns a generator of inexact complex numbers uniformly
  distributed in the closed rectangle with the given bounds for the real and
  the imaginary part.
Example:
  (let ((z ((make-random-rectangular-generator -1.0 1.0 -1.0 1.0))))
    (<= -1.0 (imag-part z) 1.0)) => #t"
      (let ((real-gen (make-random-real-generator real-lower-bound real-upper-bound))
            (imag-gen (make-random-real-generator imag-lower-bound imag-upper-bound)))
        (lambda ()
          (make-rectangular (real-gen) (imag-gen)))))

    (define make-random-polar-generator
      (case-lambda
        ((magnitude-lower-bound magnitude-upper-bound)
         (make-random-polar-generator 0 magnitude-lower-bound magnitude-upper-bound
                                      0 (* 2 PI)))
        ((origin magnitude-lower-bound magnitude-upper-bound)
         (make-random-polar-generator origin magnitude-lower-bound magnitude-upper-bound
                                      0 (* 2 PI)))
        ((magnitude-lower-bound magnitude-upper-bound angle-lower-bound angle-upper-bound)
         (make-random-polar-generator 0 magnitude-lower-bound magnitude-upper-bound
                                      angle-lower-bound angle-upper-bound))
        ((origin magnitude-lower-bound magnitude-upper-bound angle-lower-bound angle-upper-bound)
         "Syntax: (make-random-polar-generator mag-lo mag-hi)
       (make-random-polar-generator origin mag-lo mag-hi)
       (make-random-polar-generator mag-lo mag-hi angle-lo angle-hi)
       (make-random-polar-generator origin mag-lo mag-hi angle-lo angle-hi)
Library: (srfi 194)
Description: Returns a generator of inexact complex numbers uniformly
  distributed (by area) in the annulus sector around origin (default 0)
  with magnitudes in [mag-lo, mag-hi] and angles in [angle-lo, angle-hi]
  (default 0 to 2*pi).  With mag-lo 0 and the default angles this is a disk.
Example:
  (<= (magnitude ((make-random-polar-generator 0.0 1.0))) 1.0) => #t"
         (unless (complex? origin)
           (error "make-random-polar-generator: origin should be complex number" origin))
         (unless (and (real? magnitude-lower-bound)
                      (real? magnitude-upper-bound)
                      (real? angle-lower-bound)
                      (real? angle-upper-bound))
           (error "make-random-polar-generator: magnitude and angle bounds should be real numbers"))
         (unless (and (<= 0 magnitude-lower-bound)
                      (<= 0 magnitude-upper-bound))
           (error "make-random-polar-generator: magnitude bounds should be positive"))
         (unless (< magnitude-lower-bound magnitude-upper-bound)
           (error "make-random-polar-generator: magnitude lower bound should be less than upper bound"))
         (when (= angle-lower-bound angle-upper-bound)
           (error "make-random-polar-generator: angle bounds shouldn't be equal"))
         (let* ((b (square magnitude-lower-bound))
                (m (- (square magnitude-upper-bound) b))
                (t-gen (make-random-real-generator 0. 1.))
                (phi-gen (make-random-real-generator angle-lower-bound angle-upper-bound)))
           (lambda ()
             (let* ((t (t-gen))
                    (phi (phi-gen))
                    (r (sqrt (+ (* m t) b))))
               (+ origin (make-polar r phi))))))))

    (define (make-random-boolean-generator)
      "Syntax: (make-random-boolean-generator)
Library: (srfi 194)
Description: Returns a generator of #t and #f with equal probability.
Example:
  (boolean? ((make-random-boolean-generator))) => #t"
      (let ((u1 (make-random-u1-generator)))
        (lambda ()
          (zero? (u1)))))

    (define (make-random-char-generator str)
      "Syntax: (make-random-char-generator string)
Library: (srfi 194)
Description: Returns a generator of characters drawn uniformly from string.
  Repeated characters are proportionally more likely.  string must not be
  empty.
Example:
  (char? ((make-random-char-generator \"abc\"))) => #t"
      (unless (string? str)
        (error "make-random-char-generator: expected string" str))
      (unless (> (string-length str) 0)
        (error "make-random-char-generator: given string is of length 0"))
      (let ((int-gen (make-random-integer-generator 0 (string-length str))))
        (lambda ()
          (string-ref str (int-gen)))))

    (define (make-random-string-generator k str)
      "Syntax: (make-random-string-generator k string)
Library: (srfi 194)
Description: Returns a generator of strings made of characters drawn
  uniformly from string, with lengths uniformly distributed in [0, k).
Example:
  (< (string-length ((make-random-string-generator 5 \"ab\"))) 5) => #t"
      (let ((char-gen (make-random-char-generator str))
            (int-gen (make-random-integer-generator 0 k)))
        (lambda ()
          (generator->string char-gen (int-gen)))))

    ;;; ============================================================
    ;;; Non-uniform distributions
    ;;; ============================================================

    (define (make-bernoulli-generator p)
      "Syntax: (make-bernoulli-generator p)
Library: (srfi 194)
Description: Returns a generator of 1 with probability p and 0 with
  probability 1 - p, where 0 <= p <= 1.
Example:
  ((make-bernoulli-generator 1)) => 1"
      (unless (real? p)
        (error "make-bernoulli-generator: expected p to be real" p))
      (unless (<= 0 p 1)
        (error "make-bernoulli-generator: expected 0 <= p <= 1" p))
      (let ((rand-real-proc (random-source-make-reals (current-random-source))))
        (lambda ()
          (if (<= (rand-real-proc) p) 1 0))))

    (define (make-categorical-generator weights-vec)
      "Syntax: (make-categorical-generator weights-vector)
Library: (srfi 194)
Description: Returns a generator of exact integers in [0, n), where n is
  the length of weights-vector, returning i with probability proportional
  to the i-th weight.  Weights must be positive numbers.
Example:
  ((make-categorical-generator #(0.0001 1000))) => 1"
      (define weight-sum
        (vector-fold
         (lambda (sum p)
           (unless (and (number? p) (> p 0))
             (error "make-categorical-generator: parameter must be a vector of positive numbers"
                    weights-vec))
           (+ sum p))
         0
         weights-vec))
      (define length (vector-length weights-vec))
      (let ((real-gen (make-random-real-generator 0 weight-sum)))
        (lambda ()
          (define roll (real-gen))
          (let it ((sum 0) (i 0))
            (define newsum (+ sum (vector-ref weights-vec i)))
            (if (or (< roll newsum)
                    ;; on rounding errors and no match, return the last index
                    (= i (- length 1)))
                i
                (it newsum (+ i 1)))))))

    ;; Box-Muller; each call to the uniform source yields two values, the
    ;; second is cached.
    (define make-normal-generator
      (case-lambda
        (()
         (make-normal-generator 0.0 1.0))
        ((mean)
         (make-normal-generator mean 1.0))
        ((mean deviation)
         "Syntax: (make-normal-generator)
       (make-normal-generator mean)
       (make-normal-generator mean deviation)
Library: (srfi 194)
Description: Returns a generator of inexact reals with a normal (Gaussian)
  distribution with the given mean (default 0.0) and standard deviation
  (default 1.0).
Example:
  (real? ((make-normal-generator 10.0 2.0))) => #t"
         (let ((rand-real-proc (random-source-make-reals (current-random-source)))
               (state #f))
           (unless (and (real? mean) (finite? mean))
             (error "make-normal-generator: expected mean to be finite real number" mean))
           (unless (and (real? deviation) (finite? deviation) (> deviation 0))
             (error "make-normal-generator: expected deviation to be positive finite real number"
                    deviation))
           (lambda ()
             (if state
                 (let ((result state))
                   (set! state #f)
                   result)
                 (let* ((r (sqrt (* -2 (log (rand-real-proc)))))
                        (theta (* 2 PI (rand-real-proc))))
                   (set! state (+ mean (* deviation r (cos theta))))
                   (+ mean (* deviation r (sin theta))))))))))

    (define (make-exponential-generator mean)
      "Syntax: (make-exponential-generator mean)
Library: (srfi 194)
Description: Returns a generator of inexact reals with an exponential
  distribution with the given (finite, positive) mean.
Example:
  (positive? ((make-exponential-generator 2.0))) => #t"
      (unless (and (real? mean) (finite? mean) (positive? mean))
        (error "make-exponential-generator: expected mean to be finite positive real number"
               mean))
      (let ((rand-real-proc (random-source-make-reals (current-random-source))))
        (lambda ()
          (- (* mean (log (rand-real-proc)))))))

    (define (make-geometric-generator p)
      "Syntax: (make-geometric-generator p)
Library: (srfi 194)
Description: Returns a generator of exact positive integers with a geometric
  distribution: the number of Bernoulli(p) trials up to and including the
  first success, 0 < p <= 1.  The mean is 1/p.
Example:
  ((make-geometric-generator 1)) => 1"
      (define (log1p x)                 ; adapted from SRFI 144
        (let ((u (+ 1.0 x)))
          (cond ((= u 1.0) x)
                ((= u x) (log u))
                (else (* (log u) (/ x (- u 1.0)))))))
      (unless (and (real? p) (> p 0) (<= p 1))
        (error "make-geometric-generator: expected p to be real number, 0 < p <= 1" p))
      (if (zero? (- p 1.))
          (lambda () 1)
          (let ((c (/ (log1p (- p))))
                (rand-real-proc (random-source-make-reals (current-random-source))))
            (lambda ()
              (exact (ceiling (* c (log (rand-real-proc)))))))))

    ;; Small L: Knuth's method.  Large L: rejection method by Atkinson,
    ;; "The Computer Generation of Poisson Random Variables", J. Royal
    ;; Statistical Society C 28(1), 1979 (after John D Cook's C++ port).
    (define (make-poisson-generator L)
      "Syntax: (make-poisson-generator L)
Library: (srfi 194)
Description: Returns a generator of exact non-negative integers with a
  Poisson distribution with mean and variance L (a finite positive real).
Example:
  (exact-integer? ((make-poisson-generator 4.5))) => #t"
      (unless (and (real? L) (finite? L) (> L 0))
        (error "make-poisson-generator: expected L to be finite positive real number" L))
      (let ((rand-real-proc (random-source-make-reals (current-random-source))))
        (if (< L 30)
            (make-poisson/small rand-real-proc L)
            (make-poisson/large rand-real-proc L))))

    (define (make-poisson/small rand-real-proc L)
      (lambda ()
        (do ((exp-L (exp (- L)))
             (k 0 (+ k 1))
             (p 1.0 (* p (rand-real-proc))))
            ((<= p exp-L) (- k 1)))))

    (define (make-poisson/large rand-real-proc L)
      (let* ((c (- 0.767 (/ 3.36 L)))
             (beta (/ PI (sqrt (* 3 L))))
             (alpha (* beta L))
             (k (- (log c) L (log beta))))
        (define (loop)
          (let* ((u (rand-real-proc))
                 (x (/ (- alpha (log (/ (- 1.0 u) u))) beta))
                 (n (exact (floor (+ x 0.5)))))
            (if (< n 0)
                (loop)
                (let* ((v (rand-real-proc))
                       (y (- alpha (* beta x)))
                       (t (+ 1.0 (exp y)))
                       (lhs (+ y (log (/ v (* t t)))))
                       (rhs (+ k (* n (log L)) (- (log-of-fact n)))))
                  (if (<= lhs rhs)
                      n
                      (loop))))))
        loop))

    ;; log(n!) for n = 1..256; index i holds log((i+1)!).
    (define log-fact-table
      (let ((table (make-vector 256)))
        (vector-set! table 0 0)
        (do ((i 1 (+ i 1)))
            ((> i 255) table)
          (vector-set! table i (+ (vector-ref table (- i 1))
                                  (log (+ i 1)))))))

    ;; https://www.johndcook.com/blog/2010/08/16/how-to-compute-log-factorial/
    (define (log-of-fact n)
      (cond
       ((<= n 1) 0)
       ((<= n 256) (vector-ref log-fact-table (- n 1)))
       (else (let ((x (+ n 1)))
               (+ (* (- x 0.5) (log x))
                  (- x)
                  (* 0.5 (log (* 2 PI)))
                  (/ 1.0 (* x 12.0)))))))

    ;;; Binomial random variables, by Brad Lucier.
    ;;;
    ;;; binomial-geometric is the "First waiting time algorithm" from page
    ;;; 525 of Devroye, Non-Uniform Random Variate Generation (1986).
    ;;; binomial-rejection is algorithm BTRS from Hormann, "The generation
    ;;; of binomial random variates", J. Statistical Computation and
    ;;; Simulation 46 (1993), with the corrections found in TensorFlow's
    ;;; random_binomial_op.cc.

    (define (stirling-tail k)
      ;; log(k!) - [log(sqrt(2 pi)) + (k + 1/2) log(k+1) - (k+1)]
      (let ((small-k-table
             '#(.08106146679532726
                .0413406959554093
                .02767792568499834
                .020790672103765093
                .016644691189821193
                .013876128823070748
                .01189670994589177
                .010411265261972096
                .009255462182712733
                .00833056343336287
                .007573675487951841
                .00694284010720953
                .006408994188004207
                .0059513701127588475
                .005554733551962801
                .0052076559196096404
                .004901395948434738
                .004629153749334028
                .004385560249232324
                .004166319691996922)))
        (if (< k 20)
            (vector-ref small-k-table k)
            (let* ((inexact-k+1 (inexact (+ k 1)))
                   (inexact-k+1^2 (square inexact-k+1)))
              (/ (- (/ 1.0 12.0)
                    (/ (- (/ 1.0 360.0)
                          (/ (/ 1.0 1260.0) inexact-k+1^2))
                       inexact-k+1^2))
                 inexact-k+1)))))

    (define (make-binomial-generator n p)
      "Syntax: (make-binomial-generator n p)
Library: (srfi 194)
Description: Returns a generator of exact integers in [0, n] with a binomial
  distribution: the number of successes in n Bernoulli(p) trials.  n must
  be a positive exact integer and 0 <= p <= 1.
Example:
  ((make-binomial-generator 10 1)) => 10"
      (if (not (and (real? p)
                    (<= 0 p 1)
                    (exact-integer? n)
                    (positive? n)))
          (error "make-binomial-generator: bad parameters" n p)
          (cond ((< 1/2 p)
                 (let ((complement (make-binomial-generator n (- 1 p))))
                   (lambda ()
                     (- n (complement)))))
                ((zero? p)
                 (lambda () 0))
                ((< (* n p) 10)
                 (binomial-geometric n p))
                (else
                 (binomial-rejection n p)))))

    (define (binomial-geometric n p)
      (let ((geom (make-geometric-generator p)))
        (lambda ()
          (let loop ((X -1) (sum 0))
            (if (< n sum)
                X
                (loop (+ X 1) (+ sum (geom))))))))

    (define (binomial-rejection n p)
      ;; call when p <= 1/2 and np >= 10
      (let* ((spq (inexact (sqrt (* n p (- 1 p)))))
             (b (+ 1.15 (* 2.53 spq)))
             (a (+ -0.0873 (* 0.0248 b) (* 0.01 p)))
             (c (+ (* n p) 0.5))
             (v_r (- 0.92 (/ 4.2 b)))
             ;; BTRS has 1.5 instead of 5.1; BTRD, Table 1 and TensorFlow
             ;; use 5.1
             (alpha (* (+ 2.83 (/ 5.1 b)) spq))
             (lpq (log (/ p (- 1 p))))
             (m (exact (floor (* (+ n 1) p))))
             (rand-real-proc (random-source-make-reals (current-random-source))))
        (lambda ()
          (let loop ()
            (let* ((u (rand-real-proc))
                   (v (rand-real-proc))
                   (u (- u 0.5))
                   (us (- 0.5 (abs u)))
                   (k (exact (floor (+ (* (+ (* 2. (/ a us)) b) u) c)))))
              (cond ((or (< k 0) (< n k))
                     (loop))
                    ((and (<= 0.07 us) (<= v v_r))
                     k)
                    (else
                     ;; BTRS lacks this logarithm (see BTRD, step 3.2)
                     (let ((v (log (* v (/ alpha (+ (/ a (square us)) b))))))
                       (if (<= v
                               (+ (* (+ m 0.5)
                                     (log (* (/ (+ m 1.) (- n m -1.)))))
                                  (* (+ n 1.)
                                     (log (/ (- n m -1.) (- n k -1.))))
                                  (* (+ k 0.5)
                                     (log (* (/ (- n k -1.) (+ k 1.)))))
                                  (* (- k m) lpq)
                                  (- (+ (stirling-tail m)
                                        (stirling-tail (- n m)))
                                     (+ (stirling-tail k)
                                        (stirling-tail (- n k))))))
                           k
                           (loop))))))))))

    ;;; ============================================================
    ;;; Zipf distribution
    ;;; ============================================================
    ;;
    ;; Linas Vepstas, after the ZRI algorithm of Hörmann and Derflinger,
    ;; "Rejection-inversion to generate variates from monotone discrete
    ;; distributions", ACM TOMACS 6.3 (1996), 169-184.  The Hurwicz zeta
    ;; distribution 1 / (k+q)^s for integer 1 <= k <= n; q = 0 is Zipf.

    ;; For |1-s| > 1e-5.
    (define (make-zipf-generator/zri n s q)
      (define (hat x) (expt (+ x q) (- s)))
      (define _1-s (- 1 s))
      (define oms (/ 1 _1-s))
      (define (big-h x) (/ (expt (+ q x) _1-s) _1-s))
      (define (big-h-inv y) (- (expt (* y _1-s) oms) q))
      (define big-h-half (- (big-h 1.5) (hat 1)))
      (define big-h-n (big-h (+ n 0.5)))
      (define cut (- 1 (big-h-inv (- (big-h 1.5) (hat 1)))))
      (define dist (make-random-real-generator big-h-half big-h-n))
      (define (try)
        (define u (dist))
        (define x (big-h-inv u))
        (define kflt (floor (+ x 0.5)))
        (define k (exact kflt))
        (if (and (< 0 k)
                 (or (<= (- k x) cut)
                     (>= u (- (big-h (+ k 0.5)) (hat k)))))
            k
            #f))
      (define (loop-until)
        (define k (try))
        (if k k (loop-until)))
      loop-until)

    ;; For s close to 1 (handles s = 1 exactly), via 4th order expansions.
    (define (make-zipf-generator/one n s q)
      (define _1-s (- 1 s))
      (define (hat x)
        (define xpq (+ x q))
        (/ (expt xpq _1-s) xpq))
      ;; [exp(y(1-s))-1]/(1-s)
      (define (exn lg)
        (define (trm n u lg) (* lg (+ 1 (/ (* _1-s u) n))))
        (trm 2 (trm 3 (trm 4 1 lg) lg) lg))
      ;; [log(1 + y(1-s))]/(1-s)
      (define (lg y)
        (define yms (* y _1-s))
        (define (trm n u r) (- (/ 1 n) (* u r)))
        (* y (trm 1 yms (trm 2 yms (trm 3 yms (trm 4 yms 0))))))
      (define (big-h x) (exn (log (+ q x))))
      (define (big-h-inv y) (- (exp (lg y)) q))
      (define big-h-half (- (big-h 1.5) (hat 1)))
      (define big-h-n (big-h (+ n 0.5)))
      (define cut (- 1 (big-h-inv (- (big-h 1.5) (/ 1 (+ 1 q))))))
      (define dist (make-random-real-generator big-h-half big-h-n))
      (define (try)
        (define u (dist))
        (define x (big-h-inv u))
        (define kflt (floor (+ x 0.5)))
        (define k (exact kflt))
        (if (and (< 0 k)
                 (or (<= (- k x) cut)
                     (>= u (- (big-h (+ k 0.5)) (hat k)))))
            k
            #f))
      (define (loop-until)
        (define k (try))
        (if k k (loop-until)))
      loop-until)

    (define make-zipf-generator
      (case-lambda
        ((n)
         (make-zipf-generator n 1.0 0.0))
        ((n s)
         (make-zipf-generator n s 0.0))
        ((n s q)
         "Syntax: (make-zipf-generator n)
       (make-zipf-generator n s)
       (make-zipf-generator n s q)
Library: (srfi 194)
Description: Returns a generator of exact integers in [1, n] with a
  (generalized) Zipf distribution: k is returned with probability
  proportional to 1/(k+q)^s.  s defaults to 1.0 and q to 0.0.  Overflow or
  loss of precision is likely outside -10 < s < 100 and -0.5 < q < 2e8.
Example:
  (<= 1 ((make-zipf-generator 50 1.01 0)) 50) => #t"
         (if (< 1e-5 (abs (- 1 s)))
             (make-zipf-generator/zri n s q)
             (make-zipf-generator/one n s q)))))

    ;;; ============================================================
    ;;; Spheres, ellipsoids and balls
    ;;; ============================================================
    ;;
    ;; Points on a sphere: normalized vectors of Gaussian variables
    ;; (http://extremelearning.com.au/how-to-generate-uniformly-random-points-on-n-spheres-and-n-balls/).

    (define (make-sphere-generator arg)
      "Syntax: (make-sphere-generator n)
Library: (srfi 194)
Description: Returns a generator of points uniformly distributed on the
  surface of the unit n-sphere, as vectors of n+1 inexact reals.  n must be
  a positive exact integer.
Example:
  (vector-length ((make-sphere-generator 2))) => 3"
      (if (and (exact-integer? arg) (positive? arg))
          (make-ellipsoid-generator* (make-vector (+ 1 arg) 1.0))
          (error "make-sphere-generator: the argument must be a positive exact integer" arg)))

    (define (make-ellipsoid-generator arg)
      "Syntax: (make-ellipsoid-generator axes)
Library: (srfi 194)
Description: Returns a generator of points uniformly distributed on the
  surface of the ellipsoid whose axis lengths are given by the vector axes
  of positive finite reals.  Each point is a vector of inexact reals.
Example:
  (vector-length ((make-ellipsoid-generator #(1.0 2.0 3.0)))) => 3"
      (define (return-error)
        (error "make-ellipsoid-generator: the argument must be a vector of positive finite real numbers"
               arg))
      (if (and (vector? arg) (vector-every real? arg))
          (let ((inexact-arg (vector-map inexact arg)))
            (if (vector-every (lambda (x) (and (positive? x) (finite? x)))
                              inexact-arg)
                (make-ellipsoid-generator* inexact-arg)
                (return-error)))
          (return-error)))

    ;; Accept/reject sampling with acceptance proportional to the measure
    ;; of the surface element; fastest for spheres.  See
    ;; https://math.stackexchange.com/questions/973101
    (define (make-ellipsoid-generator* axes)
      (let ((gauss (make-normal-generator))
            (uniform (make-random-real-generator 0. 1.))
            (min-axis (vector-fold min +inf.0 axes)))
        (define (sphere)
          (let* ((point (vector-map (lambda (_) (gauss)) axes))
                 (norm-inverse
                  (/ (sqrt (vector-fold (lambda (sum x) (+ sum (square x)))
                                        0.
                                        point)))))
            (vector-map (lambda (x) (* x norm-inverse)) point)))
        (define (ellipsoid-distance ray)
          (sqrt (vector-fold (lambda (sum x a) (+ sum (square (/ x a))))
                             0. ray axes)))
        (define (keep point)
          (< (uniform) (* min-axis (ellipsoid-distance point))))
        (define (sample)
          (let ((point (sphere)))
            (if (keep point) point (sample))))
        (lambda ()
          (vector-map * (sample) axes))))

    ;; Harman-Lacko-Voelker dropped coordinate method, see Dezert and
    ;; Musso, "An Efficient Method for Generating Points Uniformly
    ;; Distributed in Hyperellipsoids" (2001).
    (define (make-ball-generator arg)
      "Syntax: (make-ball-generator n)
       (make-ball-generator axes)
Library: (srfi 194)
Description: Returns a generator of points uniformly distributed inside an
  n-dimensional unit ball (n a positive exact integer), or inside the
  ellipsoid with the axis lengths in the vector axes.  Each point is a
  vector of inexact reals.
Example:
  (vector-length ((make-ball-generator 2))) => 2"
      (define (return-error)
        (error "make-ball-generator: the argument must be a positive exact integer or a vector of positive finite real numbers"
               arg))
      (cond ((and (exact-integer? arg) (positive? arg))
             (make-ball-generator* (make-vector arg 1.0)))
            ((and (vector? arg) (vector-every real? arg))
             (let ((inexact-arg (vector-map inexact arg)))
               (if (vector-every (lambda (x) (and (positive? x) (finite? x)))
                                 inexact-arg)
                   (make-ball-generator* inexact-arg)
                   (return-error))))
            (else (return-error))))

    (define (make-ball-generator* axes)
      (let ((sphere-generator
             ;; yields vectors of (vector-length axes) + 2 elements
             (make-sphere-generator (+ (vector-length axes) 1))))
        (lambda ()
          ;; vector-map stops at the shorter vector: the extra two
          ;; coordinates are dropped
          (vector-map (lambda (el axis) (* el axis))
                      (sphere-generator)
                      axes))))

    ;;; ============================================================
    ;;; Generator operations
    ;;; ============================================================

    (define (gsampling . generators-lst)
      "Syntax: (gsampling generator ...)
Library: (srfi 194)
Description: Returns a generator that, on each call, picks one of the given
  generators with equal probability and returns its next value.  Exhausted
  generators are dropped; once all are exhausted (or none were given) it
  returns an end-of-file object.
Example:
  (length (generator->list (gsampling (generator 1 2) (generator 3)))) => 3"
      (let ((gen-vec (list->vector generators-lst))
            (rand-int-proc (random-source-make-integers (current-random-source))))
        (define (remove-gen index)
          (let ((new-vec (make-vector (- (vector-length gen-vec) 1))))
            (when (> index 0)
              (vector-copy! new-vec 0 gen-vec 0 index))
            (when (< index (- (vector-length gen-vec) 1))
              (vector-copy! new-vec index gen-vec (+ 1 index)))
            (set! gen-vec new-vec)))
        (define (pick)
          (let* ((index (rand-int-proc (vector-length gen-vec)))
                 (gen (vector-ref gen-vec index))
                 (value (gen)))
            (if (eof-object? value)
                (begin
                  (remove-gen index)
                  (if (= (vector-length gen-vec) 0)
                      (eof-object)
                      (pick)))
                value)))
        (lambda ()
          (if (= 0 (vector-length gen-vec))
              (eof-object)
              (pick)))))))

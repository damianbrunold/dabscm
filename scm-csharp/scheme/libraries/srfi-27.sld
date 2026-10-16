;;; SRFI 27: Sources of Random Bits
;;;
;;; Port of the SRFI 27 reference implementation by Sebastian Egner
;;; (mrg32k3a.scm + the 54-bit integer back end mrg32k3a-a.scm),
;;; Copyright (C) Sebastian Egner (2002), MIT license:
;;; Pierre L'Ecuyer's MRG32k3a combined multiple recursive generator,
;;; period ~2^191.  All intermediate values of a step fit into 54 bits,
;;; so they stay on the host's fixnum (long) fast path.
;;;
;;; Random sources are not synchronized: use a separate source per
;;; thread (make-random-source + random-source-pseudo-randomize!).

(define-library (srfi 27)
  (import (scheme base))
  (export random-integer
          random-real
          default-random-source
          make-random-source
          random-source?
          random-source-state-ref
          random-source-state-set!
          random-source-randomize!
          random-source-pseudo-randomize!
          random-source-make-integers
          random-source-make-reals)
  (begin

    (define %random-bytes (%primitive "random-bytes"))

    ;;; ============================================================
    ;;; Core generator
    ;;; ============================================================
    ;;
    ;; The state is a vector #(x10 x11 x12 x20 x21 x22), most recent
    ;; value first (the reference's unpacked state).

    (define mrg32k3a-m1 4294967087)     ; 2^32 - 209
    (define mrg32k3a-m2 4294944443)     ; 2^32 - 22853

    (define (mrg32k3a-random-m1 state)
      (let ((x11 (vector-ref state 0))
            (x12 (vector-ref state 1))
            (x13 (vector-ref state 2))
            (x21 (vector-ref state 3))
            (x22 (vector-ref state 4))
            (x23 (vector-ref state 5)))
        (let ((x10 (modulo (- (* 1403580 x12) (* 810728 x13)) 4294967087))
              (x20 (modulo (- (* 527612 x21) (* 1370589 x23)) 4294944443)))
          (vector-set! state 0 x10)
          (vector-set! state 1 x11)
          (vector-set! state 2 x12)
          (vector-set! state 3 x20)
          (vector-set! state 4 x21)
          (vector-set! state 5 x22)
          (modulo (- x10 x20) 4294967087))))

    ;; Uniform integer in {0..range-1}, 1 <= range <= m1 (rejection method).
    (define (mrg32k3a-random-integer state range)
      (let* ((q (quotient 4294967087 range))
             (qn (* q range)))
        (do ((x (mrg32k3a-random-m1 state) (mrg32k3a-random-m1 state)))
            ((< x qn) (quotient x q)))))

    ;; Uniform flonum in (0,1); normalization is 1/(m1+1).
    (define (mrg32k3a-random-real state)
      (* 0.0000000002328306549295728 (+ 1.0 (mrg32k3a-random-m1 state))))

    ;;; ============================================================
    ;;; External state
    ;;; ============================================================

    (define (mrg32k3a-state-ref state)
      (cons 'lecuyer-mrg32k3a (vector->list state)))

    (define (mrg32k3a-state-set external-state)
      (define (check-value x m)
        (unless (and (exact-integer? x) (<= 0 x (- m 1)))
          (error "random-source-state-set!: illegal value" x)))
      (unless (and (list? external-state)
                   (= (length external-state) 7)
                   (eq? (car external-state) 'lecuyer-mrg32k3a))
        (error "random-source-state-set!: malformed state" external-state))
      (let ((s (cdr external-state)))
        (check-value (list-ref s 0) mrg32k3a-m1)
        (check-value (list-ref s 1) mrg32k3a-m1)
        (check-value (list-ref s 2) mrg32k3a-m1)
        (check-value (list-ref s 3) mrg32k3a-m2)
        (check-value (list-ref s 4) mrg32k3a-m2)
        (check-value (list-ref s 5) mrg32k3a-m2)
        (when (or (zero? (+ (list-ref s 0) (list-ref s 1) (list-ref s 2)))
                  (zero? (+ (list-ref s 3) (list-ref s 4) (list-ref s 5))))
          (error "random-source-state-set!: illegal degenerate state"
                 external-state))
        (list->vector s)))

    ;;; ============================================================
    ;;; Pseudo-randomization (jump-ahead)
    ;;; ============================================================
    ;;
    ;; The generator is linear in its state, so k steps are one 3x3 matrix
    ;; power (per component).  Stream (i, j) starts at A^(16 + i*2^127 +
    ;; j*2^76), see L'Ecuyer, Simard, Chen, Kelton: "An Object-Oriented
    ;; Random-Number Package With Many Long Streams and Substreams" (2002).
    ;; A pair of matrices mod m1 / mod m2 is a vector of 18 integers.

    (define mrg32k3a-initial-state      ; entries 0 3 6 9 12 15 of A^16
      '#(1062452522 2961816100 342112271 2854655037 3321940838 3542344109))

    (define mrg32k3a-generators #f)     ; (A^(2^127) A^(2^76) A^16), lazily

    (define (mrg32k3a-product A B)      ; A*B in ((Z/m1) x (Z/m2))^(3x3)
      (define (lc i0 i1 i2 j0 j1 j2 m)
        (modulo (+ (* (vector-ref A i0) (vector-ref B j0))
                   (* (vector-ref A i1) (vector-ref B j1))
                   (* (vector-ref A i2) (vector-ref B j2)))
                m))
      (let ((m1 mrg32k3a-m1) (m2 mrg32k3a-m2))
        (vector
         (lc  0  1  2   0  3  6 m1) (lc  0  1  2   1  4  7 m1)
         (lc  0  1  2   2  5  8 m1)
         (lc  3  4  5   0  3  6 m1) (lc  3  4  5   1  4  7 m1)
         (lc  3  4  5   2  5  8 m1)
         (lc  6  7  8   0  3  6 m1) (lc  6  7  8   1  4  7 m1)
         (lc  6  7  8   2  5  8 m1)
         (lc  9 10 11   9 12 15 m2) (lc  9 10 11  10 13 16 m2)
         (lc  9 10 11  11 14 17 m2)
         (lc 12 13 14   9 12 15 m2) (lc 12 13 14  10 13 16 m2)
         (lc 12 13 14  11 14 17 m2)
         (lc 15 16 17   9 12 15 m2) (lc 15 16 17  10 13 16 m2)
         (lc 15 16 17  11 14 17 m2))))

    (define (mrg32k3a-power A e)        ; A^e
      (cond ((zero? e) '#(1 0 0 0 1 0 0 0 1 1 0 0 0 1 0 0 0 1))
            ((= e 1) A)
            ((even? e) (mrg32k3a-power (mrg32k3a-product A A) (quotient e 2)))
            (else (mrg32k3a-product (mrg32k3a-power A (- e 1)) A))))

    (define (mrg32k3a-power-power A b)  ; A^(2^b)
      (if (zero? b)
          A
          (mrg32k3a-power-power (mrg32k3a-product A A) (- b 1))))

    (define mrg32k3a-A                  ; the MRG32k3a recursion
      '#(     0 1403580 4294156359
              1       0          0
              0       1          0
         527612       0 4293573854
              1       0          0
              0       1          0))

    (define (mrg32k3a-pseudo-randomize-state i j)
      (unless (and (exact-integer? i) (exact-integer? j)
                   (>= i 0) (>= j 0))
        (error "random-source-pseudo-randomize!: i and j must be non-negative exact integers"
               i j))
      (unless mrg32k3a-generators
        (set! mrg32k3a-generators
              (list (mrg32k3a-power-power mrg32k3a-A 127)
                    (mrg32k3a-power-power mrg32k3a-A 76)
                    (mrg32k3a-power mrg32k3a-A 16))))
      (let ((M (mrg32k3a-product
                (list-ref mrg32k3a-generators 2)
                (mrg32k3a-product
                 (mrg32k3a-power (list-ref mrg32k3a-generators 0)
                                 (modulo i (expt 2 28)))
                 (mrg32k3a-power (list-ref mrg32k3a-generators 1)
                                 (modulo j (expt 2 28)))))))
        (vector (vector-ref M 0) (vector-ref M 3) (vector-ref M 6)
                (vector-ref M 9) (vector-ref M 12) (vector-ref M 15))))

    ;;; ============================================================
    ;;; True randomization
    ;;; ============================================================
    ;;
    ;; Unlike the reference (which mixes in the clock), the new state is
    ;; drawn from the host's cryptographic random source.  Each component
    ;; is a 64-bit random number reduced mod m (bias < 2^-31); the first
    ;; value of each recursion is kept non-zero so neither is degenerate.

    (define (random-u64)
      (let ((bv (%random-bytes 8)))
        (let loop ((i 0) (n 0))
          (if (= i 8)
              n
              (loop (+ i 1) (+ (* n 256) (bytevector-u8-ref bv i)))))))

    (define (mrg32k3a-randomize-state)
      (let ((m1 mrg32k3a-m1) (m2 mrg32k3a-m2))
        (vector (+ 1 (modulo (random-u64) (- m1 1)))
                (modulo (random-u64) m1)
                (modulo (random-u64) m1)
                (+ 1 (modulo (random-u64) (- m2 1)))
                (modulo (random-u64) m2)
                (modulo (random-u64) m2))))

    ;;; ============================================================
    ;;; Large integers and multiple precision reals
    ;;; ============================================================

    (define mrg32k3a-m-max mrg32k3a-m1)

    (define (mrg32k3a-random-power state k)     ; in {0..m-max^k - 1}
      (if (= k 1)
          (mrg32k3a-random-integer state mrg32k3a-m-max)
          (+ (* (mrg32k3a-random-power state (- k 1)) mrg32k3a-m-max)
             (mrg32k3a-random-integer state mrg32k3a-m-max))))

    (define (mrg32k3a-random-large state n)     ; n > m-max
      (do ((k 2 (+ k 1))
           (mk (* mrg32k3a-m-max mrg32k3a-m-max) (* mk mrg32k3a-m-max)))
          ((>= mk n)
           (let* ((mk-by-n (quotient mk n))
                  (a (* mk-by-n n)))
             (do ((x (mrg32k3a-random-power state k)
                     (mrg32k3a-random-power state k)))
                 ((< x a) (quotient x mk-by-n)))))))

    (define (mrg32k3a-random-real-mp state unit)
      (do ((k 1 (+ k 1))
           (u (- (/ 1 unit) 1) (/ u mrg32k3a-m1)))
          ((<= u 1)
           (/ (inexact (+ (mrg32k3a-random-power state k) 1))
              (inexact (+ (expt mrg32k3a-m-max k) 1))))))

    ;;; ============================================================
    ;;; SRFI 27 interface
    ;;; ============================================================

    (define-record-type random-source
      (%make-random-source state)
      %random-source?
      (state random-source-state %set-random-source-state!))

    (define (check-source who s)
      (unless (%random-source? s)
        (error (string-append who ": not a random source") s)))

    (define (make-random-source)
      "Syntax: (make-random-source)
Library: (srfi 27)
Description: Creates a new random source.  Every new source starts in the
  same state, so it yields the same sequence until it is randomized,
  pseudo-randomized or given another state.  The generator is L'Ecuyer's
  MRG32k3a.
Example:
  (let ((s (make-random-source)))
    ((random-source-make-integers s) 100)) => 85"
      (%make-random-source (vector-copy mrg32k3a-initial-state)))

    (define (random-source? obj)
      "Syntax: (random-source? obj)
Library: (srfi 27)
Description: Returns #t if obj is a random source, #f otherwise.
Example:
  (random-source? default-random-source) => #t"
      (%random-source? obj))

    (define (random-source-state-ref s)
      "Syntax: (random-source-state-ref s)
Library: (srfi 27)
Description: Returns the current state of the random source s as an
  external object (a list (lecuyer-mrg32k3a x10 x11 x12 x20 x21 x22)) that
  can be written, read back and passed to random-source-state-set!.
Example:
  (car (random-source-state-ref (make-random-source))) => lecuyer-mrg32k3a"
      (check-source "random-source-state-ref" s)
      (mrg32k3a-state-ref (random-source-state s)))

    (define (random-source-state-set! s state)
      "Syntax: (random-source-state-set! s state)
Library: (srfi 27)
Description: Sets the state of the random source s to state, which must
  have been obtained from random-source-state-ref.
Example:
  (let* ((s (make-random-source))
         (rand (random-source-make-integers s))
         (st (random-source-state-ref s))
         (a (rand 1000000)))
    (random-source-state-set! s st)
    (= a (rand 1000000))) => #t"
      (check-source "random-source-state-set!" s)
      (%set-random-source-state! s (mrg32k3a-state-set state)))

    (define (random-source-randomize! s)
      "Syntax: (random-source-randomize! s)
Library: (srfi 27)
Description: Sets the random source s to a truly random state, drawn from
  the operating system's cryptographic random number generator.
Example:
  (let ((s (make-random-source)))
    (random-source-randomize! s)
    (random-source? s)) => #t"
      (check-source "random-source-randomize!" s)
      (%set-random-source-state! s (mrg32k3a-randomize-state)))

    (define (random-source-pseudo-randomize! s i j)
      "Syntax: (random-source-pseudo-randomize! s i j)
Library: (srfi 27)
Description: Sets the random source s to the initial state of the
  (i, j)-th independent stream, where i and j are non-negative exact
  integers.  This is fully deterministic: use it to obtain reproducible yet
  independent streams, e.g. one per thread or per simulation run.  Streams
  are distinct for i, j < 2^28.
Example:
  (let ((a (make-random-source)) (b (make-random-source)))
    (random-source-pseudo-randomize! a 1 2)
    (random-source-pseudo-randomize! b 1 2)
    (= ((random-source-make-integers a) 1000000)
       ((random-source-make-integers b) 1000000))) => #t"
      (check-source "random-source-pseudo-randomize!" s)
      (%set-random-source-state! s (mrg32k3a-pseudo-randomize-state i j)))

    (define (random-source-make-integers s)
      "Syntax: (random-source-make-integers s)
Library: (srfi 27)
Description: Returns a procedure (rand n) that takes a positive exact
  integer n and returns the next uniformly distributed integer in
  {0, ..., n-1} from the random source s.  n may be arbitrarily large.
Example:
  (let ((rand (random-source-make-integers (make-random-source))))
    (< (rand 6) 6)) => #t"
      (check-source "random-source-make-integers" s)
      (lambda (n)
        (cond ((not (and (exact-integer? n) (positive? n)))
               (error "random-integer: range must be exact positive integer" n))
              ((<= n mrg32k3a-m-max)
               (mrg32k3a-random-integer (random-source-state s) n))
              (else
               (mrg32k3a-random-large (random-source-state s) n)))))

    (define (random-source-make-reals s . unit)
      "Syntax: (random-source-make-reals s)
       (random-source-make-reals s unit)
Library: (srfi 27)
Description: Returns a procedure of no arguments that returns the next
  uniformly distributed flonum strictly between 0 and 1 from the random
  source s.  The optional unit (0 < unit < 1) is the maximum spacing
  between possible results; smaller values than the default ~2.3e-10 draw
  several numbers per result.
Example:
  (let ((rand (random-source-make-reals (make-random-source))))
    (< 0 (rand) 1)) => #t"
      (check-source "random-source-make-reals" s)
      (cond
       ((null? unit)
        (lambda () (mrg32k3a-random-real (random-source-state s))))
       ((null? (cdr unit))
        (let ((unit (car unit)))
          (cond
           ((not (and (real? unit) (< 0 unit 1)))
            (error "random-source-make-reals: unit must be real in (0,1)" unit))
           ((<= (- (/ 1 unit) 1) mrg32k3a-m1)
            (lambda () (mrg32k3a-random-real (random-source-state s))))
           (else
            (lambda () (mrg32k3a-random-real-mp (random-source-state s) unit))))))
       (else
        (error "random-source-make-reals: illegal arguments" unit))))

    (define default-random-source (make-random-source))

    (define %default-integers (random-source-make-integers default-random-source))
    (define %default-reals (random-source-make-reals default-random-source))

    (define (random-integer n)
      "Syntax: (random-integer n)
Library: (srfi 27)
Description: Returns the next uniformly distributed integer in
  {0, ..., n-1} from default-random-source.  n must be a positive exact
  integer.  default-random-source starts in a fixed state, so call
  (random-source-randomize! default-random-source) first for different
  numbers on every run.
Example:
  (< (random-integer 10) 10) => #t"
      (%default-integers n))

    (define (random-real)
      "Syntax: (random-real)
Library: (srfi 27)
Description: Returns the next uniformly distributed flonum strictly between
  0 and 1 from default-random-source.
Example:
  (< 0 (random-real) 1) => #t"
      (%default-reals))))

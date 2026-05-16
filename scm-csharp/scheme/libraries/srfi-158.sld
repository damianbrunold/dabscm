(define-library (srfi 158)
  (import (scheme base) (scheme case-lambda))
  (export
    ;; Generator constructors
    generator circular-generator make-iota-generator make-range-generator
    make-coroutine-generator list->generator vector->generator
    reverse-vector->generator string->generator bytevector->generator
    make-for-each-generator make-unfold-generator
    ;; Generator operations
    gcons* gappend gflatten ggroup gmerge
    gmap gcombine gfilter gremove gstate-filter
    gtake gdrop gtake-while gdrop-while
    gdelete gdelete-neighbor-dups gindex gselect
    ;; Generator consumers
    generator->list generator->reverse-list
    generator->vector generator->vector! generator->string
    generator-fold generator-for-each generator-map->list
    generator-find generator-count generator-any generator-every
    generator-unfold
    ;; Accumulators
    make-accumulator count-accumulator list-accumulator
    reverse-list-accumulator vector-accumulator
    reverse-vector-accumulator vector-accumulator!
    string-accumulator bytevector-accumulator bytevector-accumulator!
    sum-accumulator product-accumulator)
  (begin

    ;;; Unique sentinel for "no value provided"
    (define %no-padding (list 'no-padding))

    ;;; ============================================================
    ;;; Generator Constructors
    ;;; ============================================================

    (define (generator . args)
      "Syntax: (generator arg ...)
Library: (srfi 158)
Description: Returns a generator that yields each arg in order, then returns
  end-of-file on all subsequent calls.
Example:
  (let ((g (generator 1 2 3)))
    (list (g) (g) (g) (g))) => (1 2 3 #<eof>)"
      (let ((lst args))
        (lambda ()
          (if (null? lst)
              (eof-object)
              (let ((v (car lst)))
                (set! lst (cdr lst))
                v)))))

    (define (circular-generator . args)
      "Syntax: (circular-generator arg1 arg2 ...)
Library: (srfi 158)
Description: Returns an infinite generator that cycles through the given
  arguments repeatedly. At least one argument is required.
Example:
  (let ((g (circular-generator 1 2 3)))
    (list (g) (g) (g) (g) (g))) => (1 2 3 1 2)"
      (let ((lst args))
        (lambda ()
          (when (null? lst) (set! lst args))
          (let ((v (car lst)))
            (set! lst (cdr lst))
            v))))

    (define make-iota-generator
      (case-lambda
        ((count)
         (make-iota-generator count 0 1))
        ((count start)
         (make-iota-generator count start 1))
        ((count start step)
         "Syntax: (make-iota-generator count)
       (make-iota-generator count start)
       (make-iota-generator count start step)
Library: (srfi 158)
Description: Returns a generator that yields count numbers starting from
  start (default 0) with the given step (default 1).
Example:
  (generator->list (make-iota-generator 5)) => (0 1 2 3 4)
  (generator->list (make-iota-generator 5 2 3)) => (2 5 8 11 14)"
         (let ((i 0) (val start))
           (lambda ()
             (if (>= i count)
                 (eof-object)
                 (let ((v val))
                   (set! i (+ i 1))
                   (set! val (+ val step))
                   v)))))))

    (define make-range-generator
      (case-lambda
        ((start)
         "Syntax: (make-range-generator start)
       (make-range-generator start end)
       (make-range-generator start end step)
Library: (srfi 158)
Description: Returns a generator that yields numbers from start up to
  (but not including) end, incrementing by step. If end is omitted, the
  generator is infinite. The default step is 1.
Example:
  (generator->list (make-range-generator 3 8)) => (3 4 5 6 7)
  (generator->list (make-range-generator 0 10 3)) => (0 3 6 9)"
         (let ((val start))
           (lambda ()
             (let ((v val))
               (set! val (+ val 1))
               v))))
        ((start end)
         (make-range-generator start end 1))
        ((start end step)
         (let ((val start))
           (lambda ()
             (if (>= val end)
                 (eof-object)
                 (let ((v val))
                   (set! val (+ val step))
                   v)))))))

    (define (make-coroutine-generator proc)
      "Syntax: (make-coroutine-generator proc)
Library: (srfi 158)
Description: Creates a generator from a coroutine. proc is a procedure that
  takes a yield argument. When yield is called with a value, the generator
  returns that value and suspends. When called again, the coroutine resumes
  after the yield. When proc returns, the generator yields end-of-file.
Example:
  (generator->list (make-coroutine-generator
    (lambda (yield)
      (yield 1) (yield 2) (yield 3)))) => (1 2 3)"
      (define return #f)
      (define resume #f)
      (define (yield v)
        (call-with-current-continuation
          (lambda (r)
            (set! resume r)
            (return v))))
      (lambda ()
        (call-with-current-continuation
          (lambda (cc)
            (set! return cc)
            (if resume
                (resume #t)
                (begin (proc yield)
                       (return (eof-object))))))))

    (define list->generator
      (case-lambda
        ((lst)
         "Syntax: (list->generator lis)
Library: (srfi 158)
Description: Returns a generator that yields each element of lis in order.
Example:
  (generator->list (list->generator '(a b c))) => (a b c)"
         (let ((l lst))
           (lambda ()
             (if (null? l)
                 (eof-object)
                 (let ((v (car l)))
                   (set! l (cdr l))
                   v)))))))

    (define vector->generator
      (case-lambda
        ((vec)
         (vector->generator vec 0 (vector-length vec)))
        ((vec start)
         (vector->generator vec start (vector-length vec)))
        ((vec start end)
         "Syntax: (vector->generator vec)
       (vector->generator vec start)
       (vector->generator vec start end)
Library: (srfi 158)
Description: Returns a generator that yields elements of vec from index start
  (inclusive, default 0) to end (exclusive, default length).
Example:
  (generator->list (vector->generator '#(a b c d e) 1 4)) => (b c d)"
         (let ((i start))
           (lambda ()
             (if (>= i end)
                 (eof-object)
                 (let ((v (vector-ref vec i)))
                   (set! i (+ i 1))
                   v)))))))

    (define reverse-vector->generator
      (case-lambda
        ((vec)
         (reverse-vector->generator vec 0 (vector-length vec)))
        ((vec start)
         (reverse-vector->generator vec start (vector-length vec)))
        ((vec start end)
         "Syntax: (reverse-vector->generator vec)
       (reverse-vector->generator vec start)
       (reverse-vector->generator vec start end)
Library: (srfi 158)
Description: Returns a generator that yields elements of vec from index end-1
  down to start, i.e. in reverse order.
Example:
  (generator->list (reverse-vector->generator '#(a b c d e) 1 4))
    => (d c b)"
         (let ((i (- end 1)))
           (lambda ()
             (if (< i start)
                 (eof-object)
                 (let ((v (vector-ref vec i)))
                   (set! i (- i 1))
                   v)))))))

    (define string->generator
      (case-lambda
        ((str)
         (string->generator str 0 (string-length str)))
        ((str start)
         (string->generator str start (string-length str)))
        ((str start end)
         "Syntax: (string->generator str)
       (string->generator str start)
       (string->generator str start end)
Library: (srfi 158)
Description: Returns a generator that yields characters of str from index
  start (inclusive) to end (exclusive).
Example:
  (generator->list (string->generator \"abc\")) => (#\\a #\\b #\\c)"
         (let ((i start))
           (lambda ()
             (if (>= i end)
                 (eof-object)
                 (let ((v (string-ref str i)))
                   (set! i (+ i 1))
                   v)))))))

    (define bytevector->generator
      (case-lambda
        ((bv)
         (bytevector->generator bv 0 (bytevector-length bv)))
        ((bv start)
         (bytevector->generator bv start (bytevector-length bv)))
        ((bv start end)
         "Syntax: (bytevector->generator bv)
       (bytevector->generator bv start)
       (bytevector->generator bv start end)
Library: (srfi 158)
Description: Returns a generator that yields bytes of bv from index start
  (inclusive) to end (exclusive).
Example:
  (generator->list (bytevector->generator #u8(10 20 30))) => (10 20 30)"
         (let ((i start))
           (lambda ()
             (if (>= i end)
                 (eof-object)
                 (let ((v (bytevector-u8-ref bv i)))
                   (set! i (+ i 1))
                   v)))))))

    (define (make-for-each-generator for-each obj)
      "Syntax: (make-for-each-generator for-each obj)
Library: (srfi 158)
Description: Creates a generator from any collection by using a for-each
  procedure. for-each must accept a procedure and obj as arguments and
  apply the procedure to each element of obj.
Example:
  (generator->list (make-for-each-generator for-each '(a b c))) => (a b c)
  (generator->list (make-for-each-generator string-for-each \"abc\"))
    => (#\\a #\\b #\\c)"
      (make-coroutine-generator
        (lambda (yield)
          (for-each yield obj))))

    (define (make-unfold-generator stop? mapper successor seed)
      "Syntax: (make-unfold-generator stop? mapper successor seed)
Library: (srfi 158)
Description: Creates a generator that unfolds a sequence. Starting from seed,
  if stop? returns true, the generator is done. Otherwise it yields
  (mapper seed), then updates seed to (successor seed) and repeats.
Example:
  (generator->list (make-unfold-generator
    (lambda (s) (> s 5))
    (lambda (s) (* s s))
    (lambda (s) (+ s 1))
    1)) => (1 4 9 16 25)"
      (let ((s seed) (done #f))
        (lambda ()
          (if done
              (eof-object)
              (if (stop? s)
                  (begin (set! done #t) (eof-object))
                  (let ((v (mapper s)))
                    (set! s (successor s))
                    v))))))

    ;;; ============================================================
    ;;; Generator Operations
    ;;; ============================================================

    (define (gcons* . args)
      "Syntax: (gcons* item ... gen)
Library: (srfi 158)
Description: Returns a generator that yields each item, then yields the
  values from gen. The last argument must be a generator.
Example:
  (generator->list (gcons* 'a 'b (generator 1 2 3)))
    => (a b 1 2 3)"
      (let* ((rev (reverse args))
             (gen (car rev))
             (items (reverse (cdr rev))))
        (let ((lst items))
          (lambda ()
            (if (null? lst)
                (gen)
                (let ((v (car lst)))
                  (set! lst (cdr lst))
                  v))))))

    (define (gappend . gens)
      "Syntax: (gappend gen ...)
Library: (srfi 158)
Description: Returns a generator that yields all values from the first
  generator, then all from the second, and so on.
Example:
  (generator->list (gappend (generator 1 2) (generator 3 4)))
    => (1 2 3 4)"
      (let ((gs gens))
        (lambda ()
          (let loop ()
            (if (null? gs)
                (eof-object)
                (let ((v ((car gs))))
                  (if (eof-object? v)
                      (begin (set! gs (cdr gs))
                             (loop))
                      v)))))))

    (define (gflatten gen)
      "Syntax: (gflatten gen)
Library: (srfi 158)
Description: Returns a generator that yields elements from lists produced
  by gen. Each value from gen must be a list; their elements are yielded
  in order.
Example:
  (generator->list (gflatten (generator '(1 2) '() '(3 4 5))))
    => (1 2 3 4 5)"
      (let ((current '()))
        (lambda ()
          (let loop ()
            (if (null? current)
                (let ((v (gen)))
                  (if (eof-object? v)
                      (eof-object)
                      (begin (set! current v)
                             (loop))))
                (let ((val (car current)))
                  (set! current (cdr current))
                  val))))))

    (define ggroup
      (case-lambda
        ((gen k)
         (ggroup gen k %no-padding))
        ((gen k padding)
         "Syntax: (ggroup gen k)
       (ggroup gen k padding)
Library: (srfi 158)
Description: Returns a generator that groups consecutive elements from gen
  into lists of k elements. If padding is given and the last group has fewer
  than k elements, it is padded to length k. Without padding, the last group
  may be shorter.
Example:
  (generator->list (ggroup (generator 1 2 3 4 5) 2))
    => ((1 2) (3 4) (5))
  (generator->list (ggroup (generator 1 2 3 4 5) 2 0))
    => ((1 2) (3 4) (5 0))"
         (let ((use-padding (not (eq? padding %no-padding)))
               (done #f))
           (lambda ()
             (if done
                 (eof-object)
                 (let loop ((i 0) (acc '()))
                   (if (= i k)
                       (reverse acc)
                       (let ((v (gen)))
                         (if (eof-object? v)
                             (if (null? acc)
                                 (begin (set! done #t) (eof-object))
                                 (begin
                                   (set! done #t)
                                   (if use-padding
                                       (let pad-loop ((j i) (a acc))
                                         (if (= j k)
                                             (reverse a)
                                             (pad-loop (+ j 1) (cons padding a))))
                                       (reverse acc))))
                             (loop (+ i 1) (cons v acc))))))))))))

    (define (gmerge less-than gen1 . gens)
      "Syntax: (gmerge less-than gen1 gen2 ...)
Library: (srfi 158)
Description: Returns a generator that merges values from multiple sorted
  generators into a single sorted sequence using the less-than predicate.
Example:
  (generator->list (gmerge < (generator 1 3 5) (generator 2 4 6)))
    => (1 2 3 4 5 6)"
      (let* ((gen-vec (list->vector (cons gen1 gens)))
             (n (vector-length gen-vec))
             (buf (let ((v (make-vector n)))
                    (do ((i 0 (+ i 1)))
                        ((= i n) v)
                      (vector-set! v i ((vector-ref gen-vec i)))))))
        (lambda ()
          ;; Find the minimum buffered value across all generators
          (let loop ((i 0) (min-idx -1) (min-val #f))
            (if (= i n)
                (if (< min-idx 0)
                    (eof-object)
                    (let ((result min-val))
                      (vector-set! buf min-idx
                                   ((vector-ref gen-vec min-idx)))
                      result))
                (let ((v (vector-ref buf i)))
                  (if (eof-object? v)
                      (loop (+ i 1) min-idx min-val)
                      (if (or (< min-idx 0) (less-than v min-val))
                          (loop (+ i 1) i v)
                          (loop (+ i 1) min-idx min-val)))))))))

    (define (gmap proc gen . gens)
      "Syntax: (gmap proc gen gen2 ...)
Library: (srfi 158)
Description: Returns a generator that applies proc to the values yielded
  by the given generators. With multiple generators, stops when any
  generator is exhausted.
Example:
  (generator->list (gmap + (generator 1 2 3) (generator 10 20 30)))
    => (11 22 33)"
      (if (null? gens)
          ;; Single generator fast path
          (lambda ()
            (let ((v (gen)))
              (if (eof-object? v)
                  (eof-object)
                  (proc v))))
          ;; Multiple generators
          (let ((all-gens (cons gen gens)))
            (lambda ()
              (let ((vals (map (lambda (g) (g)) all-gens)))
                (if (any eof-object? vals)
                    (eof-object)
                    (apply proc vals)))))))

    (define (gcombine proc seed gen . gens)
      "Syntax: (gcombine proc seed gen gen2 ...)
Library: (srfi 158)
Description: Returns a generator. Each time it is called, it applies proc
  to the next values from the generators and the current seed. proc must
  return two values: the yielded value and the new seed.
Example:
  (generator->list (gcombine (lambda (x s) (values (* x x) (+ s x)))
                             0 (generator 1 2 3 4 5)))
    => (1 4 9 16 25)"
      (let ((s seed)
            (all-gens (cons gen gens)))
        (lambda ()
          (let ((vals (map (lambda (g) (g)) all-gens)))
            (if (any eof-object? vals)
                (eof-object)
                (call-with-values
                  (lambda () (apply proc (append vals (list s))))
                  (lambda (value new-seed)
                    (set! s new-seed)
                    value)))))))

    (define (gfilter pred gen)
      "Syntax: (gfilter pred gen)
Library: (srfi 158)
Description: Returns a generator that yields only values from gen for which
  pred returns true.
Example:
  (generator->list (gfilter odd? (generator 1 2 3 4 5))) => (1 3 5)"
      (lambda ()
        (let loop ()
          (let ((v (gen)))
            (if (eof-object? v)
                (eof-object)
                (if (pred v) v (loop)))))))

    (define (gremove pred gen)
      "Syntax: (gremove pred gen)
Library: (srfi 158)
Description: Returns a generator that yields only values from gen for which
  pred returns false. Equivalent to (gfilter (lambda (x) (not (pred x))) gen).
Example:
  (generator->list (gremove odd? (generator 1 2 3 4 5))) => (2 4)"
      (gfilter (lambda (x) (not (pred x))) gen))

    (define (gstate-filter proc seed gen)
      "Syntax: (gstate-filter proc seed gen)
Library: (srfi 158)
Description: Returns a generator that filters values from gen using stateful
  predicate proc. proc takes the current seed and a value, and returns two
  values: the new seed and a boolean. If the boolean is true, the value is
  yielded; otherwise it is skipped.
Example:
  (generator->list (gstate-filter
    (lambda (s v) (values (+ s 1) (even? s)))
    0 (generator 'a 'b 'c 'd 'e))) => (a c e)"
      (let ((s seed))
        (lambda ()
          (let loop ()
            (let ((v (gen)))
              (if (eof-object? v)
                  (eof-object)
                  (call-with-values
                    (lambda () (proc s v))
                    (lambda (new-seed keep?)
                      (set! s new-seed)
                      (if keep? v (loop))))))))))

    (define gtake
      (case-lambda
        ((gen k)
         (gtake gen k %no-padding))
        ((gen k padding)
         "Syntax: (gtake gen k)
       (gtake gen k padding)
Library: (srfi 158)
Description: Returns a generator that yields at most k values from gen. If
  gen is exhausted before k values and padding is given, padding is used to
  fill the remaining values. Without padding, the generator stops early.
Example:
  (generator->list (gtake (generator 1 2 3 4 5) 3)) => (1 2 3)
  (generator->list (gtake (generator 1 2) 4 0)) => (1 2 0 0)"
         (let ((i 0) (use-padding (not (eq? padding %no-padding))))
           (lambda ()
             (if (>= i k)
                 (eof-object)
                 (begin
                   (set! i (+ i 1))
                   (let ((v (gen)))
                     (if (eof-object? v)
                         (if use-padding padding (eof-object))
                         v)))))))))

    (define (gdrop gen k)
      "Syntax: (gdrop gen k)
Library: (srfi 158)
Description: Returns a generator that skips the first k values from gen,
  then yields the remaining values.
Example:
  (generator->list (gdrop (generator 1 2 3 4 5) 3)) => (4 5)"
      (let ((dropped #f))
        (lambda ()
          (when (not dropped)
            (set! dropped #t)
            (let loop ((n 0))
              (when (< n k)
                (let ((v (gen)))
                  (unless (eof-object? v) (loop (+ n 1)))))))
          (gen))))

    (define (gtake-while pred gen)
      "Syntax: (gtake-while pred gen)
Library: (srfi 158)
Description: Returns a generator that yields values from gen as long as pred
  returns true. Stops as soon as pred returns false.
Example:
  (generator->list (gtake-while (lambda (x) (< x 4))
    (generator 1 2 3 4 5))) => (1 2 3)"
      (let ((done #f))
        (lambda ()
          (if done
              (eof-object)
              (let ((v (gen)))
                (if (eof-object? v)
                    (eof-object)
                    (if (pred v)
                        v
                        (begin (set! done #t) (eof-object)))))))))

    (define (gdrop-while pred gen)
      "Syntax: (gdrop-while pred gen)
Library: (srfi 158)
Description: Returns a generator that skips values from gen while pred
  returns true, then yields all remaining values.
Example:
  (generator->list (gdrop-while (lambda (x) (< x 3))
    (generator 1 2 3 4 5))) => (3 4 5)"
      (let ((dropping #t))
        (lambda ()
          (if dropping
              (let loop ()
                (let ((v (gen)))
                  (cond
                    ((eof-object? v) (eof-object))
                    ((pred v) (loop))
                    (else (set! dropping #f) v))))
              (gen)))))

    (define gdelete
      (case-lambda
        ((item gen)
         (gdelete item gen equal?))
        ((item gen =)
         "Syntax: (gdelete item gen)
       (gdelete item gen =)
Library: (srfi 158)
Description: Returns a generator that yields all values from gen except those
  equal to item. The optional = argument specifies the equality predicate
  (default: equal?).
Example:
  (generator->list (gdelete 3 (generator 1 2 3 4 3 5))) => (1 2 4 5)"
         (gfilter (lambda (v) (not (= item v))) gen))))

    (define gdelete-neighbor-dups
      (case-lambda
        ((gen)
         (gdelete-neighbor-dups gen equal?))
        ((gen =)
         "Syntax: (gdelete-neighbor-dups gen)
       (gdelete-neighbor-dups gen =)
Library: (srfi 158)
Description: Returns a generator that removes consecutive duplicate values
  from gen. The optional = argument specifies the equality predicate
  (default: equal?).
Example:
  (generator->list (gdelete-neighbor-dups
    (generator 1 1 2 3 3 3 4))) => (1 2 3 4)"
         (let ((first #t) (prev #f))
           (lambda ()
             (let loop ()
               (let ((v (gen)))
                 (cond
                   ((eof-object? v) (eof-object))
                   (first
                    (set! first #f)
                    (set! prev v)
                    v)
                   ((= prev v) (loop))
                   (else
                    (set! prev v)
                    v)))))))))

    (define (gindex value-gen index-gen)
      "Syntax: (gindex value-gen index-gen)
Library: (srfi 158)
Description: Returns a generator that yields elements from value-gen at
  positions specified by index-gen. index-gen must yield monotonically
  increasing non-negative integers.
Example:
  (generator->list (gindex (generator 'a 'b 'c 'd 'e)
                           (generator 0 2 4))) => (a c e)"
      (let ((current-idx 0))
        (lambda ()
          (let ((target (index-gen)))
            (if (eof-object? target)
                (eof-object)
                (let loop ()
                  (let ((v (value-gen)))
                    (cond
                      ((eof-object? v) (eof-object))
                      ((= current-idx target)
                       (set! current-idx (+ current-idx 1))
                       v)
                      (else
                       (set! current-idx (+ current-idx 1))
                       (loop))))))))))

    (define (gselect value-gen truth-gen)
      "Syntax: (gselect value-gen truth-gen)
Library: (srfi 158)
Description: Returns a generator that yields values from value-gen where
  truth-gen yields a true value. Both generators are advanced in lockstep.
Example:
  (generator->list (gselect (generator 'a 'b 'c 'd 'e)
                            (generator #t #f #t #f #t))) => (a c e)"
      (lambda ()
        (let loop ()
          (let ((v (value-gen))
                (t (truth-gen)))
            (cond
              ((or (eof-object? v) (eof-object? t)) (eof-object))
              (t v)
              (else (loop)))))))

    ;;; ============================================================
    ;;; Generator Consumers
    ;;; ============================================================

    (define generator->list
      (case-lambda
        ((gen)
         "Syntax: (generator->list gen)
       (generator->list gen k)
Library: (srfi 158)
Description: Reads values from gen and returns them as a list. If k is given,
  reads at most k values.
Example:
  (generator->list (generator 1 2 3)) => (1 2 3)
  (generator->list (generator 1 2 3 4 5) 3) => (1 2 3)"
         (let loop ((acc '()))
           (let ((v (gen)))
             (if (eof-object? v)
                 (reverse acc)
                 (loop (cons v acc))))))
        ((gen k)
         (let loop ((acc '()) (i 0))
           (if (>= i k)
               (reverse acc)
               (let ((v (gen)))
                 (if (eof-object? v)
                     (reverse acc)
                     (loop (cons v acc) (+ i 1)))))))))

    (define generator->reverse-list
      (case-lambda
        ((gen)
         "Syntax: (generator->reverse-list gen)
       (generator->reverse-list gen k)
Library: (srfi 158)
Description: Like generator->list, but returns the values in reverse order.
Example:
  (generator->reverse-list (generator 1 2 3)) => (3 2 1)"
         (let loop ((acc '()))
           (let ((v (gen)))
             (if (eof-object? v)
                 acc
                 (loop (cons v acc))))))
        ((gen k)
         (let loop ((acc '()) (i 0))
           (if (>= i k)
               acc
               (let ((v (gen)))
                 (if (eof-object? v)
                     acc
                     (loop (cons v acc) (+ i 1)))))))))

    (define generator->vector
      (case-lambda
        ((gen)
         "Syntax: (generator->vector gen)
       (generator->vector gen k)
Library: (srfi 158)
Description: Reads values from gen and returns them as a vector. If k is
  given, reads at most k values.
Example:
  (generator->vector (generator 1 2 3)) => #(1 2 3)"
         (list->vector (generator->list gen)))
        ((gen k)
         (list->vector (generator->list gen k)))))

    (define (generator->vector! vec at gen)
      "Syntax: (generator->vector! vec at gen)
Library: (srfi 158)
Description: Fills vec starting at index at with values from gen. Returns
  the number of elements written.
Example:
  (let ((v (make-vector 5 0)))
    (generator->vector! v 1 (generator 'a 'b 'c))
    v) => #(0 a b c 0)"
      (let loop ((i at))
        (if (>= i (vector-length vec))
            (- i at)
            (let ((v (gen)))
              (if (eof-object? v)
                  (- i at)
                  (begin
                    (vector-set! vec i v)
                    (loop (+ i 1))))))))

    (define generator->string
      (case-lambda
        ((gen)
         "Syntax: (generator->string gen)
       (generator->string gen k)
Library: (srfi 158)
Description: Reads characters from gen and returns them as a string. If k is
  given, reads at most k characters.
Example:
  (generator->string (generator #\\a #\\b #\\c)) => \"abc\""
         (list->string (generator->list gen)))
        ((gen k)
         (list->string (generator->list gen k)))))

    (define (generator-fold proc seed gen . gens)
      "Syntax: (generator-fold proc seed gen gen2 ...)
Library: (srfi 158)
Description: Folds over generator values. proc is called with each generated
  value (or set of values from multiple generators) and the current
  accumulator, returning the new accumulator. Returns the final accumulator
  when any generator is exhausted.
Example:
  (generator-fold + 0 (generator 1 2 3 4 5)) => 15
  (generator-fold cons '() (generator 1 2 3)) => (3 2 1)"
      (if (null? gens)
          ;; Single generator fast path
          (let loop ((s seed))
            (let ((v (gen)))
              (if (eof-object? v)
                  s
                  (loop (proc v s)))))
          ;; Multiple generators
          (let ((all-gens (cons gen gens)))
            (let loop ((s seed))
              (let ((vals (map (lambda (g) (g)) all-gens)))
                (if (any eof-object? vals)
                    s
                    (loop (apply proc (append vals (list s))))))))))

    (define (generator-for-each proc gen . gens)
      "Syntax: (generator-for-each proc gen gen2 ...)
Library: (srfi 158)
Description: Applies proc to each value from gen (or sets of values from
  multiple generators) for side effects. Stops when any generator is
  exhausted.
Example:
  (let ((sum 0))
    (generator-for-each (lambda (x) (set! sum (+ sum x)))
      (generator 1 2 3 4 5))
    sum) => 15"
      (if (null? gens)
          ;; Single generator fast path
          (let loop ()
            (let ((v (gen)))
              (unless (eof-object? v)
                (proc v)
                (loop))))
          ;; Multiple generators
          (let ((all-gens (cons gen gens)))
            (let loop ()
              (let ((vals (map (lambda (g) (g)) all-gens)))
                (unless (any eof-object? vals)
                  (apply proc vals)
                  (loop)))))))

    (define (generator-map->list proc gen . gens)
      "Syntax: (generator-map->list proc gen gen2 ...)
Library: (srfi 158)
Description: Applies proc to each value from the generators and collects
  the results into a list. Stops when any generator is exhausted.
Example:
  (generator-map->list square (generator 1 2 3 4 5))
    => (1 4 9 16 25)"
      (if (null? gens)
          ;; Single generator fast path
          (let loop ((acc '()))
            (let ((v (gen)))
              (if (eof-object? v)
                  (reverse acc)
                  (loop (cons (proc v) acc)))))
          ;; Multiple generators
          (let ((all-gens (cons gen gens)))
            (let loop ((acc '()))
              (let ((vals (map (lambda (g) (g)) all-gens)))
                (if (any eof-object? vals)
                    (reverse acc)
                    (loop (cons (apply proc vals) acc))))))))

    (define (generator-find pred gen)
      "Syntax: (generator-find pred gen)
Library: (srfi 158)
Description: Returns the first value from gen for which pred returns true,
  or #f if no such value exists. Note: consumes values from gen up to and
  including the found value.
Example:
  (generator-find even? (generator 1 3 5 6 7)) => 6"
      (let loop ()
        (let ((v (gen)))
          (cond
            ((eof-object? v) #f)
            ((pred v) v)
            (else (loop))))))

    (define (generator-count pred gen)
      "Syntax: (generator-count pred gen)
Library: (srfi 158)
Description: Returns the number of values from gen for which pred returns
  true. Consumes the entire generator.
Example:
  (generator-count even? (generator 1 2 3 4 5)) => 2"
      (let loop ((n 0))
        (let ((v (gen)))
          (if (eof-object? v)
              n
              (loop (if (pred v) (+ n 1) n))))))

    (define (generator-any pred gen)
      "Syntax: (generator-any pred gen)
Library: (srfi 158)
Description: Returns the first true value of (pred val) for values from gen,
  or #f if pred returns false for all values. Consumes gen up to the first
  true result.
Example:
  (generator-any odd? (generator 2 4 6 7 8)) => #t"
      (let loop ()
        (let ((v (gen)))
          (if (eof-object? v)
              #f
              (let ((r (pred v)))
                (if r r (loop)))))))

    (define (generator-every pred gen)
      "Syntax: (generator-every pred gen)
Library: (srfi 158)
Description: Returns the last true value of (pred val) for values from gen,
  or #t if the generator is empty. Returns #f as soon as pred returns false.
Example:
  (generator-every odd? (generator 1 3 5 7)) => #t
  (generator-every odd? (generator 1 3 4 5)) => #f"
      (let loop ((last #t))
        (let ((v (gen)))
          (if (eof-object? v)
              last
              (let ((r (pred v)))
                (if r (loop r) #f))))))

    (define (generator-unfold gen unfold . args)
      "Syntax: (generator-unfold gen unfold arg ...)
Library: (srfi 158)
Description: Uses the unfold procedure to convert generator values into a
  data structure. Equivalent to (unfold eof-object? (lambda (x) x) (lambda
  (x) (gen)) (gen) args ...). The unfold argument must be compatible with
  SRFI 1 unfold.
Example:
  (generator-unfold (generator 1 2 3) unfold) ; requires (srfi 1)"
      (apply unfold eof-object? (lambda (x) x) (lambda (x) (gen)) (gen)
             args))

    ;;; ============================================================
    ;;; Internal helper: any (avoids importing srfi-1 just for this)
    ;;; ============================================================

    (define (any pred lst)
      (cond
        ((null? lst) #f)
        ((pred (car lst)) #t)
        (else (any pred (cdr lst)))))

    ;;; ============================================================
    ;;; Accumulators
    ;;; ============================================================

    (define (make-accumulator kons knil finalizer)
      "Syntax: (make-accumulator kons knil finalizer)
Library: (srfi 158)
Description: Creates an accumulator. When called with a value, applies kons
  to the value and current state (initialized to knil). When called with
  end-of-file, applies finalizer to the state and returns the result.
Example:
  (let ((a (make-accumulator cons '() reverse)))
    (a 1) (a 2) (a 3) (a (eof-object))) => (1 2 3)"
      (let ((state knil))
        (lambda (v)
          (if (eof-object? v)
              (finalizer state)
              (set! state (kons v state))))))

    (define (count-accumulator)
      "Syntax: (count-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that counts the number of values
  accumulated. Returns the count when called with end-of-file.
Example:
  (let ((a (count-accumulator)))
    (a 'x) (a 'y) (a 'z) (a (eof-object))) => 3"
      (make-accumulator (lambda (v n) (+ n 1)) 0 (lambda (x) x)))

    (define (list-accumulator)
      "Syntax: (list-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects values into a list in
  order. Returns the list when called with end-of-file.
Example:
  (let ((a (list-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => (1 2 3)"
      (make-accumulator cons '() reverse))

    (define (reverse-list-accumulator)
      "Syntax: (reverse-list-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects values into a list in
  reverse order. Returns the reversed list when called with end-of-file.
Example:
  (let ((a (reverse-list-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => (3 2 1)"
      (make-accumulator cons '() (lambda (x) x)))

    (define (vector-accumulator)
      "Syntax: (vector-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects values into a vector in
  order. Returns the vector when called with end-of-file.
Example:
  (let ((a (vector-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => #(1 2 3)"
      (make-accumulator cons '() (lambda (x) (list->vector (reverse x)))))

    (define (reverse-vector-accumulator)
      "Syntax: (reverse-vector-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects values into a vector in
  reverse order. Returns the vector when called with end-of-file.
Example:
  (let ((a (reverse-vector-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => #(3 2 1)"
      (make-accumulator cons '() list->vector))

    (define (vector-accumulator! vec at)
      "Syntax: (vector-accumulator! vec at)
Library: (srfi 158)
Description: Returns an accumulator that stores values into vec starting
  at index at. Returns vec when called with end-of-file.
Example:
  (let* ((v (make-vector 5 0))
         (a (vector-accumulator! v 1)))
    (a 'a) (a 'b) (a 'c) (a (eof-object))) => #(0 a b c 0)"
      (let ((i at))
        (lambda (v)
          (if (eof-object? v)
              vec
              (begin
                (vector-set! vec i v)
                (set! i (+ i 1)))))))

    (define (string-accumulator)
      "Syntax: (string-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects characters into a string.
  Returns the string when called with end-of-file.
Example:
  (let ((a (string-accumulator)))
    (a #\\a) (a #\\b) (a #\\c) (a (eof-object))) => \"abc\""
      (make-accumulator cons '() (lambda (x) (list->string (reverse x)))))

    (define (bytevector-accumulator)
      "Syntax: (bytevector-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that collects bytes into a bytevector.
  Returns the bytevector when called with end-of-file.
Example:
  (let ((a (bytevector-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => #u8(1 2 3)"
      (make-accumulator cons '() (lambda (x) (apply bytevector (reverse x)))))

    (define (bytevector-accumulator! bv at)
      "Syntax: (bytevector-accumulator! bv at)
Library: (srfi 158)
Description: Returns an accumulator that stores bytes into bv starting
  at index at. Returns bv when called with end-of-file.
Example:
  (let* ((bv (make-bytevector 5 0))
         (a (bytevector-accumulator! bv 1)))
    (a 10) (a 20) (a 30) (a (eof-object))) => #u8(0 10 20 30 0)"
      (let ((i at))
        (lambda (v)
          (if (eof-object? v)
              bv
              (begin
                (bytevector-u8-set! bv i v)
                (set! i (+ i 1)))))))

    (define (sum-accumulator)
      "Syntax: (sum-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that computes the sum of accumulated
  values. Returns the sum when called with end-of-file.
Example:
  (let ((a (sum-accumulator)))
    (a 1) (a 2) (a 3) (a (eof-object))) => 6"
      (make-accumulator + 0 (lambda (x) x)))

    (define (product-accumulator)
      "Syntax: (product-accumulator)
Library: (srfi 158)
Description: Returns an accumulator that computes the product of accumulated
  values. Returns the product when called with end-of-file.
Example:
  (let ((a (product-accumulator)))
    (a 1) (a 2) (a 3) (a 4) (a (eof-object))) => 24"
      (make-accumulator * 1 (lambda (x) x)))

    ))

(define-library (srfi 133)
  (import (scheme base) (scheme cxr))
  (export
    ;; Constructors
    make-vector vector vector-unfold vector-unfold-right
    vector-copy vector-reverse-copy
    vector-append vector-concatenate vector-append-subvectors
    ;; Predicates
    vector? vector-empty? vector=
    ;; Selectors
    vector-ref vector-length
    ;; Iteration
    vector-fold vector-fold-right
    vector-map vector-map! vector-for-each
    vector-count vector-cumulate
    ;; Searching
    vector-index vector-index-right
    vector-skip vector-skip-right
    vector-binary-search
    vector-any vector-every
    vector-partition
    ;; Mutators
    vector-set! vector-swap!
    vector-fill! vector-reverse!
    vector-copy! vector-reverse-copy!
    vector-unfold! vector-unfold-right!
    ;; Conversion
    vector->list reverse-vector->list
    list->vector reverse-list->vector
    vector->string string->vector)
  (begin

    ;;; Internal helper: parse optional start/end arguments
    (define (%start-end v args)
      (let ((start (if (null? args) 0 (car args)))
            (end (if (or (null? args) (null? (cdr args)))
                     (vector-length v) (cadr args))))
        (values start end)))

    ;;; --- Constructors ---

    (define (vector-unfold f length . seeds)
      "Syntax: (vector-unfold f length seed ...)
Library: (srfi 133)
Description: Creates a vector of the given length by applying f to each index
  and the current seed values. f must return the element value followed by
  new seed values via multiple return values.
Example:
  (vector-unfold (lambda (i) i) 5) => #(0 1 2 3 4)
  (vector-unfold (lambda (i x) (values x (+ x 1))) 5 0) => #(0 1 2 3 4)"
      (let ((v (make-vector length)))
        (let loop ((i 0) (seeds seeds))
          (if (= i length) v
              (call-with-values
                (lambda () (apply f i seeds))
                (lambda (value . new-seeds)
                  (vector-set! v i value)
                  (loop (+ i 1) new-seeds)))))))

    (define (vector-unfold-right f length . seeds)
      "Syntax: (vector-unfold-right f length seed ...)
Library: (srfi 133)
Description: Like vector-unfold, but fills the vector from right to left,
  starting at index length-1 down to 0.
Example:
  (vector-unfold-right (lambda (i x) (values x (+ x 1))) 5 0)
    => #(4 3 2 1 0)"
      (let ((v (make-vector length)))
        (let loop ((i (- length 1)) (seeds seeds))
          (if (< i 0) v
              (call-with-values
                (lambda () (apply f i seeds))
                (lambda (value . new-seeds)
                  (vector-set! v i value)
                  (loop (- i 1) new-seeds)))))))

    ;; Override vector-copy to support optional fill argument
    (define (vector-copy v . args)
      "Syntax: (vector-copy vec)
       (vector-copy vec start)
       (vector-copy vec start end)
       (vector-copy vec start end fill)
Library: (srfi 133)
Description: Returns a newly allocated copy of the elements of vec between
  start and end. If end is greater than the length of vec, the additional
  elements are set to fill.
Example:
  (vector-copy '#(a b c d e) 1 3) => #(b c)
  (vector-copy '#(a b c) 0 5 'x) => #(a b c x x)"
      (let* ((start (if (null? args) 0 (car args)))
             (rest1 (if (null? args) '() (cdr args)))
             (end (if (null? rest1) (vector-length v) (car rest1)))
             (rest2 (if (null? rest1) '() (cdr rest1)))
             (fill (if (null? rest2) #f (car rest2)))
             (len (- end start))
             (result (make-vector len fill)))
        (let ((copy-end (min end (vector-length v))))
          (do ((i start (+ i 1)))
              ((= i copy-end) result)
            (vector-set! result (- i start) (vector-ref v i))))))

    (define (vector-reverse-copy v . args)
      "Syntax: (vector-reverse-copy vec)
       (vector-reverse-copy vec start)
       (vector-reverse-copy vec start end)
Library: (srfi 133)
Description: Returns a newly allocated vector containing the elements of vec
  between start and end in reverse order.
Example:
  (vector-reverse-copy '#(a b c d e) 1 4) => #(d c b)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (let* ((len (- end start))
                 (result (make-vector len)))
            (do ((i start (+ i 1))
                 (j (- len 1) (- j 1)))
                ((= i end) result)
              (vector-set! result j (vector-ref v i)))))))

    (define (vector-concatenate vecs)
      "Syntax: (vector-concatenate list-of-vectors)
Library: (srfi 133)
Description: Appends each vector in list-of-vectors. Equivalent to
  (apply vector-append list-of-vectors).
Example:
  (vector-concatenate '(#(a b) #(c d))) => #(a b c d)"
      (apply vector-append vecs))

    (define (vector-append-subvectors . args)
      "Syntax: (vector-append-subvectors vec1 start1 end1 ...)
Library: (srfi 133)
Description: Returns a vector that contains every element of each vec from
  start to end in order. The arguments alternate between vectors and
  start/end index pairs.
Example:
  (vector-append-subvectors '#(a b c d e) 0 2 '#(f g h) 1 3)
    => #(a b g h)"
      (let loop ((args args) (vecs '()))
        (if (null? args)
            (vector-concatenate (reverse vecs))
            (let ((v (car args))
                  (start (cadr args))
                  (end (caddr args)))
              (loop (cdddr args)
                    (cons (vector-copy v start end) vecs))))))

    ;;; --- Predicates ---

    (define (vector-empty? v)
      "Syntax: (vector-empty? vec)
Library: (srfi 133)
Description: Returns #t if vec has length 0, #f otherwise.
Example:
  (vector-empty? '#()) => #t
  (vector-empty? '#(1)) => #f"
      (= (vector-length v) 0))

    (define (vector= elt= . vecs)
      "Syntax: (vector= elt= vec ...)
Library: (srfi 133)
Description: Compares vectors element-wise using elt= as the element
  comparison procedure. Returns #t if all vectors have the same length and
  corresponding elements are equal according to elt=.
Example:
  (vector= eq? '#(a b c) '#(a b c)) => #t
  (vector= eq? '#(a b) '#(a b c)) => #f"
      (or (null? vecs) (null? (cdr vecs))
          (let loop ((vecs vecs))
            (or (null? (cdr vecs))
                (let ((v1 (car vecs)) (v2 (cadr vecs)))
                  (and (= (vector-length v1) (vector-length v2))
                       (let iloop ((i 0))
                         (or (= i (vector-length v1))
                             (and (elt= (vector-ref v1 i) (vector-ref v2 i))
                                  (iloop (+ i 1)))))
                       (loop (cdr vecs))))))))

    ;;; --- Iteration ---

    (define (vector-fold kons knil . vecs)
      "Syntax: (vector-fold kons knil vec1 vec2 ...)
Library: (srfi 133)
Description: Left fold over vectors. kons is called as (kons index state
  val1 val2 ...) for each index from 0 to length-1, where length is the
  minimum length of the given vectors.
Example:
  (vector-fold (lambda (i sum x) (+ sum x)) 0 '#(1 2 3)) => 6"
      (let ((len (apply min (map vector-length vecs))))
        (let loop ((i 0) (state knil))
          (if (= i len) state
              (loop (+ i 1)
                    (apply kons i state
                           (map (lambda (v) (vector-ref v i)) vecs)))))))

    (define (vector-fold-right kons knil . vecs)
      "Syntax: (vector-fold-right kons knil vec1 vec2 ...)
Library: (srfi 133)
Description: Right fold over vectors. kons is called as (kons index state
  val1 val2 ...) for each index from length-1 down to 0.
Example:
  (vector-fold-right (lambda (i tail x) (cons x tail)) '() '#(a b c))
    => (a b c)"
      (let ((len (apply min (map vector-length vecs))))
        (let loop ((i (- len 1)) (state knil))
          (if (< i 0) state
              (loop (- i 1)
                    (apply kons i state
                           (map (lambda (v) (vector-ref v i)) vecs)))))))

    (define (vector-map! f . vecs)
      "Syntax: (vector-map! f vec1 vec2 ...)
Library: (srfi 133)
Description: Like vector-map, but stores the results in vec1, mutating it
  in place. Returns unspecified.
Example:
  (let ((v (vector 1 2 3)))
    (vector-map! (lambda (x) (* x x)) v)
    v) => #(1 4 9)"
      (let ((len (apply min (map vector-length vecs)))
            (target (car vecs)))
        (do ((i 0 (+ i 1)))
            ((= i len))
          (vector-set! target i
                       (apply f (map (lambda (v) (vector-ref v i)) vecs))))))

    (define (vector-count pred . vecs)
      "Syntax: (vector-count pred vec1 vec2 ...)
Library: (srfi 133)
Description: Counts the number of indices i for which (pred vec1[i] vec2[i]
  ...) returns true. The count is over the minimum length of the vectors.
Example:
  (vector-count even? '#(1 2 3 4 5)) => 2"
      (let ((len (apply min (map vector-length vecs))))
        (let loop ((i 0) (count 0))
          (if (= i len) count
              (loop (+ i 1)
                    (if (apply pred (map (lambda (v) (vector-ref v i)) vecs))
                        (+ count 1) count))))))

    (define (vector-cumulate f knil v)
      "Syntax: (vector-cumulate f knil vec)
Library: (srfi 133)
Description: Returns a newly allocated vector where element i is the result
  of applying f to the cumulated value and element i, starting with knil.
  Like a running fold stored in a vector.
Example:
  (vector-cumulate + 0 '#(1 2 3 4)) => #(1 3 6 10)"
      (let* ((len (vector-length v))
             (result (make-vector len)))
        (let loop ((i 0) (state knil))
          (if (= i len) result
              (let ((new-state (f state (vector-ref v i))))
                (vector-set! result i new-state)
                (loop (+ i 1) new-state))))))

    ;;; --- Searching ---

    (define (vector-index pred . vecs)
      "Syntax: (vector-index pred vec1 vec2 ...)
Library: (srfi 133)
Description: Returns the index of the first element for which (pred vec1[i]
  vec2[i] ...) returns true, or #f if no such element exists.
Example:
  (vector-index even? '#(1 2 3 4)) => 1
  (vector-index odd? '#(2 4 6)) => #f"
      (let ((len (apply min (map vector-length vecs))))
        (let loop ((i 0))
          (cond ((= i len) #f)
                ((apply pred (map (lambda (v) (vector-ref v i)) vecs)) i)
                (else (loop (+ i 1)))))))

    (define (vector-index-right pred . vecs)
      "Syntax: (vector-index-right pred vec1 vec2 ...)
Library: (srfi 133)
Description: Like vector-index, but searches from right to left, returning
  the index of the last matching element.
Example:
  (vector-index-right even? '#(1 2 3 4)) => 3"
      (let ((len (apply min (map vector-length vecs))))
        (let loop ((i (- len 1)))
          (cond ((< i 0) #f)
                ((apply pred (map (lambda (v) (vector-ref v i)) vecs)) i)
                (else (loop (- i 1)))))))

    (define (vector-skip pred . vecs)
      "Syntax: (vector-skip pred vec1 vec2 ...)
Library: (srfi 133)
Description: Returns the index of the first element for which pred returns
  #f, or #f if pred is true for all elements.
Example:
  (vector-skip odd? '#(1 3 2 4)) => 2"
      (apply vector-index (lambda args (not (apply pred args))) vecs))

    (define (vector-skip-right pred . vecs)
      "Syntax: (vector-skip-right pred vec1 vec2 ...)
Library: (srfi 133)
Description: Like vector-skip, but searches from right to left.
Example:
  (vector-skip-right odd? '#(1 3 2 4)) => 3"
      (apply vector-index-right (lambda args (not (apply pred args))) vecs))

    (define (vector-binary-search v value cmp)
      "Syntax: (vector-binary-search vec value cmp)
Library: (srfi 133)
Description: Performs binary search on a sorted vector. cmp is a procedure
  of two arguments that returns a negative integer if the first is less,
  zero if equal, and positive if greater. Returns the index of the matching
  element or #f.
Example:
  (vector-binary-search '#(1 3 5 7 9) 5
    (lambda (a b) (- a b))) => 2"
      (let loop ((lo 0) (hi (- (vector-length v) 1)))
        (if (> lo hi) #f
            (let* ((mid (+ lo (quotient (- hi lo) 2)))
                   (c (cmp (vector-ref v mid) value)))
              (cond ((= c 0) mid)
                    ((< c 0) (loop (+ mid 1) hi))
                    (else (loop lo (- mid 1))))))))

    (define (vector-any pred . vecs)
      "Syntax: (vector-any pred vec1 vec2 ...)
Library: (srfi 133)
Description: Returns the first true value returned by pred applied to
  corresponding elements, or #f if pred returns #f for all elements.
Example:
  (vector-any even? '#(1 2 3)) => #t
  (vector-any even? '#(1 3 5)) => #f"
      (let ((len (apply min (map vector-length vecs))))
        (let loop ((i 0))
          (and (< i len)
               (or (apply pred (map (lambda (v) (vector-ref v i)) vecs))
                   (loop (+ i 1)))))))

    (define (vector-every pred . vecs)
      "Syntax: (vector-every pred vec1 vec2 ...)
Library: (srfi 133)
Description: Returns the last true value returned by pred if pred returns
  true for all corresponding elements, or #f as soon as pred returns #f.
  Returns #t for empty vectors.
Example:
  (vector-every even? '#(2 4 6)) => #t
  (vector-every even? '#(2 3 6)) => #f"
      (let ((len (apply min (map vector-length vecs))))
        (or (= len 0)
            (let loop ((i 0))
              (let ((result (apply pred (map (lambda (v) (vector-ref v i)) vecs))))
                (if (= i (- len 1))
                    result
                    (and result (loop (+ i 1)))))))))

    (define (vector-partition pred v)
      "Syntax: (vector-partition pred vec)
Library: (srfi 133)
Description: Returns two values: a vector of elements satisfying pred, and
  a vector of elements not satisfying pred, both in their original order.
Example:
  (call-with-values (lambda () (vector-partition even? '#(1 2 3 4 5)))
    list) => (#(2 4) #(1 3 5))"
      (let* ((len (vector-length v))
             (yes '()) (no '()))
        (do ((i (- len 1) (- i 1)))
            ((< i 0))
          (if (pred (vector-ref v i))
              (set! yes (cons (vector-ref v i) yes))
              (set! no (cons (vector-ref v i) no))))
        (values (list->vector yes)
                (list->vector no))))

    ;;; --- Mutators ---

    (define (vector-swap! v i j)
      "Syntax: (vector-swap! vec i j)
Library: (srfi 133)
Description: Swaps the elements at indices i and j in vec.
Example:
  (let ((v (vector 'a 'b 'c)))
    (vector-swap! v 0 2)
    v) => #(c b a)"
      (let ((tmp (vector-ref v i)))
        (vector-set! v i (vector-ref v j))
        (vector-set! v j tmp)))

    ;; Override vector-fill! to support optional start/end
    (define (vector-fill! v x . args)
      "Syntax: (vector-fill! vec fill)
       (vector-fill! vec fill start)
       (vector-fill! vec fill start end)
Library: (srfi 133)
Description: Stores fill in every element of vec between start (inclusive,
  default 0) and end (exclusive, default length).
Example:
  (let ((v (vector 1 2 3 4 5)))
    (vector-fill! v 0 1 4)
    v) => #(1 0 0 0 5)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (do ((i start (+ i 1)))
              ((= i end))
            (vector-set! v i x)))))

    (define (vector-reverse! v . args)
      "Syntax: (vector-reverse! vec)
       (vector-reverse! vec start)
       (vector-reverse! vec start end)
Library: (srfi 133)
Description: Reverses the elements of vec in place between start and end.
Example:
  (let ((v (vector 1 2 3 4 5)))
    (vector-reverse! v 1 4)
    v) => #(1 4 3 2 5)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (let loop ((lo start) (hi (- end 1)))
            (when (< lo hi)
              (vector-swap! v lo hi)
              (loop (+ lo 1) (- hi 1)))))))

    (define (vector-reverse-copy! to at from . args)
      "Syntax: (vector-reverse-copy! to at from)
       (vector-reverse-copy! to at from start)
       (vector-reverse-copy! to at from start end)
Library: (srfi 133)
Description: Copies elements from the vector from between start and end in
  reverse order into the vector to, starting at index at.
Example:
  (let ((v (vector 'x 'x 'x 'x 'x)))
    (vector-reverse-copy! v 1 '#(a b c) 0 3)
    v) => #(x c b a x)"
      (call-with-values (lambda () (%start-end from args))
        (lambda (start end)
          (let ((len (- end start)))
            (do ((i start (+ i 1))
                 (j (+ at (- len 1)) (- j 1)))
                ((= i end))
              (vector-set! to j (vector-ref from i)))))))

    (define (vector-unfold! f v start end . seeds)
      "Syntax: (vector-unfold! f vec start end seed ...)
Library: (srfi 133)
Description: Like vector-unfold, but stores the elements into vec between
  start (inclusive) and end (exclusive) rather than creating a new vector.
Example:
  (let ((v (make-vector 5 0)))
    (vector-unfold! (lambda (i) (* i i)) v 1 4)
    v) => #(0 1 4 9 0)"
      (let loop ((i start) (seeds seeds))
        (when (< i end)
          (call-with-values
            (lambda () (apply f i seeds))
            (lambda (value . new-seeds)
              (vector-set! v i value)
              (loop (+ i 1) new-seeds))))))

    (define (vector-unfold-right! f v start end . seeds)
      "Syntax: (vector-unfold-right! f vec start end seed ...)
Library: (srfi 133)
Description: Like vector-unfold-right, but stores the elements into vec
  between start and end rather than creating a new vector.
Example:
  (let ((v (make-vector 5 0)))
    (vector-unfold-right! (lambda (i) (* i i)) v 1 4)
    v) => #(0 1 4 9 0)"
      (let loop ((i (- end 1)) (seeds seeds))
        (when (>= i start)
          (call-with-values
            (lambda () (apply f i seeds))
            (lambda (value . new-seeds)
              (vector-set! v i value)
              (loop (- i 1) new-seeds))))))

    ;;; --- Conversion ---

    (define (reverse-vector->list v . args)
      "Syntax: (reverse-vector->list vec)
       (reverse-vector->list vec start)
       (reverse-vector->list vec start end)
Library: (srfi 133)
Description: Returns a list of the elements of vec between start and end
  in reverse order.
Example:
  (reverse-vector->list '#(a b c d e) 1 4) => (d c b)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (let loop ((i start) (acc '()))
            (if (= i end) acc
                (loop (+ i 1) (cons (vector-ref v i) acc)))))))

    (define (reverse-list->vector lst)
      "Syntax: (reverse-list->vector list)
Library: (srfi 133)
Description: Returns a newly allocated vector whose elements are the
  elements of list in reverse order.
Example:
  (reverse-list->vector '(a b c)) => #(c b a)"
      (list->vector (reverse lst)))

))

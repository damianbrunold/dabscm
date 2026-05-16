(define-library (srfi 132)
  (import (scheme base))
  (export
    list-sorted? vector-sorted?
    list-sort list-stable-sort list-sort! list-stable-sort!
    vector-sort vector-stable-sort vector-sort! vector-stable-sort!
    list-merge list-merge!
    vector-merge vector-merge!
    list-delete-neighbor-dups list-delete-neighbor-dups!
    vector-delete-neighbor-dups vector-delete-neighbor-dups!
    vector-find-median vector-find-median!
    vector-select! vector-separate!)
  (begin

    ;; ---- Internal helpers ----

    (define (%start-end v args)
      (let ((start (if (null? args) 0 (car args)))
            (end   (if (or (null? args) (null? (cdr args)))
                       (vector-length v) (cadr args))))
        (values start end)))

    (define (%vector-swap! v i j)
      (let ((tmp (vector-ref v i)))
        (vector-set! v i (vector-ref v j))
        (vector-set! v j tmp)))

    ;; ---- Predicates ----

    (define (list-sorted? < lis)
      "Syntax: (list-sorted? < lis)
Library: (srfi 132)
Description: Returns #t if the elements of lis are in non-decreasing order
according to the comparison procedure <, #f otherwise. Returns #t for empty
and single-element lists.
Example:
  (list-sorted? < '(1 2 3)) => #t
  (list-sorted? < '(3 1 2)) => #f
  (list-sorted? < '()) => #t"
      (or (null? lis)
          (null? (cdr lis))
          (let loop ((prev (car lis)) (rest (cdr lis)))
            (or (null? rest)
                (let ((cur (car rest)))
                  (and (not (< cur prev))
                       (loop cur (cdr rest))))))))

    (define (vector-sorted? < v . args)
      "Syntax: (vector-sorted? < v)
       (vector-sorted? < v start)
       (vector-sorted? < v start end)
Library: (srfi 132)
Description: Returns #t if the elements of v in the range [start, end) are in
non-decreasing order according to <, #f otherwise. start defaults to 0 and
end defaults to the length of v.
Example:
  (vector-sorted? < #(1 2 3)) => #t
  (vector-sorted? < #(3 1 2)) => #f
  (vector-sorted? < #(1 3 2 4) 2 4) => #t"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (or (<= (- end start) 1)
              (let loop ((i (+ start 1)))
                (or (>= i end)
                    (and (not (< (vector-ref v i) (vector-ref v (- i 1))))
                         (loop (+ i 1)))))))))

    ;; ---- List merge (used by list-sort) ----

    (define (%list-merge < l1 l2)
      (let loop ((l1 l1) (l2 l2) (acc '()))
        (cond ((null? l1) (%append-reverse acc l2))
              ((null? l2) (%append-reverse acc l1))
              ((< (car l2) (car l1))
               (loop l1 (cdr l2) (cons (car l2) acc)))
              (else
               (loop (cdr l1) l2 (cons (car l1) acc))))))

    (define (%append-reverse rev-head tail)
      (if (null? rev-head)
          tail
          (%append-reverse (cdr rev-head) (cons (car rev-head) tail))))

    ;; ---- List sort ----

    ;; Natural merge sort: detects existing sorted runs for O(n) best case.
    ;; Collects ascending runs, then merges bottom-up pairwise.
    (define (%list-sort < lst)
      (if (or (null? lst) (null? (cdr lst)))
          lst
          ;; Collect natural ascending runs (non-destructive: copies each run)
          (let collect-runs ((rest lst) (runs '()))
            (if (null? rest)
                (%merge-runs < (reverse runs))
                (let run-loop ((prev (car rest)) (tail (cdr rest)) (run (list (car rest))))
                  (if (or (null? tail) (< (car tail) prev))
                      (collect-runs tail (cons (reverse run) runs))
                      (run-loop (car tail) (cdr tail) (cons (car tail) run))))))))

    ;; Destructive natural merge sort: reuses cons cells via set-cdr!.
    (define (%list-sort! < lst)
      (if (or (null? lst) (null? (cdr lst)))
          lst
          ;; Collect natural ascending runs by snipping with set-cdr!
          (let collect-runs ((rest lst) (runs '()))
            (if (null? rest)
                (%merge-runs! < (reverse runs))
                (let run-loop ((prev rest) (cur (cdr rest)))
                  (if (or (null? cur) (< (car cur) (car prev)))
                      (let ((run-start rest))
                        (set-cdr! prev '())
                        (collect-runs cur (cons run-start runs)))
                      (run-loop cur (cdr cur))))))))

    ;; Merge a list of runs pairwise until one remains (non-destructive).
    ;; Runs must be in left-to-right order for stability.
    (define (%merge-runs < runs)
      (if (null? (cdr runs))
          (car runs)
          (%merge-runs < (%merge-pairs < runs))))

    (define (%merge-pairs < runs)
      (cond ((null? runs) '())
            ((null? (cdr runs)) runs)
            (else (cons (%list-merge < (car runs) (cadr runs))
                        (%merge-pairs < (cddr runs))))))

    ;; Merge a list of runs pairwise until one remains (destructive).
    (define (%merge-runs! < runs)
      (if (null? (cdr runs))
          (car runs)
          (%merge-runs! < (%merge-pairs! < runs))))

    (define (%merge-pairs! < runs)
      (cond ((null? runs) '())
            ((null? (cdr runs)) runs)
            (else (cons (list-merge! < (car runs) (cadr runs))
                        (%merge-pairs! < (cddr runs))))))

    (define (list-sort < l)
      "Syntax: (list-sort < lis)
Library: (srfi 132)
Description: Returns a list containing the elements of lis in non-decreasing
order according to the comparison procedure <. The original list is not
modified. The sort is stable: equal elements maintain their relative order.
Example:
  (list-sort < '(3 1 4 1 5 9)) => (1 1 3 4 5 9)
  (list-sort string<? '(\"banana\" \"apple\" \"cherry\")) => (\"apple\" \"banana\" \"cherry\")"
      (%list-sort < l))

    (define (list-stable-sort < lis)
      "Syntax: (list-stable-sort < lis)
Library: (srfi 132)
Description: Returns a list containing the elements of lis in non-decreasing
order according to <. The sort is stable: equal elements maintain their
relative order. Equivalent to list-sort since the underlying merge sort
algorithm is stable.
Example:
  (list-stable-sort < '(3 1 4 1 5)) => (1 1 3 4 5)"
      (%list-sort < lis))

    (define (list-sort! < lis)
      "Syntax: (list-sort! < lis)
Library: (srfi 132)
Description: Returns a list containing the elements of lis in non-decreasing
order according to <. This is a linear-update variant that modifies the input
list's cons cells to avoid allocation.
Example:
  (list-sort! < '(3 1 4 1 5)) => (1 1 3 4 5)"
      (%list-sort! < lis))

    (define (list-stable-sort! < lis)
      "Syntax: (list-stable-sort! < lis)
Library: (srfi 132)
Description: Returns a list containing the elements of lis in non-decreasing
order according to <. This is a stable, linear-update variant that modifies
the input list's cons cells to avoid allocation.
Example:
  (list-stable-sort! < '(3 1 4 1 5)) => (1 1 3 4 5)"
      (%list-sort! < lis))

    ;; ---- List merge (public) ----

    (define (list-merge < lis1 lis2)
      "Syntax: (list-merge < lis1 lis2)
Library: (srfi 132)
Description: Merges two sorted lists into a single sorted list. Both input
lists must already be sorted according to <. The merge is stable: elements
from lis1 are preferred over equal elements from lis2. The input lists are
not modified.
Example:
  (list-merge < '(1 3 5) '(2 4 6)) => (1 2 3 4 5 6)
  (list-merge < '(1 2) '(2 3)) => (1 2 2 3)"
      (%list-merge < lis1 lis2))

    (define (list-merge! < lis1 lis2)
      "Syntax: (list-merge! < lis1 lis2)
Library: (srfi 132)
Description: Merges two sorted lists into a single sorted list. Both input
lists must already be sorted according to <. This is a destructive variant
that may modify the cons cells of the input lists via set-cdr!.
Example:
  (list-merge! < (list 1 3 5) (list 2 4 6)) => (1 2 3 4 5 6)"
      (cond ((null? lis1) lis2)
            ((null? lis2) lis1)
            (else
             (let ((head (if (< (car lis2) (car lis1)) lis2 lis1))
                   (other (if (< (car lis2) (car lis1)) lis1 lis2)))
               (let loop ((tail head)
                          (a (cdr head))
                          (b other))
                 (cond ((null? a)
                        (set-cdr! tail b))
                       ((null? b)
                        (set-cdr! tail a))
                       ((< (car b) (car a))
                        (set-cdr! tail b)
                        (loop b a (cdr b)))
                       (else
                        (set-cdr! tail a)
                        (loop a (cdr a) b))))
               head))))

    ;; ---- Vector sort ----

    ;; Natural merge sort: detects existing sorted runs for O(n) best case.
    ;; Stable, O(n log n) worst case, O(n) auxiliary space.
    (define (%vector-merge-sort! < v start end)
      (let ((n (- end start)))
        (when (> n 1)
          (let ((aux (make-vector n)))
            ;; Detect natural runs. Strictly descending runs are reversed
            ;; in-place for stability. Returns list of (start . end) pairs
            ;; using offsets relative to 0 (not to start).
            (let detect-runs ((i 0) (runs '()))
              (if (>= i n)
                  (%vector-merge-runs! < v start aux (reverse runs) n)
                  (let ((run-start i))
                    (cond
                      ((>= (+ i 1) n)
                       ;; Single element run
                       (detect-runs n (cons (cons i n) runs)))
                      ((< (vector-ref v (+ start i 1)) (vector-ref v (+ start i)))
                       ;; Strictly descending run - find extent then reverse
                       (let desc-loop ((j (+ i 2)))
                         (if (and (> n j)
                                  (< (vector-ref v (+ start j))
                                     (vector-ref v (+ start j -1))))
                             (desc-loop (+ j 1))
                             (begin
                               (%vector-reverse! v (+ start i) (+ start j))
                               (detect-runs j (cons (cons i j) runs))))))
                      (else
                       ;; Ascending run (non-strictly: equal elements stay)
                       (let asc-loop ((j (+ i 2)))
                         (if (and (> n j)
                                  (not (< (vector-ref v (+ start j))
                                          (vector-ref v (+ start j -1)))))
                             (asc-loop (+ j 1))
                             (detect-runs j (cons (cons i j) runs)))))))))))))

    ;; Reverse a subrange of vector v in-place.
    (define (%vector-reverse! v lo hi)
      (let loop ((i lo) (j (- hi 1)))
        (when (< i j)
          (%vector-swap! v i j)
          (loop (+ i 1) (- j 1)))))

    ;; Merge runs pairwise until one remains. Alternates between v and aux.
    ;; runs is a list of (start . end) offset pairs (relative to 0).
    (define (%vector-merge-runs! < v vstart aux runs n)
      (if (null? (cdr runs))
          ;; Single run - data is already in v, nothing to do
          (values)
          ;; Merge pairs: from v into aux, then from aux back into v, etc.
          (let pass ((runs runs) (from v) (from-off vstart) (to aux) (to-off 0))
            (let merge-pairs ((in runs) (out '()))
              (cond
                ((null? in)
                 ;; End of pass
                 (let ((new-runs (reverse out)))
                   (if (null? (cdr new-runs))
                       ;; Done - if result is in aux, copy back to v
                       (when (eq? to aux)
                         (vector-copy! v vstart aux 0 n))
                       ;; More passes needed
                       (pass new-runs to to-off from from-off))))
                ((null? (cdr in))
                 ;; Odd run: copy to destination
                 (let ((r (car in)))
                   (vector-copy! to (+ to-off (car r))
                                 from (+ from-off (car r))
                                 (+ from-off (cdr r)))
                   (merge-pairs '() (cons r out))))
                (else
                 ;; Merge first two runs into destination
                 (let ((r1 (car in)) (r2 (cadr in)))
                   (%do-vector-merge-range!
                    < to (+ to-off (car r1))
                    from (+ from-off (car r1)) (+ from-off (cdr r1))
                    from (+ from-off (car r2)) (+ from-off (cdr r2)))
                   (merge-pairs (cddr in)
                                (cons (cons (car r1) (cdr r2)) out)))))))))

    ;; Merge two adjacent ranges from source vectors into destination.
    (define (%do-vector-merge-range! < to to-start from1 start1 end1 from2 start2 end2)
      (let loop ((i start1) (j start2) (k to-start))
        (cond
          ((>= i end1)
           (vector-copy! to k from2 j end2))
          ((>= j end2)
           (vector-copy! to k from1 i end1))
          ((< (vector-ref from2 j) (vector-ref from1 i))
           (vector-set! to k (vector-ref from2 j))
           (loop i (+ j 1) (+ k 1)))
          (else
           (vector-set! to k (vector-ref from1 i))
           (loop (+ i 1) j (+ k 1))))))

    (define (vector-sort! < v . args)
      "Syntax: (vector-sort! < v)
       (vector-sort! < v start)
       (vector-sort! < v start end)
Library: (srfi 132)
Description: Sorts the elements of vector v in the range [start, end) in
non-decreasing order according to <. The sort is performed in place. The sort
is stable. Returns an unspecified value. start defaults to 0 and end defaults
to the length of v.
Example:
  (let ((v (vector 3 1 4 1 5))) (vector-sort! < v) v) => #(1 1 3 4 5)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (%vector-merge-sort! < v start end))))

    (define (vector-stable-sort! < v . args)
      "Syntax: (vector-stable-sort! < v)
       (vector-stable-sort! < v start)
       (vector-stable-sort! < v start end)
Library: (srfi 132)
Description: Sorts the elements of vector v in the range [start, end) in
non-decreasing order according to <. The sort is performed in place and is
stable: equal elements maintain their relative order. Returns an unspecified
value. Equivalent to vector-sort!.
Example:
  (let ((v (vector 3 1 4 1 5))) (vector-stable-sort! < v) v) => #(1 1 3 4 5)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (%vector-merge-sort! < v start end))))

    (define (vector-sort < v . args)
      "Syntax: (vector-sort < v)
       (vector-sort < v start)
       (vector-sort < v start end)
Library: (srfi 132)
Description: Returns a newly allocated vector containing the elements of v in
the range [start, end) sorted in non-decreasing order according to <. The
original vector is not modified. The sort is stable.
Example:
  (vector-sort < #(3 1 4 1 5)) => #(1 1 3 4 5)
  (vector-sort < #(5 3 1 4 2) 1 4) => #(1 3 4)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (let ((result (vector-copy v start end)))
            (%vector-merge-sort! < result 0 (- end start))
            result))))

    (define (vector-stable-sort < v . args)
      "Syntax: (vector-stable-sort < v)
       (vector-stable-sort < v start)
       (vector-stable-sort < v start end)
Library: (srfi 132)
Description: Returns a newly allocated vector containing the elements of v in
the range [start, end) sorted in non-decreasing order according to <. The
original vector is not modified. The sort is stable. Equivalent to vector-sort.
Example:
  (vector-stable-sort < #(3 1 4 1 5)) => #(1 1 3 4 5)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (let ((result (vector-copy v start end)))
            (%vector-merge-sort! < result 0 (- end start))
            result))))

    ;; ---- Vector merge ----

    (define (%vmerge-args v1 v2 args)
      ;; Parse optional args: [start1 [end1 [start2 [end2]]]]
      (let* ((start1 (if (null? args) 0 (car args)))
             (args (if (null? args) '() (cdr args)))
             (end1 (if (null? args) (vector-length v1) (car args)))
             (args (if (null? args) '() (cdr args)))
             (start2 (if (null? args) 0 (car args)))
             (args (if (null? args) '() (cdr args)))
             (end2 (if (null? args) (vector-length v2) (car args))))
        (values start1 end1 start2 end2)))

    (define (vector-merge < v1 v2 . args)
      "Syntax: (vector-merge < v1 v2)
       (vector-merge < v1 v2 start1)
       (vector-merge < v1 v2 start1 end1)
       (vector-merge < v1 v2 start1 end1 start2)
       (vector-merge < v1 v2 start1 end1 start2 end2)
Library: (srfi 132)
Description: Merges the elements of sorted vectors v1 (range [start1, end1))
and v2 (range [start2, end2)) into a newly allocated vector in non-decreasing
order according to <. Both input ranges must already be sorted. Elements from
v1 are preferred over equal elements from v2 (stable).
Example:
  (vector-merge < #(1 3 5) #(2 4 6)) => #(1 2 3 4 5 6)"
      (call-with-values (lambda () (%vmerge-args v1 v2 args))
        (lambda (start1 end1 start2 end2)
          (let* ((n1 (- end1 start1))
                 (n2 (- end2 start2))
                 (result (make-vector (+ n1 n2))))
            (%do-vector-merge! < result 0 v1 start1 end1 v2 start2 end2)
            result))))

    (define (%vmerge!-args to from1 from2 args)
      ;; Parse optional args: [start [start1 [end1 [start2 [end2]]]]]
      (let* ((start (if (null? args) 0 (car args)))
             (args (if (null? args) '() (cdr args)))
             (start1 (if (null? args) 0 (car args)))
             (args (if (null? args) '() (cdr args)))
             (end1 (if (null? args) (vector-length from1) (car args)))
             (args (if (null? args) '() (cdr args)))
             (start2 (if (null? args) 0 (car args)))
             (args (if (null? args) '() (cdr args)))
             (end2 (if (null? args) (vector-length from2) (car args))))
        (values start start1 end1 start2 end2)))

    (define (vector-merge! < to from1 from2 . args)
      "Syntax: (vector-merge! < to from1 from2)
       (vector-merge! < to from1 from2 start)
       (vector-merge! < to from1 from2 start start1)
       (vector-merge! < to from1 from2 start start1 end1)
       (vector-merge! < to from1 from2 start start1 end1 start2)
       (vector-merge! < to from1 from2 start start1 end1 start2 end2)
Library: (srfi 132)
Description: Merges the sorted elements of from1 (range [start1, end1)) and
from2 (range [start2, end2)) into the vector to, starting at index start.
Both source ranges must be sorted according to <. The target range must not
overlap the source ranges. Returns an unspecified value.
Example:
  (let ((v (make-vector 6)))
    (vector-merge! < v #(1 3 5) #(2 4 6))
    v) => #(1 2 3 4 5 6)"
      (call-with-values (lambda () (%vmerge!-args to from1 from2 args))
        (lambda (start start1 end1 start2 end2)
          (%do-vector-merge! < to start from1 start1 end1 from2 start2 end2))))

    (define (%do-vector-merge! < to to-start v1 start1 end1 v2 start2 end2)
      (let loop ((i start1) (j start2) (k to-start))
        (cond
          ((>= i end1)
           (vector-copy! to k v2 j end2))
          ((>= j end2)
           (vector-copy! to k v1 i end1))
          ((< (vector-ref v2 j) (vector-ref v1 i))
           (vector-set! to k (vector-ref v2 j))
           (loop i (+ j 1) (+ k 1)))
          (else
           (vector-set! to k (vector-ref v1 i))
           (loop (+ i 1) j (+ k 1))))))

    ;; ---- Duplicate deletion ----

    (define (list-delete-neighbor-dups = lis)
      "Syntax: (list-delete-neighbor-dups = lis)
Library: (srfi 132)
Description: Returns a list with adjacent duplicate elements removed. Elements
are compared using the equality predicate =. The first element of each run of
equal elements is retained. The input list is not modified. Shares common tail
structure with the input when possible.
Example:
  (list-delete-neighbor-dups = '(1 1 2 3 3 3 4)) => (1 2 3 4)
  (list-delete-neighbor-dups = '()) => ()"
      (if (or (null? lis) (null? (cdr lis)))
          lis
          (let ((x (car lis))
                (tail (cdr lis)))
            (if (= x (car tail))
                ;; Skip duplicates, then recurse
                (let skip ((rest (cdr tail)))
                  (cond ((null? rest) (list x))
                        ((= x (car rest)) (skip (cdr rest)))
                        (else (cons x (list-delete-neighbor-dups = rest)))))
                ;; No duplicate here; recurse on tail and share structure if unchanged
                (let ((new-tail (list-delete-neighbor-dups = tail)))
                  (if (eq? new-tail tail)
                      lis
                      (cons x new-tail)))))))

    (define (list-delete-neighbor-dups! = lis)
      "Syntax: (list-delete-neighbor-dups! = lis)
Library: (srfi 132)
Description: Destructively removes adjacent duplicate elements from lis by
relinking cons cells with set-cdr!. Elements are compared using =. The first
element of each run of equal elements is retained. Returns the modified list.
Example:
  (list-delete-neighbor-dups! = (list 1 1 2 3 3 3 4)) => (1 2 3 4)"
      (if (null? lis) lis
          (let loop ((prev lis) (rest (cdr lis)))
            (cond ((null? rest) lis)
                  ((= (car prev) (car rest))
                   (set-cdr! prev (cdr rest))
                   (loop prev (cdr rest)))
                  (else
                   (loop rest (cdr rest)))))))

    (define (vector-delete-neighbor-dups = v . args)
      "Syntax: (vector-delete-neighbor-dups = v)
       (vector-delete-neighbor-dups = v start)
       (vector-delete-neighbor-dups = v start end)
Library: (srfi 132)
Description: Returns a newly allocated vector with adjacent duplicate elements
removed from the range [start, end) of v. Elements are compared using =. The
first element of each run of equal elements is retained.
Example:
  (vector-delete-neighbor-dups = #(1 1 2 3 3 4)) => #(1 2 3 4)
  (vector-delete-neighbor-dups = #(1 2 3)) => #(1 2 3)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (if (>= start end)
              (vector)
              ;; First pass: count unique elements
              (let ((count (let loop ((i (+ start 1)) (c 1))
                             (cond ((>= i end) c)
                                   ((= (vector-ref v (- i 1)) (vector-ref v i))
                                    (loop (+ i 1) c))
                                   (else (loop (+ i 1) (+ c 1)))))))
                ;; Second pass: fill result
                (let ((result (make-vector count)))
                  (vector-set! result 0 (vector-ref v start))
                  (let loop ((i (+ start 1)) (j 1))
                    (cond ((>= i end) result)
                          ((= (vector-ref v (- i 1)) (vector-ref v i))
                           (loop (+ i 1) j))
                          (else
                           (vector-set! result j (vector-ref v i))
                           (loop (+ i 1) (+ j 1)))))))))))

    (define (vector-delete-neighbor-dups! = v . args)
      "Syntax: (vector-delete-neighbor-dups! = v)
       (vector-delete-neighbor-dups! = v start)
       (vector-delete-neighbor-dups! = v start end)
Library: (srfi 132)
Description: Destructively compacts the range [start, end) of v by removing
adjacent duplicate elements. Elements are compared using =. The first element
of each run of equal elements is retained. Returns the new end index (an exact
integer), not a vector. Elements beyond the new end are unchanged.
Example:
  (let ((v (vector 1 1 2 3 3 4)))
    (vector-delete-neighbor-dups! = v)) => 4"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (if (>= start end) start
              (let loop ((i (+ start 1)) (j (+ start 1)))
                (cond ((>= i end) j)
                      ((= (vector-ref v (- j 1)) (vector-ref v i))
                       (loop (+ i 1) j))
                      (else
                       (vector-set! v j (vector-ref v i))
                       (loop (+ i 1) (+ j 1)))))))))

    ;; ---- Selection ----

    ;; Quickselect: find k-th smallest element in v[start..end)
    ;; May rearrange elements. Average O(n).
    (define (vector-select! < v k . args)
      "Syntax: (vector-select! < v k)
       (vector-select! < v k start)
       (vector-select! < v k start end)
Library: (srfi 132)
Description: Returns the k-th smallest element (zero-indexed) in the range
[start, end) of vector v, according to the comparison procedure <. May
rearrange elements within the range. Runs in O(n) average time.
Example:
  (vector-select! < (vector 3 1 4 1 5) 0) => 1
  (vector-select! < (vector 3 1 4 1 5) 2) => 3
  (vector-select! < (vector 3 1 4 1 5) 4) => 5"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (%quickselect! < v (+ start k) start end))))

    ;; Insertion sort for small ranges, used as fallback.
    (define (%insertion-sort! < v lo hi)
      (let outer ((i (+ lo 1)))
        (when (> hi i)
          (let ((x (vector-ref v i)))
            (let inner ((j i))
              (if (and (> j lo) (< x (vector-ref v (- j 1))))
                  (begin (vector-set! v j (vector-ref v (- j 1)))
                         (inner (- j 1)))
                  (vector-set! v j x))))
          (outer (+ i 1)))))

    (define (%quickselect! < v k lo hi)
      ;; Select element that would be at index k if v[lo..hi) were sorted.
      ;; Falls back to insertion sort for small ranges.
      (if (<= (- hi lo) 15)
          (begin (%insertion-sort! < v lo hi)
                 (vector-ref v k))
          (let ((pivot-idx (%partition! < v lo hi)))
            (cond ((= k pivot-idx)
                   (vector-ref v k))
                  ((< k pivot-idx)
                   (%quickselect! < v k lo pivot-idx))
                  (else
                   (%quickselect! < v k (+ pivot-idx 1) hi))))))

    (define (%partition! < v lo hi)
      ;; Median-of-three pivot selection + Hoare partition
      (let* ((mid (+ lo (quotient (- hi lo) 2)))
             (last (- hi 1)))
        ;; Sort lo, mid, last; use mid as pivot
        (when (< (vector-ref v mid) (vector-ref v lo))
          (%vector-swap! v lo mid))
        (when (< (vector-ref v last) (vector-ref v lo))
          (%vector-swap! v lo last))
        (when (< (vector-ref v last) (vector-ref v mid))
          (%vector-swap! v mid last))
        ;; Move pivot to last-1 position (or last if only 2 elements)
        (if (<= (- hi lo) 2)
            ;; Already sorted for 2-3 elements, pivot is at mid
            mid
            (begin
              (%vector-swap! v mid (- last 1))
              (let ((pivot (vector-ref v (- last 1))))
                (let loop ((i lo) (j (- last 1)))
                  (let ((i (let iloop ((i (+ i 1)))
                             (if (< (vector-ref v i) pivot) (iloop (+ i 1)) i)))
                        (j (let jloop ((j (- j 1)))
                             (if (< pivot (vector-ref v j)) (jloop (- j 1)) j))))
                    (if (>= i j)
                        (begin (%vector-swap! v i (- last 1)) i)
                        (begin (%vector-swap! v i j)
                               (loop i j))))))))))

    (define (vector-separate! < v k . args)
      "Syntax: (vector-separate! < v k)
       (vector-separate! < v k start)
       (vector-separate! < v k start end)
Library: (srfi 132)
Description: Rearranges the elements of v in the range [start, end) so that
the k smallest elements (according to <) are in positions [start, start+k).
The remaining elements are in positions [start+k, end) in unspecified order.
Returns an unspecified value.
Example:
  (let ((v (vector 5 3 1 4 2)))
    (vector-separate! < v 2)
    (let ((first-two (list (vector-ref v 0) (vector-ref v 1))))
      (list-sort < first-two))) => (1 2)"
      (call-with-values (lambda () (%start-end v args))
        (lambda (start end)
          (when (and (> k 0) (< (+ start k) end))
            (%quickselect! < v (+ start k -1) start end)))))

    ;; ---- Median ----

    (define (vector-find-median! < v knil . args)
      "Syntax: (vector-find-median! < v knil)
       (vector-find-median! < v knil mean)
Library: (srfi 132)
Description: Finds the median of the elements in vector v according to <.
If v is empty, returns knil. If v has an odd number of elements, returns the
middle element. If v has an even number of elements and mean is provided,
returns (mean a b) where a and b are the two middle elements; otherwise
returns the lower of the two. This variant sorts v in place.
Example:
  (vector-find-median! < (vector 3 1 4 1 5) 0) => 3
  (vector-find-median! < (vector 3 1 4 5) 0 (lambda (a b) (/ (+ a b) 2))) => 7/2"
      (let ((mean (if (null? args) #f (car args)))
            (n (vector-length v)))
        (cond ((= n 0) knil)
              (else
               (vector-sort! < v)
               (let ((mid (quotient n 2)))
                 (if (odd? n)
                     (vector-ref v mid)
                     (if mean
                         (mean (vector-ref v (- mid 1)) (vector-ref v mid))
                         (vector-ref v (- mid 1)))))))))

    (define (vector-find-median < v knil . args)
      "Syntax: (vector-find-median < v knil)
       (vector-find-median < v knil mean)
Library: (srfi 132)
Description: Finds the median of the elements in vector v according to <.
If v is empty, returns knil. If v has an odd number of elements, returns the
middle element. If v has an even number of elements and mean is provided,
returns (mean a b) where a and b are the two middle elements; otherwise
returns the lower of the two. The original vector is not modified.
Example:
  (vector-find-median < #(3 1 4 1 5) 0) => 3
  (vector-find-median < #(3 1 4 5) 0 (lambda (a b) (/ (+ a b) 2))) => 7/2"
      (apply vector-find-median! < (vector-copy v) knil args))

    ))

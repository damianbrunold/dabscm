(define-library (srfi 95)
  (import (scheme base))
  (export sorted? merge merge! sort sort!)
  (begin

    ;; ---- Internal helpers ----

    (define (%effective-less less? key)
      (if key
          (lambda (a b) (less? (key a) (key b)))
          less?))

    (define (%append-reverse rev-head tail)
      (if (null? rev-head)
          tail
          (%append-reverse (cdr rev-head) (cons (car rev-head) tail))))

    ;; ---- sorted? ----

    (define (sorted? seq less? . opt)
      "Syntax: (sorted? sequence less?)
       (sorted? sequence less? key)
Library: (srfi 95)
Description: Returns #t if the elements of sequence are in non-decreasing
order according to the comparison procedure less?, #f otherwise. The sequence
may be a list, vector, or string. If key is provided, it is applied to each
element before comparison.
Example:
  (sorted? '(1 2 3) <) => #t
  (sorted? #(3 1 2) <) => #f
  (sorted? '((a . 1) (b . 2) (c . 3)) < cdr) => #t"
      (let ((key (if (null? opt) #f (car opt))))
        (cond
          ((null? seq) #t)
          ((list? seq)
           (%list-sorted? seq less? key))
          ((vector? seq)
           (%vector-sorted? seq less? key))
          ((string? seq)
           (%vector-sorted? seq less? key))
          (else (error "sorted?: unsupported sequence type" seq)))))

    (define (%list-sorted? lis less? key)
      (or (null? lis)
          (null? (cdr lis))
          (let loop ((prev (if key (key (car lis)) (car lis)))
                     (rest (cdr lis)))
            (or (null? rest)
                (let ((cur (if key (key (car rest)) (car rest))))
                  (and (not (less? cur prev))
                       (loop cur (cdr rest))))))))

    (define (%vector-sorted? v less? key)
      (let ((len (if (string? v) (string-length v) (vector-length v))))
        (or (<= len 1)
            (let ((ref (if (string? v) string-ref vector-ref)))
              (let loop ((i 1)
                         (prev-key (let ((e (ref v 0)))
                                     (if key (key e) e))))
                (or (>= i len)
                    (let ((cur-key (let ((e (ref v i)))
                                     (if key (key e) e))))
                      (and (not (less? cur-key prev-key))
                           (loop (+ i 1) cur-key)))))))))

    ;; ---- merge ----

    (define (merge list1 list2 less? . opt)
      "Syntax: (merge list1 list2 less?)
       (merge list1 list2 less? key)
Library: (srfi 95)
Description: Merges two sorted lists into a single sorted list. Both input
lists must already be sorted according to less?. The merge is stable: equal
elements from list1 appear before those from list2. The input lists are not
modified. If key is provided, it is applied to each element before comparison.
Example:
  (merge '(1 3 5) '(2 4 6) <) => (1 2 3 4 5 6)
  (merge '((a . 1) (b . 3)) '((c . 2) (d . 4)) < cdr)
    => ((a . 1) (c . 2) (b . 3) (d . 4))"
      (let ((key (if (null? opt) #f (car opt))))
        (%list-merge list1 list2 less? key)))

    (define (%list-merge l1 l2 less? key)
      (let loop ((l1 l1) (l2 l2) (acc '()))
        (cond ((null? l1) (%append-reverse acc l2))
              ((null? l2) (%append-reverse acc l1))
              ((less? (if key (key (car l2)) (car l2))
                      (if key (key (car l1)) (car l1)))
               (loop l1 (cdr l2) (cons (car l2) acc)))
              (else
               (loop (cdr l1) l2 (cons (car l1) acc))))))

    ;; ---- merge! ----

    (define (merge! list1 list2 less? . opt)
      "Syntax: (merge! list1 list2 less?)
       (merge! list1 list2 less? key)
Library: (srfi 95)
Description: Destructively merges two sorted lists into a single sorted list
by reusing the cons cells of the input lists via set-cdr!. Both input lists
must already be sorted according to less?. The merge is stable. If key is
provided, it is applied to each element before comparison.
Example:
  (merge! (list 1 3 5) (list 2 4 6) <) => (1 2 3 4 5 6)"
      (let ((key (if (null? opt) #f (car opt))))
        (%list-merge! list1 list2 less? key)))

    (define (%list-merge! l1 l2 less? key)
      (cond ((null? l1) l2)
            ((null? l2) l1)
            (else
             (let* ((k1 (if key (key (car l1)) (car l1)))
                    (k2 (if key (key (car l2)) (car l2)))
                    (head (if (less? k2 k1) l2 l1))
                    (other (if (less? k2 k1) l1 l2)))
               (let loop ((tail head)
                          (a (cdr head))
                          (b other))
                 (cond ((null? a)
                        (set-cdr! tail b))
                       ((null? b)
                        (set-cdr! tail a))
                       ((less? (if key (key (car b)) (car b))
                               (if key (key (car a)) (car a)))
                        (set-cdr! tail b)
                        (loop b a (cdr b)))
                       (else
                        (set-cdr! tail a)
                        (loop a (cdr a) b))))
               head))))

    ;; ---- List sort (stable merge sort) ----

    (define (%list-sort less? lst)
      (if (or (null? lst) (null? (cdr lst)))
          lst
          (let loop ((slow lst) (fast (cdr lst)) (acc '()))
            (if (or (null? fast) (null? (cdr fast)))
                (let ((back (cdr slow))
                      (front (reverse (cons (car slow) acc))))
                  (%list-merge (%list-sort less? front)
                               (%list-sort less? back)
                               less? #f))
                (loop (cdr slow) (cddr fast) (cons (car slow) acc))))))

    ;; ---- Vector sort (bottom-up merge sort) ----

    (define (%vector-merge-sort! less? v start end)
      (let ((n (- end start)))
        (when (> n 1)
          (let ((aux (make-vector n)))
            (let widthloop ((width 1) (src 0))
              (if (>= width n)
                  (when (= src 1)
                    (vector-copy! v start aux 0 n))
                  (begin
                    (let pairloop ((i 0))
                      (cond
                        ((>= i n) #f)
                        ((>= (+ i width) n)
                         (if (= src 0)
                             (vector-copy! aux i v (+ start i) (+ start n))
                             (vector-copy! v (+ start i) aux i n))
                         #f)
                        (else
                         (let* ((mid (+ i width))
                                (right-end (min (+ i width width) n))
                                (from (if (= src 0) v aux))
                                (from-off (if (= src 0) start 0))
                                (to (if (= src 0) aux v))
                                (to-off (if (= src 0) 0 start)))
                           (let mergeloop ((li (+ from-off i))
                                           (ri (+ from-off mid))
                                           (wi (+ to-off i)))
                             (cond
                               ((>= li (+ from-off mid))
                                (vector-copy! to wi from ri (+ from-off right-end)))
                               ((>= ri (+ from-off right-end))
                                (vector-copy! to wi from li (+ from-off mid)))
                               ((less? (vector-ref from ri) (vector-ref from li))
                                (vector-set! to wi (vector-ref from ri))
                                (mergeloop li (+ ri 1) (+ wi 1)))
                               (else
                                (vector-set! to wi (vector-ref from li))
                                (mergeloop (+ li 1) ri (+ wi 1))))))
                         (pairloop (+ i width width)))))
                    (widthloop (* width 2) (- 1 src)))))))))

    ;; ---- sort ----

    (define (sort seq less? . opt)
      "Syntax: (sort sequence less?)
       (sort sequence less? key)
Library: (srfi 95)
Description: Returns a new sequence containing the elements of sequence sorted
in non-decreasing order according to less?. The returned sequence is the same
type as the input (list, vector, or string). The original sequence is not
modified. The sort is stable. If key is provided, it is applied to each
element before comparison; the original elements (not the keys) appear in the
result.
Example:
  (sort '(3 1 4 1 5) <) => (1 1 3 4 5)
  (sort #(3 1 2) <) => #(1 2 3)
  (sort \"cab\" char<?) => \"abc\"
  (sort '((a . 2) (b . 1) (c . 2)) < cdr) => ((b . 1) (a . 2) (c . 2))"
      (let ((key (if (null? opt) #f (car opt))))
        (cond
          ((list? seq)
           (%list-sort (%effective-less less? key) seq))
          ((vector? seq)
           (let ((result (vector-copy seq)))
             (%vector-sort-with-key! less? key result 0 (vector-length result))
             result))
          ((string? seq)
           (let ((chars (%list-sort (%effective-less less? key)
                                    (string->list seq))))
             (list->string chars)))
          (else (error "sort: unsupported sequence type" seq)))))

    (define (%vector-sort-with-key! less? key v start end)
      (if key
          ;; Decorate-sort-undecorate for key efficiency
          (let ((n (- end start)))
            (when (> n 0)
              (let ((decorated (make-vector n)))
                ;; Build decorated vector of (key . value) pairs
                (let loop ((i 0))
                  (when (< i n)
                    (let ((elem (vector-ref v (+ start i))))
                      (vector-set! decorated i (cons (key elem) elem)))
                    (loop (+ i 1))))
                ;; Sort by key
                (%vector-merge-sort! (lambda (a b) (less? (car a) (car b)))
                                     decorated 0 n)
                ;; Undecorate back into v
                (let loop ((i 0))
                  (when (< i n)
                    (vector-set! v (+ start i) (cdr (vector-ref decorated i)))
                    (loop (+ i 1)))))))
          (%vector-merge-sort! less? v start end)))

    ;; ---- sort! ----

    (define (sort! seq less? . opt)
      "Syntax: (sort! sequence less?)
       (sort! sequence less? key)
Library: (srfi 95)
Description: Sorts the elements of sequence in non-decreasing order according
to less?. This is a destructive variant that may modify the input sequence.
For vectors, the sort is performed in place. For lists, the cons cells may be
relinked. For strings, a new sorted string is returned (strings are immutable).
The sort is stable. If key is provided, it is applied to each element before
comparison; the original elements (not the keys) appear in the result.
Example:
  (sort! (list 3 1 4 1 5) <) => (1 1 3 4 5)
  (let ((v (vector 3 1 2))) (sort! v <) v) => #(1 2 3)
  (sort! '((a . 2) (b . 1)) < cdr) => ((b . 1) (a . 2))"
      (let ((key (if (null? opt) #f (car opt))))
        (cond
          ((list? seq)
           (%list-sort (%effective-less less? key) seq))
          ((vector? seq)
           (%vector-sort-with-key! less? key seq 0 (vector-length seq))
           seq)
          ((string? seq)
           (let ((chars (%list-sort (%effective-less less? key)
                                    (string->list seq))))
             (list->string chars)))
          (else (error "sort!: unsupported sequence type" seq)))))

    ))

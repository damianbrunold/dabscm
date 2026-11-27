(define-library (scm data cluster)
  (import (scheme base)
          (scheme inexact)
          (srfi 1)
          (srfi 27)
          (srfi 69)
          (srfi 132))
  (export adjusted-rand-index
          cosine-similarity
          cutree
          cutree-height
          distance-matrix
          graph-edges
          graph-size
          graph-strength
          hclust
          jaccard-similarity
          kmeans
          knn-graph
          louvain
          make-graph
          make-sparse
          membership-groups
          modularity
          silhouette
          similarity-graph
          sparse->alist
          sparse-dot
          sparse-keys
          sparse-norm
          sparse-ref
          sparse-sum
          sparse?
          weighted-jaccard-similarity)
  (begin

    ;; ================================================================
    ;; (scm data cluster): similarity, graphs and clustering for data
    ;; analysis, in plain Scheme.
    ;;
    ;; - sparse vectors (key -> number, any keys) with cosine, Jaccard and
    ;;   weighted Jaccard similarity
    ;; - weighted undirected graphs: from a similarity function
    ;;   (similarity-graph, knn-graph) or an edge list (make-graph)
    ;; - community detection: louvain (modularity with a resolution;
    ;;   with 'refine, each community is split into its connected parts
    ;;   before aggregation, the connectivity guarantee of Leiden)
    ;; - hierarchical clustering: hclust on a distance matrix (average,
    ;;   complete, single, ward linkage; nearest-neighbour chain, O(n^2)
    ;;   memory), cutree / cutree-height
    ;; - kmeans (k-means++ start) on dense vectors
    ;; - quality: modularity, silhouette, adjusted-rand-index
    ;;
    ;; A membership is a vector of cluster numbers 0..c-1, numbered by
    ;; size (largest first, ties by first member). Every random step
    ;; takes a seed, so results are reproducible.
    ;; ================================================================

    ;; --- sparse vectors -----------------------------------------------

    (define-record-type <sparse>
      (%make-sparse table norm sum)
      sparse?
      (table sparse-table)
      (norm sparse-norm)
      (sum sparse-sum))

    ;; alist ((key . number) …) or hash table -> sparse vector; repeated
    ;; keys add up, zero entries are dropped
    (define (make-sparse entries)
      "Syntax: (make-sparse entries)
Library: (scm data cluster)
Description: A sparse vector from an alist ((key . number) …) or a hash table;
  any keys (equal?), repeated keys add up, zeros are dropped.
Example:
  (sparse-ref (make-sparse '((a . 1) (a . 2))) 'a) => 3"
      (let ((t (make-hash-table equal?)))
        (if (hash-table? entries)
            (hash-table-walk entries
                             (lambda (k v)
                               (hash-table-update!/default
                                t
                                k
                                (lambda (x) (+ x v))
                                0)))
            (for-each (lambda (p)
                        (hash-table-update!/default t
                                                    (car p)
                                                    (lambda (x) (+ x (cdr p)))
                                                    0))
                      entries))
        (for-each (lambda (k)
                    (when (zero? (hash-table-ref t k))
                      (hash-table-delete! t k)))
                  (hash-table-keys t))
        (let ((sq 0) (sum 0))
          (hash-table-walk t
                           (lambda (k v)
                             (set! sq (+ sq (* v v)))
                             (set! sum (+ sum v))))
          (%make-sparse t (sqrt (inexact sq)) sum))))

    (define (sparse-ref v k)
      "Syntax: (sparse-ref v key)
Library: (scm data cluster)
Description: The value of key in sparse vector v, 0 when absent.
Example:
  (sparse-ref (make-sparse '((a . 1))) 'b) => 0"
      (hash-table-ref/default (sparse-table v) k 0))

    (define (sparse-keys v)
      "Syntax: (sparse-keys v)
Library: (scm data cluster)
Description: The keys with a non-zero value, in no particular order.
Example:
  (sparse-keys (make-sparse '((a . 1) (b . 0)))) => (a)"
      (hash-table-keys (sparse-table v)))

    (define (sparse->alist v)
      "Syntax: (sparse->alist v)
Library: (scm data cluster)
Description: The entries ((key . value) …), in no particular order.
Example:
  (sparse->alist (make-sparse '((a . 2)))) => ((a . 2))"
      (hash-table->alist (sparse-table v)))

    (define (sparse-dot a b)
      "Syntax: (sparse-dot a b)
Library: (scm data cluster)
Description: The dot product of two sparse vectors.
Example:
  (sparse-dot (make-sparse '((x . 2))) (make-sparse '((x . 3) (y . 1)))) => 6"
      (let-values
          (((small big)
            (if (<= (hash-table-size (sparse-table a))
                    (hash-table-size (sparse-table b)))
                (values a b)
                (values b a))))
        (let ((bt (sparse-table big))
              (acc 0))
          (hash-table-walk (sparse-table small)
                           (lambda (k v)
                             (let ((w (hash-table-ref/default bt k #f)))
                               (when w (set! acc (+ acc (* v w)))))))
          acc)))

    (define (cosine-similarity a b)
      "Syntax: (cosine-similarity a b)
Library: (scm data cluster)
Description: Cosine of the angle between two sparse vectors (0.0 when one is
  empty).
Example:
  (cosine-similarity (make-sparse '((x . 1))) (make-sparse '((x . 5)))) => 1.0"
      (let ((na (sparse-norm a))
            (nb (sparse-norm b)))
        (if (or (zero? na) (zero? nb))
            0.0
            (/ (inexact (sparse-dot a b)) (* na nb)))))

    ;; |keys a ∩ keys b| / |keys a ∪ keys b|
    (define (jaccard-similarity a b)
      "Syntax: (jaccard-similarity a b)
Library: (scm data cluster)
Description: Shared keys over all keys of two sparse vectors (the values are
  ignored).
Example:
  (jaccard-similarity (make-sparse '((x . 1) (y . 1))) (make-sparse '((x . 9)))) => 0.5"
      (let* ((ta (sparse-table a))
             (tb (sparse-table b))
             (inter 0))
        (hash-table-walk ta
                         (lambda (k v)
                           (when (hash-table-exists? tb k)
                             (set! inter (+ inter 1)))))
        (let ((union (- (+ (hash-table-size ta) (hash-table-size tb)) inter)))
          (if (zero? union) 0.0 (/ (inexact inter) union)))))

    ;; Σ min / Σ max over the keys (non-negative values)
    (define (weighted-jaccard-similarity a b)
      "Syntax: (weighted-jaccard-similarity a b)
Library: (scm data cluster)
Description: Σ min(a_k, b_k) / Σ max(a_k, b_k) over all keys (Ruzicka
  similarity; for counts or shares, non-negative).
Example:
  (weighted-jaccard-similarity (make-sparse '((x . 1))) (make-sparse '((x . 3)))) => 0.25"
      (let* ((ta (sparse-table a))
             (tb (sparse-table b))
             (mins 0)
             (maxs 0))
        (hash-table-walk ta
                         (lambda (k v)
                           (let ((w (hash-table-ref/default tb k 0)))
                             (set! mins (+ mins (min v w)))
                             (set! maxs (+ maxs (max v w))))))
        (hash-table-walk tb
                         (lambda (k w)
                           (unless (hash-table-exists? ta k)
                             (set! maxs (+ maxs w)))))
        (if (zero? maxs) 0.0 (/ (inexact mins) maxs))))

    ;; --- graphs ---------------------------------------------------------

    ;; nodes 0..n-1; adj: vector of alists ((j . w) …), symmetric; a
    ;; self-loop (i . w) stands for internal weight w (counted once)
    (define-record-type <graph>
      (%make-graph n adj strength total)
      graph?
      (n graph-size)
      (adj graph-adj)
      (strength graph-strengths)
      (total graph-total))

    (define (graph-strength g i)
      "Syntax: (graph-strength g i)
Library: (scm data cluster)
Description: The weighted degree of node i (a self-loop counts once).
Example:
  (graph-strength (make-graph 2 '((0 1 2))) 0) => 2"
      (vector-ref (graph-strengths g) i))

    (define (build-graph n tables)
      (let* ((adj (vector-map (lambda (t) (hash-table->alist t)) tables))
             (str (vector-map (lambda (l) (fold + 0 (map cdr l))) adj)))
        (%make-graph n adj str (fold + 0 (vector->list str)))))

    (define (make-tables n)
      (let ((v (make-vector n #f)))
        (do ((i 0 (+ i 1))) ((= i n) v)
          (vector-set! v i (make-hash-table eqv?)))))

    (define (add-edge! tables i j w)
      (hash-table-update!/default (vector-ref tables i)
                                  j
                                  (lambda (x) (+ x w))
                                  0)
      (unless (= i j)
        (hash-table-update!/default (vector-ref tables j)
                                    i
                                    (lambda (x) (+ x w))
                                    0)))

    ;; edges: ((i j w) …) or ((i j) …) (weight 1); repeated edges add up
    (define (make-graph n edges)
      "Syntax: (make-graph n edges)
Library: (scm data cluster)
Description: An undirected weighted graph with nodes 0..n-1 from edges
  ((i j w) …) or ((i j) …) (weight 1); repeated edges add up, weights
  must be positive. Also graph-size, graph-strength, graph-edges.
Example:
  (graph-edges (make-graph 3 '((0 1) (1 2 0.5)))) => ((0 1 1) (1 2 0.5))"
      (let ((tables (make-tables n)))
        (for-each (lambda (e)
                    (let ((w (if (pair? (cddr e)) (caddr e) 1)))
                      (unless (and (number? w) (> w 0))
                        (error "make-graph: edge weight must be positive" e))
                      (add-edge! tables (car e) (cadr e) w)))
                  edges)
        (build-graph n tables)))

    ;; -> ((i j w) …) with i <= j
    (define (graph-edges g)
      "Syntax: (graph-edges g)
Library: (scm data cluster)
Description: The edges ((i j w) …) with i <= j, by i then j.
Example:
  (graph-edges (make-graph 2 '((1 0 3)))) => ((0 1 3))"
      (let ((acc '()))
        (do ((i 0 (+ i 1))) ((= i (graph-size g)) (reverse acc))
          (for-each (lambda (p)
                      (when (<= i (car p))
                        (set! acc (cons (list i (car p) (cdr p)) acc))))
                    (list-sort (lambda (a b) (< (car a) (car b)))
                               (vector-ref (graph-adj g) i))))))

    (define (->vector items) (if (vector? items) items (list->vector items)))

    ;; every pair with (sim a b) >= min-sim (and > 0) becomes an edge
    (define (similarity-graph items sim . opt)
      "Syntax: (similarity-graph items sim [min-sim])
Library: (scm data cluster)
Description: A graph over items (list or vector) with an edge i-j weighted
  (sim a b) for every pair whose similarity is positive and >=
  min-sim (default 0). O(n²) calls of sim.
Example:
  (similarity-graph vecs cosine-similarity 0.2)"
      (let* ((v (->vector items))
             (n (vector-length v))
             (min-sim (if (pair? opt) (car opt) 0))
             (tables (make-tables n)))
        (do ((i 0 (+ i 1))) ((= i n))
          (do ((j (+ i 1) (+ j 1))) ((= j n))
            (let ((s (sim (vector-ref v i) (vector-ref v j))))
              (when (and (> s 0) (>= s min-sim)) (add-edge! tables i j s)))))
        (build-graph n tables)))

    ;; each item linked to its k most similar items (similarity > min-sim),
    ;; the union made symmetric (the weight is the similarity)
    (define (knn-graph items k sim . opt)
      "Syntax: (knn-graph items k sim [min-sim])
Library: (scm data cluster)
Description: A graph linking every item to its k most similar items (similarity
  > min-sim, default 0), made symmetric; weights are the similarities.
  Sparser than similarity-graph for community detection.
Example:
  (louvain (knn-graph vecs 10 cosine-similarity))"
      (let* ((v (->vector items))
             (n (vector-length v))
             (min-sim (if (pair? opt) (car opt) 0))
             (tables (make-tables n)))
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((cands '()))
            (do ((j 0 (+ j 1))) ((= j n))
              (unless (= i j)
                (let ((s (sim (vector-ref v i) (vector-ref v j))))
                  (when (and (> s 0) (> s min-sim))
                    (set! cands (cons (cons j s) cands))))))
            (let
                ((best (take-at-most (list-sort
                                      (lambda (a b)
                                        (or
                                         (> (cdr a) (cdr b))
                                         (and (= (cdr a) (cdr b))
                                              (< (car a) (car b)))))
                                      cands)
                                     k)))
              (for-each (lambda (p)
                          ;; set, not add: a mutual neighbour counts once
                          (hash-table-set! (vector-ref tables i)
                                           (car p)
                                           (cdr p))
                          (hash-table-set! (vector-ref tables (car p))
                                           i
                                           (cdr p)))
                        best))))
        (build-graph n tables)))

    (define (take-at-most l k)
      (if (or (null? l) (<= k 0))
          '()
          (cons (car l) (take-at-most (cdr l) (- k 1)))))

    ;; --- memberships ----------------------------------------------------

    ;; renumber: largest cluster 0, ties by the smallest member
    (define (normalize-membership m)
      (let* ((n (vector-length m))
             (size (make-hash-table equal?))
             (first (make-hash-table equal?)))
        (do ((i (- n 1) (- i 1))) ((< i 0))
          (let ((c (vector-ref m i)))
            (hash-table-update!/default size c (lambda (x) (+ x 1)) 0)
            (hash-table-set! first c i)))
        (let* ((cs (list-sort (lambda (a b)
                                (let ((sa (hash-table-ref size a))
                                      (sb (hash-table-ref size b)))
                                  (or (> sa sb)
                                      (and
                                       (= sa sb)
                                       (< (hash-table-ref first a)
                                          (hash-table-ref first b))))))
                              (hash-table-keys size)))
               (num (make-hash-table equal?)))
          (let loop ((cs cs) (i 0))
            (when (pair? cs)
              (hash-table-set! num (car cs) i)
              (loop (cdr cs) (+ i 1))))
          (vector-map (lambda (c) (hash-table-ref num c)) m))))

    ;; membership -> vector of member lists, by cluster number
    (define (membership-groups m)
      "Syntax: (membership-groups m)
Library: (scm data cluster)
Description: A membership vector -> vector of member lists by cluster number.
Example:
  (membership-groups #(0 1 0)) => #((0 2) (1))"
      (let* ((c (if (zero? (vector-length m))
                    0
                    (+ 1 (apply max (vector->list m)))))
             (g (make-vector c '())))
        (do ((i (- (vector-length m) 1) (- i 1))) ((< i 0) g)
          (let ((k (vector-ref m i)))
            (vector-set! g k (cons i (vector-ref g k)))))))

    ;; --- modularity / louvain ----------------------------------------------

    ;; Q = 1/2m Σ_c (in_c - γ tot_c² / 2m)
    (define (modularity g m . opt)
      "Syntax: (modularity g m [resolution])
Library: (scm data cluster)
Description: Newman modularity of membership m in graph g, with resolution γ
  (default 1.0): 1/2m Σ_c (in_c - γ tot_c² / 2m).
Example:
  (modularity g (louvain g))"
      (let* ((gamma (if (pair? opt) (car opt) 1.0))
             (m2 (inexact (graph-total g)))
             (in (make-hash-table eqv?))
             (tot (make-hash-table eqv?)))
        (if (zero? m2)
            0.0
            (begin
              (do ((i 0 (+ i 1))) ((= i (graph-size g)))
                (let ((ci (vector-ref m i)))
                  (hash-table-update!/default
                   tot
                   ci
                   (lambda (x) (+ x (graph-strength g i)))
                   0)
                  (for-each (lambda (p)
                              (when (= ci (vector-ref m (car p)))
                                (hash-table-update!/default
                                 in
                                 ci
                                 (lambda (x) (+ x (cdr p)))
                                 0)))
                            (vector-ref (graph-adj g) i))))
              (/ (fold (lambda (c acc)
                         (let ((t (hash-table-ref tot c)))
                           (+ acc
                              (- (hash-table-ref/default in c 0)
                                 (/ (* gamma t t) m2)))))
                       0.0
                       (hash-table-keys tot))
                 m2)))))

    (define (seeded-source seed)
      (let ((s (make-random-source)))
        (random-source-pseudo-randomize! s seed 0)
        s))

    (define (shuffled-iota n rnd)
      (let ((v (list->vector (iota n))))
        (do ((i (- n 1) (- i 1))) ((< i 1) v)
          (let* ((j (rnd (+ i 1)))
                 (t (vector-ref v i)))
            (vector-set! v i (vector-ref v j))
            (vector-set! v j t)))))

    ;; one local-moving phase; -> (values membership moved?)
    (define (local-moving g gamma rnd)
      (let* ((n (graph-size g))
             (m2 (inexact (graph-total g)))
             (comm (list->vector (iota n)))
             (tot (vector-map inexact (graph-strengths g)))
             (moved-any #f))
        (let pass ()
          (let ((moved #f)
                (order (shuffled-iota n rnd)))
            (vector-for-each (lambda (i)
                               (let* ((ci (vector-ref comm i))
                                      (ki (graph-strength g i))
                                      (links (make-hash-table eqv?)))
                                 (for-each
                                  (lambda (p)
                                    (unless (= (car p) i)
                                      (hash-table-update!/default
                                       links
                                       (vector-ref comm (car p))
                                       (lambda (x) (+ x (cdr p)))
                                       0)))
                                  (vector-ref (graph-adj g) i))
                                 (vector-set! tot ci
                                              (- (vector-ref tot ci) ki))
                                 (let* ((gain
                                         (lambda (c)
                                           (-
                                            (hash-table-ref/default links c 0)
                                            (/ (* gamma (vector-ref tot c) ki)
                                               m2))))
                                        (best ci)
                                        (best-gain (gain ci)))
                                   (for-each
                                    (lambda (c)
                                      (let ((x (gain c)))
                                        (when
                                            (or
                                             (> x (+ best-gain 1e-12))
                                             (and (> x (- best-gain 1e-12))
                                                  (< c best)
                                                  (not (= best ci))))
                                          (set! best c)
                                          (set! best-gain x))))
                                    (list-sort < (hash-table-keys links)))
                                   (vector-set! tot best
                                                (+ (vector-ref tot best) ki))
                                   (unless (= best ci)
                                     (vector-set! comm i best)
                                     (set! moved #t)
                                     (set! moved-any #t)))))
                             order)
            (when moved (pass))))
        (values comm moved-any)))

    ;; split every community into its connected parts (edges inside it)
    (define (split-connected g comm)
      (let* ((n (graph-size g))
             (out (make-vector n -1))
             (next 0))
        (do ((s 0 (+ s 1))) ((= s n) out)
          (when (< (vector-ref out s) 0)
            (let ((c (vector-ref comm s))
                  (id next))
              (set! next (+ next 1))
              (vector-set! out s id)
              (let loop ((stack (list s)))
                (when (pair? stack)
                  (let ((i (car stack))
                        (rest (cdr stack)))
                    (loop (fold (lambda (p acc)
                                  (let ((j (car p)))
                                    (if
                                     (and (< (vector-ref out j) 0)
                                          (= (vector-ref comm j) c))
                                     (begin
                                       (vector-set! out j id)
                                       (cons j acc))
                                     acc)))
                                rest
                                (vector-ref (graph-adj g) i)))))))))))

    ;; dense renumbering 0..c-1 -> (values membership c)
    (define (compact m)
      (let ((num (make-hash-table eqv?))
            (next 0))
        (let ((r (vector-map (lambda (c)
                               (or (hash-table-ref/default num c #f)
                                   (begin
                                     (hash-table-set! num c next)
                                     (set! next (+ next 1))
                                     (- next 1))))
                             m)))
          (values r next))))

    (define (aggregate g comm c)
      (let ((tables (make-tables c)))
        (do ((i 0 (+ i 1))) ((= i (graph-size g)))
          (let ((ci (vector-ref comm i)))
            (for-each (lambda (p)
                        (let ((cj (vector-ref comm (car p))))
                          ;; each undirected edge is listed at both ends:
                          ;; add each listing once in one direction
                          (cond ((= ci cj)
                                 (hash-table-update!/default
                                  (vector-ref tables ci)
                                  ci
                                  (lambda (x) (+ x (cdr p)))
                                  0))
                                ((< ci cj)
                                 (hash-table-update!/default
                                  (vector-ref tables ci)
                                  cj
                                  (lambda (x) (+ x (cdr p)))
                                  0)
                                 (hash-table-update!/default
                                  (vector-ref tables cj)
                                  ci
                                  (lambda (x) (+ x (cdr p)))
                                  0)))))
                      (vector-ref (graph-adj g) i))))
        (build-graph c tables)))

    ;; (louvain g [resolution] ['refine] ['seed n]) -> membership
    (define (louvain g . opts)
      "Syntax: (louvain g [resolution] ['refine] ['seed n])
Library: (scm data cluster)
Description: Community detection by modularity optimisation (Louvain: local
  moving, then aggregation, repeated). resolution γ (default 1.0):
  higher gives smaller communities. 'refine splits every community
  into its connected parts before aggregating (the connectivity
  guarantee of Leiden). The node order is shuffled with seed (default
  1), so the result is reproducible. Returns a membership vector,
  clusters numbered by size.
Example:
  (louvain (make-graph 4 '((0 1) (2 3)))) => #(0 0 1 1)"
      (let* ((gamma (if (and (pair? opts) (number? (car opts)))
                        (car opts)
                        1.0))
             (refine? (memq 'refine opts))
             (seed (let ((t (memq 'seed opts))) (if t (cadr t) 1)))
             (rnd (random-source-make-integers (seeded-source seed)))
             (n (graph-size g)))
        (if (or (zero? n) (zero? (graph-total g)))
            (normalize-membership (list->vector (iota n)))
            (let loop ((cur g)
                       (member (list->vector (iota n))))
              (let-values (((comm moved) (local-moving cur gamma rnd)))
                (let*-values (((comm)
                               (if refine? (split-connected cur comm) comm))
                              ((comm c) (compact comm)))
                  (let
                      ((member (vector-map (lambda (x) (vector-ref comm x))
                                           member)))
                    (if (or (not moved) (= c (graph-size cur)))
                        (normalize-membership member)
                        (loop (aggregate cur comm c) member)))))))))

    ;; --- distances / hierarchical clustering ----------------------------

    ;; items + (dist a b) -> n×n distance matrix (vector of vectors)
    (define (distance-matrix items dist)
      "Syntax: (distance-matrix items dist)
Library: (scm data cluster)
Description: The symmetric n×n matrix (vector of vectors of flonums) of
  (dist a b) over items; the diagonal is 0.
Example:
  (distance-matrix '(0 3) (lambda (a b) (abs (- a b)))) => #(#(0.0 3.0) #(3.0 0.0))"
      (let* ((v (->vector items))
             (n (vector-length v))
             (d (make-vector n #f)))
        (do ((i 0 (+ i 1))) ((= i n)) (vector-set! d i (make-vector n 0.0)))
        (do ((i 0 (+ i 1))) ((= i n) d)
          (do ((j (+ i 1) (+ j 1))) ((= j n))
            (let ((x (inexact (dist (vector-ref v i) (vector-ref v j)))))
              (vector-set! (vector-ref d i) j x)
              (vector-set! (vector-ref d j) i x))))))

    (define (dref d i j) (vector-ref (vector-ref d i) j))

    ;; Lance-Williams update: distance of k to the merge of i (size ni)
    ;; and j (size nj)
    (define (lw linkage dki dkj dij ni nj nk)
      (case linkage
        ((average) (/ (+ (* ni dki) (* nj dkj)) (+ ni nj)))
        ((complete) (max dki dkj))
        ((single) (min dki dkj))
        ((ward)
         ;; on squared euclidean distances (ward.D2 when given squares)
         (/ (- (+ (* (+ ni nk) dki) (* (+ nj nk) dkj)) (* nk dij))
            (+ ni nj nk)))
        (else (error "hclust: unknown linkage" linkage))))

    ;; (hclust d [linkage]) -> merges: list of (a b height size) in
    ;; height order, a/b: leaf 0..n-1 or merge n+t (t-th merge)
    (define (hclust d . opt)
      "Syntax: (hclust d [linkage])
Library: (scm data cluster)
Description: Agglomerative hierarchical clustering of a distance matrix d;
  linkage average (default, UPGMA), complete, single or ward (Ward on
  the given distances; give squared Euclidean distances for R's
  ward.D2 merge order). Nearest-neighbour chain, O(n²) time per merge
  scan and O(n²) memory. Returns the n-1 merges (a b height size) by
  height; a, b are leaves 0..n-1 or earlier merges n+t (R's hclust
  merge with other numbering).
Example:
  (cutree (hclust (distance-matrix pts dist)) 3)"
      (let* ((linkage (if (pair? opt) (car opt) 'average))
             (n (vector-length d))
             (dm (vector-map vector-copy d))
             (active (make-vector n #t))
             (size (make-vector n 1))
             (raw '()))
        ;; nearest-neighbour chain (exact for these reducible linkages)
        (let loop ((chain '()) (left n))
          (when (> left 1)
            (let* ((chain (if (null? chain)
                              (list (let find ((i 0))
                                      (if (vector-ref active i)
                                          i
                                          (find (+ i 1)))))
                              chain))
                   (a (car chain))
                   (prev (and (pair? (cdr chain)) (cadr chain)))
                   (b (let scan ((j 0) (best #f) (bd +inf.0))
                        (cond ((= j n) best)
                              ((or (= j a) (not (vector-ref active j)))
                               (scan (+ j 1) best bd))
                              (else (let ((x (dref dm a j)))
                                      (if
                                       (or (< x bd)
                                           (and (= x bd) prev (= j prev)))
                                       (scan (+ j 1) j x)
                                       (scan (+ j 1) best bd))))))))
              (if (and prev (= b prev))
                  ;; merge a and b into slot (min a b)
                  (let* ((i (min a b))
                         (j (max a b))
                         (dij (dref dm i j))
                         (ni (vector-ref size i))
                         (nj (vector-ref size j)))
                    (set! raw (cons (list i j dij (+ ni nj)) raw))
                    (do ((k 0 (+ k 1))) ((= k n))
                      (when
                          (and (vector-ref active k)
                               (not (= k i))
                               (not (= k j)))
                        (let
                            ((x (lw linkage
                                    (dref dm k i)
                                    (dref dm k j)
                                    dij
                                    ni
                                    nj
                                    (vector-ref size k))))
                          (vector-set! (vector-ref dm k) i x)
                          (vector-set! (vector-ref dm i) k x))))
                    (vector-set! active j #f)
                    (vector-set! size i (+ ni nj))
                    (loop (cddr chain) (- left 1)))
                  (loop (cons b chain) left)))))
        ;; sort by height (stable) and name the clusters
        (let* ((sorted (list-stable-sort
                        (lambda (x y) (< (caddr x) (caddr y)))
                        (reverse raw)))
               (parent (list->vector (iota n)))
               (label (list->vector (iota n))))
          (define (root i)
            (let ((p (vector-ref parent i)))
              (if (= p i)
                  i
                  (let ((r (root p)))
                    (vector-set! parent i r)
                    r))))
          (let loop ((ms sorted) (t 0) (acc '()))
            (if (null? ms)
                (reverse acc)
                (let* ((m (car ms))
                       (ri (root (car m)))
                       (rj (root (cadr m)))
                       (la (vector-ref label ri))
                       (lb (vector-ref label rj)))
                  (vector-set! parent rj ri)
                  (vector-set! label ri (+ n t))
                  (loop (cdr ms)
                        (+ t 1)
                        (cons (list (min la lb)
                                    (max la lb)
                                    (caddr m)
                                    (cadddr m))
                              acc))))))))

    (define (apply-merges n merges count)
      (let ((parent (list->vector (iota (+ n (length merges))))))
        (define (root i)
          (let ((p (vector-ref parent i)))
            (if (= p i)
                i
                (let ((r (root p)))
                  (vector-set! parent i r)
                  r))))
        (let loop ((ms merges) (t 0))
          (when (and (pair? ms) (< t count))
            (vector-set! parent (root (car (car ms))) (+ n t))
            (vector-set! parent (root (cadr (car ms))) (+ n t))
            (loop (cdr ms) (+ t 1))))
        (normalize-membership (vector-map (lambda (i) (root i))
                                          (list->vector (iota n))))))

    ;; membership with k clusters
    (define (cutree merges k)
      "Syntax: (cutree merges k)
Library: (scm data cluster)
Description: The membership with k clusters from hclust's merges.
Example:
  (cutree (hclust d) 2) => #(0 0 0 1 1)"
      (let ((n (+ 1 (length merges))))
        (apply-merges n merges (max 0 (- n (max 1 k))))))

    ;; membership: merges up to height h
    (define (cutree-height merges h)
      "Syntax: (cutree-height merges h)
Library: (scm data cluster)
Description: The membership after all merges at height <= h.
Example:
  (cutree-height (hclust d) 1.5)"
      (let ((n (+ 1 (length merges))))
        (apply-merges n merges (count (lambda (m) (<= (caddr m) h)) merges))))

    ;; --- k-means ----------------------------------------------------------

    (define (sqdist a b)
      (let ((n (vector-length a)))
        (let loop ((i 0) (acc 0.0))
          (if (= i n)
              acc
              (let ((x (- (vector-ref a i) (vector-ref b i))))
                (loop (+ i 1) (+ acc (* x x))))))))

    ;; (kmeans points k ['seed n] ['max-iter n]) -> (membership . centres)
    ;; points: list/vector of equal-length numeric vectors
    (define (kmeans points k . opts)
      "Syntax: (kmeans points k ['seed n] ['max-iter n])
Library: (scm data cluster)
Description: Lloyd's k-means on dense points (equal-length numeric vectors or
  lists), k-means++ start with seed (default 1), at most max-iter
  rounds (default 100). Returns (membership . centres), centres in
  cluster order.
Example:
  (car (kmeans '(#(0) #(1) #(10)) 2)) => #(0 0 1)"
      (let* ((pts (vector-map (lambda (p) (vector-map inexact (->vector p)))
                              (->vector points)))
             (n (vector-length pts))
             (seed (let ((t (memq 'seed opts))) (if t (cadr t) 1)))
             (max-iter (let ((t (memq 'max-iter opts))) (if t (cadr t) 100)))
             (src (seeded-source seed))
             (rint (random-source-make-integers src))
             (rreal (random-source-make-reals src)))
        (when (or (< k 1) (> k n)) (error "kmeans: need 1 <= k <= n" k n))
        ;; k-means++
        (let ((centres (list (vector-copy (vector-ref pts (rint n))))))
          (let grow ()
            (when (< (length centres) k)
              (let* ((d2 (vector-map (lambda (p)
                                       (apply
                                        min
                                        (map (lambda (c) (sqdist p c))
                                             centres)))
                                     pts))
                     (total (fold + 0.0 (vector->list d2))))
                (set! centres
                      (append centres
                              (list (vector-copy
                                     (vector-ref
                                      pts
                                      (if
                                       (zero? total)
                                       (rint n)
                                       (let ((r (* total (rreal))))
                                         (let pick ((i 0) (acc 0.0))
                                           (let
                                               ((acc
                                                 (+ acc (vector-ref d2 i))))
                                             (if (or (>= acc r) (= i (- n 1)))
                                                 i
                                                 (pick (+ i 1) acc))))))))))))
              (grow)))
          (let ((cs (list->vector centres)))
            (let iterate ((it 0)
                          (assign (make-vector n -1)))
              (let
                  ((new (vector-map (lambda (p)
                                      (let loop ((j 0) (best 0) (bd +inf.0))
                                        (if
                                         (= j k)
                                         best
                                         (let
                                             ((x
                                               (sqdist p (vector-ref cs j))))
                                           (if (< x bd)
                                               (loop (+ j 1) j x)
                                               (loop (+ j 1) best bd))))))
                                    pts)))
                ;; recompute centres (an empty cluster keeps its centre)
                (do ((j 0 (+ j 1))) ((= j k))
                  (let
                      ((members (filter (lambda (i) (= (vector-ref new i) j))
                                        (iota n))))
                    (when (pair? members)
                      (let* ((dim (vector-length (vector-ref pts 0)))
                             (c (make-vector dim 0.0)))
                        (for-each (lambda (i)
                                    (let ((p (vector-ref pts i)))
                                      (do ((d 0 (+ d 1))) ((= d dim))
                                        (vector-set!
                                         c
                                         d
                                         (+ (vector-ref c d)
                                            (vector-ref p d))))))
                                  members)
                        (do ((d 0 (+ d 1))) ((= d dim))
                          (vector-set! c d
                                       (/ (vector-ref c d) (length members))))
                        (vector-set! cs j c)))))
                (if (or (equal? new assign) (>= (+ it 1) max-iter))
                    ;; renumber with the centres
                    (let ((m (normalize-membership new))
                          (out (make-vector k #f)))
                      (do ((i 0 (+ i 1))) ((= i n))
                        (vector-set! out
                                     (vector-ref m i)
                                     (vector-ref cs (vector-ref new i))))
                      (cons m
                            (vector->list
                             (vector-map (lambda (c) (or c (vector))) out))))
                    (iterate (+ it 1) new))))))))

    ;; --- quality ------------------------------------------------------------

    ;; -> (mean . per-item vector); a singleton cluster scores 0
    (define (silhouette d m)
      "Syntax: (silhouette d m)
Library: (scm data cluster)
Description: Silhouette widths of membership m under distance matrix d:
  (mean . per-item vector); an item alone in its cluster scores 0.
Example:
  (car (silhouette d (cutree (hclust d) 2)))"
      (let* ((n (vector-length m))
             (groups (membership-groups m))
             (s (make-vector n 0.0)))
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((own (vector-ref groups (vector-ref m i))))
            (when (> (length own) 1)
              (let ((a (/ (fold (lambda (j acc) (+ acc (dref d i j))) 0.0 own)
                          (- (length own) 1)))
                    (b (let loop ((c 0) (best +inf.0))
                         (if (= c (vector-length groups))
                             best
                             (loop (+ c 1)
                                   (if (= c (vector-ref m i))
                                       best
                                       (let ((g (vector-ref groups c)))
                                         (if
                                          (null? g)
                                          best
                                          (min
                                           best
                                           (/
                                            (fold
                                             (lambda (j acc)
                                               (+ acc (dref d i j)))
                                             0.0
                                             g)
                                            (length g)))))))))))
                (vector-set! s i
                             (if (or (infinite? b) (zero? (max a b)))
                                 0.0
                                 (/ (- b a) (max a b))))))))
        (cons (if (zero? n) 0.0 (/ (fold + 0.0 (vector->list s)) n)) s)))

    ;; Hubert-Arabie adjusted Rand index of two memberships
    (define (adjusted-rand-index a b)
      "Syntax: (adjusted-rand-index a b)
Library: (scm data cluster)
Description: Agreement of two memberships of the same items, corrected for
  chance (Hubert-Arabie): 1 identical, about 0 random, may be negative.
Example:
  (adjusted-rand-index #(0 0 1) #(5 5 7)) => 1.0"
      (let* ((n (vector-length a))
             (cells (make-hash-table equal?))
             (ra (make-hash-table eqv?))
             (rb (make-hash-table eqv?))
             (c2 (lambda (x) (/ (* x (- x 1)) 2))))
        (unless (= n (vector-length b))
          (error "adjusted-rand-index: memberships differ in length"))
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((x (vector-ref a i))
                (y (vector-ref b i)))
            (hash-table-update!/default cells
                                        (cons x y)
                                        (lambda (v) (+ v 1))
                                        0)
            (hash-table-update!/default ra x (lambda (v) (+ v 1)) 0)
            (hash-table-update!/default rb y (lambda (v) (+ v 1)) 0)))
        (let* ((sum-cells (fold (lambda (v acc) (+ acc (c2 v)))
                                0
                                (hash-table-values cells)))
               (sa (fold (lambda (v acc) (+ acc (c2 v)))
                         0
                         (hash-table-values ra)))
               (sb (fold (lambda (v acc) (+ acc (c2 v)))
                         0
                         (hash-table-values rb)))
               (total (c2 n))
               (expected (if (zero? total) 0 (/ (* sa sb) total)))
               (maxi (/ (+ sa sb) 2)))
          (if (= maxi expected)
              1.0
              (inexact (/ (- sum-cells expected) (- maxi expected)))))))))

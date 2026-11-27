(import (scheme base)
        (scheme inexact)
        (srfi 1)
        (scm data cluster)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-cluster")

(test-group "sparse vectors"
  (let ((a (make-sparse '((x . 1) (y . 2) (z . 0))))
        (b (make-sparse '((y . 2) (w . 4) (y . 1)))))
    (test-equal 2 (sparse-ref a 'y))
    (test-equal 0 (sparse-ref a 'z))
    (test-equal 3 (sparse-ref b 'y)) ; repeated keys add up
    (test-equal 2 (length (sparse-keys a))) ; zero dropped
    (test-equal 6 (sparse-dot a b))
    (test-equal 3 (sparse-sum a))
    (test-approximate (sqrt 5) (sparse-norm a) 1e-12)
    (test-approximate (/ 6 (* (sqrt 5) 5)) (cosine-similarity a b) 1e-12)
    (test-approximate 1/3 (jaccard-similarity a b) 1e-12)
    ;; Σmin = 2, Σmax = 1 + 3 + 4 = 8
    (test-approximate 0.25 (weighted-jaccard-similarity a b) 1e-12)
    (test-equal 0.0 (cosine-similarity a (make-sparse '())))
    (test-approximate 1.0 (cosine-similarity a a) 1e-12)))

;; two triangles joined by one weak edge
(define two-triangles
  (make-graph 6 '((0 1 1) (1 2 1) (0 2 1) (3 4 1) (4 5 1) (3 5 1) (2 3 0.1))))

(test-group "graphs"
  (test-equal 6 (graph-size two-triangles))
  (test-equal 2.1 (graph-strength two-triangles 2))
  (test-equal 7 (length (graph-edges two-triangles)))
  (let ((g (make-graph 2 '((0 1) (0 1 2)))))
    (test-equal '((0 1 3)) (graph-edges g)))
  (let* ((items (map make-sparse '(((a . 1)) ((a . 1) (b . 1)) ((c . 1)))))
         (g (similarity-graph items cosine-similarity)))
    (test-equal 1 (length (graph-edges g)))
    (test-equal 0 (graph-strength g 2)))
  (let* ((items (map (lambda (x) (make-sparse `((v . ,x) (w . 1))))
                     '(1 2 3 10 11)))
         (g (knn-graph items 1 weighted-jaccard-similarity)))
    ;; every node has at least one neighbour
    (test-assert (every (lambda (i) (> (graph-strength g i) 0)) (iota 5)))))

(test-group "louvain"
  (let ((m (louvain two-triangles)))
    (test-equal #(0 0 0 1 1 1) m)
    ;; 2m = 12.2, in = 6, tot = 6.1 per triangle: 2 (6 - 6.1²/12.2) / 12.2
    (test-approximate 0.483607 (modularity two-triangles m) 1e-6))
  (test-equal #(0 0 0 1 1 1) (louvain two-triangles 1.0 'refine 'seed 7))
  ;; reproducible per seed
  (test-equal (louvain two-triangles 'seed 3) (louvain two-triangles 'seed 3))
  ;; a high resolution splits into smaller groups
  (test-assert (> (+ 1
                     (apply max (vector->list (louvain two-triangles 10.0))))
                  2))
  ;; no edges: singletons
  (test-equal #(0 1 2) (louvain (make-graph 3 '())))
  (test-equal 0.0 (modularity (make-graph 3 '()) #(0 1 2)))
  (test-equal #((0 1 2) (3 4 5)) (membership-groups #(0 0 0 1 1 1))))

;; 1-d points: {0, 1, 2} and {10, 11}
(define pts '(0 1 2 10 11))
(define d (distance-matrix pts (lambda (a b) (abs (- a b)))))

(test-group "hclust"
  (let ((merges (hclust d)))
    (test-equal 4 (length merges))
    ;; first merges: 0-1 (1), 3-4 (1)
    (test-equal '(0 1 1.0 2) (car merges))
    (test-equal '(3 4 1.0 2) (cadr merges))
    ;; 2 joins {0,1} at average 1.5
    (test-equal '(2 5 1.5 3) (caddr merges))
    (test-equal 5 (cadddr (cadddr merges)))
    (test-equal #(0 0 0 1 1) (cutree merges 2))
    ;; {0,1} {3,4} {2}: numbered by size, ties by first member
    (test-equal #(0 0 2 1 1) (cutree merges 3))
    (test-equal #(0 1 2 3 4) (cutree merges 5))
    (test-equal #(0 0 0 0 0) (cutree merges 1))
    (test-equal #(0 0 0 1 1) (cutree-height merges 1.5)))
  (test-equal '(2 5 2.0 3) (caddr (hclust d 'complete)))
  (test-equal '(1.0 1.0 1.0 8.0) (map caddr (hclust d 'single)))
  (test-equal #(0 0 0 1 1) (cutree (hclust d 'ward) 2)))

(test-group "kmeans"
  (let ((r (kmeans (map vector pts) 2 'seed 5)))
    (test-equal #(0 0 0 1 1) (car r))
    (test-equal #(1.0) (cadr r))
    (test-equal #(10.5) (caddr r)))
  (test-error (kmeans '(#(1)) 2)))

(test-group "quality"
  (let ((s (silhouette d #(0 0 0 1 1))))
    (test-assert (> (car s) 0.8))
    (test-equal 5 (vector-length (cdr s))))
  (test-assert (< (car (silhouette d #(0 1 0 1 0))) 0))
  (test-equal 1.0 (adjusted-rand-index #(0 0 1 1) #(1 1 0 0)))
  (test-approximate -0.5 (adjusted-rand-index #(0 0 1 1) #(0 1 0 1)) 1e-12))

(test-end "scm-data-cluster")

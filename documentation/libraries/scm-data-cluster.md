# `(scm data cluster)`

Similarity, graphs and clustering — cosine/Jaccard, k-NN graphs, Louvain, hclust, k-means

## Overview

Similarity, graphs and clustering in plain Scheme, for data analysis
next to `(scm data …)`:

- sparse vectors (`make-sparse`, any keys) with `cosine-similarity`,
  `jaccard-similarity` and `weighted-jaccard-similarity`
- weighted undirected graphs from an edge list (`make-graph`) or a
  similarity (`similarity-graph`, `knn-graph`)
- community detection: `louvain` (modularity with a resolution; with
  `'refine` every community is split into its connected parts, the
  connectivity guarantee of Leiden), `modularity`
- hierarchical clustering: `hclust` on a `distance-matrix` (average,
  complete, single, ward linkage), `cutree`, `cutree-height`
- `kmeans` (k-means++ start) on dense vectors
- quality: `silhouette`, `adjusted-rand-index`

A membership is a vector of cluster numbers 0..c-1, numbered by size
(largest first). Random steps take a seed, so results are reproducible.

## Common uses

```scheme
;; codes described by their hospital volumes; communities of codes
;; provided by the same hospitals
(define vecs (map (lambda (c) (make-sparse (code-hospital-counts c))) codes))
(define m (louvain (knn-graph vecs 15 cosine-similarity) 1.0 'refine))
(membership-groups m)

;; a dendrogram cut into 8 groups
(define d (distance-matrix vecs (lambda (a b) (- 1 (cosine-similarity a b)))))
(cutree (hclust d 'average) 8)
```


## Exports

### `adjusted-rand-index`

```
Syntax: (adjusted-rand-index a b)
Library: (scm data cluster)
Description: Agreement of two memberships of the same items, corrected for
  chance (Hubert-Arabie): 1 identical, about 0 random, may be negative.
Example:
  (adjusted-rand-index #(0 0 1) #(5 5 7)) => 1.0
```

### `cosine-similarity`

```
Syntax: (cosine-similarity a b)
Library: (scm data cluster)
Description: Cosine of the angle between two sparse vectors (0.0 when one is
  empty).
Example:
  (cosine-similarity (make-sparse '((x . 1))) (make-sparse '((x . 5)))) => 1.0
```

### `cutree`

```
Syntax: (cutree merges k)
Library: (scm data cluster)
Description: The membership with k clusters from hclust's merges.
Example:
  (cutree (hclust d) 2) => #(0 0 0 1 1)
```

### `cutree-height`

```
Syntax: (cutree-height merges h)
Library: (scm data cluster)
Description: The membership after all merges at height <= h.
Example:
  (cutree-height (hclust d) 1.5)
```

### `distance-matrix`

```
Syntax: (distance-matrix items dist)
Library: (scm data cluster)
Description: The symmetric n×n matrix (vector of vectors of flonums) of
  (dist a b) over items; the diagonal is 0.
Example:
  (distance-matrix '(0 3) (lambda (a b) (abs (- a b)))) => #(#(0.0 3.0) #(3.0 0.0))
```

### `graph-edges`

```
Syntax: (graph-edges g)
Library: (scm data cluster)
Description: The edges ((i j w) …) with i <= j, by i then j.
Example:
  (graph-edges (make-graph 2 '((1 0 3)))) => ((0 1 3))
```

### `graph-size`

*(no documentation)*

### `graph-strength`

```
Syntax: (graph-strength g i)
Library: (scm data cluster)
Description: The weighted degree of node i (a self-loop counts once).
Example:
  (graph-strength (make-graph 2 '((0 1 2))) 0) => 2
```

### `hclust`

```
Syntax: (hclust d [linkage])
Library: (scm data cluster)
Description: Agglomerative hierarchical clustering of a distance matrix d;
  linkage average (default, UPGMA), complete, single or ward (Ward on
  the given distances; give squared Euclidean distances for R's
  ward.D2 merge order). Nearest-neighbour chain, O(n²) time per merge
  scan and O(n²) memory. Returns the n-1 merges (a b height size) by
  height; a, b are leaves 0..n-1 or earlier merges n+t (R's hclust
  merge with other numbering).
Example:
  (cutree (hclust (distance-matrix pts dist)) 3)
```

### `jaccard-similarity`

```
Syntax: (jaccard-similarity a b)
Library: (scm data cluster)
Description: Shared keys over all keys of two sparse vectors (the values are
  ignored).
Example:
  (jaccard-similarity (make-sparse '((x . 1) (y . 1))) (make-sparse '((x . 9)))) => 0.5
```

### `kmeans`

```
Syntax: (kmeans points k ['seed n] ['max-iter n])
Library: (scm data cluster)
Description: Lloyd's k-means on dense points (equal-length numeric vectors or
  lists), k-means++ start with seed (default 1), at most max-iter
  rounds (default 100). Returns (membership . centres), centres in
  cluster order.
Example:
  (car (kmeans '(#(0) #(1) #(10)) 2)) => #(0 0 1)
```

### `knn-graph`

```
Syntax: (knn-graph items k sim [min-sim])
Library: (scm data cluster)
Description: A graph linking every item to its k most similar items (similarity
  > min-sim, default 0), made symmetric; weights are the similarities.
  Sparser than similarity-graph for community detection.
Example:
  (louvain (knn-graph vecs 10 cosine-similarity))
```

### `louvain`

```
Syntax: (louvain g [resolution] ['refine] ['seed n])
Library: (scm data cluster)
Description: Community detection by modularity optimisation (Louvain: local
  moving, then aggregation, repeated). resolution γ (default 1.0):
  higher gives smaller communities. 'refine splits every community
  into its connected parts before aggregating (the connectivity
  guarantee of Leiden). The node order is shuffled with seed (default
  1), so the result is reproducible. Returns a membership vector,
  clusters numbered by size.
Example:
  (louvain (make-graph 4 '((0 1) (2 3)))) => #(0 0 1 1)
```

### `make-graph`

```
Syntax: (make-graph n edges)
Library: (scm data cluster)
Description: An undirected weighted graph with nodes 0..n-1 from edges
  ((i j w) …) or ((i j) …) (weight 1); repeated edges add up, weights
  must be positive. Also graph-size, graph-strength, graph-edges.
Example:
  (graph-edges (make-graph 3 '((0 1) (1 2 0.5)))) => ((0 1 1) (1 2 0.5))
```

### `make-sparse`

```
Syntax: (make-sparse entries)
Library: (scm data cluster)
Description: A sparse vector from an alist ((key . number) …) or a hash table;
  any keys (equal?), repeated keys add up, zeros are dropped.
Example:
  (sparse-ref (make-sparse '((a . 1) (a . 2))) 'a) => 3
```

### `membership-groups`

```
Syntax: (membership-groups m)
Library: (scm data cluster)
Description: A membership vector -> vector of member lists by cluster number.
Example:
  (membership-groups #(0 1 0)) => #((0 2) (1))
```

### `modularity`

```
Syntax: (modularity g m [resolution])
Library: (scm data cluster)
Description: Newman modularity of membership m in graph g, with resolution γ
  (default 1.0): 1/2m Σ_c (in_c - γ tot_c² / 2m).
Example:
  (modularity g (louvain g))
```

### `silhouette`

```
Syntax: (silhouette d m)
Library: (scm data cluster)
Description: Silhouette widths of membership m under distance matrix d:
  (mean . per-item vector); an item alone in its cluster scores 0.
Example:
  (car (silhouette d (cutree (hclust d) 2)))
```

### `similarity-graph`

```
Syntax: (similarity-graph items sim [min-sim])
Library: (scm data cluster)
Description: A graph over items (list or vector) with an edge i-j weighted
  (sim a b) for every pair whose similarity is positive and >=
  min-sim (default 0). O(n²) calls of sim.
Example:
  (similarity-graph vecs cosine-similarity 0.2)
```

### `sparse->alist`

```
Syntax: (sparse->alist v)
Library: (scm data cluster)
Description: The entries ((key . value) …), in no particular order.
Example:
  (sparse->alist (make-sparse '((a . 2)))) => ((a . 2))
```

### `sparse-dot`

```
Syntax: (sparse-dot a b)
Library: (scm data cluster)
Description: The dot product of two sparse vectors.
Example:
  (sparse-dot (make-sparse '((x . 2))) (make-sparse '((x . 3) (y . 1)))) => 6
```

### `sparse-keys`

```
Syntax: (sparse-keys v)
Library: (scm data cluster)
Description: The keys with a non-zero value, in no particular order.
Example:
  (sparse-keys (make-sparse '((a . 1) (b . 0)))) => (a)
```

### `sparse-norm`

*(no documentation)*

### `sparse-ref`

```
Syntax: (sparse-ref v key)
Library: (scm data cluster)
Description: The value of key in sparse vector v, 0 when absent.
Example:
  (sparse-ref (make-sparse '((a . 1))) 'b) => 0
```

### `sparse-sum`

*(no documentation)*

### `sparse?`

*(no documentation)*

### `weighted-jaccard-similarity`

```
Syntax: (weighted-jaccard-similarity a b)
Library: (scm data cluster)
Description: Σ min(a_k, b_k) / Σ max(a_k, b_k) over all keys (Ruzicka
  similarity; for counts or shares, non-negative).
Example:
  (weighted-jaccard-similarity (make-sparse '((x . 1))) (make-sparse '((x . 3)))) => 0.25
```


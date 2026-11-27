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

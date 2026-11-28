---
title: "(scm data cluster): similarity and clustering"
part: libraries
order: 1040
libraries: (scm data cluster)
summary: Describing things by sparse vectors of counts, cosine and Jaccard similarity, similarity graphs and k-nearest-neighbour graphs, communities with Louvain, hierarchical clustering and cutting the tree, k-means on measurements, judging a clustering with silhouettes, comparing two clusterings; customer segments from purchases.
---
# (scm data cluster): similarity and clustering

Clustering finds groups of similar things without being told the groups:
customers who buy alike, products bought together, hospitals with
similar case mixes. `(scm data cluster)` has the parts:

- **Describing:** sparse vectors.
- **Comparing:** cosine and Jaccard similarity.
- **Grouping:**
  - graphs with Louvain communities;
  - hierarchical clustering;
  - k-means.
- **Judging the result:** silhouettes and the adjusted Rand index.

```scheme
(import (scheme base) (scheme cxr) (scheme write) (scm data cluster))

(define (round3 x) (/ (round (* 1000 x)) 1000))
```

## Things as vectors

Each customer is described by what they bought: a *sparse vector* from
tea to kilograms, which stores only the teas a customer actually bought:

```scheme
(define purchases
  '(("ada"    (sencha . 4) (gyokuro . 2) (matcha . 1))
    ("alan"   (sencha . 3) (matcha . 2) (bancha . 1))
    ("grace"  (assam . 5) (darjeeling . 2))
    ("edsger" (assam . 3) (ceylon . 2) (darjeeling . 1))
    ("barbara" (rooibos . 4) (chamomile . 2))
    ("donald" (rooibos . 2) (chamomile . 3) (sencha . 1))))

(define names (map car purchases))
(define vecs (map (lambda (p) (make-sparse (cdr p))) purchases))

(sparse-ref (car vecs) 'sencha)             ;; => 4
(sparse-ref (car vecs) 'assam)              ;; => 0
```

## Similarity

*Cosine similarity* compares the direction of two vectors, so a customer
who buys a lot and one who buys a little of the same teas are similar.
*Jaccard similarity* compares only which teas, not how much:

```scheme
(define (sim a b) (cosine-similarity (list-ref vecs a) (list-ref vecs b)))
(round3 (sim 0 1))                          ;; => 0.816
(round3 (sim 0 2))                          ;; => 0.0
(round3 (sim 4 5))                          ;; => 0.837
(round3 (jaccard-similarity (list-ref vecs 0) (list-ref vecs 1))) ;; => 0.5
```

1 means the same mix, 0 nothing in common. ada and alan share sencha and
matcha; ada and grace buy entirely different teas.

## Communities in a graph

A similarity graph links every pair of similar customers, weighted by
their similarity. Louvain finds *communities*, groups more strongly
linked inside than to each other:

```scheme
(define g (similarity-graph vecs cosine-similarity 0.1))
(define m (louvain g))
m                                           ;; => #(0 0 1 1 2 2)

(define (named groups) (map (lambda (members) (map (lambda (i) (list-ref names i)) members))
                            (vector->list groups)))
(named (membership-groups m))
;; => (("ada" "alan") ("grace" "edsger") ("barbara" "donald"))
```

Green-tea, black-tea and herbal customers. donald's one kilogram of
sencha links him a little to the green-tea group, not enough to move
him. A membership vector gives each item's cluster number, the largest
cluster first; `membership-groups` lists the members.

- The resolution (`(louvain g 1.5)`) controls the size: higher gives
  more, smaller communities.
- `'refine` makes sure every community is connected.
- With many items, `knn-graph` links each item to its k most similar
  ones only, which keeps the graph small and is often what makes
  communities visible.
- Louvain shuffles the order it visits the nodes in, with a fixed seed,
  so the result is the same on every run (`'seed n` picks another).

## Hierarchical clustering

Hierarchical clustering merges the two closest groups, again and again,
into a tree; cutting the tree gives any number of clusters. It works on
distances, here one minus the similarity:

```scheme
(define d (distance-matrix vecs (lambda (a b) (- 1 (cosine-similarity a b)))))
(define tree (hclust d 'average))

(cutree tree 3)                             ;; => #(0 0 1 1 2 2)
(cutree tree 2)                             ;; => #(0 0 1 1 0 0)
(map round3 (map caddr tree))               ;; => (0.156 0.163 0.184 0.888 1.0)
```

The heights of the merges show where the natural cut is: three merges
happen at small distances (within the groups), then a jump to 0.89 and 1
(between them). With two clusters, the herbal customers join the
green-tea ones, through donald's sencha. `cutree-height` cuts at a
distance instead of a count.

The linkage says how the distance between groups is measured:
`average` (the default), `complete`, `single`, or `ward`.

## k-means on measurements

For numeric measurements, k-means finds k centres and puts each point
with the nearest. Each customer: kilograms per month and average price
per kilogram:

```scheme
(define spend '(#(1.0 120) #(1.2 110) #(0.8 130) #(6.0 30) #(5.5 25) #(7.0 35)))

(define km (kmeans spend 2))
(car km)                                    ;; => #(0 0 0 1 1 1)
(map (lambda (c) (vector-map round3 c)) (cdr km)) ;; => (#(1.0 120.0) #(6.167 30.0))
```

A few kilograms of expensive tea, or a lot of cheap tea. The two columns
have very different ranges, and k-means measures plain distances, so
large-valued columns dominate: standardise them first (`zscore` from
`(scm data stats)`) when they should count equally.

## How good is a clustering?

The *silhouette* of an item compares its distance to its own cluster
with the distance to the nearest other one: near 1 it sits well, near 0
it is on a border, below 0 it is probably in the wrong cluster:

```scheme
(define s3 (silhouette d (cutree tree 3)))
(define s2 (silhouette d (cutree tree 2)))
(round3 (car s3))                           ;; => 0.817
(round3 (car s2))                           ;; => 0.515
```

The mean silhouette prefers three clusters here. The *adjusted Rand
index* measures how far two clusterings agree, whatever their numbers
(1 the same, about 0 no better than chance):

```scheme
(adjusted-rand-index m (cutree tree 3))     ;; => 1.0
(round3 (adjusted-rand-index (cutree tree 2) (cutree tree 3))) ;; => 0.444
```

Louvain and the tree found the same three groups, which is reassuring:
a structure that different methods agree on is more likely real.

## Where next

- [Data frames](scm-data.md) and [statistics](scm-data-stats.md) to
  build the vectors from data and describe the clusters;
  [charts](scm-data-plot.md) to show them.
- Reference: `(scm data cluster)`.

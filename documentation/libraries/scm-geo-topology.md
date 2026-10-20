# `(scm geo topology)`

Planar graphs of polygon layers — overlay, dissolve, gap and sliver cleanup

## Overview

`(scm geo topology)` builds the planar graph of one or more layers of polygon
features: every ring is cut at every crossing and wherever a vertex of another
ring touches it, edges that coincide are stored once, and the faces the edges
enclose are found. Each face knows which features cover it, from whichever
layer.

Most polygon operations are then a matter of giving each face a key and
tracing the borders between faces of different keys with
`planar-graph-dissolve`:

| Operation | Key of a face |
|---|---|
| dissolve by an attribute | the attribute of the feature covering it |
| overlay (union) of two layers | the pair of features covering it |
| clip | a key only where the clipping layer covers it |
| clean overlaps | one of the features covering it |

`planar-graph-merge-faces!` gives faces (gaps, slivers, overlaps) to the
neighbour they share the longest border with. Faces with the same key merge;
faces with different keys share their borders vertex for vertex, so the
result has no gaps or overlaps and `(scm geo topojson)` stores each border
once.

## Common uses

```scheme
(import (scm geo) (scm geo topology))

;; municipalities dissolved into cantons
(define g (make-planar-graph (list municipalities)))
(planar-graph-dissolve g
  (lambda (face)
    (let ((fs (planar-graph-face-features g face)))
      (and (pair? fs) (feature-ref (car fs) "canton")))))
;; => ((1 . rings) (2 . rings) ...)
```

`make-planar-graph` takes `'((snap . distance))` to merge vertices closer
than that, and `'((progress . #t))` to report its steps on large inputs.


## Exports

### `make-planar-graph`

```
Syntax: (make-planar-graph layers [options])
Library: (scm geo topology)
Description: Builds the planar graph of the polygon features in layers, a list
  of lists of features (see (scm geo)). Rings are cut at every crossing and at
  every vertex that lies on another ring, coinciding edges are merged, and the
  faces they enclose are found; each face knows the features covering it.
  options is an alist: (snap . distance) merges vertices closer than distance
  and lets a vertex split an edge that passes closer than that; the default is
  a billionth of the extent of the data, enough to absorb rounding.
  (progress . #t) reports each step and its time on the error port.
  Face 0 is the face outside every ring.
Example:
  (planar-graph-face-count
    (make-planar-graph (list (list (make-feature '() (make-polygon (list #(0 0 2 0 2 2 0 2 0 0))))
                                   (make-feature '() (make-polygon (list #(1 1 3 1 3 3 1 3 1 1))))))))
  => 4
```

### `planar-graph-components`

```
Syntax: (planar-graph-components graph keys)
Library: (scm geo topology)
Description: keys is a vector with one key per face of graph, as for
  planar-graph-dissolve. Returns a vector with one number per face naming the
  connected part it belongs to: faces with equal keys (equal?) that share a
  border are in the same part. Faces with key #f get -1. With
  planar-graph-face-area this tells the size of each part of a dissolved
  region, to find its slivers.
Example:
  (planar-graph-components g (vector #f 'a 'a 'b)) => #(-1 1 1 3)
```

### `planar-graph-dissolve`

```
Syntax: (planar-graph-dissolve graph keys)
Library: (scm geo topology)
Description: Merges the faces of graph by key and returns an alist from each key
  to the rings outlining its faces (outer rings counter-clockwise, holes
  clockwise), in order of first appearance. keys is a vector with one key per
  face, or a procedure from face to key; keys are compared with equal?, and
  faces with key #f are left out. Faces with the same key share no border in
  the result, faces with different keys share their borders exactly: the
  rings use the same vertices on both sides.
Example:
  (planar-graph-dissolve g (lambda (f) (and (pair? (planar-graph-face-features g f)) 'all)))
  => ((all #(0 0 2 0 2 1 3 1 3 3 1 3 1 2 0 2 0 0)))
```

### `planar-graph-face-area`

```
Syntax: (planar-graph-face-area graph face)
Library: (scm geo topology)
Description: Returns the area of face of graph, without the holes in it. Face 0,
  the outside, has area 0.
Example:
  (planar-graph-face-area g 1) => 3.0
```

### `planar-graph-face-count`

*(no documentation)*

### `planar-graph-face-features`

```
Syntax: (planar-graph-face-features graph face)
Library: (scm geo topology)
Description: Returns the features covering face of graph, in the order of the
  layers and features given to make-planar-graph: none for face 0, the
  outside, and for gaps; more than one where features overlap.
Example:
  (planar-graph-face-features g 1) => (#<feature>)
```

### `planar-graph-face-neighbours`

```
Syntax: (planar-graph-face-neighbours graph face)
Library: (scm geo topology)
Description: Returns the faces bordering face of graph as an alist from face to
  the length of the border they share.
Example:
  (planar-graph-face-neighbours g 1) => ((0 . 6.0) (2 . 2.0))
```

### `planar-graph-merge-faces!`

```
Syntax: (planar-graph-merge-faces! graph keys merge?)
Library: (scm geo topology)
Description: keys is a vector with one key per face of graph, as for
  planar-graph-dissolve. Gives every face for which (merge? face) is true the
  key of the neighbour it shares the longest border with, among the neighbours
  with a key other than #f that are not to be merged themselves, repeating
  until no more faces can be given a key; this fills gaps and removes slivers.
  Returns keys, which is modified.
Example:
  (planar-graph-merge-faces! g keys (lambda (f) (< (planar-graph-face-area g f) 10))) => #(...)
```

### `planar-graph?`

*(no documentation)*


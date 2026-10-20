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

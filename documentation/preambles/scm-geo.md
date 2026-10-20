## Overview

`(scm geo)` is the base of the geo libraries: features (a geometry with
properties), polygon rings and the planar geometry done on them. Coordinates
are plain numbers in any planar system (metres in a national grid, say);
nothing is projected.

- A **feature** is made with `make-feature` from an alist of properties
  (string keys, as `(scm json simple)` uses) and a geometry.
- A **geometry** is a tagged list: `(polygon ring ...)`, `(polyline path ...)`
  or `(multipoint point ...)`, made with `make-polygon`, `make-polyline` and
  `make-multipoint`.
- A **ring** or path is a flat vector of coordinates `#(x0 y0 x1 y1 ...)`; a
  ring is closed, its last point equal to its first. A polygon's rings may come
  in any order and orientation: the area inside an odd number of them is the
  polygon. `rings->polygons` sorts them into outer rings and holes.

## Common uses

```scheme
(import (scm geo))

(define ring #(0 0 4 0 4 4 0 4 0 0))
(ring-area ring)                        ;; => 16.0, positive: counter-clockwise
(point-in-ring? 1 1 ring)               ;; => #t
(path-simplify #(0 0 1 0.1 2 0) 0.5)    ;; => #(0 0 2 0), Douglas-Peucker
(polygon-inner-point (list ring))       ;; => #(2.0 2.0), a label point
```

`features->geojson` and `geojson->features` convert to and from GeoJSON in
the representation of `(scm json simple)`. Shapefiles are read with
`(scm geo shapefile)`, overlays and dissolves are done with
`(scm geo topology)`, and `(scm geo topojson)` writes the result.

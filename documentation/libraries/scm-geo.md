# `(scm geo)`

Planar geometry of features — rings, areas, simplification, label points, GeoJSON

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


## Exports

### `bbox-overlap?`

```
Syntax: (bbox-overlap? a b)
Library: (scm geo)
Description: Returns #t when the bounding boxes a and b overlap or touch.
Example:
  (bbox-overlap? #(0 0 1 1) #(1 1 2 2)) => #t
```

### `bbox-union`

```
Syntax: (bbox-union a b)
Library: (scm geo)
Description: Returns the smallest bounding box containing the bounding boxes a
  and b; either may be #f, meaning empty.
Example:
  (bbox-union #(0 0 1 1) #(2 -1 3 0)) => #(0 -1 3 1)
```

### `feature-geometry`

*(no documentation)*

### `feature-properties`

*(no documentation)*

### `feature-ref`

```
Syntax: (feature-ref feature key [default])
Library: (scm geo)
Description: Returns the value of the property named key (a string) of feature,
  or default (#f when omitted) when the feature has no such property. A
  property that is present but empty holds the symbol null.
Example:
  (feature-ref (make-feature '(("name" . "Bern")) (make-polygon '())) "name") => "Bern"
```

### `feature-rings`

```
Syntax: (feature-rings feature)
Library: (scm geo)
Description: Returns the rings of feature's polygon geometry, or the empty list
  when its geometry is not a polygon.
Example:
  (feature-rings (make-feature '() (make-polygon (list #(0 0 1 0 1 1 0 0))))) => (#(0 0 1 0 1 1 0 0))
```

### `feature?`

*(no documentation)*

### `features->geojson`

```
Syntax: (features->geojson features)
Library: (scm geo)
Description: Returns a GeoJSON FeatureCollection of features, as data for
  (scm json simple): write it with json->string. Polygons have their outer
  rings counter-clockwise and their holes clockwise (RFC 7946).
Example:
  (json->string (features->geojson (list (make-feature '(("id" . 1)) (make-multipoint (list #(1 2)))))))
  => "{\"type\":\"FeatureCollection\",\"features\":[...]}"
```

### `geojson->features`

```
Syntax: (geojson->features json)
Library: (scm geo)
Description: Returns the features of json, a GeoJSON FeatureCollection as
  parsed by (scm json simple). Features without geometry are skipped.
Example:
  (length (geojson->features (json-parse "{\"type\":\"FeatureCollection\",\"features\":[]}"))) => 0
```

### `geometry-parts`

```
Syntax: (geometry-parts geometry)
Library: (scm geo)
Description: Returns the parts of geometry: the rings of a polygon, the paths
  of a polyline, the points of a multipoint.
Example:
  (geometry-parts (make-multipoint (list #(1 2)))) => (#(1 2))
```

### `geometry-type`

```
Syntax: (geometry-type geometry)
Library: (scm geo)
Description: Returns the type of geometry: one of the symbols polygon,
  polyline or multipoint.
Example:
  (geometry-type (make-polyline '())) => polyline
```

### `make-feature`

*(no documentation)*

### `make-multipoint`

```
Syntax: (make-multipoint points)
Library: (scm geo)
Description: Returns a point geometry made of points, a list of vectors #(x y).
Example:
  (geometry-type (make-multipoint (list #(1 2)))) => multipoint
```

### `make-polygon`

```
Syntax: (make-polygon rings)
Library: (scm geo)
Description: Returns a polygon geometry made of rings, a list of closed rings,
  each a flat vector #(x0 y0 x1 y1 ... x0 y0). Outer rings and holes may come
  in any order; the area inside an odd number of rings is the polygon.
Example:
  (geometry-type (make-polygon (list #(0 0 1 0 1 1 0 0)))) => polygon
```

### `make-polyline`

```
Syntax: (make-polyline paths)
Library: (scm geo)
Description: Returns a polyline geometry made of paths, a list of flat
  coordinate vectors #(x0 y0 x1 y1 ...).
Example:
  (geometry-parts (make-polyline (list #(0 0 5 5)))) => (#(0 0 5 5))
```

### `path-dp-thresholds`

```
Syntax: (path-dp-thresholds path)
Library: (scm geo)
Description: Returns a vector with one Douglas-Peucker removal threshold per
  point of path, a flat coordinate vector: simplifying to a tolerance keeps
  the points whose threshold exceeds it, and the points marked -1 always (the
  ends). Thresholds never grow down the split tree, so this gives exactly what
  Douglas-Peucker gives at that tolerance. A closed path (first point equal to
  last) is first split at the point farthest from its start, which is kept
  like an end, so a ring never collapses to a line.
Example:
  (path-dp-thresholds #(0 0 1 1 2 0)) => #(-1 1 -1)
```

### `path-simplify`

```
Syntax: (path-simplify path tolerance [thresholds])
Library: (scm geo)
Description: Returns path, a flat coordinate vector, simplified with
  Douglas-Peucker to tolerance: every point removed lies within tolerance of
  the simplified line. thresholds, as returned by path-dp-thresholds, saves
  computing them again.
Example:
  (path-simplify #(0 0 1 0.1 2 0) 0.5) => #(0 0 2 0)
```

### `point-in-ring?`

```
Syntax: (point-in-ring? x y ring)
Library: (scm geo)
Description: Returns #t when the point (x, y) lies inside ring (even-odd rule).
  A point exactly on the boundary may count as either.
Example:
  (point-in-ring? 1 1 #(0 0 2 0 2 2 0 2 0 0)) => #t
```

### `point-in-rings?`

```
Syntax: (point-in-rings? x y rings)
Library: (scm geo)
Description: Returns #t when the point (x, y) lies inside an odd number of
  rings, that is inside the polygon they make up.
Example:
  (point-in-rings? 1.5 1.5 (list #(0 0 4 0 4 4 0 4 0 0) #(1 1 1 2 2 2 2 1 1 1))) => #f
```

### `polygon-inner-point`

```
Syntax: (polygon-inner-point rings [precision])
Library: (scm geo)
Description: Returns a point #(x y) inside the polygon made of rings that lies
  as far from its boundary as possible, to within precision (by default a
  thousandth of the polygon's larger side): the pole of inaccessibility, a
  good place for a label. Uses a quadtree search (the polylabel algorithm).
Example:
  (polygon-inner-point (list #(0 0 4 0 4 4 0 4 0 0)) 0.01) => #(2 2)
```

### `ring-area`

```
Syntax: (ring-area ring)
Library: (scm geo)
Description: Returns the signed planar area of ring, a closed flat coordinate
  vector: positive when the ring runs counter-clockwise (with y pointing up),
  negative when it runs clockwise.
Example:
  (ring-area #(0 0 2 0 2 2 0 2 0 0)) => 4.0
```

### `ring-bbox`

```
Syntax: (ring-bbox ring)
Library: (scm geo)
Description: Returns the bounding box of ring (or of any flat coordinate
  vector) as #(xmin ymin xmax ymax).
Example:
  (ring-bbox #(0 0 3 1 1 2 0 0)) => #(0 0 3 2)
```

### `ring-groups`

```
Syntax: (ring-groups rings)
Library: (scm geo)
Description: Groups rings into polygons as rings->polygons does, but returns
  the rings by position: a list of polygons, each a list of pairs (index .
  reverse?), the outer ring first, where index is the position of the ring in
  rings and reverse? tells whether it runs the wrong way (outer rings
  counter-clockwise, holes clockwise).
Example:
  (ring-groups (list #(0 0 4 0 4 4 0 4 0 0) #(1 1 2 1 2 2 1 2 1 1))) => (((0 . #f) (1 . #t)))
```

### `ring-point-count`

```
Syntax: (ring-point-count ring)
Library: (scm geo)
Description: Returns the number of points in ring (or in any flat coordinate
  vector), counting a closed ring's last point, which repeats its first.
Example:
  (ring-point-count #(0 0 1 0 1 1 0 0)) => 4
```

### `ring-reverse`

```
Syntax: (ring-reverse ring)
Library: (scm geo)
Description: Returns ring with its points in the opposite order.
Example:
  (ring-reverse #(0 0 1 0 1 1 0 0)) => #(0 0 1 1 1 0 0 0)
```

### `rings->polygons`

```
Syntax: (rings->polygons rings)
Library: (scm geo)
Description: Groups rings into polygons and returns a list of them, each a
  list whose first ring is the outer ring and whose other rings are its holes.
  Outer rings are made counter-clockwise and holes clockwise; a hole goes to
  the smallest outer ring that contains it. Rings without area are dropped.
Example:
  (length (rings->polygons (list #(0 0 4 0 4 4 0 4 0 0) #(1 1 2 1 2 2 1 2 1 1)))) => 1
```

### `rings-area`

```
Syntax: (rings-area rings)
Library: (scm geo)
Description: Returns the area enclosed by rings, outer rings counted positive
  and holes negative whatever their orientation: the absolute area of a ring
  inside an even number of other rings is added, the others subtracted.
Example:
  (rings-area (list #(0 0 4 0 4 4 0 4 0 0) #(1 1 1 2 2 2 2 1 1 1))) => 15.0
```

### `rings-bbox`

```
Syntax: (rings-bbox rings)
Library: (scm geo)
Description: Returns the bounding box of a list of rings, or #f when the list
  is empty.
Example:
  (rings-bbox (list #(0 0 1 0 0 0) #(5 5 6 6 5 5))) => #(0 0 6 6)
```


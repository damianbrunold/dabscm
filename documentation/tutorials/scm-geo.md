---
title: "(scm geo): features, polygons, shapefiles and TopoJSON"
part: libraries
order: 1042
libraries: (scm geo) (scm geo shapefile) (scm geo topology) (scm geo topojson)
summary: Features with properties and geometries, rings as coordinate vectors, areas, bounding boxes, point in polygon, holes, label points, simplification; GeoJSON in and out; reading shapefiles, also from ZIP archives; dissolving municipalities into regions with a planar graph; writing compact TopoJSON with shared borders.
---
# (scm geo): features, polygons, shapefiles and TopoJSON

The geo libraries handle the maps behind statistics: municipalities,
cantons, sales regions.

| library | does |
|---|---|
| `(scm geo)` | features, polygons, areas, point in polygon, GeoJSON |
| `(scm geo shapefile)` | reads ESRI shapefiles |
| `(scm geo topology)` | dissolves, overlays and cleans polygon layers |
| `(scm geo topojson)` | reads and writes TopoJSON, with shared borders stored once |

Coordinates are plain planar numbers: metres in a national grid such as
the Swiss LV95, or longitude and latitude. Nothing is projected. To draw
maps, see [charts and maps](scm-data-plot.md).

```scheme
(import (scheme base) (scheme write) (scm json simple)
        (scm geo) (scm geo topology) (scm geo topojson))
```

## Rings and polygons

A ring is a flat vector of coordinates, `#(x0 y0 x1 y1 …)`, closed by
repeating the first point. Here a helper for squares, `box`:

```scheme
(define (box x y side)
  (vector x y (+ x side) y (+ x side) (+ y side) x (+ y side) x y))

(define plot (box 0 0 1000))             ; a 1 km square
(ring-area plot)                            ;; => 1000000.0
(ring-area (ring-reverse plot))             ;; => -1000000.0
(ring-bbox plot)                            ;; => #(0 0 1000 1000)
(point-in-ring? 500 250 plot)               ;; => #t
(point-in-ring? 1500 250 plot)              ;; => #f
```

The sign of the area tells the orientation: positive for
counter-clockwise rings. A polygon is a list of rings, and a point is
inside when it is inside an odd number of them, so an inner ring is a
hole:

```scheme
(define park (make-polygon (list (box 0 0 10) (box 3 3 4))))   ; a lake in the middle
(geometry-type park)                        ;; => polygon
(rings-area (geometry-parts park))          ;; => 84.0
(point-in-rings? 1 1 (geometry-parts park)) ;; => #t
(point-in-rings? 5 5 (geometry-parts park)) ;; => #f
(polygon-inner-point (list (box 0 0 1000))) ;; => #(500.0 500.0)
```

`polygon-inner-point` finds a point well inside a polygon, the place
for a label (the centre of a U-shaped region lies outside it).
`path-simplify` drops points that lie within a tolerance of the line
(Douglas-Peucker), for smaller files and faster maps:

```scheme
(path-simplify #(0 0 1 0.1 2 0 3 5) 0.5)    ;; => #(0 0 2 0 3 5)
```

## Features and GeoJSON

A feature is a geometry with properties, keyed by strings as in JSON:

```scheme
(define municipalities
  (list (make-feature '(("name" . "Aach") ("region" . "North")) (make-polygon (list (box 0 1000 1000))))
        (make-feature '(("name" . "Bühl") ("region" . "North")) (make-polygon (list (box 1000 1000 1000))))
        (make-feature '(("name" . "Calw") ("region" . "South")) (make-polygon (list (box 0 0 1000))))
        (make-feature '(("name" . "Dorf") ("region" . "South")) (make-polygon (list (box 1000 0 1000))))))

(feature-ref (car municipalities) "name")   ;; => "Aach"
(feature-geometry (car municipalities))     ;; => (polygon #(0 1000 1000 1000 1000 2000 0 2000 0 1000))
```

`features->geojson` and `geojson->features` convert to and from GeoJSON
in the form of `(scm json simple)`:

```scheme
(define gj (features->geojson (list (car municipalities))))
(json->string gj)
;; => "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"name\":\"Aach\",\"region\":\"North\"},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[0,1000],[1000,1000],[1000,2000],[0,2000],[0,1000]]]}}]}"
(map (lambda (f) (feature-ref f "name")) (geojson->features (json-parse (json->string gj)))) ;; => ("Aach")
```

## Shapefiles

Official boundaries usually come as shapefiles: a `.shp` file with the
geometries, a `.dbf` table with the attributes and a `.cpg` naming its
character set.

```scheme no-test
(import (scm geo shapefile) (scm zip))

(define cantons (read-shapefile "swissBOUNDARIES3D_1_5_TLM_KANTONSGEBIET.shp"))
(map (lambda (f) (feature-ref f "NAME")) cantons)   ; => ("Zürich" "Bern" ...)

;; straight from the downloaded ZIP, without unpacking it
(define cantons2
  (call-with-input-zip "boundaries.zip"
    (lambda (z)
      (shapefile->features (zip-read-entry-bytevector z "cantons.shp")
                           (zip-read-entry-bytevector z "cantons.dbf")
                           'utf-8))))
```

`read-sf` in `(scm data io)` reads the same files into a data frame.

## Dissolving with a planar graph

Statistics are often needed for regions that are made of smaller units:
cantons from municipalities, sales regions from postcodes. Merging the
polygons naively leaves slivers and double borders. `(scm geo topology)`
builds the planar graph of the layer, the *faces* between all edges,
and traces the borders between faces with different keys:

```scheme
(define g (make-planar-graph (list municipalities)))
(planar-graph-face-count g)                 ;; => 5

(define regions
  (planar-graph-dissolve g
    (lambda (face)
      (let ((fs (planar-graph-face-features g face)))
        (and (pair? fs) (feature-ref (car fs) "region"))))))

(map car regions)                           ;; => ("North" "South")
(map (lambda (r) (rings-area (cdr r))) regions) ;; => (2000000.0 2000000.0)
```

The five faces are the four squares plus the outside, which no feature
covers and which gets the key `#f`. Each result is a key with its rings;
the inner border between Aach and Bühl is gone:

```scheme
(cdr (car regions))
;; => (#(0.0 1000.0 1000.0 1000.0 2000.0 1000.0 2000.0 2000.0 1000.0 2000.0 0.0 2000.0 0.0 1000.0))
```

The key procedure decides the operation:

- a dissolve uses an attribute;
- an overlay of two layers uses the pair of features covering a face;
- a clip gives a key only where the clipping layer is.

`planar-graph-merge-faces!` hands gaps and slivers to the neighbour
they share the longest border with, and `'((snap . 0.01))` merges
vertices closer than a tolerance, for layers digitised separately.

## TopoJSON

In GeoJSON every border between two neighbours is stored twice, once
for each. TopoJSON stores it once as an *arc* that both polygons refer
to, so the file is smaller and simplifying it leaves no gaps between
neighbours:

```scheme
(define topo (features->topojson (list (cons "municipalities" municipalities))))
(topojson-layers topo)                      ;; => ("municipalities")
(vector-length (cdr (assoc "arcs" topo)))   ;; => 8
(map (lambda (f) (feature-ref f "name")) (topojson->features topo "municipalities"))
;; => ("Aach" "Bühl" "Calw" "Dorf")
```

Four squares have 16 sides but only 8 distinct borders. Options make the
file smaller still: `(simplify . tolerance)` simplifies each arc once
for both sides, `(quantization . 100000)` writes integer coordinates on
a grid. A file with several layers (municipalities and cantons) shares
borders between the layers too.

```scheme no-test
(call-with-output-file "regions.topo.json"
  (lambda (p)
    (write-string (json->string (features->topojson (list (cons "municipalities" municipalities))
                                                     '((simplify . 20) (quantization . 100000))))
                  p)))
```

## Where next

- [Charts and maps](scm-data-plot.md) to draw them,
  [reading and writing data](scm-data-io.md#geometries) for frames with
  geometries, [JSON](scm-json.md).
- Reference: `(scm geo)`, `(scm geo shapefile)`, `(scm geo topology)`,
  `(scm geo topojson)`.

# `(scm geo topojson)`

TopoJSON: writing with shared arcs, simplification and quantization; reading

## Overview

`(scm geo topojson)` reads TopoJSON (`topojson->features`, one layer at a
time, `topojson-layers` for their names) and writes polygon features as a
TopoJSON topology: every
border shared by two rings, in one layer or across layers, is stored once as
an arc that both rings refer to. Borders are matched by exactly equal
coordinates, as `(scm geo topology)` produces them.

Options:

- `(simplify . tolerance)`: Douglas-Peucker on each arc. A shared arc is
  simplified once for both sides, so neighbours stay gap-free; rings that
  would collapse keep enough points to remain polygons.
- `(quantization . n)`: integer coordinates on an n by n grid, delta-encoded,
  with a `transform`.
- `(thresholds . name)` and `(threshold-scale . factor)`: a member with each
  point's Douglas-Peucker removal threshold, so a reader can simplify further
  to any tolerance in one pass.

## Common uses

```scheme
(import (scm json simple) (scm geo topojson))

(call-with-output-file "cantons.topo.json"
  (lambda (p)
    (write-string
     (json->string
      (features->topojson (list (cons "cantons" cantons))
                          '((simplify . 20) (quantization . 100000))))
     p)))
```


## Exports

### `features->topojson`

```
Syntax: (features->topojson layers [options])
Library: (scm geo topojson)
Description: Returns a TopoJSON topology of the polygon features in layers, an
  alist from layer name (a string) to a list of features, as data for (scm
  json simple): write it with json->string. Each layer becomes a
  GeometryCollection of Polygon and MultiPolygon geometries with the
  features' properties; borders shared by rings, within a layer or across
  layers, are stored once as shared arcs. Outer rings run clockwise, holes
  counter-clockwise, as TopoJSON tools expect. options is an alist:
  (simplify . tolerance) simplifies every arc with Douglas-Peucker, shared
  arcs once for both sides, so neighbours stay gap-free; rings that would
  collapse keep enough points to stay polygons. (quantization . n) quantizes
  coordinates to an n by n grid and delta-encodes the arcs, adding a
  transform. (thresholds . name) adds a member name with, per arc, the
  Douglas-Peucker removal threshold of each point after quantization (-1 for
  the ends, which are always kept; see path-dp-thresholds), multiplied by
  (threshold-scale . factor), 1 by default, and rounded: with it a reader
  simplifies any arc to any tolerance in one pass.
Example:
  (json->string (features->topojson (list (cons "cantons" features))
                                    '((simplify . 20) (quantization . 100000))))
```

### `topojson->features`

```
Syntax: (topojson->features json [layer])
Library: (scm geo topojson)
Description: The features of one object (layer) of a TopoJSON topology,
  json as parsed by (scm json simple), by default the first: arcs are
  decoded (with the transform, when quantized) and stitched into rings
  and paths; a MultiPolygon becomes one polygon with all its rings.
  Properties are those of the geometries, plus "id" from their id.
Example:
  (topojson->features (json-parse text) "cantons")
```

### `topojson-layers`

```
Syntax: (topojson-layers json)
Library: (scm geo topojson)
Description: The names of the objects (layers) of a TopoJSON topology,
  json as parsed by (scm json simple).
Example:
  (topojson-layers (json-parse text)) => ("cantons" "lakes")
```


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

# `(scm raster)`

Anti-aliased 2D rasterization — paths, fills, strokes, dashes, PNG output

## Exports

### `canvas->png`

```
Syntax: (canvas->png canvas)
Library: (scm raster)
Description: Encodes the canvas as a PNG (RGBA) and returns the bytes as a
  bytevector.
Example:
  (canvas->png (make-canvas 10 10 (rgba 255 255 255)))
```

### `canvas-fill-path!`

```
Syntax: (canvas-fill-path! canvas path paint [options])
Library: (scm raster)
Description: Fills path with paint, anti-aliased. paint is a colour from
  rgba, or a procedure (lambda (x y) ...) returning one for the pixel
  centre x, y (for gradients and patterns). options is an alist:
  (transform . m) applies the transform m to the path; (fill-rule .
  evenodd) or (fill-rule . nonzero), the default; (opacity . a)
  multiplies the paint's alpha by a.
Example:
  (canvas-fill-path! c (path-circle 50 50 20) (rgba 200 0 0))
  (canvas-fill-path! c path (rgba 0 0 0) '((fill-rule . evenodd)))
```

### `canvas-height`

*(no documentation)*

### `canvas-pixels`

*(no documentation)*

### `canvas-ref`

```
Syntax: (canvas-ref canvas x y)
Library: (scm raster)
Description: Returns the pixel at column x, row y as a list (r g b a) of
  integers from 0 to 255.
Example:
  (canvas-ref (make-canvas 1 1 (rgba 255 0 0)) 0 0) => (255 0 0 255)
```

### `canvas-stroke-path!`

```
Syntax: (canvas-stroke-path! canvas path paint [options])
Library: (scm raster)
Description: Strokes path with paint, anti-aliased. options is an alist:
  (width . w), default 1; (join . miter|round|bevel), default miter;
  (cap . butt|round|square), default butt; (miter-limit . l), default 4;
  (dash . (on off ...)) and (dash-offset . o) for dashed lines;
  (transform . m), which also scales the width; (opacity . a).
Example:
  (canvas-stroke-path! c '((M 10 10) (L 90 90)) (rgba 0 0 0)
                       '((width . 2) (cap . round)))
```

### `canvas-width`

*(no documentation)*

### `canvas?`

*(no documentation)*

### `make-canvas`

```
Syntax: (make-canvas width height [background])
Library: (scm raster)
Description: Returns a new canvas of width x height pixels, filled with
  the colour background (from rgba), or transparent without one.
Example:
  (make-canvas 200 100 (rgba 255 255 255))
```

### `path-circle`

```
Syntax: (path-circle cx cy r)
Library: (scm raster)
Description: Returns a closed path for the circle centred on cx, cy with
  radius r.
Example:
  (path-circle 50 50 10)
```

### `path-ellipse`

```
Syntax: (path-ellipse cx cy rx ry)
Library: (scm raster)
Description: Returns a closed path for the ellipse centred on cx, cy with
  radii rx and ry, as four cubic arcs.
Example:
  (path-ellipse 50 50 40 20)
```

### `path-polyline`

```
Syntax: (path-polyline points [closed?])
Library: (scm raster)
Description: Returns a path through points, a list of pairs (x . y),
  closed when closed? is true.
Example:
  (path-polyline '((0 . 0) (10 . 0) (10 . 10)) #t)
```

### `path-rect`

```
Syntax: (path-rect x y w h [rx [ry]])
Library: (scm raster)
Description: Returns a closed path for the rectangle at x, y of size w x
  h, with corners rounded by rx and ry (ry defaults to rx), each limited to
  half the side as in SVG.
Example:
  (path-rect 0 0 100 50)
  (path-rect 0 0 100 50 4)
```

### `rgba`

```
Syntax: (rgba r g b [a])
Library: (scm raster)
Description: Returns a colour usable as paint: r, g and b are integers from
  0 to 255, a is the opacity from 0.0 to 1.0 (default 1.0).
Example:
  (rgba 42 120 214)       ; opaque blue
  (rgba 0 0 0 0.1)        ; a light shade
```

### `transform-apply`

```
Syntax: (transform-apply m x y)
Library: (scm raster)
Description: Returns the transformed point as a pair (x . y).
Example:
  (transform-apply (transform-scale 2 3) 1 1) => (2.0 . 3.0)
```

### `transform-identity`

```
Syntax: (transform-identity)
Library: (scm raster)
Description: Returns the identity transform. Transforms are vectors
  #(a b c d e f) mapping (x, y) to (a x + c y + e, b x + d y + f), as the
  SVG matrix() does.
Example:
  (transform-identity) => #(1.0 0.0 0.0 1.0 0.0 0.0)
```

### `transform-multiply`

```
Syntax: (transform-multiply m n)
Library: (scm raster)
Description: Returns the transform that applies n first, then m (the
  matrix product m * n).
Example:
  (transform-multiply (transform-translate 10 0) (transform-scale 2))
```

### `transform-rotate`

```
Syntax: (transform-rotate degrees)
Library: (scm raster)
Description: Returns a transform that rotates by degrees around the
  origin; positive turns the x axis towards the y axis (clockwise on a
  canvas, where y points down).
Example:
  (transform-apply (transform-rotate 90) 1 0) ; => approximately (0 . 1)
```

### `transform-scale`

```
Syntax: (transform-scale sx [sy])
Library: (scm raster)
Description: Returns a transform that scales by sx horizontally and sy
  vertically (sy defaults to sx).
Example:
  (transform-apply (transform-scale 2) 3 4) => (6.0 . 8.0)
```

### `transform-translate`

```
Syntax: (transform-translate tx ty)
Library: (scm raster)
Description: Returns a transform that moves by tx, ty.
Example:
  (transform-apply (transform-translate 5 1) 1 1) => (6.0 . 2.0)
```


# `(scm svg raster)`

SVG rendering to a raster canvas or PNG — shapes, paths, CSS, text, patterns

## Exports

### `svg->canvas`

```
Syntax: (svg->canvas svg [options])
Library: (scm svg raster)
Description: Renders svg, SVG text or an SXML tree (as (scm html builder)
  takes it), to a new canvas of (scm raster) and returns it. The canvas
  is the root's width and height (or its viewBox's size) times the scale.
  options is an alist: (scale . s), default 1; (background . colour), a
  colour from rgba, transparent by default; (fonts . ((normal . font)
  (bold . font))), fonts of (scm truetype), DejaVu Sans by default.
Example:
  (svg->canvas "<svg width='20' height='20'><circle cx='10' cy='10' r='8'/></svg>"
               '((scale . 2)))
```

### `svg->png`

```
Syntax: (svg->png svg [options])
Library: (scm svg raster)
Description: Renders svg like svg->canvas and returns it encoded as a PNG
  bytevector.
Example:
  (svg->png chart-sxml '((scale . 2) (background . #(255 255 255 1.0))))
```

### `svg-text->sxml`

```
Syntax: (svg-text->sxml text)
Library: (scm svg core)
Description: Parses SVG (or other simple XML) text into SXML, the tree
  shape svg->canvas accepts: (tag (@ (name "value") ...) child ...).
  Comments, the prolog, the doctype and processing instructions are
  dropped; entities are decoded.
Example:
  (svg-text->sxml "<svg width='10'><rect/></svg>")
  => (svg (@ (width "10")) (rect (@)))
```


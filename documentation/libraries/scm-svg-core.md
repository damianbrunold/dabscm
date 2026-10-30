# `(scm svg core)`

SVG parsing shared by the renderers — XML, CSS cascade, transforms, paths, paints

## Overview

The format-neutral half of the SVG renderers, shared by `(scm svg raster)`
(canvas, PNG) and `(scm svg pdf)` (PDF vectors): an XML reader to SXML, tree
accessors, number and transform parsing, path data (arcs become cubic
curves), CSS rules with the cascade (type, class and id selectors,
descendants, specificity), paints and the geometry of the basic shapes. Both
renderers support the same SVG subset, described in `(scm svg raster)`.

Programs normally use the renderers; this library is for writing another one.


## Exports

### `attr`

```
Syntax: (attr node name [default])
Library: (scm svg core)
Description: The value (a string) of attribute name of an SXML element, or
  default (#f).
Example:
  (attr '(rect (@ (x "5"))) 'x) => "5"
```

### `collapse-spaces`

```
Syntax: (collapse-spaces string)
Library: (scm svg core)
Description: Text as SVG lays it out: runs of whitespace become one space,
  leading and trailing whitespace removed.
Example:
  (collapse-spaces "  a \n b ") => "a b"
```

### `collect`

```
Syntax: (collect node rules ids ancestors)
Library: (scm svg core)
Description: Walks a document once before drawing: appends the rules of its
  style elements to (car rules), a one-element list used as a box, and
  records each element with an id in the hash table ids as (node .
  ancestors).
Example:
  (collect root (list '()) (make-hash-table equal?) '())
```

### `compute-style`

```
Syntax: (compute-style node parent-style rules ancestors)
Library: (scm svg core)
Description: The computed style of an element (an alist property -> value):
  the inherited properties of parent-style, then its presentation
  attributes, the matching rules by specificity and order, and its style
  attribute. ancestors is the list of element-info of its ancestors,
  nearest first.
Example:
  (compute-style node '() rules '())
```

### `el-attrs`

```
Syntax: (el-attrs node)
Library: (scm svg core)
Description: The attributes of an SXML element as an alist of symbol -> string
  (numbers and raw values converted, #f dropped).
Example:
  (el-attrs '(rect (@ (x 1) (y "2")))) => ((x . "1") (y . "2"))
```

### `el-children`

```
Syntax: (el-children node)
Library: (scm svg core)
Description: The children of an SXML element, with nested fragments spliced in
  and #f and () dropped, as (scm html builder) does.
Example:
  (el-children '(g (@) (rect) #f ((circle)))) => ((rect) (circle))
```

### `element-info`

```
Syntax: (element-info node)
Library: (scm svg core)
Description: An element's tag, id and classes, ("tag" id (class …)), as the
  selector matching takes them.
Example:
  (element-info '(rect (@ (class "a b")))) => ("rect" #f ("a" "b"))
```

### `element?`

*(no documentation)*

### `invert`

```
Syntax: (invert transform)
Library: (scm svg core)
Description: The inverse of a transform vector (the identity for a singular
  one).
Example:
  (invert (transform-scale 2)) => #(0.5 0.0 0.0 0.5 0.0 0.0)
```

### `length-attr`

```
Syntax: (length-attr node name default)
Library: (scm svg core)
Description: A length attribute as a number (percentages give default).
Example:
  (length-attr '(rect (@ (width "20"))) 'width 0) => 20.0
```

### `node-text`

```
Syntax: (node-text node)
Library: (scm svg core)
Description: The text content of an element: its strings, numbers and raw
  text, recursively.
Example:
  (node-text '(text "a" (tspan "b"))) => "ab"
```

### `number-or`

```
Syntax: (number-or string default)
Library: (scm svg core)
Description: The number at the start of string (an SVG length; units are
  ignored), or default when there is none or string is #f.
Example:
  (number-or "12px" 0) => 12.0
```

### `numbers`

```
Syntax: (numbers string)
Library: (scm svg core)
Description: The numbers in an SVG number list (separated by spaces or
  commas; exponents and signs allowed), as inexact numbers.
Example:
  (numbers "1,2 -3.5e2") => (1.0 2.0 -350.0)
```

### `option`

```
Syntax: (option alist key default)
Library: (scm svg core)
Description: The value of key in an options alist, or default.
Example:
  (option '((scale . 2)) 'scale 1) => 2
```

### `parse-css`

```
Syntax: (parse-css text)
Library: (scm svg core)
Description: The rules of a style sheet: (specificity order compounds .
  declarations) for each selector with type, class and id parts and
  descendant combinators; at-rule blocks and other selectors are skipped.
Example:
  (parse-css ".a{fill:red}")
```

### `parse-declarations`

```
Syntax: (parse-declarations string)
Library: (scm svg core)
Description: CSS declarations (a style attribute) as an alist of property ->
  value, both strings, !important dropped.
Example:
  (parse-declarations "fill: red; stroke:none") => (("fill" . "red") ("stroke" . "none"))
```

### `parse-paint`

```
Syntax: (parse-paint string)
Library: (scm svg core)
Description: A paint value: an rgba vector #(r g b a) (hex, rgb(), rgba(),
  named colours), none, (url . id), or #f when not understood.
Example:
  (parse-paint "#ff0000") => #(255 0 0 1.0)
```

### `parse-path-data`

```
Syntax: (parse-path-data string)
Library: (scm svg core)
Description: SVG path data as a list of absolute commands (M x y) (L x y)
  (Q x1 y1 x y) (C x1 y1 x2 y2 x y) (Z): relative commands resolved, H
  and V made lines, S and T reflected, arcs turned into cubic curves.
Example:
  (parse-path-data "M0 0 h10 v10 z") => ((M 0.0 0.0) (L 10.0 0.0) (L 10.0 10.0) (Z))
```

### `parse-transform`

```
Syntax: (parse-transform string)
Library: (scm svg core)
Description: An SVG transform attribute (matrix, translate, scale, rotate,
  skewX, skewY, in sequence) as a transform vector of (scm raster).
Example:
  (parse-transform "translate(10 5) scale(2)")
```

### `prop`

```
Syntax: (prop style name)
Library: (scm svg core)
Description: The value of property name (a string) in a computed style, or its
  initial value (fill black, stroke none, font-size 16 …), or #f.
Example:
  (prop '(("fill" . "red")) "stroke") => "none"
```

### `scale-factor`

```
Syntax: (scale-factor transform)
Library: (scm svg core)
Description: The geometric mean scale of a transform: the square root of its
  determinant's absolute value.
Example:
  (scale-factor (transform-scale 2 8)) => 4.0
```

### `shape-path`

```
Syntax: (shape-path node)
Library: (scm svg core)
Description: The outline of a basic shape (rect with rounded corners, circle,
  ellipse, line, polyline, polygon, path) as a path, or () when empty.
Example:
  (shape-path '(rect (@ (width "10") (height "5"))))
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

### `viewbox-transform`

```
Syntax: (viewbox-transform node width height)
Library: (scm svg core)
Description: The transform from an svg element's viewBox to its width and
  height (or the given ones), as preserveAspectRatio xMidYMid meet; the
  identity without a viewBox.
Example:
  (viewbox-transform root 200 100)
```

### `with-alpha`

```
Syntax: (with-alpha colour alpha)
Library: (scm svg core)
Description: An rgba colour with its alpha multiplied by alpha.
Example:
  (with-alpha #(0 0 0 1.0) 0.5) => #(0 0 0 0.5)
```


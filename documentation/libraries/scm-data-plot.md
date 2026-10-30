# `(scm data plot)`

ggplot-style charts and maps rendered to SVG, PNG and PDF

## Overview

Charts and maps in the style of ggplot2, rendered to SVG (SXML), PNG and PDF
(vectors, with embedded text). A plot is a data
frame plus specs: aesthetics, geoms (`geom-col` `geom-bar` `geom-line`
`geom-point` `geom-area` `geom-histogram` `geom-boxplot` `geom-text`
`geom-hline` `geom-vline`), labels, scales, `coord-flip`, `facet-wrap` and a
theme. The look is fixed and restrained: thin bars with rounded data ends,
2px lines, hairline gridlines, a colour-blind-checked palette of eight colours
in fixed order, a legend from two series on, `<title>` tooltips, light and dark
colours via CSS classes.

Maps, as with R's sf: `geom-sf` draws the geometry column of a frame read with
`read-sf` (shapefile, GeoJSON, TopoJSON) — polygons filled by the `fill`
aesthetic, lines, points, or outlines only with `(fill none)` — and
`geom-sf-text` labels regions (larger ones first, leaving out labels that
would overlap). A numeric fill is classed with `scale-fill-steps`: quantile,
equal or explicit breaks, one-sided ramps (blue, green, orange, red, violet)
or two-sided ones around a midpoint (blue-red, …), a no-data class.
`coord-sf` picks the projection (lon/lat data is drawn equirectangular by
default, projected data such as LV95 as it is).

## Common uses

```scheme
(save-plot (ggplot df (aes (x splg) (y points) (fill model))
             (geom-col (position dodge) (labels #t))
             (coord-flip)
             (labs (title "MFZO points") (x #f) (y "Points")))
           "points.png")
(bar-chart df 'splg 'points)        ; quick charts: bar-chart line-chart scatter-plot histogram

;; a choropleth: cantons joined with values, classed in five quantiles
(define kt (left-join (read-sf "cantons.shp") shares (by (KANTONSNUM . kt))))
(save-plot (ggplot kt (aes (fill share) (label NAME))
             (geom-sf) (geom-sf-text)
             (scale-fill-steps (n 5) (palette blue) (labels pct))
             (labs (title "Share per canton") (fill "Share")))
           "map.pdf")                ; .svg, .png or .pdf
```


## Exports

### `bar-chart`

```
Syntax: (bar-chart df x y [fill [title]])
Library: (scm data plot)
Description: A bar chart of column y per x (dodged by fill when given;
  horizontal bars when there are many or long categories).
Example:
  (bar-chart df 'splg 'points 'model "Points")
```

### `ggplot`

*(no documentation)*

### `histogram`

```
Syntax: (histogram df x [bins])
Library: (scm data plot)
Description: A histogram of column x.
Example:
  (histogram df 'age 20)
```

### `line-chart`

```
Syntax: (line-chart df x y [color [title]])
Library: (scm data plot)
Description: Lines of y over x, one per value of color.
Example:
  (line-chart df 'year 'cases 'kanton)
```

### `make-plot`

```
Syntax: (make-plot df specs)
Library: (scm data plot)
Description: A plot of df from a list of specs (the procedure behind the
  ggplot macro, for specs built at run time).
Example:
  (make-plot df '((aes (x splg) (y n)) (geom-col)))
```

### `plot->pdf`

```
Syntax: (plot->pdf plot [options])
Library: (scm data plot)
Description: The plot as a one-page PDF bytevector, drawn as vectors with
  embedded text. A pixel of the plot is 0.75 point (as in CSS) unless
  options, an alist as for svg->pdf of (scm svg pdf), give (width . pt)
  or (height . pt); (margin . pt) adds a margin, (title . s) sets the
  document title.
Example:
  (plot->pdf p '((width . 400)))
```

### `plot->png`

```
Syntax: (plot->png plot [scale])
Library: (scm data plot)
Description: The plot as a PNG bytevector, rendered at scale (default 2,
  for sharp output on high-resolution screens and in documents).
Example:
  (plot->png p)
```

### `plot->svg`

```
Syntax: (plot->svg plot)
Library: (scm data plot)
Description: Renders the plot to SVG as SXML (with its style sheet
  embedded), for inline use in (scm html builder) pages.
Example:
  (html->string (plot->svg p))
```

### `plot->svg-string`

```
Syntax: (plot->svg-string plot)
Library: (scm data plot)
Description: The plot as SVG text (a standalone .svg document).
Example:
  (plot->svg-string p)
```

### `plot-add`

```
Syntax: (plot-add plot spec …)
Library: (scm data plot)
Description: The plot with more specs (layers, labels, …) appended.
Example:
  (plot-add p '(geom-point) '(labs (title "x")))
```

### `plot-css`

```
Syntax: (plot-css [scope])
Library: (scm data plot)
Description: The CSS for charts on an HTML page: light colours, and dark
  ones for prefers-color-scheme: dark and for [data-theme=dark] on the
  root element (a [data-theme=light] root stays light). Charts embed the
  light sheet themselves, so this is only needed for dark mode.
Example:
  (plot-css)
```

### `plot?`

*(no documentation)*

### `save-plot`

```
Syntax: (save-plot plot path [scale])
Library: (scm data plot)
Description: Writes the plot to path as SVG, PNG or PDF, chosen by the
  extension (.svg, .png or .pdf); scale applies to PNG.
Example:
  (save-plot p "points.png")
```

### `scatter-plot`

*(no documentation)*


# `(scm data plot)`

ggplot-style charts rendered to SVG and PNG

## Overview

Charts in the style of ggplot2, rendered to SVG (SXML) and PNG. A plot is a data
frame plus specs: aesthetics, geoms (`geom-col` `geom-bar` `geom-line`
`geom-point` `geom-area` `geom-histogram` `geom-boxplot` `geom-text`
`geom-hline` `geom-vline`), labels, scales, `coord-flip`, `facet-wrap` and a
theme. The look is fixed and restrained: thin bars with rounded data ends,
2px lines, hairline gridlines, a colour-blind-checked palette of eight colours
in fixed order, a legend from two series on, `<title>` tooltips, light and dark
colours via CSS classes.

## Common uses

```scheme
(save-plot (ggplot df (aes (x splg) (y points) (fill model))
             (geom-col (position dodge) (labels #t))
             (coord-flip)
             (labs (title "MFZO points") (x #f) (y "Points")))
           "points.png")
(bar-chart df 'splg 'points)        ; quick charts: bar-chart line-chart scatter-plot histogram
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
Description: Writes the plot to path as SVG or PNG, chosen by the
  extension (.svg or .png).
Example:
  (save-plot p "points.png")
```

### `scatter-plot`

*(no documentation)*


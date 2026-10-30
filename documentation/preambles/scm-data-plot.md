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

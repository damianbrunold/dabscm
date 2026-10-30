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

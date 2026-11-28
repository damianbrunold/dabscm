---
title: "(scm data plot): charts and maps"
part: libraries
order: 1038
libraries: (scm data plot)
summary: The grammar of graphics with ggplot, aes and geoms; bars side by side or stacked, lines and points, histograms and boxplots; labels, axis formats, flipped and faceted charts; quick charts; output as SVG for web pages, PNG and PDF; choropleth maps from GeoJSON with classed colour scales; looking inside a chart.
---
# (scm data plot): charts and maps

`(scm data plot)` draws charts in the style of R's ggplot2: a chart is a
data frame plus a description of how its columns map to positions,
colours and labels. The output is SVG, for web pages and reports, or
PNG and PDF.

```scheme
(import (scheme base) (scheme file) (scheme write) (scm fs) (scm image) (scm data))

(define sales
  (tibble (shop "Zurich" "Bern" "Basel" "Zurich" "Bern" "Basel")
          (month 'jan 'jan 'jan 'feb 'feb 'feb)
          (kg 384 124 72 410 150 90)))
```

## A first chart

```scheme
(define p
  (ggplot sales
          (aes (x shop) (y kg) (fill month))
          (geom-col (position dodge))
          (labs (title "Kilograms per shop") (x #f) (y "kg"))))

(define dir (mktempdir '(prefix . "plots")))
(save-plot p (join-path dir "kg.svg"))
(save-plot p (join-path dir "kg.png"))
(save-plot p (join-path dir "kg.pdf"))
```

- `aes` (aesthetics) says which column goes where: shop on the x axis,
  kilograms as the bar height, the month as the colour.
- `geom-col` draws bars; `(position dodge)` puts the months side by side,
  the default stacks them, `(position fill)` stacks them to 100 %.
- `labs` sets the title and axis labels; `#f` leaves a label out.

`save-plot` picks the format from the extension. The PNG is rendered at
twice the size by default, sharp on high-resolution screens; the PDF is
vector graphics with real text:

```scheme
(image-info (plot->png p))                  ;; => ((format . png) (width . 1440) (height . 800) (orientation . 1))
(utf8->string (bytevector-copy (plot->pdf p) 0 5)) ;; => "%PDF-"
```

The look is fixed on purpose: thin bars, hairline grid lines, a palette
of eight colours that colour-blind readers can tell apart, a legend
only when there are two series or more. Charts made by different
scripts look like they belong together.

## Looking inside

`plot->svg` returns the chart as SXML, the tree form of `(scm html
builder)`, so a chart can go straight into a page, and a test can look
inside it. Every bar carries a tooltip:

```scheme
(define (find-all tree tag)                 ; all elements with this tag
  (cond ((not (pair? tree)) '())
        ((eq? (car tree) tag) (cons tree (find-in (cdr tree) tag)))
        (else (find-in (cdr tree) tag))))
(define (find-in trees tag)
  (if (null? trees) '() (append (find-all (car trees) tag) (find-in (cdr trees) tag))))
(define (tooltips svg) (map cadr (find-all svg 'title)))

(define svg (plot->svg p))
(car svg)                                   ;; => svg
(tooltips svg)
;; => ("Zurich, jan: 384" "Bern, jan: 124" "Basel, jan: 72" "Zurich, feb: 410" "Bern, feb: 150" "Basel, feb: 90")
```

`plot->svg-string` gives a standalone SVG document as text.

## Other geoms

```scheme
;; lines over time, one per shop, with the points marked
(define trend (ggplot sales (aes (x month) (y kg) (color shop)) (geom-line) (geom-point)
                      (scale-x (levels jan feb))))

;; the distribution of one variable
(define brew (tibble (minutes 3.0 3.5 2.5 4.0 3.0 5.5 3.0 2.0 4.5 3.0)))
(define hist (ggplot brew (aes (x minutes)) (geom-histogram (bins 4))))

;; horizontal bars with the values written at their ends
(define ranked (ggplot sales (aes (x shop) (y kg)) (geom-col (labels #t)) (coord-flip)))

;; one small chart per month
(define small (ggplot sales (aes (x shop) (y kg)) (geom-col) (facet-wrap month)))

(map (lambda (pl) (cdr (assq 'width (image-info (plot->png pl 1))))) (list trend hist ranked small))
;; => (720 720 720 720)
```

| geom | draws |
|---|---|
| `geom-col` | bars of given heights |
| `geom-bar` | bars counting rows |
| `geom-line`, `geom-area` | lines, filled areas |
| `geom-point` | points (a scatter plot with `x` and `y` numeric) |
| `geom-histogram`, `geom-boxplot` | distributions |
| `geom-text` | labels at data positions |
| `geom-hline`, `geom-vline` | reference lines, e.g. a target |

`scale-x` and `scale-y` set the order of categories (`levels`), the
range (`limits`), a log scale, and the format of the axis labels:
`(labels pct)`, `int`, `si`, or any procedure such as `fmt-num`. `theme`
sets the size and where the legend goes.

## Quick charts

For a first look at data, one call is enough:

```scheme
(plot? (bar-chart sales 'shop 'kg 'month "Kilograms")) ;; => #t
(plot? (histogram brew 'minutes))                       ;; => #t
```

`line-chart` and `scatter-plot` are the other two. They return ordinary
plots, so `plot-add` can add labels or layers to them afterwards.

## Maps

A map is a chart of a frame with a geometry column, read with `read-sf`
from GeoJSON, a shapefile or TopoJSON. Here four made-up sales regions
as squares:

```scheme
(define (square-feature name x y)
  (string-append "{\"type\":\"Feature\",\"properties\":{\"region\":\"" name "\"},"
                 "\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[["
                 (number->string x) "," (number->string y) "],[" (number->string (+ x 1)) "," (number->string y) "],["
                 (number->string (+ x 1)) "," (number->string (+ y 1)) "],[" (number->string x) "," (number->string (+ y 1)) "],["
                 (number->string x) "," (number->string y) "]]]}}"))

(call-with-output-file (join-path dir "regions.geojson")
  (lambda (out)
    (write-string (string-append "{\"type\":\"FeatureCollection\",\"features\":["
                                 (square-feature "North" 8 47) "," (square-feature "West" 7 46) ","
                                 (square-feature "East" 9 46) "," (square-feature "South" 8 45) "]}")
                  out)))

(define regions (read-sf (join-path dir "regions.geojson")))
(define shares (tibble (region "North" "West" "East" "South") (share 0.42 0.18 0.27 0.13)))
```

Join the values to the geometries, fill each region by its value, label
it, and class the values into steps of one colour:

```scheme
(define map-plot
  (ggplot (left-join regions shares (by region))
          (aes (fill share) (label region))
          (geom-sf)
          (geom-sf-text)
          (scale-fill-steps (breaks (0.15 0.25 0.35)) (palette green) (labels pct))
          (labs (title "Share of sales") (fill "Share"))))

(tooltips (plot->svg map-plot))             ;; => ("North: 42 %" "West: 18 %" "East: 27 %" "South: 13 %")
(save-plot map-plot (join-path dir "regions.pdf"))
(rm dir 'recursive)
```

- `scale-fill-steps` classes a numeric fill: `(breaks quantile)` (the
  default, equally many regions per class), `equal`, or explicit
  thresholds as here; `(n 5)` sets the number of classes.
- One-sided palettes (`blue`, `green`, `orange`, `red`, `violet`) are
  for amounts; two-sided ones (`blue-red` …) with `(midpoint 0)` for
  changes that can go either way.
- Labels are placed in the middle of each region, larger regions first,
  leaving out labels that would overlap.
- Longitude/latitude data is drawn with the right proportions for its
  latitude; projected data (Swiss LV95, for example) as it is.

## On web pages

A chart's SXML goes into a page built with `(scm html builder)` as it is.
The chart brings its light colours; `plot-css` adds the dark-mode
colours for pages that switch themes:

```scheme no-test
(html->string
 `(html (head (style ,(raw (plot-css))))
        (body (h1 "Sales") ,(plot->svg p))))
```

## Where next

- [Reports](scm-data-report.md) with charts and tables to HTML, Markdown
  and PDF.
- [Joining and reshaping](scm-data-reshape.md): `ggplot` wants long
  frames, one row per bar or point.
- [PDF](scm-pdf.md) and [images](scm-images.md) for the lower levels.
- Reference: `(scm data plot)`.

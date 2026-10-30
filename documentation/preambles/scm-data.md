## Overview

`(scm data)` is a small toolkit for data analysis scripts, modelled on R's
tidyverse (dplyr, tidyr, ggplot2) and pandas: **read → transform → summarise →
chart → report**. It re-exports the `(scm data …)` libraries, so one import is
enough:

| Library | What it does |
|---|---|
| `(scm data frame)` | column-oriented data frames (`tibble`, `make-df`, `df-print`, …) |
| `(scm data verbs)` | `where`, `mutate`, `summarise`, `group-by`, `arrange`, joins, pivots, … |
| `(scm data expr)` | the expression language used inside the verbs |
| `(scm data stats)` | `mean`, `median`, `quantile`, `sd`, `cor`, `freq`, `crosstab`, … |
| `(scm data tests)` | distributions and hypothesis tests as in R: `t-test`, `chisq-test`, `fisher-test`, `lm`, … |
| `(scm data format)` | `fmt-num`, `fmt-pct`, `fmt-pct-change` (Swiss separators by default) |
| `(scm data io)` | CSV, XLSX, JSON, s-expression lines, SQL results, shapefiles, GeoJSON, TopoJSON |
| `(scm data plot)` | ggplot-style charts and maps to SVG, PNG and PDF |
| `(scm data report)` | reports with tables and charts to HTML, Markdown and PDF |
| `(scm data core)` | the missing value `na`, dates, type inference |

It covers the everyday 80 % of analysis work and deliberately stops there: no
lazy evaluation, no modelling beyond linear models and the classic tests, no
interactive charts.

`(scm data r)`, imported on its own, translates analysis code between R
(tidyverse) and `(scm data)` in both directions.

## Common uses

```scheme
(import (scheme base) (scm data))

(define cases (read-csv "cases.csv" 'sep #\; 'col-types '((plz . string))))

(define per-splg
  (-> cases
      (where (= kanton "ZH") (>= year ,from-year))
      (group-by splg year)
      (summarise (n (n)) (points (sum points)))
      (pivot-wider (names-from year) (values-from points) (values-fill 0))
      (arrange (desc 2025))))

(df-print per-splg)

(write-report
  (report (title "Points per SPLG") (date)
          (table ,per-splg (total-row))
          (figure ,(ggplot per-splg (aes (x splg) (y 2025)) (geom-col) (coord-flip))))
  "report.html")
```

## Writing expressions

The verbs are macros that quasiquote their arguments: a bare symbol names a
column, and Scheme values are spliced in with unquote (`,from-year`,
`(in splg ,my-list)`, `(,my-proc points)`). Every verb also exists as a
procedure taking quoted expressions (`df-filter`, `df-mutate`, …) for code that
builds them at run time. The row filter is called `where` and the counting verb
`tally`, so they don't clash with `filter` and `count` of `(srfi 1)`.

## Missing values

Missing cells are `na` (test with `na?`). Aggregates skip it, arithmetic and
comparisons with it give `na`, and a `na` condition counts as false in `where`.

## Script helpers

`script-args` parses `key=value` arguments into typed values (with usage output
for unknown keys and `help`), and `with-timing` prints how long a step took.

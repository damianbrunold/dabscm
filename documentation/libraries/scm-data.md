# `(scm data)`

Data analysis in one import — frames, verbs, stats, tests, IO, charts, maps, reports

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


## Exports

### `->`

*(no documentation)*

### `add-count`

*(no documentation)*

### `alists->df`

```
Syntax: (alists->df alists [names])
Library: (scm data frame)
Description: A frame from a list of rows given as alists ((key . value) …),
  keys being symbols or strings. Columns are the keys in order of first
  appearance (or the given names); missing keys become na.
Example:
  (df-names (alists->df '(((a . 1)) ((a . 2) (b . 3))))) => (a b)
```

### `all-rows`

*(no documentation)*

### `anti-join`

*(no documentation)*

### `arrange`

*(no documentation)*

### `bar-chart`

```
Syntax: (bar-chart df x y [fill [title]])
Library: (scm data plot)
Description: A bar chart of column y per x (dodged by fill when given;
  horizontal bars when there are many or long categories).
Example:
  (bar-chart df 'splg 'points 'model "Points")
```

### `bind-cols`

*(no documentation)*

### `bind-rows`

*(no documentation)*

### `binom-test`

```
Syntax: (binom-test successes trials option ...)
Library: (scm data tests)
Description: The exact binomial test, as R's binom.test, with the
  Clopper-Pearson confidence interval. Options: 'p 0.5, 'alternative,
  'conf-level 0.95.
Example:
  (binom-test 682 925 'p 0.75)
```

### `chisq-test`

```
Syntax: (chisq-test x [y] option ...)
Library: (scm data tests)
Description: Pearson's chi-squared test, as R's chisq.test: for a
  contingency table (a list or vector of rows, or a frame whose numeric
  columns are the table, such as crosstab gives without margins), for two
  vectors of categories (cross-tabulated), or a goodness-of-fit test for
  one vector of counts against 'p (default: equal; 'rescale-p #t scales p
  to sum 1). 2x2 tables get Yates' correction unless 'correct #f.
  (htest-ref h 'expected) and 'residuals give the expected counts and
  Pearson residuals.
Example:
  (chisq-test '((762 327 468) (484 239 477)))
```

### `column-type`

```
Syntax: (column-type vector)
Library: (scm data core)
Description: The type of a column: the common value-type of its non-NA
  values; int and real together give real; na if all are NA, mixed if
  the values have different types.
Example:
  (column-type (vector 1 2.5 na)) => real
```

### `compile-expr`

```
Syntax: (compile-expr df expr)
Library: (scm data expr)
Description: Compiles a column expression against the columns of df into
  a procedure (lambda (i rows) value): the value for row i, with rows the
  vector of row indices of its group (used by aggregates and window
  functions; (all-rows df) when ungrouped). See the library comment for
  the vocabulary.
Example:
  ((compile-expr df '(* pts 2)) 0 (all-rows df))
```

### `cor`

```
Syntax: (cor xs ys [method])
Library: (scm data stats)
Description: The correlation coefficient; method pearson (default) or
  spearman (Pearson on the average ranks).
Example:
  (cor '(1 2 3 4) '(1 3 2 4)) => 0.8
```

### `cor-test`

```
Syntax: (cor-test x y option ...)
Library: (scm data tests)
Description: Test of association, as R's cor.test: 'method pearson
  (t test with Fisher's z confidence interval), kendall (exact below 50
  pairs without ties, else normal with tie correction) or spearman (the
  t approximation, as R with exact = FALSE). Options: 'alternative,
  'conf-level, 'exact 'auto|#f.
Example:
  (cor-test '(1 2 3 4 5) '(2 1 4 3 5))
```

### `cov`

```
Syntax: (cov xs ys)
Library: (scm data stats)
Description: The sample covariance of two equally long lists (pairs with
  a na are skipped).
Example:
  (cov '(1 2 3) '(2 4 6)) => 2.0
```

### `crosstab`

```
Syntax: (crosstab row-values col-values [margins?])
Library: (scm data stats)
Description: A two-way frequency table as a data frame: a column row with
  the distinct row values, then one column per distinct column value
  (named after it) holding counts. With margins? #t a total column and
  a total row are added.
Example:
  (crosstab '(a a b) '(x y x) #t)
```

### `csv-for-each`

```
Syntax: (csv-for-each path proc option ...)
Library: (scm data io)
Description: Streams a large CSV file: calls proc with each record as an
  alist ((column . string) …), without building a frame. Takes the
  options 'sep, 'header, 'names and 'skip of read-csv.
Example:
  (csv-for-each "big.csv" (lambda (r) (display (cdr (assq 'id r)))))
```

### `cumsum`

```
Syntax: (cumsum xs)
Library: (scm data stats)
Description: The running sums, as a list; na stays na and is skipped.
Example:
  (cumsum (list 1 2 na 3)) => (1 3 na 6)
```

### `dF`

```
Syntax: (dF x df1 df2)
Library: (scm data tests)
Description: The density of the F distribution (dF, not df as in R, so
  that it does not take the usual name of a data frame).
Example:
  (dF 1 5 10) => 0.4954798
```

### `data-frame?`

*(no documentation)*

### `data-locale`

*(no documentation)*

### `day->string`

```
Syntax: (day->string day [style])
Library: (scm data core)
Description: Formats a date. style is iso (default, "2024-03-11") or
  dmy ("11.03.2024").
Example:
  (day->string (ymd->day 2024 3 11) 'dmy) => "11.03.2024"
```

### `day->ymd`

```
Syntax: (day->ymd day)
Library: (scm data core)
Description: The list (year month day-of-month) of a date.
Example:
  (day->ymd (ymd->day 2024 2 29)) => (2024 2 29)
```

### `day-from-number`

```
Syntax: (day-from-number n)
Library: (scm data core)
Description: The date n days after 1970-01-01 (n may be negative).
Example:
  (day->string (day-from-number 0)) => "1970-01-01"
```

### `day-month`

*(no documentation)*

### `day-number`

*(no documentation)*

### `day-weekday`

```
Syntax: (day-weekday day)
Library: (scm data core)
Description: ISO weekday of a date: 1 = Monday … 7 = Sunday.
Example:
  (day-weekday (ymd->day 2026 10 30)) => 5
```

### `day-year`

*(no documentation)*

### `day?`

*(no documentation)*

### `dbeta`

```
Syntax: (dbeta x a b)
Library: (scm data tests)
Description: The density of the beta distribution.
Example:
  (dbeta 0.5 2 2) => 1.5
```

### `dbinom`

```
Syntax: (dbinom k n p)
Library: (scm data tests)
Description: The binomial probability P(X = k) for n trials with success
  probability p.
Example:
  (dbinom 2 4 0.5) => 0.375
```

### `dchisq`

```
Syntax: (dchisq x df)
Library: (scm data tests)
Description: The density of the chi-squared distribution.
Example:
  (dchisq 1 2) => 0.30326532985631671
```

### `define-df-function`

```
Syntax: (define-df-function name kind proc)
Library: (scm data expr)
Description: Adds a function to the expression vocabulary. kind is
  scalar (called per row, returns na if an argument is na), raw (per row,
  gets na unchanged), agg (called with the list of the group's non-na
  values of the first argument plus the other arguments, returns one
  value) or window (called with the vector of the group's values plus the
  other arguments, returns a vector of the same length).
Example:
  (define-df-function 'sq 'scalar (lambda (x) (* x x)))
  (mutate df (pts2 (sq pts)))
```

### `df->alists`

```
Syntax: (df->alists df)
Library: (scm data frame)
Description: The rows as a list of alists.
Example:
  (df->alists (tibble (a 1))) => (((a . 1)))
```

### `df->csv-string`

*(no documentation)*

### `df->features`

```
Syntax: (df->features df [geometry-column])
Library: (scm data io)
Description: The rows of a frame with a geometry column as (scm geo)
  features, the other columns as their properties (keys are strings, na
  becomes null). Rows without a geometry are left out.
Example:
  (features->geojson (df->features regions))
```

### `df->rows`

```
Syntax: (df->rows df)
Library: (scm data frame)
Description: The rows as a list of lists, cells in column order.
Example:
  (df->rows (tibble (a 1 2) (b 3 4))) => ((1 3) (2 4))
```

### `df->string`

```
Syntax: (df->string df [n])
Library: (scm data frame)
Description: The first n rows (default 10) as an aligned text table with
  the column types under the header.
Example:
  (display (df->string (tibble (a 1 2))))
```

### `df-add-count`

*(no documentation)*

### `df-arrange`

```
Syntax: (df-arrange df keys)
Library: (scm data verbs)
Description: Sorts the rows (stable) by the keys: a column, an expression
  or (desc key) for descending order; na sorts last. Macro form:
  (arrange df key …).
Example:
  (arrange df splg (desc pts))
```

### `df-bind-cols`

*(no documentation)*

### `df-bind-rows`

```
Syntax: (df-bind-rows frames [id-column labels])
Library: (scm data verbs)
Description: Stacks frames on top of each other; columns are matched by
  name (missing ones filled with na). With an id-column, a first column
  tells which frame each row came from (labels, default 1, 2, …). Also:
  (bind-rows df …).
Example:
  (df-bind-rows (list a b) 'year '(2024 2025))
```

### `df-column`

```
Syntax: (df-column df name)
Library: (scm data frame)
Description: The vector of column name (do not mutate it).
Example:
  (df-column (tibble (a 1 2)) 'a) => #(1 2)
```

### `df-column-type`

*(no documentation)*

### `df-columns`

```
Syntax: (df-columns df)
Library: (scm data frame)
Description: The columns as an alist ((name . vector) …).
Example:
  (df-columns (tibble (a 1))) => ((a . #(1)))
```

### `df-count`

```
Syntax: (df-count df cols)
Library: (scm data verbs)
Description: The number of rows per combination of cols (column n),
  sorted by cols; with no cols, of the existing groups (or all rows).
  Macro form: (tally df col …).
Example:
  (tally df splg year)
```

### `df-distinct`

```
Syntax: (df-distinct df cols)
Library: (scm data verbs)
Description: The first row of each distinct combination of the given
  columns, keeping only those columns ('() = all columns). Macro form:
  (distinct df col …).
Example:
  (distinct df splg gln)
```

### `df-drop-columns`

*(no documentation)*

### `df-drop-na`

```
Syntax: (df-drop-na df cols)
Library: (scm data verbs)
Description: The rows without na in cols ('() = in any column). Macro
  form: (drop-na df col …).
Example:
  (drop-na df pts)
```

### `df-fill`

```
Syntax: (df-fill df cols direction)
Library: (scm data verbs)
Description: Fills na with the previous (direction down) or next (up)
  non-na value of the column, per group. Macro forms: (fill-down df col …),
  (fill-up df col …).
Example:
  (fill-down df kanton)
```

### `df-filter`

```
Syntax: (df-filter df exprs)
Library: (scm data verbs)
Description: The rows for which all expressions are true (na counts as
  false); macro form: (where df expr …). Grouped frames evaluate
  aggregates per group, e.g. (where df (= pts (max pts))).
Example:
  (df-filter df '((> pts 10) (= splg 'BEW8)))
```

### `df-function-names`

*(no documentation)*

### `df-glimpse`

```
Syntax: (df-glimpse df [port])
Library: (scm data frame)
Description: Prints one line per column: name, type and the first values,
  like dplyr's glimpse.
Example:
  (df-glimpse (tibble (a 1 2)))
```

### `df-group-by`

```
Syntax: (df-group-by df cols)
Library: (scm data verbs)
Description: The frame grouped by the given columns; summarise, mutate,
  where and tally then work per group. Macro form: (group-by df col …).
Example:
  (group-by df splg year)
```

### `df-group-keys`

```
Syntax: (df-group-keys df)
Library: (scm data verbs)
Description: The groups of a grouped frame as a list of (key-values .
  row-index-vector), sorted by key.
Example:
  (map car (df-group-keys (group-by df splg))) => ((BEW8) (GYN2))
```

### `df-groups`

*(no documentation)*

### `df-has-column?`

*(no documentation)*

### `df-head`

```
Syntax: (head df [n])
Library: (scm data verbs)
Description: The first n rows (default 6).
Example:
  (head df 3)
```

### `df-head-string`

*(no documentation)*

### `df-join`

```
Syntax: (df-join kind x y by [suffix-x suffix-y])
Library: (scm data verbs)
Description: Joins two frames on key columns. kind is left, inner, full,
  semi (rows of x with a match) or anti (rows of x without). by lists the
  keys: a name present in both, or (x-name . y-name); '() means all
  common column names. Non-key columns present in both get the suffixes
  (default ".x" and ".y"). Macro forms: (left-join x y [(by key …)]),
  inner-join, full-join, semi-join, anti-join.
Example:
  (left-join pts limits (by splg))
```

### `df-map-rows`

```
Syntax: (df-map-rows df proc)
Library: (scm data verbs)
Description: Calls proc with each row as an alist and returns the list of
  results (escape hatch for anything the verbs don't cover).
Example:
  (df-map-rows df (lambda (r) (cdr (assq 'pts r))))
```

### `df-mutate`

```
Syntax: (df-mutate df specs)
Library: (scm data verbs)
Description: Adds or replaces columns; specs is a list of (name . expr),
  evaluated in order, so later expressions see earlier results. Grouped
  frames evaluate aggregates and window functions per group. Macro form:
  (mutate df (name expr) …).
Example:
  (df-mutate df '((pts2 . (* 2 pts))))
```

### `df-names`

*(no documentation)*

### `df-ncol`

*(no documentation)*

### `df-nrow`

*(no documentation)*

### `df-pivot-longer`

```
Syntax: (df-pivot-longer df cols names-to values-to)
Library: (scm data verbs)
Description: Turns the columns cols into rows: each row becomes one row per
  column, with the column name (a symbol) in names-to and the value in
  values-to; the other columns are repeated. Macro form:
  (pivot-longer df (cols c …) (names-to name) (values-to name)).
Example:
  (pivot-longer df (cols v1 v2) (names-to model) (values-to pts))
```

### `df-pivot-wider`

```
Syntax: (df-pivot-wider df names-from values-from [fill])
Library: (scm data verbs)
Description: Turns rows into columns: one column per distinct value of the
  names-from columns (joined with _ when several), holding values-from;
  the remaining columns identify the rows. Missing combinations get fill
  (default na). Macro form:
  (pivot-wider df (names-from col …) (values-from col) [(values-fill v)]).
Example:
  (pivot-wider df (names-from year model) (values-from pts) (values-fill 0))
```

### `df-print`

*(no documentation)*

### `df-pull`

```
Syntax: (df-pull df col)
Library: (scm data verbs)
Description: The values of one column as a list. Macro form: (pull df col).
Example:
  (pull df splg) => (BEW8 GYN2)
```

### `df-ref`

```
Syntax: (df-ref df row name)
Library: (scm data frame)
Description: The cell in row i (0-based) of column name.
Example:
  (df-ref (tibble (a 1 2)) 1 'a) => 2
```

### `df-relocate`

*(no documentation)*

### `df-rename`

```
Syntax: (df-rename df pairs)
Library: (scm data verbs)
Description: Renames columns; pairs is a list of (new . old). Macro form:
  (rename df (new old) …).
Example:
  (rename df (points pts))
```

### `df-rename-columns`

```
Syntax: (df-rename-columns df renames)
Library: (scm data frame)
Description: Renames columns; renames is an alist ((old . new) …).
Example:
  (df-names (df-rename-columns (tibble (a 1)) '((a . x)))) => (x)
```

### `df-replace-na`

```
Syntax: (df-replace-na df pairs)
Library: (scm data verbs)
Description: Replaces na in the given columns; pairs is ((col . value) …).
  Macro form: (replace-na df (col value) …).
Example:
  (replace-na df (pts 0))
```

### `df-row`

```
Syntax: (df-row df i)
Library: (scm data frame)
Description: Row i (0-based) as an alist ((name . value) …).
Example:
  (df-row (tibble (a 1 2) (b 3 4)) 0) => ((a . 1) (b . 3))
```

### `df-sample-n`

```
Syntax: (sample-n df n [seed])
Library: (scm data verbs)
Description: n rows drawn at random without replacement (in their
  original order); a seed makes the draw reproducible.
Example:
  (sample-n df 100 42)
```

### `df-select`

```
Syntax: (df-select df specs)
Library: (scm data verbs)
Description: Keeps and orders columns. A spec is a column name,
  (starts-with "x"), (ends-with "x"), (contains "x"), (matches regex),
  (everything), (where pred) with pred on the column vector,
  (except spec …) to drop columns, or (rename new old). Grouping
  columns are always kept. Macro form: (select df spec …).
Example:
  (select df splg (starts-with "pts") (except pts-raw))
```

### `df-select-columns`

```
Syntax: (df-select-columns df names)
Library: (scm data frame)
Description: A frame with only the given columns, in the given order.
Example:
  (df-names (df-select-columns (tibble (a 1) (b 2)) '(b))) => (b)
```

### `df-separate`

```
Syntax: (df-separate df col into separator-regex)
Library: (scm data verbs)
Description: Splits a string column into several columns at a separator
  (a regular expression); missing parts become na. Macro form:
  (separate df col (into a b …) [(sep regex)]) (default separator: one
  of space , ; : / _ - .).
Example:
  (separate df falltyp (into art stat sub) (sep ":"))
```

### `df-set-groups`

```
Syntax: (df-set-groups df names)
Library: (scm data frame)
Description: The same frame grouped by the given columns ('() ungroups).
Example:
  (df-groups (df-set-groups (tibble (a 1)) '(a))) => (a)
```

### `df-slice`

```
Syntax: (df-slice df start [end])
Library: (scm data verbs)
Description: Rows start (inclusive, 0-based) to end (exclusive, default
  the last row), like substring. Also: (slice df start [end]).
Example:
  (slice df 0 10)
```

### `df-split`

```
Syntax: (df-split df)
Library: (scm data verbs)
Description: A grouped frame as a list of (key-values . frame), one per
  group, sorted by key.
Example:
  (df-split (group-by df splg))
```

### `df-summarise`

```
Syntax: (df-summarise df specs)
Library: (scm data verbs)
Description: One row per group (one row if ungrouped): the grouping
  columns plus a column per (name . expr) spec, normally an aggregate
  such as (sum pts) or (n). Later specs may use earlier ones. The result
  is ungrouped and sorted by the grouping columns. Macro form:
  (summarise df (name expr) …).
Example:
  (df-summarise (df-group-by df '(splg)) '((total . (sum pts))))
```

### `df-tail`

*(no documentation)*

### `df-take`

```
Syntax: (df-take df indices)
Library: (scm data frame)
Description: A frame with the rows at the given 0-based indices (a vector
  or list), in that order; an index may repeat.
Example:
  (df-column (df-take (tibble (a 10 20 30)) #(2 0)) 'a) => #(30 10)
```

### `df-transmute`

*(no documentation)*

### `df-types`

```
Syntax: (df-types df)
Library: (scm data frame)
Description: The column types as an alist ((name . type) …), see
  column-type in (scm data core).
Example:
  (df-types (tibble (a 1 2) (b "x" na))) => ((a . int) (b . string))
```

### `df-ungroup`

*(no documentation)*

### `df-unnest-longer`

```
Syntax: (df-unnest-longer df col [into])
Library: (scm data verbs)
Description: One row per element of the list column col (rows with an
  empty list are dropped). With into, a list of names, each element must
  be a list and is spread into those columns (col is dropped). Macro form:
  (unnest-longer df col [(into name …)]).
Example:
  (unnest-longer cases operateure (into gln splg points))
```

### `df-with-column`

```
Syntax: (df-with-column df name values)
Library: (scm data frame)
Description: Adds column name at the end, or replaces it in place. values
  is a vector, a list, or one value recycled to all rows.
Example:
  (df-names (df-with-column (tibble (a 1)) 'b 0)) => (a b)
```

### `df-with-columns`

```
Syntax: (df-with-columns df columns)
Library: (scm data frame)
Description: df-with-column for each (name . values) of an alist.
Example:
  (df-ncol (df-with-columns (tibble (a 1)) '((b . 2) (c . 3)))) => 3
```

### `distinct`

*(no documentation)*

### `dnorm`

```
Syntax: (dnorm x [mean sd])
Library: (scm data tests)
Description: The normal density.
Example:
  (dnorm 0) => 0.3989422804014327
```

### `dpois`

```
Syntax: (dpois k lambda)
Library: (scm data tests)
Description: The Poisson probability P(X = k).
Example:
  (dpois 0 1) => 0.36787944117144233
```

### `drop-na`

*(no documentation)*

### `dt`

```
Syntax: (dt x df)
Library: (scm data tests)
Description: The density of Student's t distribution.
Example:
  (dt 0 10) => 0.389108383966031
```

### `empty-df`

*(no documentation)*

### `eval-column`

```
Syntax: (eval-column df expr)
Library: (scm data verbs)
Description: Evaluates an expression for every row (per group when df is
  grouped) and returns the vector of results.
Example:
  (eval-column df '(* 2 pts))
```

### `expr-uses-aggregate?`

```
Syntax: (expr-uses-aggregate? expr)
Library: (scm data expr)
Description: True if the expression calls an aggregate function (or (n)).
Example:
  (expr-uses-aggregate? '(/ (sum pts) (n))) => #t
```

### `features->df`

```
Syntax: (features->df features [geometry-column])
Library: (scm data io)
Description: A frame of (scm geo) features, as R's sf has them: one
  column per property (null becomes na) and their geometries in the
  column geometry (or the name given).
Example:
  (features->df (read-shapefile "cantons.shp"))
```

### `fill-down`

*(no documentation)*

### `fill-up`

*(no documentation)*

### `fisher-test`

```
Syntax: (fisher-test table option ...)
Library: (scm data tests)
Description: Fisher's exact test for a 2x2 table (rows as lists, or a
  frame as for chisq-test), as R's fisher.test: the p-value sums the
  probabilities of tables no more likely than the observed one; the
  estimate is the conditional maximum likelihood odds ratio with its
  exact confidence interval. Options: 'alternative, 'or 1 (odds ratio
  under the null), 'conf-level 0.95.
Example:
  (fisher-test '((3 1) (1 3)))
```

### `fmt-date`

```
Syntax: (fmt-date day [style])
Library: (scm data format)
Description: Formats a date: iso (default, 2024-03-11) or dmy (11.03.2024).
Example:
  (fmt-date (ymd->day 2024 3 11) 'dmy) => "11.03.2024"
```

### `fmt-int`

```
Syntax: (fmt-int x)
Library: (scm data format)
Description: (fmt-num x 0): rounded, with thousands separators.
Example:
  (fmt-int 1234567) => "1'234'567"
```

### `fmt-num`

```
Syntax: (fmt-num x [decimals [thousands?]])
Library: (scm data format)
Description: Formats a number with a fixed number of decimals (default 0)
  and thousands separators from data-locale (pass #f as thousands? to
  leave them out). na gives (na-string).
Example:
  (fmt-num 24973.25 1) => "24'973.3"
  (fmt-num -0.04 1)    => "0.0"
```

### `fmt-pct`

```
Syntax: (fmt-pct fraction [decimals])
Library: (scm data format)
Description: Formats a fraction as percent with a space before % (default
  1 decimal).
Example:
  (fmt-pct 0.2345) => "23.5 %"
```

### `fmt-pct-change`

```
Syntax: (fmt-pct-change from to [decimals])
Library: (scm data format)
Description: The relative change from a to b as a signed percent (default
  0 decimals); "n/a" when a is 0 and b is not.
Example:
  (fmt-pct-change 20316 24973) => "+23 %"
```

### `fmt-si`

```
Syntax: (fmt-si x [decimals])
Library: (scm data format)
Description: Short form with k / M / G suffix (default 1 decimal), for
  axis labels.
Example:
  (fmt-si 12345) => "12.3k"
```

### `fmt-value`

```
Syntax: (fmt-value x)
Library: (scm data format)
Description: Generic display form of a cell value, used when printing data
  frames: integers plain, reals with up to 4 decimals, dates ISO, strings
  as they are, na as (na-string), lists and other values written.
Example:
  (fmt-value 2.50) => "2.5"
```

### `freq`

```
Syntax: (freq xs [sort])
Library: (scm data stats)
Description: A frequency table as a data frame with columns value, n and
  share (fraction); sorted by value, or by descending n with 'by-count.
  na values are counted as their own value.
Example:
  (freq '(a b a)) ; value a b, n 2 1, share 0.667 0.333
```

### `full-join`

*(no documentation)*

### `ggplot`

*(no documentation)*

### `group-by`

*(no documentation)*

### `head`

```
Syntax: (head df [n])
Library: (scm data verbs)
Description: The first n rows (default 6).
Example:
  (head df 3)
```

### `histogram`

```
Syntax: (histogram df x [bins])
Library: (scm data plot)
Description: A histogram of column x.
Example:
  (histogram df 'age 20)
```

### `histogram-bins`

```
Syntax: (histogram-bins xs [bins | 'width w])
Library: (scm data stats)
Description: Bins numbers for a histogram: a data frame with columns from,
  to and n (left-closed bins [from, to), the last one closed). The number
  of bins defaults to Sturges' rule; give a count, or 'width w for fixed
  width bins starting at a multiple of w.
Example:
  (histogram-bins '(1 2 2 3 7) 3)
```

### `htest->string`

```
Syntax: (htest->string htest)
Library: (scm data tests)
Description: The test result as text, in the layout of R's print.htest.
Example:
  (display (htest->string (t-test '(1 2 3 4))))
```

### `htest-alternative`

*(no documentation)*

### `htest-conf-int`

*(no documentation)*

### `htest-conf-level`

*(no documentation)*

### `htest-data-name`

*(no documentation)*

### `htest-estimate`

*(no documentation)*

### `htest-extra`

*(no documentation)*

### `htest-method`

*(no documentation)*

### `htest-null-value`

*(no documentation)*

### `htest-p-value`

*(no documentation)*

### `htest-parameter`

*(no documentation)*

### `htest-print`

```
Syntax: (htest-print htest [port])
Library: (scm data tests)
Description: Writes the test result like R prints it.
Example:
  (htest-print (t-test '(1 2 3 4)))
```

### `htest-ref`

```
Syntax: (htest-ref htest key)
Library: (scm data tests)
Description: One value of a test result: statistic, parameter (a list
  when there are several), p-value, conf-int, conf-level, estimate (a
  list when there are several), null-value, alternative, method, or a
  key of the extra results (e.g. expected for chisq-test).
Example:
  (htest-ref (t-test '(1 2 3 4)) 'p-value)
```

### `htest-statistic`

*(no documentation)*

### `htest?`

*(no documentation)*

### `infer-column`

```
Syntax: (infer-column string-vector [na-strings [decimal-char]])
Library: (scm data core)
Description: Guesses the type of a column of strings and converts it:
  int if every non-missing cell is an integer, else real if all are
  numbers (a value with a leading zero such as "007" is a code, and
  keeps the column a string), else bool (TRUE/FALSE, or t/f as Postgres sends them), else date (ISO or DD.MM.YYYY), else
  string. Cells in na-strings (default "", NA, N/A, NULL, #N/A) become
  na. Returns the converted vector.
Example:
  (infer-column (vector "1" "" "3")) => #(1 na 3)
```

### `inner-join`

*(no documentation)*

### `iqr`

```
Syntax: (iqr xs)
Library: (scm data stats)
Description: The interquartile range, quantile 0.75 minus quantile 0.25.
Example:
  (iqr '(1 2 3 4 5)) => 2
```

### `kruskal-test`

```
Syntax: (kruskal-test df '(y ~ g)) or (kruskal-test samples)
Library: (scm data tests)
Description: The Kruskal-Wallis rank sum test, as R's kruskal.test (with
  the tie correction). samples is a list of lists of numbers.
Example:
  (kruskal-test '((2.9 3.0 2.5 2.6 3.2) (3.8 2.7 4.0 2.4) (2.8 3.4 3.7 2.2 2.0)))
```

### `ks-test`

```
Syntax: (ks-test x y option ...)
Library: (scm data tests)
Description: The Kolmogorov-Smirnov test, as R's ks.test: y is either a
  second sample, or a distribution function (a procedure of one
  argument, e.g. (lambda (q) (pnorm q 0 1))). Exact p-values for one
  sample below 100 values and for two samples with m*n < 10000 (two-sided,
  no ties); otherwise the asymptotic distribution. Options: 'alternative
  two-sided|less|greater, 'exact 'auto|#f.
Example:
  (ks-test '(0.1 -0.4 1.2 0.8 -1.5) pnorm)
```

### `lbeta`

```
Syntax: (lbeta a b)
Library: (scm data tests)
Description: The natural logarithm of the beta function B(a, b).
Example:
  (lbeta 2 3) => -2.4849066497880004 ; log(1/12)
```

### `lchoose`

```
Syntax: (lchoose n k)
Library: (scm data tests)
Description: The natural logarithm of the binomial coefficient n over k.
Example:
  (exp (lchoose 5 2)) => 10.000000000000002
```

### `left-join`

*(no documentation)*

### `lgamma`

```
Syntax: (lgamma x)
Library: (scm data tests)
Description: The natural logarithm of the absolute value of the gamma
  function (Lanczos approximation, about 15 digits).
Example:
  (lgamma 5) => 3.1780538303479458 ; log(24)
```

### `line-chart`

```
Syntax: (line-chart df x y [color [title]])
Library: (scm data plot)
Description: Lines of y over x, one per value of color.
Example:
  (line-chart df 'year 'cases 'kanton)
```

### `lm`

```
Syntax: (lm df formula)
Library: (scm data tests)
Description: Fits a linear model by least squares (Householder QR), as
  R's lm. formula is a list such as (y ~ x1 + x2), (y ~ .) for all other
  columns, with 0 or - 1 to drop the intercept. Non-numeric columns are
  factors, coded against their first level (sorted), named like R's
  (column name followed by the level). Rows with na are dropped. See
  lm-summary, lm-coefficients, predict and tidy.
Example:
  (lm mtcars '(mpg ~ wt + hp))
```

### `lm->string`

```
Syntax: (lm->string lm)
Library: (scm data tests)
Description: The summary of a fit as text, in the layout of R's
  print(summary(fit)).
Example:
  (display (lm->string fit))
```

### `lm-coefficients`

```
Syntax: (lm-coefficients lm)
Library: (scm data tests)
Description: The coefficients as an alist (term name . estimate).
Example:
  (lm-coefficients (lm df '(y ~ x)))
```

### `lm-fitted`

```
Syntax: (lm-fitted lm)
Library: (scm data tests)
Description: The fitted values as a list.
Example:
  (lm-fitted fit)
```

### `lm-print`

```
Syntax: (lm-print lm [port])
Library: (scm data tests)
Description: Writes the summary of a fit like R prints summary(fit).
Example:
  (lm-print fit)
```

### `lm-residuals`

```
Syntax: (lm-residuals lm)
Library: (scm data tests)
Description: The residuals as a list.
Example:
  (lm-residuals fit)
```

### `lm-simple`

```
Syntax: (lm-simple xs ys)
Library: (scm data stats)
Description: Least-squares line y = intercept + slope * x; returns an
  alist ((intercept . a) (slope . b) (r2 . r²) (n . pairs)).
Example:
  (lm-simple '(1 2 3) '(2 4 6)) => ((intercept . 0.0) (slope . 2.0) (r2 . 1.0) (n . 3))
```

### `lm-summary`

```
Syntax: (lm-summary lm)
Library: (scm data tests)
Description: The summary of a fit, as R's summary.lm, as an alist:
  coefficients (a frame: term estimate std-error statistic p-value),
  sigma (residual standard error), df, r-squared, adj-r-squared,
  f-statistic, f-df1, f-df2, f-p-value.
Example:
  (cdr (assq 'r-squared (lm-summary fit)))
```

### `lm?`

*(no documentation)*

### `make-df`

```
Syntax: (make-df columns)
Library: (scm data frame)
Description: A frame from an alist of (name . values), values being a
  vector or a list. A single non-list value is recycled to the length of
  the other columns.
Example:
  (df-nrow (make-df '((a . #(1 2 3)) (b . ("x" "y" "z"))))) => 3
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

### `make-report`

```
Syntax: (make-report blocks)
Library: (scm data report)
Description: A report from a list of blocks (the procedure behind the
  report macro).
Example:
  (make-report (list '(title "Hello") (list 'table df)))
```

### `mean`

```
Syntax: (mean xs)
Library: (scm data stats)
Description: The arithmetic mean (inexact); na if there are no values.
Example:
  (mean #(1 2 3 4)) => 2.5
```

### `median`

```
Syntax: (median xs)
Library: (scm data stats)
Description: The median (middle value, or mean of the two middle values).
Example:
  (median '(3 1 2 10)) => 5/2
```

### `mutate`

*(no documentation)*

### `na`

*(no documentation)*

### `na-string`

*(no documentation)*

### `na?`

```
Syntax: (na? x)
Library: (scm data core)
Description: True if x is the missing value na. Data frames use na for
  missing cells; aggregates skip it, arithmetic with it yields na.
Example:
  (na? na) => #t
  (na? 0)  => #f
```

### `oneway-test`

```
Syntax: (oneway-test df '(y ~ g) option ...) or (oneway-test samples option ...)
Library: (scm data tests)
Description: Test of equal means in k groups, as R's oneway.test: Welch's
  F test, or the classic one-way ANOVA F test with 'var-equal #t.
  samples is a list of lists of numbers.
Example:
  (oneway-test '((1 2 3) (2 3 4) (5 6 7)) 'var-equal #t)
```

### `p-adjust`

```
Syntax: (p-adjust p-values [method])
Library: (scm data tests)
Description: Adjusts p-values for multiple comparisons, as R's p.adjust:
  holm (default), hochberg, bonferroni, BH (or fdr), BY or none.
  Returns a list in the input order; na stays na.
Example:
  (p-adjust '(0.01 0.02 0.03) 'bonferroni) => (0.03 0.06 0.09)
```

### `parse-cell`

```
Syntax: (parse-cell string type [decimal-char])
Library: (scm data core)
Description: Converts a string to a value of the given column type (int,
  real, bool, date, symbol, string). Returns na when the string can't be
  read as that type. decimal-char (default #\.) is the decimal separator.
Example:
  (parse-cell "1,5" 'real #\,) => 1.5
```

### `pbeta`

```
Syntax: (pbeta q a b [lower?])
Library: (scm data tests)
Description: The distribution function of the beta distribution.
Example:
  (pbeta 0.5 2 3) => 0.6875
```

### `pbeta-regularized`

```
Syntax: (pbeta-regularized x a b [upper?])
Library: (scm data tests)
Description: The regularized incomplete beta function I_x(a, b), or
  1 - I_x(a, b) with upper? #t (computed as I_{1-x}(b, a)).
Example:
  (pbeta-regularized 0.5 2 2) => 0.5
```

### `pbinom`

```
Syntax: (pbinom q n p [lower?])
Library: (scm data tests)
Description: The binomial distribution function P(X <= q); with lower?
  #f P(X > q).
Example:
  (pbinom 2 4 0.5) => 0.6875
```

### `pchisq`

```
Syntax: (pchisq q df [lower?])
Library: (scm data tests)
Description: The distribution function of the chi-squared distribution;
  (pchisq q df #f) is the p-value of a chi-squared statistic.
Example:
  (pchisq 3.841459 1 #f) => 0.05
```

### `pct-change`

```
Syntax: (pct-change from to)
Library: (scm data stats)
Description: The relative change (to - from) / from as a fraction; na if
  from is 0 or a value is na.
Example:
  (pct-change 200 250) => 0.25
```

### `pf`

```
Syntax: (pf q df1 df2 [lower?])
Library: (scm data tests)
Description: The distribution function of the F distribution.
Example:
  (pf 4.964603 1 10 #f) => 0.05
```

### `pgamma-regularized`

```
Syntax: (pgamma-regularized a x [upper?])
Library: (scm data tests)
Description: The regularized incomplete gamma function P(a, x), or
  Q(a, x) = 1 - P(a, x) with upper? #t, each computed directly so that
  small tail values keep their precision.
Example:
  (pgamma-regularized 1 1) => 0.6321205588285577
```

### `pivot-longer`

*(no documentation)*

### `pivot-wider`

*(no documentation)*

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

### `pnorm`

```
Syntax: (pnorm q [mean sd [lower?]])
Library: (scm data tests)
Description: The normal distribution function P(X <= q); with lower? #f
  the upper tail P(X > q).
Example:
  (pnorm 1.96) => 0.9750021048517795
```

### `ppois`

```
Syntax: (ppois q lambda [lower?])
Library: (scm data tests)
Description: The Poisson distribution function P(X <= q).
Example:
  (ppois 2 1) => 0.9196986029286058
```

### `predict`

```
Syntax: (predict lm df)
Library: (scm data tests)
Description: The predictions of a fit for the rows of df (a vector; na
  where a predictor is na or a factor level is unknown).
Example:
  (predict fit (tibble (wt 3.0) (hp 120)))
```

### `prop-test`

```
Syntax: (prop-test successes trials option ...)
Library: (scm data tests)
Description: The test of equal (or given) proportions, as R's prop.test:
  successes and trials are numbers (one group) or lists (k groups).
  One group gets Wilson's score interval, two groups the interval of the
  difference, both with continuity correction (k <= 2) unless
  'correct #f. Options: 'p (null proportion(s)), 'alternative,
  'conf-level, 'correct.
Example:
  (prop-test '(83 90 129 70) '(86 93 136 82))
```

### `pt`

```
Syntax: (pt q df [lower?])
Library: (scm data tests)
Description: The distribution function of Student's t distribution.
Example:
  (pt 2.228139 10) => 0.975
```

### `pull`

*(no documentation)*

### `qbeta`

```
Syntax: (qbeta p a b [lower?])
Library: (scm data tests)
Description: The quantile function of the beta distribution.
Example:
  (qbeta 0.5 2 2) => 0.5
```

### `qbinom`

```
Syntax: (qbinom p n prob [lower?])
Library: (scm data tests)
Description: The smallest k with P(X <= k) >= p.
Example:
  (qbinom 0.5 10 0.5) => 5
```

### `qchisq`

```
Syntax: (qchisq p df [lower?])
Library: (scm data tests)
Description: The quantile function of the chi-squared distribution.
Example:
  (qchisq 0.95 1) => 3.841458820694124
```

### `qf`

```
Syntax: (qf p df1 df2 [lower?])
Library: (scm data tests)
Description: The quantile function of the F distribution.
Example:
  (qf 0.95 1 10) => 4.9646027437307
```

### `qnorm`

```
Syntax: (qnorm p [mean sd [lower?]])
Library: (scm data tests)
Description: The normal quantile function (Wichura's AS241).
Example:
  (qnorm 0.975) => 1.959963984540054
```

### `qt`

```
Syntax: (qt p df [lower?])
Library: (scm data tests)
Description: The quantile function of Student's t distribution.
Example:
  (qt 0.975 10) => 2.2281388519649385
```

### `quantile`

```
Syntax: (quantile xs p)
Library: (scm data stats)
Description: The p-quantile (0 <= p <= 1) with linear interpolation (R's
  type 7, also pandas' default); p may be a list, giving a list.
Example:
  (quantile '(1 2 3 4) 0.25) => 1.75
```

### `query-result->df`

```
Syntax: (query-result->df result option ...)
Library: (scm data io)
Description: A frame from a database query result of (scm database
  postgres) pg-query or (scm database sqlserver) ss-query: column names
  from the result, NULL as na, values converted by type inference or
  'col-types (other options as strings->df).
Example:
  (query-result->df (pg-query conn "SELECT splg, pts FROM mfzo_summary"))
```

### `ranks`

```
Syntax: (ranks xs [ties])
Library: (scm data stats)
Description: The rank of each value (1 = smallest) as a list; ties is
  average (default, as R's rank), min or dense. na stays na.
Example:
  (ranks '(10 20 10 30)) => (1.5 3 1.5 4)
```

### `read-csv`

```
Syntax: (read-csv path option ...)
Library: (scm data io)
Description: Reads a CSV file (RFC 4180: quoted fields may hold separators,
  quotes as "" and line breaks) into a frame. Options:
  'sep char (default: detected from , ; tab |), 'header #t|#f,
  'names (a b …) to name the columns, 'na ("" "NA" …) strings read as
  na, 'decimal char (#\. or #\,), 'col-types ((col . type) …),
  'skip n lines before the header, 'n-max rows to read.
Example:
  (read-csv "cases.csv" 'sep #\; 'col-types '((plz . string)))
```

### `read-csv-string`

```
Syntax: (read-csv-string string option ...)
Library: (scm data io)
Description: read-csv on a string.
Example:
  (df-nrow (read-csv-string "a,b\n1,2\n")) => 1
```

### `read-json-records`

```
Syntax: (read-json-records path)
Library: (scm data io)
Description: Reads a JSON file holding an array of objects into a frame,
  one row per object; null becomes na, arrays become list cells.
Example:
  (read-json-records "cases.json")
```

### `read-jsonl`

```
Syntax: (read-jsonl path)
Library: (scm data io)
Description: Reads JSON Lines (one object per line) into a frame.
Example:
  (read-jsonl "events.jsonl")
```

### `read-sexp-lines`

```
Syntax: (read-sexp-lines path option ...)
Library: (scm data io)
Description: Reads a file of data, one per line, each an alist of entries
  into a frame. An entry (key value) gives the cell value, (key v1 v2 …)
  a list cell, (key . value) the value, (key) the empty list. Options:
  'list-cols (k …) columns whose entries are always lists, so (k v) gives
  (v) and a missing entry the empty list; 'map proc to turn each datum
  into an alist yourself (return #f to skip it); 'names to fix the
  columns; 'add ((col . value) …) for constant columns (e.g. which run a
  file comes from).
Example:
  (read-sexp-lines "splg.scm" 'list-cols '(lgs operateure)
                   'add '((year . 2024) (model . v1)))
```

### `read-sf`

```
Syntax: (read-sf path option ...)
Library: (scm data io)
Description: Reads geometries with their attributes into a frame (see
  features->df): an ESRI shapefile (.shp, with the .dbf next to it), a
  GeoJSON FeatureCollection (.geojson, .json) or a TopoJSON topology
  (.topojson, or any JSON file of type Topology). Options: 'layer name
  (TopoJSON object, default the first), 'encoding utf-8|latin-1 (the
  shapefile's attributes, default from its .cpg file).
Example:
  (read-sf "cantons.shp" 'encoding 'latin-1)
```

### `read-xlsx`

```
Syntax: (read-xlsx path option ...)
Library: (scm data io)
Description: Reads one sheet of an XLSX file into a frame. Options:
  'sheet name or 1-based number (default 1), 'header #t|#f, 'skip rows
  before the header, 'names, 'na, 'col-types (as read-csv). Numeric
  columns stay numeric; date cells are recognised as dates.
Example:
  (read-xlsx "list.xlsx" 'sheet "Daten" 'skip 2)
```

### `relocate`

*(no documentation)*

### `rename`

*(no documentation)*

### `replace-na`

*(no documentation)*

### `report`

*(no documentation)*

### `report->html`

```
Syntax: (report->html report [toc?])
Library: (scm data report)
Description: The report as one self-contained HTML page (string): inline
  CSS with a light and a dark theme, charts as inline SVG, and a table of
  contents of the h2 headings when there are at least three (toc? #f to
  leave it out).
Example:
  (report->html doc)
```

### `report->markdown`

```
Syntax: (report->markdown report [figure-writer])
Library: (scm data report)
Description: The report as GitHub-flavoured Markdown (string). Figures are
  passed to figure-writer, (lambda (plot number) …) returning the image
  path to link (write-report sets one up that writes PNG files); without
  one, figures become a placeholder line.
Example:
  (report->markdown doc)
```

### `report->pdf`

```
Syntax: (report->pdf report [options])
Library: (scm data report)
Description: The report as a PDF document (bytevector): A4 pages with the
  text in embedded fonts, tables (header repeated after a page break,
  wide tables wrapped), figures as vector graphics, h1–h3 as bookmarks
  and a footer with the title and page numbers. options is an alist:
  (page-size . (w . h)) in points (pdf-page-size-a4 by default, see
  (scm pdf)), (margin . pt) 56, (font-size . pt) 10, (font . family) a
  family found by (scm fonts) for the text and the figures, DejaVu Sans
  by default, (mono-font . family) for code, (footer . #f) to leave the
  footer out.
Example:
  (call-with-port (open-binary-output-file "r.pdf")
    (lambda (o) (write-bytevector (report->pdf doc) o)))
```

### `rows->df`

```
Syntax: (rows->df names rows)
Library: (scm data frame)
Description: A frame from a list of rows; each row is a list or vector of
  cells in the order of names. Short rows are filled with na.
Example:
  (df-ref (rows->df '(a b) '((1 "x") (2 "y"))) 1 'b) => "y"
```

### `sample-n`

```
Syntax: (sample-n df n [seed])
Library: (scm data verbs)
Description: n rows drawn at random without replacement (in their
  original order); a seed makes the draw reproducible.
Example:
  (sample-n df 100 42)
```

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

### `script-args`

```
Syntax: (script-args spec [usage [args]])
Library: (scm data)
Description: Parses the script's key=value arguments. spec lists the
  arguments as (key . default), the type taken from the default: #t/#f
  yes/no, integers, numbers, symbols, comma lists (typed like the
  default's first element), strings otherwise; or as (key type default)
  with type string, int, number, bool, symbol, list-int, list-number,
  list-string or list-symbol, e.g. (out string #f) for an optional
  string. Returns the alist ((key . value) …) of all arguments.
  Unknown keys and help/--help print the usage (with the optional usage
  text) and exit. args defaults to the command line after the script.
Example:
  ;; scm report.scm years=2024,2025 out=rep
  (define args (script-args '((years . (2024 2025)) (out . "report") (regroup . #f))))
  (cdr (assq 'years args)) => (2024 2025)
```

### `sd`

```
Syntax: (sd xs)
Library: (scm data stats)
Description: The sample standard deviation, (sqrt (var xs)).
Example:
  (sd '(2 4 4 4 5 5 7 9)) => 2.138089935299395
```

### `select`

*(no documentation)*

### `semi-join`

*(no documentation)*

### `separate`

*(no documentation)*

### `shapiro-test`

```
Syntax: (shapiro-test x)
Library: (scm data tests)
Description: The Shapiro-Wilk normality test (Royston's algorithm, as R's
  shapiro.test) for 3 to 5000 values.
Example:
  (shapiro-test '(2.1 3.4 1.9 5.6 4.4 3.3 2.8))
```

### `slice`

```
Syntax: (df-slice df start [end])
Library: (scm data verbs)
Description: Rows start (inclusive, 0-based) to end (exclusive, default
  the last row), like substring. Also: (slice df start [end]).
Example:
  (slice df 0 10)
```

### `string->day`

```
Syntax: (string->day s)
Library: (scm data core)
Description: Parses an ISO date "YYYY-MM-DD" (also "YYYYMMDD" and the
  Swiss "DD.MM.YYYY"); returns #f when s is not such a date.
Example:
  (day->ymd (string->day "11.03.2024")) => (2024 3 11)
```

### `strings->df`

```
Syntax: (strings->df names string-vectors opts)
Library: (scm data io)
Description: Builds a frame from columns of strings, converting each column
  by type inference or by 'col-types; honours 'na and 'decimal like
  read-csv. Used by the readers; handy for other text sources (SQL results).
Example:
  (df-types (strings->df '(a) (list (vector "1" "2")) '())) => ((a . int))
```

### `sum`

```
Syntax: (sum xs)
Library: (scm data stats)
Description: The sum of the numbers in the list or vector xs (na skipped).
Example:
  (sum (list 1 2 na 3)) => 6
```

### `summarise`

*(no documentation)*

### `summarize`

*(no documentation)*

### `t-test`

```
Syntax: (t-test x [y] option ...) or (t-test df '(y ~ g) option ...)
Library: (scm data tests)
Description: Student's t test, as R's t.test: one sample (x alone), two
  samples (Welch unless 'var-equal #t), or paired ('paired #t). With a
  frame and a formula (y ~ g), g must have two levels; (y ~ 1) is the
  one-sample test. Options: 'alternative two-sided|less|greater, 'mu 0,
  'paired #f, 'var-equal #f, 'conf-level 0.95. na values are dropped
  (pairwise when paired).
Example:
  (t-test '(0.7 -1.6 -0.2) '(1.9 0.8 1.1) 'var-equal #t)
```

### `tail`

*(no documentation)*

### `tally`

*(no documentation)*

### `tibble`

*(no documentation)*

### `tidy`

```
Syntax: (tidy htest-or-lm)
Library: (scm data tests)
Description: A test result as a one-row frame in the style of broom's
  tidy: estimate (for two estimates their difference, then estimate1 and
  estimate2), statistic, p-value, parameter (df1/df2 for two), conf-low,
  conf-high, method and alternative; columns without a value are left
  out. For an lm fit, the coefficient table.
Example:
  (tidy (t-test '(1 2 3 4)))
```

### `transmute`

*(no documentation)*

### `ungroup`

*(no documentation)*

### `unnest-longer`

*(no documentation)*

### `value-range`

```
Syntax: (value-range xs)
Library: (scm data stats)
Description: The list (min max) of the numbers, #f if there are none.
Example:
  (value-range (list 3 na 1 7)) => (1 7)
```

### `value-type`

```
Syntax: (value-type x)
Library: (scm data core)
Description: The data type of one value: na, int (exact integer), real
  (any other real number), string, bool, date, symbol, list or other.
Example:
  (value-type 1.5) => real
```

### `value<?`

```
Syntax: (value<? a b)
Library: (scm data expr)
Description: Total order used for sorting and grouping: numbers, strings,
  symbols and dates in their natural order, #f before #t; values of
  different types by type; na sorts last.
Example:
  (value<? "a" "b") => #t
```

### `value=?`

*(no documentation)*

### `var`

```
Syntax: (var xs)
Library: (scm data stats)
Description: The sample variance (divided by n-1); na for fewer than 2
  values.
Example:
  (var '(1 2 3 4)) => 1.6666666666666667
```

### `weighted-mean`

```
Syntax: (weighted-mean xs weights)
Library: (scm data stats)
Description: The mean of xs weighted by ws (pairs with a na are skipped).
Example:
  (weighted-mean '(1 3) '(3 1)) => 1.5
```

### `where`

*(no documentation)*

### `wilcox-test`

```
Syntax: (wilcox-test x [y] option ...) or (wilcox-test df '(y ~ g) option ...)
Library: (scm data tests)
Description: The Wilcoxon signed-rank test (x alone, or paired) or rank-sum
  (Mann-Whitney) test, as R's wilcox.test: exact p-values below 50
  observations without ties (and zeros), else the normal approximation
  with tie correction and continuity correction. Options: 'alternative,
  'mu 0, 'paired #f, 'exact 'auto|#t|#f, 'correct #t.
Example:
  (wilcox-test '(1 2 3) '(4 5 6 7))
```

### `with-timing`

```
Syntax: (with-timing label thunk)
Library: (scm data)
Description: Calls thunk, prints label and the elapsed seconds to the
  current output port, and returns thunk's result.
Example:
  (define cases (with-timing "read" (lambda () (read-csv "cases.csv"))))
```

### `write-csv`

```
Syntax: (write-csv df path option ...)
Library: (scm data io)
Description: Writes a frame as CSV (header row, CRLF line ends, fields
  quoted when needed). Options: 'sep char (default #\,), 'decimal char,
  'na string for missing cells (default ""), 'bom #t to start with a
  UTF-8 byte order mark (so Excel detects UTF-8).
Example:
  (write-csv df "out.csv" 'sep #\; 'decimal #\, 'bom #t)
```

### `write-geojson`

```
Syntax: (write-geojson df path [geometry-column])
Library: (scm data io)
Description: Writes a frame with a geometry column as a GeoJSON
  FeatureCollection (see df->features).
Example:
  (write-geojson regions "regions.geojson")
```

### `write-json-records`

```
Syntax: (write-json-records df path [pretty?])
Library: (scm data io)
Description: Writes a frame as a JSON array of objects (na as null, dates
  as ISO strings, list cells as arrays).
Example:
  (write-json-records df "out.json" #t)
```

### `write-jsonl`

*(no documentation)*

### `write-report`

```
Syntax: (write-report report path [figure-format])
Library: (scm data report)
Description: Writes the report to path, as HTML (.html), Markdown (.md)
  or PDF (.pdf, see report->pdf). For Markdown, figures are written next
  to the file as
  <name>-fig<n>.png (figure-format png, the default) or .svg, and linked.
Example:
  (write-report doc "report.html")
  (write-report doc "report.md" 'svg)
```

### `write-sexp-lines`

```
Syntax: (write-sexp-lines df path)
Library: (scm data io)
Description: Writes each row as one line ((column value) …), the format
  read-sexp-lines reads back; list cells are written as (column v1 v2 …),
  na cells are left out, dates are written as ISO strings.
Example:
  (write-sexp-lines df "rows.scm")
```

### `write-xlsx`

```
Syntax: (write-xlsx df-or-sheets path option ...)
Library: (scm data io)
Description: Writes one frame, or several given as an alist
  (("Sheet name" . df) …), to an XLSX file: bold header row with an
  AutoFilter, the header frozen, column widths fitted to the content,
  numbers as numeric cells, na as empty cells, dates as ISO text.
  Option 'sheet-name for a single frame (default "Data").
Example:
  (write-xlsx `(("2024" . ,df24) ("2025" . ,df25)) "points.xlsx")
```

### `ymd->day`

```
Syntax: (ymd->day year month day)
Library: (scm data core)
Description: The date for a year, month (1-12) and day of month.
Example:
  (day-number (ymd->day 1970 1 2)) => 1
```

### `zscore`

```
Syntax: (zscore xs)
Library: (scm data stats)
Description: The standardised values (x - mean) / sd, as a list.
Example:
  (zscore '(1 2 3)) => (-1.0 0.0 1.0)
```


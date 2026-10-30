# `(scm data verbs)`

dplyr/tidyr-style data-frame verbs — where, mutate, summarise, joins, pivots

## Overview

dplyr/tidyr-style operations. Each is a macro (columns as bare names, Scheme
values via unquote) and a procedure (`df-…`, with quoted expressions). `->`
threads a frame through a pipeline.

| Rows | `where` `arrange` `distinct` `head` `tail` `slice` `sample-n` |
|---|---|
| Columns | `select` `rename` `mutate` `transmute` `relocate` `pull` |
| Groups | `group-by` `ungroup` `summarise` `tally` `add-count` |
| Combining | `left-join` `inner-join` `full-join` `semi-join` `anti-join` `bind-rows` `bind-cols` |
| Reshaping | `pivot-longer` `pivot-wider` `unnest-longer` `separate` |
| Missing | `drop-na` `replace-na` `fill-down` `fill-up` |

## Common uses

```scheme
(-> pts
    (where (in splg ,mfzo-splgs))
    (group-by splg year model)
    (summarise (points (sum points)))
    (pivot-wider (names-from year model) (values-from points))
    (left-join limits (by splg)))
```


## Exports

### `->`

*(no documentation)*

### `add-count`

*(no documentation)*

### `anti-join`

*(no documentation)*

### `arrange`

*(no documentation)*

### `bind-cols`

*(no documentation)*

### `bind-rows`

*(no documentation)*

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

### `df-head`

```
Syntax: (head df [n])
Library: (scm data verbs)
Description: The first n rows (default 6).
Example:
  (head df 3)
```

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

### `df-pull`

```
Syntax: (df-pull df col)
Library: (scm data verbs)
Description: The values of one column as a list. Macro form: (pull df col).
Example:
  (pull df splg) => (BEW8 GYN2)
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

### `df-replace-na`

```
Syntax: (df-replace-na df pairs)
Library: (scm data verbs)
Description: Replaces na in the given columns; pairs is ((col . value) …).
  Macro form: (replace-na df (col value) …).
Example:
  (replace-na df (pts 0))
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

### `df-transmute`

*(no documentation)*

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

### `distinct`

*(no documentation)*

### `drop-na`

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

### `fill-down`

*(no documentation)*

### `fill-up`

*(no documentation)*

### `full-join`

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

### `inner-join`

*(no documentation)*

### `left-join`

*(no documentation)*

### `mutate`

*(no documentation)*

### `pivot-longer`

*(no documentation)*

### `pivot-wider`

*(no documentation)*

### `pull`

*(no documentation)*

### `relocate`

*(no documentation)*

### `rename`

*(no documentation)*

### `replace-na`

*(no documentation)*

### `sample-n`

```
Syntax: (sample-n df n [seed])
Library: (scm data verbs)
Description: n rows drawn at random without replacement (in their
  original order); a seed makes the draw reproducible.
Example:
  (sample-n df 100 42)
```

### `select`

*(no documentation)*

### `semi-join`

*(no documentation)*

### `separate`

*(no documentation)*

### `slice`

```
Syntax: (df-slice df start [end])
Library: (scm data verbs)
Description: Rows start (inclusive, 0-based) to end (exclusive, default
  the last row), like substring. Also: (slice df start [end]).
Example:
  (slice df 0 10)
```

### `summarise`

*(no documentation)*

### `summarize`

*(no documentation)*

### `tail`

*(no documentation)*

### `tally`

*(no documentation)*

### `transmute`

*(no documentation)*

### `ungroup`

*(no documentation)*

### `unnest-longer`

*(no documentation)*

### `where`

*(no documentation)*


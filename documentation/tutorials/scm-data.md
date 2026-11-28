---
title: "(scm data): data frames and verbs"
part: libraries
order: 1033
libraries: (scm data) (scm data frame) (scm data verbs) (scm data expr) (scm data core)
summary: Tables as data frames, reading CSV, column types and missing values, filtering, choosing and computing columns, sorting, pipelines, grouping and summarising, the expression language with Scheme values spliced in, dates, a sales analysis from raw rows to a summary table.
---
# (scm data): data frames and verbs

`(scm data)` is a toolkit for analysis scripts in the style of R's
tidyverse and pandas: read a table, transform it, summarise it, chart it,
write a report. This chapter covers the table itself and the *verbs* that
transform it. Joins and reshaping, statistics, tests, charts and reports
have chapters of their own (see the end).

```scheme
(import (scheme base) (scheme write) (scm data))
```

One import brings all the `(scm data …)` libraries.

## A data frame

A data frame is a table of named columns of equal length. `tibble` makes
one column by column, and `df-print` shows it with the column types:

```scheme
(define teas
  (tibble (tea "Sencha" "Assam" "Matcha" "Rooibos")
          (origin "Japan" "India" "Japan" "South Africa")
          (price 48 22 160 18)))

(df-print teas)
;; prints: # A data frame: 4 × 3
;; prints:   tea      origin        price
;; prints:   <chr>    <chr>         <int>
;; prints: 1 Sencha   Japan            48
;; prints: 2 Assam    India            22
;; prints: 3 Matcha   Japan           160
;; prints: 4 Rooibos  South Africa     18

(df-names teas)                             ;; => (tea origin price)
(df-nrow teas)                              ;; => 4
(df-column teas 'price)                     ;; => #(48 22 160 18)
(df-row teas 2)                             ;; => ((tea . "Matcha") (origin . "Japan") (price . 160))
```

Columns are vectors, rows come out as alists. A frame never changes:
every operation returns a new one (sharing the columns it did not
touch), so a frame can be passed around without copying.

`alists->df` builds a frame from rows, the shape data often arrives in:

```scheme
(df-nrow (alists->df '(((tea . "Gyokuro") (price . 95)) ((tea . "Bancha") (price . 14))))) ;; => 2
```

## Reading CSV

Real data comes from files. `read-csv` reads a file, `read-csv-string`
text; the column types are inferred:

```scheme
(define sales
  (read-csv-string
   "date,shop,tea,kg,plz
2025-03-03,Zurich,Sencha,2.5,8001
2025-03-03,Bern,Assam,1,3011
2025-03-04,Zurich,Assam,4,8001
2025-03-04,Basel,Sencha,1.5,4051
2025-03-05,Bern,Rooibos,3,3011
2025-03-05,Zurich,Matcha,0.5,8001
2025-03-06,Basel,Assam,,4051
2025-03-07,Zurich,Sencha,2,8001
2025-03-07,Bern,Sencha,1,3011
"))

(df-types sales)                            ;; => ((date . date) (shop . string) (tea . string) (kg . real) (plz . int))
```

- ISO dates become dates, numbers become integers or reals.
- The empty `kg` on 6 March is a *missing value*, `na`.
- A value with a leading zero (`"08001"`) would stay a string, so
  codes do not lose their zeros. `'col-types '((plz . string))` sets a
  type explicitly; postcodes are codes, not quantities.

`read-csv` takes `'sep #\;` and `'decimal #\,` for the European variant
of CSV. The [I/O chapter](scm-data-io.md) has the other formats.

## Missing values

`na` is a value of its own. In the expressions of the verbs (below),
arithmetic and comparisons with it give `na`; summaries skip it:

```scheme
(na? (vector-ref (df-column sales 'kg) 6)) ;; => #t
(sum (df-column sales 'kg))                ;; => 15.5
(mean (list 1 2 na 3))                     ;; => 2.0
(na? (vector-ref (df-column (mutate sales (grams (* 1000 kg))) 'grams) 6)) ;; => #t
```

Outside the verbs `na` is an ordinary Scheme value: `(+ 1 na)` is an
error, so test with `na?` first.

## Rows: where, arrange, head

`where` keeps the rows for which a condition holds. Inside a verb a bare
name is a column:

```scheme
(df-print (where sales (= shop "Zurich") (>= kg 2)))
;; prints: # A data frame: 3 × 5
;; prints:   date        shop    tea        kg    plz
;; prints:   <date>      <chr>   <chr>   <dbl>  <int>
;; prints: 1 2025-03-03  Zurich  Sencha    2.5   8001
;; prints: 2 2025-03-04  Zurich  Assam       4   8001
;; prints: 3 2025-03-07  Zurich  Sencha      2   8001
```

Several conditions must all hold. A row whose condition is `na` (the
missing `kg`) is dropped. `arrange` sorts, `desc` reverses a key, and
`head` takes the first rows:

```scheme
(df-print (head (arrange sales (desc kg)) 3))
;; prints: # A data frame: 3 × 5
;; prints:   date        shop    tea         kg    plz
;; prints:   <date>      <chr>   <chr>    <dbl>  <int>
;; prints: 1 2025-03-04  Zurich  Assam        4   8001
;; prints: 2 2025-03-05  Bern    Rooibos      3   3011
;; prints: 3 2025-03-03  Zurich  Sencha     2.5   8001
```

`slice`, `tail`, `distinct` and `sample-n` are the other row verbs.

## Columns: select, mutate, rename

```scheme
(define with-price (left-join sales teas (by tea)))

(df-print (-> with-price
              (mutate (revenue (* kg price)))
              (select date shop tea revenue)
              (head 3)))
;; prints: # A data frame: 3 × 4
;; prints:   date        shop    tea     revenue
;; prints:   <date>      <chr>   <chr>     <dbl>
;; prints: 1 2025-03-03  Zurich  Sencha      120
;; prints: 2 2025-03-03  Bern    Assam        22
;; prints: 3 2025-03-04  Zurich  Assam        88
```

`left-join` added the price of each tea from the first table (more on
joins in the [next chapter](scm-data-reshape.md)). `mutate` computes a
column per row, `select` keeps columns in the given order. `->` threads
the frame through the steps: each step gets the result of the one
before as its first argument. Read it as "then".

## Groups: group-by and summarise

`summarise` reduces rows to one per group:

```scheme
(df-print (-> with-price
              (mutate (revenue (* kg price)))
              (group-by shop)
              (summarise (sales (n)) (kg (sum kg)) (revenue (sum revenue)))
              (arrange (desc revenue))))
;; prints: # A data frame: 3 × 4
;; prints:   shop    sales     kg  revenue
;; prints:   <chr>   <int>  <dbl>    <dbl>
;; prints: 1 Zurich      4      9      384
;; prints: 2 Bern        3      5      124
;; prints: 3 Basel       2    1.5       72
```

`(n)` counts the rows of the group. `tally` is the short form of counting
alone:

```scheme
(df-print (tally (group-by sales tea)))
;; prints: # A data frame: 4 × 2
;; prints:   tea          n
;; prints:   <chr>    <int>
;; prints: 1 Assam        3
;; prints: 2 Matcha       1
;; prints: 3 Rooibos      1
;; prints: 4 Sencha       4
```

On a grouped frame `mutate` computes per group, so aggregates refer to
the group, for example each sale's share of its shop's kilograms, in
per cent:

```scheme
(df-column (-> sales (drop-na kg) (group-by shop) (mutate (pct (round (* 100 (/ kg (sum kg)))))))
           'pct)
;; => #(28.0 20.0 44.0 100.0 60.0 6.0 22.0 20.0)
```

## The expression language

The expressions inside verbs are not ordinary Scheme: they are compiled
once and then run per row, with bare names standing for columns. The
vocabulary has arithmetic and comparisons, `and`/`or`/`not`, `if`,
`case-when`, `in`, `coalesce`, string functions (`str-upper`,
`str-detect`, `str-sub` …), date functions (`year`, `weekday`,
`days-between` …), aggregates (`n` `sum` `mean` `median` `sd` `min`
`max` …) and window functions (`lag` `cumsum` `rank` …):

```scheme
(df-print (-> sales
              (mutate (size (case-when ((< kg 1) 'small) ((< kg 3) 'medium) (else 'large)))
                      (day (weekday date)))
              (where (in tea ("Sencha" "Matcha")))
              (select tea kg size day)))
;; prints: # A data frame: 5 × 4
;; prints:   tea        kg  size      day
;; prints:   <chr>   <dbl>  <sym>   <int>
;; prints: 1 Sencha    2.5  medium      1
;; prints: 2 Sencha    1.5  medium      2
;; prints: 3 Matcha    0.5  small       3
;; prints: 4 Sencha      2  medium      5
;; prints: 5 Sencha      1  medium      5
```

`weekday` counts Monday as 1. `case-when` takes the first branch whose
condition is true; a missing value makes a condition false, so a row
with no `kg` would land in `else`, as in R.

A Scheme value from outside goes in with unquote, and `(,proc …)` calls a
Scheme procedure per row:

```scheme
(define minimum 2)
(define (label shop kg) (string-append shop ": " (number->string kg) " kg"))

(df-column (-> sales (where (>= kg ,minimum)) (mutate (text (,label shop kg)))) 'text)
;; => #("Zurich: 2.5 kg" "Zurich: 4.0 kg" "Bern: 3.0 kg" "Zurich: 2.0 kg")
```

Without the comma, `minimum` would be taken for a column, and there is
none of that name:

```scheme
(where sales (>= kg minimum))               ;; => error
```

## Dates

A date is a day number; the date functions work on it, and comparisons
work as for numbers:

```scheme
(define d (string->day "2025-03-05"))
(day->string d)                             ;; => "2025-03-05"
(day->ymd d)                                ;; => (2025 3 5)
(day->string (ymd->day 2025 12 24))         ;; => "2025-12-24"
(day->string (string->day "24.12.2025"))    ;; => "2025-12-24"

(df-nrow (where sales (>= date ,(string->day "2025-03-05")))) ;; => 5
(df-column (-> sales (mutate (age (days-between date ,(ymd->day 2025 3 7)))) (head 2)) 'age) ;; => #(4 4)
```

## Example: what sold on which day

Raw sales rows to a weekday summary, the kind of table that ends up in a
report: kilograms per weekday, the best-selling tea of each day, and the
day's share of the week.

```scheme
(define day-names #("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun"))
(define (day-name n) (vector-ref day-names (- n 1)))

(define per-day
  (-> sales
      (drop-na kg)
      (mutate (day (,day-name (weekday date))))
      (group-by day tea)
      (summarise (kg (sum kg)))
      (group-by day)
      (mutate (best (= kg (max kg))))
      (where best)
      (ungroup)
      (select day tea kg)))

(df-print per-day)
;; prints: # A data frame: 4 × 3
;; prints:   day    tea         kg
;; prints:   <chr>  <chr>    <dbl>
;; prints: 1 Fri    Sencha       3
;; prints: 2 Mon    Sencha     2.5
;; prints: 3 Tue    Assam        4
;; prints: 4 Wed    Rooibos      3
```

The second `group-by` regroups the per-tea sums by day, so `(max kg)` is
the maximum of the day, and `where` keeps that row. Thursday is missing:
its only sale has no weight and was dropped. `summarise` sorts by
its groups, which puts the days in alphabetical order; to get them in
calendar order, keep the weekday number and sort by it.

## Building verbs at run time

Each verb is a macro, and has a procedure behind it that takes the
expressions as data: `df-filter`, `df-mutate`, `df-summarise`,
`df-arrange`, `df-select` … They are for code that builds an analysis
from a configuration or user input:

```scheme
(define rules '((>= kg 2) (= shop "Zurich")))
(df-nrow (df-filter sales rules))           ;; => 3
(df-column (df-mutate (head sales 2) '((grams . (* 1000 kg)))) 'grams) ;; => #(2500.0 1000.0)
```

## Where next

- [Joining and reshaping](scm-data-reshape.md): joins, pivots, missing
  values, window functions, your own functions.
- [Statistics and formatting](scm-data-stats.md),
  [hypothesis tests](scm-data-tests.md), [reading and writing
  data](scm-data-io.md), [charts and maps](scm-data-plot.md),
  [reports](scm-data-report.md), [clustering](scm-data-cluster.md),
  [R translation](scm-data-r.md).
- Reference: `(scm data)`, `(scm data frame)`, `(scm data verbs)`,
  `(scm data expr)`, `(scm data core)`.

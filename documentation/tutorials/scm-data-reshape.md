---
title: "(scm data): joining and reshaping"
part: libraries
order: 1034
libraries: (scm data verbs) (scm data expr)
summary: Joins on one or several keys and differently named keys, keeping or removing matches, stacking frames; long and wide shapes with pivot-longer and pivot-wider; list columns, splitting text columns; missing values; window functions per group; your own expression functions; splitting a frame by group.
---
# (scm data): joining and reshaping

The [first data chapter](scm-data.md) covers frames and the basic verbs.
This one combines tables and changes their shape.

```scheme
(import (scheme base) (scheme write) (scm data))

(define orders
  (tibble (order 1 2 3 4)
          (customer "ada" "alan" "ada" "grace")
          (tea "Sencha" "Assam" "Oolong" "Sencha")
          (kg 2 1 1 3)))

(define customers
  (tibble (customer "ada" "alan" "edsger")
          (city "London" "Manchester" "Austin")))
```

## Joins

A join adds the columns of a second table to the rows of the first that
match on a key. `left-join` keeps every row of the first table; where
there is no match the new columns are `na`:

```scheme
(df-print (left-join orders customers (by customer)))
;; prints: # A data frame: 4 × 5
;; prints:   order  customer  tea        kg  city
;; prints:   <int>  <chr>     <chr>   <int>  <chr>
;; prints: 1     1  ada       Sencha      2  London
;; prints: 2     2  alan      Assam       1  Manchester
;; prints: 3     3  ada       Oolong      1  London
;; prints: 4     4  grace     Sencha      3  NA
```

The other joins differ in which rows they keep:

| join | keeps |
|---|---|
| `left-join` | every row of the first table |
| `inner-join` | rows with a match in both |
| `full-join` | every row of both |
| `semi-join` | rows of the first that have a match, without adding columns |
| `anti-join` | rows of the first that have *no* match |

```scheme
(df-nrow (inner-join orders customers (by customer))) ;; => 3
(df-nrow (full-join orders customers (by customer)))  ;; => 5
(df-column (semi-join customers orders (by customer)) 'customer) ;; => #("ada" "alan")
(df-column (anti-join customers orders (by customer)) 'customer) ;; => #("edsger")
(df-column (anti-join orders customers (by customer)) 'customer) ;; => #("grace")
```

The anti-joins answer the questions data checks ask: which customers
never ordered, which orders name a customer we do not know.

When the key has different names in the two tables, pair them up; with
several keys, list them all:

```scheme
(define prices (tibble (name "Sencha" "Assam") (chf 48 22)))
(define (show-na v) (vector-map (lambda (x) (if (na? x) 'missing x)) v))
(show-na (df-column (left-join orders prices (by (tea . name))) 'chf)) ;; => #(48 22 missing 48)
```

`(by shop year)` joins on two columns. If a key occurs several times in
the second table, the row of the first is repeated for each match, as in
SQL: check keys that should be unique with `tally` first.

## Stacking

`bind-rows` puts frames under each other, matching columns by name; a
column missing in one of them is `na` there. `bind-cols` puts them side
by side:

```scheme
(df-print (bind-rows (tibble (tea "Sencha") (kg 2))
                     (tibble (tea "Assam") (shop "Bern"))))
;; prints: # A data frame: 2 × 3
;; prints:   tea        kg  shop
;; prints:   <chr>   <int>  <chr>
;; prints: 1 Sencha      2  NA
;; prints: 2 Assam      NA  Bern
```

## Long and wide

The same numbers can be laid out *wide*, one column per month, as people
like to read them, or *long*, one row per measurement, as the verbs and
charts like to work with them:

```scheme
(define monthly (tibble (tea "Sencha" "Assam") (jan 10 4) (feb 12 na) (mar 9 6)))

(define long (pivot-longer monthly (cols jan feb mar) (names-to month) (values-to kg)))
(df-print long)
;; prints: # A data frame: 6 × 3
;; prints:   tea     month     kg
;; prints:   <chr>   <sym>  <int>
;; prints: 1 Sencha  jan       10
;; prints: 2 Sencha  feb       12
;; prints: 3 Sencha  mar        9
;; prints: 4 Assam   jan        4
;; prints: 5 Assam   feb       NA
;; prints: 6 Assam   mar        6
```

The old column names become values of `month` (as symbols, since column
names are symbols). `pivot-wider` goes back:

```scheme
(df-print (pivot-wider long (names-from month) (values-from kg)))
;; prints: # A data frame: 2 × 4
;; prints:   tea       jan    feb    mar
;; prints:   <chr>   <int>  <int>  <int>
;; prints: 1 Sencha     10     12      9
;; prints: 2 Assam       4     NA      6
```

A typical round trip: summarise in long form, then widen for the
report table, with `(values-fill 0)` for combinations that do not
occur:

```scheme
(df-print (-> orders
              (group-by tea customer)
              (summarise (kg (sum kg)))
              (pivot-wider (names-from customer) (values-from kg) (values-fill 0))))
;; prints: # A data frame: 3 × 4
;; prints:   tea      alan    ada  grace
;; prints:   <chr>   <int>  <int>  <int>
;; prints: 1 Assam       1      0      0
;; prints: 2 Oolong      0      1      0
;; prints: 3 Sencha      0      2      3
```

The new columns come in the order their names first appear in the data;
`select` puts them in another.

## Lists in cells, text to split

A cell may hold a list. `unnest-longer` gives each element a row of its
own, and `separate` splits a text column at a separator:

```scheme
(df-print (unnest-longer (tibble (order 1 2) (teas '("Sencha" "Assam") '("Matcha"))) teas))
;; prints: # A data frame: 3 × 2
;; prints:   order  teas
;; prints:   <int>  <chr>
;; prints: 1     1  Sencha
;; prints: 2     1  Assam
;; prints: 3     2  Matcha

(df-print (separate (tibble (code "ZH-8001" "BE-3011")) code (into canton plz) (sep "-")))
;; prints: # A data frame: 2 × 2
;; prints:   canton  plz
;; prints:   <chr>   <chr>
;; prints: 1 ZH      8001
;; prints: 2 BE      3011
```

The parts are strings; `(mutate (plz (->number plz)))` converts one that
holds numbers.

## Missing values

`drop-na` drops rows with a missing value (in the named columns, or in
any), `replace-na` sets a value, and `fill-down` repeats the last value
seen, which repairs spreadsheets where a group label is written only
once:

```scheme
(df-nrow (drop-na long kg))                 ;; => 5
(df-column (replace-na long (kg 0)) 'kg)    ;; => #(10 12 9 4 0 6)
(df-column (fill-down (tibble (shop "Zurich" na na "Bern" na) (kg 1 2 3 4 5)) shop) 'shop)
;; => #("Zurich" "Zurich" "Zurich" "Bern" "Bern")
```

## Window functions

Window functions see the whole column (or group) but return a value per
row: `lag` and `lead` (the previous and next value), `cumsum`, `rank`,
`share` and others. Per group, they restart for each group:

```scheme
(df-print (-> long
              (drop-na kg)
              (group-by tea)
              (mutate (change (- kg (lag kg))) (running (cumsum kg)) (place (rank (- kg))))))
;; prints: # A data frame: 5 × 6, groups: tea
;; prints:   tea     month     kg  change  running  place
;; prints:   <chr>   <sym>  <int>   <int>    <int>  <int>
;; prints: 1 Sencha  jan       10      NA       10      2
;; prints: 2 Sencha  feb       12       2       22      1
;; prints: 3 Sencha  mar        9      -3       31      3
;; prints: 4 Assam   jan        4      NA        4      2
;; prints: 5 Assam   mar        6       2       10      1
```

`rank` ranks from small to large; ranking the negated value puts the
largest first. The first `lag` of each group is `na`, as there is no
previous month. The rows must be in the right order for this: `arrange`
first when they might not be.

## Your own functions

`define-df-function` adds a function to the expression language. A
`scalar` function works per row, an `agg` function reduces a group's
values (missing ones already removed) to one:

```scheme
(define-df-function 'with-vat 'scalar (lambda (chf) (* chf 1.081)))
(define-df-function 'spread 'agg (lambda (xs) (- (apply max xs) (apply min xs))))

(df-column (mutate prices (gross (round (with-vat chf)))) 'gross) ;; => #(52.0 24.0)
(df-print (-> long (group-by tea) (summarise (lowest (min kg)) (spread (spread kg)))))
;; prints: # A data frame: 2 × 3
;; prints:   tea     lowest  spread
;; prints:   <chr>    <int>   <int>
;; prints: 1 Assam        4       2
;; prints: 2 Sencha       9       3
```

A function used once is simpler as `(,proc column)`; one that many
analyses share is worth a name.

## Splitting by group

`df-split` turns a grouped frame into one frame per group, for example
to write one file per customer:

```scheme
(map (lambda (part) (list (car part) (df-nrow (cdr part))))
     (df-split (group-by orders customer)))
;; => ((("ada") 2) (("alan") 1) (("grace") 1))
```

Each part is the group's key values and its frame.

## Where next

- [Statistics and formatting](scm-data-stats.md), [charts](scm-data-plot.md)
  (long frames are what `ggplot` wants), [reading and writing
  data](scm-data-io.md).
- Reference: `(scm data verbs)`, `(scm data expr)`.

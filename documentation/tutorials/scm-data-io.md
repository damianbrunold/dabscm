---
title: "(scm data io): reading and writing data"
part: libraries
order: 1037
libraries: (scm data io)
summary: CSV with separators, decimal commas, column types, missing-value markers, skipped lines and an Excel-friendly byte order mark; streaming large CSV files; Excel workbooks with several sheets; JSON arrays and JSON Lines; Scheme data files; database query results; geometries from GeoJSON, shapefiles and TopoJSON.
---
# (scm data io): reading and writing data

Data frames come from files and go back to files. Every reader infers
the column types; options come after the required arguments as symbol
and value pairs.

| format | read | write |
|---|---|---|
| CSV | `read-csv`, `read-csv-string`, `csv-for-each` | `write-csv`, `df->csv-string` |
| Excel `.xlsx` | `read-xlsx` | `write-xlsx` |
| JSON | `read-json-records`, `read-jsonl` | `write-json-records`, `write-jsonl` |
| Scheme data | `read-sexp-lines` | `write-sexp-lines` |
| SQL results | `query-result->df` | |
| geometries | `read-sf` | `write-geojson` |

```scheme
(import (scheme base) (scheme file) (scheme write) (scm fs) (scm data))

(define dir (mktempdir '(prefix . "data-io")))
(define (at name) (join-path dir name))
(define (write-text! name text) (call-with-output-file (at name) (lambda (p) (write-string text p))))
```

## CSV

A CSV file from a Swiss or German system often has semicolons and
decimal commas, a title line above the header and its own marker for
missing values:

```scheme
(write-text! "stock.csv"
  "Export 2025-03-07\nArtikel;Name;Lager kg;Preis\n0101;Sencha;12,5;48,00\n0102;Assam;-;22,50\n0207;Matcha;0,8;160,00\n")

(define stock (read-csv (at "stock.csv") 'skip 1 'sep #\; 'decimal #\, 'na '("-")))
(df-print stock)
;; prints: # A data frame: 3 × 4
;; prints:   Artikel  Name    Lager kg  Preis
;; prints:   <chr>    <chr>      <dbl>  <dbl>
;; prints: 1 0101     Sencha      12.5     48
;; prints: 2 0102     Assam         NA   22.5
;; prints: 3 0207     Matcha       0.8    160
```

- `'skip 1` skips the title line, `'sep` and `'decimal` set the
  separators (without `'sep` it is guessed from the header line).
- The article numbers stay strings because of their leading zeros;
  `'col-types '((Artikel . string))` says so explicitly, which is safer
  when every number in a column happens to have no zero.
- A column name with a space is fine; in verbs write it as
  `|Lager kg|`, or `rename` it.

`write-csv` writes a frame back. `'bom #t` starts the file with a byte
order mark, so that Excel opens UTF-8 files with umlauts correctly:

```scheme
(define tidy-stock (rename stock (article Artikel) (name Name) (kg |Lager kg|) (chf Preis)))
(write-csv tidy-stock (at "stock-out.csv") 'sep #\; 'decimal #\, 'bom #t)
(df->csv-string (head tidy-stock 2))       ;; => "article,name,kg,chf\r\n0101,Sencha,12.5,48\r\n0102,Assam,,22.5\r\n"
```

Missing values are written as empty cells unless `'na` says otherwise.

## Large CSV files

`read-csv` builds the whole frame in memory. For files of millions of
lines, `csv-for-each` passes one record at a time, as an alist of
strings, so the program can count or filter without keeping them:

```scheme
(write-text! "log.csv" "time,status,bytes\n10:00,200,512\n10:01,404,0\n10:02,200,2048\n10:03,500,0\n")

(define errors 0)
(csv-for-each (at "log.csv")
  (lambda (r) (when (>= (string->number (cdr (assq 'status r))) 400) (set! errors (+ errors 1)))))
errors                                      ;; => 2
```

`'n-max` reads only the first rows of a big file, for a quick look.

## Excel

`write-xlsx` writes one frame or several sheets, with a bold, frozen
header row, a filter and fitted column widths; `read-xlsx` reads a sheet
back:

```scheme
(define by-origin (tibble (origin "Japan" "India") (kg 13.3 0)))
(write-xlsx `(("Stock" . ,tidy-stock) ("By origin" . ,by-origin)) (at "stock.xlsx"))

(define back (read-xlsx (at "stock.xlsx") 'sheet "By origin"))
(df-column back 'kg)                        ;; => #(13.3 0.0)
(df-column (read-xlsx (at "stock.xlsx")) 'article) ;; => #("0101" "0102" "0207")
```

Numbers stay numbers and text stays text. `'sheet` takes a name or a
number, `'skip` skips rows above the header. The [Excel
tutorial](scm-excel.md) covers formatting, formulas and templates.

## JSON

An array of objects is a frame, one row per object; `null` is `na`:

```scheme
(write-text! "orders.json" "[{\"id\": 1, \"tea\": \"Sencha\", \"gift\": true},
                             {\"id\": 2, \"tea\": \"Assam\", \"gift\": null}]")
(define orders (read-json-records (at "orders.json")))
(df-types orders)                           ;; => ((id . int) (tea . string) (gift . bool))

(write-json-records orders (at "orders-out.json"))
(call-with-input-file (at "orders-out.json") (lambda (p) (read-line p)))
;; => "[{\"id\":1,\"tea\":\"Sencha\",\"gift\":true},{\"id\":2,\"tea\":\"Assam\",\"gift\":null}]"
```

JSON Lines, one object per line, is the usual format for logs and
exports that grow: `read-jsonl` and `write-jsonl`.

## Scheme data

A file of Scheme data, one alist per line, is the most direct format for
data a Scheme program produces itself. Entries with several values
become list cells:

```scheme
(write-text! "runs.scm" "((tea \"Sencha\") (kg 2.5) (tasters \"ada\" \"alan\"))\n((tea \"Assam\") (kg 1) (tasters \"grace\"))\n")

(define runs (read-sexp-lines (at "runs.scm") 'list-cols '(tasters) 'add '((year . 2025))))
(df-column runs 'tasters)                   ;; => #(("ada" "alan") ("grace"))
(df-column runs 'year)                      ;; => #(2025 2025)
(df-column (unnest-longer runs tasters) 'tasters) ;; => #("ada" "alan" "grace")
```

`'add` adds constant columns, handy when several files (one per year,
say) are read and stacked with `bind-rows`.

## Databases

A query result of `(scm database postgres)` or `(scm database sqlserver)`
becomes a frame with `query-result->df`; NULL is `na`:

```scheme no-test
(define sales (query-result->df (pg-query conn "SELECT shop, tea, kg FROM sales WHERE day >= $1" "2025-03-01")))
```

Aggregating in SQL first (`GROUP BY` in the query) keeps large tables in
the database and only the result in memory.

## Geometries

`read-sf` reads shapefiles, GeoJSON and TopoJSON into a frame with a
`geometry` column next to the attributes, for maps with `geom-sf` (see
[charts and maps](scm-data-plot.md)):

```scheme
(write-text! "shops.geojson" "{\"type\": \"FeatureCollection\", \"features\": [
  {\"type\": \"Feature\", \"properties\": {\"shop\": \"Zurich\", \"kg\": 384},
   \"geometry\": {\"type\": \"Point\", \"coordinates\": [8.54, 47.37]}},
  {\"type\": \"Feature\", \"properties\": {\"shop\": \"Bern\", \"kg\": 124},
   \"geometry\": {\"type\": \"Point\", \"coordinates\": [7.45, 46.95]}}]}")

(define shops (read-sf (at "shops.geojson")))
(df-names shops)                            ;; => (shop kg geometry)
(df-column shops 'kg)                       ;; => #(384 124)

(write-geojson (mutate shops (kg2 (* 2 kg))) (at "shops-out.geojson"))
(df-column (read-sf (at "shops-out.geojson")) 'kg2) ;; => #(768 248)
(rm dir 'recursive)
```

Shapefiles name their character set in a `.cpg` file; `'encoding
'latin-1` overrides it for old files without one. A TopoJSON file holds
several layers, chosen with `'layer`.

## Where next

- [Data frames](scm-data.md), [charts and maps](scm-data-plot.md),
  [reports](scm-data-report.md).
- [CSV](techniques-08-structured-data.md#csv), [JSON](scm-json.md) and
  [Excel](scm-excel.md) without data frames.
- Reference: `(scm data io)`.

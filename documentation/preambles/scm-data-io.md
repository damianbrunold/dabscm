## Overview

Reading and writing data frames. Options follow the required arguments as a
quoted property list. Column types are inferred (integers, reals, booleans,
dates, strings; values with leading zeros such as `"007"` stay strings) unless
`'col-types` names them.

| Format | Read | Write |
|---|---|---|
| CSV (RFC 4180) | `read-csv`, `read-csv-string`, `csv-for-each` (streaming) | `write-csv` |
| XLSX | `read-xlsx` | `write-xlsx` (one or more sheets) |
| JSON | `read-json-records`, `read-jsonl` | `write-json-records`, `write-jsonl` |
| s-expression lines | `read-sexp-lines` | `write-sexp-lines` |
| SQL | `query-result->df` (pg-query / ss-query results) | |
| Geometry | `read-sf` (shapefile, GeoJSON, TopoJSON), `features->df` | `write-geojson`, `df->features` |

## Common uses

```scheme
(read-csv "cases.csv" 'sep #\; 'decimal #\, 'col-types '((plz . string)))
(write-xlsx `(("2024" . ,df24) ("2025" . ,df25)) "points.xlsx")
(read-sexp-lines "splg.scm" 'list-cols '(operateure) 'add '((year . 2024)))
(query-result->df (pg-query conn "SELECT splg, pts FROM mfzo_summary"))
(read-sf "gemeinden.topojson" 'layer "gemeinden")   ; properties + a geometry column
```

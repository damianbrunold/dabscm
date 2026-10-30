# `(scm data io)`

Data frames from and to CSV, XLSX, JSON, s-expression lines, SQL results

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

## Common uses

```scheme
(read-csv "cases.csv" 'sep #\; 'decimal #\, 'col-types '((plz . string)))
(write-xlsx `(("2024" . ,df24) ("2025" . ,df25)) "points.xlsx")
(read-sexp-lines "splg.scm" 'list-cols '(operateure) 'add '((year . 2024)))
(query-result->df (pg-query conn "SELECT splg, pts FROM mfzo_summary"))
```


## Exports

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

### `df->csv-string`

*(no documentation)*

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


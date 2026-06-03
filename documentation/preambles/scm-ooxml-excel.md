## Overview

`(scm ooxml excel)` creates Excel workbooks in the OOXML (`.xlsx`) format. Build a
workbook, add worksheets, set cells (with optional styles), and save to a file or
bytevector. To read existing workbooks, see `(scm ooxml excel-reader)`.

## Common uses

```scheme
(import (scm ooxml excel))

(define wb (make-workbook))
(define ws (workbook-add-worksheet! wb "Sheet1"))

(worksheet-set-cell! ws "A1" "Name" 'string #f)   ;; text
(worksheet-set-cell! ws "B1" 42     'num    #f)   ;; number

(workbook-save wb "report.xlsx")
```

Cells are addressed in A1 notation; the type is `'string` or `'num`, and the last
argument is a style index (`#f` for none). Create styles with `make-style` /
`workbook-add-style`, set column widths and row heights, and add autofilters.
`workbook-save-to-bytevector` returns the file as bytes.

## Overview

`(scm odf spreadsheet)` creates spreadsheets in the OpenDocument (`.ods`) format.
Its API mirrors `(scm ooxml excel)`: build a workbook, add worksheets, set cells,
and save. Use whichever format your consumers need.

## Common uses

```scheme
(import (scm odf spreadsheet))

(define wb (make-workbook))
(define ws (workbook-add-worksheet! wb "Sheet1"))

(worksheet-set-cell! ws "A1" "Name" 'string #f)
(worksheet-set-cell! ws "B1" 42     'num    #f)

(workbook-save wb "report.ods")
```

Cells use A1 notation; the type is `'string`, `'num`, or `'boolean`, and the last
argument is a style (`#f` for none). Column widths, row heights, named styles, and
streaming workbooks are supported, and `workbook-save-to-bytevector` returns the
file as bytes.

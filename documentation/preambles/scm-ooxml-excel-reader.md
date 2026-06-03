## Overview

`(scm ooxml excel-reader)` reads Excel workbooks in the OOXML (`.xlsx`) format —
the counterpart to `(scm ooxml excel)`. Open a workbook from a file or bytevector,
enumerate its sheets, and read cell values.

## Common uses

```scheme
(import (scm ooxml excel-reader))

(define wb (read-workbook "report.xlsx"))

(workbook-sheet-names wb)               ;; => ("Sheet1" ...)
(define sheet (workbook-sheet wb 0))    ;; first sheet (by index)
(sheet-ref sheet 1 1)                   ;; cell at row 1, col 1
(sheet-rows sheet)                      ;; all rows as lists of cell values
```

`read-workbook-from-bytevector` reads from in-memory bytes (e.g. an upload).
`sheet-dimensions` reports the used range, and `sheet-cells` gives the populated
cells.

# `(scm ooxml excel-reader)`

## Exports

### `read-workbook`

```
Syntax: (read-workbook path)
Library: (scm ooxml excel-reader)
Description: Reads the core sheet contents of the XLSX workbook at path and
  returns a workbook object. Cell values become Scheme strings, numbers and
  booleans; date-formatted cells become ISO 8601 strings. Use workbook-sheet,
  sheet-ref, sheet-rows and sheet-cells to access the data. Styling, merged
  cells, charts and images are not read.
Example:
  (let ((wb (read-workbook "report.xlsx")))
    (sheet-ref (workbook-sheet wb 0) 1 1)) => "Name"
```

### `read-workbook-from-bytevector`

```
Syntax: (read-workbook-from-bytevector bv)
Library: (scm ooxml excel-reader)
Description: Like read-workbook, but reads from an in-memory bytevector holding
  the bytes of an XLSX file. The bytes are written to a temporary file (the
  underlying zip reader is file-based) which is removed before returning.
Example:
  (read-workbook-from-bytevector (workbook-save-to-bytevector wb))
```

### `sheet-cells`

```
Syntax: (sheet-cells sheet)
Library: (scm ooxml excel-reader)
Description: Returns the populated cells only, as a list of ((row col) . value)
  pairs sorted by row then column. Useful for sparse sheets.
Example:
  (sheet-cells sheet) => (((1 1) . "Name") ((2 1) . "Bob") ((2 2) . 42))
```

### `sheet-dimensions`

```
Syntax: (sheet-dimensions sheet)
Library: (scm ooxml excel-reader)
Description: Returns (max-row . max-col), the 1-based extent of the populated
  cells, or (0 . 0) for an empty sheet.
Example:
  (sheet-dimensions sheet) => (10 . 3)
```

### `sheet-name`

```
Syntax: (sheet-name sheet)
Library: (scm ooxml excel-reader)
Description: Returns the name of a sheet object.
Example:
  (sheet-name (workbook-sheet wb 0)) => "Sheet1"
```

### `sheet-ref`

```
Syntax: (sheet-ref sheet row col)
Library: (scm ooxml excel-reader)
Description: Returns the value of the cell at the 1-based row and column, or #f
  if the cell is empty.
Example:
  (sheet-ref sheet 1 1) => "Name"
  (sheet-ref sheet 2 2) => 42
```

### `sheet-rows`

```
Syntax: (sheet-rows sheet)
Library: (scm ooxml excel-reader)
Description: Returns the sheet as a list of rows (top to bottom). Each row is a
  list of cell values from column 1 to the sheet's maximum column; empty cells
  are #f. Returns the empty list for an empty sheet.
Example:
  (sheet-rows sheet) => (("Name" "Age") ("Bob" 42))
```

### `workbook-sheet`

```
Syntax: (workbook-sheet wb name-or-index)
Library: (scm ooxml excel-reader)
Description: Returns a sheet object by name (string) or by 0-based position
  (integer), or #f if there is no such sheet.
Example:
  (workbook-sheet wb 0)
  (workbook-sheet wb "Data")
```

### `workbook-sheet-names`

```
Syntax: (workbook-sheet-names wb)
Library: (scm ooxml excel-reader)
Description: Returns the list of worksheet names in workbook order.
Example:
  (workbook-sheet-names wb) => ("Sheet1" "Data")
```

### `workbook-sheets`

```
Syntax: (workbook-sheets wb)
Library: (scm ooxml excel-reader)
Description: Returns the list of all sheet objects in workbook order.
Example:
  (map sheet-name (workbook-sheets wb)) => ("Sheet1" "Data")
```


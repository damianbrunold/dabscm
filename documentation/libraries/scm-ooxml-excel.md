# `(scm ooxml excel)`

Excel workbook and worksheet creation (OOXML/XLSX format)

## Exports

### `call-with-streaming-table`

```
Syntax: (call-with-streaming-table filename name num-cols proc)
Library: (scm ooxml excel)
Description: Creates a single-sheet streaming table workbook, calls
(proc wb-proxy st) where wb-proxy supports workbook-add-style and st is a
streaming table, then finalizes and saves the XLSX file. Returns 'ok.
Example:
  (call-with-streaming-table "/tmp/big.xlsx" "Data" 3
    (lambda (wb st)
      (streaming-table-write-row! st '("Name" "Age" "City"))
      (streaming-table-write-row! st '("Alice" 30 "Bern"))))
```

### `call-with-streaming-workbook`

```
Syntax: (call-with-streaming-workbook filename name proc)
Library: (scm ooxml excel)
Description: Creates a single-sheet streaming workbook, calls (proc wb-proxy sws)
where wb-proxy supports workbook-add-style and sws is a streaming worksheet,
then finalizes and saves the XLSX file to filename. Cells must be written in
row-ascending order. Returns 'ok.
Example:
  (call-with-streaming-workbook "/tmp/big.xlsx" "Data"
    (lambda (wb sws)
      (let ((hdr (workbook-add-style wb fill: fgcolor: 'lightblue)))
        (worksheet-set-cell! sws "A1" "Name" 'string hdr)
        (worksheet-set-cell! sws "A2" "Alice" 'string #f))))
```

### `call-with-worksheet`

```
Syntax: (call-with-worksheet filename name proc)
Library: (scm ooxml excel)
Description: Creates a workbook with a single worksheet named name, calls
(proc wb ws) where wb is the workbook and ws is the worksheet, then saves
the workbook to filename.
Example:
  (call-with-worksheet "/tmp/out.xlsx" "Data"
    (lambda (wb ws)
      (worksheet-set-cell! ws "A1" "hello" 'string #f)))
```

### `col-index->string`

```
Syntax: (col-index->string col)
Library: (scm ooxml excel)
Description: Converts a 1-based column index to its Excel column letter string.
Example:
  (col-index->string 1)  => "A"
  (col-index->string 26) => "Z"
  (col-index->string 27) => "AA"
```

### `make-style`

```
Syntax: (make-style)
Library: (scm ooxml excel)
Description: Creates and returns a new mutable style object with default font
(Calibri 11pt black), no fill, no border, and no alignment. The style object
is a message-passing procedure accepting set-font, set-fill, set-border, and
set-alignment actions. Use workbook-add-style instead of this function directly.
Example:
  (let ((s (make-style)))
    (s 'set-font 'color 'red 'bold #t)
    (s 'set-fill 'fgcolor 'lightblue))
```

### `make-workbook`

```
Syntax: (make-workbook)
Library: (scm ooxml excel)
Description: Creates and returns a new empty workbook object.
Example:
  (let ((wb (make-workbook)))
    (workbook-add-worksheet! wb "Sheet1")
    (workbook-save wb "out.xlsx"))
```

### `open-streaming-table`

```
Syntax: (open-streaming-table filename sheet-name num-cols)
Library: (scm ooxml excel)
Description: Opens a new single-sheet streaming table workbook. num-cols is
the number of columns per row. Returns a pair (st . close-proc) where st is
a streaming table and close-proc must be called exactly once to finalize.
Example:
  (let* ((handle (open-streaming-table "/tmp/out.xlsx" "Sheet1" 3))
         (st     (car handle))
         (done!  (cdr handle)))
    (streaming-table-write-row! st '("hello" "world" 42))
    (done!))
```

### `open-streaming-workbook`

```
Syntax: (open-streaming-workbook filename sheet-name)
Library: (scm ooxml excel)
Description: Opens a new single-sheet streaming workbook writing to filename.
Returns a pair (sws . close-proc) where sws is a streaming worksheet and
close-proc is a zero-argument procedure that finalizes and closes the XLSX file.
close-proc must be called exactly once when all data has been written. Cells
must be written in row-ascending order.
Example:
  (let* ((handle (open-streaming-workbook "/tmp/out.xlsx" "Sheet1"))
         (sws    (car handle))
         (done!  (cdr handle)))
    (worksheet-set-cell! sws "A1" "hello" 'string #f)
    (done!))
```

### `register-color!`

```
Syntax: (register-color! name hex-string)
Library: (scm ooxml excel)
Description: Registers a new named color in the color table used by resolve-color.
name is a symbol; hex-string is an 8-character ARGB hex string (e.g. "FFFF0000").
Example:
  (register-color! 'salmon "FFFA8072")
```

### `resolve-color`

```
Syntax: (resolve-color color)
Library: (scm ooxml excel)
Description: Resolves a color value to an 8-character ARGB hex string. color may
be a string (returned as-is) or a symbol naming a known color (black, white, red,
darkred, lightred, green, darkgreen, lightgreen, blue, darkblue, lightblue,
yellow, orange, purple, gray, darkgray, lightgray). Signals an error for unknown
color symbols.
Example:
  (resolve-color 'red)       => "FFFF0000"
  (resolve-color "FF0000FF") => "FF0000FF"
```

### `row-col->cell-id`

```
Syntax: (row-col->cell-id row col)
Library: (scm ooxml excel)
Description: Returns the Excel cell ID string for the given 1-based row and
column indices.
Example:
  (row-col->cell-id 1 1)  => "A1"
  (row-col->cell-id 3 28) => "AB3"
```

### `streaming-table-finish!`

```
Syntax: (streaming-table-finish! st)
Library: (scm ooxml excel)
Description: Finalizes a streaming table worksheet.
```

### `streaming-table-row-num`

```
Syntax: (streaming-table-row-num st)
Library: (scm ooxml excel)
Description: Returns the number of rows written so far to a streaming table.
```

### `streaming-table-set-autofilter!`

```
Syntax: (streaming-table-set-autofilter! st ref)
Library: (scm ooxml excel)
Description: Sets the autofilter range for a streaming table.
```

### `streaming-table-set-col-width!`

```
Syntax: (streaming-table-set-col-width! st col width)
Library: (scm ooxml excel)
Description: Sets the width of a column in a streaming table.
```

### `streaming-table-set-row-height!`

```
Syntax: (streaming-table-set-row-height! st row height)
Library: (scm ooxml excel)
Description: Sets the height of a row in a streaming table.
```

### `streaming-table-write-row!`

```
Syntax: (streaming-table-write-row! st values)
Library: (scm ooxml excel)
Description: Writes a row to a streaming table. values is a list of cell
values.
```

### `streaming-table-write-styled-row!`

```
Syntax: (streaming-table-write-styled-row! st values styles)
Library: (scm ooxml excel)
Description: Writes a row with per-cell styles. values and styles are
parallel lists; each style element is #f or a style index.
```

### `workbook-add-style`

```
Syntax: (workbook-add-style wb [(font opts...)] [(fill opts...)] [(border opts...)] [(alignment opts...)])
Library: (scm ooxml excel)
Description: Creates a style, registers it with wb, and returns its style index
for use as the style argument to worksheet-set-cell!. Accepts keyword sections
font, fill, border, and alignment followed by property keyword/value pairs.
Font properties: name: family: size: color: bold italic
Fill properties: type: fgcolor: bgcolor:
Border properties: left: right: top: bottom: diagonal:
Alignment properties: rotation:
Color values may be symbols (e.g. 'red) or 8-char ARGB hex strings.
Example:
(workbook-add-style wb (fill fgcolor: lightblue))
(workbook-add-style wb (fill fgcolor: lightblue) (font color: red bold))
```

### `workbook-add-worksheet!`

```
Syntax: (workbook-add-worksheet! wb name)
Library: (scm ooxml excel)
Description: Adds a new worksheet named name to wb and returns the new worksheet
object. Worksheets are saved in the order they are added.
Example:
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb "Sheet1")))
    (worksheet-set-cell! ws "A1" 42 'num #f))
```

### `workbook-save`

```
Syntax: (workbook-save wb filename)
Library: (scm ooxml excel)
Description: Serializes wb to an XLSX file at the given filename path. All
worksheets added via workbook-add-worksheet! are included. Returns 'ok.
Example:
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb "Data")))
    (worksheet-set-cell! ws "A1" "hello" 'string #f)
    (workbook-save wb "/tmp/out.xlsx"))
```

### `workbook-save-to-bytevector`

```
Syntax: (workbook-save-to-bytevector wb)
Library: (scm ooxml excel)
Description: Serializes wb to an XLSX file in memory and returns the bytes as
a bytevector. Useful for generating documents for HTTP responses or in-memory
processing without writing to disk.
Example:
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb "Data")))
    (worksheet-set-cell! ws "A1" "hello" 'string #f)
    (workbook-save-to-bytevector wb))
```

### `workbook-styles`

```
Syntax: (workbook-styles wb)
Library: (scm ooxml excel)
Description: Returns the styles object for wb. Works for both regular workbooks
and streaming workbook proxies. The styles object is used internally by
workbook-add-style.
Example:
  ((workbook-styles wb) 'styles-count) => 0
```

### `worksheet-set-autofilter!`

```
Syntax: (worksheet-set-autofilter! ws ref)
Library: (scm ooxml excel)
Description: Adds an AutoFilter to worksheet ws over the cell range ref. ref is
an A1-notation range string. Works for both regular and streaming worksheets.
Example:
  (worksheet-set-autofilter! ws "A1:E1")
```

### `worksheet-set-cell!`

```
Syntax: (worksheet-set-cell! ws id value type style)
Library: (scm ooxml excel)
Description: Sets the cell at id (an A1-notation string such as "B3") in
worksheet ws. type is either 'string or 'num. style is either #f for no style
or a style index returned by workbook-add-style. Works for both regular and
streaming worksheets. For streaming worksheets, cells must be written in
row-ascending order.
Example:
  (worksheet-set-cell! ws "A1" "hello" 'string #f)
  (worksheet-set-cell! ws "B2" 42 'num #f)
  (worksheet-set-cell! ws "C3" "hi" 'string my-style)
```

### `worksheet-set-col-width!`

```
Syntax: (worksheet-set-col-width! ws col width)
Library: (scm ooxml excel)
Description: Sets the width of the column identified by the letter string col
in worksheet ws. Works for both regular and streaming worksheets.
Example:
  (worksheet-set-col-width! ws "A" 20)
  (worksheet-set-col-width! ws "B" 12.5)
```

### `worksheet-set-row-height!`

```
Syntax: (worksheet-set-row-height! ws row height)
Library: (scm ooxml excel)
Description: Sets the height (in points) of the 1-based row index in worksheet
ws. Works for both regular and streaming worksheets.
Example:
  (worksheet-set-row-height! ws 1 30)
```


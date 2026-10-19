# `(scm ooxml excel template)`

## Exports

### `open-xlsx-template`

```
Syntax: (open-xlsx-template path-or-bytevector)
Library: (scm ooxml excel template)
Description: Opens an XLSX workbook from a file path or a bytevector holding
  its bytes and returns a template object. All parts are read into memory;
  parts that are never patched are written back unchanged by xlsx-save.
Example:
  (define tpl (open-xlsx-template "Vorlage.xlsx"))
```

### `xlsx-add-conditional-formats!`

```
Syntax: (xlsx-add-conditional-formats! tpl sheet-name specs)
Library: (scm ooxml excel template)
Description: Adds expression-based conditional formatting. Each spec is
  (sqref rule ...) where each rule is (formula dxf-id) or
  (formula dxf-id stop-if-true?). formula uses English function names and
  relative references are relative to the top-left cell of sqref. dxf-id
  comes from xlsx-add-dxf!. Rules get increasing priorities in the given
  order, after any existing rules.
Example:
  (xlsx-add-conditional-formats! tpl "Data"
    (list (list "A2:H100" (list "$B2<>$B1" sep-dxf))))
```

### `xlsx-add-data-validations!`

```
Syntax: (xlsx-add-data-validations! tpl sheet-name specs)
Library: (scm ooxml excel template)
Description: Adds list data validations (dropdowns), replacing any existing
  validations of the sheet. Each spec is (sqref items): items is a list of
  strings (inline list; joined length must not exceed 255 characters and
  items must not contain commas) or a string formula such as
  "Lists!$A$1:$A$7". Invalid entries are rejected with an error message.
Example:
  (xlsx-add-data-validations! tpl "Data"
    (list (list "F2:F100" '("ok" "Verstoss"))))
```

### `xlsx-add-dxf!`

```
Syntax: (xlsx-add-dxf! tpl options)
Library: (scm ooxml excel template)
Description: Adds a differential format (used by conditional formatting) to
  xl/styles.xml and returns its index. options is an alist with keys
  font-color (ARGB string), bold, italic (booleans), fill (ARGB string,
  solid background) and border-left/-right/-top/-bottom (border style such
  as "thin"), border-color (ARGB, default automatic).
Example:
  (xlsx-add-dxf! tpl '((fill . "FFFFFF00")))  => 0
  (xlsx-add-dxf! tpl '((border-top . "thin")))  => 1
```

### `xlsx-cell-ref`

```
Syntax: (xlsx-cell-ref row col)
Library: (scm ooxml excel template)
Description: Returns the A1-style reference for a 1-based row and column.
Example:
  (xlsx-cell-ref 3 28) => "AB3"
```

### `xlsx-collapse-outline-cols!`

```
Syntax: (xlsx-collapse-outline-cols! tpl sheet-name level)
Library: (scm ooxml excel template)
Description: Collapses grouped columns: every <col> with an outlineLevel >=
  level is hidden and the column following each such group is marked
  collapsed (like Outline.ShowLevels ColumnLevels:=level-1).
Example:
  (xlsx-collapse-outline-cols! tpl "Data" 1)
```

### `xlsx-column-styles`

```
Syntax: (xlsx-column-styles tpl sheet-name)
Library: (scm ooxml excel template)
Description: Returns a procedure mapping a 1-based column index to the
  column's default cellXfs index from <cols> (0 when none). Cells written
  without a style do not inherit the column style, so pass these on.
Example:
  ((xlsx-column-styles tpl "Data") 3) => 60
```

### `xlsx-derive-xf!`

```
Syntax: (xlsx-derive-xf! tpl base-xf-index format-code)
Library: (scm ooxml excel template)
Description: Returns the index of a cellXfs entry equal to base-xf-index but
  with number format format-code, adding it on first use (cached per
  template).
Example:
  (xlsx-derive-xf! tpl 36 "@") => 94
```

### `xlsx-formula`

*(no documentation)*

### `xlsx-formula-text`

*(no documentation)*

### `xlsx-formula?`

*(no documentation)*

### `xlsx-full-calc-on-load!`

```
Syntax: (xlsx-full-calc-on-load! tpl)
Library: (scm ooxml excel template)
Description: Makes the spreadsheet application recalculate all formulas when
  the workbook is opened (calcPr fullCalcOnLoad) and removes a stale
  xl/calcChain.xml with its relationship and content type.
Example:
  (xlsx-full-calc-on-load! tpl)
```

### `xlsx-number-format-id!`

```
Syntax: (xlsx-number-format-id! tpl format-code)
Library: (scm ooxml excel template)
Description: Returns the numFmtId for format-code, using the built-in id
  where one exists ("@" => 49), an existing custom format, or adding a new
  custom <numFmt> (id >= 164) to xl/styles.xml.
Example:
  (xlsx-number-format-id! tpl ";;;@") => 164
```

### `xlsx-part-names`

```
Syntax: (xlsx-part-names tpl)
Library: (scm ooxml excel template)
Description: Returns the names of all zip parts of the template, in order.
Example:
  (member "xl/styles.xml" (xlsx-part-names tpl)) => ("xl/styles.xml" ...)
```

### `xlsx-part-text`

```
Syntax: (xlsx-part-text tpl name)
Library: (scm ooxml excel template)
Description: Returns the text (UTF-8 decoded) of part name, or #f if the part
  does not exist.
Example:
  (xlsx-part-text tpl "xl/workbook.xml") => "<?xml ..."
```

### `xlsx-quote-sheet-name`

```
Syntax: (xlsx-quote-sheet-name name)
Library: (scm ooxml excel template)
Description: Returns name ready for use in a formula or defined name: quoted
  with single quotes (inner quotes doubled) unless it consists only of
  letters, digits and underscores.
Example:
  (xlsx-quote-sheet-name "Lies mich") => "'Lies mich'"
```

### `xlsx-remove-conditional-formats!`

```
Syntax: (xlsx-remove-conditional-formats! tpl sheet-name)
Library: (scm ooxml excel template)
Description: Removes all (non-extension) conditional formatting of a sheet.
Example:
  (xlsx-remove-conditional-formats! tpl "Data")
```

### `xlsx-remove-part!`

```
Syntax: (xlsx-remove-part! tpl name)
Library: (scm ooxml excel template)
Description: Removes part name from the template (no-op if absent). Content
  type overrides and relationships pointing at it are not touched.
Example:
  (xlsx-remove-part! tpl "xl/calcChain.xml")
```

### `xlsx-replace-sheet-data!`

```
Syntax: (xlsx-replace-sheet-data! tpl sheet-name keep-rows writer)
Library: (scm ooxml excel template)
Description: Replaces the rows of a worksheet. Template rows with a row number
  <= keep-rows (e.g. a header row) are kept, all others dropped. writer is
  called during xlsx-save with one argument, an emit procedure:
  (emit values) or (emit values styles) appends the next row (starting at
  keep-rows + 1) and returns its row number. values is a list from column A;
  each element is #f (no value), a string, a number, #t or an xlsx-formula.
  styles is an optional parallel list of cellXfs indices (#f = none). Rows
  are streamed into the zip entry, so writer may emit many rows. writer runs
  once per save. The worksheet's <dimension> element is dropped (optional;
  recomputed by the application).
Example:
  (xlsx-replace-sheet-data! tpl "Data" 1
    (lambda (emit)
      (emit (list "a" 1 (xlsx-formula "B2*2")))))
```

### `xlsx-replace-text!`

```
Syntax: (xlsx-replace-text! tpl replacements)
Library: (scm ooxml excel template)
Description: Replaces literal text placeholders in the shared strings and in
  all drawings (text boxes). replacements is an alist of (from . to) plain
  strings; both are XML-escaped. A placeholder split across formatting runs
  is not found.
Example:
  (xlsx-replace-text! tpl '(("{DATUM}" . "30. Juni 2026")))
```

### `xlsx-save`

```
Syntax: (xlsx-save tpl filename)
Library: (scm ooxml excel template)
Description: Writes the (patched) workbook to filename. Row writers given to
  xlsx-replace-sheet-data! run now. Returns 'ok.
Example:
  (xlsx-save tpl "out.xlsx") => ok
```

### `xlsx-save-to-bytevector`

```
Syntax: (xlsx-save-to-bytevector tpl)
Library: (scm ooxml excel template)
Description: Like xlsx-save, but returns the workbook bytes as a bytevector.
Example:
  (bytevector? (xlsx-save-to-bytevector tpl)) => #t
```

### `xlsx-set-autofilter!`

```
Syntax: (xlsx-set-autofilter! tpl sheet-name range)
Library: (scm ooxml excel template)
Description: Sets the autofilter of a sheet to range (e.g. "A1:BE500"),
  replacing an existing one, and updates the hidden _xlnm._FilterDatabase
  defined name accordingly.
Example:
  (xlsx-set-autofilter! tpl "Data" "A1:H100")
```

### `xlsx-set-cells!`

```
Syntax: (xlsx-set-cells! tpl sheet-name specs)
Library: (scm ooxml excel template)
Description: Sets individual cells of a worksheet. Each spec is
  (ref value) or (ref value style): ref is an A1 reference, value as for
  xlsx-replace-sheet-data!. Without a style the existing cell's style is
  kept. Existing cells are replaced, missing cells and rows inserted in
  order. Not usable on a sheet whose rows were replaced.
Example:
  (xlsx-set-cells! tpl "Summary"
    (list (list "C2" "Spital X") (list "E15" (xlsx-formula "SUM(A1:A9)"))))
```

### `xlsx-set-defined-name!`

```
Syntax: (xlsx-set-defined-name! tpl name value [local-sheet [hidden?]])
Library: (scm ooxml excel template)
Description: Sets (or adds) a defined name in xl/workbook.xml. local-sheet is
  a sheet name for a sheet-scoped name or #f for a global one.
Example:
  (xlsx-set-defined-name! tpl "Codes" "Lists!$A$1:$A$9")
```

### `xlsx-set-part-text!`

```
Syntax: (xlsx-set-part-text! tpl name text)
Library: (scm ooxml excel template)
Description: Replaces (or adds) part name with the given text.
Example:
  (xlsx-set-part-text! tpl "xl/workbook.xml" xml)
```

### `xlsx-sheet-names`

```
Syntax: (xlsx-sheet-names tpl)
Library: (scm ooxml excel template)
Description: Returns the worksheet names in workbook order.
Example:
  (xlsx-sheet-names tpl) => ("Lies mich" "Legende" ...)
```

### `xlsx-sheet-part`

```
Syntax: (xlsx-sheet-part tpl sheet-name)
Library: (scm ooxml excel template)
Description: Returns the zip part name holding the worksheet called
  sheet-name. An error is raised for unknown sheets.
Example:
  (xlsx-sheet-part tpl "Leistungscontrolling") => "xl/worksheets/sheet4.xml"
```

### `xlsx-template?`

*(no documentation)*


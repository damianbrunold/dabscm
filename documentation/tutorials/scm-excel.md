---
title: (scm ooxml excel) and friends: spreadsheets
part: libraries
order: 1020
libraries: (scm ooxml excel) (scm ooxml excel-reader) (scm ooxml excel template) (scm odf spreadsheet)
summary: Writing .xlsx workbooks with styles, widths, frozen panes and filters; streaming large tables; reading workbooks back; filling a designed template with values and formulas; OpenDocument .ods files.
---
# (scm ooxml excel) and friends: spreadsheets

| library | does |
|---|---|
| `(scm ooxml excel)` | writes `.xlsx` workbooks, also huge ones as a stream |
| `(scm ooxml excel-reader)` | reads the values of `.xlsx` workbooks |
| `(scm ooxml excel template)` | fills in an existing, designed workbook |
| `(scm odf spreadsheet)` | writes OpenDocument `.ods` files, with the same API |

```scheme
(import (scheme base) (scheme cxr) (scheme write) (srfi 1)
        (scm fs) (scm ooxml excel) (scm ooxml excel-reader) (scm ooxml excel template))

(define dir (mktempdir '(prefix . "xlsx")))
(define (at name) (join-path dir name))
```

## A workbook

```scheme
(define sales
  '(("Sencha" "green" 12.5 4.5)
    ("Matcha" "green" 3 12)
    ("Assam" "black" 20 3.2)))

(define wb (make-workbook))
(define ws (workbook-add-worksheet! wb "Sales"))
(define header (workbook-add-style wb (font bold color: white) (fill fgcolor: darkblue)))
(define money (workbook-add-style wb (alignment horizontal: right)))

(for-each (lambda (title col) (worksheet-set-cell! ws (row-col->cell-id 1 col) title 'string header))
          '("Tea" "Kind" "Kg" "Price") '(1 2 3 4))
(for-each (lambda (row r)
            (worksheet-set-cell! ws (row-col->cell-id r 1) (car row) 'string #f)
            (worksheet-set-cell! ws (row-col->cell-id r 2) (cadr row) 'string #f)
            (worksheet-set-cell! ws (row-col->cell-id r 3) (caddr row) 'num #f)
            (worksheet-set-cell! ws (row-col->cell-id r 4) (cadddr row) 'num money))
          sales (iota (length sales) 2))

(worksheet-set-col-width! ws "A" 18)
(worksheet-freeze-panes! ws "A2")
(worksheet-set-autofilter! ws "A1:D4")
(workbook-set-properties! wb '((title . "Tea sales") (creator . "Teashop")))
(workbook-save wb (at "sales.xlsx"))
(file-exists? (at "sales.xlsx"))           ;; => #t
```

- Cells are addressed as `"B3"`; `row-col->cell-id` builds the address
  from numbers (row 1, column 1 is `"A1"`), `col-index->string` the
  column letters (`28` is `"AB"`).
- The type is `'string` or `'num`; the last argument is a style or `#f`.
- `workbook-add-style` takes `font`, `fill`, `border` and `alignment`
  sections and returns the style's number.
- Frozen panes keep the header visible while scrolling; the autofilter
  gives the header drop-down filters.

`worksheet-merge-cells!`, `worksheet-set-row-height!`,
`worksheet-add-image!` and `worksheet-set-page-setup!` do what their names
say; `workbook-save-to-bytevector` returns the file as bytes, for a
download.

```scheme
(row-col->cell-id 3 28)                     ;; => "AB3"
(col-index->string 28)                      ;; => "AB"
```

## Reading

```scheme
(define book (read-workbook (at "sales.xlsx")))
(workbook-sheet-names book)                 ;; => ("Sales")
(define sheet (workbook-sheet book "Sales"))
(sheet-dimensions sheet)                    ;; => (4 . 4)
(sheet-ref sheet 1 1)                       ;; => "Tea"
(sheet-ref sheet 3 4)                       ;; => 12
(sheet-rows sheet)
;; => (("Tea" "Kind" "Kg" "Price") ("Sencha" "green" 12.5 4.5) ("Matcha" "green" 3 12) ("Assam" "black" 20 3.2))
```

Values come back as strings, numbers and booleans, dates as ISO 8601
strings; empty cells are `#f`. Styles are not read. A sheet as records,
keyed by the header row:

```scheme
(define (sheet->records sheet)
  (let ((rows (sheet-rows sheet)))
    (map (lambda (row) (map cons (map string->symbol (car rows)) row))
         (cdr rows))))

(define records (sheet->records sheet))
(car records)                               ;; => ((Tea . "Sencha") (Kind . "green") (Kg . 12.5) (Price . 4.5))
(fold + 0 (map (lambda (r) (* (cdr (assq 'Kg r)) (cdr (assq 'Price r)))) records))
;; => 156.25
```

`read-workbook-from-bytevector` reads an upload without a temporary file.

## Large tables as a stream

A workbook built with `make-workbook` lives in memory until it is saved.
For hundreds of thousands of rows, write a stream instead: rows go to the
file as they are written:

```scheme
(call-with-streaming-table (at "squares.xlsx") "Data" 3
  (lambda (wb table)
    (let ((bold (workbook-add-style wb (font bold))))
      (streaming-table-write-styled-row! table '("n" "n²" "even") (list bold bold bold))
      (do ((n 1 (+ n 1))) ((> n 10000))
        (streaming-table-write-row! table (list n (* n n) (if (even? n) "yes" "no")))))))

(define squares (workbook-sheet (read-workbook (at "squares.xlsx")) 0))
(sheet-dimensions squares)                  ;; => (10001 . 3)
(list (sheet-ref squares 10001 1) (sheet-ref squares 10001 2)) ;; => (10000 100000000)
```

Memory use stays flat however many rows are written.

## Templates

Reports often have to look exactly like a designed workbook: logos,
colours, formulas, a sheet with explanations. Design it in Excel and fill
in only the data. `(scm ooxml excel template)` opens any `.xlsx` and
changes cells while keeping everything else:

```scheme
(define tpl (open-xlsx-template (at "sales.xlsx")))
(xlsx-sheet-names tpl)                      ;; => ("Sales")
(xlsx-set-cells! tpl "Sales"
                 (list (list "A5" "Total")
                       (list "C5" (xlsx-formula "SUM(C2:C4)"))))
(xlsx-full-calc-on-load! tpl)
(xlsx-save tpl (at "report.xlsx"))

(sheet-ref (workbook-sheet (read-workbook (at "report.xlsx")) 0) 5 1) ;; => "Total"
(sheet-ref (workbook-sheet (read-workbook (at "report.xlsx")) 0) 5 3) ;; => #f
```

The formula cell reads as `#f`: its value is computed by the spreadsheet
program when the file is opened (`xlsx-full-calc-on-load!` asks for
that). Cells keep their style unless a third element gives a new one.

To replace a whole table below a header, `xlsx-replace-sheet-data!` takes
a writer that emits rows as the file is saved, so it handles large data:

```scheme
(define tpl2 (open-xlsx-template (at "sales.xlsx")))
(xlsx-replace-sheet-data! tpl2 "Sales" 1
  (lambda (emit)
    (emit '("Oolong" "blue" 7 6.8))
    (emit (list "Total" #f (xlsx-formula "SUM(C2:C2)") #f))))
(xlsx-save tpl2 (at "report2.xlsx"))
(sheet-rows (workbook-sheet (read-workbook (at "report2.xlsx")) 0))
;; => (("Tea" "Kind" "Kg" "Price") ("Oolong" "blue" 7 6.8) ("Total" #f #f #f))
```

`xlsx-replace-text!` replaces placeholders like `{DATE}` in texts and text
boxes, and further procedures add conditional formats, data validations
and defined names.

## OpenDocument spreadsheets

`(scm odf spreadsheet)` has the same procedures and writes `.ods` files
for LibreOffice. Import it with a prefix when both are used:

```scheme
(import (prefix (scm odf spreadsheet) ods:))

(define o (ods:make-workbook))
(define osheet (ods:workbook-add-worksheet! o "Sales"))
(ods:worksheet-set-cell! osheet "A1" "Tea" 'string #f)
(ods:worksheet-set-cell! osheet "B1" 12.5 'num #f)
(ods:workbook-save o (at "sales.ods"))
(file-exists? (at "sales.ods"))             ;; => #t

(rm dir 'recursive)
```

## Where next

- [`(scm word)`](scm-word.md), `(scm data io)` for data frames to and from
  Excel, `(scm ooxml docprops)` for document properties.
- Reference: `(scm ooxml excel)`, `(scm ooxml excel-reader)`,
  `(scm ooxml excel template)`, `(scm odf spreadsheet)`.

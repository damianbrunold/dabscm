(import (scheme base) (scheme write) (scm fs) (scm ooxml excel) (scm ooxml excel-reader)
        (scm zip) (srfi 13) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "excel")

;; col-index->string: 1-based column index to Excel letter string
(test-group "col-index->string"
  (test-equal "A" (col-index->string 1))
  (test-equal "Z" (col-index->string 26))
  (test-equal "AA" (col-index->string 27))
  (test-equal "AB" (col-index->string 28))
  (test-equal "AZ" (col-index->string 52))
  (test-equal "BA" (col-index->string 53))
  (test-equal "ZZ" (col-index->string 702))
  (test-equal "AAA" (col-index->string 703)))

;; row-col->cell-id: (row col) -> "colrow"
(test-group "row-col->cell-id"
  (test-equal "A1" (row-col->cell-id 1 1))
  (test-equal "AB3" (row-col->cell-id 3 28))
  (test-equal "B10" (row-col->cell-id 10 2)))

;; resolve-color: named colors
(test-group "resolve-color-named"
  (test-equal "FF000000" (resolve-color 'black))
  (test-equal "FFFF0000" (resolve-color 'red))
  (test-equal "FFADD8E6" (resolve-color 'lightblue)))

;; resolve-color: string passthrough
(test-group "resolve-color-string"
  (test-equal "FFAABBCC" (resolve-color "FFAABBCC")))

;; register-color!
(test-group "register-color"
  (register-color! 'test-salmon "FFFA8072")
  (test-equal "FFFA8072" (resolve-color 'test-salmon)))

;; make-workbook: starts with zero styles
(test-group "make-workbook"
  (test-equal 0 ((workbook-styles (make-workbook)) 'styles-count)))

;; workbook-add-worksheet!: returns a worksheet object (vector)
(test-group "workbook-add-worksheet"
  (test-equal #t
    (let* ((wb (make-workbook))
           (ws (workbook-add-worksheet! wb "Sheet1")))
      (vector? ws)))
  ;; second worksheet is also a vector
  (test-equal #t
    (let* ((wb (make-workbook))
           (ws1 (workbook-add-worksheet! wb "Alpha"))
           (ws2 (workbook-add-worksheet! wb "Beta")))
      (and (vector? ws1) (vector? ws2)))))

;; workbook-add-style: first style returns index 1
(test-group "workbook-add-style"
  (test-equal 1
    (let* ((wb (make-workbook))
           (idx (workbook-add-style wb fill: fgcolor: 'lightblue)))
      idx))
  ;; second distinct style returns index 2
  (test-equal 2
    (let* ((wb (make-workbook))
           (_ (workbook-add-style wb fill: fgcolor: 'lightblue))
           (idx2 (workbook-add-style wb font: color: 'red bold)))
      idx2)))

;; workbook-save: write a workbook with cells, returns 'ok
(test-group "workbook-save"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-excel.xlsx"))
           (wb   (make-workbook))
           (ws   (workbook-add-worksheet! wb "Data"))
           (s1   (workbook-add-style wb fill: fgcolor: 'lightblue)))
      (worksheet-set-cell! ws "A1" "Name"  'string s1)
      (worksheet-set-cell! ws "B1" "Score" 'string s1)
      (worksheet-set-cell! ws "A2" "Alice" 'string #f)
      (worksheet-set-cell! ws "B2" 42      'num    #f)
      (workbook-save wb path))))

;; call-with-worksheet: single-sheet convenience API, returns 'ok
(test-group "call-with-worksheet"
  (test-equal 'ok
    (let ((path (join-path (special-folder-temp) "test-scm-excel-cw.xlsx")))
      (call-with-worksheet path "Results"
        (lambda (wb ws)
          (let ((hdr (workbook-add-style wb font: bold)))
            (worksheet-set-cell! ws "A1" "Item"  'string hdr)
            (worksheet-set-cell! ws "B1" "Value" 'string hdr)
            (worksheet-set-cell! ws "A2" "Foo"   'string #f)
            (worksheet-set-cell! ws "B2" 99      'num    #f)))))))

;; call-with-streaming-workbook: streaming API, returns 'ok
(test-group "call-with-streaming-workbook"
  (test-equal 'ok
    (let ((path (join-path (special-folder-temp) "test-scm-excel-stream.xlsx")))
      (call-with-streaming-workbook path "Stream"
        (lambda (wb sws)
          (let ((hdr (workbook-add-style wb fill: fgcolor: 'yellow font: bold)))
            (worksheet-set-cell! sws "A1" "Col1"  'string hdr)
            (worksheet-set-cell! sws "B1" "Col2"  'string hdr)
            (worksheet-set-cell! sws "A2" "Hello" 'string #f)
            (worksheet-set-cell! sws "B2" 123     'num    #f)))))))

;; workbook-save-to-bytevector: returns a non-empty bytevector
(test-group "workbook-save-to-bytevector"
  (test-equal #t
    (let* ((wb (make-workbook))
           (ws (workbook-add-worksheet! wb "Sheet1")))
      (worksheet-set-cell! ws "A1" "hello" 'string #f)
      (let ((bv (workbook-save-to-bytevector wb)))
        (and (bytevector? bv) (> (bytevector-length bv) 0))))))

;; workbook-save-to-bytevector: ZIP magic bytes at offset 0
(test-group "workbook-save-to-bytevector-zip-magic"
  (test-equal #t
    (let* ((wb (make-workbook))
           (ws (workbook-add-worksheet! wb "Sheet1")))
      (worksheet-set-cell! ws "A1" 42 'num #f)
      (let ((bv (workbook-save-to-bytevector wb)))
        (and (= (bytevector-u8-ref bv 0) #x50)   ; P
             (= (bytevector-u8-ref bv 1) #x4B)   ; K
             (= (bytevector-u8-ref bv 2) #x03)
             (= (bytevector-u8-ref bv 3) #x04))))))

;; cells added out of column order are written in correct column order
(test-group "column-order"
  (test-equal #t
    (let* ((path (join-path (special-folder-temp) "test-scm-excel-sort.xlsx"))
           (wb   (make-workbook))
           (ws   (workbook-add-worksheet! wb "Sheet1")))
      (worksheet-set-cell! ws "C1" 3 'num #f)
      (worksheet-set-cell! ws "A1" 1 'num #f)
      (worksheet-set-cell! ws "B1" 2 'num #f)
      (workbook-save wb path)
      (call-with-input-zip path
        (lambda (z)
          (let* ((xml (utf8->string (zip-read-entry-bytevector z "xl/worksheets/sheet1.xml")))
                 (pos-a (string-contains xml "r=\"A1\""))
                 (pos-b (string-contains xml "r=\"B1\""))
                 (pos-c (string-contains xml "r=\"C1\"")))
            (and pos-a pos-b pos-c
                 (< pos-a pos-b)
                 (< pos-b pos-c))))))))

;; rows added out of order are written in correct row order
(test-group "row-order"
  (test-equal #t
    (let* ((path (join-path (special-folder-temp) "test-scm-excel-rowsort.xlsx"))
           (wb   (make-workbook))
           (ws   (workbook-add-worksheet! wb "Sheet1")))
      (worksheet-set-cell! ws "A3" 3 'num #f)
      (worksheet-set-cell! ws "A1" 1 'num #f)
      (worksheet-set-cell! ws "A2" 2 'num #f)
      (workbook-save wb path)
      (call-with-input-zip path
        (lambda (z)
          (let* ((xml (utf8->string (zip-read-entry-bytevector z "xl/worksheets/sheet1.xml")))
                 (pos-1 (string-contains xml "r=\"1\""))
                 (pos-2 (string-contains xml "r=\"2\""))
                 (pos-3 (string-contains xml "r=\"3\"")))
            (and pos-1 pos-2 pos-3
                 (< pos-1 pos-2)
                 (< pos-2 pos-3))))))))

;; ── Reader: round-trip via the writer ─────────────────────────────────────

;; write a workbook, read it back, check values, types and layout
(test-group "reader-roundtrip"
  (let* ((path (join-path (special-folder-temp) "test-scm-excel-read.xlsx"))
         (wb   (make-workbook))
         (ws   (workbook-add-worksheet! wb "Data")))
    (worksheet-set-cell! ws "A1" "Name" 'string #f)
    (worksheet-set-cell! ws "B1" "Age" 'string #f)
    (worksheet-set-cell! ws "A2" "Bob" 'string #f)
    (worksheet-set-cell! ws "B2" 42 'num #f)
    (worksheet-set-cell! ws "C5" 3.5 'num #f)
    (workbook-save wb path)
    (let* ((rwb   (read-workbook path))
           (sheet (workbook-sheet rwb 0)))
      (test-equal '("Data") (workbook-sheet-names rwb))
      (test-equal "Data" (sheet-name sheet))
      (test-equal "Name" (sheet-ref sheet 1 1))
      (test-equal "Age"  (sheet-ref sheet 1 2))
      (test-equal "Bob"  (sheet-ref sheet 2 1))
      (test-equal 42     (sheet-ref sheet 2 2))
      (test-equal 3.5    (sheet-ref sheet 5 3))
      (test-equal #f     (sheet-ref sheet 3 1))
      (test-equal '(5 . 3) (sheet-dimensions sheet))
      ;; sheet-rows yields a dense matrix up to the maximum extent
      (test-equal '("Name" "Age" #f) (car (sheet-rows sheet)))
      ;; sheet-cells yields only populated cells, sorted
      (test-equal '(((1 1) . "Name") ((1 2) . "Age") ((2 1) . "Bob")
                    ((2 2) . 42) ((5 3) . 3.5))
                  (sheet-cells sheet)))))

;; multiple worksheets are resolved by name and index, in order
(test-group "reader-multi-sheet"
  (let* ((path (join-path (special-folder-temp) "test-scm-excel-read-multi.xlsx"))
         (wb   (make-workbook))
         (a    (workbook-add-worksheet! wb "Alpha"))
         (b    (workbook-add-worksheet! wb "Beta")))
    (worksheet-set-cell! a "A1" "in-alpha" 'string #f)
    (worksheet-set-cell! b "A1" "in-beta" 'string #f)
    (workbook-save wb path)
    (let ((rwb (read-workbook path)))
      (test-equal '("Alpha" "Beta") (workbook-sheet-names rwb))
      (test-equal "in-alpha" (sheet-ref (workbook-sheet rwb "Alpha") 1 1))
      (test-equal "in-beta"  (sheet-ref (workbook-sheet rwb "Beta") 1 1))
      (test-equal "in-beta"  (sheet-ref (workbook-sheet rwb 1) 1 1))
      (test-equal #f (workbook-sheet rwb "Nope")))))

;; round-trip through a bytevector
(test-group "reader-from-bytevector"
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb "S")))
    (worksheet-set-cell! ws "A1" "hi" 'string #f)
    (let* ((bv  (workbook-save-to-bytevector wb))
           (rwb (read-workbook-from-bytevector bv)))
      (test-equal "hi" (sheet-ref (workbook-sheet rwb 0) 1 1)))))

;; ── Reader: hand-built workbook for types the writer cannot emit ───────────

;; dates (style numFmt), booleans, inline strings and shared strings
(test-group "reader-cell-types"
  (let* ((ns "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
         (rns "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
         (bv (call-with-output-zip-bytevector
               (lambda (z)
                 (call-with-output-zip-entry z "xl/workbook.xml"
                   (lambda (p)
                     (display (string-append
                       "<?xml version=\"1.0\"?>"
                       "<workbook xmlns=\"" ns "\" xmlns:r=\"" rns "\">"
                       "<sheets><sheet name=\"S\" sheetId=\"1\" r:id=\"rId1\"/></sheets>"
                       "</workbook>") p)))
                 (call-with-output-zip-entry z "xl/_rels/workbook.xml.rels"
                   (lambda (p)
                     (display (string-append
                       "<?xml version=\"1.0\"?>"
                       "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                       "<Relationship Id=\"rId1\" Type=\"x\" Target=\"worksheets/sheet1.xml\"/>"
                       "</Relationships>") p)))
                 (call-with-output-zip-entry z "xl/styles.xml"
                   (lambda (p)
                     (display (string-append
                       "<?xml version=\"1.0\"?>"
                       "<styleSheet xmlns=\"" ns "\">"
                       "<cellXfs count=\"2\"><xf numFmtId=\"0\"/><xf numFmtId=\"14\"/></cellXfs>"
                       "</styleSheet>") p)))
                 (call-with-output-zip-entry z "xl/sharedStrings.xml"
                   (lambda (p)
                     (display (string-append
                       "<?xml version=\"1.0\"?>"
                       "<sst xmlns=\"" ns "\" count=\"1\" uniqueCount=\"1\">"
                       "<si><t>Hello</t></si></sst>") p)))
                 (call-with-output-zip-entry z "xl/worksheets/sheet1.xml"
                   (lambda (p)
                     (display (string-append
                       "<?xml version=\"1.0\"?>"
                       "<worksheet xmlns=\"" ns "\"><sheetData>"
                       "<row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c>"
                       "<c r=\"B1\"><v>3.5</v></c></row>"
                       "<row r=\"2\"><c r=\"A2\" s=\"1\"><v>44197</v></c>"
                       "<c r=\"B2\" t=\"b\"><v>1</v></c></row>"
                       "<row r=\"3\"><c r=\"A3\" t=\"inlineStr\"><is><t>inline</t></is></c></row>"
                       "</sheetData></worksheet>") p))))))
         (rwb   (read-workbook-from-bytevector bv))
         (sheet (workbook-sheet rwb 0)))
    (test-equal "Hello"      (sheet-ref sheet 1 1))   ; shared string
    (test-equal 3.5          (sheet-ref sheet 1 2))   ; number
    (test-equal "2021-01-01" (sheet-ref sheet 2 1))   ; date serial via numFmt 14
    (test-equal #t           (sheet-ref sheet 2 2))   ; boolean
    (test-equal "inline"     (sheet-ref sheet 3 1)))) ; inline string

(test-end "excel")

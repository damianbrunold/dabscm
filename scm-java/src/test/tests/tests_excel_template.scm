(import (scheme base) (scheme write) (scm fs) (scm ooxml excel)
        (scm ooxml excel-reader) (scm ooxml excel template)
        (scm zip) (srfi 13) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "excel-template")

;; A small "designed" template: header row, a summary sheet with a styled
;; empty cell, a style (so xl/styles.xml exists) and a stale calcChain.
(define (make-template-bytes)
  (let* ((wb (make-workbook))
         (data (workbook-add-worksheet! wb "Data"))
         (summary (workbook-add-worksheet! wb "Sum mary"))
         (bold (workbook-add-style wb (font bold))))
    (worksheet-set-cell! data "A1" "ID" 'string bold)
    (worksheet-set-cell! data "B1" "Code" 'string bold)
    (worksheet-set-cell! data "C1" "Status" 'string bold)
    (worksheet-set-cell! data "A2" "old" 'string #f)
    (worksheet-set-cell! summary "B2" "Name" 'string #f)
    (worksheet-set-cell! summary "C2" "" 'string bold)
    (worksheet-set-cell! summary "B4" "Total" 'string #f)
    (workbook-save-to-bytevector wb)))

(define (sheet-xml tpl name)
  (xlsx-part-text tpl (xlsx-sheet-part tpl name)))

(define (before? s a b)
  (let ((ia (string-contains s a)) (ib (string-contains s b)))
    (and ia ib (< ia ib))))

(test-group "open-and-sheets"
  (let ((tpl (open-xlsx-template (make-template-bytes))))
    (test-assert (xlsx-template? tpl))
    (test-equal '("Data" "Sum mary") (xlsx-sheet-names tpl))
    (test-equal "xl/worksheets/sheet1.xml" (xlsx-sheet-part tpl "Data"))
    (test-assert (member "xl/styles.xml" (xlsx-part-names tpl)))
    (test-equal "AB3" (xlsx-cell-ref 3 28))
    (test-equal "Data" (xlsx-quote-sheet-name "Data"))
    (test-equal "'Sum mary'" (xlsx-quote-sheet-name "Sum mary"))
    (test-equal "'it''s'" (xlsx-quote-sheet-name "it's"))))

(test-group "untouched-roundtrip"
  (let* ((bytes (make-template-bytes))
         (tpl (open-xlsx-template bytes))
         (rwb (read-workbook-from-bytevector (xlsx-save-to-bytevector tpl))))
    (test-equal "ID" (sheet-ref (workbook-sheet rwb "Data") 1 1))
    (test-equal "old" (sheet-ref (workbook-sheet rwb "Data") 2 1))
    (test-equal "Total" (sheet-ref (workbook-sheet rwb "Sum mary") 4 2))))

(test-group "replace-rows"
  (let ((tpl (open-xlsx-template (make-template-bytes))))
    (xlsx-replace-sheet-data! tpl "Data" 1
      (lambda (emit)
        (test-equal 2 (emit (list "Z1" 4711 (xlsx-formula "B2*2"))))
        (test-equal 3 (emit (list " pad " #f "a<b&c") (list 1 #f #f)))))
    (let* ((bv (xlsx-save-to-bytevector tpl))
           (rwb (read-workbook-from-bytevector bv))
           (data (workbook-sheet rwb "Data")))
      ;; header kept, old row 2 replaced
      (test-equal "ID" (sheet-ref data 1 1))
      (test-equal "Z1" (sheet-ref data 2 1))
      (test-equal 4711 (sheet-ref data 2 2))
      (test-equal " pad " (sheet-ref data 3 1))
      (test-equal #f (sheet-ref data 3 2))
      (test-equal "a<b&c" (sheet-ref data 3 3))
      (test-equal '(3 . 3) (sheet-dimensions data)))
    ;; the formula is written without a cached value; dimension is dropped
    (let ((xml (call-with-input-zip
                (let ((p (join-path (special-folder-temp) "test-scm-xlsx-tpl-rows.xlsx")))
                  (xlsx-save tpl p)
                  p)
                (lambda (z) (utf8->string (zip-read-entry-bytevector z "xl/worksheets/sheet1.xml"))))))
      (test-assert (string-contains xml "<c r=\"C2\"><f>B2*2</f></c>"))
      (test-assert (string-contains xml "xml:space=\"preserve\""))
      (test-assert (string-contains xml "<c r=\"A3\" s=\"1\""))
      (test-assert (not (string-contains xml "<dimension"))))
    ;; the writer runs on every save
    (let ((rwb (read-workbook-from-bytevector (xlsx-save-to-bytevector tpl))))
      (test-equal "Z1" (sheet-ref (workbook-sheet rwb "Data") 2 1)))))

(test-group "set-cells"
  (let ((tpl (open-xlsx-template (make-template-bytes))))
    (xlsx-set-cells! tpl "Sum mary"
                     (list (list "C2" "Spital & Co")
                           (list "C3" 42)
                           (list "A4" "first")
                           (list "D9" (xlsx-formula "SUM(C3:C3)"))))
    (let ((xml (sheet-xml tpl "Sum mary")))
      ;; the existing cell keeps its style
      (test-assert (string-contains xml "<c r=\"C2\" s=\"1\" t=\"inlineStr\">"))
      ;; cells and rows are inserted in order
      (test-assert (before? xml "<c r=\"A4\"" "<c r=\"B4\""))
      (test-assert (before? xml "<row r=\"3\"" "<row r=\"4\""))
      (test-assert (before? xml "<row r=\"4\"" "<row r=\"9\"")))
    (let* ((rwb (read-workbook-from-bytevector (xlsx-save-to-bytevector tpl)))
           (s (workbook-sheet rwb "Sum mary")))
      (test-equal "Spital & Co" (sheet-ref s 2 3))
      (test-equal "Name" (sheet-ref s 2 2))
      (test-equal 42 (sheet-ref s 3 3))
      (test-equal "first" (sheet-ref s 4 1))
      (test-equal "Total" (sheet-ref s 4 2)))
    ;; a streamed sheet cannot be cell-patched
    (xlsx-replace-sheet-data! tpl "Data" 1 (lambda (emit) #f))
    (test-error (xlsx-set-cells! tpl "Data" (list (list "A1" "x"))))))

(test-group "column-styles"
  (let ((tpl (open-xlsx-template (make-template-bytes))))
    (let ((part (xlsx-sheet-part tpl "Data")))
      (xlsx-set-part-text!
       tpl part
       (let* ((xml (xlsx-part-text tpl part))
              (i (string-contains xml "<sheetData")))
         (string-append (substring xml 0 i)
                        "<cols><col min=\"1\" max=\"1\" width=\"9\" style=\"1\" customWidth=\"1\"/>"
                        "<col min=\"2\" max=\"3\" width=\"9\" outlineLevel=\"1\"/>"
                        "<col min=\"4\" max=\"4\" width=\"9\"/></cols>"
                        (substring xml i (string-length xml))))))
    (let ((cs (xlsx-column-styles tpl "Data")))
      (test-equal 1 (cs 1))
      (test-equal 0 (cs 2))
      (test-equal 0 (cs 99)))
    (xlsx-collapse-outline-cols! tpl "Data" 1)
    (let ((xml (sheet-xml tpl "Data")))
      (test-assert (string-contains xml "<col min=\"2\" max=\"3\" width=\"9\" outlineLevel=\"1\" hidden=\"1\"/>"))
      (test-assert (string-contains xml "<col min=\"4\" max=\"4\" width=\"9\" collapsed=\"1\"/>")))))

(test-group "styles"
  (let ((tpl (open-xlsx-template (make-template-bytes))))
    (test-equal 0 (xlsx-add-dxf! tpl '((fill . "FFFFFF00"))))
    (test-equal 1 (xlsx-add-dxf! tpl '((border-top . "thin") (font-color . "FFFF0000") (bold . #t))))
    (test-equal 49 (xlsx-number-format-id! tpl "@"))
    (test-equal 164 (xlsx-number-format-id! tpl ";;;@"))
    (test-equal 164 (xlsx-number-format-id! tpl ";;;@"))
    (test-equal 165 (xlsx-number-format-id! tpl "0.000"))
    (let* ((xml (xlsx-part-text tpl "xl/styles.xml"))
           (n (xlsx-derive-xf! tpl 1 "@")))
      (test-equal n (xlsx-derive-xf! tpl 1 "@"))
      (test-assert (not (= n (xlsx-derive-xf! tpl 1 ";;;@"))))
      (let ((xml (xlsx-part-text tpl "xl/styles.xml")))
        (test-assert (string-contains xml "<dxfs count=\"2\">"))
        (test-assert (string-contains xml "<numFmts count=\"2\">"))
        (test-assert (before? xml "<numFmts" "<fonts"))
        (test-assert (before? xml "<cellXfs" "<dxfs"))
        (test-assert (string-contains xml "numFmtId=\"49\""))
        (test-assert (string-contains xml "<top style=\"thin\"><color auto=\"1\"/></top>"))))
    ;; the derived styles are usable
    (let ((rwb (read-workbook-from-bytevector (xlsx-save-to-bytevector tpl))))
      (test-equal "ID" (sheet-ref (workbook-sheet rwb "Data") 1 1)))))

(test-group "sheet-extras"
  (let ((tpl (open-xlsx-template (make-template-bytes))))
    (xlsx-replace-sheet-data! tpl "Data" 1 (lambda (emit) (emit (list "a" "b" "c"))))
    (let ((d (xlsx-add-dxf! tpl '((fill . "FFC0C0C0")))))
      (xlsx-add-conditional-formats! tpl "Data"
        (list (list "A2:C9" (list "$A2<>$A1" d))
              (list "B2:B9" (list "NOT(ISERROR(FIND($B2,$C2)))" d #t))))
      (xlsx-add-conditional-formats! tpl "Data" (list (list "C2:C9" (list "C2=\"x\"" d)))))
    (xlsx-add-data-validations! tpl "Data" (list (list "C2:C9" '("ok" "Verstoss"))))
    (xlsx-add-data-validations! tpl "Data" (list (list "C2:C9" '("ok" "unklar"))
                                                 (list "D2:D9" "'Sum mary'!$B$2:$B$4")))
    (test-error (xlsx-add-data-validations! tpl "Data" (list (list "C2" '("a,b")))))
    (xlsx-set-autofilter! tpl "Data" "A1:C9")
    (xlsx-set-autofilter! tpl "Data" "A1:C2")
    (let ((xml (sheet-xml tpl "Data")))
      (test-assert (string-contains xml "<formula>$A2&lt;&gt;$A1</formula>"))
      (test-assert (string-contains xml "priority=\"3\""))
      (test-assert (string-contains xml "stopIfTrue=\"1\""))
      (test-assert (string-contains xml "<dataValidations count=\"2\">"))
      (test-assert (string-contains xml "<formula1>&quot;ok,unklar&quot;</formula1>"))
      (test-assert (not (string-contains xml "Verstoss")))
      (test-assert (string-contains xml "<autoFilter ref=\"A1:C2\"/>"))
      (test-assert (not (string-contains xml "A1:C9\"/>")))
      ;; schema order: sheetData, autoFilter, conditionalFormatting, dataValidations, pageMargins
      (test-assert (before? xml "</sheetData>" "<autoFilter"))
      (test-assert (before? xml "<autoFilter" "<conditionalFormatting"))
      (test-assert (before? xml "sqref=\"C2:C9\"><cfRule" "<dataValidations"))
      (test-assert (before? xml "</dataValidations>" "</worksheet>")))
    (let ((wbx (xlsx-part-text tpl "xl/workbook.xml")))
      (test-assert (string-contains wbx "<definedName name=\"_xlnm._FilterDatabase\" localSheetId=\"0\" hidden=\"1\">Data!$A$1:$C$2</definedName>"))
      (test-equal #f (string-contains wbx "$C$9")))
    (xlsx-set-defined-name! tpl "Codes" "'Sum mary'!$B$2:$B$4")
    (test-assert (string-contains (xlsx-part-text tpl "xl/workbook.xml")
                                  "<definedName name=\"Codes\">'Sum mary'!$B$2:$B$4</definedName>"
                                  ))
    (let ((rwb (read-workbook-from-bytevector (xlsx-save-to-bytevector tpl))))
      (test-equal "a" (sheet-ref (workbook-sheet rwb "Data") 2 1)))))

(test-group "calc-and-text"
  (let ((tpl (open-xlsx-template (make-template-bytes))))
    (xlsx-set-part-text! tpl "xl/calcChain.xml" "<calcChain/>")
    (xlsx-full-calc-on-load! tpl)
    (test-assert (string-contains (xlsx-part-text tpl "xl/workbook.xml")
                                  "<calcPr fullCalcOnLoad=\"1\"/>"))
    (test-assert (not (member "xl/calcChain.xml" (xlsx-part-names tpl))))
    (xlsx-full-calc-on-load! tpl)
    (xlsx-replace-text! tpl '(("Total" . "Summe & Rest")))
    (let ((rwb (read-workbook-from-bytevector (xlsx-save-to-bytevector tpl))))
      (test-equal "Summe & Rest" (sheet-ref (workbook-sheet rwb "Sum mary") 4 2)))))

(test-end "excel-template")

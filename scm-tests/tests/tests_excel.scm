(import (scheme base) (scm fs) (scm ooxml excel) (scm zip) (srfi 13) (scm test))

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

(test-end "excel")

(import (scheme base)
        (scm test)
        (scm fs)
        (scm odf spreadsheet)
        (scm zip))

(test-runner-factory scm-test-runner)

(test-begin "odf_spreadsheet")

;; col-index->string: 1-based column index to letter string
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

;; make-workbook: returns a vector
(test-group "make-workbook"
  (test-equal #t (vector? (make-workbook))))

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

;; workbook-add-style: first style returns a string
(test-group "workbook-add-style"
  (test-equal #t
    (let* ((wb (make-workbook))
           (s  (workbook-add-style wb fill: fgcolor: 'lightblue)))
      (string? s)))
  ;; two styles return different names
  (test-equal #t
    (let* ((wb (make-workbook))
           (s1 (workbook-add-style wb fill: fgcolor: 'lightblue))
           (s2 (workbook-add-style wb font: color: 'red bold)))
      (not (string=? s1 s2)))))

;; workbook-save: write a workbook with cells, returns 'ok
(test-group "workbook-save"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-spreadsheet.ods"))
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
    (let ((path (join-path (special-folder-temp) "test-scm-odf-spreadsheet-cw.ods")))
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
    (let ((path (join-path (special-folder-temp) "test-scm-odf-spreadsheet-stream.ods")))
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

;; mimetype entry content is correct
(test-group "mimetype"
  (test-equal "application/vnd.oasis.opendocument.spreadsheet"
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-spreadsheet-mime.ods"))
           (wb (make-workbook))
           (ws (workbook-add-worksheet! wb "Sheet1")))
      (worksheet-set-cell! ws "A1" "test" 'string #f)
      (workbook-save wb path)
      (call-with-input-zip path
        (lambda (z)
          (utf8->string (zip-read-entry-bytevector z "mimetype")))))))

;; worksheet-set-col-width! and worksheet-set-row-height!
(test-group "col-width-row-height"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-spreadsheet-dims.ods"))
           (wb   (make-workbook))
           (ws   (workbook-add-worksheet! wb "Dims")))
      (worksheet-set-col-width! ws "A" 20)
      (worksheet-set-col-width! ws "B" 40)
      (worksheet-set-row-height! ws 1 30)
      (worksheet-set-cell! ws "A1" "Wide" 'string #f)
      (worksheet-set-cell! ws "B1" "Wider" 'string #f)
      (workbook-save wb path))))

;; boolean cell type
(test-group "boolean-cell"
  (test-equal 'ok
    (let* ((path (join-path (special-folder-temp) "test-scm-odf-spreadsheet-bool.ods"))
           (wb   (make-workbook))
           (ws   (workbook-add-worksheet! wb "Bool")))
      (worksheet-set-cell! ws "A1" #t 'boolean #f)
      (worksheet-set-cell! ws "A2" #f 'boolean #f)
      (workbook-save wb path))))

(test-end "odf_spreadsheet")

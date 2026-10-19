(define-library (scm ooxml excel template)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (srfi 1)
          (except (srfi 13) string-hash)
          (scm fs)
          (scm zip)
          (only (scm ooxml excel) col-index->string))
  (export open-xlsx-template
          xlsx-template?
          xlsx-sheet-names
          xlsx-sheet-part
          xlsx-part-names
          xlsx-part-text
          xlsx-set-part-text!
          xlsx-remove-part!
          xlsx-formula
          xlsx-formula?
          xlsx-formula-text
          xlsx-replace-sheet-data!
          xlsx-set-cells!
          xlsx-column-styles
          xlsx-add-conditional-formats!
          xlsx-remove-conditional-formats!
          xlsx-add-data-validations!
          xlsx-set-autofilter!
          xlsx-set-defined-name!
          xlsx-add-dxf!
          xlsx-number-format-id!
          xlsx-derive-xf!
          xlsx-full-calc-on-load!
          xlsx-collapse-outline-cols!
          xlsx-replace-text!
          xlsx-save
          xlsx-save-to-bytevector
          xlsx-cell-ref
          xlsx-quote-sheet-name)
  (begin

    ;; --------------------------------------------------------------
    ;; Template-based XLSX editing.
    ;;
    ;; Opens an existing workbook (typically a designed template), keeps
    ;; every part it does not touch byte-for-byte, and patches the parts
    ;; it does: worksheet rows and cells, conditional formatting, data
    ;; validation, autofilter, defined names, dxf/numFmt/xf styles and
    ;; calculation settings. Patching works on the XML text of the parts
    ;; with a small tag scanner; there is no DOM.
    ;;
    ;; Strings written into cells are always inline strings, so
    ;; xl/sharedStrings.xml is never rewritten. Formula cells are written
    ;; without cached values; call xlsx-full-calc-on-load! so the
    ;; spreadsheet application recalculates them on open.
    ;;
    ;; Replaced worksheet rows are streamed: the writer procedure given to
    ;; xlsx-replace-sheet-data! runs while the workbook is being saved and
    ;; writes its rows straight into the zip entry.
    ;; --------------------------------------------------------------

    (define-record-type <xlsx-template>
      (make-xlsx-template parts writers xf-cache)
      xlsx-template?
      (parts tpl-parts set-tpl-parts!)          ; list of (name . bytevector|string)
      (writers tpl-writers set-tpl-writers!)    ; alist part-name -> (keep-rows . writer)
      (xf-cache tpl-xf-cache set-tpl-xf-cache!))

    (define-record-type <xlsx-formula>
      (xlsx-formula text)
      xlsx-formula?
      (text xlsx-formula-text))

    (define rows-marker "<!--scm-template-rows-->")

    ;; ---- string helpers ------------------------------------------

    (define (xml-escape str)
      (let ((out (open-output-string)))
        (string-for-each
         (lambda (c)
           (case c
             ((#\&) (write-string "&amp;" out))
             ((#\<) (write-string "&lt;" out))
             ((#\>) (write-string "&gt;" out))
             ((#\") (write-string "&quot;" out))
             (else
              (let ((n (char->integer c)))
                ;; XML 1.0 forbids most control characters
                (when (or (>= n 32) (= n 9) (= n 10) (= n 13))
                  (write-char c out))))))
         str)
        (get-output-string out)))

    (define (xml-unescape str)
      (if (not (string-index str #\&))
          str
          (let loop ((s str)
                     (pairs '(("&lt;" . "<") ("&gt;" . ">") ("&quot;" . "\"")
                              ("&apos;" . "'") ("&amp;" . "&"))))
            (if (null? pairs)
                s
                (loop (replace-all s (caar pairs) (cdar pairs)) (cdr pairs))))))

    (define (replace-all str from to)
      (let ((flen (string-length from)))
        (if (= flen 0)
            str
            (let ((out (open-output-string)))
              (let loop ((start 0))
                (let ((i (string-contains str from start)))
                  (if i
                      (begin
                        (write-string (substring str start i) out)
                        (write-string to out)
                        (loop (+ i flen)))
                      (begin
                        (write-string (substring str start (string-length str)) out)
                        (get-output-string out)))))))))

    (define (tag-name-end? c)
      (or (char=? c #\space) (char=? c #\>) (char=? c #\/)
          (char=? c #\tab) (char=? c #\newline) (char=? c #\return)))

    (define (find-tag xml name start)
      ;; Index of the next "<name" (exact element name) at or after start.
      (let ((needle (string-append "<" name))
            (len (string-length xml)))
        (let loop ((from start))
          (let ((i (string-contains xml needle from)))
            (cond
              ((not i) #f)
              ((and (< (+ i (string-length needle)) len)
                    (tag-name-end? (string-ref xml (+ i (string-length needle)))))
               i)
              (else (loop (+ i 1))))))))

    (define (open-tag-end xml start)
      ;; Index just after the '>' closing the tag starting at start.
      (+ 1 (string-index xml #\> start)))

    (define (self-closing? xml start)
      (let ((e (open-tag-end xml start)))
        (char=? (string-ref xml (- e 2)) #\/)))

    (define (element-end xml name start)
      ;; Index just after the element starting at start.
      (if (self-closing? xml start)
          (open-tag-end xml start)
          (let ((close (string-append "</" name ">")))
            (+ (string-contains xml close start) (string-length close)))))

    (define (tag-attr tag attr)
      ;; Attribute value (unescaped) from an opening tag string, or #f.
      (let ((needle (string-append " " attr "=\"")))
        (let ((i (string-contains tag needle)))
          (and i
               (let* ((vs (+ i (string-length needle)))
                      (ve (string-index tag #\" vs)))
                 (xml-unescape (substring tag vs ve)))))))

    (define (set-tag-attr tag attr value)
      ;; Sets attr in an opening tag string (with or without trailing /).
      (let* ((needle (string-append " " attr "=\""))
             (i (string-contains tag needle))
             (v (xml-escape value)))
        (if i
            (let* ((vs (+ i (string-length needle)))
                   (ve (string-index tag #\" vs)))
              (string-append (substring tag 0 vs) v (substring tag ve (string-length tag))))
            (let* ((len (string-length tag))
                   (cut (if (and (>= len 2) (char=? (string-ref tag (- len 2)) #\/))
                            (- len 2)
                            (- len 1))))
              (string-append (substring tag 0 cut) " " attr "=\"" v "\""
                             (substring tag cut len))))))

    (define (remove-tag-attr tag attr)
      (let* ((needle (string-append " " attr "=\""))
             (i (string-contains tag needle)))
        (if i
            (let ((ve (string-index tag #\" (+ i (string-length needle)))))
              (string-append (substring tag 0 i) (substring tag (+ ve 1) (string-length tag))))
            tag)))

    (define (string-splice str start end new)
      (string-append (substring str 0 start) new (substring str end (string-length str))))

    (define (all-elements xml name start limit)
      ;; List of (start . end) for every <name> element in [start, limit).
      (let loop ((from start) (acc '()))
        (let ((i (find-tag xml name from)))
          (if (or (not i) (>= i limit))
              (reverse acc)
              (let ((e (element-end xml name i)))
                (loop e (cons (cons i e) acc)))))))

    ;; ---- cell references -----------------------------------------

    (define (xlsx-cell-ref row col)
      "Syntax: (xlsx-cell-ref row col)
Library: (scm ooxml excel template)
Description: Returns the A1-style reference for a 1-based row and column.
Example:
  (xlsx-cell-ref 3 28) => \"AB3\""
      (string-append (col-index->string col) (number->string row)))

    (define (ref->row-col ref)
      (let loop ((i 0) (col 0))
        (if (and (< i (string-length ref)) (char-alphabetic? (string-ref ref i)))
            (loop (+ i 1) (+ (* col 26)
                             (- (char->integer (char-upcase (string-ref ref i))) 64)))
            (cons (string->number (substring ref i (string-length ref))) col))))

    (define (xlsx-quote-sheet-name name)
      "Syntax: (xlsx-quote-sheet-name name)
Library: (scm ooxml excel template)
Description: Returns name ready for use in a formula or defined name: quoted
  with single quotes (inner quotes doubled) unless it consists only of
  letters, digits and underscores.
Example:
  (xlsx-quote-sheet-name \"Lies mich\") => \"'Lies mich'\""
      (if (and (> (string-length name) 0)
               (string-every (lambda (c) (or (char-alphabetic? c) (char-numeric? c)
                                             (char=? c #\_)))
                             name))
          name
          (string-append "'" (replace-all name "'" "''") "'")))

    ;; ---- opening ---------------------------------------------------

    (define (read-zip-parts path)
      (call-with-input-zip path
        (lambda (z)
          (map (lambda (name) (cons name (zip-read-entry-bytevector z name)))
               (zip-entry-names z)))))

    (define (open-xlsx-template source)
      "Syntax: (open-xlsx-template path-or-bytevector)
Library: (scm ooxml excel template)
Description: Opens an XLSX workbook from a file path or a bytevector holding
  its bytes and returns a template object. All parts are read into memory;
  parts that are never patched are written back unchanged by xlsx-save.
Example:
  (define tpl (open-xlsx-template \"Vorlage.xlsx\"))"
      (let ((parts
             (if (bytevector? source)
                 (let ((path (mktemp '(prefix . "scm-xlsx-tpl"))))
                   (dynamic-wind
                     (lambda () #f)
                     (lambda ()
                       (let ((p (open-binary-output-file path)))
                         (write-bytevector source p)
                         (close-port p))
                       (read-zip-parts path))
                     (lambda () (delete-file path))))
                 (read-zip-parts source))))
        (make-xlsx-template parts '() '())))

    ;; ---- part access -----------------------------------------------

    (define (xlsx-part-names tpl)
      "Syntax: (xlsx-part-names tpl)
Library: (scm ooxml excel template)
Description: Returns the names of all zip parts of the template, in order.
Example:
  (member \"xl/styles.xml\" (xlsx-part-names tpl)) => (\"xl/styles.xml\" ...)"
      (map car (tpl-parts tpl)))

    (define (xlsx-part-text tpl name)
      "Syntax: (xlsx-part-text tpl name)
Library: (scm ooxml excel template)
Description: Returns the text (UTF-8 decoded) of part name, or #f if the part
  does not exist.
Example:
  (xlsx-part-text tpl \"xl/workbook.xml\") => \"<?xml ...\""
      (let ((p (assoc name (tpl-parts tpl))))
        (and p
             (begin
               (when (bytevector? (cdr p))
                 (set-cdr! p (utf8->string (cdr p))))
               (cdr p)))))

    (define (xlsx-set-part-text! tpl name text)
      "Syntax: (xlsx-set-part-text! tpl name text)
Library: (scm ooxml excel template)
Description: Replaces (or adds) part name with the given text.
Example:
  (xlsx-set-part-text! tpl \"xl/workbook.xml\" xml)"
      (let ((p (assoc name (tpl-parts tpl))))
        (if p
            (set-cdr! p text)
            (set-tpl-parts! tpl (append (tpl-parts tpl) (list (cons name text)))))))

    (define (xlsx-remove-part! tpl name)
      "Syntax: (xlsx-remove-part! tpl name)
Library: (scm ooxml excel template)
Description: Removes part name from the template (no-op if absent). Content
  type overrides and relationships pointing at it are not touched.
Example:
  (xlsx-remove-part! tpl \"xl/calcChain.xml\")"
      (set-tpl-parts! tpl (remove (lambda (p) (string=? (car p) name)) (tpl-parts tpl))))

    (define (update-part! tpl name proc)
      (let ((text (xlsx-part-text tpl name)))
        (unless text
          (error "xlsx template: missing part" name))
        (xlsx-set-part-text! tpl name (proc text))))

    ;; ---- sheets ------------------------------------------------------

    (define (workbook-sheet-entries tpl)
      ;; List of (name rid tag-start tag-end) in workbook order.
      (let* ((xml (xlsx-part-text tpl "xl/workbook.xml"))
             (s (find-tag xml "sheets" 0))
             (e (element-end xml "sheets" s)))
        (map (lambda (se)
               (let ((tag (substring xml (car se) (open-tag-end xml (car se)))))
                 (list (tag-attr tag "name") (tag-attr tag "r:id") (car se) (cdr se))))
             (all-elements xml "sheet" s e))))

    (define (xlsx-sheet-names tpl)
      "Syntax: (xlsx-sheet-names tpl)
Library: (scm ooxml excel template)
Description: Returns the worksheet names in workbook order.
Example:
  (xlsx-sheet-names tpl) => (\"Lies mich\" \"Legende\" ...)"
      (map car (workbook-sheet-entries tpl)))

    (define (workbook-rels tpl)
      (let ((xml (xlsx-part-text tpl "xl/_rels/workbook.xml.rels")))
        (map (lambda (se)
               (let ((tag (substring xml (car se) (open-tag-end xml (car se)))))
                 (list (tag-attr tag "Id") (tag-attr tag "Target") (tag-attr tag "Type"))))
             (all-elements xml "Relationship" 0 (string-length xml)))))

    (define (resolve-target t)
      (if (and (> (string-length t) 0) (char=? (string-ref t 0) #\/))
          (substring t 1 (string-length t))
          (string-append "xl/" t)))

    (define (xlsx-sheet-part tpl sheet)
      "Syntax: (xlsx-sheet-part tpl sheet-name)
Library: (scm ooxml excel template)
Description: Returns the zip part name holding the worksheet called
  sheet-name. An error is raised for unknown sheets.
Example:
  (xlsx-sheet-part tpl \"Leistungscontrolling\") => \"xl/worksheets/sheet4.xml\""
      (let ((entry (assoc sheet (workbook-sheet-entries tpl))))
        (unless entry
          (error "xlsx template: unknown sheet" sheet))
        (let ((rel (assoc (cadr entry) (workbook-rels tpl))))
          (resolve-target (cadr rel)))))

    (define (sheet-index tpl sheet)
      (list-index (lambda (n) (string=? n sheet)) (xlsx-sheet-names tpl)))

    ;; ---- sheetData parsing ------------------------------------------

    (define (sheet-data-bounds xml)
      ;; (values start inner-start inner-end end) of <sheetData>.
      (let ((s (find-tag xml "sheetData" 0)))
        (unless s (error "xlsx template: worksheet without sheetData"))
        (if (self-closing? xml s)
            (let ((e (open-tag-end xml s)))
              (values s e e e))
            (let* ((is (open-tag-end xml s))
                   (ie (string-contains xml "</sheetData>" is)))
              (values s is ie (+ ie (string-length "</sheetData>")))))))

    (define (parse-rows xml start end)
      ;; List of rows (num attrs cells); attrs is the opening tag text
      ;; between "<row" and ">"/"/>"; cells is a list of (col . xml).
      (map (lambda (re)
             (let* ((ts (car re))
                    (te (open-tag-end xml ts))
                    (sc (self-closing? xml ts))
                    (tag (substring xml ts te))
                    (attrs (substring xml (+ ts 4) (- te (if sc 2 1))))
                    (num (string->number (tag-attr tag "r")))
                    (cells (if sc
                               '()
                               (map (lambda (ce)
                                      (let ((ctag (substring xml (car ce)
                                                             (open-tag-end xml (car ce)))))
                                        (cons (cdr (ref->row-col (tag-attr ctag "r")))
                                              (substring xml (car ce) (cdr ce)))))
                                    (all-elements xml "c" te (cdr re))))))
               (list num attrs cells)))
           (all-elements xml "row" start end)))

    (define (render-row row)
      (let ((attrs (cadr row)) (cells (caddr row)))
        (if (null? cells)
            (string-append "<row" attrs "/>")
            (string-append "<row" attrs ">"
                           (apply string-append (map cdr cells))
                           "</row>"))))

    ;; ---- cell rendering --------------------------------------------

    (define (style-attr style)
      (if (and style (not (eqv? style 0)))
          (string-append " s=\"" (number->string style) "\"")
          ""))

    (define (needs-preserve? s)
      (let ((n (string-length s)))
        (and (> n 0)
             (or (char-whitespace? (string-ref s 0))
                 (char-whitespace? (string-ref s (- n 1)))
                 (string-index s #\newline)))))

    (define (number->xml n)
      (cond
        ((and (exact? n) (integer? n)) (number->string n))
        ((exact? n) (number->string (inexact n)))
        ((integer? n) (number->string (exact n)))
        (else (number->string n))))

    (define (write-cell! port ref value style)
      ;; Writes one <c> element; values: #f/'() (empty, only written when
      ;; styled), string, number, boolean #t, xlsx-formula.
      (cond
        ((or (not value) (null? value))
         (when (and style (not (eqv? style 0)))
           (write-string "<c r=\"" port) (write-string ref port) (write-string "\"" port)
           (write-string (style-attr style) port) (write-string "/>" port)))
        ((string? value)
         (write-string "<c r=\"" port) (write-string ref port) (write-string "\"" port)
         (write-string (style-attr style) port)
         (write-string " t=\"inlineStr\"><is><t" port)
         (when (needs-preserve? value) (write-string " xml:space=\"preserve\"" port))
         (write-string ">" port)
         (write-string (xml-escape value) port)
         (write-string "</t></is></c>" port))
        ((number? value)
         (write-string "<c r=\"" port) (write-string ref port) (write-string "\"" port)
         (write-string (style-attr style) port)
         (write-string "><v>" port) (write-string (number->xml value) port)
         (write-string "</v></c>" port))
        ((eq? value #t)
         (write-string "<c r=\"" port) (write-string ref port) (write-string "\"" port)
         (write-string (style-attr style) port)
         (write-string " t=\"b\"><v>1</v></c>" port))
        ((xlsx-formula? value)
         (write-string "<c r=\"" port) (write-string ref port) (write-string "\"" port)
         (write-string (style-attr style) port)
         (write-string "><f>" port) (write-string (xml-escape (xlsx-formula-text value)) port)
         (write-string "</f></c>" port))
        (else (error "xlsx template: unsupported cell value" value))))

    (define (cell->string ref value style)
      (let ((p (open-output-string)))
        (write-cell! p ref value style)
        (get-output-string p)))

    ;; ---- replacing rows ----------------------------------------------

    (define (xlsx-replace-sheet-data! tpl sheet keep-rows writer)
      "Syntax: (xlsx-replace-sheet-data! tpl sheet-name keep-rows writer)
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
  (xlsx-replace-sheet-data! tpl \"Data\" 1
    (lambda (emit)
      (emit (list \"a\" 1 (xlsx-formula \"B2*2\")))))"
      (let ((part (xlsx-sheet-part tpl sheet)))
        (update-part! tpl part
          (lambda (xml)
            (let-values (((s is ie e) (sheet-data-bounds xml)))
              (let* ((rows (filter (lambda (r) (<= (car r) keep-rows))
                                   (parse-rows xml is ie)))
                     (inner (string-append (apply string-append (map render-row rows))
                                           rows-marker))
                     (xml2 (string-append (substring xml 0 s)
                                          "<sheetData>" inner "</sheetData>"
                                          (substring xml e (string-length xml))))
                     (d (find-tag xml2 "dimension" 0)))
                (if d
                    (string-splice xml2 d (element-end xml2 "dimension" d) "")
                    xml2)))))
        (set-tpl-writers! tpl (cons (cons part (cons keep-rows writer))
                                    (remove (lambda (w) (string=? (car w) part))
                                            (tpl-writers tpl))))))

    (define (run-row-writer port keep-rows writer)
      (let ((row keep-rows))
        (writer
         (lambda (values . rest)
           (set! row (+ row 1))
           (let ((rs (number->string row))
                 (styles (if (pair? rest) (car rest) '())))
             (write-string "<row r=\"" port) (write-string rs port) (write-string "\">" port)
             (let loop ((vs values) (ss styles) (col 1))
               (unless (null? vs)
                 (let ((style (if (pair? ss) (car ss) #f)))
                   (write-cell! port (string-append (col-index->string col) rs)
                                (car vs) style)
                   (loop (cdr vs) (if (pair? ss) (cdr ss) '()) (+ col 1)))))
             (write-string "</row>" port))
           row))))

    ;; ---- patching single cells ---------------------------------------

    (define (xlsx-set-cells! tpl sheet specs)
      "Syntax: (xlsx-set-cells! tpl sheet-name specs)
Library: (scm ooxml excel template)
Description: Sets individual cells of a worksheet. Each spec is
  (ref value) or (ref value style): ref is an A1 reference, value as for
  xlsx-replace-sheet-data!. Without a style the existing cell's style is
  kept. Existing cells are replaced, missing cells and rows inserted in
  order. Not usable on a sheet whose rows were replaced.
Example:
  (xlsx-set-cells! tpl \"Summary\"
    (list (list \"C2\" \"Spital X\") (list \"E15\" (xlsx-formula \"SUM(A1:A9)\"))))"
      (let ((part (xlsx-sheet-part tpl sheet)))
        (when (assoc part (tpl-writers tpl))
          (error "xlsx template: cannot set cells on a streamed sheet" sheet))
        (update-part! tpl part
          (lambda (xml)
            (let-values (((s is ie e) (sheet-data-bounds xml)))
              (let loop ((rows (parse-rows xml is ie)) (specs specs))
                (if (null? specs)
                    (string-append (substring xml 0 s)
                                   "<sheetData>"
                                   (apply string-append (map render-row rows))
                                   "</sheetData>"
                                   (substring xml e (string-length xml)))
                    (loop (set-cell-in-rows rows (car specs)) (cdr specs)))))))))

    (define (set-cell-in-rows rows spec)
      (let* ((ref (car spec))
             (value (cadr spec))
             (rc (ref->row-col ref))
             (rnum (car rc))
             (col (cdr rc))
             (row (find (lambda (r) (= (car r) rnum)) rows))
             (old (and row (assv col (caddr row))))
             (style (cond
                      ((pair? (cddr spec)) (caddr spec))
                      (old (let ((s (tag-attr (substring (cdr old) 0
                                                         (open-tag-end (cdr old) 0))
                                              "s")))
                             (and s (string->number s))))
                      (else #f)))
             (cell (cons col (cell->string ref value style))))
        (define (put-cell cells)
          (cond
            ((null? cells) (list cell))
            ((= (caar cells) col) (cons cell (cdr cells)))
            ((> (caar cells) col) (cons cell cells))
            (else (cons (car cells) (put-cell (cdr cells))))))
        (if row
            (map (lambda (r)
                   (if (eq? r row)
                       (list (car r) (remove-tag-attr (cadr r) "spans") (put-cell (caddr r)))
                       r))
                 rows)
            (let ((new (list rnum (string-append " r=\"" (number->string rnum) "\"")
                             (list cell))))
              (let ins ((rs rows))
                (cond
                  ((null? rs) (list new))
                  ((> (caar rs) rnum) (cons new rs))
                  (else (cons (car rs) (ins (cdr rs))))))))))

    ;; ---- column styles ---------------------------------------------

    (define (xlsx-column-styles tpl sheet)
      "Syntax: (xlsx-column-styles tpl sheet-name)
Library: (scm ooxml excel template)
Description: Returns a procedure mapping a 1-based column index to the
  column's default cellXfs index from <cols> (0 when none). Cells written
  without a style do not inherit the column style, so pass these on.
Example:
  ((xlsx-column-styles tpl \"Data\") 3) => 60"
      (let* ((xml (xlsx-part-text tpl (xlsx-sheet-part tpl sheet)))
             (cs (find-tag xml "cols" 0))
             (ranges
              (if (not cs)
                  '()
                  (map (lambda (ce)
                         (let ((tag (substring xml (car ce) (open-tag-end xml (car ce)))))
                           (list (string->number (tag-attr tag "min"))
                                 (string->number (tag-attr tag "max"))
                                 (let ((s (tag-attr tag "style")))
                                   (if s (string->number s) 0)))))
                       (all-elements xml "col" cs (element-end xml "cols" cs))))))
        (lambda (col)
          (let ((r (find (lambda (r) (<= (car r) col (cadr r))) ranges)))
            (if r (caddr r) 0)))))

    ;; ---- worksheet-level elements ------------------------------------

    (define worksheet-order
      '("sheetPr" "dimension" "sheetViews" "sheetFormatPr" "cols" "sheetData"
        "sheetCalcPr" "sheetProtection" "protectedRanges" "scenarios" "autoFilter"
        "sortState" "dataConsolidate" "customSheetViews" "mergeCells" "phoneticPr"
        "conditionalFormatting" "dataValidations" "hyperlinks" "printOptions"
        "pageMargins" "pageSetup" "headerFooter" "rowBreaks" "colBreaks"
        "customProperties" "cellWatches" "ignoredErrors" "smartTags" "drawing"
        "legacyDrawing" "legacyDrawingHF" "drawingHF" "picture" "oleObjects"
        "controls" "webPublishItems" "tableParts" "extLst"))

    (define (after-sheet-data xml)
      (let-values (((s is ie e) (sheet-data-bounds xml))) e))

    (define (insert-sheet-element xml name element)
      ;; Inserts element at its schema position (after sheetData).
      (let* ((start (after-sheet-data xml))
             (following (cdr (member name worksheet-order)))
             (positions (filter-map (lambda (n) (find-tag xml n start)) following))
             (pos (if (null? positions)
                      (string-contains xml "</worksheet>" start)
                      (apply min positions))))
        (string-splice xml pos pos element)))

    (define (remove-sheet-elements xml name)
      (let ((start (after-sheet-data xml)))
        (let loop ((xml xml))
          (let ((i (find-tag xml name start)))
            (if i
                (loop (string-splice xml i (element-end xml name i) ""))
                xml)))))

    (define (max-cf-priority xml)
      (let loop ((from 0) (best 0))
        (let ((i (find-tag xml "cfRule" from)))
          (if i
              (let* ((tag (substring xml i (open-tag-end xml i)))
                     (p (tag-attr tag "priority")))
                (loop (+ i 1) (max best (or (and p (string->number p)) 0))))
              best))))

    (define (xlsx-remove-conditional-formats! tpl sheet)
      "Syntax: (xlsx-remove-conditional-formats! tpl sheet-name)
Library: (scm ooxml excel template)
Description: Removes all (non-extension) conditional formatting of a sheet.
Example:
  (xlsx-remove-conditional-formats! tpl \"Data\")"
      (update-part! tpl (xlsx-sheet-part tpl sheet)
        (lambda (xml) (remove-sheet-elements xml "conditionalFormatting"))))

    (define (xlsx-add-conditional-formats! tpl sheet specs)
      "Syntax: (xlsx-add-conditional-formats! tpl sheet-name specs)
Library: (scm ooxml excel template)
Description: Adds expression-based conditional formatting. Each spec is
  (sqref rule ...) where each rule is (formula dxf-id) or
  (formula dxf-id stop-if-true?). formula uses English function names and
  relative references are relative to the top-left cell of sqref. dxf-id
  comes from xlsx-add-dxf!. Rules get increasing priorities in the given
  order, after any existing rules.
Example:
  (xlsx-add-conditional-formats! tpl \"Data\"
    (list (list \"A2:H100\" (list \"$B2<>$B1\" sep-dxf))))"
      (update-part! tpl (xlsx-sheet-part tpl sheet)
        (lambda (xml)
          (let ((prio (max-cf-priority xml))
                (out (open-output-string)))
            (for-each
             (lambda (spec)
               (write-string "<conditionalFormatting sqref=\"" out)
               (write-string (xml-escape (car spec)) out)
               (write-string "\">" out)
               (for-each
                (lambda (rule)
                  (set! prio (+ prio 1))
                  (write-string "<cfRule type=\"expression\" dxfId=\"" out)
                  (write-string (number->string (cadr rule)) out)
                  (write-string "\" priority=\"" out)
                  (write-string (number->string prio) out)
                  (write-string "\"" out)
                  (when (and (pair? (cddr rule)) (caddr rule))
                    (write-string " stopIfTrue=\"1\"" out))
                  (write-string "><formula>" out)
                  (write-string (xml-escape (car rule)) out)
                  (write-string "</formula></cfRule>" out))
                (cdr spec))
               (write-string "</conditionalFormatting>" out))
             specs)
            (insert-sheet-element xml "conditionalFormatting" (get-output-string out))))))

    (define (xlsx-add-data-validations! tpl sheet specs)
      "Syntax: (xlsx-add-data-validations! tpl sheet-name specs)
Library: (scm ooxml excel template)
Description: Adds list data validations (dropdowns), replacing any existing
  validations of the sheet. Each spec is (sqref items): items is a list of
  strings (inline list; joined length must not exceed 255 characters and
  items must not contain commas) or a string formula such as
  \"Lists!$A$1:$A$7\". Invalid entries are rejected with an error message.
Example:
  (xlsx-add-data-validations! tpl \"Data\"
    (list (list \"F2:F100\" '(\"ok\" \"Verstoss\"))))"
      (define (formula1 items)
        (if (string? items)
            items
            (let ((joined (string-join items ",")))
              (when (> (string-length joined) 255)
                (error "xlsx template: inline validation list longer than 255 characters"
                       joined))
              (when (any (lambda (i) (string-index i #\,)) items)
                (error "xlsx template: validation list item contains a comma" items))
              (string-append "\"" joined "\""))))
      (update-part! tpl (xlsx-sheet-part tpl sheet)
        (lambda (xml)
          (let ((out (open-output-string)))
            (write-string "<dataValidations count=\"" out)
            (write-string (number->string (length specs)) out)
            (write-string "\">" out)
            (for-each
             (lambda (spec)
               (write-string "<dataValidation type=\"list\" allowBlank=\"1\" showInputMessage=\"1\" showErrorMessage=\"1\" sqref=\"" out)
               (write-string (xml-escape (car spec)) out)
               (write-string "\"><formula1>" out)
               (write-string (xml-escape (formula1 (cadr spec))) out)
               (write-string "</formula1></dataValidation>" out))
             specs)
            (write-string "</dataValidations>" out)
            (insert-sheet-element (remove-sheet-elements xml "dataValidations")
                                  "dataValidations" (get-output-string out))))))

    (define (absolute-range range)
      ;; "A1:BE9" -> "$A$1:$BE$9"
      (string-join
       (map (lambda (ref)
              (let ((rc (ref->row-col ref)))
                (string-append "$" (col-index->string (cdr rc)) "$" (number->string (car rc)))))
            (string-split-on range #\:))
       ":"))

    (define (string-split-on s ch)
      (let loop ((start 0) (acc '()))
        (let ((i (string-index s ch start)))
          (if i
              (loop (+ i 1) (cons (substring s start i) acc))
              (reverse (cons (substring s start (string-length s)) acc))))))

    (define (xlsx-set-autofilter! tpl sheet range)
      "Syntax: (xlsx-set-autofilter! tpl sheet-name range)
Library: (scm ooxml excel template)
Description: Sets the autofilter of a sheet to range (e.g. \"A1:BE500\"),
  replacing an existing one, and updates the hidden _xlnm._FilterDatabase
  defined name accordingly.
Example:
  (xlsx-set-autofilter! tpl \"Data\" \"A1:H100\")"
      (update-part! tpl (xlsx-sheet-part tpl sheet)
        (lambda (xml)
          (insert-sheet-element (remove-sheet-elements xml "autoFilter")
                                "autoFilter"
                                (string-append "<autoFilter ref=\"" range "\"/>"))))
      (xlsx-set-defined-name! tpl "_xlnm._FilterDatabase"
                              (string-append (xlsx-quote-sheet-name sheet) "!"
                                             (absolute-range range))
                              sheet #t))

    ;; ---- workbook ------------------------------------------------------

    (define (xlsx-set-defined-name! tpl name value . opts)
      "Syntax: (xlsx-set-defined-name! tpl name value [local-sheet [hidden?]])
Library: (scm ooxml excel template)
Description: Sets (or adds) a defined name in xl/workbook.xml. local-sheet is
  a sheet name for a sheet-scoped name or #f for a global one.
Example:
  (xlsx-set-defined-name! tpl \"Codes\" \"Lists!$A$1:$A$9\")"
      (let* ((local (and (pair? opts) (car opts)))
             (hidden (and (pair? opts) (pair? (cdr opts)) (cadr opts)))
             (local-id (and local (sheet-index tpl local)))
             (element (string-append
                       "<definedName name=\"" (xml-escape name) "\""
                       (if local-id
                           (string-append " localSheetId=\"" (number->string local-id) "\"")
                           "")
                       (if hidden " hidden=\"1\"" "")
                       ">" (xml-escape value) "</definedName>")))
        (when (and local (not local-id))
          (error "xlsx template: unknown sheet" local))
        (update-part! tpl "xl/workbook.xml"
          (lambda (xml)
            (let ((dn (find-tag xml "definedNames" 0)))
              (if (not dn)
                  (let ((pos (+ (string-contains xml "</sheets>")
                                (string-length "</sheets>"))))
                    (string-splice xml pos pos
                                   (string-append "<definedNames>" element "</definedNames>")))
                  (let* ((de (element-end xml "definedNames" dn))
                         (match
                          (find (lambda (se)
                                  (let ((tag (substring xml (car se) (open-tag-end xml (car se)))))
                                    (and (equal? (tag-attr tag "name") name)
                                         (equal? (tag-attr tag "localSheetId")
                                                 (and local-id (number->string local-id))))))
                                (all-elements xml "definedName" dn de))))
                    (if match
                        (string-splice xml (car match) (cdr match) element)
                        (let ((pos (string-contains xml "</definedNames>" dn)))
                          (string-splice xml pos pos element))))))))))

    (define (xlsx-full-calc-on-load! tpl)
      "Syntax: (xlsx-full-calc-on-load! tpl)
Library: (scm ooxml excel template)
Description: Makes the spreadsheet application recalculate all formulas when
  the workbook is opened (calcPr fullCalcOnLoad) and removes a stale
  xl/calcChain.xml with its relationship and content type.
Example:
  (xlsx-full-calc-on-load! tpl)"
      (update-part! tpl "xl/workbook.xml"
        (lambda (xml)
          (let ((c (find-tag xml "calcPr" 0)))
            (if c
                (let ((te (open-tag-end xml c)))
                  (string-splice xml c te
                                 (set-tag-attr (substring xml c te) "fullCalcOnLoad" "1")))
                (let* ((anchor (or (string-contains xml "</definedNames>")
                                   (string-contains xml "</sheets>")))
                       (pos (+ anchor (if (string-prefix? "</definedNames>"
                                                          (substring xml anchor (string-length xml)))
                                          (string-length "</definedNames>")
                                          (string-length "</sheets>")))))
                  (string-splice xml pos pos "<calcPr fullCalcOnLoad=\"1\"/>"))))))
      (when (assoc "xl/calcChain.xml" (tpl-parts tpl))
        (xlsx-remove-part! tpl "xl/calcChain.xml")
        (update-part! tpl "[Content_Types].xml"
          (lambda (xml) (remove-elements-matching xml "Override" "/xl/calcChain.xml")))
        (update-part! tpl "xl/_rels/workbook.xml.rels"
          (lambda (xml) (remove-elements-matching xml "Relationship" "calcChain.xml")))))

    (define (remove-elements-matching xml name needle)
      (let loop ((xml xml) (from 0))
        (let ((i (find-tag xml name from)))
          (if (not i)
              xml
              (let ((e (element-end xml name i)))
                (if (string-contains (substring xml i e) needle)
                    (loop (string-splice xml i e "") i)
                    (loop xml e)))))))

    (define (xlsx-collapse-outline-cols! tpl sheet level)
      "Syntax: (xlsx-collapse-outline-cols! tpl sheet-name level)
Library: (scm ooxml excel template)
Description: Collapses grouped columns: every <col> with an outlineLevel >=
  level is hidden and the column following each such group is marked
  collapsed (like Outline.ShowLevels ColumnLevels:=level-1).
Example:
  (xlsx-collapse-outline-cols! tpl \"Data\" 1)"
      (update-part! tpl (xlsx-sheet-part tpl sheet)
        (lambda (xml)
          (let ((cs (find-tag xml "cols" 0)))
            (if (not cs)
                xml
                (let* ((ce (element-end xml "cols" cs))
                       (cols (all-elements xml "col" cs ce))
                       (tags (map (lambda (se) (substring xml (car se) (cdr se))) cols))
                       (grouped? (lambda (tag)
                                   (let ((l (tag-attr tag "outlineLevel")))
                                     (and l (>= (string->number l) level)))))
                       (new-tags
                        (let loop ((ts tags) (prev-grouped #f) (prev-max #f) (acc '()))
                          (if (null? ts)
                              (reverse acc)
                              (let* ((tag (car ts))
                                     (g (grouped? tag))
                                     (mn (string->number (tag-attr tag "min")))
                                     (mx (string->number (tag-attr tag "max")))
                                     (tag2 (cond
                                             (g (set-tag-attr tag "hidden" "1"))
                                             ((and prev-grouped (eqv? mn (+ prev-max 1)))
                                              (set-tag-attr tag "collapsed" "1"))
                                             (else tag))))
                                (loop (cdr ts) g mx (cons tag2 acc)))))))
                  (string-append (substring xml 0 (car (first cols)))
                                 (apply string-append new-tags)
                                 (substring xml (cdr (last cols)) (string-length xml)))))))))

    (define (xlsx-replace-text! tpl replacements)
      "Syntax: (xlsx-replace-text! tpl replacements)
Library: (scm ooxml excel template)
Description: Replaces literal text placeholders in the shared strings and in
  all drawings (text boxes). replacements is an alist of (from . to) plain
  strings; both are XML-escaped. A placeholder split across formatting runs
  is not found.
Example:
  (xlsx-replace-text! tpl '((\"{DATUM}\" . \"30. Juni 2026\")))"
      (for-each
       (lambda (name)
         (when (or (string=? name "xl/sharedStrings.xml")
                   (and (string-prefix? "xl/drawings/" name)
                        (string-suffix? ".xml" name)
                        (not (string-contains name "_rels"))))
           (update-part! tpl name
             (lambda (xml)
               (fold (lambda (r xml) (replace-all xml (xml-escape (car r)) (xml-escape (cdr r))))
                     xml replacements)))))
       (xlsx-part-names tpl)))

    ;; ---- styles ----------------------------------------------------

    (define styles-order
      '("numFmts" "fonts" "fills" "borders" "cellStyleXfs" "cellXfs" "cellStyles"
        "dxfs" "tableStyles" "colors" "extLst"))

    (define (insert-styles-element xml name element)
      (let* ((following (cdr (member name styles-order)))
             (positions (filter-map (lambda (n) (find-tag xml n 0)) following))
             (pos (if (null? positions)
                      (string-contains xml "</styleSheet>")
                      (apply min positions))))
        (string-splice xml pos pos element)))

    (define (append-to-collection xml name child)
      ;; Appends child to <name count=..> (created if missing); returns
      ;; (new-xml . index-of-child).
      (let ((i (find-tag xml name 0)))
        (if (not i)
            (cons (insert-styles-element xml name
                                         (string-append "<" name " count=\"1\">" child
                                                        "</" name ">"))
                  0)
            (let* ((te (open-tag-end xml i))
                   (tag (substring xml i te))
                   (sc (self-closing? xml i))
                   (count (let ((c (tag-attr tag "count"))) (if c (string->number c) 0)))
                   (open (set-tag-attr (if sc
                                           (string-append (substring tag 0 (- (string-length tag) 2)) ">")
                                           tag)
                                       "count" (number->string (+ count 1)))))
              (if sc
                  (cons (string-splice xml i te (string-append open child "</" name ">")) count)
                  (let* ((close (string-contains xml (string-append "</" name ">") te))
                         (xml2 (string-splice xml close close child)))
                    (cons (string-splice xml2 i te open) count)))))))

    (define (color-xml tag color)
      (if color (string-append "<" tag " rgb=\"" color "\"/>") ""))

    (define (xlsx-add-dxf! tpl options)
      "Syntax: (xlsx-add-dxf! tpl options)
Library: (scm ooxml excel template)
Description: Adds a differential format (used by conditional formatting) to
  xl/styles.xml and returns its index. options is an alist with keys
  font-color (ARGB string), bold, italic (booleans), fill (ARGB string,
  solid background) and border-left/-right/-top/-bottom (border style such
  as \"thin\"), border-color (ARGB, default automatic).
Example:
  (xlsx-add-dxf! tpl '((fill . \"FFFFFF00\")))  => 0
  (xlsx-add-dxf! tpl '((border-top . \"thin\")))  => 1"
      (define (opt k) (let ((p (assq k options))) (and p (cdr p))))
      (let* ((font (if (or (opt 'font-color) (opt 'bold) (opt 'italic))
                       (string-append "<font>"
                                      (if (opt 'bold) "<b/>" "")
                                      (if (opt 'italic) "<i/>" "")
                                      (color-xml "color" (opt 'font-color))
                                      "</font>")
                       ""))
             (fill (if (opt 'fill)
                       (string-append "<fill><patternFill patternType=\"solid\">"
                                      (color-xml "fgColor" (opt 'fill))
                                      (color-xml "bgColor" (opt 'fill))
                                      "</patternFill></fill>")
                       ""))
             (bcolor (if (opt 'border-color)
                         (color-xml "color" (opt 'border-color))
                         "<color auto=\"1\"/>"))
             (side (lambda (key tag)
                     (if (opt key)
                         (string-append "<" tag " style=\"" (opt key) "\">" bcolor "</" tag ">")
                         "")))
             (border (if (any opt '(border-left border-right border-top border-bottom))
                         (string-append "<border>"
                                        (side 'border-left "left")
                                        (side 'border-right "right")
                                        (side 'border-top "top")
                                        (side 'border-bottom "bottom")
                                        "</border>")
                         ""))
             (dxf (string-append "<dxf>" font fill border "</dxf>"))
             (result #f))
        (update-part! tpl "xl/styles.xml"
          (lambda (xml)
            (let ((r (append-to-collection xml "dxfs" dxf)))
              (set! result (cdr r))
              (car r))))
        result))

    (define builtin-num-fmts
      '(("General" . 0) ("0" . 1) ("0.00" . 2) ("#,##0" . 3) ("#,##0.00" . 4)
        ("0%" . 9) ("0.00%" . 10) ("0.00E+00" . 11) ("@" . 49)))

    (define (xlsx-number-format-id! tpl code)
      "Syntax: (xlsx-number-format-id! tpl format-code)
Library: (scm ooxml excel template)
Description: Returns the numFmtId for format-code, using the built-in id
  where one exists (\"@\" => 49), an existing custom format, or adding a new
  custom <numFmt> (id >= 164) to xl/styles.xml.
Example:
  (xlsx-number-format-id! tpl \";;;@\") => 164"
      (let ((b (assoc code builtin-num-fmts)))
        (if b
            (cdr b)
            (let* ((xml (xlsx-part-text tpl "xl/styles.xml"))
                   (nf (find-tag xml "numFmts" 0))
                   (fmts (if nf
                             (map (lambda (se)
                                    (let ((tag (substring xml (car se) (open-tag-end xml (car se)))))
                                      (cons (tag-attr tag "formatCode")
                                            (string->number (tag-attr tag "numFmtId")))))
                                  (all-elements xml "numFmt" nf (element-end xml "numFmts" nf)))
                             '()))
                   (existing (assoc code fmts)))
              (if existing
                  (cdr existing)
                  (let ((id (+ 1 (fold max 163 (map cdr fmts)))))
                    (xlsx-set-part-text!
                     tpl "xl/styles.xml"
                     (car (append-to-collection
                           xml "numFmts"
                           (string-append "<numFmt numFmtId=\"" (number->string id)
                                          "\" formatCode=\"" (xml-escape code) "\"/>"))))
                    id))))))

    (define (xlsx-derive-xf! tpl base-xf code)
      "Syntax: (xlsx-derive-xf! tpl base-xf-index format-code)
Library: (scm ooxml excel template)
Description: Returns the index of a cellXfs entry equal to base-xf-index but
  with number format format-code, adding it on first use (cached per
  template).
Example:
  (xlsx-derive-xf! tpl 36 \"@\") => 94"
      (let* ((key (cons base-xf code))
             (hit (assoc key (tpl-xf-cache tpl))))
        (if hit
            (cdr hit)
            (let* ((fmt-id (xlsx-number-format-id! tpl code))
                   (xml (xlsx-part-text tpl "xl/styles.xml"))
                   (cx (find-tag xml "cellXfs" 0))
                   (xfs (all-elements xml "xf" cx (element-end xml "cellXfs" cx)))
                   (base (list-ref xfs base-xf))
                   (base-xml (substring xml (car base) (cdr base)))
                   (te (open-tag-end base-xml 0))
                   (tag (set-tag-attr (set-tag-attr (substring base-xml 0 te)
                                                    "numFmtId" (number->string fmt-id))
                                      "applyNumberFormat" "1"))
                   (new-xml (string-append tag (substring base-xml te (string-length base-xml))))
                   (r (append-to-collection xml "cellXfs" new-xml)))
              (xlsx-set-part-text! tpl "xl/styles.xml" (car r))
              (set-tpl-xf-cache! tpl (cons (cons key (cdr r)) (tpl-xf-cache tpl)))
              (cdr r)))))

    ;; ---- saving --------------------------------------------------------

    (define (write-parts tpl zp)
      (for-each
       (lambda (part)
         (let ((name (car part))
               (content (cdr part))
               (w (assoc (car part) (tpl-writers tpl))))
           (cond
             (w
              (let* ((i (string-contains content rows-marker))
                     (p (zip-add-text-entry zp name 0)))
                (write-string (substring content 0 i) p)
                (run-row-writer p (cadr w) (cddr w))
                (write-string (substring content (+ i (string-length rows-marker))
                                         (string-length content))
                              p)
                (flush-output-port p)))
             ((string? content)
              (let ((p (zip-add-text-entry zp name 0)))
                (write-string content p)
                (flush-output-port p)))
             (else
              (let ((p (zip-add-binary-entry zp name)))
                (write-bytevector content p)
                (flush-output-port p))))))
       (tpl-parts tpl)))

    (define (xlsx-save tpl filename)
      "Syntax: (xlsx-save tpl filename)
Library: (scm ooxml excel template)
Description: Writes the (patched) workbook to filename. Row writers given to
  xlsx-replace-sheet-data! run now. Returns 'ok.
Example:
  (xlsx-save tpl \"out.xlsx\") => ok"
      (call-with-output-zip filename (lambda (zp) (write-parts tpl zp)))
      'ok)

    (define (xlsx-save-to-bytevector tpl)
      "Syntax: (xlsx-save-to-bytevector tpl)
Library: (scm ooxml excel template)
Description: Like xlsx-save, but returns the workbook bytes as a bytevector.
Example:
  (bytevector? (xlsx-save-to-bytevector tpl)) => #t"
      (call-with-output-zip-bytevector (lambda (zp) (write-parts tpl zp))))))

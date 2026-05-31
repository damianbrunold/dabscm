(define-library (scm ooxml excel-reader)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (srfi 1)
          (except (srfi 13) string-hash)
          (srfi 69)
          (srfi 132)
          (scm fs)
          (scm zip)
          (scm xml))
  (export read-workbook
          read-workbook-from-bytevector
          workbook-sheet-names
          workbook-sheets
          workbook-sheet
          sheet-name
          sheet-dimensions
          sheet-ref
          sheet-rows
          sheet-cells)
  (begin

    ;; --------------------------------------------------------------
    ;; Reader for the core sheet contents of XLSX (SpreadsheetML)
    ;; workbooks. Built purely on (scm zip) and (scm xml).
    ;;
    ;; Reads cell values only: strings (shared and inline), numbers,
    ;; booleans and formula cached values. Date-formatted cells are
    ;; recognised via xl/styles.xml and returned as ISO 8601 strings
    ;; ("YYYY-MM-DD", "YYYY-MM-DDTHH:MM:SS" or "HH:MM:SS").
    ;;
    ;; Not read: styling, merged-cell geometry, charts, images,
    ;; comments and data validation.
    ;; --------------------------------------------------------------

    ;; ---- generic XML helpers -------------------------------------

    (define (local-name qname)
      ;; Strip any namespace prefix from an XML qualified name.
      (let ((i (string-index qname #\:)))
        (if i (substring qname (+ i 1) (string-length qname)) qname)))

    (define (attr r . names)
      ;; Return the first present attribute among names, or #f.
      (let loop ((ns names))
        (if (null? ns)
            #f
            (or (xml-attribute r (car ns)) (loop (cdr ns))))))

    (define (with-reader bv proc)
      ;; Open an XML reader over a bytevector, run proc, always close.
      (let ((r (open-xml-bytevector bv)))
        (guard (exn (#t (close-xml r) (raise exn)))
          (let ((result (proc r)))
            (close-xml r)
            result))))

    ;; ---- cell reference parsing ----------------------------------

    (define (parse-cell-ref ref)
      ;; "AB12" -> (12 . 28): a (row . col) pair, both 1-based.
      (let ((n (string-length ref)))
        (let loop ((i 0) (col 0))
          (if (and (< i n) (char-alphabetic? (string-ref ref i)))
              (loop (+ i 1)
                    (+ (* col 26)
                       (+ 1 (- (char->integer (char-upcase (string-ref ref i)))
                               (char->integer #\A)))))
              (cons (or (string->number (substring ref i n)) 0) col)))))

    ;; ---- date detection and conversion ---------------------------

    (define excel-date-builtin-ids
      '(14 15 16 17 18 19 20 21 22 45 46 47))

    (define (date-format-code? code)
      ;; Heuristic: a format code denotes a date/time if, after removing
      ;; quoted literals, [bracketed] sections and backslash escapes, it
      ;; still contains one of the date/time letters y m d h s.
      (let ((n (string-length code)))
        (let loop ((i 0))
          (if (>= i n)
              #f
              (let ((ch (string-ref code i)))
                (cond
                  ((char=? ch #\")
                   (let skip ((j (+ i 1)))
                     (cond ((>= j n) #f)
                           ((char=? (string-ref code j) #\") (loop (+ j 1)))
                           (else (skip (+ j 1))))))
                  ((char=? ch #\[)
                   (let skip ((j (+ i 1)))
                     (cond ((>= j n) #f)
                           ((char=? (string-ref code j) #\]) (loop (+ j 1)))
                           (else (skip (+ j 1))))))
                  ((char=? ch #\\) (loop (+ i 2)))
                  (else
                   (if (memv (char-downcase ch) '(#\y #\m #\d #\h #\s))
                       #t
                       (loop (+ i 1))))))))))

    (define (civil-from-days z0)
      ;; Howard Hinnant's days-from-civil inverse: convert a day count
      ;; relative to 1970-01-01 into a (year month day) list.
      (let* ((z (+ z0 719468))
             (era (quotient (if (>= z 0) z (- z 146096)) 146097))
             (doe (- z (* era 146097)))
             (yoe (quotient (+ (- doe (quotient doe 1460))
                               (quotient doe 36524)
                               (- (quotient doe 146096)))
                            365))
             (y (+ yoe (* era 400)))
             (doy (- doe (+ (* 365 yoe) (quotient yoe 4) (- (quotient yoe 100)))))
             (mp (quotient (+ (* 5 doy) 2) 153))
             (d (+ (- doy (quotient (+ (* 153 mp) 2) 5)) 1))
             (m (if (< mp 10) (+ mp 3) (- mp 9))))
        (list (if (<= m 2) (+ y 1) y) m d)))

    (define (pad2 n) (string-pad (number->string n) 2 #\0))
    (define (pad4 n) (string-pad (number->string n) 4 #\0))

    (define (serial->iso serial)
      ;; Convert an Excel date serial number to an ISO 8601 string.
      ;; Uses the standard 1899-12-30 epoch (serial 25569 = 1970-01-01),
      ;; which matches Excel for all dates from 1900-03-01 onward.
      (let* ((days (exact (floor serial)))
             (frac (- serial days))
             (raw-secs (exact (round (* frac 86400))))
             (carry (quotient raw-secs 86400))
             (secs (- raw-secs (* carry 86400)))
             (days (+ days carry))
             (h (quotient secs 3600))
             (mi (quotient (- secs (* h 3600)) 60))
             (s (- secs (* h 3600) (* mi 60)))
             (time-str (string-append (pad2 h) ":" (pad2 mi) ":" (pad2 s))))
        (cond
          ;; Pure time-of-day value (serial in [0,1)): no meaningful date.
          ((and (< serial 1) (>= serial 0)) time-str)
          (else
           (let* ((ymd (civil-from-days (- days 25569)))
                  (date-str (string-append (pad4 (car ymd)) "-"
                                           (pad2 (cadr ymd)) "-"
                                           (pad2 (caddr ymd)))))
             (if (= secs 0)
                 date-str
                 (string-append date-str "T" time-str)))))))

    ;; ---- styles.xml: which style indexes are dates ---------------

    (define (parse-styles bv)
      ;; Returns a vector indexed by cellXfs position; #t where that
      ;; style applies a date/time number format. Missing styles -> #f.
      (if (not bv)
          (vector)
          (with-reader bv
            (lambda (r)
              ;; First pass collects custom numFmt codes; the cellXfs
              ;; section always follows numFmts in styles.xml, so a
              ;; single forward scan suffices.
              (let ((custom (make-hash-table)))
                (let loop ((xfs '()) (in-cellxfs #f) (cont #t))
                  (cond
                    ((not cont) (list->vector (reverse xfs)))
                    (else
                     (case (xml-node-type r)
                       ((element)
                        (let ((nm (local-name (xml-name r))))
                          (cond
                            ((string=? nm "numFmt")
                             (let ((id (string->number (or (attr r "numFmtId") "")))
                                   (code (attr r "formatCode")))
                               (when (and id code)
                                 (hash-table-set! custom id code))
                               (loop xfs in-cellxfs (xml-read r))))
                            ((string=? nm "cellXfs")
                             (loop xfs #t (xml-read r)))
                            ((and in-cellxfs (string=? nm "xf"))
                             (let* ((id (string->number (or (attr r "numFmtId") "0")))
                                    (date? (and id (date-numfmt? id custom))))
                               (loop (cons date? xfs) in-cellxfs (xml-read r))))
                            (else (loop xfs in-cellxfs (xml-read r))))))
                       ((end-element)
                        (let ((nm (local-name (xml-name r))))
                          (if (string=? nm "cellXfs")
                              (loop xfs #f (xml-read r))
                              (loop xfs in-cellxfs (xml-read r)))))
                       (else (loop xfs in-cellxfs (xml-read r))))))))))))

    (define (date-numfmt? id custom)
      (or (memv id excel-date-builtin-ids)
          (let ((code (hash-table-ref/default custom id #f)))
            (and code (date-format-code? code)))))

    (define (style-date? styles idx)
      (and (>= idx 0)
           (< idx (vector-length styles))
           (vector-ref styles idx)))

    ;; ---- sharedStrings.xml ---------------------------------------

    (define (parse-shared-strings bv)
      ;; Returns a vector of strings indexed by shared-string id. Rich
      ;; text runs within an <si> are concatenated.
      (if (not bv)
          (vector)
          (with-reader bv
            (lambda (r)
              (let loop ((acc '()) (cur #f) (cont #t))
                (cond
                  ((not cont) (list->vector (reverse acc)))
                  (else
                   (case (xml-node-type r)
                     ((element)
                      (let ((nm (local-name (xml-name r))))
                        (cond
                          ((string=? nm "si") (loop acc "" (xml-read r)))
                          ((string=? nm "t")
                           (let ((txt (or (xml-value r) "")))
                             ;; xml-value consumed the element; do not re-read.
                             (loop acc (if cur (string-append cur txt) txt) #t)))
                          (else (loop acc cur (xml-read r))))))
                     ((end-element)
                      (if (string=? (local-name (xml-name r)) "si")
                          (loop (cons (or cur "") acc) #f (xml-read r))
                          (loop acc cur (xml-read r))))
                     (else (loop acc cur (xml-read r)))))))))))

    ;; ---- worksheet sheetN.xml ------------------------------------

    (define (parse-sheet bv name shared styles)
      ;; Parse one worksheet into a sheet object. shared is the
      ;; shared-strings vector, styles the date-style vector.
      (let ((cells (make-hash-table))
            (maxrow 0)
            (maxcol 0)
            (cur-ref #f)
            (cur-style 0)
            (cur-type #f))
        (define (store! value)
          (when cur-ref
            (let* ((rc (parse-cell-ref cur-ref))
                   (row (car rc))
                   (col (cdr rc)))
              (when (> row maxrow) (set! maxrow row))
              (when (> col maxcol) (set! maxcol col))
              (hash-table-set! cells (cell-key row col) value))))
        (with-reader bv
          (lambda (r)
            (let loop ((cont #t))
              (cond
                ((not cont) #t)
                (else
                 (case (xml-node-type r)
                   ((element)
                    (let ((nm (local-name (xml-name r))))
                      (cond
                        ((string=? nm "c")
                         (set! cur-ref (attr r "r"))
                         (set! cur-style (or (string->number (or (attr r "s") "0")) 0))
                         (set! cur-type (attr r "t"))
                         (loop (xml-read r)))
                        ((string=? nm "v")
                         (let ((txt (or (xml-value r) "")))
                           (store! (typed-value txt cur-type cur-style shared styles))
                           (loop #t)))
                        ((string=? nm "t")
                         ;; Inline-string text: <c t="inlineStr"><is><t>..</t></is></c>
                         (let ((txt (or (xml-value r) "")))
                           (when (equal? cur-type "inlineStr") (store! txt))
                           (loop #t)))
                        (else (loop (xml-read r))))))
                   ((end-element)
                    (when (string=? (local-name (xml-name r)) "c")
                      (set! cur-ref #f))
                    (loop (xml-read r)))
                   (else (loop (xml-read r)))))))))
        (vector 'xlsx-sheet name cells maxrow maxcol)))

    (define (typed-value txt type style shared styles)
      ;; Map a raw <v> text plus its cell type/style to a Scheme value.
      (cond
        ((equal? type "s")
         (let ((idx (string->number txt)))
           (if (and idx (>= idx 0) (< idx (vector-length shared)))
               (vector-ref shared idx)
               "")))
        ((equal? type "str") txt)
        ((equal? type "inlineStr") txt)
        ((equal? type "b") (not (equal? (string-trim-both txt) "0")))
        ((equal? type "e") txt)              ; error value, kept as text
        (else
         (let ((num (string->number (string-trim-both txt))))
           (cond
             ((not num) txt)
             ((style-date? styles style) (serial->iso num))
             (else num))))))

    ;; ---- workbook plumbing ---------------------------------------

    (define (cell-key row col) (+ (* row 16384) col))

    (define (parse-rels bv)
      ;; Map relationship id -> target path (relative to xl/).
      (if (not bv)
          '()
          (with-reader bv
            (lambda (r)
              (let loop ((acc '()) (cont #t))
                (cond
                  ((not cont) (reverse acc))
                  (else
                   (case (xml-node-type r)
                     ((element)
                      (if (string=? (local-name (xml-name r)) "Relationship")
                          (let ((id (attr r "Id"))
                                (target (attr r "Target")))
                            (loop (if (and id target) (cons (cons id target) acc) acc)
                                  (xml-read r)))
                          (loop acc (xml-read r))))
                     (else (loop acc (xml-read r)))))))))))

    (define (parse-workbook-sheets bv)
      ;; Ordered list of (sheet-name . relationship-id) from workbook.xml.
      (if (not bv)
          '()
          (with-reader bv
            (lambda (r)
              (let loop ((acc '()) (cont #t))
                (cond
                  ((not cont) (reverse acc))
                  (else
                   (case (xml-node-type r)
                     ((element)
                      (if (string=? (local-name (xml-name r)) "sheet")
                          (let ((name (or (attr r "name") ""))
                                (rid (attr r "r:id" "id")))
                            (loop (cons (cons name rid) acc) (xml-read r)))
                          (loop acc (xml-read r))))
                     (else (loop acc (xml-read r)))))))))))

    (define (resolve-target t)
      (cond
        ((not t) #f)
        ((and (> (string-length t) 0) (char=? (string-ref t 0) #\/))
         (substring t 1 (string-length t)))
        (else (string-append "xl/" t))))

    (define (zip-entry bv-zip name)
      ;; Read a zip entry as a bytevector, or #f if absent.
      (and (member name (zip-entry-names bv-zip))
           (zip-read-entry-bytevector bv-zip name)))

    (define (read-workbook-from-zip z)
      (let* ((shared (parse-shared-strings (zip-entry z "xl/sharedStrings.xml")))
             (styles (parse-styles (zip-entry z "xl/styles.xml")))
             (rels (parse-rels (zip-entry z "xl/_rels/workbook.xml.rels")))
             (order (parse-workbook-sheets (zip-entry z "xl/workbook.xml"))))
        (vector 'xlsx-workbook
                (filter-map
                  (lambda (entry)
                    (let* ((name (car entry))
                           (rid (cdr entry))
                           (target (and rid (cdr (or (assoc rid rels) '(#f . #f)))))
                           (path (resolve-target target))
                           (sbv (and path (zip-entry z path))))
                      (and sbv (cons name (parse-sheet sbv name shared styles)))))
                  order))))

    ;; ---- public API ----------------------------------------------

    (define (read-workbook path)
      "Syntax: (read-workbook path)
Library: (scm ooxml excel-reader)
Description: Reads the core sheet contents of the XLSX workbook at path and
  returns a workbook object. Cell values become Scheme strings, numbers and
  booleans; date-formatted cells become ISO 8601 strings. Use workbook-sheet,
  sheet-ref, sheet-rows and sheet-cells to access the data. Styling, merged
  cells, charts and images are not read.
Example:
  (let ((wb (read-workbook \"report.xlsx\")))
    (sheet-ref (workbook-sheet wb 0) 1 1)) => \"Name\""
      (call-with-input-zip path read-workbook-from-zip))

    (define (read-workbook-from-bytevector bv)
      "Syntax: (read-workbook-from-bytevector bv)
Library: (scm ooxml excel-reader)
Description: Like read-workbook, but reads from an in-memory bytevector holding
  the bytes of an XLSX file. The bytes are written to a temporary file (the
  underlying zip reader is file-based) which is removed before returning.
Example:
  (read-workbook-from-bytevector (workbook-save-to-bytevector wb))"
      (let ((path (mktemp '(prefix . "scm-xlsx-read"))))
        (dynamic-wind
          (lambda () #f)
          (lambda ()
            (let ((p (open-binary-output-file path)))
              (write-bytevector bv p)
              (close-port p))
            (read-workbook path))
          (lambda () (delete-file path)))))

    (define (workbook-sheet-names wb)
      "Syntax: (workbook-sheet-names wb)
Library: (scm ooxml excel-reader)
Description: Returns the list of worksheet names in workbook order.
Example:
  (workbook-sheet-names wb) => (\"Sheet1\" \"Data\")"
      (map car (vector-ref wb 1)))

    (define (workbook-sheets wb)
      "Syntax: (workbook-sheets wb)
Library: (scm ooxml excel-reader)
Description: Returns the list of all sheet objects in workbook order.
Example:
  (map sheet-name (workbook-sheets wb)) => (\"Sheet1\" \"Data\")"
      (map cdr (vector-ref wb 1)))

    (define (workbook-sheet wb name-or-index)
      "Syntax: (workbook-sheet wb name-or-index)
Library: (scm ooxml excel-reader)
Description: Returns a sheet object by name (string) or by 0-based position
  (integer), or #f if there is no such sheet.
Example:
  (workbook-sheet wb 0)
  (workbook-sheet wb \"Data\")"
      (let ((sheets (vector-ref wb 1)))
        (cond
          ((string? name-or-index)
           (let ((p (assoc name-or-index sheets)))
             (and p (cdr p))))
          ((and (integer? name-or-index)
                (>= name-or-index 0)
                (< name-or-index (length sheets)))
           (cdr (list-ref sheets name-or-index)))
          (else #f))))

    (define (sheet-name sheet)
      "Syntax: (sheet-name sheet)
Library: (scm ooxml excel-reader)
Description: Returns the name of a sheet object.
Example:
  (sheet-name (workbook-sheet wb 0)) => \"Sheet1\""
      (vector-ref sheet 1))

    (define (sheet-dimensions sheet)
      "Syntax: (sheet-dimensions sheet)
Library: (scm ooxml excel-reader)
Description: Returns (max-row . max-col), the 1-based extent of the populated
  cells, or (0 . 0) for an empty sheet.
Example:
  (sheet-dimensions sheet) => (10 . 3)"
      (cons (vector-ref sheet 3) (vector-ref sheet 4)))

    (define (sheet-ref sheet row col)
      "Syntax: (sheet-ref sheet row col)
Library: (scm ooxml excel-reader)
Description: Returns the value of the cell at the 1-based row and column, or #f
  if the cell is empty.
Example:
  (sheet-ref sheet 1 1) => \"Name\"
  (sheet-ref sheet 2 2) => 42"
      (hash-table-ref/default (vector-ref sheet 2) (cell-key row col) #f))

    (define (sheet-rows sheet)
      "Syntax: (sheet-rows sheet)
Library: (scm ooxml excel-reader)
Description: Returns the sheet as a list of rows (top to bottom). Each row is a
  list of cell values from column 1 to the sheet's maximum column; empty cells
  are #f. Returns the empty list for an empty sheet.
Example:
  (sheet-rows sheet) => ((\"Name\" \"Age\") (\"Bob\" 42))"
      (let ((maxrow (vector-ref sheet 3))
            (maxcol (vector-ref sheet 4))
            (cells (vector-ref sheet 2)))
        (if (or (= maxrow 0) (= maxcol 0))
            '()
            (map (lambda (row)
                   (map (lambda (col)
                          (hash-table-ref/default cells (cell-key row col) #f))
                        (iota maxcol 1)))
                 (iota maxrow 1)))))

    (define (sheet-cells sheet)
      "Syntax: (sheet-cells sheet)
Library: (scm ooxml excel-reader)
Description: Returns the populated cells only, as a list of ((row col) . value)
  pairs sorted by row then column. Useful for sparse sheets.
Example:
  (sheet-cells sheet) => (((1 1) . \"Name\") ((2 1) . \"Bob\") ((2 2) . 42))"
      (let ((pairs (hash-table->alist (vector-ref sheet 2))))
        (map (lambda (p)
               (let ((row (quotient (car p) 16384))
                     (col (remainder (car p) 16384)))
                 (cons (list row col) (cdr p))))
             (list-sort (lambda (a b) (< (car a) (car b))) pairs))))
))

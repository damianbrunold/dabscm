(define-library (scm ooxml excel)
  (export make-workbook
          workbook-add-worksheet!
          workbook-styles
          worksheet-set-cell!
          worksheet-set-col-width!
          worksheet-set-row-height!
          worksheet-set-autofilter!
          workbook-save
          workbook-save-to-bytevector
          make-style
          workbook-add-style
          resolve-color
          register-color!
          call-with-streaming-workbook
          call-with-worksheet
          col-index->string
          row-col->cell-id
          open-streaming-workbook
          streaming-table-write-row!
          streaming-table-write-styled-row!
          streaming-table-finish!
          streaming-table-row-num
          streaming-table-set-col-width!
          streaming-table-set-row-height!
          streaming-table-set-autofilter!
          call-with-streaming-table
          open-streaming-table)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme write)
          (scm compile)
          (scm dict)
          (scm io)
          (srfi 132)
          (scm list)
          (scm macro)
          (scm zip))

  (begin
    (define xml-preamble
      "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")

    (define *color-table* (make-dict))
    (dict-put *color-table* 'black      "FF000000")
    (dict-put *color-table* 'white      "FFFFFFFF")
    (dict-put *color-table* 'red        "FFFF0000")
    (dict-put *color-table* 'darkred    "FF8B0000")
    (dict-put *color-table* 'lightred   "FFFF8080")
    (dict-put *color-table* 'green      "FF00B050")
    (dict-put *color-table* 'darkgreen  "FF008000")
    (dict-put *color-table* 'lightgreen "FF90EE90")
    (dict-put *color-table* 'blue       "FF0070C0")
    (dict-put *color-table* 'darkblue   "FF00008B")
    (dict-put *color-table* 'lightblue  "FFADD8E6")
    (dict-put *color-table* 'yellow     "FFFFFF00")
    (dict-put *color-table* 'orange     "FFFF8000")
    (dict-put *color-table* 'purple     "FF800080")
    (dict-put *color-table* 'gray       "FF808080")
    (dict-put *color-table* 'darkgray   "FF404040")
    (dict-put *color-table* 'lightgray  "FFD3D3D3")

    (define (register-color! name hex-string)
      "Syntax: (register-color! name hex-string)
Library: (scm ooxml excel)
Description: Registers a new named color in the color table used by resolve-color.
name is a symbol; hex-string is an 8-character ARGB hex string (e.g. \"FFFF0000\").
Example:
  (register-color! 'salmon \"FFFA8072\")"
      (dict-put *color-table* name hex-string))

    (define (resolve-color color)
      "Syntax: (resolve-color color)
Library: (scm ooxml excel)
Description: Resolves a color value to an 8-character ARGB hex string. color may
be a string (returned as-is) or a symbol naming a known color (black, white, red,
darkred, lightred, green, darkgreen, lightgreen, blue, darkblue, lightblue,
yellow, orange, purple, gray, darkgray, lightgray). Signals an error for unknown
color symbols.
Example:
  (resolve-color 'red)       => \"FFFF0000\"
  (resolve-color \"FF0000FF\") => \"FF0000FF\""
      (if (string? color)
          color
          (or (dict-get *color-table* color #f)
              (error "unknown color" color))))

    (define (xml-escape str)
      (let loop ((chars (string->list str)) (acc '()))
        (if (null? chars)
            (list->string (reverse acc))
            (let* ((c (car chars))
                   (replacement (cond ((char=? c #\&) (string->list "&amp;"))
                                      ((char=? c #\<) (string->list "&lt;"))
                                      ((char=? c #\>) (string->list "&gt;"))
                                      ((char=? c #\") (string->list "&quot;"))
                                      (else           (list c)))))
              (loop (cdr chars) (append (reverse replacement) acc))))))

    (define (cell-id-split id)
      ;; Returns (col . row) e.g. "AA12" -> ("AA" . "12")
      (let loop ((i 0))
        (if (or (= i (string-length id))
                (char-numeric? (string-ref id i)))
            (cons (substring id 0 i) (substring id i))
            (loop (+ i 1)))))

    (define (col-string->index col)
      ;; Converts column letters to 1-based index: "A"->1, "Z"->26, "AA"->27
      (let loop ((chars (string->list col)) (result 0))
        (if (null? chars)
            result
            (loop (cdr chars)
                  (+ (* result 26)
                     (- (char->integer (car chars))
                        (char->integer #\A)
                        -1))))))

    (define (col-index->string col)
      "Syntax: (col-index->string col)
Library: (scm ooxml excel)
Description: Converts a 1-based column index to its Excel column letter string.
Example:
  (col-index->string 1)  => \"A\"
  (col-index->string 26) => \"Z\"
  (col-index->string 27) => \"AA\""
      (let loop ((col col) (result '()))
        (if (= col 0)
            (list->string result)
            (let ((r (modulo (- col 1) 26)))
              (loop (quotient (- col 1) 26)
                    (cons (integer->char (+ (char->integer #\A) r)) result))))))

    (define (row-col->cell-id row col)
      "Syntax: (row-col->cell-id row col)
Library: (scm ooxml excel)
Description: Returns the Excel cell ID string for the given 1-based row and
column indices.
Example:
  (row-col->cell-id 1 1)  => \"A1\"
  (row-col->cell-id 3 28) => \"AB3\""
      (string-append (col-index->string col) (number->string row)))

    (define (sorted-dict-entries d)
      (let ((entries (dict-entries d)))
        (list-sort (lambda (a b) (< (string->number (car a)) (string->number (car b)))) entries)))

    (define (sorted-col-entries d)
      (let ((entries (dict-entries d)))
        (list-sort (lambda (a b)
                     (< (col-string->index (car a))
                        (col-string->index (car b))))
                   entries)))

    (define (sorted-cell-values d)
      (let ((cells (dict-values d)))
        (list-sort (lambda (a b)
                     (< (col-string->index (car (cell-id-split (cell-id a))))
                        (col-string->index (car (cell-id-split (cell-id b))))))
                   cells)))

    (define ns-base-package
      "http://schemas.openxmlformats.org/package/2006")

    (define ns-base-office-doc
      "http://schemas.openxmlformats.org/officeDocument/2006")

    (define ns-base-spreadsheetml
      "http://schemas.openxmlformats.org/spreadsheetml/2006")

    (define content-type-base
      "application/vnd.openxmlformats-officedocument")

    (define (ns type)
      (case type
        ((relationships)
         (string-append ns-base-package "/relationships"))
        ((content-types)
         (string-append ns-base-package "/content-types"))
        ((doc-relationships)
         (string-append ns-base-office-doc "/relationships"))
        ((spreadsheetml-main)
         (string-append ns-base-spreadsheetml "/main"))))

    (define (rel-type type)
      (case type
        ((office-doc)
         (string-append ns-base-office-doc "/relationships/officeDocument"))
        ((styles)
         (string-append ns-base-office-doc "/relationships/styles"))
        ((worksheet)
         (string-append ns-base-office-doc "/relationships/worksheet"))
        ((shared-strings)
         (string-append ns-base-office-doc "/relationships/sharedStrings"))))

    (define (content-type type)
      (case type
        ((rel+xml)
         "application/vnd.openxmlformats-package.relationships+xml")
        ((xml)
         "application/xml")
        ((wb)
         (string-append content-type-base ".spreadsheetml.sheet.main+xml"))
        ((ws)
         (string-append content-type-base ".spreadsheetml.worksheet+xml"))
        ((styles)
         (string-append content-type-base ".spreadsheetml.styles+xml"))
        ((shared-strings)
         (string-append content-type-base ".spreadsheetml.sharedStrings+xml"))))

    (define (make-cell id value type style)
      (vector 'cell id value type style))

    (define (make-string-cell id value style)
      (make-cell id value 'string style))

    (define (make-num-cell id value style)
      (make-cell id value 'num style))

    (define (cell-id c) (vector-ref c 1))
    (define (cell-value c) (vector-ref c 2))
    (define (cell-type c) (vector-ref c 3))
    (define (cell-style c) (vector-ref c 4))

    (define (make-workbook)
      "Syntax: (make-workbook)
Library: (scm ooxml excel)
Description: Creates and returns a new empty workbook object.
Example:
  (let ((wb (make-workbook)))
    (workbook-add-worksheet! wb \"Sheet1\")
    (workbook-save wb \"out.xlsx\"))"
      (vector 'wb
              (make-shared-strings)
              (make-styles)
              '())) ;; worksheets

    (define (workbook-shared-strings wb) (vector-ref wb 1))
    (define (workbook-styles wb)
      "Syntax: (workbook-styles wb)
Library: (scm ooxml excel)
Description: Returns the styles object for wb. Works for both regular workbooks
and streaming workbook proxies. The styles object is used internally by
workbook-add-style.
Example:
  ((workbook-styles wb) 'styles-count) => 0"
      (if (procedure? wb)
          (wb 'styles)
          (vector-ref wb 2)))
    (define (workbook-styles-count wb) ((workbook-styles wb) 'styles-count))
    (define (workbook-worksheets wb) (vector-ref wb 3))
    (define (workbook-worksheets-count wb) (length (workbook-worksheets wb)))

    (define (workbook-worksheets! wb sheets) (vector-set! wb 3 sheets))

    (define (workbook-write-zip wb zp)
      (define (add-zip-entry name contents)
        (call-with-output-zip-entry
         zp name
         (lambda (port) (display contents port))
         0))
      (add-zip-entry "_rels/.rels"
                     (render-rels))
      (add-zip-entry "[Content_Types].xml"
                     (render-content-types wb))
      (add-zip-entry "xl/_rels/workbook.xml.rels"
                     (render-wb-rels wb))
      (add-zip-entry "xl/workbook.xml"
                     (render-workbook wb))
      (add-zip-entry "xl/sharedStrings.xml"
                     (shared-strings-render (workbook-shared-strings wb)))
      (when (> (workbook-styles-count wb) 0)
        (add-zip-entry "xl/styles.xml"
                       ((workbook-styles wb) 'render)))
      (let loop ((sheets (workbook-worksheets wb)))
        (unless (null? sheets)
          (add-zip-entry (format #f "xl/worksheets/sheet~a.xml"
                                 (worksheet-id (car sheets)))
                         (render-worksheet (car sheets)))
          (loop (cdr sheets)))))

    (define (workbook-save wb filename)
      "Syntax: (workbook-save wb filename)
Library: (scm ooxml excel)
Description: Serializes wb to an XLSX file at the given filename path. All
worksheets added via workbook-add-worksheet! are included. Returns 'ok.
Example:
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb \"Data\")))
    (worksheet-set-cell! ws \"A1\" \"hello\" 'string #f)
    (workbook-save wb \"/tmp/out.xlsx\"))"
      (call-with-output-zip filename (lambda (zp) (workbook-write-zip wb zp)))
      'ok)

    (define (workbook-save-to-bytevector wb)
      "Syntax: (workbook-save-to-bytevector wb)
Library: (scm ooxml excel)
Description: Serializes wb to an XLSX file in memory and returns the bytes as
a bytevector. Useful for generating documents for HTTP responses or in-memory
processing without writing to disk.
Example:
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb \"Data\")))
    (worksheet-set-cell! ws \"A1\" \"hello\" 'string #f)
    (workbook-save-to-bytevector wb))"
      (call-with-output-zip-bytevector (lambda (zp) (workbook-write-zip wb zp))))

    (define (workbook-add-worksheet! wb name)
      "Syntax: (workbook-add-worksheet! wb name)
Library: (scm ooxml excel)
Description: Adds a new worksheet named name to wb and returns the new worksheet
object. Worksheets are saved in the order they are added.
Example:
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb \"Sheet1\")))
    (worksheet-set-cell! ws \"A1\" 42 'num #f))"
      (let ((sheets (workbook-worksheets wb)))
        (let ((new-sheet (make-worksheet name
                                         (+ (length sheets) 1)
                                         (workbook-shared-strings wb))))
          (workbook-worksheets! wb (append sheets (list new-sheet)))
          new-sheet)))

    (define (make-worksheet name i ss)
      (vector 'ws name i (make-dict) ss (make-dict) (make-dict) #f))

    (define (worksheet-name ws)        (vector-ref ws 1))
    (define (worksheet-id ws)          (vector-ref ws 2))
    (define (worksheet-rows ws)        (vector-ref ws 3))
    (define (worksheet-ss ws)          (vector-ref ws 4))
    (define (worksheet-col-widths ws)  (vector-ref ws 5))
    (define (worksheet-row-heights ws) (vector-ref ws 6))
    (define (worksheet-autofilter ws)  (vector-ref ws 7))

    (define (worksheet-set-col-width! ws col width)
      "Syntax: (worksheet-set-col-width! ws col width)
Library: (scm ooxml excel)
Description: Sets the width of the column identified by the letter string col
in worksheet ws. Works for both regular and streaming worksheets.
Example:
  (worksheet-set-col-width! ws \"A\" 20)
  (worksheet-set-col-width! ws \"B\" 12.5)"
      (if (procedure? ws)
          (ws 'set-col-width! col width)
          (dict-put (worksheet-col-widths ws) col width)))

    (define (worksheet-set-row-height! ws row height)
      "Syntax: (worksheet-set-row-height! ws row height)
Library: (scm ooxml excel)
Description: Sets the height (in points) of the 1-based row index in worksheet
ws. Works for both regular and streaming worksheets.
Example:
  (worksheet-set-row-height! ws 1 30)"
      (if (procedure? ws)
          (ws 'set-row-height! row height)
          (dict-put (worksheet-row-heights ws) (number->string row) height)))

    (define (worksheet-set-autofilter! ws ref)
      "Syntax: (worksheet-set-autofilter! ws ref)
Library: (scm ooxml excel)
Description: Adds an AutoFilter to worksheet ws over the cell range ref. ref is
an A1-notation range string. Works for both regular and streaming worksheets.
Example:
  (worksheet-set-autofilter! ws \"A1:E1\")"
      (if (procedure? ws)
          (ws 'set-autofilter! ref)
          (vector-set! ws 7 ref)))

    (define (worksheet-set-cell! ws id value type style)
      "Syntax: (worksheet-set-cell! ws id value type style)
Library: (scm ooxml excel)
Description: Sets the cell at id (an A1-notation string such as \"B3\") in
worksheet ws. type is either 'string or 'num. style is either #f for no style
or a style index returned by workbook-add-style. Works for both regular and
streaming worksheets. For streaming worksheets, cells must be written in
row-ascending order.
Example:
  (worksheet-set-cell! ws \"A1\" \"hello\" 'string #f)
  (worksheet-set-cell! ws \"B2\" 42 'num #f)
  (worksheet-set-cell! ws \"C3\" \"hi\" 'string my-style)"
      (if (procedure? ws)
          (ws 'set-cell! id value type style)
          (let ((row (cdr (cell-id-split id)))
                (rows (worksheet-rows ws)))
            (unless (dict-contains rows row)
              (dict-put rows row (make-dict)))
            (let ((data (dict-get rows row)))
              (if (eq? type 'string)
                  (let ((ss (worksheet-ss ws)))
                    (dict-put data id (make-string-cell id (shared-strings-put! ss value) style)))
                  (dict-put data id (make-num-cell id value style)))))))

    (define (render-cell port cell)
      (let ((style-attr (if (cell-style cell)
                            (format #f " s=\"~a\"" (cell-style cell))
                            ""))
            (type-attr  (if (eq? (cell-type cell) 'string) " t=\"s\"" "")))
        (format port "<c r=\"~a\"~a~a><v>~a</v></c>"
                (cell-id cell) style-attr type-attr (cell-value cell))))

    (define (render-worksheet ws)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<worksheet xmlns=\"~a\">" (ns 'spreadsheetml-main))
         ;; Column widths
         (unless (= 0 (dict-size (worksheet-col-widths ws)))
           (display "<cols>" port)
           (for-each (lambda (entry)
                       (format port "<col min=\"~a\" max=\"~a\" width=\"~a\" customWidth=\"1\"/>"
                               (col-string->index (car entry))
                               (col-string->index (car entry))
                               (cdr entry)))
                     (sorted-col-entries (worksheet-col-widths ws)))
           (display "</cols>" port))
         (display "<sheetData>" port)
         (let ((row-heights (worksheet-row-heights ws)))
           (let loop-rows ((rows (sorted-dict-entries (worksheet-rows ws))))
             (unless (null? rows)
               (let* ((row  (caar rows))
                      (data (cdar rows))
                      (rh   (and (dict-contains row-heights row)
                                 (dict-get row-heights row))))
                 (if rh
                     (format port "<row r=\"~a\" ht=\"~a\" customHeight=\"1\">" row rh)
                     (format port "<row r=\"~a\">" row))
                 (let loop-cells ((cells (sorted-cell-values data)))
                   (unless (null? cells)
                     (render-cell port (car cells))
                     (loop-cells (cdr cells))))
                 (display "</row>" port))
               (loop-rows (cdr rows)))))
         (display "</sheetData>" port)
         ;; Autofilter
         (let ((af (worksheet-autofilter ws)))
           (when af
             (format port "<autoFilter ref=\"~a\"/>" af)))
         (display "</worksheet>" port))))

    ;; Style system
    (define (make-font)
      (let ((name "Calibri")
            (family "2")
            (scheme #f)
            (sz "11")
            (color "FF000000")
            (bold #f)
            (italic #f))
        (lambda (action . args)
          (case action
            ((set-name)   (set! name (car args)))
            ((set-family) (set! family (car args)))
            ((set-scheme) (set! scheme (car args)))
            ((set-sz)     (set! sz (car args)))
            ((set-color)  (set! color (car args)))
            ((set-bold)   (set! bold (car args)))
            ((set-italic) (set! italic (car args)))
            ((get) (vector name family scheme sz color bold italic))))))

    (define (make-fill)
      (let ((type "none")
            (fgcolor #f)
            (bgcolor #f))
        (lambda (action . args)
          (case action
            ((set-type)    (set! type (car args)))
            ((set-fgcolor) (set! fgcolor (car args)))
            ((set-bgcolor) (set! bgcolor (car args)))
            ((get) (vector type fgcolor bgcolor))))))

    (define (make-border)
      (let ((left #f)
            (right #f)
            (top #f)
            (bottom #f)
            (diagonal #f))
        (lambda (action . args)
          (case action
            ((set-left)     (set! left     (list (car args) "FF000000")))
            ((set-right)    (set! right    (list (car args) "FF000000")))
            ((set-top)      (set! top      (list (car args) "FF000000")))
            ((set-bottom)   (set! bottom   (list (car args) "FF000000")))
            ((set-diagonal) (set! diagonal (list (car args) "FF000000")))
            ((get) (vector left right top bottom diagonal))))))

    (define (make-alignment)
      (let ((rotation 0))
        (lambda (action . args)
          (case action
            ((set-rotation) (set! rotation (car args)))
            ((get) rotation)))))

    (define (make-style)
      "Syntax: (make-style)
Library: (scm ooxml excel)
Description: Creates and returns a new mutable style object with default font
(Calibri 11pt black), no fill, no border, and no alignment. The style object
is a message-passing procedure accepting set-font, set-fill, set-border, and
set-alignment actions. Use workbook-add-style instead of this function directly.
Example:
  (let ((s (make-style)))
    (s 'set-font 'color 'red 'bold #t)
    (s 'set-fill 'fgcolor 'lightblue))"
      (let ((font (make-font))
            (fill (make-fill))
            (border (make-border))
            (alignment (make-alignment)))
        (lambda (action . args)
          (case action
            ((set-font)
             (let loop ((props args))
               (unless (null? props)
                 (let ((prop (car props))
                       (val (cadr props)))
                   (case prop
                     ((name)   (font 'set-name val))
                     ((family) (font 'set-family val))
                     ((scheme) (font 'set-scheme val))
                     ((sz)     (font 'set-sz val))
                     ((color)  (font 'set-color (resolve-color val)))
                     ((bold)   (font 'set-bold val))
                     ((italic) (font 'set-italic val)))
                   (loop (cddr props))))))
            ((set-fill)
             (let loop ((props args))
               (unless (null? props)
                 (let ((prop (car props))
                       (val (cadr props)))
                   (case prop
                     ((type)    (fill 'set-type val))
                     ((fgcolor) (fill 'set-fgcolor (resolve-color val)))
                     ((bgcolor) (fill 'set-bgcolor (resolve-color val))))
                   (loop (cddr props))))))
            ((set-border)
             (let loop ((props args))
               (unless (null? props)
                 (let ((prop (car props))
                       (val (cadr props)))
                   (case prop
                     ((left)     (border 'set-left val))
                     ((right)    (border 'set-right val))
                     ((top)      (border 'set-top val))
                     ((bottom)   (border 'set-bottom val))
                     ((diagonal) (border 'set-diagonal val)))
                   (loop (cddr props))))))
            ((set-alignment)
             (let loop ((props args))
               (unless (null? props)
                 (let ((prop (car props))
                       (val (cadr props)))
                   (case prop
                     ((rotation) (alignment 'set-rotation val)))
                   (loop (cddr props))))))
            ((get-font)      (font 'get))
            ((get-fill)      (fill 'get))
            ((get-border)    (border 'get))
            ((get-alignment) (alignment 'get))))))

    (define (make-styles)
      (let ((fonts (list (vector "Calibri" "2" #f "11" "FF000000" #f #f)))
            (fills (list (vector "none" #f #f)
                         (vector "gray125" #f #f)))
            (borders (list (vector #f #f #f #f #f)))
            (alignments (list 0))
            (styles '()))
        (lambda (action . args)
          (case action
            ((add-style)
             (let ((style (car args)))
               (let* ((font (style 'get-font))
                      (fill (style 'get-fill))
                      (border (style 'get-border))
                      (alignment (style 'get-alignment))
                      (font-id #f)
                      (fill-id #f)
                      (border-id #f)
                      (alignment-id #f))
                 ;; Add font if not already present
                 (set! font-id (or (let loop ((i 0) (fs fonts))
                                     (cond ((null? fs) #f)
                                           ((equal? (car fs) font) i)
                                           (else (loop (+ i 1) (cdr fs)))))
                                   (let ((id (length fonts)))
                                     (set! fonts (append fonts (list font)))
                                     id)))
                 ;; Add fill if not already present
                 (set! fill-id (or (let loop ((i 0) (fs fills))
                                     (cond ((null? fs) #f)
                                           ((equal? (car fs) fill) i)
                                           (else (loop (+ i 1) (cdr fs)))))
                                   (let ((id (length fills)))
                                     (set! fills (append fills (list fill)))
                                     id)))
                 ;; Add border if not already present
                 (set! border-id (or (let loop ((i 0) (bs borders))
                                       (cond ((null? bs) #f)
                                             ((equal? (car bs) border) i)
                                             (else (loop (+ i 1) (cdr bs)))))
                                     (let ((id (length borders)))
                                       (set! borders
                                             (append borders (list border)))
                                       id)))
                 ;; Add alignment if not already present
                 (set! alignment-id (or (let loop ((i 0) (as alignments))
                                          (cond ((null? as) #f)
                                                ((equal? (car as) alignment) i)
                                                (else (loop (+ i 1) (cdr as)))))
                                        (let ((id (length alignments)))
                                          (set! alignments
                                                (append alignments
                                                        (list alignment)))
                                          id)))
                 (set! styles (append styles
                                      (list (vector font-id
                                                    fill-id
                                                    border-id
                                                    alignment-id))))
                 (length styles))))
            ((styles-count) (length styles))
            ((render)
             (call-with-output-string
              (lambda (port)
                (display xml-preamble port)
                (format port "<styleSheet xmlns=\"~a\">" (ns 'spreadsheetml-main))
                ;; Render fonts
                (format port "<fonts count=\"~a\">" (length fonts))
                (for-each (lambda (font)
                            (display "<font>" port)
                            (format port "<name val=\"~a\"/>" (vector-ref font 0))
                            (format port "<family val=\"~a\"/>" (vector-ref font 1))
                            (when (vector-ref font 2)
                              (format port "<scheme val=\"~a\"/>" (vector-ref font 2)))
                            (format port "<sz val=\"~a\"/>" (vector-ref font 3))
                            (format port "<color rgb=\"~a\"/>" (vector-ref font 4))
                            (when (vector-ref font 5) (display "<b val=\"1\"/>" port))
                            (when (vector-ref font 6) (display "<i val=\"1\"/>" port))
                            (display "</font>" port))
                          fonts)
                (display "</fonts>" port)

                ;; Render fills
                (format port "<fills count=\"~a\">" (length fills))
                (for-each (lambda (fill)
                            (display "<fill>" port)
                            (format port "<patternFill patternType=\"~a\">" (vector-ref fill 0))
                            (when (vector-ref fill 1)
                              (format port "<fgColor rgb=\"~a\"/>" (vector-ref fill 1)))
                            (when (vector-ref fill 2)
                              (format port "<bgColor rgb=\"~a\"/>" (vector-ref fill 2)))
                            (format port "</patternFill>")
                            (display "</fill>" port))
                          fills)
                (display "</fills>" port)

                ;; Render borders
                (format port "<borders count=\"~a\">" (length borders))
                (for-each (lambda (border)
                            (display "<border>" port)
                            (let ((b (vector-ref border 0)))
                              (if b
                                  (format port "<left style=\"~a\"><color rgb=\"~a\"/></left>" (car b) (cadr b))
                                  (display "<left/>" port)))
                            (let ((b (vector-ref border 1)))
                              (if b
                                  (format port "<right style=\"~a\"><color rgb=\"~a\"/></right>" (car b) (cadr b))
                                  (display "<right/>" port)))
                            (let ((b (vector-ref border 2)))
                              (if b
                                  (format port "<top style=\"~a\"><color rgb=\"~a\"/></top>" (car b) (cadr b))
                                  (display "<top/>" port)))
                            (let ((b (vector-ref border 3)))
                              (if b
                                  (format port "<bottom style=\"~a\"><color rgb=\"~a\"/></bottom>" (car b) (cadr b))
                                  (display "<bottom/>" port)))
                            (let ((b (vector-ref border 4)))
                              (if b
                                  (format port "<diagonal style=\"~a\"><color rgb=\"~a\"/></diagonal>" (car b) (cadr b))
                                  (display "<diagonal/>" port)))
                            (display "</border>" port))
                          borders)
                (display "</borders>" port)

                ;; Render cellStyleXfs (always one default)
                (display "<cellStyleXfs count=\"1\">" port)
                (display "<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>" port)
                (display "</cellStyleXfs>" port)

                ;; Render cellXfs (always at least one default)
                (format port "<cellXfs count=\"~a\">" (+ 1 (length styles)))
                ;; Default XF
                (display "<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"0\" applyFont=\"0\" applyFill=\"0\" applyBorder=\"0\" applyAlignment=\"0\" applyProtection=\"0\"/>" port)
                ;; Custom XFs
                (for-each (lambda (style)
                            (format port "<xf numFmtId=\"0\" fontId=\"~a\" fillId=\"~a\" borderId=\"~a\" applyAlignment=\"1\" applyNumberFormat=\"0\" applyFont=\"1\" applyFill=\"1\" applyBorder=\"1\" applyProtection=\"0\" xfId=\"0\">"
                                    (vector-ref style 0)
                                    (vector-ref style 1)
                                    (vector-ref style 2))
                            ;; Add alignment if rotation is set
                            (let ((alignment-id (vector-ref style 3)))
                              (unless (zero? alignment-id)
                                (let ((rotation (list-ref alignments alignment-id)))
                                  (unless (zero? rotation)
                                    (format port "<alignment textRotation=\"~a\"/>" rotation)))))
                            (display "</xf>" port))
                          styles)
                (display "</cellXfs>" port)

                ;; Render cellStyles (always one default)
                (display "<cellStyles count=\"1\">" port)
                (display "<cellStyle name=\"Standard\" xfId=\"0\" builtinId=\"0\"/>" port)
                (display "</cellStyles>" port)

                ;; Render dxfs (always empty)
                (display "<dxfs count=\"0\"/>" port)
                (display "</styleSheet>" port))))))))

    ;; Shared-strings: vector #(tag dict count next-id)
    (define (make-shared-strings)
      (vector 'shared-strings (make-dict) 0 0))

    (define (shared-strings-put! ss value)
      (let ((dict (vector-ref ss 1)))
        (vector-set! ss 2 (+ 1 (vector-ref ss 2)))
        (if (dict-contains dict value)
            (dict-get dict value)
            (let ((id (vector-ref ss 3)))
              (vector-set! ss 3 (+ id 1))
              (dict-put dict value id)
              id))))

    (define (shared-strings-get ss id)
      (dict-get (vector-ref ss 1) id))

    (define (shared-strings-render ss)
      (let ((dict (vector-ref ss 1))
            (count (vector-ref ss 2)))
        (call-with-output-string
         (lambda (port)
           (display xml-preamble port)
           (format port "<sst xmlns=\"~a\" count=\"~a\" uniqueCount=\"~a\">"
                   (ns 'spreadsheetml-main)
                   count
                   (dict-size dict))
           (do ((values (dict-keys dict) (cdr values)))
               ((null? values))
             (format port "<si><t>~a</t></si>" (xml-escape (car values))))
           (display "</sst>" port)))))

    (define (render-rels)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<Relationships xmlns=\"~a\">" (ns 'relationships))
         (format port "<Relationship Id=\"rId1\" Type=\"~a\" Target=\"~a\"/>"
                 (rel-type 'office-doc)
                 "xl/workbook.xml")
         (display "</Relationships>" port))))

    (define (render-content-types wb)
      (let ((sheets (workbook-worksheets wb)))
        (call-with-output-string
         (lambda (port)
           (display xml-preamble port)
           (format port "<Types xmlns=\"~a\">" (ns 'content-types))
           (format port "<Default Extension=\"rels\" ContentType=\"~a\"/>"
                   (content-type 'rel+xml))
           (format port "<Default Extension=\"xml\" ContentType=\"~a\"/>"
                   (content-type 'xml))
           (format port "<Override PartName=\"~a\" ContentType=\"~a\"/>"
                   "/xl/workbook.xml"
                   (content-type 'wb))
           (do ((i 1 (+ i 1)))
               ((> i (length sheets)))
             (format port "<Override PartName=\"~a\" ContentType=\"~a\"/>"
                     (format #f "/xl/worksheets/sheet~a.xml" i)
                     (content-type 'ws)))
           (when (> (workbook-styles-count wb) 0)
             (format port "<Override PartName=\"~a\" ContentType=\"~a\"/>"
                     "/xl/styles.xml"
                     (content-type 'styles)))
           (format port "<Override PartName=\"~a\" ContentType=\"~a\"/>"
                   "/xl/sharedStrings.xml"
                   (content-type 'shared-strings))
           (display "</Types>" port)))))

    (define (render-wb-rels wb)
      (let ((sheets (workbook-worksheets wb)))
        (call-with-output-string
         (lambda (port)
           (display xml-preamble port)
           (format port "<Relationships xmlns=\"~a\">" (ns 'relationships))
           (do ((i 1 (+ i 1)))
               ((> i (length sheets)))
             (format port "<Relationship Id=\"rId~a\" Type=\"~a\" Target=\"~a\"/>"
                     i
                     (rel-type 'worksheet)
                     (format #f "worksheets/sheet~a.xml" i)))
           (if (> (workbook-styles-count wb) 0)
               (format port "<Relationship Id=\"~a\" Type=\"~a\" Target=\"~a\"/>"
                       (format #f "rId~a" (+ 1 (length sheets)))
                       (rel-type 'styles)
                       "styles.xml"))
           (format port "<Relationship Id=\"~a\" Type=\"~a\" Target=\"~a\"/>"
                   (format #f "rId~a" (+ 2 (length sheets)))
                   (rel-type 'shared-strings)
                   "sharedStrings.xml")
           (display "</Relationships>" port)))))

    (define (render-workbook wb)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<workbook xmlns=\"~a\" xmlns:r=\"~a\">"
                 (ns 'spreadsheetml-main)
                 (ns 'doc-relationships))
         (display "<sheets>" port)
         (let loop ((sheets (workbook-worksheets wb)))
           (unless (null? sheets)
             (let* ((ws   (car sheets))
                    (name (worksheet-name ws))
                    (i    (worksheet-id ws)))
               (format port "<sheet name=\"~a\" sheetId=\"~a\" r:id=\"rId~a\"/>"
                       name i i))
             (loop (cdr sheets))))
         (display "</sheets>" port)
         (display "</workbook>" port))))

    (define (make-streaming-worksheet ss port)
      (let ((col-widths    (make-dict))
            (row-heights   (make-dict))
            (autofilter    #f)
            (current-row   #f)
            (current-cells (make-dict))
            (header-emitted #f))

        (define (emit-header!)
          (unless header-emitted
            (unless (= 0 (dict-size col-widths))
              (display "<cols>" port)
              (for-each (lambda (e)
                          (format port "<col min=\"~a\" max=\"~a\" width=\"~a\" customWidth=\"1\"/>"
                                  (col-string->index (car e))
                                  (col-string->index (car e))
                                  (cdr e)))
                        (sorted-col-entries col-widths))
              (display "</cols>" port))
            (display "<sheetData>" port)
            (set! header-emitted #t)))

        (define (flush-row!)
          (when current-row
            (let ((rh (and (dict-contains row-heights current-row)
                           (dict-get row-heights current-row))))
              (if rh
                  (format port "<row r=\"~a\" ht=\"~a\" customHeight=\"1\">" current-row rh)
                  (format port "<row r=\"~a\">" current-row))
              (for-each (lambda (cell) (render-cell port cell))
                        ;; do not sort - for performance reasons
                        ;; use non-streaming version for random access
                        (dict-values current-cells))
              (display "</row>" port))
            (set! current-row #f)
            (set! current-cells (make-dict))))

        (lambda (action . args)
          (case action
            ((set-cell!)
             (let* ((id    (car args))
                    (value (cadr args))
                    (type  (caddr args))
                    (style (cadddr args))
                    (row   (cdr (cell-id-split id))))
               (emit-header!)
               (unless (equal? row current-row)
                 (flush-row!)
                 (set! current-row row))
               (if (eq? type 'string)
                   (dict-put current-cells id
                             (make-string-cell id (shared-strings-put! ss value) style))
                   (dict-put current-cells id
                             (make-num-cell id value style)))))
            ((set-col-width!)
             (dict-put col-widths (car args) (cadr args)))
            ((set-row-height!)
             (dict-put row-heights (number->string (car args)) (cadr args)))
            ((set-autofilter!)
             (set! autofilter (car args)))
            ((finish!)
             (emit-header!)
             (flush-row!)
             (display "</sheetData>" port)
             (when autofilter
               (format port "<autoFilter ref=\"~a\"/>" autofilter))
             (display "</worksheet>" port))))))

    ;; Streaming-table: vector #(tag ss port col-letters row-num
    ;;                           col-widths row-heights autofilter header-emitted)
    ;; Indices:                   0    1  2    3          4
    ;;                                 5          6         7          8
    (define (make-streaming-table ss port num-cols)
      "Syntax: (make-streaming-table ss port num-cols)
Library: (scm ooxml excel)
Description: Creates a table-streaming worksheet optimized for writing
fixed-width rows at high speed. num-cols is the base number of columns;
rows may contain additional columns beyond this (up to 12 extra). Returns
a streaming-table vector for use with streaming-table-write-row! etc."
      (let* ((max-cols    (+ num-cols 12))
             (col-letters (make-vector max-cols "")))
        (do ((i 0 (+ i 1)))
            ((= i max-cols))
          (vector-set! col-letters i (col-index->string (+ i 1))))
        (vector 'streaming-table ss port col-letters 0
                (make-dict) (make-dict) #f #f)))

    (define (st-emit-header! st)
      (unless (vector-ref st 8)
        (let ((port (vector-ref st 2))
              (col-widths (vector-ref st 5)))
          (unless (= 0 (dict-size col-widths))
            (display "<cols>" port)
            (for-each (lambda (e)
                        (format port "<col min=\"~a\" max=\"~a\" width=\"~a\" customWidth=\"1\"/>"
                                (col-string->index (car e))
                                (col-string->index (car e))
                                (cdr e)))
                      (sorted-col-entries col-widths))
            (display "</cols>" port))
          (display "<sheetData>" port)
          (vector-set! st 8 #t))))

    (define (st-write-cell-inline! st row-str col-idx value style)
      (let ((port (vector-ref st 2))
            (cell-ref (string-append (vector-ref (vector-ref st 3) col-idx)
                                     row-str)))
        (if (number? value)
            (begin
              (display "<c r=\"" port)
              (display cell-ref port)
              (display "\"" port)
              (when style
                (display " s=\"" port)
                (display style port)
                (display "\"" port))
              (display "><v>" port)
              (display value port)
              (display "</v></c>" port))
            (let ((ss-id (shared-strings-put! (vector-ref st 1)
                           (if (string? value)
                               value
                               (format #f "~a" value)))))
              (display "<c r=\"" port)
              (display cell-ref port)
              (display "\"" port)
              (when style
                (display " s=\"" port)
                (display style port)
                (display "\"" port))
              (display " t=\"s\"><v>" port)
              (display ss-id port)
              (display "</v></c>" port)))))

    (define (streaming-table-write-row! st values)
      "Syntax: (streaming-table-write-row! st values)
Library: (scm ooxml excel)
Description: Writes a row to a streaming table. values is a list of cell
values."
      (st-emit-header! st)
      (let ((row-num (+ 1 (vector-ref st 4))))
        (vector-set! st 4 row-num)
        (let ((row-str (number->string row-num))
              (port (vector-ref st 2)))
          (let ((rh (dict-get (vector-ref st 6) row-str #f)))
            (if rh
                (format port "<row r=\"~a\" ht=\"~a\" customHeight=\"1\">" row-str rh)
                (begin (display "<row r=\"" port)
                       (display row-str port)
                       (display "\">" port))))
          (let loop ((vals values) (col 0))
            (unless (null? vals)
              (st-write-cell-inline! st row-str col (car vals) #f)
              (loop (cdr vals) (+ col 1))))
          (display "</row>" port))))

    (define (streaming-table-write-styled-row! st values styles)
      "Syntax: (streaming-table-write-styled-row! st values styles)
Library: (scm ooxml excel)
Description: Writes a row with per-cell styles. values and styles are
parallel lists; each style element is #f or a style index."
      (st-emit-header! st)
      (let ((row-num (+ 1 (vector-ref st 4))))
        (vector-set! st 4 row-num)
        (let ((row-str (number->string row-num))
              (port (vector-ref st 2)))
          (let ((rh (dict-get (vector-ref st 6) row-str #f)))
            (if rh
                (format port "<row r=\"~a\" ht=\"~a\" customHeight=\"1\">" row-str rh)
                (begin (display "<row r=\"" port)
                       (display row-str port)
                       (display "\">" port))))
          (let loop ((vals values) (stys styles) (col 0))
            (unless (null? vals)
              (st-write-cell-inline! st row-str col (car vals)
                                     (if (null? stys) #f (car stys)))
              (loop (cdr vals)
                    (if (null? stys) '() (cdr stys))
                    (+ col 1))))
          (display "</row>" port))))

    (define (streaming-table-finish! st)
      "Syntax: (streaming-table-finish! st)
Library: (scm ooxml excel)
Description: Finalizes a streaming table worksheet."
      (st-emit-header! st)
      (let ((port (vector-ref st 2)))
        (display "</sheetData>" port)
        (when (vector-ref st 7)
          (format port "<autoFilter ref=\"~a\"/>" (vector-ref st 7)))
        (display "</worksheet>" port)))

    (define (streaming-table-row-num st)
      "Syntax: (streaming-table-row-num st)
Library: (scm ooxml excel)
Description: Returns the number of rows written so far to a streaming table."
      (vector-ref st 4))

    (define (streaming-table-set-col-width! st col width)
      "Syntax: (streaming-table-set-col-width! st col width)
Library: (scm ooxml excel)
Description: Sets the width of a column in a streaming table."
      (dict-put (vector-ref st 5) col width))

    (define (streaming-table-set-row-height! st row height)
      "Syntax: (streaming-table-set-row-height! st row height)
Library: (scm ooxml excel)
Description: Sets the height of a row in a streaming table."
      (dict-put (vector-ref st 6) (number->string row) height))

    (define (streaming-table-set-autofilter! st ref)
      "Syntax: (streaming-table-set-autofilter! st ref)
Library: (scm ooxml excel)
Description: Sets the autofilter range for a streaming table."
      (vector-set! st 7 ref))

    (define (call-with-streaming-table filename name num-cols proc)
      "Syntax: (call-with-streaming-table filename name num-cols proc)
Library: (scm ooxml excel)
Description: Creates a single-sheet streaming table workbook, calls
(proc wb-proxy st) where wb-proxy supports workbook-add-style and st is a
streaming table, then finalizes and saves the XLSX file. Returns 'ok.
Example:
  (call-with-streaming-table \"/tmp/big.xlsx\" \"Data\" 3
    (lambda (wb st)
      (streaming-table-write-row! st '(\"Name\" \"Age\" \"City\"))
      (streaming-table-write-row! st '(\"Alice\" 30 \"Bern\"))))"
      (let* ((ss      (make-shared-strings))
             (styles  (make-styles))
             (wb-proxy (lambda (action . args)
                         (case action
                           ((styles) styles)))))
        (call-with-output-zip filename
          (lambda (zp)
            (define (add-zip-entry zname contents)
              (call-with-output-zip-entry zp zname
                (lambda (port) (display contents port))
                0))
            (call-with-output-zip-entry zp "xl/worksheets/sheet1.xml"
              (lambda (sheet-port)
                (display xml-preamble sheet-port)
                (format sheet-port "<worksheet xmlns=\"~a\">" (ns 'spreadsheetml-main))
                (let ((st (make-streaming-table ss sheet-port num-cols)))
                  (proc wb-proxy st)
                  (streaming-table-finish! st)))
              0)
            (let* ((fake-ws (vector 'ws name 1 #f #f #f #f #f))
                   (fake-wb (vector 'wb ss styles (list fake-ws))))
              (add-zip-entry "_rels/.rels"                (render-rels))
              (add-zip-entry "[Content_Types].xml"        (render-content-types fake-wb))
              (add-zip-entry "xl/_rels/workbook.xml.rels" (render-wb-rels fake-wb))
              (add-zip-entry "xl/workbook.xml"            (render-workbook fake-wb))
              (add-zip-entry "xl/sharedStrings.xml"       (shared-strings-render ss))
              (when (> (styles 'styles-count) 0)
                (add-zip-entry "xl/styles.xml"            (styles 'render))))))
        'ok))

    (define (open-streaming-table filename sheet-name num-cols)
      "Syntax: (open-streaming-table filename sheet-name num-cols)
Library: (scm ooxml excel)
Description: Opens a new single-sheet streaming table workbook. num-cols is
the number of columns per row. Returns a pair (st . close-proc) where st is
a streaming table and close-proc must be called exactly once to finalize.
Example:
  (let* ((handle (open-streaming-table \"/tmp/out.xlsx\" \"Sheet1\" 3))
         (st     (car handle))
         (done!  (cdr handle)))
    (streaming-table-write-row! st '(\"hello\" \"world\" 42))
    (done!))"
      (let* ((ss         (make-shared-strings))
             (styles     (make-styles))
             (zp         (open-output-zip-file filename))
             (sheet-port (zip-add-text-entry zp "xl/worksheets/sheet1.xml" 0)))
        (display xml-preamble sheet-port)
        (format sheet-port "<worksheet xmlns=\"~a\">" (ns 'spreadsheetml-main))
        (let ((st (make-streaming-table ss sheet-port num-cols)))
          (cons st
                (lambda ()
                  (streaming-table-finish! st)
                  (flush-output-port sheet-port)
                  (let* ((fake-ws (vector 'ws sheet-name 1 #f #f #f #f #f))
                         (fake-wb (vector 'wb ss styles (list fake-ws))))
                    (for-each (lambda (pair)
                                (let ((p (zip-add-text-entry zp (car pair) 0)))
                                  (display (cdr pair) p)
                                  (flush-output-port p)))
                              (list (cons "_rels/.rels"                (render-rels))
                                    (cons "[Content_Types].xml"        (render-content-types fake-wb))
                                    (cons "xl/_rels/workbook.xml.rels" (render-wb-rels fake-wb))
                                    (cons "xl/workbook.xml"            (render-workbook fake-wb))
                                    (cons "xl/sharedStrings.xml"       (shared-strings-render ss))))
                    (when (> (styles 'styles-count) 0)
                      (let ((p (zip-add-text-entry zp "xl/styles.xml" 0)))
                        (display (styles 'render) p)
                        (flush-output-port p))))
                  (close-output-zip zp))))))

    (define (call-with-worksheet filename name proc)
      "Syntax: (call-with-worksheet filename name proc)
Library: (scm ooxml excel)
Description: Creates a workbook with a single worksheet named name, calls
(proc wb ws) where wb is the workbook and ws is the worksheet, then saves
the workbook to filename.
Example:
  (call-with-worksheet \"/tmp/out.xlsx\" \"Data\"
    (lambda (wb ws)
      (worksheet-set-cell! ws \"A1\" \"hello\" 'string #f)))"
      (let* ((wb (make-workbook))
             (ws (workbook-add-worksheet! wb name)))
        (proc wb ws)
        (workbook-save wb filename)))

    (define (call-with-streaming-workbook filename name proc)
      "Syntax: (call-with-streaming-workbook filename name proc)
Library: (scm ooxml excel)
Description: Creates a single-sheet streaming workbook, calls (proc wb-proxy sws)
where wb-proxy supports workbook-add-style and sws is a streaming worksheet,
then finalizes and saves the XLSX file to filename. Cells must be written in
row-ascending order. Returns 'ok.
Example:
  (call-with-streaming-workbook \"/tmp/big.xlsx\" \"Data\"
    (lambda (wb sws)
      (let ((hdr (workbook-add-style wb fill: fgcolor: 'lightblue)))
        (worksheet-set-cell! sws \"A1\" \"Name\" 'string hdr)
        (worksheet-set-cell! sws \"A2\" \"Alice\" 'string #f))))"
      (let* ((ss      (make-shared-strings))
             (styles  (make-styles))
             (wb-proxy (lambda (action . args)
                         (case action
                           ((styles) styles)))))
        (call-with-output-zip filename
          (lambda (zp)
            (define (add-zip-entry zname contents)
              (call-with-output-zip-entry zp zname
                (lambda (port) (display contents port))
                0))
            (call-with-output-zip-entry zp "xl/worksheets/sheet1.xml"
              (lambda (sheet-port)
                (display xml-preamble sheet-port)
                (format sheet-port "<worksheet xmlns=\"~a\">" (ns 'spreadsheetml-main))
                (let ((sws (make-streaming-worksheet ss sheet-port)))
                  (proc wb-proxy sws)
                  (sws 'finish!)))
              0)
            (let* ((fake-ws (vector 'ws name 1 #f #f #f #f #f))
                   (fake-wb (vector 'wb ss styles (list fake-ws))))
              (add-zip-entry "_rels/.rels"                (render-rels))
              (add-zip-entry "[Content_Types].xml"        (render-content-types fake-wb))
              (add-zip-entry "xl/_rels/workbook.xml.rels" (render-wb-rels fake-wb))
              (add-zip-entry "xl/workbook.xml"            (render-workbook fake-wb))
              (add-zip-entry "xl/sharedStrings.xml"       (shared-strings-render ss))
              (when (> (styles 'styles-count) 0)
                (add-zip-entry "xl/styles.xml"            (styles 'render))))))
        'ok))

    (define (open-streaming-workbook filename sheet-name)
      "Syntax: (open-streaming-workbook filename sheet-name)
Library: (scm ooxml excel)
Description: Opens a new single-sheet streaming workbook writing to filename.
Returns a pair (sws . close-proc) where sws is a streaming worksheet and
close-proc is a zero-argument procedure that finalizes and closes the XLSX file.
close-proc must be called exactly once when all data has been written. Cells
must be written in row-ascending order.
Example:
  (let* ((handle (open-streaming-workbook \"/tmp/out.xlsx\" \"Sheet1\"))
         (sws    (car handle))
         (done!  (cdr handle)))
    (worksheet-set-cell! sws \"A1\" \"hello\" 'string #f)
    (done!))"
      (let* ((ss         (make-shared-strings))
             (styles     (make-styles))
             (zp         (open-output-zip-file filename))
             (sheet-port (zip-add-text-entry zp "xl/worksheets/sheet1.xml" 0)))
        (display xml-preamble sheet-port)
        (format sheet-port "<worksheet xmlns=\"~a\">" (ns 'spreadsheetml-main))
        (let ((sws (make-streaming-worksheet ss sheet-port)))
          (cons sws
                (lambda ()
                  (sws 'finish!)
                  (flush-output-port sheet-port)
                  (let* ((fake-ws (vector 'ws sheet-name 1 #f #f #f #f #f))
                         (fake-wb (vector 'wb ss styles (list fake-ws))))
                    (for-each (lambda (pair)
                                (let ((p (zip-add-text-entry zp (car pair) 0)))
                                  (display (cdr pair) p)
                                  (flush-output-port p)))
                              (list (cons "_rels/.rels"                (render-rels))
                                    (cons "[Content_Types].xml"        (render-content-types fake-wb))
                                    (cons "xl/_rels/workbook.xml.rels" (render-wb-rels fake-wb))
                                    (cons "xl/workbook.xml"            (render-workbook fake-wb))
                                    (cons "xl/sharedStrings.xml"       (shared-strings-render ss))))
                    (when (> (styles 'styles-count) 0)
                      (let ((p (zip-add-text-entry zp "xl/styles.xml" 0)))
                        (display (styles 'render) p)
                        (flush-output-port p))))
                  (close-output-zip zp))))))

    (define (translate-style-section-args args)
      (let loop ((args args) (result '()))
        (if (null? args)
            (reverse result)
            (let ((arg (car args)))
              (cond
                ;; flags (no value)
                ((eq? arg 'bold)     (loop (cdr args)  (cons #t (cons 'bold result))))
                ((eq? arg 'italic)   (loop (cdr args)  (cons #t (cons 'italic result))))
                ;; key-value pairs
                ((eq? arg 'name:)    (loop (cddr args) (cons (cadr args) (cons 'name result))))
                ((eq? arg 'family:)  (loop (cddr args) (cons (cadr args) (cons 'family result))))
                ((eq? arg 'size:)    (loop (cddr args) (cons (cadr args) (cons 'sz result))))
                ((eq? arg 'color:)   (loop (cddr args) (cons (cadr args) (cons 'color result))))
                ((eq? arg 'type:)    (loop (cddr args) (cons (cadr args) (cons 'type result))))
                ((eq? arg 'fgcolor:) (loop (cddr args) (cons (cadr args) (cons 'fgcolor result))))
                ((eq? arg 'bgcolor:) (loop (cddr args) (cons (cadr args) (cons 'bgcolor result))))
                ((eq? arg 'left:)    (loop (cddr args) (cons (cadr args) (cons 'left result))))
                ((eq? arg 'right:)   (loop (cddr args) (cons (cadr args) (cons 'right result))))
                ((eq? arg 'top:)     (loop (cddr args) (cons (cadr args) (cons 'top result))))
                ((eq? arg 'bottom:)  (loop (cddr args) (cons (cadr args) (cons 'bottom result))))
                ((eq? arg 'diagonal:)(loop (cddr args) (cons (cadr args) (cons 'diagonal result))))
                ((eq? arg 'rotation:)(loop (cddr args) (cons (cadr args) (cons 'rotation result))))
                (else (loop (cdr args) result)))))))

    (define (workbook-add-style-impl wb sections)
      (let ((s (make-style)))
        (for-each
          (lambda (section)
            (let ((name (car section))
                  (args (translate-style-section-args (cdr section))))
              (unless (null? args)
                (case name
                  ((font)      (apply s 'set-font args))
                  ((fill)      (apply s 'set-fill args))
                  ((border)    (apply s 'set-border args))
                  ((alignment) (apply s 'set-alignment args))))))
          sections)
        ((workbook-styles wb) 'add-style s)))

    (define-syntax workbook-add-style
      "Syntax: (workbook-add-style wb [(font opts...)] [(fill opts...)] [(border opts...)] [(alignment opts...)])
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
(workbook-add-style wb (fill fgcolor: lightblue) (font color: red bold))"
      (syntax-rules ()
        ((_ wb (section-name section-args ...) ...)
         (workbook-add-style-impl wb
           (list (list 'section-name 'section-args ...) ...)))
        ((_ wb flat-args ...)
         (workbook-add-style-impl wb '()))))
))

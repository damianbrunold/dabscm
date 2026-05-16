(define-library (scm odf spreadsheet)
  (export make-workbook
          workbook-add-worksheet!
          workbook-styles
          worksheet-set-cell!
          worksheet-set-col-width!
          worksheet-set-row-height!
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
          streaming-table-write-row!
          streaming-table-write-styled-row!
          streaming-table-finish!
          streaming-table-row-num
          streaming-table-set-col-width!
          streaming-table-set-row-height!
          streaming-table-get-col-styles
          streaming-table-get-row-styles
          streaming-table-set-pre-write-thunk!
          call-with-streaming-table
          open-streaming-table)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme write)
          (scm compile)
          (scm dict)
          (scm io)
          (srfi 1)
          (srfi 132)
          (scm list)
          (scm macro)
          (scm zip))

  (begin
    (define xml-preamble "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")

    ;; ODF namespace URIs
    (define ns-office   "urn:oasis:names:tc:opendocument:xmlns:office:1.0")
    (define ns-style    "urn:oasis:names:tc:opendocument:xmlns:style:1.0")
    (define ns-text     "urn:oasis:names:tc:opendocument:xmlns:text:1.0")
    (define ns-table    "urn:oasis:names:tc:opendocument:xmlns:table:1.0")
    (define ns-fo       "urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0")
    (define ns-number   "urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0")
    (define ns-svg      "urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0")
    (define ns-meta     "urn:oasis:names:tc:opendocument:xmlns:meta:1.0")
    (define ns-dc       "http://purl.org/dc/elements/1.1/")
    (define ns-manifest "urn:oasis:names:tc:opendocument:xmlns:manifest:1.0")

    (define mimetype-ods "application/vnd.oasis.opendocument.spreadsheet")

    ;; ---------------------------------------------------------------
    ;; Color table (shared ARGB 8-char format with scm ooxml excel)
    ;; ---------------------------------------------------------------
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
Library: (scm odf spreadsheet)
Description: Registers a new named color in the color table used by resolve-color.
name is a symbol; hex-string is an 8-character ARGB hex string (e.g. \"FFFF0000\").
Example:
  (register-color! 'salmon \"FFFA8072\")"
      (dict-put *color-table* name hex-string))

    (define (resolve-color color)
      "Syntax: (resolve-color color)
Library: (scm odf spreadsheet)
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

    (define (argb->odf-color argb)
      ;; Converts 8-char ARGB hex string to ODF "#RRGGBB" format.
      (string-append "#" (substring argb 2 8)))

    ;; ---------------------------------------------------------------
    ;; XML escaping
    ;; ---------------------------------------------------------------
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

    ;; ---------------------------------------------------------------
    ;; Cell ID parsing and column utilities
    ;; ---------------------------------------------------------------
    (define (cell-id-split id)
      ;; Returns (col-letters . row-digits) e.g. "AA12" -> ("AA" . "12")
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
Library: (scm odf spreadsheet)
Description: Converts a 1-based column index to its column letter string.
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
Library: (scm odf spreadsheet)
Description: Returns the cell ID string for the given 1-based row and column
indices.
Example:
  (row-col->cell-id 1 1)  => \"A1\"
  (row-col->cell-id 3 28) => \"AB3\""
      (string-append (col-index->string col) (number->string row)))

    ;; ---------------------------------------------------------------
    ;; Unit conversion
    ;; ---------------------------------------------------------------
    (define (pts->cm pts)
      ;; Converts points to centimeters (1pt = 1/72 inch, 1 inch = 2.54cm).
      (let* ((inches (/ pts 72))
             (cm (* inches 2.54)))
        ;; Round to 3 decimal places for clean XML output
        (/ (round (* cm 1000)) 1000)))

    (define (format-cm val)
      ;; Formats a cm value as string with "cm" suffix.
      (string-append (number->string (inexact val)) "cm"))

    ;; ---------------------------------------------------------------
    ;; Cell data structure
    ;; Cells store: (vector 'cell col-index value type style-name)
    ;; col-index is 1-based integer
    ;; ---------------------------------------------------------------
    (define (make-cell col-index value type style-name)
      (vector 'cell col-index value type style-name))

    (define (cell-col-index c) (vector-ref c 1))
    (define (cell-value c)     (vector-ref c 2))
    (define (cell-type c)      (vector-ref c 3))
    (define (cell-style c)     (vector-ref c 4))

    ;; ---------------------------------------------------------------
    ;; Style system
    ;; ---------------------------------------------------------------
    (define (make-font)
      (let ((name "Arial")
            (family #f)
            (sz "10")
            (color "FF000000")
            (bold #f)
            (italic #f))
        (lambda (action . args)
          (case action
            ((set-name)   (set! name (car args)))
            ((set-family) (set! family (car args)))
            ((set-sz)     (set! sz (car args)))
            ((set-color)  (set! color (car args)))
            ((set-bold)   (set! bold (car args)))
            ((set-italic) (set! italic (car args)))
            ((get) (vector name family sz color bold italic))))))

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
Library: (scm odf spreadsheet)
Description: Creates and returns a new mutable style object with default font
(Arial 10pt black), no fill, no border, and no alignment. The style object
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

    ;; ---------------------------------------------------------------
    ;; Styles collection — manages named ODF automatic styles
    ;; ---------------------------------------------------------------
    (define (make-styles)
      (let ((styles '())   ;; list of (name . style-obj) pairs
            (next-id 1))
        (lambda (action . args)
          (case action
            ((add-style)
             (let* ((style (car args))
                    (name (string-append "ce" (number->string next-id))))
               (set! next-id (+ next-id 1))
               (set! styles (append styles (list (cons name style))))
               name))
            ((styles-count) (length styles))
            ((styles-list)  styles)))))

    ;; ---------------------------------------------------------------
    ;; Render ODF style XML for a single cell style
    ;; ---------------------------------------------------------------
    (define (render-cell-style port name style)
      (let ((font      (style 'get-font))
            (fill      (style 'get-fill))
            (border-v  (style 'get-border))
            (rotation  (style 'get-alignment)))
        (format port "<style:style style:name=\"~a\" style:family=\"table-cell\">"
                name)
        ;; text-properties (font)
        (let ((font-name   (vector-ref font 0))
              (font-family (vector-ref font 1))
              (font-sz     (vector-ref font 2))
              (font-color  (vector-ref font 3))
              (font-bold   (vector-ref font 4))
              (font-italic (vector-ref font 5)))
          (let ((attrs '()))
            (when font-name
              (set! attrs (cons (format #f " style:font-name=\"~a\"" font-name) attrs)))
            (when font-sz
              (set! attrs (cons (format #f " fo:font-size=\"~apt\"" font-sz) attrs)))
            (when font-color
              (set! attrs (cons (format #f " fo:color=\"~a\"" (argb->odf-color font-color)) attrs)))
            (when font-bold
              (set! attrs (cons " fo:font-weight=\"bold\"" attrs)))
            (when font-italic
              (set! attrs (cons " fo:font-style=\"italic\"" attrs)))
            (unless (null? attrs)
              (display "<style:text-properties" port)
              (for-each (lambda (a) (display a port)) (reverse attrs))
              (display "/>" port))))
        ;; table-cell-properties (fill, border, rotation)
        (let ((fill-type    (vector-ref fill 0))
              (fill-fgcolor (vector-ref fill 1))
              (border-left     (vector-ref border-v 0))
              (border-right    (vector-ref border-v 1))
              (border-top      (vector-ref border-v 2))
              (border-bottom   (vector-ref border-v 3))
              (border-diagonal (vector-ref border-v 4)))
          (let ((attrs '()))
            (when (and (string? fill-type)
                       (string=? fill-type "solid")
                       fill-fgcolor)
              (set! attrs (cons (format #f " fo:background-color=\"~a\""
                                        (argb->odf-color fill-fgcolor))
                                attrs)))
            ;; Borders — ODF format: "width style color"
            (when border-left
              (set! attrs (cons (format #f " fo:border-left=\"0.06pt solid ~a\""
                                        (argb->odf-color (cadr border-left)))
                                attrs)))
            (when border-right
              (set! attrs (cons (format #f " fo:border-right=\"0.06pt solid ~a\""
                                        (argb->odf-color (cadr border-right)))
                                attrs)))
            (when border-top
              (set! attrs (cons (format #f " fo:border-top=\"0.06pt solid ~a\""
                                        (argb->odf-color (cadr border-top)))
                                attrs)))
            (when border-bottom
              (set! attrs (cons (format #f " fo:border-bottom=\"0.06pt solid ~a\""
                                        (argb->odf-color (cadr border-bottom)))
                                attrs)))
            (when border-diagonal
              (set! attrs (cons (format #f " fo:border=\"0.06pt solid ~a\""
                                        (argb->odf-color (cadr border-diagonal)))
                                attrs)))
            (when (and (number? rotation) (not (zero? rotation)))
              (set! attrs (cons (format #f " style:rotation-angle=\"~a\"" rotation)
                                attrs)))
            (unless (null? attrs)
              (display "<style:table-cell-properties" port)
              (for-each (lambda (a) (display a port)) (reverse attrs))
              (display "/>" port))))
        (display "</style:style>" port)))

    ;; ---------------------------------------------------------------
    ;; Worksheet data structure
    ;; (vector 'ws name id rows col-widths row-heights)
    ;; rows: dict of row-num(int) -> dict of col-index(int) -> cell
    ;; col-widths: dict of col-letter(string) -> width(number in points)
    ;; row-heights: dict of row-num(int) -> height(number in points)
    ;; ---------------------------------------------------------------
    (define (make-worksheet name id)
      (vector 'ws name id (make-dict) (make-dict) (make-dict)))

    (define (worksheet-name ws)        (vector-ref ws 1))
    (define (worksheet-id ws)          (vector-ref ws 2))
    (define (worksheet-rows ws)        (vector-ref ws 3))
    (define (worksheet-col-widths ws)  (vector-ref ws 4))
    (define (worksheet-row-heights ws) (vector-ref ws 5))

    ;; ---------------------------------------------------------------
    ;; Workbook data structure
    ;; (vector 'wb styles worksheets)
    ;; ---------------------------------------------------------------
    (define (make-workbook)
      "Syntax: (make-workbook)
Library: (scm odf spreadsheet)
Description: Creates and returns a new empty workbook object.
Example:
  (let ((wb (make-workbook)))
    (workbook-add-worksheet! wb \"Sheet1\")
    (workbook-save wb \"out.ods\"))"
      (vector 'wb
              (make-styles)
              '())) ;; worksheets

    (define (workbook-styles wb)
      "Syntax: (workbook-styles wb)
Library: (scm odf spreadsheet)
Description: Returns the styles object for wb. Works for both regular workbooks
and streaming workbook proxies. The styles object is used internally by
workbook-add-style.
Example:
  ((workbook-styles wb) 'styles-count) => 0"
      (if (procedure? wb)
          (wb 'styles)
          (vector-ref wb 1)))
    (define (workbook-styles-count wb) ((workbook-styles wb) 'styles-count))
    (define (workbook-worksheets wb) (vector-ref wb 2))
    (define (workbook-worksheets! wb sheets) (vector-set! wb 2 sheets))

    (define (workbook-add-worksheet! wb name)
      "Syntax: (workbook-add-worksheet! wb name)
Library: (scm odf spreadsheet)
Description: Adds a new worksheet named name to wb and returns the new worksheet
object. Worksheets are saved in the order they are added.
Example:
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb \"Sheet1\")))
    (worksheet-set-cell! ws \"A1\" 42 'num #f))"
      (let ((sheets (workbook-worksheets wb)))
        (let ((new-sheet (make-worksheet name (+ (length sheets) 1))))
          (workbook-worksheets! wb (append sheets (list new-sheet)))
          new-sheet)))

    (define (worksheet-set-col-width! ws col width)
      "Syntax: (worksheet-set-col-width! ws col width)
Library: (scm odf spreadsheet)
Description: Sets the width of the column identified by the letter string col
in worksheet ws. width is specified in points. Works for both regular and
streaming worksheets.
Example:
  (worksheet-set-col-width! ws \"A\" 20)
  (worksheet-set-col-width! ws \"B\" 12.5)"
      (if (procedure? ws)
          (ws 'set-col-width! col width)
          (dict-put (worksheet-col-widths ws) col width)))

    (define (worksheet-set-row-height! ws row height)
      "Syntax: (worksheet-set-row-height! ws row height)
Library: (scm odf spreadsheet)
Description: Sets the height (in points) of the 1-based row index in worksheet
ws. Works for both regular and streaming worksheets.
Example:
  (worksheet-set-row-height! ws 1 30)"
      (if (procedure? ws)
          (ws 'set-row-height! row height)
          (dict-put (worksheet-row-heights ws) (number->string row) height)))

    (define (worksheet-set-cell! ws id value type style)
      "Syntax: (worksheet-set-cell! ws id value type style)
Library: (scm odf spreadsheet)
Description: Sets the cell at id (an A1-notation string such as \"B3\") in
worksheet ws. type is 'string, 'num, or 'boolean. style is either #f for no
style or a style name string returned by workbook-add-style. Works for both
regular and streaming worksheets. For streaming worksheets, cells must be
written in row-ascending order.
Example:
  (worksheet-set-cell! ws \"A1\" \"hello\" 'string #f)
  (worksheet-set-cell! ws \"B2\" 42 'num #f)
  (worksheet-set-cell! ws \"C3\" #t 'boolean #f)
  (worksheet-set-cell! ws \"D4\" \"hi\" 'string my-style)"
      (if (procedure? ws)
          (ws 'set-cell! id value type style)
          (let* ((parts (cell-id-split id))
                 (col-letters (car parts))
                 (row-str (cdr parts))
                 (col-idx (col-string->index col-letters))
                 (col-key (number->string col-idx))
                 (rows (worksheet-rows ws)))
            (unless (dict-contains rows row-str)
              (dict-put rows row-str (make-dict)))
            (let ((row-data (dict-get rows row-str)))
              (dict-put row-data col-key
                        (make-cell col-idx value type style))))))

    ;; ---------------------------------------------------------------
    ;; Rendering helpers
    ;; ---------------------------------------------------------------

    ;; Sort dict entries by numeric key (keys are strings of numbers)
    (define (sorted-dict-entries d)
      (let ((entries (dict-entries d)))
        (list-sort (lambda (a b) (< (string->number (car a)) (string->number (car b)))) entries)))

    ;; Sort dict entries by column string->index key
    (define (sorted-col-entries d)
      (let ((entries (dict-entries d)))
        (list-sort (lambda (a b)
                     (< (col-string->index (car a))
                        (col-string->index (car b))))
                   entries)))

    (define (render-odf-cell port cell)
      ;; Renders a single table:table-cell element.
      (let ((style-attr (if (cell-style cell)
                            (format #f " table:style-name=\"~a\"" (cell-style cell))
                            ""))
            (type (cell-type cell))
            (value (cell-value cell)))
        (cond
         ((eq? type 'string)
          (format port "<table:table-cell~a office:value-type=\"string\">" style-attr)
          (format port "<text:p>~a</text:p>" (xml-escape (if (string? value) value (format #f "~a" value))))
          (display "</table:table-cell>" port))
         ((eq? type 'num)
          (format port "<table:table-cell~a office:value-type=\"float\" office:value=\"~a\">"
                  style-attr value)
          (format port "<text:p>~a</text:p>" value)
          (display "</table:table-cell>" port))
         ((eq? type 'boolean)
          (let ((bool-str (if value "true" "false"))
                (display-str (if value "TRUE" "FALSE")))
            (format port "<table:table-cell~a office:value-type=\"boolean\" office:boolean-value=\"~a\">"
                    style-attr bool-str)
            (format port "<text:p>~a</text:p>" display-str)
            (display "</table:table-cell>" port)))
         (else
          ;; Fallback: treat as string
          (format port "<table:table-cell~a office:value-type=\"string\">" style-attr)
          (format port "<text:p>~a</text:p>" (xml-escape (format #f "~a" value)))
          (display "</table:table-cell>" port)))))

    (define (render-empty-cells port count)
      ;; Renders empty cells, using number-columns-repeated for efficiency.
      (when (> count 0)
        (if (= count 1)
            (display "<table:table-cell/>" port)
            (format port "<table:table-cell table:number-columns-repeated=\"~a\"/>" count))))

    ;; ---------------------------------------------------------------
    ;; Column/row style rendering for automatic-styles
    ;; ---------------------------------------------------------------
    (define (collect-col-styles worksheets)
      ;; Returns a list of (style-name . width-cm-string) for all unique column widths.
      ;; Also returns an alist mapping (sheet-id . col-letter) -> style-name.
      (let ((style-list '())
            (col-map '())
            (next-id 1))
        (for-each
         (lambda (ws)
           (for-each
            (lambda (entry)
              (let* ((col (car entry))
                     (width (cdr entry))
                     (cm-str (format-cm (pts->cm width)))
                     ;; Check if we already have a style for this width
                     (existing (let loop ((sl style-list))
                                 (if (null? sl) #f
                                     (if (string=? (cdar sl) cm-str)
                                         (caar sl)
                                         (loop (cdr sl)))))))
                (if existing
                    (set! col-map (cons (cons (cons (worksheet-id ws) col) existing)
                                        col-map))
                    (let ((name (string-append "co" (number->string next-id))))
                      (set! next-id (+ next-id 1))
                      (set! style-list (append style-list (list (cons name cm-str))))
                      (set! col-map (cons (cons (cons (worksheet-id ws) col) name)
                                          col-map))))))
            (sorted-col-entries (worksheet-col-widths ws))))
         worksheets)
        (cons style-list col-map)))

    (define (collect-row-styles worksheets)
      ;; Returns a list of (style-name . height-cm-string) and
      ;; an alist of (sheet-id . row-num) -> style-name.
      (let ((style-list '())
            (row-map '())
            (next-id 1))
        (for-each
         (lambda (ws)
           (for-each
            (lambda (entry)
              (let* ((row-num (car entry))
                     (height (cdr entry))
                     (cm-str (format-cm (pts->cm height)))
                     (existing (let loop ((sl style-list))
                                 (if (null? sl) #f
                                     (if (string=? (cdar sl) cm-str)
                                         (caar sl)
                                         (loop (cdr sl)))))))
                (if existing
                    (set! row-map (cons (cons (cons (worksheet-id ws) row-num) existing)
                                        row-map))
                    (let ((name (string-append "ro" (number->string next-id))))
                      (set! next-id (+ next-id 1))
                      (set! style-list (append style-list (list (cons name cm-str))))
                      (set! row-map (cons (cons (cons (worksheet-id ws) row-num) name)
                                          row-map))))))
            (sorted-dict-entries (worksheet-row-heights ws))))
         worksheets)
        (cons style-list row-map)))

    (define (alist-lookup key alist)
      (let loop ((al alist))
        (cond ((null? al) #f)
              ((equal? (caar al) key) (cdar al))
              (else (loop (cdr al))))))

    ;; ---------------------------------------------------------------
    ;; Render content.xml
    ;; ---------------------------------------------------------------
    (define (render-content-xml wb col-style-list col-map row-style-list row-map)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<office:document-content xmlns:office=\"~a\" xmlns:style=\"~a\" xmlns:text=\"~a\" xmlns:table=\"~a\" xmlns:fo=\"~a\" xmlns:number=\"~a\" office:version=\"1.2\">"
                 ns-office ns-style ns-text ns-table ns-fo ns-number)
         ;; automatic-styles
         (display "<office:automatic-styles>" port)
         ;; Cell styles
         (let ((styles-obj (workbook-styles wb)))
           (for-each (lambda (entry)
                       (render-cell-style port (car entry) (cdr entry)))
                     (styles-obj 'styles-list)))
         ;; Column styles
         (for-each (lambda (entry)
                     (format port "<style:style style:name=\"~a\" style:family=\"table-column\">" (car entry))
                     (format port "<style:table-column-properties style:column-width=\"~a\"/>" (cdr entry))
                     (display "</style:style>" port))
                   col-style-list)
         ;; Row styles
         (for-each (lambda (entry)
                     (format port "<style:style style:name=\"~a\" style:family=\"table-row\">" (car entry))
                     (format port "<style:table-row-properties style:row-height=\"~a\"/>" (cdr entry))
                     (display "</style:style>" port))
                   row-style-list)
         (display "</office:automatic-styles>" port)
         ;; body
         (display "<office:body><office:spreadsheet>" port)
         (for-each
          (lambda (ws)
            (format port "<table:table table:name=\"~a\">" (xml-escape (worksheet-name ws)))
            ;; Column definitions
            (let ((col-widths (worksheet-col-widths ws)))
              (unless (= 0 (dict-size col-widths))
                (for-each
                 (lambda (entry)
                   (let* ((col (car entry))
                          (style-name (alist-lookup (cons (worksheet-id ws) col)
                                                    col-map)))
                     (if style-name
                         (format port "<table:table-column table:style-name=\"~a\"/>"
                                 style-name)
                         (display "<table:table-column/>" port))))
                 (sorted-col-entries col-widths))))
            ;; Rows
            (let ((rows (sorted-dict-entries (worksheet-rows ws)))
                  (row-heights (worksheet-row-heights ws)))
              (for-each
               (lambda (row-entry)
                 (let* ((row-num (car row-entry))
                        (row-data (cdr row-entry))
                        (row-style-name (alist-lookup (cons (worksheet-id ws) row-num)
                                                      row-map)))
                   (if row-style-name
                       (format port "<table:table-row table:style-name=\"~a\">"
                               row-style-name)
                       (display "<table:table-row>" port))
                   ;; Cells — sorted by column index with gaps
                   (let ((cells (sorted-dict-entries row-data)))
                     (let loop ((remaining cells) (expected-col 1))
                       (unless (null? remaining)
                         (let* ((cell (cdar remaining))
                                (col-idx (cell-col-index cell))
                                (gap (- col-idx expected-col)))
                           (render-empty-cells port gap)
                           (render-odf-cell port cell)
                           (loop (cdr remaining) (+ col-idx 1))))))
                   (display "</table:table-row>" port)))
               rows))
            (display "</table:table>" port))
          (workbook-worksheets wb))
         (display "</office:spreadsheet></office:body>" port)
         (display "</office:document-content>" port))))

    ;; ---------------------------------------------------------------
    ;; Render styles.xml
    ;; ---------------------------------------------------------------
    (define (render-styles-xml)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<office:document-styles xmlns:office=\"~a\" xmlns:style=\"~a\" xmlns:fo=\"~a\" office:version=\"1.2\">"
                 ns-office ns-style ns-fo)
         (display "<office:styles>" port)
         (display "<style:default-style style:family=\"table-cell\">" port)
         (display "<style:text-properties style:font-name=\"Arial\" fo:font-size=\"10pt\"/>" port)
         (display "</style:default-style>" port)
         (display "</office:styles>" port)
         (display "</office:document-styles>" port))))

    ;; ---------------------------------------------------------------
    ;; Render meta.xml
    ;; ---------------------------------------------------------------
    (define (render-meta-xml)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<office:document-meta xmlns:office=\"~a\" xmlns:meta=\"~a\" office:version=\"1.2\">"
                 ns-office ns-meta)
         (display "<office:meta>" port)
         (display "<meta:generator>SCM ODF Spreadsheet Library</meta:generator>" port)
         (display "</office:meta>" port)
         (display "</office:document-meta>" port))))

    ;; ---------------------------------------------------------------
    ;; Render manifest.xml
    ;; ---------------------------------------------------------------
    (define (render-manifest-xml)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<manifest:manifest xmlns:manifest=\"~a\" manifest:version=\"1.2\">"
                 ns-manifest)
         (format port "<manifest:file-entry manifest:full-path=\"/\" manifest:version=\"1.2\" manifest:media-type=\"~a\"/>"
                 mimetype-ods)
         (display "<manifest:file-entry manifest:full-path=\"content.xml\" manifest:media-type=\"text/xml\"/>" port)
         (display "<manifest:file-entry manifest:full-path=\"styles.xml\" manifest:media-type=\"text/xml\"/>" port)
         (display "<manifest:file-entry manifest:full-path=\"meta.xml\" manifest:media-type=\"text/xml\"/>" port)
         (display "</manifest:manifest>" port))))

    ;; ---------------------------------------------------------------
    ;; Write the complete ODS ZIP archive
    ;; ---------------------------------------------------------------
    (define (workbook-write-zip wb zp)
      ;; Collect column and row styles
      (let* ((col-result (collect-col-styles (workbook-worksheets wb)))
             (col-style-list (car col-result))
             (col-map (cdr col-result))
             (row-result (collect-row-styles (workbook-worksheets wb)))
             (row-style-list (car row-result))
             (row-map (cdr row-result)))
        (define (add-zip-entry name contents)
          (call-with-output-zip-entry
           zp name
           (lambda (port) (display contents port))
           0))
        ;; mimetype must be first entry and STORED (uncompressed)
        (zip-add-stored-entry zp "mimetype" (string->utf8 mimetype-ods) 0)
        ;; Other entries
        (add-zip-entry "META-INF/manifest.xml" (render-manifest-xml))
        (add-zip-entry "content.xml"
                       (render-content-xml wb col-style-list col-map
                                           row-style-list row-map))
        (add-zip-entry "styles.xml"  (render-styles-xml))
        (add-zip-entry "meta.xml"    (render-meta-xml))))

    (define (workbook-save wb filename)
      "Syntax: (workbook-save wb filename)
Library: (scm odf spreadsheet)
Description: Serializes wb to an ODS file at the given filename path. All
worksheets added via workbook-add-worksheet! are included. Returns 'ok.
Example:
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb \"Data\")))
    (worksheet-set-cell! ws \"A1\" \"hello\" 'string #f)
    (workbook-save wb \"/tmp/out.ods\"))"
      (call-with-output-zip filename (lambda (zp) (workbook-write-zip wb zp)))
      'ok)

    (define (workbook-save-to-bytevector wb)
      "Syntax: (workbook-save-to-bytevector wb)
Library: (scm odf spreadsheet)
Description: Serializes wb to an ODS file in memory and returns the bytes as
a bytevector. Useful for generating documents for HTTP responses or in-memory
processing without writing to disk.
Example:
  (let* ((wb (make-workbook))
         (ws (workbook-add-worksheet! wb \"Data\")))
    (worksheet-set-cell! ws \"A1\" \"hello\" 'string #f)
    (workbook-save-to-bytevector wb))"
      (call-with-output-zip-bytevector (lambda (zp) (workbook-write-zip wb zp))))

    ;; ---------------------------------------------------------------
    ;; Streaming worksheet support
    ;; ---------------------------------------------------------------
    (define (make-streaming-worksheet styles-obj port)
      (let ((col-widths    (make-dict))
            (row-heights   (make-dict))
            (current-row   #f)
            (current-cells '())  ;; list of cells for current row, sorted by col
            (header-emitted #f)
            (col-style-map '())  ;; alist of col-letter -> style-name
            (row-style-map '())  ;; alist of row-num -> style-name
            (next-co-id    1)
            (next-ro-id    1))

        (define (emit-header!)
          (unless header-emitted
            ;; Emit automatic-styles closing and body opening have already been
            ;; handled before the streaming worksheet starts.
            ;; Emit column definitions
            (unless (= 0 (dict-size col-widths))
              (for-each
               (lambda (entry)
                 (let* ((col (car entry))
                        (style-name (alist-lookup col col-style-map)))
                   (if style-name
                       (format port "<table:table-column table:style-name=\"~a\"/>"
                               style-name)
                       (display "<table:table-column/>" port))))
               (sorted-col-entries col-widths)))
            (set! header-emitted #t)))

        (define (flush-row!)
          (when current-row
            (let ((row-style (alist-lookup (number->string current-row) row-style-map)))
              (if row-style
                  (format port "<table:table-row table:style-name=\"~a\">"
                          row-style)
                  (display "<table:table-row>" port))
              ;; Emit cells in column order with gaps
              (let ((sorted (list-sort (lambda (a b) (< (cell-col-index a) (cell-col-index b)))
                                       current-cells)))
                (let loop ((remaining sorted) (expected-col 1))
                  (unless (null? remaining)
                    (let* ((cell (car remaining))
                           (col-idx (cell-col-index cell))
                           (gap (- col-idx expected-col)))
                      (render-empty-cells port gap)
                      (render-odf-cell port cell)
                      (loop (cdr remaining) (+ col-idx 1))))))
              (display "</table:table-row>" port))
            (set! current-row #f)
            (set! current-cells '())))

        (lambda (action . args)
          (case action
            ((set-cell!)
             (let* ((id    (car args))
                    (value (cadr args))
                    (type  (caddr args))
                    (style (cadddr args))
                    (parts (cell-id-split id))
                    (col-letters (car parts))
                    (row-str (cdr parts))
                    (row-num (string->number row-str))
                    (col-idx (col-string->index col-letters)))
               (emit-header!)
               (unless (eqv? row-num current-row)
                 (flush-row!)
                 (set! current-row row-num))
               (set! current-cells
                     (append current-cells
                             (list (make-cell col-idx value type style))))))
            ((set-col-width!)
             (let* ((col (car args))
                    (width (cadr args))
                    (cm-str (format-cm (pts->cm width)))
                    (name (string-append "co" (number->string next-co-id))))
               (set! next-co-id (+ next-co-id 1))
               (dict-put col-widths col width)
               (set! col-style-map (cons (cons col name) col-style-map))
               ;; The style definition is emitted in the automatic-styles
               ;; section before the table starts, so we store it for later.
               ;; For streaming, we emit column style inline in the
               ;; automatic-styles block before body.
               ))
            ((set-row-height!)
             (let* ((row-num (car args))
                    (height (cadr args))
                    (row-key (number->string row-num))
                    (cm-str (format-cm (pts->cm height)))
                    (name (string-append "ro" (number->string next-ro-id))))
               (set! next-ro-id (+ next-ro-id 1))
               (dict-put row-heights row-key height)
               (set! row-style-map (cons (cons row-key name) row-style-map))))
            ((get-col-styles)
             ;; Returns list of (name . cm-string) for automatic-styles rendering
             (map (lambda (entry)
                    (let ((style-name (alist-lookup (car entry) col-style-map)))
                      (cons style-name (format-cm (pts->cm (cdr entry))))))
                  (sorted-col-entries col-widths)))
            ((get-row-styles)
             ;; Returns list of (name . cm-string) for automatic-styles rendering
             (map (lambda (entry)
                    (let ((style-name (alist-lookup (car entry) row-style-map)))
                      (cons style-name (format-cm (pts->cm (cdr entry))))))
                  (sorted-dict-entries row-heights)))
            ((finish!)
             (emit-header!)
             (flush-row!)
             (display "</table:table>" port)
             (display "</office:spreadsheet></office:body>" port)
             (display "</office:document-content>" port))))))

    ;; ---------------------------------------------------------------
    ;; Streaming table — optimized for fixed-width rows
    ;; ---------------------------------------------------------------
    ;; Vector #(tag port row-num col-widths row-heights
    ;;          col-style-map row-style-map next-co-id next-ro-id
    ;;          header-emitted pre-write-thunk)
    ;; Indices:  0   1    2       3          4
    ;;               5            6          7         8
    ;;               9             10
    (define (make-streaming-table styles-obj port num-cols)
      "Syntax: (make-streaming-table styles-obj port num-cols)
Library: (scm odf spreadsheet)
Description: Creates a table-streaming worksheet optimized for writing
fixed-width rows at high speed. num-cols is the base number of columns;
rows may contain additional columns beyond this (up to 12 extra). Returns
a streaming-table vector for use with streaming-table-write-row! etc.
Use streaming-table-set-pre-write-thunk! to set a callback that runs
before the first row is written."
      (vector 'streaming-table port 0 (make-dict) (make-dict)
              '() '() 1 1 #f #f))

    (define (streaming-table-set-pre-write-thunk! st thunk)
      (vector-set! st 10 thunk))

    (define (st-fire-pre-write! st)
      (let ((thunk (vector-ref st 10)))
        (when thunk
          (vector-set! st 10 #f)
          (thunk))))

    (define (st-emit-header! st)
      (unless (vector-ref st 9)
        (let ((port (vector-ref st 1))
              (col-widths (vector-ref st 3))
              (col-style-map (vector-ref st 5)))
          (unless (= 0 (dict-size col-widths))
            (for-each
             (lambda (entry)
               (let ((style-name (alist-lookup (car entry) col-style-map)))
                 (if style-name
                     (format port "<table:table-column table:style-name=\"~a\"/>"
                             style-name)
                     (display "<table:table-column/>" port))))
             (sorted-col-entries col-widths))))
        (vector-set! st 9 #t)))

    (define (st-write-cell-inline! st value style)
      (let ((port (vector-ref st 1)))
        (if (number? value)
            (begin
              (display "<table:table-cell" port)
              (when style
                (display " table:style-name=\"" port)
                (display style port)
                (display "\"" port))
              (display " office:value-type=\"float\" office:value=\"" port)
              (display value port)
              (display "\"><text:p>" port)
              (display value port)
              (display "</text:p></table:table-cell>" port))
            (begin
              (display "<table:table-cell" port)
              (when style
                (display " table:style-name=\"" port)
                (display style port)
                (display "\"" port))
              (display " office:value-type=\"string\"><text:p>" port)
              (display (xml-escape (if (string? value)
                                       value
                                       (format #f "~a" value))) port)
              (display "</text:p></table:table-cell>" port)))))

    (define (streaming-table-write-row! st values)
      "Syntax: (streaming-table-write-row! st values)
Library: (scm odf spreadsheet)
Description: Writes a row to a streaming table. values is a list of cell
values."
      (st-fire-pre-write! st)
      (st-emit-header! st)
      (let ((row-num (+ 1 (vector-ref st 2))))
        (vector-set! st 2 row-num)
        (let ((row-str (number->string row-num))
              (port (vector-ref st 1)))
          (let ((row-style (alist-lookup row-str (vector-ref st 6))))
            (if row-style
                (format port "<table:table-row table:style-name=\"~a\">"
                        row-style)
                (display "<table:table-row>" port)))
          (let loop ((vals values))
            (unless (null? vals)
              (st-write-cell-inline! st (car vals) #f)
              (loop (cdr vals))))
          (display "</table:table-row>" port))))

    (define (streaming-table-write-styled-row! st values styles)
      "Syntax: (streaming-table-write-styled-row! st values styles)
Library: (scm odf spreadsheet)
Description: Writes a row with per-cell styles. values and styles are
parallel lists; each style element is #f or a style name string."
      (st-fire-pre-write! st)
      (st-emit-header! st)
      (let ((row-num (+ 1 (vector-ref st 2))))
        (vector-set! st 2 row-num)
        (let ((row-str (number->string row-num))
              (port (vector-ref st 1)))
          (let ((row-style (alist-lookup row-str (vector-ref st 6))))
            (if row-style
                (format port "<table:table-row table:style-name=\"~a\">"
                        row-style)
                (display "<table:table-row>" port)))
          (let loop ((vals values) (stys styles))
            (unless (null? vals)
              (st-write-cell-inline! st (car vals)
                                     (if (null? stys) #f (car stys)))
              (loop (cdr vals)
                    (if (null? stys) '() (cdr stys)))))
          (display "</table:table-row>" port))))

    (define (streaming-table-finish! st)
      "Syntax: (streaming-table-finish! st)
Library: (scm odf spreadsheet)
Description: Finalizes a streaming table worksheet."
      (st-emit-header! st)
      (let ((port (vector-ref st 1)))
        (display "</table:table>" port)
        (display "</office:spreadsheet></office:body>" port)
        (display "</office:document-content>" port)))

    (define (streaming-table-row-num st)
      "Syntax: (streaming-table-row-num st)
Library: (scm odf spreadsheet)
Description: Returns the number of rows written so far to a streaming table."
      (vector-ref st 2))

    (define (streaming-table-set-col-width! st col width)
      "Syntax: (streaming-table-set-col-width! st col width)
Library: (scm odf spreadsheet)
Description: Sets the width of a column in a streaming table (in points)."
      (let ((name (string-append "co" (number->string (vector-ref st 7)))))
        (vector-set! st 7 (+ (vector-ref st 7) 1))
        (dict-put (vector-ref st 3) col width)
        (vector-set! st 5 (cons (cons col name) (vector-ref st 5)))))

    (define (streaming-table-set-row-height! st row height)
      "Syntax: (streaming-table-set-row-height! st row height)
Library: (scm odf spreadsheet)
Description: Sets the height of a row in a streaming table (in points)."
      (let* ((row-key (number->string row))
             (name (string-append "ro" (number->string (vector-ref st 8)))))
        (vector-set! st 8 (+ (vector-ref st 8) 1))
        (dict-put (vector-ref st 4) row-key height)
        (vector-set! st 6 (cons (cons row-key name) (vector-ref st 6)))))

    (define (streaming-table-get-col-styles st)
      "Syntax: (streaming-table-get-col-styles st)
Library: (scm odf spreadsheet)
Description: Returns column styles for automatic-styles."
      (map (lambda (entry)
             (let ((style-name (alist-lookup (car entry) (vector-ref st 5))))
               (cons style-name (format-cm (pts->cm (cdr entry))))))
           (sorted-col-entries (vector-ref st 3))))

    (define (streaming-table-get-row-styles st)
      "Syntax: (streaming-table-get-row-styles st)
Library: (scm odf spreadsheet)
Description: Returns row styles for automatic-styles."
      (map (lambda (entry)
             (let ((style-name (alist-lookup (car entry) (vector-ref st 6))))
               (cons style-name (format-cm (pts->cm (cdr entry))))))
           (sorted-dict-entries (vector-ref st 4))))

    (define (call-with-streaming-table filename name num-cols proc)
      "Syntax: (call-with-streaming-table filename name num-cols proc)
Library: (scm odf spreadsheet)
Description: Creates a single-sheet streaming table workbook, calls
(proc wb-proxy st) where wb-proxy supports workbook-add-style and st is a
streaming table, then finalizes and saves the ODS file. Returns 'ok.
Example:
  (call-with-streaming-table \"/tmp/big.ods\" \"Data\" 3
    (lambda (wb st)
      (streaming-table-write-row! st '(\"Name\" \"Age\" \"City\"))
      (streaming-table-write-row! st '(\"Alice\" 30 \"Bern\"))))"
      (let ((styles (make-styles)))
        (let ((wb-proxy (lambda (action . args)
                          (case action
                            ((styles) styles)))))
          (call-with-output-zip filename
            (lambda (zp)
              (zip-add-stored-entry zp "mimetype" (string->utf8 mimetype-ods) 0)
              (call-with-output-zip-entry zp "content.xml"
                (lambda (content-port)
                  (let* ((st (make-streaming-table styles content-port num-cols))
                         (header-written #f)
                         (emit-header!
                          (lambda ()
                            (unless header-written
                              (set! header-written #t)
                              (display xml-preamble content-port)
                              (format content-port "<office:document-content xmlns:office=\"~a\" xmlns:style=\"~a\" xmlns:text=\"~a\" xmlns:table=\"~a\" xmlns:fo=\"~a\" xmlns:number=\"~a\" office:version=\"1.2\">"
                                      ns-office ns-style ns-text ns-table ns-fo ns-number)
                              (display "<office:automatic-styles>" content-port)
                              (for-each (lambda (entry)
                                          (render-cell-style content-port (car entry) (cdr entry)))
                                        (styles 'styles-list))
                              (for-each (lambda (entry)
                                          (format content-port "<style:style style:name=\"~a\" style:family=\"table-column\">" (car entry))
                                          (format content-port "<style:table-column-properties style:column-width=\"~a\"/>" (cdr entry))
                                          (display "</style:style>" content-port))
                                        (streaming-table-get-col-styles st))
                              (for-each (lambda (entry)
                                          (format content-port "<style:style style:name=\"~a\" style:family=\"table-row\">" (car entry))
                                          (format content-port "<style:table-row-properties style:row-height=\"~a\"/>" (cdr entry))
                                          (display "</style:style>" content-port))
                                        (streaming-table-get-row-styles st))
                              (display "</office:automatic-styles>" content-port)
                              (display "<office:body><office:spreadsheet>" content-port)
                              (format content-port "<table:table table:name=\"~a\">"
                                      (xml-escape name))))))
                    (streaming-table-set-pre-write-thunk! st emit-header!)
                    (proc wb-proxy st)
                    (emit-header!)
                    (streaming-table-finish! st)))
                0)
              (let ((add-entry (lambda (zname contents)
                                 (call-with-output-zip-entry zp zname
                                   (lambda (p) (display contents p))
                                   0))))
                (add-entry "META-INF/manifest.xml" (render-manifest-xml))
                (add-entry "styles.xml"            (render-styles-xml))
                (add-entry "meta.xml"              (render-meta-xml)))))
          'ok)))

    (define (open-streaming-table filename sheet-name num-cols)
      "Syntax: (open-streaming-table filename sheet-name num-cols)
Library: (scm odf spreadsheet)
Description: Opens a new single-sheet streaming table workbook. num-cols is
the number of columns per row. Returns a pair (st . close-proc) where st is
a streaming table and close-proc must be called exactly once to finalize.
Example:
  (let* ((handle (open-streaming-table \"/tmp/out.ods\" \"Sheet1\" 3))
         (st     (car handle))
         (done!  (cdr handle)))
    (streaming-table-write-row! st '(\"hello\" \"world\" 42))
    (done!))"
      (let* ((styles     (make-styles))
             (zp         (open-output-zip-file filename)))
        (zip-add-stored-entry zp "mimetype" (string->utf8 mimetype-ods) 0)
        (let* ((content-port (zip-add-text-entry zp "content.xml" 0))
               (st (make-streaming-table styles content-port num-cols))
               (header-written #f)
               (emit-header!
                (lambda ()
                  (unless header-written
                    (set! header-written #t)
                    (display xml-preamble content-port)
                    (format content-port "<office:document-content xmlns:office=\"~a\" xmlns:style=\"~a\" xmlns:text=\"~a\" xmlns:table=\"~a\" xmlns:fo=\"~a\" xmlns:number=\"~a\" office:version=\"1.2\">"
                            ns-office ns-style ns-text ns-table ns-fo ns-number)
                    (display "<office:automatic-styles>" content-port)
                    (for-each (lambda (entry)
                                (render-cell-style content-port (car entry) (cdr entry)))
                              (styles 'styles-list))
                    (for-each (lambda (entry)
                                (format content-port "<style:style style:name=\"~a\" style:family=\"table-column\">" (car entry))
                                (format content-port "<style:table-column-properties style:column-width=\"~a\"/>" (cdr entry))
                                (display "</style:style>" content-port))
                              (streaming-table-get-col-styles st))
                    (for-each (lambda (entry)
                                (format content-port "<style:style style:name=\"~a\" style:family=\"table-row\">" (car entry))
                                (format content-port "<style:table-row-properties style:row-height=\"~a\"/>" (cdr entry))
                                (display "</style:style>" content-port))
                              (streaming-table-get-row-styles st))
                    (display "</office:automatic-styles>" content-port)
                    (display "<office:body><office:spreadsheet>" content-port)
                    (format content-port "<table:table table:name=\"~a\">"
                            (xml-escape sheet-name))))))
          (streaming-table-set-pre-write-thunk! st emit-header!)
          (cons st
                (lambda ()
                  (emit-header!)
                  (streaming-table-finish! st)
                  (flush-output-port content-port)
                  (for-each (lambda (pair)
                              (let ((p (zip-add-text-entry zp (car pair) 0)))
                                (display (cdr pair) p)
                                (flush-output-port p)))
                            (list (cons "META-INF/manifest.xml" (render-manifest-xml))
                                  (cons "styles.xml"            (render-styles-xml))
                                  (cons "meta.xml"              (render-meta-xml))))
                  (close-output-zip zp))))))

    ;; ---------------------------------------------------------------
    ;; Streaming workbook — writes content.xml incrementally
    ;; ---------------------------------------------------------------
    (define (call-with-streaming-workbook filename name proc)
      "Syntax: (call-with-streaming-workbook filename name proc)
Library: (scm odf spreadsheet)
Description: Creates a single-sheet streaming workbook, calls (proc wb-proxy sws)
where wb-proxy supports workbook-add-style and sws is a streaming worksheet,
then finalizes and saves the ODS file to filename. Cells must be written in
row-ascending order. Styles and column/row dimensions should be set before
writing any cells. Returns 'ok.
Example:
  (call-with-streaming-workbook \"/tmp/big.ods\" \"Data\"
    (lambda (wb sws)
      (let ((hdr (workbook-add-style wb fill: fgcolor: 'lightblue)))
        (worksheet-set-cell! sws \"A1\" \"Name\" 'string hdr)
        (worksheet-set-cell! sws \"A2\" \"Alice\" 'string #f))))"
      (let ((styles (make-styles)))
        (let ((wb-proxy (lambda (action . args)
                          (case action
                            ((styles) styles)))))
          (call-with-output-zip filename
            (lambda (zp)
              ;; mimetype must be first entry, STORED (uncompressed)
              (zip-add-stored-entry zp "mimetype" (string->utf8 mimetype-ods) 0)
              ;; Write content.xml as a streaming entry.
              ;; On first set-cell!, the wrapper emits the XML preamble,
              ;; automatic-styles (cell/col/row styles collected so far),
              ;; and the table opening tag. After proc returns, finish! flushes
              ;; remaining rows and closes all XML elements.
              (call-with-output-zip-entry zp "content.xml"
                (lambda (content-port)
                  (let* ((sws (make-streaming-worksheet styles content-port))
                         (header-written #f)
                         (emit-header!
                          (lambda ()
                            (unless header-written
                              (set! header-written #t)
                              (display xml-preamble content-port)
                              (format content-port "<office:document-content xmlns:office=\"~a\" xmlns:style=\"~a\" xmlns:text=\"~a\" xmlns:table=\"~a\" xmlns:fo=\"~a\" xmlns:number=\"~a\" office:version=\"1.2\">"
                                      ns-office ns-style ns-text ns-table ns-fo ns-number)
                              (display "<office:automatic-styles>" content-port)
                              ;; Cell styles
                              (for-each (lambda (entry)
                                          (render-cell-style content-port (car entry) (cdr entry)))
                                        (styles 'styles-list))
                              ;; Column styles
                              (for-each (lambda (entry)
                                          (format content-port "<style:style style:name=\"~a\" style:family=\"table-column\">" (car entry))
                                          (format content-port "<style:table-column-properties style:column-width=\"~a\"/>" (cdr entry))
                                          (display "</style:style>" content-port))
                                        (sws 'get-col-styles))
                              ;; Row styles
                              (for-each (lambda (entry)
                                          (format content-port "<style:style style:name=\"~a\" style:family=\"table-row\">" (car entry))
                                          (format content-port "<style:table-row-properties style:row-height=\"~a\"/>" (cdr entry))
                                          (display "</style:style>" content-port))
                                        (sws 'get-row-styles))
                              (display "</office:automatic-styles>" content-port)
                              (display "<office:body><office:spreadsheet>" content-port)
                              (format content-port "<table:table table:name=\"~a\">"
                                      (xml-escape name)))))
                         ;; Wrapper intercepts set-cell! to lazily emit the header
                         (wrapper
                          (lambda (action . args)
                            (when (eq? action 'set-cell!)
                              (emit-header!))
                            (apply sws action args))))
                    (proc wb-proxy wrapper)
                    ;; Ensure header is emitted even if no cells were written
                    (emit-header!)
                    (sws 'finish!)))
                0)
              ;; Other ZIP entries
              (let ((add-entry (lambda (zname contents)
                                 (call-with-output-zip-entry zp zname
                                   (lambda (p) (display contents p))
                                   0))))
                (add-entry "META-INF/manifest.xml" (render-manifest-xml))
                (add-entry "styles.xml"            (render-styles-xml))
                (add-entry "meta.xml"              (render-meta-xml)))))
          'ok)))

    ;; ---------------------------------------------------------------
    ;; Convenience: single-sheet workbook
    ;; ---------------------------------------------------------------
    (define (call-with-worksheet filename name proc)
      "Syntax: (call-with-worksheet filename name proc)
Library: (scm odf spreadsheet)
Description: Creates a workbook with a single worksheet named name, calls
(proc wb ws) where wb is the workbook and ws is the worksheet, then saves
the workbook to filename.
Example:
  (call-with-worksheet \"/tmp/out.ods\" \"Data\"
    (lambda (wb ws)
      (worksheet-set-cell! ws \"A1\" \"hello\" 'string #f)))"
      (let* ((wb (make-workbook))
             (ws (workbook-add-worksheet! wb name)))
        (proc wb ws)
        (workbook-save wb filename)))

    ;; ---------------------------------------------------------------
    ;; workbook-add-style defmacro (same keyword syntax as scm ooxml excel)
    ;; ---------------------------------------------------------------
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
Library: (scm odf spreadsheet)
Description: Creates a style, registers it with wb, and returns its style name
(a string like \"ce1\") for use as the style argument to worksheet-set-cell!.
Accepts keyword sections font, fill, border, and alignment followed by
property keyword/value pairs.
Font properties: name: family: size: color: bold italic
Fill properties: type: fgcolor: bgcolor:
Border properties: left: right: top: bottom: diagonal:
Alignment properties: rotation:
Color values may be symbols (e.g. 'red) or 8-char ARGB hex strings.
Example:
(workbook-add-style wb (fill type: solid fgcolor: lightblue))
(workbook-add-style wb (fill type: solid fgcolor: lightblue) (font color: red bold))"
      (syntax-rules ()
        ((_ wb (section-name section-args ...) ...)
         (workbook-add-style-impl wb
           (list (list 'section-name 'section-args ...) ...)))
        ((_ wb flat-args ...)
         (workbook-add-style-impl wb '()))))))

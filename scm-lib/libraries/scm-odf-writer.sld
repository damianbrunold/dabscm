(define-library (scm odf writer)
  (export make-document
          document-add-paragraph!
          document-define-style!
          document-add-named-style!
          document-save
          document-save-to-bytevector
          paragraph-add-run!
          paragraph-add-tab!
          paragraph-add-break!
          paragraph-add-image!
          paragraph-set-style!
          paragraph-set-alignment!
          paragraph-set-spacing!
          paragraph-set-tab-stops!
          paragraph-set-indent!
          make-run-style
          paragraph-add-styled-run!
          resolve-color
          register-color!
          call-with-document
          document-add-heading!
          document-add-table-of-contents!
          document-add-index!
          paragraph-add-index-entry!
          document-add-page-break!
          paragraph-set-page-break-before!
          document-set-page-size!
          document-set-header!
          document-set-footer!
          paragraph-add-page-number!)
  (import (scheme base)
          (scheme cxr)
          (scheme file)
          (scheme write)
          (scm compile)
          (scm io)
          (scm macro)
          (scm zip))

  (begin
    (define xml-preamble
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")

    ;; ── ODF namespaces ──────────────────────────────────────────────────────

    (define ns-office   "urn:oasis:names:tc:opendocument:xmlns:office:1.0")
    (define ns-style    "urn:oasis:names:tc:opendocument:xmlns:style:1.0")
    (define ns-text     "urn:oasis:names:tc:opendocument:xmlns:text:1.0")
    (define ns-fo       "urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0")
    (define ns-svg      "urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0")
    (define ns-draw     "urn:oasis:names:tc:opendocument:xmlns:drawing:1.0")
    (define ns-xlink    "http://www.w3.org/1999/xlink")
    (define ns-meta     "urn:oasis:names:tc:opendocument:xmlns:meta:1.0")
    (define ns-dc       "http://purl.org/dc/elements/1.1/")
    (define ns-manifest "urn:oasis:names:tc:opendocument:xmlns:manifest:1.0")

    ;; ── Color table ─────────────────────────────────────────────────────────

    (define *odf-color-table*
      '((black      . "FF000000")
        (white      . "FFFFFFFF")
        (red        . "FFFF0000")
        (darkred    . "FF8B0000")
        (lightred   . "FFFF8080")
        (green      . "FF00B050")
        (darkgreen  . "FF008000")
        (lightgreen . "FF90EE90")
        (blue       . "FF0070C0")
        (darkblue   . "FF00008B")
        (lightblue  . "FFADD8E6")
        (yellow     . "FFFFFF00")
        (orange     . "FFFF8000")
        (purple     . "FF800080")
        (gray       . "FF808080")
        (darkgray   . "FF404040")
        (lightgray  . "FFD3D3D3")))

    (define (register-color! name hex-string)
      "Syntax: (register-color! name hex-string)
Library: (scm odf writer)
Description: Registers a new named color. name is a symbol; hex-string is an
  8-character ARGB hex string (e.g. \"FFFF0000\").
Example:
  (register-color! 'salmon \"FFFA8072\")"
      (set! *odf-color-table* (cons (cons name hex-string) *odf-color-table*)))

    (define (resolve-color color)
      "Syntax: (resolve-color color)
Library: (scm odf writer)
Description: Resolves a color to an 8-character ARGB hex string. color may be
  a string (returned as-is) or a named symbol (black, white, red, etc.).
Example:
  (resolve-color 'red)       => \"FFFF0000\"
  (resolve-color \"FFAABBCC\") => \"FFAABBCC\""
      (if (string? color)
          color
          (let ((entry (assq color *odf-color-table*)))
            (if entry
                (cdr entry)
                (error "unknown color" color)))))

    ;; ARGB (8-char) -> ODF "#RRGGBB"
    (define (argb->odf-color argb)
      (string-append "#" (substring argb 2 8)))

    ;; ── XML helpers ─────────────────────────────────────────────────────────

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

    ;; ── Unit conversions ────────────────────────────────────────────────────

    (define (pt->cm pt)
      ;; Convert points to centimeters: cm = pt * 2.54 / 72
      (* pt (/ 2.54 72)))

    (define (format-cm val)
      ;; Format a cm value as a string with 3 decimal places followed by "cm"
      (let* ((rounded (/ (round (* val 1000)) 1000))
             (s (number->string (inexact rounded))))
        (string-append s "cm")))

    (define (format-pt val)
      ;; Format a points value as "Xpt" string
      (string-append (number->string val) "pt"))

    ;; ── Style ID ────────────────────────────────────────────────────────────

    (define (style-id-from-name name)
      ;; Remove spaces: "Heading 1" -> "Heading1"
      (let loop ((chars (string->list name)) (acc '()))
        (if (null? chars)
            (list->string (reverse acc))
            (if (char=? (car chars) #\space)
                (loop (cdr chars) acc)
                (loop (cdr chars) (cons (car chars) acc))))))

    ;; ── Run style object (message-passing) ──────────────────────────────────

    (define (make-run-style)
      "Syntax: (make-run-style)
Library: (scm odf writer)
Description: Creates a mutable run style object (font-name, font-size, bold,
  italic, underline, color). Use paragraph-add-styled-run! to apply it.
Example:
  (let ((rs (make-run-style)))
    (rs 'set-bold #t)
    (rs 'set-color (resolve-color 'red))
    (paragraph-add-styled-run! para \"text\" rs))"
      (let ((font-name #f)
            (font-size #f)
            (bold      #f)
            (italic    #f)
            (underline #f)
            (color     #f))
        (lambda (action . args)
          (case action
            ((set-font-name) (set! font-name (car args)))
            ((set-font-size) (set! font-size (car args)))
            ((set-bold)      (set! bold (car args)))
            ((set-italic)    (set! italic (car args)))
            ((set-underline) (set! underline (car args)))
            ((set-color)     (set! color (car args)))
            ((get) (vector font-name font-size bold italic underline color))))))

    ;; ── Document data structure ─────────────────────────────────────────────
    ;; (vector 'doc paragraphs named-styles images next-image-id page-size header footer)
    ;;               1          2             3      4             5         6      7

    (define (make-document)
      "Syntax: (make-document)
Library: (scm odf writer)
Description: Creates and returns a new empty ODF text document object.
Example:
  (let ((doc (make-document)))
    (document-add-paragraph! doc)
    (document-save doc \"out.odt\"))"
      (vector 'doc '() '() '() 1 #f #f #f))

    (define (doc-paragraphs doc)       (vector-ref doc 1))
    (define (doc-named-styles doc)     (vector-ref doc 2))
    (define (doc-images doc)           (vector-ref doc 3))
    (define (doc-next-image-id doc)    (vector-ref doc 4))
    (define (doc-page-size doc)        (vector-ref doc 5))
    (define (doc-header doc)           (vector-ref doc 6))
    (define (doc-footer doc)           (vector-ref doc 7))
    (define (doc-set-paragraphs! doc v)    (vector-set! doc 1 v))
    (define (doc-set-named-styles! doc v)  (vector-set! doc 2 v))
    (define (doc-set-images! doc v)        (vector-set! doc 3 v))
    (define (doc-set-next-image-id! doc v) (vector-set! doc 4 v))
    (define (doc-set-page-size! doc v)     (vector-set! doc 5 v))
    (define (doc-set-header*! doc v)       (vector-set! doc 6 v))
    (define (doc-set-footer*! doc v)       (vector-set! doc 7 v))

    ;; ── Paragraph data structure ────────────────────────────────────────────
    ;; (vector 'para doc style-name alignment spacing tab-stops indent runs outline-level page-break-before)
    ;;               1   2          3         4       5         6      7    8             9

    (define (make-para doc style-name)
      (vector 'para doc style-name #f #f '() #f '() #f #f))

    (define (para-doc para)         (vector-ref para 1))
    (define (para-style para)       (vector-ref para 2))
    (define (para-alignment para)   (vector-ref para 3))
    (define (para-spacing para)     (vector-ref para 4))
    (define (para-tab-stops para)   (vector-ref para 5))
    (define (para-indent para)      (vector-ref para 6))
    (define (para-runs para)        (vector-ref para 7))
    (define (para-set-style! para v)     (vector-set! para 2 v))
    (define (para-set-alignment! para v) (vector-set! para 3 v))
    (define (para-set-spacing! para v)   (vector-set! para 4 v))
    (define (para-set-tab-stops! para v) (vector-set! para 5 v))
    (define (para-set-indent! para v)    (vector-set! para 6 v))
    (define (para-set-runs! para v)      (vector-set! para 7 v))
    (define (para-outline-level para)        (vector-ref para 8))
    (define (para-set-outline-level! para v) (vector-set! para 8 v))
    (define (para-page-break-before para)        (vector-ref para 9))
    (define (para-set-page-break-before*! para v) (vector-set! para 9 v))
    (define (para-append-run! para run)
      (para-set-runs! para (append (para-runs para) (list run))))

    (define (document-add-paragraph! doc . rest)
      "Syntax: (document-add-paragraph! doc [style-name])
Library: (scm odf writer)
Description: Adds a new paragraph to doc, optionally with a named style.
  Returns the new paragraph object.
Example:
  (let* ((doc (make-document))
         (p (document-add-paragraph! doc \"Heading1\")))
    (paragraph-add-run! p \"Title\"))"
      (let* ((style-name (if (null? rest) #f (car rest)))
             (para (make-para doc style-name)))
        (doc-set-paragraphs! doc (append (doc-paragraphs doc) (list para)))
        para))

    (define (document-add-heading! doc level . rest)
      "Syntax: (document-add-heading! doc level [text])
Library: (scm odf writer)
Description: Adds a heading paragraph at the given outline level (1-6). Returns
  the new paragraph object. If text is provided, it is added as an unstyled run.
Example:
  (document-add-heading! doc 1 \"Introduction\")"
      (let* ((style-name (string-append "Heading_20_" (number->string level)))
             (para (make-para doc style-name)))
        (para-set-outline-level! para level)
        (doc-set-paragraphs! doc (append (doc-paragraphs doc) (list para)))
        (when (and (not (null? rest)) (string? (car rest)))
          (paragraph-add-styled-run! para (car rest) #f))
        para))

    ;; ── Page size ──────────────────────────────────────────────────────────

    ;; Named page sizes: (width-cm . height-cm) as strings for ODF
    (define *page-sizes*
      '((letter . ("21.59cm" . "27.94cm"))
        (a4     . ("21.00cm" . "29.70cm"))
        (a5     . ("14.80cm" . "21.00cm"))
        (legal  . ("21.59cm" . "35.56cm"))))

    (define (document-set-page-size! doc size)
      "Syntax: (document-set-page-size! doc size)
Library: (scm odf writer)
Description: Sets the page size for the document. size may be a symbol
  (letter, a4, a5, legal) or a pair (width-cm-string . height-cm-string).
Example:
  (document-set-page-size! doc 'a5)
  (document-set-page-size! doc '(\"14.80cm\" . \"21.00cm\"))"
      (if (symbol? size)
          (let ((entry (assq size *page-sizes*)))
            (if entry
                (doc-set-page-size! doc (cdr entry))
                (error "unknown page size" size)))
          (doc-set-page-size! doc size)))

    ;; ── Page breaks ─────────────────────────────────────────────────────────

    (define (paragraph-set-page-break-before! para)
      "Syntax: (paragraph-set-page-break-before! para)
Library: (scm odf writer)
Description: Sets the page-break-before property on para so that it starts on
  a new page when rendered.
Example:
  (let ((p (document-add-paragraph! doc)))
    (paragraph-set-page-break-before! p)
    (paragraph-add-run! p \"New page content\"))"
      (para-set-page-break-before*! para #t))

    (define (document-add-page-break! doc)
      "Syntax: (document-add-page-break! doc)
Library: (scm odf writer)
Description: Adds a page break to doc by inserting an empty paragraph with the
  page-break-before property set.
Example:
  (document-add-page-break! doc)"
      (let ((para (document-add-paragraph! doc)))
        (paragraph-set-page-break-before! para)
        para))

    ;; ── Headers, footers, and fields ────────────────────────────────────────

    (define (document-set-header! doc . paras)
      "Syntax: (document-set-header! doc para ...)
Library: (scm odf writer)
Description: Sets the document header to the given paragraph(s). The paragraphs
  should be created with document-add-paragraph! and can contain runs, page
  numbers, and other inline content.
Example:
  (let ((p (document-add-paragraph! doc)))
    (paragraph-set-alignment! p 'right)
    (paragraph-add-run! p \"My Document\" italic size: 8)
    (document-set-header! doc p))"
      (doc-set-header*! doc paras))

    (define (document-set-footer! doc . paras)
      "Syntax: (document-set-footer! doc para ...)
Library: (scm odf writer)
Description: Sets the document footer to the given paragraph(s). The paragraphs
  should be created with document-add-paragraph! and can contain runs, page
  numbers, and other inline content.
Example:
  (let ((p (document-add-paragraph! doc)))
    (paragraph-set-alignment! p 'center)
    (paragraph-add-page-number! p)
    (document-set-footer! doc p))"
      (doc-set-footer*! doc paras))

    (define (paragraph-add-page-number! para)
      "Syntax: (paragraph-add-page-number! para)
Library: (scm odf writer)
Description: Adds a page number field to the paragraph. The page number is
  automatically updated when the document is rendered.
Example:
  (let ((p (document-add-paragraph! doc)))
    (paragraph-add-run! p \"Page \")
    (paragraph-add-page-number! p))"
      (para-append-run! para (vector 'page-number)))

    ;; ── Table of contents and index ─────────────────────────────────────────

    (define (document-add-table-of-contents! doc . rest)
      "Syntax: (document-add-table-of-contents! doc [title [max-level]])
Library: (scm odf writer)
Description: Adds a table of contents placeholder to the document. The TOC is
  updated by LibreOffice on open. title defaults to \"Table of Contents\" and
  max-level defaults to 3.
Example:
  (document-add-table-of-contents! doc)
  (document-add-table-of-contents! doc \"Contents\" 2)"
      (let* ((title     (if (null? rest) "Table of Contents" (car rest)))
             (max-level (if (or (null? rest) (null? (cdr rest))) 3 (cadr rest)))
             (block     (vector 'toc title max-level)))
        (doc-set-paragraphs! doc (append (doc-paragraphs doc) (list block)))
        block))

    (define (document-add-index! doc . rest)
      "Syntax: (document-add-index! doc [title])
Library: (scm odf writer)
Description: Adds an alphabetical index placeholder to the document. The index
  is updated by LibreOffice on open. title defaults to \"Index\". Use
  paragraph-add-index-entry! to mark terms for the index.
Example:
  (document-add-index! doc)
  (document-add-index! doc \"Alphabetical Index\")"
      (let* ((title (if (null? rest) "Index" (car rest)))
             (block (vector 'index title)))
        (doc-set-paragraphs! doc (append (doc-paragraphs doc) (list block)))
        block))

    (define (paragraph-add-index-entry! para term)
      "Syntax: (paragraph-add-index-entry! para term)
Library: (scm odf writer)
Description: Marks an inline index entry in para. term is the text that will
  appear in the alphabetical index. The mark is invisible in the document body.
Example:
  (paragraph-add-run! para \"Scheme is a programming language.\")
  (paragraph-add-index-entry! para \"Scheme\")"
      (para-append-run! para (vector 'index-mark term)))

    ;; ── Named style ─────────────────────────────────────────────────────────
    ;; (vector style-id name based-on ppr rpr)
    ;;         0        1    2        3   4
    ;; ppr: (vector alignment spacing-before spacing-after line-spacing tab-stops indent)
    ;;              0         1               2             3            4         5
    ;; rpr: (vector font-name font-size bold italic underline color)
    ;;              0         1         2    3      4         5

    (define (document-add-named-style! doc name based-on
                                   font-name font-size color
                                   bold italic underline
                                   alignment
                                   spacing-before spacing-after line-spacing)
      "Syntax: (document-add-named-style! doc name based-on font-name font-size color bold italic underline alignment spacing-before spacing-after line-spacing)
Library: (scm odf writer)
Description: Low-level function to add a named paragraph style to doc. All
  spacing values are in points (ODF uses pt natively). Use document-define-style!
  for a more convenient keyword-based interface.
Example:
  (document-add-named-style! doc \"Heading\" #f \"Arial\" 16 #f #t #f #f 'center 24 12 #f)"
      (let* ((sid (style-id-from-name name))
             (ppr (vector alignment spacing-before spacing-after line-spacing '() #f))
             (rpr (vector font-name font-size bold italic underline color)))
        (doc-set-named-styles! doc
          (append (doc-named-styles doc)
                  (list (vector sid name based-on ppr rpr))))))

    (define (document-define-style-impl! doc name bo fn sz co bd it ul al sb sa ls)
      (document-add-named-style! doc name bo fn sz
        (if co (resolve-color co) #f)
        bd it ul al sb sa ls))

    (define-syntax document-define-style!
      "Syntax: (document-define-style! doc name [based-on: s] [font: n] [size: n] [color: c] [bold] [italic] [underline] [alignment: a] [spacing-before: n] [spacing-after: n] [line-spacing: n])
Library: (scm odf writer)
Description: Defines a named paragraph style in doc. Keyword arguments set font,
  size, color, bold/italic/underline flags, alignment, and spacing (in points).
  Unlike the Word library, spacing values are stored in points directly since
  ODF uses pt natively.
Example:
  (document-define-style! doc \"Heading\" font: \"Arial\" size: 16 bold alignment: 'center)"
      (syntax-rules ()
        ((_ doc name rest ...)
         (dds-aux doc name #f #f #f #f #f #f #f #f #f #f #f rest ...))))

    (define-syntax dds-aux
      (syntax-rules (based-on: font: size: color: bold italic underline
                     alignment: spacing-before: spacing-after: line-spacing:)
        ((_ doc name bo fn sz co bd it ul al sb sa ls based-on: val rest ...)
         (dds-aux doc name val fn sz co bd it ul al sb sa ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls font: val rest ...)
         (dds-aux doc name bo val sz co bd it ul al sb sa ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls size: val rest ...)
         (dds-aux doc name bo fn val co bd it ul al sb sa ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls color: val rest ...)
         (dds-aux doc name bo fn sz val bd it ul al sb sa ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls alignment: val rest ...)
         (dds-aux doc name bo fn sz co bd it ul val sb sa ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls spacing-before: val rest ...)
         (dds-aux doc name bo fn sz co bd it ul al val sa ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls spacing-after: val rest ...)
         (dds-aux doc name bo fn sz co bd it ul al sb val ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls line-spacing: val rest ...)
         (dds-aux doc name bo fn sz co bd it ul al sb sa val rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls bold rest ...)
         (dds-aux doc name bo fn sz co #t it ul al sb sa ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls italic rest ...)
         (dds-aux doc name bo fn sz co bd #t ul al sb sa ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls underline rest ...)
         (dds-aux doc name bo fn sz co bd it #t al sb sa ls rest ...))
        ((_ doc name bo fn sz co bd it ul al sb sa ls)
         (document-define-style-impl! doc name bo fn sz co bd it ul al sb sa ls))))

    ;; ── Paragraph mutation ──────────────────────────────────────────────────

    (define (paragraph-set-style! para style-name)
      "Syntax: (paragraph-set-style! para style-name)
Library: (scm odf writer)
Description: Sets the named style of para. style-name is a string matching a
  style defined with document-define-style!.
Example:
  (paragraph-set-style! para \"Heading1\")"
      (para-set-style! para style-name))

    (define (paragraph-set-alignment! para alignment)
      "Syntax: (paragraph-set-alignment! para alignment)
Library: (scm odf writer)
Description: Sets the alignment of para. alignment is one of 'left 'center
  'right 'justify.
Example:
  (paragraph-set-alignment! para 'center)"
      (para-set-alignment! para alignment))

    (define (paragraph-set-spacing! para before-pt after-pt . rest)
      "Syntax: (paragraph-set-spacing! para before-pt after-pt [line-pt])
Library: (scm odf writer)
Description: Sets paragraph spacing in points. ODF stores point values
  directly (no conversion needed). line-pt is optional line height.
Example:
  (paragraph-set-spacing! para 12 6)
  (paragraph-set-spacing! para 0 0 14)"
      (let ((line-pt (if (null? rest) #f (car rest))))
        (para-set-spacing! para (list before-pt after-pt line-pt))))

    (define (paragraph-set-tab-stops! para stops)
      "Syntax: (paragraph-set-tab-stops! para stops)
Library: (scm odf writer)
Description: Sets tab stops for para. stops is a list of (pos-pt alignment)
  where pos-pt is in points and alignment is a symbol ('left 'center 'right
  'decimal). Points are converted to cm for ODF output.
Example:
  (paragraph-set-tab-stops! para '((72 left) (144 center)))"
      (para-set-tab-stops! para
        (map (lambda (stop)
               (list (pt->cm (car stop))
                     (symbol->string (cadr stop))))
             stops)))

    (define (paragraph-set-indent! para left-pt . rest)
      "Syntax: (paragraph-set-indent! para left-pt [right-pt [first-pt]])
Library: (scm odf writer)
Description: Sets paragraph indentation in points. Values are stored directly
  in points for ODF output.
Example:
  (paragraph-set-indent! para 36)
  (paragraph-set-indent! para 18 0 -18)"
      (let* ((right-pt (if (null? rest) 0 (car rest)))
             (first-pt (if (or (null? rest) (null? (cdr rest))) 0 (cadr rest))))
        (para-set-indent! para (list left-pt right-pt first-pt))))

    ;; ── Run mutation ────────────────────────────────────────────────────────

    (define (paragraph-add-styled-run! para text run-style-or-false)
      "Syntax: (paragraph-add-styled-run! para text run-style-or-false)
Library: (scm odf writer)
Description: Adds a text run to para. run-style-or-false is a run style object
  from make-run-style, or #f for unstyled text.
Example:
  (paragraph-add-styled-run! para \"hello\" #f)
  (let ((rs (make-run-style))) (rs 'set-bold #t)
    (paragraph-add-styled-run! para \"bold\" rs))"
      (para-append-run! para (vector 'run text run-style-or-false)))

    (define (paragraph-add-run-impl! para text fn sz co bd it ul)
      (if (and (not fn) (not sz) (not co) (not bd) (not it) (not ul))
          (paragraph-add-styled-run! para text #f)
          (let ((rs (make-run-style)))
            (when fn (rs 'set-font-name fn))
            (when sz (rs 'set-font-size sz))
            (when co (rs 'set-color (resolve-color co)))
            (when bd (rs 'set-bold #t))
            (when it (rs 'set-italic #t))
            (when ul (rs 'set-underline #t))
            (paragraph-add-styled-run! para text rs))))

    (define-syntax paragraph-add-run!
      "Syntax: (paragraph-add-run! para text [font: n] [size: n] [color: c] [bold] [italic] [underline])
Library: (scm odf writer)
Description: Adds a text run to para with optional formatting. Keyword arguments
  set font name, size (points), color (symbol or ARGB string), and style flags.
Example:
  (paragraph-add-run! para \"hello\")
  (paragraph-add-run! para \"bold red\" bold color: 'red)"
      (syntax-rules ()
        ((_ para text rest ...)
         (par-aux para text #f #f #f #f #f #f rest ...))))

    (define-syntax par-aux
      (syntax-rules (font: size: color: bold italic underline)
        ((_ para text fn sz co bd it ul font: val rest ...)
         (par-aux para text val sz co bd it ul rest ...))
        ((_ para text fn sz co bd it ul size: val rest ...)
         (par-aux para text fn val co bd it ul rest ...))
        ((_ para text fn sz co bd it ul color: val rest ...)
         (par-aux para text fn sz val bd it ul rest ...))
        ((_ para text fn sz co bd it ul bold rest ...)
         (par-aux para text fn sz co #t it ul rest ...))
        ((_ para text fn sz co bd it ul italic rest ...)
         (par-aux para text fn sz co bd #t ul rest ...))
        ((_ para text fn sz co bd it ul underline rest ...)
         (par-aux para text fn sz co bd it #t rest ...))
        ((_ para text fn sz co bd it ul)
         (paragraph-add-run-impl! para text fn sz co bd it ul))))

    (define (paragraph-add-tab! para)
      "Syntax: (paragraph-add-tab! para)
Library: (scm odf writer)
Description: Adds a tab character to para.
Example:
  (paragraph-add-tab! para)"
      (para-append-run! para (vector 'tab)))

    (define (paragraph-add-break! para)
      "Syntax: (paragraph-add-break! para)
Library: (scm odf writer)
Description: Adds a line break to para.
Example:
  (paragraph-add-break! para)"
      (para-append-run! para (vector 'break)))

    (define (image-ext filename)
      ;; Returns extension string without dot from filename
      (let loop ((i (- (string-length filename) 1)))
        (cond ((< i 0) "png")
              ((char=? (string-ref filename i) #\.)
               (substring filename (+ i 1) (string-length filename)))
              (else (loop (- i 1))))))

    (define (ext->mime ext)
      (cond ((string=? ext "png")  "image/png")
            ((string=? ext "jpg")  "image/jpeg")
            ((string=? ext "jpeg") "image/jpeg")
            ((string=? ext "gif")  "image/gif")
            ((string=? ext "bmp")  "image/bmp")
            (else "image/png")))

    (define (paragraph-add-image! para filename width-pt height-pt)
      "Syntax: (paragraph-add-image! para filename width-pt height-pt)
Library: (scm odf writer)
Description: Embeds an image from filename into para. width-pt and height-pt
  are the display dimensions in points, which are converted to cm for ODF.
Example:
  (paragraph-add-image! para \"logo.png\" 100 50)"
      (let* ((doc     (para-doc para))
             (images  (doc-images doc))
             (img-id  (doc-next-image-id doc))
             (ext     (image-ext filename))
             (mime    (ext->mime ext))
             (w-cm    (pt->cm width-pt))
             (h-cm    (pt->cm height-pt))
             (entry-name (format #f "Pictures/image~a.~a" img-id ext)))
        (doc-set-next-image-id! doc (+ img-id 1))
        (doc-set-images! doc
          (append images (list (list img-id ext mime filename entry-name))))
        (para-append-run! para (vector 'image entry-name w-cm h-cm))))

    ;; ── ODF alignment mapping ───────────────────────────────────────────────

    (define (render-alignment alignment)
      (case alignment
        ((left)    "start")
        ((center)  "center")
        ((right)   "end")
        ((justify) "justify")
        (else      (if (string? alignment) alignment "start"))))

    ;; ── Automatic style collection ──────────────────────────────────────────
    ;; Collect unique paragraph and text span styles, assigning auto names.

    (define (para-props-key para)
      ;; Returns a unique key representing the paragraph's formatting properties
      ;; (excluding named style, which is separate)
      (let ((alignment (para-alignment para))
            (spacing   (para-spacing para))
            (tab-stops (para-tab-stops para))
            (indent    (para-indent para))
            (pgbrk    (para-page-break-before para)))
        (if (or alignment spacing (not (null? tab-stops)) indent pgbrk)
            (list alignment spacing tab-stops indent pgbrk)
            #f)))

    (define (run-style-key run)
      ;; Returns a unique key for a run's style, or #f if no style
      (let* ((rs (vector-ref run 2))
             (rdata (if rs (rs 'get) #f)))
        (if rdata
            (list (vector-ref rdata 0)    ; font-name
                  (vector-ref rdata 1)    ; font-size
                  (vector-ref rdata 2)    ; bold
                  (vector-ref rdata 3)    ; italic
                  (vector-ref rdata 4)    ; underline
                  (vector-ref rdata 5))   ; color
            #f)))

    (define (collect-auto-styles doc)
      ;; Returns (values para-style-alist text-style-alist)
      ;; Each alist maps a key to an auto style name.
      (let ((para-styles '())
            (text-styles '())
            (next-p 1)
            (next-t 1)
            (all-elems (append (doc-paragraphs doc)
                               (or (doc-header doc) '())
                               (or (doc-footer doc) '()))))
        ;; Collect paragraph styles (skip non-paragraph elements)
        (for-each
          (lambda (elem)
            (when (eq? (vector-ref elem 0) 'para)
              (let ((key (para-props-key elem)))
                (when (and key (not (assoc key para-styles)))
                  (set! para-styles
                    (append para-styles
                            (list (cons key (string-append "P" (number->string next-p))))))
                  (set! next-p (+ next-p 1))))))
          all-elems)
        ;; Collect text styles (skip non-paragraph elements)
        (for-each
          (lambda (elem)
            (when (eq? (vector-ref elem 0) 'para)
              (for-each
                (lambda (run)
                  (when (eq? (vector-ref run 0) 'run)
                    (let ((key (run-style-key run)))
                      (when (and key (not (assoc key text-styles)))
                        (set! text-styles
                          (append text-styles
                                  (list (cons key (string-append "T" (number->string next-t))))))
                        (set! next-t (+ next-t 1))))))
                (para-runs elem))))
          all-elems)
        (list para-styles text-styles)))

    ;; ── XML rendering: automatic paragraph style ────────────────────────────

    (define (render-auto-para-style port name key)
      ;; key is (alignment spacing tab-stops indent page-break-before)
      (let ((alignment (car key))
            (spacing   (cadr key))
            (tab-stops (caddr key))
            (indent    (cadddr key))
            (pgbrk    (if (null? (cddddr key)) #f (car (cddddr key)))))
        (format port "<style:style style:name=\"~a\" style:family=\"paragraph\">" name)
        (display "<style:paragraph-properties" port)
        (when pgbrk
          (display " fo:break-before=\"page\"" port))
        (when alignment
          (format port " fo:text-align=\"~a\"" (render-alignment alignment)))
        (when spacing
          (let ((before (car spacing))
                (after  (cadr spacing))
                (line   (caddr spacing)))
            (format port " fo:margin-top=\"~a\"" (format-pt before))
            (format port " fo:margin-bottom=\"~a\"" (format-pt after))
            (when line
              (format port " fo:line-height=\"~a\"" (format-pt line)))))
        (when indent
          (let ((left  (car indent))
                (right (cadr indent))
                (first (caddr indent)))
            (format port " fo:margin-left=\"~a\"" (format-pt left))
            (format port " fo:margin-right=\"~a\"" (format-pt right))
            (format port " fo:text-indent=\"~a\"" (format-pt first))))
        (if (not (null? tab-stops))
            (begin
              (display ">" port)
              (display "<style:tab-stops>" port)
              (for-each (lambda (ts)
                          (format port "<style:tab-stop style:position=\"~a\" style:type=\"~a\"/>"
                                  (format-cm (car ts)) (cadr ts)))
                        tab-stops)
              (display "</style:tab-stops>" port)
              (display "</style:paragraph-properties>" port))
            (display "/>" port))
        (display "</style:style>" port)))

    ;; ── XML rendering: automatic text style ─────────────────────────────────

    (define (render-auto-text-style port name key)
      ;; key is (font-name font-size bold italic underline color)
      (let ((fname  (car key))
            (fsize  (cadr key))
            (bold   (caddr key))
            (italic (cadddr key))
            (ul     (list-ref key 4))
            (color  (list-ref key 5)))
        (format port "<style:style style:name=\"~a\" style:family=\"text\">" name)
        (display "<style:text-properties" port)
        (when fname
          (format port " style:font-name=\"~a\"" (xml-escape fname)))
        (when fsize
          (format port " fo:font-size=\"~a\"" (format-pt fsize)))
        (when bold
          (display " fo:font-weight=\"bold\"" port))
        (when italic
          (display " fo:font-style=\"italic\"" port))
        (when ul
          (display " style:text-underline-style=\"solid\" style:text-underline-width=\"auto\" style:text-underline-color=\"font-color\"" port))
        (when color
          (format port " fo:color=\"~a\"" (argb->odf-color color)))
        (display "/>" port)
        (display "</style:style>" port)))

    ;; ── XML rendering: content.xml ──────────────────────────────────────────

    (define (render-run port run text-styles)
      (let ((tag (vector-ref run 0)))
        (cond
          ((eq? tag 'run)
           (let* ((text  (vector-ref run 1))
                  (rs    (vector-ref run 2))
                  (key   (if rs
                             (let ((rdata (rs 'get)))
                               (list (vector-ref rdata 0)
                                     (vector-ref rdata 1)
                                     (vector-ref rdata 2)
                                     (vector-ref rdata 3)
                                     (vector-ref rdata 4)
                                     (vector-ref rdata 5)))
                             #f))
                  (style-name (if key
                                  (let ((entry (assoc key text-styles)))
                                    (if entry (cdr entry) #f))
                                  #f)))
             (if style-name
                 (begin
                   (format port "<text:span text:style-name=\"~a\">" style-name)
                   (display (xml-escape text) port)
                   (display "</text:span>" port))
                 (display (xml-escape text) port))))
          ((eq? tag 'tab)
           (display "<text:tab/>" port))
          ((eq? tag 'break)
           (display "<text:line-break/>" port))
          ((eq? tag 'image)
           (let ((entry-name (vector-ref run 1))
                 (w-cm       (vector-ref run 2))
                 (h-cm       (vector-ref run 3)))
             (format port "<draw:frame draw:name=\"~a\" svg:width=\"~a\" svg:height=\"~a\" text:anchor-type=\"as-char\">"
                     (xml-escape entry-name)
                     (format-cm w-cm) (format-cm h-cm))
             (format port "<draw:image xlink:href=\"~a\" xlink:type=\"simple\" xlink:show=\"embed\" xlink:actuate=\"onLoad\"/>"
                     (xml-escape entry-name))
             (display "</draw:frame>" port)))
          ((eq? tag 'index-mark)
           (let ((term (vector-ref run 1)))
             (format port "<text:alphabetical-index-mark text:string-value=\"~a\"/>"
                     (xml-escape term))))
          ((eq? tag 'page-number)
           (display "<text:page-number text:select-page=\"current\">0</text:page-number>" port)))))

    ;; ── TOC / Index element rendering ───────────────────────────────────────

    (define (render-toc-element port toc)
      (let ((title     (vector-ref toc 1))
            (max-level (vector-ref toc 2)))
        (display "<text:table-of-content text:name=\"Table of Contents\">" port)
        (format port "<text:table-of-content-source text:outline-level=\"~a\">" max-level)
        (when title
          (format port "<text:index-title-template>~a</text:index-title-template>"
                  (xml-escape title)))
        (display "</text:table-of-content-source>" port)
        (display "<text:index-body>" port)
        (when title
          (display "<text:index-title>" port)
          (format port "<text:p>~a</text:p>" (xml-escape title))
          (display "</text:index-title>" port))
        (display "</text:index-body>" port)
        (display "</text:table-of-content>" port)))

    (define (render-index-element port idx)
      (let ((title (vector-ref idx 1)))
        (display "<text:alphabetical-index text:name=\"Alphabetical Index\">" port)
        (display "<text:alphabetical-index-source/>" port)
        (display "<text:index-body>" port)
        (when title
          (display "<text:index-title>" port)
          (format port "<text:p>~a</text:p>" (xml-escape title))
          (display "</text:index-title>" port))
        (display "</text:index-body>" port)
        (display "</text:alphabetical-index>" port)))

    (define (render-content-xml doc)
      (let* ((auto-styles (collect-auto-styles doc))
             (para-styles (car auto-styles))
             (text-styles (cadr auto-styles)))
        (call-with-output-string
         (lambda (port)
           (display xml-preamble port)
           (format port "<office:document-content xmlns:office=\"~a\" xmlns:style=\"~a\" xmlns:text=\"~a\" xmlns:fo=\"~a\" xmlns:draw=\"~a\" xmlns:xlink=\"~a\" xmlns:svg=\"~a\" office:version=\"1.2\">"
                   ns-office ns-style ns-text ns-fo ns-draw ns-xlink ns-svg)
           ;; Automatic styles
           (display "<office:automatic-styles>" port)
           (for-each (lambda (entry)
                       (render-auto-para-style port (cdr entry) (car entry)))
                     para-styles)
           (for-each (lambda (entry)
                       (render-auto-text-style port (cdr entry) (car entry)))
                     text-styles)
           (display "</office:automatic-styles>" port)
           ;; Body
           (display "<office:body><office:text>" port)
           (for-each
             (lambda (elem)
               (let ((tag (vector-ref elem 0)))
                 (cond
                   ((eq? tag 'para)
                    (let* ((key (para-props-key elem))
                           (auto-name (if key
                                          (let ((entry (assoc key para-styles)))
                                            (if entry (cdr entry) #f))
                                          #f))
                           (named-style (para-style elem))
                           (style-attr (cond
                                         (named-style
                                          (format #f " text:style-name=\"~a\""
                                                  (style-id-from-name named-style)))
                                         (auto-name
                                          (format #f " text:style-name=\"~a\"" auto-name))
                                         (else "")))
                           (outline-level (para-outline-level elem)))
                      (if outline-level
                          (begin
                            (format port "<text:h text:outline-level=\"~a\"~a>"
                                    outline-level style-attr)
                            (for-each (lambda (run) (render-run port run text-styles))
                                      (para-runs elem))
                            (display "</text:h>" port))
                          (begin
                            (format port "<text:p~a>" style-attr)
                            (for-each (lambda (run) (render-run port run text-styles))
                                      (para-runs elem))
                            (display "</text:p>" port)))))
                   ((eq? tag 'toc)
                    (render-toc-element port elem))
                   ((eq? tag 'index)
                    (render-index-element port elem)))))
             (doc-paragraphs doc))
           (display "</office:text></office:body>" port)
           (display "</office:document-content>" port)))))

    ;; ── XML rendering: styles.xml ───────────────────────────────────────────

    (define (render-styles-xml doc)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<office:document-styles xmlns:office=\"~a\" xmlns:style=\"~a\" xmlns:fo=\"~a\" xmlns:text=\"~a\" office:version=\"1.2\">"
                 ns-office ns-style ns-fo ns-text)
         (display "<office:styles>" port)
         ;; Default style
         (display "<style:default-style style:family=\"paragraph\">" port)
         (display "<style:paragraph-properties fo:text-align=\"start\"/>" port)
         (display "<style:text-properties style:font-name=\"Arial\" fo:font-size=\"12pt\"/>" port)
         (display "</style:default-style>" port)
         ;; Standard style
         (display "<style:style style:name=\"Standard\" style:family=\"paragraph\"/>" port)
         ;; Built-in heading styles
         (for-each
           (lambda (def)
             (let ((level (car def))
                   (size  (cadr def))
                   (sb    (caddr def))
                   (sa    (cadddr def)))
               (format port "<style:style style:name=\"Heading_20_~a\" style:display-name=\"Heading ~a\" style:family=\"paragraph\" style:parent-style-name=\"Standard\" style:default-outline-level=\"~a\">"
                       level level level)
               (format port "<style:paragraph-properties fo:margin-top=\"~a\" fo:margin-bottom=\"~a\"/>"
                       (format-pt sb) (format-pt sa))
               (format port "<style:text-properties fo:font-weight=\"bold\" fo:font-size=\"~a\"/>"
                       (format-pt size))
               (display "</style:style>" port)))
           '((1 24 24 12)
             (2 18 18 8)
             (3 14 14 6)
             (4 12 12 4)
             (5 11 10 4)
             (6 10 8 4)))
         ;; User-defined named styles
         (for-each
           (lambda (ns)
             (let* ((sid      (vector-ref ns 0))
                    (sname    (vector-ref ns 1))
                    (based-on (vector-ref ns 2))
                    (ppr      (vector-ref ns 3))
                    (rpr      (vector-ref ns 4))
                    (align    (vector-ref ppr 0))
                    (sbefore  (vector-ref ppr 1))
                    (safter   (vector-ref ppr 2))
                    (sline    (vector-ref ppr 3)))
               (format port "<style:style style:name=\"~a\" style:family=\"paragraph\""
                       (xml-escape sid))
               (if based-on
                   (format port " style:parent-style-name=\"~a\">"
                           (xml-escape (style-id-from-name based-on)))
                   (display " style:parent-style-name=\"Standard\">" port))
               ;; Paragraph properties
               (when (or align sbefore safter sline)
                 (display "<style:paragraph-properties" port)
                 (when align
                   (format port " fo:text-align=\"~a\"" (render-alignment align)))
                 (when sbefore
                   (format port " fo:margin-top=\"~a\"" (format-pt sbefore)))
                 (when safter
                   (format port " fo:margin-bottom=\"~a\"" (format-pt safter)))
                 (when sline
                   (format port " fo:line-height=\"~a\"" (format-pt sline)))
                 (display "/>" port))
               ;; Text properties
               (let ((fname  (vector-ref rpr 0))
                     (fsize  (vector-ref rpr 1))
                     (bold   (vector-ref rpr 2))
                     (italic (vector-ref rpr 3))
                     (ul     (vector-ref rpr 4))
                     (color  (vector-ref rpr 5)))
                 (when (or fname fsize bold italic ul color)
                   (display "<style:text-properties" port)
                   (when fname
                     (format port " style:font-name=\"~a\"" (xml-escape fname)))
                   (when fsize
                     (format port " fo:font-size=\"~a\"" (format-pt fsize)))
                   (when bold
                     (display " fo:font-weight=\"bold\"" port))
                   (when italic
                     (display " fo:font-style=\"italic\"" port))
                   (when ul
                     (display " style:text-underline-style=\"solid\" style:text-underline-width=\"auto\" style:text-underline-color=\"font-color\"" port))
                   (when color
                     (format port " fo:color=\"~a\"" (argb->odf-color color)))
                   (display "/>" port)))
               (display "</style:style>" port)))
           (doc-named-styles doc))
         (display "</office:styles>" port)
         ;; Page layout (automatic styles + master pages)
         (let ((ps  (doc-page-size doc))
               (hdr (doc-header doc))
               (ftr (doc-footer doc)))
           (when (or ps hdr ftr)
             (display "<office:automatic-styles>" port)
             (display "<style:page-layout style:name=\"pm1\">" port)
             (if ps
                 (format port "<style:page-layout-properties fo:page-width=\"~a\" fo:page-height=\"~a\"/>"
                         (car ps) (cdr ps))
                 (display "<style:page-layout-properties/>" port))
             (display "</style:page-layout>" port)
             (display "</office:automatic-styles>" port)
             (display "<office:master-styles>" port)
             (if (or hdr ftr)
                 (begin
                   (display "<style:master-page style:name=\"Standard\" style:page-layout-name=\"pm1\">" port)
                   (when hdr
                     (display "<style:header>" port)
                     (for-each
                       (lambda (para)
                         (let ((alignment (para-alignment para)))
                           (if alignment
                               (format port "<text:p text:style-name=\"Standard\"><text:span>")
                               (display "<text:p>" port))
                           ;; Render inline: for header/footer we use simple text + fields
                           (for-each
                             (lambda (run)
                               (let ((tag (vector-ref run 0)))
                                 (cond
                                   ((eq? tag 'run)
                                    (display (xml-escape (vector-ref run 1)) port))
                                   ((eq? tag 'page-number)
                                    (display "<text:page-number text:select-page=\"current\">0</text:page-number>" port))
                                   ((eq? tag 'tab)
                                    (display "<text:tab/>" port)))))
                             (para-runs para))
                           (if alignment
                               (display "</text:span></text:p>" port)
                               (display "</text:p>" port))))
                       hdr)
                     (display "</style:header>" port))
                   (when ftr
                     (display "<style:footer>" port)
                     (for-each
                       (lambda (para)
                         (let ((alignment (para-alignment para)))
                           (if alignment
                               (format port "<text:p text:style-name=\"Standard\"><text:span>")
                               (display "<text:p>" port))
                           (for-each
                             (lambda (run)
                               (let ((tag (vector-ref run 0)))
                                 (cond
                                   ((eq? tag 'run)
                                    (display (xml-escape (vector-ref run 1)) port))
                                   ((eq? tag 'page-number)
                                    (display "<text:page-number text:select-page=\"current\">0</text:page-number>" port))
                                   ((eq? tag 'tab)
                                    (display "<text:tab/>" port)))))
                             (para-runs para))
                           (if alignment
                               (display "</text:span></text:p>" port)
                               (display "</text:p>" port))))
                       ftr)
                     (display "</style:footer>" port))
                   (display "</style:master-page>" port))
                 (display "<style:master-page style:name=\"Standard\" style:page-layout-name=\"pm1\"/>" port))
             (display "</office:master-styles>" port)))
         (display "</office:document-styles>" port))))

    ;; ── XML rendering: meta.xml ─────────────────────────────────────────────

    (define (render-meta-xml)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<office:document-meta xmlns:office=\"~a\" xmlns:meta=\"~a\" office:version=\"1.2\">"
                 ns-office ns-meta)
         (display "<office:meta>" port)
         (display "<meta:generator>SCM ODF Writer Library</meta:generator>" port)
         (display "</office:meta>" port)
         (display "</office:document-meta>" port))))

    ;; ── XML rendering: manifest.xml ─────────────────────────────────────────

    (define (render-manifest-xml doc)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<manifest:manifest xmlns:manifest=\"~a\" manifest:version=\"1.2\">"
                 ns-manifest)
         (display "<manifest:file-entry manifest:full-path=\"/\" manifest:version=\"1.2\" manifest:media-type=\"application/vnd.oasis.opendocument.text\"/>" port)
         (display "<manifest:file-entry manifest:full-path=\"content.xml\" manifest:media-type=\"text/xml\"/>" port)
         (display "<manifest:file-entry manifest:full-path=\"styles.xml\" manifest:media-type=\"text/xml\"/>" port)
         (display "<manifest:file-entry manifest:full-path=\"meta.xml\" manifest:media-type=\"text/xml\"/>" port)
         ;; Image entries
         (for-each
           (lambda (img)
             (let ((entry-name (list-ref img 4))
                   (mime       (caddr img)))
               (format port "<manifest:file-entry manifest:full-path=\"~a\" manifest:media-type=\"~a\"/>"
                       (xml-escape entry-name) mime)))
           (doc-images doc))
         (display "</manifest:manifest>" port))))

    ;; ── document-save ───────────────────────────────────────────────────────

    (define (document-write-zip doc zp)
      ;; 1. mimetype — STORED (uncompressed), must be first entry
      (zip-add-stored-entry zp "mimetype"
                            (string->utf8 "application/vnd.oasis.opendocument.text"))
      ;; 2. META-INF/manifest.xml
      (let ((p (zip-add-text-entry zp "META-INF/manifest.xml")))
        (display (render-manifest-xml doc) p)
        (flush-output-port p))
      ;; 3. content.xml
      (let ((p (zip-add-text-entry zp "content.xml")))
        (display (render-content-xml doc) p)
        (flush-output-port p))
      ;; 4. styles.xml
      (let ((p (zip-add-text-entry zp "styles.xml")))
        (display (render-styles-xml doc) p)
        (flush-output-port p))
      ;; 5. meta.xml
      (let ((p (zip-add-text-entry zp "meta.xml")))
        (display (render-meta-xml) p)
        (flush-output-port p))
      ;; 6. Embedded images
      (for-each
        (lambda (img)
          (let* ((img-path   (list-ref img 3))
                 (entry-name (list-ref img 4))
                 (bin-port   (zip-add-binary-entry zp entry-name 0)))
            (let ((in-port (open-binary-input-file img-path)))
              (let loop ()
                (let ((chunk (read-bytevector 4096 in-port)))
                  (unless (eof-object? chunk)
                    (write-bytevector chunk bin-port)
                    (loop))))
              (close-input-port in-port))))
        (doc-images doc)))

    (define (document-save doc filename)
      "Syntax: (document-save doc filename)
Library: (scm odf writer)
Description: Serializes doc to an ODF text document (.odt) file at filename.
  Returns 'ok.
Example:
  (let* ((doc (make-document))
         (p   (document-add-paragraph! doc)))
    (paragraph-add-run! p \"Hello, World!\")
    (document-save doc \"/tmp/out.odt\"))"
      (call-with-output-zip filename (lambda (zp) (document-write-zip doc zp)))
      'ok)

    (define (document-save-to-bytevector doc)
      "Syntax: (document-save-to-bytevector doc)
Library: (scm odf writer)
Description: Serializes doc to an ODF text document in memory and returns the
  bytes as a bytevector. Useful for generating documents for HTTP responses or
  in-memory processing without writing to disk.
Example:
  (let* ((doc (make-document))
         (p   (document-add-paragraph! doc)))
    (paragraph-add-run! p \"Hello, World!\")
    (document-save-to-bytevector doc))"
      (call-with-output-zip-bytevector (lambda (zp) (document-write-zip doc zp))))

    ;; ── call-with-document ──────────────────────────────────────────────────

    (define (call-with-document filename proc)
      "Syntax: (call-with-document filename proc)
Library: (scm odf writer)
Description: Creates a new document, calls (proc doc), then saves to filename.
  Returns 'ok.
Example:
  (call-with-document \"/tmp/out.odt\"
    (lambda (doc)
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p \"Hello\"))))"
      (let ((doc (make-document)))
        (proc doc)
        (document-save doc filename)))))

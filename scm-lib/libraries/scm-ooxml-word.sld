(define-library (scm ooxml word)
  (export make-document
          document-add-paragraph!
          document-define-style!
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
          document-add-named-style!
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
      "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")

    ;; ── Color table ──────────────────────────────────────────────────────────

    (define *word-color-table*
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
Library: (scm ooxml word)
Description: Registers a new named color. name is a symbol; hex-string is an
8-character ARGB hex string (e.g. \"FFFF0000\").
Example:
  (register-color! 'salmon \"FFFA8072\")"
      (set! *word-color-table* (cons (cons name hex-string) *word-color-table*)))

    (define (resolve-color color)
      "Syntax: (resolve-color color)
Library: (scm ooxml word)
Description: Resolves a color to an 8-character ARGB hex string. color may be
a string (returned as-is) or a named symbol (black, white, red, etc.).
Example:
  (resolve-color 'red)       => \"FFFF0000\"
  (resolve-color \"FFAABBCC\") => \"FFAABBCC\""
      (if (string? color)
          color
          (let ((entry (assq color *word-color-table*)))
            (if entry
                (cdr entry)
                (error "unknown color" color)))))

    ;; Strip alpha prefix: 8-char ARGB -> 6-char RGB for Word XML w:val
    (define (argb->rgb argb) (substring argb 2 8))

    ;; ── XML helpers ──────────────────────────────────────────────────────────

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

    ;; ── Style ID ─────────────────────────────────────────────────────────────

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
Library: (scm ooxml word)
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

    ;; ── Document data structure ───────────────────────────────────────────────
    ;; (vector 'doc paragraphs named-styles images next-image-id page-size header footer)
    ;;               1          2             3      4             5         6      7

    (define (make-document)
      "Syntax: (make-document)
Library: (scm ooxml word)
Description: Creates and returns a new empty Word document object.
Example:
  (let ((doc (make-document)))
    (document-add-paragraph! doc)
    (document-save doc \"out.docx\"))"
      (vector 'doc '() '() '() 2 #f #f #f))

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

    ;; ── Paragraph data structure ──────────────────────────────────────────────
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
Library: (scm ooxml word)
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
Library: (scm ooxml word)
Description: Adds a heading paragraph at the given outline level (1-6). Returns
the new paragraph object. If text is provided, it is added as an unstyled run.
Example:
  (document-add-heading! doc 1 \"Introduction\")"
      (let* ((style-name (string-append "Heading " (number->string level)))
             (para (make-para doc style-name)))
        (para-set-outline-level! para level)
        (doc-set-paragraphs! doc (append (doc-paragraphs doc) (list para)))
        (when (and (not (null? rest)) (string? (car rest)))
          (paragraph-add-styled-run! para (car rest) #f))
        para))

    ;; ── Page size ──────────────────────────────────────────────────────────

    ;; Named page sizes: (width-twips . height-twips)
    (define *page-sizes*
      '((letter . (12240 . 15840))
        (a4     . (11906 . 16838))
        (a5     . ( 8391 . 11906))
        (legal  . (12240 . 20163))))

    (define (document-set-page-size! doc size)
      "Syntax: (document-set-page-size! doc size)
Library: (scm ooxml word)
Description: Sets the page size for the document. size may be a symbol
(letter, a4, a5, legal) or a pair (width-twips . height-twips).
Example:
  (document-set-page-size! doc 'a5)
  (document-set-page-size! doc '(8391 . 11906))"
      (if (symbol? size)
          (let ((entry (assq size *page-sizes*)))
            (if entry
                (doc-set-page-size! doc (cdr entry))
                (error "unknown page size" size)))
          (doc-set-page-size! doc size)))

    ;; ── Page breaks ─────────────────────────────────────────────────────────

    (define (paragraph-set-page-break-before! para)
      "Syntax: (paragraph-set-page-break-before! para)
Library: (scm ooxml word)
Description: Sets the page-break-before property on para so that it starts on
a new page when rendered.
Example:
  (let ((p (document-add-paragraph! doc)))
    (paragraph-set-page-break-before! p)
    (paragraph-add-run! p \"New page content\"))"
      (para-set-page-break-before*! para #t))

    (define (document-add-page-break! doc)
      "Syntax: (document-add-page-break! doc)
Library: (scm ooxml word)
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
Library: (scm ooxml word)
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
Library: (scm ooxml word)
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
Library: (scm ooxml word)
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
Library: (scm ooxml word)
Description: Adds a table of contents placeholder to the document. The TOC is
a field code that Word/LibreOffice updates on open. title defaults to
\"Table of Contents\" and max-level defaults to 3.
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
Library: (scm ooxml word)
Description: Adds an alphabetical index placeholder to the document. The index
is a field code that Word/LibreOffice updates on open. title defaults to
\"Index\". Use paragraph-add-index-entry! to mark terms for the index.
Example:
  (document-add-index! doc)
  (document-add-index! doc \"Alphabetical Index\")"
      (let* ((title (if (null? rest) "Index" (car rest)))
             (block (vector 'index title)))
        (doc-set-paragraphs! doc (append (doc-paragraphs doc) (list block)))
        block))

    (define (paragraph-add-index-entry! para term)
      "Syntax: (paragraph-add-index-entry! para term)
Library: (scm ooxml word)
Description: Marks an inline index entry in para. term is the text that will
appear in the alphabetical index. The mark is invisible in the document body.
Example:
  (paragraph-add-run! para \"Scheme is a programming language.\")
  (paragraph-add-index-entry! para \"Scheme\")"
      (para-append-run! para (vector 'xe term)))

    ;; ── Named style ──────────────────────────────────────────────────────────
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
      (let* ((sid (style-id-from-name name))
             (ppr (vector alignment spacing-before spacing-after line-spacing '() #f))
             (rpr (vector font-name font-size bold italic underline color)))
        (doc-set-named-styles! doc
          (append (doc-named-styles doc)
                  (list (vector sid name based-on ppr rpr))))))

    (define (document-define-style-impl! doc name bo fn sz co bd it ul al sb sa ls)
      (document-add-named-style! doc name bo fn sz
        (if co (resolve-color co) #f)
        bd it ul al
        (if sb (* sb 20) #f)
        (if sa (* sa 20) #f)
        (if ls (* ls 20) #f)))

    (define-syntax document-define-style!
      "Syntax: (document-define-style! doc name [based-on: s] [font: n] [size: n] [color: c] [bold] [italic] [underline] [alignment: a] [spacing-before: n] [spacing-after: n] [line-spacing: n])
Library: (scm ooxml word)
Description: Defines a named paragraph style in doc. Keyword arguments set font,
size, color, bold/italic/underline flags, alignment, and spacing (in points).
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

    ;; ── Paragraph mutation ────────────────────────────────────────────────────

    (define (paragraph-set-style! para style-name)
      "Syntax: (paragraph-set-style! para style-name)
Library: (scm ooxml word)
Description: Sets the named style of para. style-name is a string matching a
style defined with document-define-style! or a built-in Word style.
Example:
  (paragraph-set-style! para \"Heading1\")"
      (para-set-style! para style-name))

    (define (paragraph-set-alignment! para alignment)
      "Syntax: (paragraph-set-alignment! para alignment)
Library: (scm ooxml word)
Description: Sets the alignment of para. alignment is one of 'left 'center
'right 'justify.
Example:
  (paragraph-set-alignment! para 'center)"
      (para-set-alignment! para alignment))

    (define (paragraph-set-spacing! para before-pt after-pt . rest)
      "Syntax: (paragraph-set-spacing! para before-pt after-pt [line-pt])
Library: (scm ooxml word)
Description: Sets paragraph spacing. Values are in points and are converted
to twips internally (1 pt = 20 twips). line-pt is optional.
Example:
  (paragraph-set-spacing! para 12 6)
  (paragraph-set-spacing! para 0 0 14)"
      (let ((line-pt (if (null? rest) #f (car rest))))
        (para-set-spacing! para
          (list (* before-pt 20)
                (* after-pt 20)
                (if line-pt (* line-pt 20) #f)))))

    (define (paragraph-set-tab-stops! para stops)
      "Syntax: (paragraph-set-tab-stops! para stops)
Library: (scm ooxml word)
Description: Sets tab stops for para. stops is a list of (pos-pt alignment)
where pos-pt is in points and alignment is a symbol ('left 'center 'right
'decimal). Points are converted to twips.
Example:
  (paragraph-set-tab-stops! para '((2.5 left) (5.0 center)))"
      (para-set-tab-stops! para
        (map (lambda (stop)
               (list (* (car stop) 20)
                     (symbol->string (cadr stop))))
             stops)))

    (define (paragraph-set-indent! para left-pt . rest)
      "Syntax: (paragraph-set-indent! para left-pt [right-pt [first-pt]])
Library: (scm ooxml word)
Description: Sets paragraph indentation in points (converted to twips).
Example:
  (paragraph-set-indent! para 1.0)
  (paragraph-set-indent! para 0.5 0 -0.5)"
      (let* ((right-pt (if (null? rest) 0 (car rest)))
             (first-pt (if (or (null? rest) (null? (cdr rest))) 0 (cadr rest))))
        (para-set-indent! para
          (list (* left-pt 20) (* right-pt 20) (* first-pt 20)))))

    ;; ── Run mutation ─────────────────────────────────────────────────────────

    (define (paragraph-add-styled-run! para text run-style-or-false)
      "Syntax: (paragraph-add-styled-run! para text run-style-or-false)
Library: (scm ooxml word)
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
Library: (scm ooxml word)
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
Library: (scm ooxml word)
Description: Adds a tab character to para.
Example:
  (paragraph-add-tab! para)"
      (para-append-run! para (vector 'tab)))

    (define (paragraph-add-break! para)
      "Syntax: (paragraph-add-break! para)
Library: (scm ooxml word)
Description: Adds a line break (w:br) to para.
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
Library: (scm ooxml word)
Description: Embeds an image from filename into para. width-pt and height-pt
are the display dimensions in points (1 pt = 12700 EMU).
Example:
  (paragraph-add-image! para \"logo.png\" 100 50)"
      (let* ((doc     (para-doc para))
             (images  (doc-images doc))
             (img-num (+ 1 (length images)))
             ;; rId1=styles, rId2=settings, rId3=header, rId4=footer; images start rId5
             (rel-id  (string-append "rId" (number->string (+ 4 img-num))))
             (ext     (image-ext filename))
             (mime    (ext->mime ext))
             (w-emu   (* width-pt 12700))
             (h-emu   (* height-pt 12700)))
        (doc-set-images! doc
          (append images (list (list rel-id img-num ext mime filename))))
        (para-append-run! para (vector 'image rel-id w-emu h-emu))))

    ;; ── XML rendering ─────────────────────────────────────────────────────────

    (define ns-w   "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
    (define ns-r   "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
    (define ns-wp  "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing")
    (define ns-a   "http://schemas.openxmlformats.org/drawingml/2006/main")
    (define ns-pic "http://schemas.openxmlformats.org/drawingml/2006/picture")
    (define ns-pkg "http://schemas.openxmlformats.org/package/2006/relationships")

    (define ns-rel-base
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships")

    (define ct-base
      "application/vnd.openxmlformats-officedocument")

    (define (render-alignment alignment)
      (case alignment
        ((left)    "left")
        ((center)  "center")
        ((right)   "right")
        ((justify) "both")
        (else      (if (string? alignment) alignment "left"))))

    (define (render-ppr port para)
      (let ((style     (para-style para))
            (alignment (para-alignment para))
            (spacing   (para-spacing para))
            (tab-stops (para-tab-stops para))
            (indent    (para-indent para))
            (pgbrk    (para-page-break-before para)))
        (when (or style alignment spacing (not (null? tab-stops)) indent pgbrk)
          (display "<w:pPr>" port)
          (when style
            (format port "<w:pStyle w:val=\"~a\"/>" (style-id-from-name style)))
          (when pgbrk
            (display "<w:pageBreakBefore/>" port))
          (when alignment
            (format port "<w:jc w:val=\"~a\"/>" (render-alignment alignment)))
          (when spacing
            (let ((before (car spacing))
                  (after  (cadr spacing))
                  (line   (caddr spacing)))
              (if line
                  (format port "<w:spacing w:before=\"~a\" w:after=\"~a\" w:line=\"~a\" w:lineRule=\"atLeast\"/>"
                          before after line)
                  (format port "<w:spacing w:before=\"~a\" w:after=\"~a\"/>"
                          before after))))
          (when (not (null? tab-stops))
            (display "<w:tabs>" port)
            (for-each (lambda (ts)
                        (format port "<w:tab w:val=\"~a\" w:pos=\"~a\"/>"
                                (cadr ts) (car ts)))
                      tab-stops)
            (display "</w:tabs>" port))
          (when indent
            (format port "<w:ind w:left=\"~a\" w:right=\"~a\" w:firstLine=\"~a\"/>"
                    (car indent) (cadr indent) (caddr indent)))
          (display "</w:pPr>" port))))

    (define (render-rpr port rdata)
      ;; rdata is (vector font-name font-size bold italic underline color)
      (let ((fname  (vector-ref rdata 0))
            (fsize  (vector-ref rdata 1))
            (bold   (vector-ref rdata 2))
            (italic (vector-ref rdata 3))
            (ul     (vector-ref rdata 4))
            (color  (vector-ref rdata 5)))
        (when (or fname fsize bold italic ul color)
          (display "<w:rPr>" port)
          (when fname
            (format port "<w:rFonts w:ascii=\"~a\" w:hAnsi=\"~a\"/>" fname fname))
          (when fsize
            (format port "<w:sz w:val=\"~a\"/><w:szCs w:val=\"~a\"/>"
                    (* fsize 2) (* fsize 2)))
          (when bold    (display "<w:b/>" port))
          (when italic  (display "<w:i/>" port))
          (when ul      (display "<w:u w:val=\"single\"/>" port))
          (when color
            (format port "<w:color w:val=\"~a\"/>" (argb->rgb color)))
          (display "</w:rPr>" port))))

    (define (render-run port run)
      (let ((tag (vector-ref run 0)))
        (cond
          ((eq? tag 'run)
           (let* ((text  (vector-ref run 1))
                  (rs    (vector-ref run 2))
                  (rdata (if rs (rs 'get) #f))
                  (need-preserve (and (string? text)
                                      (> (string-length text) 0)
                                      (or (char=? (string-ref text 0) #\space)
                                          (char=? (string-ref text
                                                              (- (string-length text) 1))
                                                  #\space)))))
             (display "<w:r>" port)
             (when rdata (render-rpr port rdata))
             (if need-preserve
                 (format port "<w:t xml:space=\"preserve\">~a</w:t>"
                         (xml-escape text))
                 (format port "<w:t>~a</w:t>" (xml-escape text)))
             (display "</w:r>" port)))
          ((eq? tag 'tab)
           (display "<w:r><w:tab/></w:r>" port))
          ((eq? tag 'break)
           (display "<w:r><w:br/></w:r>" port))
          ((eq? tag 'image)
           (let* ((rel-id  (vector-ref run 1))
                  (w-emu   (vector-ref run 2))
                  (h-emu   (vector-ref run 3))
                  (img-id  1))   ;; drawing id (unique per document, simplified)
             (display "<w:r><w:drawing>" port)
             (display "<wp:inline xmlns:wp=\"" port)
             (display ns-wp port)
             (display "\">" port)
             (format port "<wp:extent cx=\"~a\" cy=\"~a\"/>" w-emu h-emu)
             (format port "<wp:docPr id=\"~a\" name=\"~a\"/>" img-id rel-id)
             (format port "<a:graphic xmlns:a=\"~a\">" ns-a)
             (format port "<a:graphicData uri=\"~a\">" ns-pic)
             (format port "<pic:pic xmlns:pic=\"~a\">" ns-pic)
             (display "<pic:nvPicPr>" port)
             (format port "<pic:cNvPr id=\"0\" name=\"~a\"/>" rel-id)
             (display "<pic:cNvPicPr/>" port)
             (display "</pic:nvPicPr>" port)
             (display "<pic:blipFill>" port)
             (format port "<a:blip r:embed=\"~a\" xmlns:r=\"~a\"/>" rel-id ns-r)
             (display "<a:stretch><a:fillRect/></a:stretch>" port)
             (display "</pic:blipFill>" port)
             (display "<pic:spPr>" port)
             (display "<a:xfrm><a:off x=\"0\" y=\"0\"/>" port)
             (format port "<a:ext cx=\"~a\" cy=\"~a\"/>" w-emu h-emu)
             (display "</a:xfrm>" port)
             (display "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>" port)
             (display "</pic:spPr>" port)
             (display "</pic:pic></a:graphicData></a:graphic>" port)
             (display "</wp:inline></w:drawing></w:r>" port)))
          ((eq? tag 'xe)
           (let ((term (vector-ref run 1)))
             (display "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" port)
             (format port "<w:r><w:instrText xml:space=\"preserve\"> XE \"~a\" </w:instrText></w:r>"
                     (xml-escape term))
             (display "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>" port)))
          ((eq? tag 'page-number)
           (display "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" port)
           (display "<w:r><w:instrText xml:space=\"preserve\"> PAGE </w:instrText></w:r>" port)
           (display "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>" port)))))

    ;; ── TOC / Index field rendering ─────────────────────────────────────────

    (define (render-toc-field port toc)
      (let ((title     (vector-ref toc 1))
            (max-level (vector-ref toc 2)))
        (when title
          (display "<w:p>" port)
          (display "<w:r><w:rPr><w:b/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/></w:rPr>" port)
          (format port "<w:t>~a</w:t></w:r>" (xml-escape title))
          (display "</w:p>" port))
        (display "<w:p>" port)
        (display "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" port)
        (format port "<w:r><w:instrText xml:space=\"preserve\"> TOC \\o \"1-~a\" \\h \\z </w:instrText></w:r>"
                max-level)
        (display "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>" port)
        (display "<w:r><w:t>[Update field to see Table of Contents]</w:t></w:r>" port)
        (display "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>" port)
        (display "</w:p>" port)))

    (define (render-index-field port idx)
      (let ((title (vector-ref idx 1)))
        (when title
          (display "<w:p>" port)
          (display "<w:r><w:rPr><w:b/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/></w:rPr>" port)
          (format port "<w:t>~a</w:t></w:r>" (xml-escape title))
          (display "</w:p>" port))
        (display "<w:p>" port)
        (display "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" port)
        (display "<w:r><w:instrText xml:space=\"preserve\"> INDEX \\e \" \" \\h \"A\" </w:instrText></w:r>" port)
        (display "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>" port)
        (display "<w:r><w:t>[Update field to see Index]</w:t></w:r>" port)
        (display "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>" port)
        (display "</w:p>" port)))

    (define (render-hdr-ftr-paras port paras)
      (for-each (lambda (para)
                  (display "<w:p>" port)
                  (render-ppr port para)
                  (for-each (lambda (run) (render-run port run))
                            (para-runs para))
                  (display "</w:p>" port))
                paras))

    (define (render-header-xml doc)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<w:hdr xmlns:w=\"~a\" xmlns:r=\"~a\">" ns-w ns-r)
         (render-hdr-ftr-paras port (doc-header doc))
         (display "</w:hdr>" port))))

    (define (render-footer-xml doc)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<w:ftr xmlns:w=\"~a\" xmlns:r=\"~a\">" ns-w ns-r)
         (render-hdr-ftr-paras port (doc-footer doc))
         (display "</w:ftr>" port))))

    (define (render-document doc)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<w:document xmlns:w=\"~a\" xmlns:r=\"~a\">" ns-w ns-r)
         (display "<w:body>" port)
         (for-each (lambda (elem)
                     (let ((tag (vector-ref elem 0)))
                       (cond
                         ((eq? tag 'para)
                          (display "<w:p>" port)
                          (render-ppr port elem)
                          (for-each (lambda (run) (render-run port run))
                                    (para-runs elem))
                          (display "</w:p>" port))
                         ((eq? tag 'toc)
                          (render-toc-field port elem))
                         ((eq? tag 'index)
                          (render-index-field port elem)))))
                   (doc-paragraphs doc))
         ;; Required final empty paragraph
         (display "<w:p/>" port)
         ;; Section properties (page size, header/footer references)
         (let ((ps (doc-page-size doc))
               (hdr (doc-header doc))
               (ftr (doc-footer doc)))
           (when (or ps hdr ftr)
             (display "<w:sectPr>" port)
             (when hdr
               (display "<w:headerReference w:type=\"default\" r:id=\"rId3\"/>" port))
             (when ftr
               (display "<w:footerReference w:type=\"default\" r:id=\"rId4\"/>" port))
             (when ps
               (format port "<w:pgSz w:w=\"~a\" w:h=\"~a\"/>"
                       (car ps) (cdr ps)))
             (display "</w:sectPr>" port)))
         (display "</w:body></w:document>" port))))

    (define (render-styles doc)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<w:styles xmlns:w=\"~a\">" ns-w)
         (display "<w:docDefaults><w:rPrDefault><w:rPr>" port)
         (display "<w:sz w:val=\"20\"/><w:szCs w:val=\"20\"/>" port)
         (display "</w:rPr></w:rPrDefault></w:docDefaults>" port)
         ;; Default Normal style
         (display "<w:style w:type=\"paragraph\" w:default=\"1\" w:styleId=\"Normal\">" port)
         (display "<w:name w:val=\"Normal\"/></w:style>" port)
         ;; Built-in heading styles
         (for-each
           (lambda (def)
             (let ((level (car def))
                   (size  (cadr def))
                   (sb    (caddr def))
                   (sa    (cadddr def)))
               (format port "<w:style w:type=\"paragraph\" w:styleId=\"Heading~a\">" level)
               (format port "<w:name w:val=\"Heading ~a\"/>" level)
               (display "<w:basedOn w:val=\"Normal\"/>" port)
               (format port "<w:pPr><w:outlineLvl w:val=\"~a\"/>" (- level 1))
               (format port "<w:spacing w:before=\"~a\" w:after=\"~a\"/>" sb sa)
               (display "</w:pPr>" port)
               (format port "<w:rPr><w:b/><w:sz w:val=\"~a\"/><w:szCs w:val=\"~a\"/></w:rPr>"
                       (* size 2) (* size 2))
               (display "</w:style>" port)))
           '((1 24 480 240)
             (2 18 360 160)
             (3 14 280 120)
             (4 12 240 80)
             (5 11 200 80)
             (6 10 160 80)))
         ;; Named styles
         (for-each (lambda (ns)
                     (let* ((sid      (vector-ref ns 0))
                            (sname    (vector-ref ns 1))
                            (based-on (vector-ref ns 2))
                            (ppr      (vector-ref ns 3))
                            (rpr      (vector-ref ns 4))
                            (align    (vector-ref ppr 0))
                            (sbefore  (vector-ref ppr 1))
                            (safter   (vector-ref ppr 2))
                            (sline    (vector-ref ppr 3)))
                       (format port "<w:style w:type=\"paragraph\" w:styleId=\"~a\">" sid)
                       (format port "<w:name w:val=\"~a\"/>" (xml-escape sname))
                       (when based-on
                         (format port "<w:basedOn w:val=\"~a\"/>"
                                 (style-id-from-name based-on)))
                       ;; pPr
                       (when (or align sbefore safter sline)
                         (display "<w:pPr>" port)
                         (when align
                           (format port "<w:jc w:val=\"~a\"/>" (render-alignment align)))
                         (when (or sbefore safter sline)
                           (cond
                             ((and sbefore safter sline)
                              (format port "<w:spacing w:before=\"~a\" w:after=\"~a\" w:line=\"~a\" w:lineRule=\"atLeast\"/>"
                                      sbefore safter sline))
                             ((and sbefore safter)
                              (format port "<w:spacing w:before=\"~a\" w:after=\"~a\"/>"
                                      sbefore safter))
                             (sbefore
                              (format port "<w:spacing w:before=\"~a\"/>" sbefore))
                             (safter
                              (format port "<w:spacing w:after=\"~a\"/>" safter))
                             (sline
                              (format port "<w:spacing w:line=\"~a\" w:lineRule=\"atLeast\"/>" sline))))
                         (display "</w:pPr>" port))
                       ;; rPr
                       (render-rpr port rpr)
                       (display "</w:style>" port)))
                   (doc-named-styles doc))
         (display "</w:styles>" port))))

    (define (render-rels)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<Relationships xmlns=\"~a\">" ns-pkg)
         (format port "<Relationship Id=\"rId1\" Type=\"~a/officeDocument\" Target=\"word/document.xml\"/>"
                 ns-rel-base)
         (display "</Relationships>" port))))

    (define (render-content-types doc)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">")
         (display "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" port)
         (display "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" port)
         (format port "<Override PartName=\"/word/document.xml\" ContentType=\"~a.wordprocessingml.document.main+xml\"/>"
                 ct-base)
         (format port "<Override PartName=\"/word/styles.xml\" ContentType=\"~a.wordprocessingml.styles+xml\"/>"
                 ct-base)
         (format port "<Override PartName=\"/word/settings.xml\" ContentType=\"~a.wordprocessingml.settings+xml\"/>"
                 ct-base)
         (when (doc-header doc)
           (format port "<Override PartName=\"/word/header1.xml\" ContentType=\"~a.wordprocessingml.header+xml\"/>"
                   ct-base))
         (when (doc-footer doc)
           (format port "<Override PartName=\"/word/footer1.xml\" ContentType=\"~a.wordprocessingml.footer+xml\"/>"
                   ct-base))
         (for-each (lambda (img)
                     (let ((img-num (cadr img))
                           (ext     (caddr img))
                           (mime    (list-ref img 3)))
                       (format port "<Override PartName=\"/word/media/image~a.~a\" ContentType=\"~a\"/>"
                               img-num ext mime)))
                   (doc-images doc))
         (display "</Types>" port))))

    (define (render-doc-rels doc)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<Relationships xmlns=\"~a\">" ns-pkg)
         (format port "<Relationship Id=\"rId1\" Type=\"~a/styles\" Target=\"styles.xml\"/>"
                 ns-rel-base)
         (format port "<Relationship Id=\"rId2\" Type=\"~a/settings\" Target=\"settings.xml\"/>"
                 ns-rel-base)
         (when (doc-header doc)
           (format port "<Relationship Id=\"rId3\" Type=\"~a/header\" Target=\"header1.xml\"/>"
                   ns-rel-base))
         (when (doc-footer doc)
           (format port "<Relationship Id=\"rId4\" Type=\"~a/footer\" Target=\"footer1.xml\"/>"
                   ns-rel-base))
         (for-each (lambda (img)
                     (let ((rel-id  (car img))
                           (img-num (cadr img))
                           (ext     (caddr img)))
                       (format port "<Relationship Id=\"~a\" Type=\"~a/image\" Target=\"media/image~a.~a\"/>"
                               rel-id ns-rel-base img-num ext)))
                   (doc-images doc))
         (display "</Relationships>" port))))

    (define (render-settings)
      (call-with-output-string
       (lambda (port)
         (display xml-preamble port)
         (format port "<w:settings xmlns:w=\"~a\">" ns-w)
         (display "<w:updateFields w:val=\"true\"/>" port)
         (display "</w:settings>" port))))

    ;; ── document-save ────────────────────────────────────────────────────────

    (define (document-write-zip doc zp)
      (define (add-entry name contents)
        (call-with-output-zip-entry
         zp name
         (lambda (port) (display contents port))
         0))
      (add-entry "_rels/.rels"
                 (render-rels))
      (add-entry "[Content_Types].xml"
                 (render-content-types doc))
      (add-entry "word/_rels/document.xml.rels"
                 (render-doc-rels doc))
      (add-entry "word/document.xml"
                 (render-document doc))
      (add-entry "word/settings.xml"
                 (render-settings))
      (add-entry "word/styles.xml"
                 (render-styles doc))
      ;; Write header/footer files
      (when (doc-header doc)
        (add-entry "word/header1.xml"
                   (render-header-xml doc)))
      (when (doc-footer doc)
        (add-entry "word/footer1.xml"
                   (render-footer-xml doc)))
      ;; Write image files
      (for-each (lambda (img)
                  (let* ((img-num  (cadr img))
                         (ext      (caddr img))
                         (img-path (list-ref img 4))
                         (entry    (format #f "word/media/image~a.~a"
                                           img-num ext)))
                    (let ((bin-port (zip-add-binary-entry zp entry 0)))
                      (let ((in-port (open-binary-input-file img-path)))
                        (let loop ()
                          (let ((chunk (read-bytevector 4096 in-port)))
                            (unless (eof-object? chunk)
                              (write-bytevector chunk bin-port)
                              (loop))))
                        (close-input-port in-port)))))
                (doc-images doc)))

    (define (document-save doc filename)
      "Syntax: (document-save doc filename)
Library: (scm ooxml word)
Description: Serializes doc to a DOCX file at filename. Returns 'ok.
Example:
  (let* ((doc (make-document))
         (p   (document-add-paragraph! doc)))
    (paragraph-add-run! p \"Hello, World!\")
    (document-save doc \"/tmp/out.docx\"))"
      (call-with-output-zip filename (lambda (zp) (document-write-zip doc zp)))
      'ok)

    (define (document-save-to-bytevector doc)
      "Syntax: (document-save-to-bytevector doc)
Library: (scm ooxml word)
Description: Serializes doc to a DOCX file in memory and returns the bytes as
a bytevector. Useful for generating documents for HTTP responses or in-memory
processing without writing to disk.
Example:
  (let* ((doc (make-document))
         (p   (document-add-paragraph! doc)))
    (paragraph-add-run! p \"Hello, World!\")
    (document-save-to-bytevector doc))"
      (call-with-output-zip-bytevector (lambda (zp) (document-write-zip doc zp))))

    ;; ── call-with-document ───────────────────────────────────────────────────

    (define (call-with-document filename proc)
      "Syntax: (call-with-document filename proc)
Library: (scm ooxml word)
Description: Creates a new document, calls (proc doc), then saves to filename.
Returns 'ok.
Example:
  (call-with-document \"/tmp/out.docx\"
    (lambda (doc)
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p \"Hello\"))))"
      (let ((doc (make-document)))
        (proc doc)
        (document-save doc filename)))
))

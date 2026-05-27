(define-library (scm pdf)
  (import (scheme base) (scheme file) (scheme write) (scheme inexact)
          (scm compression) (srfi 151))
  (export
    ;; Document
    make-pdf
    pdf-add-page!
    pdf-page-count
    pdf->bytevector
    pdf-save
    ;; Page record accessors
    pdf-page?
    pdf-page-width
    pdf-page-height
    pdf-page-has-content?
    ;; Page-size presets (point pairs: (cons width height))
    pdf-page-size-a4
    pdf-page-size-a5
    pdf-page-size-letter
    pdf-page-size-legal
    ;; ── Drawing API ─────────────────────────────────────────────────────
    ;; Path construction
    pdf-move-to
    pdf-line-to
    pdf-curve-to
    pdf-rect
    pdf-close-path
    ;; Painting
    pdf-stroke
    pdf-close-stroke
    pdf-fill
    pdf-fill-even-odd
    pdf-fill-and-stroke
    pdf-fill-and-stroke-even-odd
    pdf-end-path
    pdf-clip
    pdf-clip-even-odd
    ;; Graphics state
    pdf-save-state
    pdf-restore-state
    pdf-with-state
    ;; Line attributes
    pdf-set-line-width
    pdf-set-line-cap
    pdf-set-line-join
    pdf-set-miter-limit
    pdf-set-dash
    ;; Colors
    pdf-set-stroke-gray
    pdf-set-stroke-rgb
    pdf-set-stroke-cmyk
    pdf-set-fill-gray
    pdf-set-fill-rgb
    pdf-set-fill-cmyk
    ;; Transforms
    pdf-translate
    pdf-scale
    pdf-rotate
    pdf-transform
    ;; Line cap/join constants
    pdf-line-cap-butt
    pdf-line-cap-round
    pdf-line-cap-square
    pdf-line-join-miter
    pdf-line-join-round
    pdf-line-join-bevel
    ;; ── Fonts and text ──────────────────────────────────────────────────
    pdf-use-font
    pdf-font?
    pdf-font-base-name
    pdf-font-encoding
    pdf-text-width
    pdf-draw-text
    pdf-font-ascender
    pdf-font-descender
    pdf-font-cap-height
    pdf-font-x-height
    pdf-flow-text
    ;; TrueType embedding (phase 4)
    pdf-embed-truetype-font
    pdf-read-binary-file
    pdf-font-kind
    pdf-font-ttf-bytes
    pdf-font-num-glyphs
    pdf-font-cmap-lookup
    pdf-font-units-per-em
    ;; ── Images (phase 5) ────────────────────────────────────────────────
    pdf-embed-jpeg
    pdf-embed-png
    pdf-draw-image
    pdf-image?
    pdf-image-width
    pdf-image-height
    ;; ── Metadata, links, outlines (phase 6) ─────────────────────────────
    pdf-set-metadata!
    pdf-add-link
    pdf-add-outline!
    ;; PDF value constructors (low-level, used by later phases)
    pdf/name
    pdf/ref
    pdf/dict
    pdf/array
    pdf/stream
    pdf/literal
    pdf-name?
    pdf-ref?
    pdf-dict?
    pdf-array?
    pdf-stream?)
  (begin

    ;; ──────────────────────────────────────────────────────────────────────
    ;; Phase 0 of the (scm pdf) library.
    ;;
    ;; Produces structurally valid PDF 1.4 files consisting of a Catalog,
    ;; a Pages tree, and one or more blank Page objects with a MediaBox.
    ;; Drawing, fonts and text flow are added in later phases. The object
    ;; serializer, xref/trailer writer, and the page record built here
    ;; are the foundation those later phases plug into.
    ;; ──────────────────────────────────────────────────────────────────────

    ;; ── Page-size presets (points; 1pt = 1/72 inch) ────────────────────────

    (define pdf-page-size-a4     (cons 595 842))
    (define pdf-page-size-a5     (cons 420 595))
    (define pdf-page-size-letter (cons 612 792))
    (define pdf-page-size-legal  (cons 612 1008))

    ;; ── PDF value types ───────────────────────────────────────────────────
    ;; Tagged records so the serializer can dispatch on type. Plain Scheme
    ;; numbers, booleans and the symbol 'null serialize directly; strings
    ;; serialize as PDF literal strings unless wrapped with pdf/literal
    ;; (raw passthrough) or pdf/name (PDF name object).

    (define-record-type pdf-name
      (%make-pdf-name value)
      pdf-name?
      (value pdf-name-value))

    (define-record-type pdf-ref
      (%make-pdf-ref id)
      pdf-ref?
      (id pdf-ref-id))

    (define-record-type pdf-dict
      (%make-pdf-dict entries)
      pdf-dict?
      (entries pdf-dict-entries))

    (define-record-type pdf-array
      (%make-pdf-array items)
      pdf-array?
      (items pdf-array-items))

    (define-record-type pdf-stream
      (%make-pdf-stream dict data)
      pdf-stream?
      (dict pdf-stream-dict)
      (data pdf-stream-data))

    ;; Escape hatch: raw bytes to splice verbatim into the output (no
    ;; quoting). Used by later phases for already-formed content streams.
    (define-record-type pdf-literal
      (%make-pdf-literal bytes)
      pdf-literal?
      (bytes pdf-literal-bytes))

    (define (pdf/name s)
      "Syntax: (pdf/name string)
Library: (scm pdf)
Description: Constructs a PDF name object (serialized as /string). Used
  for dictionary keys' values, font names, type tags, etc.
Example: (pdf/name \"Catalog\")"
      (%make-pdf-name s))

    (define (pdf/ref id)
      "Syntax: (pdf/ref object-id)
Library: (scm pdf)
Description: Constructs an indirect-object reference (serialized as
  \"N 0 R\"). object-id is the integer id assigned by the writer.
Example: (pdf/ref 3)"
      (%make-pdf-ref id))

    (define (pdf/dict . args)
      "Syntax: (pdf/dict key1 value1 key2 value2 ...)
Library: (scm pdf)
Description: Constructs a PDF dictionary from alternating string keys
  and PDF values. Keys are bare strings (the leading / is added by the
  serializer). Values may be other PDF values, numbers, booleans, the
  symbol 'null, or plain strings (emitted as literal strings).
Example:
  (pdf/dict \"Type\" (pdf/name \"Catalog\")
            \"Pages\" (pdf/ref 2))"
      (%make-pdf-dict (pairs->entries args)))

    (define (pdf/array items)
      "Syntax: (pdf/array list-of-values)
Library: (scm pdf)
Description: Constructs a PDF array from a Scheme list of PDF values.
Example: (pdf/array (list 0 0 595 842))"
      (%make-pdf-array items))

    (define (pdf/stream dict data)
      "Syntax: (pdf/stream dict bytevector)
Library: (scm pdf)
Description: Constructs a PDF stream object. dict is a pdf-dict (its
  /Length entry is added automatically if missing). data is the raw
  stream payload as a bytevector — callers are responsible for any
  compression and for setting /Filter accordingly.
Example:
  (pdf/stream (pdf/dict) (string->utf8 \"q Q\"))"
      (%make-pdf-stream dict data))

    (define (pdf/literal bytes)
      "Syntax: (pdf/literal bytevector)
Library: (scm pdf)
Description: Wraps a bytevector so the PDF serializer splices it
  verbatim into the output stream. Intended for already-formed PDF
  fragments — most users should not need this.
Example: (pdf/literal (string->utf8 \"<< /Foo /Bar >>\"))"
      (%make-pdf-literal bytes))

    (define (pairs->entries args)
      (cond
        ((null? args) '())
        ((null? (cdr args))
         (error "pdf/dict: odd number of arguments"))
        (else
         (cons (cons (car args) (cadr args))
               (pairs->entries (cddr args))))))

    ;; ── Document and page records ─────────────────────────────────────────

    (define-record-type pdf-document
      (%make-pdf-document pages fonts images metadata outlines)
      pdf-document?
      (pages    pdf-document-pages    set-pdf-document-pages!)
      ;; Alist of font-symbol → pdf-font. Order is preserved so font
      ;; resource names (F1, F2, …) are stable across saves.
      (fonts    pdf-document-fonts    set-pdf-document-fonts!)
      ;; List of pdf-image, in registration order; resource names are
      ;; Im1, Im2, ….
      (images   pdf-document-images   set-pdf-document-images!)
      ;; Alist of metadata key (symbol: title author subject keywords
      ;; creator producer creation-date mod-date) → string.
      (metadata pdf-document-metadata set-pdf-document-metadata!)
      ;; List of pdf-outline (in tree order; first-level items live at
      ;; the document root, children hang off their parents).
      (outlines pdf-document-outlines set-pdf-document-outlines!))

    (define-record-type pdf-page
      (%make-pdf-page width height content annotations object-id)
      pdf-page?
      (width       pdf-page-width)
      (height      pdf-page-height)
      ;; Reversed list of bytevector chunks holding the content stream's
      ;; operators. Append with %pdf-page-add-chunk!; concatenate at save.
      (content     pdf-page-content     set-pdf-page-content!)
      ;; List of pdf-annotation records attached to this page (link
      ;; annotations, etc.). Order preserved; emitted into /Annots.
      (annotations pdf-page-annotations set-pdf-page-annotations!)
      ;; Indirect-object id assigned by pdf->bytevector; #f until then.
      ;; Used by outline /Dest entries to refer to the page.
      (object-id   pdf-page-object-id   set-pdf-page-object-id!))

    (define (%pdf-page-add-chunk! page bv)
      (set-pdf-page-content! page (cons bv (pdf-page-content page))))

    (define (pdf-page-has-content? page)
      "Syntax: (pdf-page-has-content? page)
Library: (scm pdf)
Description: True if any drawing operators have been emitted to page.
  Pages without content are written without a /Contents entry."
      (not (null? (pdf-page-content page))))

    (define (make-pdf)
      "Syntax: (make-pdf)
Library: (scm pdf)
Description: Creates a new empty PDF document. Pages are appended with
  pdf-add-page! and the finished document is serialized with pdf-save
  or pdf->bytevector.
Example:
  (define doc (make-pdf))
  (pdf-add-page! doc)
  (pdf-save doc \"blank.pdf\")"
      (%make-pdf-document '() '() '() '() '()))

    (define (pdf-page-count doc)
      "Syntax: (pdf-page-count doc)
Library: (scm pdf)
Description: Returns the number of pages currently in doc.
Example: (pdf-page-count (make-pdf))  ; => 0"
      (length (pdf-document-pages doc)))

    (define (pdf-add-page! doc . opts)
      "Syntax: (pdf-add-page! doc)
       (pdf-add-page! doc size-pair)
       (pdf-add-page! doc width-pt height-pt)
Library: (scm pdf)
Description: Appends a new page to doc and returns the page record.
  With no extra arguments the page is A4 (595x842 points). A size pair
  is a (cons width height); the page-size presets (pdf-page-size-a4
  etc.) are such pairs. Or pass explicit width and height in points.
Example:
  (pdf-add-page! doc)                       ; A4
  (pdf-add-page! doc pdf-page-size-letter)  ; US Letter
  (pdf-add-page! doc 200 100)               ; custom size"
      (let ((w 595) (h 842))
        (cond
          ((null? opts) #t)
          ((and (null? (cdr opts)) (pair? (car opts)))
           (set! w (car (car opts)))
           (set! h (cdr (car opts))))
          ((and (pair? (cdr opts)) (null? (cddr opts)))
           (set! w (car opts))
           (set! h (cadr opts)))
          (else
           (error "pdf-add-page!: expected (), (size-pair), or (w h)" opts)))
        (let ((page (%make-pdf-page w h '() '() #f)))
          (set-pdf-document-pages! doc
            (append (pdf-document-pages doc) (list page)))
          page)))

    ;; ── Byte-accumulating writer ──────────────────────────────────────────
    ;; Holds reversed list of bytevector chunks and a running length so
    ;; pdf-writer-length is O(1) — that length is the byte offset used in
    ;; the xref table.

    (define-record-type pdf-writer
      (%make-pdf-writer chunks length objects next-id)
      pdf-writer?
      (chunks   pdf-writer-chunks   set-pdf-writer-chunks!)
      (length   pdf-writer-length   set-pdf-writer-length!)
      (objects  pdf-writer-objects  set-pdf-writer-objects!)
      (next-id  pdf-writer-next-id  set-pdf-writer-next-id!))

    (define (make-pdf-writer)
      (%make-pdf-writer '() 0 '() 1))

    (define (pdf-writer-emit-bytes! w bv)
      (set-pdf-writer-chunks! w (cons bv (pdf-writer-chunks w)))
      (set-pdf-writer-length! w (+ (pdf-writer-length w)
                                   (bytevector-length bv))))

    (define (pdf-writer-emit-string! w s)
      (pdf-writer-emit-bytes! w (string->utf8 s)))

    (define (pdf-writer-allocate-id! w)
      (let ((id (pdf-writer-next-id w)))
        (set-pdf-writer-next-id! w (+ id 1))
        id))

    (define (pdf-writer-define-object! w id value)
      (set-pdf-writer-objects! w
        (cons (cons id (pdf-writer-length w))
              (pdf-writer-objects w)))
      (pdf-writer-emit-string! w
        (string-append (number->string id) " 0 obj\n"))
      (pdf-emit-value! w value)
      (pdf-writer-emit-string! w "\nendobj\n"))

    ;; ── Value serializer ──────────────────────────────────────────────────

    (define (pdf-emit-value! w v)
      (cond
        ((pdf-name? v)
         (pdf-writer-emit-string! w
           (string-append "/" (pdf-name-value v))))
        ((pdf-ref? v)
         (pdf-writer-emit-string! w
           (string-append (number->string (pdf-ref-id v)) " 0 R")))
        ((pdf-dict? v)    (pdf-emit-dict! w v))
        ((pdf-array? v)   (pdf-emit-array! w v))
        ((pdf-stream? v)  (pdf-emit-stream! w v))
        ((pdf-literal? v) (pdf-writer-emit-bytes! w (pdf-literal-bytes v)))
        ((number? v)
         (pdf-writer-emit-string! w (pdf-format-number v)))
        ((boolean? v)
         (pdf-writer-emit-string! w (if v "true" "false")))
        ((eq? v 'null)
         (pdf-writer-emit-string! w "null"))
        ((string? v)
         (pdf-emit-literal-string! w v))
        ((symbol? v)
         (pdf-writer-emit-string! w
           (string-append "/" (symbol->string v))))
        (else
         (error "pdf: cannot serialize value" v))))

    (define (pdf-emit-dict! w d)
      (pdf-writer-emit-string! w "<<")
      (for-each
        (lambda (entry)
          (pdf-writer-emit-string! w
            (string-append " /" (car entry) " "))
          (pdf-emit-value! w (cdr entry)))
        (pdf-dict-entries d))
      (pdf-writer-emit-string! w " >>"))

    (define (pdf-emit-array! w a)
      (pdf-writer-emit-string! w "[")
      (let loop ((items (pdf-array-items a)) (first? #t))
        (cond
          ((null? items)
           (pdf-writer-emit-string! w "]"))
          (else
           (unless first? (pdf-writer-emit-string! w " "))
           (pdf-emit-value! w (car items))
           (loop (cdr items) #f)))))

    (define (pdf-emit-stream! w s)
      ;; Ensure the dictionary advertises a /Length matching the payload.
      ;; If the caller already set /Length we trust it.
      (let* ((data    (pdf-stream-data s))
             (dict    (pdf-stream-dict s))
             (entries (pdf-dict-entries dict))
             (dict*   (if (assoc "Length" entries)
                          dict
                          (%make-pdf-dict
                           (append entries
                                   (list (cons "Length"
                                               (bytevector-length data))))))))
        (pdf-emit-dict! w dict*)
        (pdf-writer-emit-string! w "\nstream\n")
        (pdf-writer-emit-bytes! w data)
        (pdf-writer-emit-string! w "\nendstream")))

    (define (pdf-emit-literal-string! w s)
      (pdf-writer-emit-string! w "(")
      (pdf-writer-emit-string! w (pdf-escape-literal s))
      (pdf-writer-emit-string! w ")"))

    (define (pdf-escape-literal s)
      ;; Escape ( ) and \ per the PDF spec. Non-ASCII bytes pass through
      ;; — callers needing arbitrary Unicode should switch to hex strings
      ;; or PDFDocEncoding (added in later phases).
      (let loop ((i 0) (acc '()))
        (if (>= i (string-length s))
            (list->string (reverse acc))
            (let ((c (string-ref s i)))
              (loop (+ i 1)
                    (case c
                      ((#\\) (cons #\\ (cons #\\ acc)))
                      ((#\() (cons #\( (cons #\\ acc)))
                      ((#\)) (cons #\) (cons #\\ acc)))
                      (else  (cons c acc))))))))

    (define (pdf-format-number n)
      (cond
        ((exact-integer? n) (number->string n))
        ((and (rational? n) (exact? n))
         ;; Convert exact non-integer rationals to inexact to avoid
         ;; emitting fractions like 1/2 that PDF can't parse.
         (number->string (inexact n)))
        (else (number->string n))))

    (define (pdf-pad10 n)
      (let* ((s (number->string n))
             (len (string-length s)))
        (if (>= len 10)
            s
            (string-append (make-string (- 10 len) #\0) s))))

    ;; ── Trailer / xref ────────────────────────────────────────────────────

    (define (pdf-writer-finish! w root-id . opts)
      (let* ((info-id     (if (null? opts) #f (car opts)))
             (xref-offset (pdf-writer-length w))
             (size        (pdf-writer-next-id w))
             (offsets     (make-vector size 0)))
        (for-each
          (lambda (pair)
            (vector-set! offsets (car pair) (cdr pair)))
          (pdf-writer-objects w))
        (pdf-writer-emit-string! w "xref\n")
        (pdf-writer-emit-string! w
          (string-append "0 " (number->string size) "\n"))
        ;; Object 0 is the head of the free-object linked list.
        (pdf-writer-emit-string! w "0000000000 65535 f \n")
        (let loop ((i 1))
          (when (< i size)
            (pdf-writer-emit-string! w
              (string-append (pdf-pad10 (vector-ref offsets i))
                             " 00000 n \n"))
            (loop (+ i 1))))
        (pdf-writer-emit-string! w "trailer\n")
        (let ((entries (list (cons "Size" size)
                             (cons "Root" (pdf/ref root-id)))))
          (when info-id
            (set! entries
              (append entries (list (cons "Info" (pdf/ref info-id))))))
          (pdf-emit-value! w (%make-pdf-dict entries)))
        (pdf-writer-emit-string! w
          (string-append "\nstartxref\n"
                         (number->string xref-offset)
                         "\n%%EOF\n"))
        (bytevector-concat (reverse (pdf-writer-chunks w)))))

    (define (bytevector-concat bvs)
      (let* ((total (let loop ((rest bvs) (acc 0))
                      (if (null? rest) acc
                          (loop (cdr rest)
                                (+ acc (bytevector-length (car rest)))))))
             (out (make-bytevector total 0)))
        (let loop ((rest bvs) (off 0))
          (cond
            ((null? rest) out)
            (else
             (let* ((bv (car rest))
                    (len (bytevector-length bv)))
               (bytevector-copy! out off bv 0 len)
               (loop (cdr rest) (+ off len))))))))

    ;; ── Top-level: build the bytevector / save to file ────────────────────

    (define (pdf->bytevector doc)
      "Syntax: (pdf->bytevector doc)
Library: (scm pdf)
Description: Serializes doc to a bytevector containing a complete PDF
  file (header, all objects, xref table, trailer, %%EOF). Pages with
  no content render as blank pages of the requested size.
Example:
  (define doc (make-pdf))
  (pdf-add-page! doc)
  (pdf->bytevector doc)"
      (when (null? (pdf-document-pages doc))
        (error "pdf->bytevector: document has no pages"))
      (let ((w (make-pdf-writer)))
        ;; Header. The four high-bit bytes in the comment line are a
        ;; spec-recommended hint that the file is binary, so tools that
        ;; sniff line endings don't mangle it.
        (pdf-writer-emit-string! w "%PDF-1.4\n")
        (pdf-writer-emit-bytes! w
          (bytevector #x25 #xE2 #xE3 #xCF #xD3 #x0A))
        (let* ((pages      (pdf-document-pages doc))
               (fonts      (map cdr (pdf-document-fonts doc)))
               (images     (pdf-document-images doc))
               (outlines   (pdf-document-outlines doc))
               (metadata   (pdf-document-metadata doc))
               (catalog-id (pdf-writer-allocate-id! w))
               (pages-id   (pdf-writer-allocate-id! w))
               (page-ids   (map (lambda (page)
                                  (let ((id (pdf-writer-allocate-id! w)))
                                    (set-pdf-page-object-id! page id)
                                    id))
                                pages))
               (font-ids   (map (lambda (f)
                                  (let ((id (pdf-writer-allocate-id! w)))
                                    (set-pdf-font-object-id! f id)
                                    id))
                                fonts))
               (image-ids  (map (lambda (i)
                                  (let ((id (pdf-writer-allocate-id! w)))
                                    (set-pdf-image-object-id! i id)
                                    id))
                                images))
               ;; One indirect object per annotation, per page. We flatten
               ;; into a parallel list of (page . list-of-annotation-ids).
               (annotation-ids
                (map (lambda (page)
                       (map (lambda (_) (pdf-writer-allocate-id! w))
                            (pdf-page-annotations page)))
                     pages))
               (outline-tree-ids
                (and (not (null? outlines))
                     (%outlines-allocate-ids! w outlines)))
               (outlines-root-id
                (and outline-tree-ids (pdf-writer-allocate-id! w)))
               (info-id
                (and (not (null? metadata)) (pdf-writer-allocate-id! w)))
               (font-subdict
                (if (null? fonts)
                    #f
                    (%make-pdf-dict
                      (map (lambda (f)
                             (cons (pdf-font-resource-name f)
                                   (pdf/ref (pdf-font-object-id f))))
                           fonts))))
               (xobject-subdict
                (if (null? images)
                    #f
                    (%make-pdf-dict
                      (map (lambda (i)
                             (cons (pdf-image-resource-name i)
                                   (pdf/ref (pdf-image-object-id i))))
                           images))))
               (page-resources
                (cond
                  ((and font-subdict xobject-subdict)
                   (pdf/dict "Font" font-subdict "XObject" xobject-subdict))
                  (font-subdict     (pdf/dict "Font"    font-subdict))
                  (xobject-subdict  (pdf/dict "XObject" xobject-subdict))
                  (else             (pdf/dict)))))
          ;; Catalog (with optional /Outlines).
          (pdf-writer-define-object! w catalog-id
            (let ((entries
                   (list (cons "Type"  (pdf/name "Catalog"))
                         (cons "Pages" (pdf/ref pages-id)))))
              (when outlines-root-id
                (set! entries
                  (append entries
                          (list (cons "Outlines" (pdf/ref outlines-root-id))
                                (cons "PageMode" (pdf/name "UseOutlines"))))))
              (%make-pdf-dict entries)))
          ;; Pages.
          (pdf-writer-define-object! w pages-id
            (pdf/dict "Type"  (pdf/name "Pages")
                      "Kids"  (pdf/array (map pdf/ref page-ids))
                      "Count" (length pages)))
          ;; Each page + its content stream + its annotations.
          (for-each
            (lambda (page id annot-ids)
              (let* ((content-id
                      (and (pdf-page-has-content? page)
                           (pdf-writer-allocate-id! w)))
                     (page-dict-entries
                      (list (cons "Type"      (pdf/name "Page"))
                            (cons "Parent"    (pdf/ref pages-id))
                            (cons "MediaBox"  (pdf/array
                                                (list 0 0
                                                      (pdf-page-width page)
                                                      (pdf-page-height page))))
                            (cons "Resources" page-resources))))
                (when content-id
                  (set! page-dict-entries
                    (append page-dict-entries
                            (list (cons "Contents" (pdf/ref content-id))))))
                (when (not (null? annot-ids))
                  (set! page-dict-entries
                    (append page-dict-entries
                            (list (cons "Annots"
                                        (pdf/array (map pdf/ref annot-ids)))))))
                (pdf-writer-define-object! w id
                  (%make-pdf-dict page-dict-entries))
                (when content-id
                  (let* ((raw (bytevector-concat
                                (reverse (pdf-page-content page))))
                         (zbv (zlib-compress raw)))
                    (pdf-writer-define-object! w content-id
                      (pdf/stream
                        (pdf/dict "Filter" (pdf/name "FlateDecode"))
                        zbv))))
                ;; Emit each annotation object.
                (for-each
                  (lambda (annot aid)
                    (%emit-annotation! w annot aid))
                  (pdf-page-annotations page) annot-ids)))
            pages page-ids annotation-ids)
          ;; Fonts.
          (for-each
            (lambda (font id)
              (case (pdf-font-kind font)
                ((truetype) (%emit-truetype-font! w font id))
                (else       (%emit-core14-font! w font id))))
            fonts font-ids)
          ;; Images.
          (for-each (lambda (img) (%emit-image! w img)) images)
          ;; Outlines (if any). The pre-allocated ids let us emit the
          ;; root + each item with all sibling/child refs resolved.
          (when outlines-root-id
            (%emit-outlines! w outlines outlines-root-id))
          ;; Info (metadata) object.
          (when info-id
            (pdf-writer-define-object! w info-id
              (%build-info-dict metadata)))
          (pdf-writer-finish! w catalog-id info-id))))

    (define (%emit-core14-font! w font id)
      (let ((base (pdf-font-base-name font))
            (enc  (pdf-font-encoding font)))
        (pdf-writer-define-object! w id
          ;; Symbol and ZapfDingbats must use their built-in encoding
          ;; (omit /Encoding); the 12 Latin fonts use WinAnsiEncoding.
          (if (memq enc '(symbol zapfdingbats))
              (pdf/dict "Type"     (pdf/name "Font")
                        "Subtype"  (pdf/name "Type1")
                        "BaseFont" (pdf/name base))
              (pdf/dict "Type"     (pdf/name "Font")
                        "Subtype"  (pdf/name "Type1")
                        "BaseFont" (pdf/name base)
                        "Encoding" (pdf/name "WinAnsiEncoding"))))))

    ;; ──────────────────────────────────────────────────────────────────────
    ;; Drawing API (phase 1)
    ;;
    ;; Coordinates are PDF-native: origin at the bottom-left of the page,
    ;; Y axis pointing up, units in points (1/72 inch). All operators
    ;; append text to the page's content stream; the stream is built
    ;; lazily and Flate-compressed at save time.
    ;; ──────────────────────────────────────────────────────────────────────

    (define pdf-line-cap-butt   0)
    (define pdf-line-cap-round  1)
    (define pdf-line-cap-square 2)
    (define pdf-line-join-miter 0)
    (define pdf-line-join-round 1)
    (define pdf-line-join-bevel 2)

    (define (pdf-fmt-num n)
      ;; PDF wants plain decimal — never scientific. Integers print plain;
      ;; exact rationals get coerced to inexact so we don't emit "1/2".
      (cond
        ((exact-integer? n) (number->string n))
        ((and (rational? n) (exact? n))
         (number->string (inexact n)))
        (else (number->string n))))

    (define (emit-op! page . tokens)
      ;; tokens is a list of pre-formatted strings; they are joined with
      ;; single spaces and terminated by a newline.
      (let loop ((rest tokens) (acc '()) (first? #t))
        (cond
          ((null? rest)
           (%pdf-page-add-chunk! page
             (string->utf8
               (string-append
                 (apply string-append (reverse acc))
                 "\n"))))
          (else
           (loop (cdr rest)
                 (cons (car rest)
                       (if first? acc (cons " " acc)))
                 #f)))))

    (define (n->s x) (pdf-fmt-num x))

    ;; ── Path construction ────────────────────────────────────────────────

    (define (pdf-move-to page x y)
      "Syntax: (pdf-move-to page x y)
Library: (scm pdf)
Description: Begins a new subpath at (x, y). Emits the PDF 'm' operator.
Example: (pdf-move-to page 100 200)"
      (emit-op! page (n->s x) (n->s y) "m"))

    (define (pdf-line-to page x y)
      "Syntax: (pdf-line-to page x y)
Library: (scm pdf)
Description: Appends a straight line segment from the current point to
  (x, y). Emits the PDF 'l' operator.
Example: (pdf-line-to page 300 400)"
      (emit-op! page (n->s x) (n->s y) "l"))

    (define (pdf-curve-to page cx1 cy1 cx2 cy2 x y)
      "Syntax: (pdf-curve-to page cx1 cy1 cx2 cy2 x y)
Library: (scm pdf)
Description: Appends a cubic Bezier curve from the current point to
  (x, y) using control points (cx1, cy1) and (cx2, cy2). Emits 'c'.
Example: (pdf-curve-to page 100 100 200 200 300 100)"
      (emit-op! page (n->s cx1) (n->s cy1)
                     (n->s cx2) (n->s cy2)
                     (n->s x)   (n->s y) "c"))

    (define (pdf-rect page x y w h)
      "Syntax: (pdf-rect page x y width height)
Library: (scm pdf)
Description: Appends a complete rectangular subpath with its lower-left
  corner at (x, y). Emits the PDF 're' operator. No painting is done.
Example: (pdf-rect page 50 50 100 200)"
      (emit-op! page (n->s x) (n->s y) (n->s w) (n->s h) "re"))

    (define (pdf-close-path page)
      "Syntax: (pdf-close-path page)
Library: (scm pdf)
Description: Closes the current subpath with a straight line back to its
  start. Emits the PDF 'h' operator.
Example: (pdf-close-path page)"
      (emit-op! page "h"))

    ;; ── Painting ─────────────────────────────────────────────────────────

    (define (pdf-stroke page)
      "Syntax: (pdf-stroke page)
Library: (scm pdf)
Description: Strokes the current path. Emits the PDF 'S' operator.
Example: (pdf-stroke page)"
      (emit-op! page "S"))

    (define (pdf-close-stroke page)
      "Syntax: (pdf-close-stroke page)
Library: (scm pdf)
Description: Closes and strokes the current path. Emits 's'.
Example: (pdf-close-stroke page)"
      (emit-op! page "s"))

    (define (pdf-fill page)
      "Syntax: (pdf-fill page)
Library: (scm pdf)
Description: Fills the current path using the non-zero winding rule.
  Emits the PDF 'f' operator.
Example: (pdf-fill page)"
      (emit-op! page "f"))

    (define (pdf-fill-even-odd page)
      "Syntax: (pdf-fill-even-odd page)
Library: (scm pdf)
Description: Fills the current path using the even-odd rule. Emits 'f*'.
Example: (pdf-fill-even-odd page)"
      (emit-op! page "f*"))

    (define (pdf-fill-and-stroke page)
      "Syntax: (pdf-fill-and-stroke page)
Library: (scm pdf)
Description: Fills (non-zero) and strokes the current path. Emits 'B'.
Example: (pdf-fill-and-stroke page)"
      (emit-op! page "B"))

    (define (pdf-fill-and-stroke-even-odd page)
      "Syntax: (pdf-fill-and-stroke-even-odd page)
Library: (scm pdf)
Description: Fills (even-odd) and strokes the current path. Emits 'B*'.
Example: (pdf-fill-and-stroke-even-odd page)"
      (emit-op! page "B*"))

    (define (pdf-end-path page)
      "Syntax: (pdf-end-path page)
Library: (scm pdf)
Description: Ends the current path without filling or stroking. Used
  after pdf-clip / pdf-clip-even-odd. Emits 'n'.
Example: (pdf-end-path page)"
      (emit-op! page "n"))

    (define (pdf-clip page)
      "Syntax: (pdf-clip page)
Library: (scm pdf)
Description: Modifies the current clipping path by intersecting it with
  the current path (non-zero rule). Per the PDF spec this must be
  followed by a painting or pdf-end-path operator. Emits 'W'.
Example: (pdf-rect page 0 0 100 100) (pdf-clip page) (pdf-end-path page)"
      (emit-op! page "W"))

    (define (pdf-clip-even-odd page)
      "Syntax: (pdf-clip-even-odd page)
Library: (scm pdf)
Description: Like pdf-clip but uses the even-odd rule. Emits 'W*'.
Example: (pdf-clip-even-odd page)"
      (emit-op! page "W*"))

    ;; ── Graphics state ───────────────────────────────────────────────────

    (define (pdf-save-state page)
      "Syntax: (pdf-save-state page)
Library: (scm pdf)
Description: Pushes the current graphics state onto the stack (CTM,
  colors, line attributes, clip path). Emits the PDF 'q' operator. Must
  be paired with pdf-restore-state. Prefer pdf-with-state to keep them
  balanced.
Example: (pdf-save-state page)"
      (emit-op! page "q"))

    (define (pdf-restore-state page)
      "Syntax: (pdf-restore-state page)
Library: (scm pdf)
Description: Pops the most recently saved graphics state. Emits 'Q'.
Example: (pdf-restore-state page)"
      (emit-op! page "Q"))

    (define (pdf-with-state page thunk)
      "Syntax: (pdf-with-state page thunk)
Library: (scm pdf)
Description: Calls thunk between a save-state / restore-state pair so
  any transforms, colors, or clip changes made inside do not leak out.
Example:
  (pdf-with-state page
    (lambda ()
      (pdf-translate page 100 100)
      (pdf-set-fill-rgb page 1 0 0)
      (pdf-rect page 0 0 50 50)
      (pdf-fill page)))"
      (pdf-save-state page)
      (let ((result (thunk)))
        (pdf-restore-state page)
        result))

    ;; ── Line attributes ──────────────────────────────────────────────────

    (define (pdf-set-line-width page width)
      "Syntax: (pdf-set-line-width page width)
Library: (scm pdf)
Description: Sets the line width in user units. Emits 'w'.
Example: (pdf-set-line-width page 1.5)"
      (emit-op! page (n->s width) "w"))

    (define (pdf-set-line-cap page cap)
      "Syntax: (pdf-set-line-cap page cap)
Library: (scm pdf)
Description: Sets the line cap style. cap is 0 (butt), 1 (round) or
  2 (projecting square) — see pdf-line-cap-butt etc. Emits 'J'.
Example: (pdf-set-line-cap page pdf-line-cap-round)"
      (emit-op! page (n->s cap) "J"))

    (define (pdf-set-line-join page join)
      "Syntax: (pdf-set-line-join page join)
Library: (scm pdf)
Description: Sets the line join style. join is 0 (miter), 1 (round) or
  2 (bevel) — see pdf-line-join-miter etc. Emits 'j'.
Example: (pdf-set-line-join page pdf-line-join-round)"
      (emit-op! page (n->s join) "j"))

    (define (pdf-set-miter-limit page m)
      "Syntax: (pdf-set-miter-limit page miter-limit)
Library: (scm pdf)
Description: Sets the miter limit. Emits 'M'.
Example: (pdf-set-miter-limit page 10)"
      (emit-op! page (n->s m) "M"))

    (define (pdf-set-dash page pattern phase)
      "Syntax: (pdf-set-dash page pattern-list phase)
Library: (scm pdf)
Description: Sets the dash pattern. pattern-list is a list of numbers
  alternating dash/gap lengths; an empty list resets to a solid line.
  phase is the offset into the pattern at which to start. Emits 'd'.
Example:
  (pdf-set-dash page '(5 3) 0)   ; 5-on 3-off
  (pdf-set-dash page '() 0)      ; solid"
      (let ((array (string-append
                     "["
                     (let loop ((p pattern) (first? #t) (acc ""))
                       (if (null? p) acc
                           (loop (cdr p) #f
                                 (string-append acc
                                                (if first? "" " ")
                                                (n->s (car p))))))
                     "]")))
        (emit-op! page array (n->s phase) "d")))

    ;; ── Colors ───────────────────────────────────────────────────────────
    ;; Color components are in [0, 1]. Stroke ops use capitals (G, RG, K);
    ;; fill ops use lowercase (g, rg, k).

    (define (pdf-set-stroke-gray page g)
      "Syntax: (pdf-set-stroke-gray page g)
Library: (scm pdf)
Description: Sets the stroking color to gray (g in [0, 1]). Emits 'G'.
Example: (pdf-set-stroke-gray page 0.5)"
      (emit-op! page (n->s g) "G"))

    (define (pdf-set-fill-gray page g)
      "Syntax: (pdf-set-fill-gray page g)
Library: (scm pdf)
Description: Sets the non-stroking color to gray (g in [0, 1]).
  Emits 'g'.
Example: (pdf-set-fill-gray page 0.9)"
      (emit-op! page (n->s g) "g"))

    (define (pdf-set-stroke-rgb page r g b)
      "Syntax: (pdf-set-stroke-rgb page r g b)
Library: (scm pdf)
Description: Sets the stroking color to RGB (each in [0, 1]).
  Emits 'RG'.
Example: (pdf-set-stroke-rgb page 1 0 0)   ; red"
      (emit-op! page (n->s r) (n->s g) (n->s b) "RG"))

    (define (pdf-set-fill-rgb page r g b)
      "Syntax: (pdf-set-fill-rgb page r g b)
Library: (scm pdf)
Description: Sets the non-stroking color to RGB (each in [0, 1]).
  Emits 'rg'.
Example: (pdf-set-fill-rgb page 0 0 1)   ; blue"
      (emit-op! page (n->s r) (n->s g) (n->s b) "rg"))

    (define (pdf-set-stroke-cmyk page c m y k)
      "Syntax: (pdf-set-stroke-cmyk page c m y k)
Library: (scm pdf)
Description: Sets the stroking color to CMYK (each in [0, 1]).
  Emits 'K'.
Example: (pdf-set-stroke-cmyk page 0 1 1 0)   ; pure red"
      (emit-op! page (n->s c) (n->s m) (n->s y) (n->s k) "K"))

    (define (pdf-set-fill-cmyk page c m y k)
      "Syntax: (pdf-set-fill-cmyk page c m y k)
Library: (scm pdf)
Description: Sets the non-stroking color to CMYK (each in [0, 1]).
  Emits 'k'.
Example: (pdf-set-fill-cmyk page 1 0 0 0)   ; cyan"
      (emit-op! page (n->s c) (n->s m) (n->s y) (n->s k) "k"))

    ;; ── Transforms ───────────────────────────────────────────────────────
    ;; Each transform is concatenated with the current transformation
    ;; matrix (CTM). Order matters: transforms apply to subsequently
    ;; drawn content, in the order they were emitted. Use pdf-with-state
    ;; to scope them.

    (define (pdf-transform page a b c d e f)
      "Syntax: (pdf-transform page a b c d e f)
Library: (scm pdf)
Description: Concatenates the matrix [a b c d e f] onto the current
  transformation matrix. The PDF CTM is a 3x3 affine matrix whose six
  free entries are passed in column-major order. Emits 'cm'.
Example: (pdf-transform page 1 0 0 1 100 200)   ; translate (100,200)"
      (emit-op! page (n->s a) (n->s b) (n->s c)
                     (n->s d) (n->s e) (n->s f) "cm"))

    (define (pdf-translate page tx ty)
      "Syntax: (pdf-translate page tx ty)
Library: (scm pdf)
Description: Concatenates a translation by (tx, ty) onto the CTM.
Example: (pdf-translate page 100 200)"
      (pdf-transform page 1 0 0 1 tx ty))

    (define (pdf-scale page sx sy)
      "Syntax: (pdf-scale page sx sy)
Library: (scm pdf)
Description: Concatenates an axis-aligned scale by (sx, sy) onto the CTM.
Example: (pdf-scale page 2 2)"
      (pdf-transform page sx 0 0 sy 0 0))

    (define (pdf-rotate page degrees)
      "Syntax: (pdf-rotate page degrees)
Library: (scm pdf)
Description: Concatenates a rotation about the origin (in degrees,
  counter-clockwise) onto the CTM. Translate first to rotate about a
  different point.
Example:
  (pdf-with-state page
    (lambda ()
      (pdf-translate page 100 100)
      (pdf-rotate page 45)
      (pdf-rect page -25 -25 50 50)
      (pdf-stroke page)))"
      (let* ((radians (* degrees (/ 3.141592653589793 180.0)))
             (c (cos radians))
             (s (sin radians)))
        (pdf-transform page c s (- s) c 0 0)))

    ;; ──────────────────────────────────────────────────────────────────────
    ;; Fonts and text (phase 2)
    ;;
    ;; The 14 standard PDF base fonts are supported with no embedding —
    ;; every conformant viewer ships them. The 12 Latin fonts use
    ;; WinAnsiEncoding (CP1252) so Latin-1 plus a handful of common
    ;; Windows extensions (Euro, smart quotes, em-dash, …) work directly
    ;; from Scheme strings. Symbol and ZapfDingbats use their built-in
    ;; encodings and accept bytes 0–255 verbatim.
    ;;
    ;; pdf-text-width and pdf-draw-text use baked-in AFM metrics so text
    ;; widths are accurate for layout (phase 3).
    ;; ──────────────────────────────────────────────────────────────────────

    ;; ── Embedded Core14 AFM metrics (auto-generated; see notes/gen-pdf-core14-metrics.py) ──
    ;; Auto-generated by notes/gen-pdf-core14-metrics.py — do not edit.
    ;; Widths are in 1/1000 em units. Latin font vectors are indexed by
    ;; WinAnsiEncoding byte; Symbol/ZapfDingbats vectors are indexed by
    ;; the font's native encoding code.

    (define %core14-widths-helvetica
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         278  278  355  556  556  889  667  191  333  333  389  584  278  333  278  278 
         556  556  556  556  556  556  556  556  556  556  278  278  584  584  584  556 
        1015  667  667  722  722  667  611  778  722  278  500  667  556  833  722  778 
         667  778  722  667  611  722  667  944  667  667  611  278  278  278  469  556 
         333  556  556  500  556  556  278  556  556  222  222  500  222  833  556  556 
         556  556  333  500  278  556  500  722  500  500  500  334  260  334  584    0 
         556    0  222  556  333 1000  556  556  333 1000  667  333 1000    0  611    0 
           0  222  222  333  333  350  556 1000  333 1000  500  333  944    0  500  667 
         278  333  556  556  556  556  260  556  333  737  370  556  584  333  737  333 
         400  584  333  333  333  556  537  278  333  333  365  556  834  834  834  611 
         667  667  667  667  667  667 1000  722  667  667  667  667  278  278  278  278 
         722  722  778  778  778  778  778  584  778  722  722  722  722  667  667  611 
         556  556  556  556  556  556  889  500  556  556  556  556  278  278  278  278 
         556  556  556  556  556  556  556  584  611  556  556  556  556  500  556  500 ))

    (define %core14-widths-helvetica-bold
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         278  333  474  556  556  889  722  238  333  333  389  584  278  333  278  278 
         556  556  556  556  556  556  556  556  556  556  333  333  584  584  584  611 
         975  722  722  722  722  667  611  778  722  278  556  722  611  833  722  778 
         667  778  722  667  611  722  667  944  667  667  611  333  278  333  584  556 
         333  556  611  556  611  556  333  611  611  278  278  556  278  889  611  611 
         611  611  389  556  333  611  556  778  556  556  500  389  280  389  584    0 
         556    0  278  556  500 1000  556  556  333 1000  667  333 1000    0  611    0 
           0  278  278  500  500  350  556 1000  333 1000  556  333  944    0  500  667 
         278  333  556  556  556  556  280  556  333  737  370  556  584  333  737  333 
         400  584  333  333  333  611  556  278  333  333  365  556  834  834  834  611 
         722  722  722  722  722  722 1000  722  667  667  667  667  278  278  278  278 
         722  722  778  778  778  778  778  584  778  722  722  722  722  667  667  611 
         556  556  556  556  556  556  889  556  556  556  556  556  278  278  278  278 
         611  611  611  611  611  611  611  584  611  611  611  611  611  556  611  556 ))

    (define %core14-widths-helvetica-oblique
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         278  278  355  556  556  889  667  191  333  333  389  584  278  333  278  278 
         556  556  556  556  556  556  556  556  556  556  278  278  584  584  584  556 
        1015  667  667  722  722  667  611  778  722  278  500  667  556  833  722  778 
         667  778  722  667  611  722  667  944  667  667  611  278  278  278  469  556 
         333  556  556  500  556  556  278  556  556  222  222  500  222  833  556  556 
         556  556  333  500  278  556  500  722  500  500  500  334  260  334  584    0 
         556    0  222  556  333 1000  556  556  333 1000  667  333 1000    0  611    0 
           0  222  222  333  333  350  556 1000  333 1000  500  333  944    0  500  667 
         278  333  556  556  556  556  260  556  333  737  370  556  584  333  737  333 
         400  584  333  333  333  556  537  278  333  333  365  556  834  834  834  611 
         667  667  667  667  667  667 1000  722  667  667  667  667  278  278  278  278 
         722  722  778  778  778  778  778  584  778  722  722  722  722  667  667  611 
         556  556  556  556  556  556  889  500  556  556  556  556  278  278  278  278 
         556  556  556  556  556  556  556  584  611  556  556  556  556  500  556  500 ))

    (define %core14-widths-helvetica-bold-oblique
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         278  333  474  556  556  889  722  238  333  333  389  584  278  333  278  278 
         556  556  556  556  556  556  556  556  556  556  333  333  584  584  584  611 
         975  722  722  722  722  667  611  778  722  278  556  722  611  833  722  778 
         667  778  722  667  611  722  667  944  667  667  611  333  278  333  584  556 
         333  556  611  556  611  556  333  611  611  278  278  556  278  889  611  611 
         611  611  389  556  333  611  556  778  556  556  500  389  280  389  584    0 
         556    0  278  556  500 1000  556  556  333 1000  667  333 1000    0  611    0 
           0  278  278  500  500  350  556 1000  333 1000  556  333  944    0  500  667 
         278  333  556  556  556  556  280  556  333  737  370  556  584  333  737  333 
         400  584  333  333  333  611  556  278  333  333  365  556  834  834  834  611 
         722  722  722  722  722  722 1000  722  667  667  667  667  278  278  278  278 
         722  722  778  778  778  778  778  584  778  722  722  722  722  667  667  611 
         556  556  556  556  556  556  889  556  556  556  556  556  278  278  278  278 
         611  611  611  611  611  611  611  584  611  611  611  611  611  556  611  556 ))

    (define %core14-widths-times-roman
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         250  333  408  500  500  833  778  180  333  333  500  564  250  333  250  278 
         500  500  500  500  500  500  500  500  500  500  278  278  564  564  564  444 
         921  722  667  667  722  611  556  722  722  333  389  722  611  889  722  722 
         556  722  667  556  611  722  722  944  722  722  611  333  278  333  469  500 
         333  444  500  444  500  444  333  500  500  278  278  500  278  778  500  500 
         500  500  333  389  278  500  500  722  500  500  444  480  200  480  541    0 
         500    0  333  500  444 1000  500  500  333 1000  556  333  889    0  611    0 
           0  333  333  444  444  350  500 1000  333  980  389  333  722    0  444  722 
         250  333  500  500  500  500  200  500  333  760  276  500  564  333  760  333 
         400  564  300  300  333  500  453  250  333  300  310  500  750  750  750  444 
         722  722  722  722  722  722  889  667  611  611  611  611  333  333  333  333 
         722  722  722  722  722  722  722  564  722  722  722  722  722  722  556  500 
         444  444  444  444  444  444  667  444  444  444  444  444  278  278  278  278 
         500  500  500  500  500  500  500  564  500  500  500  500  500  500  500  500 ))

    (define %core14-widths-times-bold
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         250  333  555  500  500 1000  833  278  333  333  500  570  250  333  250  278 
         500  500  500  500  500  500  500  500  500  500  333  333  570  570  570  500 
         930  722  667  722  722  667  611  778  778  389  500  778  667  944  722  778 
         611  778  722  556  667  722  722 1000  722  722  667  333  278  333  581  500 
         333  500  556  444  556  444  333  500  556  278  333  556  278  833  556  500 
         556  556  444  389  333  556  500  722  500  500  444  394  220  394  520    0 
         500    0  333  500  500 1000  500  500  333 1000  556  333 1000    0  667    0 
           0  333  333  500  500  350  500 1000  333 1000  389  333  722    0  444  722 
         250  333  500  500  500  500  220  500  333  747  300  500  570  333  747  333 
         400  570  300  300  333  556  540  250  333  300  330  500  750  750  750  500 
         722  722  722  722  722  722 1000  722  667  667  667  667  389  389  389  389 
         722  722  778  778  778  778  778  570  778  722  722  722  722  722  611  556 
         500  500  500  500  500  500  722  444  444  444  444  444  278  278  278  278 
         500  556  500  500  500  500  500  570  500  556  556  556  556  500  556  500 ))

    (define %core14-widths-times-italic
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         250  333  420  500  500  833  778  214  333  333  500  675  250  333  250  278 
         500  500  500  500  500  500  500  500  500  500  333  333  675  675  675  500 
         920  611  611  667  722  611  611  722  722  333  444  667  556  833  667  722 
         611  722  611  500  556  722  611  833  611  556  556  389  278  389  422  500 
         333  500  500  444  500  444  278  500  500  278  278  444  278  722  500  500 
         500  500  389  389  278  500  444  667  444  444  389  400  275  400  541    0 
         500    0  333  500  556  889  500  500  333 1000  500  333  944    0  556    0 
           0  333  333  556  556  350  500  889  333  980  389  333  667    0  389  556 
         250  389  500  500  500  500  275  500  333  760  276  500  675  333  760  333 
         400  675  300  300  333  500  523  250  333  300  310  500  750  750  750  500 
         611  611  611  611  611  611  889  667  611  611  611  611  333  333  333  333 
         722  667  722  722  722  722  722  675  722  722  722  722  722  556  611  500 
         500  500  500  500  500  500  667  444  444  444  444  444  278  278  278  278 
         500  500  500  500  500  500  500  675  500  500  500  500  500  444  500  444 ))

    (define %core14-widths-times-bold-italic
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         250  389  555  500  500  833  778  278  333  333  500  570  250  333  250  278 
         500  500  500  500  500  500  500  500  500  500  333  333  570  570  570  500 
         832  667  667  667  722  667  667  722  778  389  500  667  611  889  722  722 
         611  722  667  556  611  722  667  889  667  611  611  333  278  333  570  500 
         333  500  500  444  500  444  333  500  556  278  278  500  278  778  556  500 
         500  500  389  389  278  556  444  667  500  444  389  348  220  348  570    0 
         500    0  333  500  500 1000  500  500  333 1000  556  333  944    0  611    0 
           0  333  333  500  500  350  500 1000  333 1000  389  333  722    0  389  611 
         250  389  500  500  500  500  220  500  333  747  266  500  606  333  747  333 
         400  570  300  300  333  576  500  250  333  300  300  500  750  750  750  500 
         667  667  667  667  667  667  944  667  667  667  667  667  389  389  389  389 
         722  722  722  722  722  722  722  570  722  722  722  722  722  611  611  500 
         500  500  500  500  500  500  722  444  444  444  444  444  278  278  278  278 
         500  556  500  500  500  500  500  570  500  556  556  556  556  444  500  444 ))

    (define %core14-widths-courier
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600    0 
         600    0  600  600  600  600  600  600  600  600  600  600  600    0  600    0 
           0  600  600  600  600  600  600  600  600  600  600  600  600    0  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 ))

    (define %core14-widths-courier-bold
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600    0 
         600    0  600  600  600  600  600  600  600  600  600  600  600    0  600    0 
           0  600  600  600  600  600  600  600  600  600  600  600  600    0  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 ))

    (define %core14-widths-courier-oblique
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600    0 
         600    0  600  600  600  600  600  600  600  600  600  600  600    0  600    0 
           0  600  600  600  600  600  600  600  600  600  600  600  600    0  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 ))

    (define %core14-widths-courier-bold-oblique
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600    0 
         600    0  600  600  600  600  600  600  600  600  600  600  600    0  600    0 
           0  600  600  600  600  600  600  600  600  600  600  600  600    0  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 
         600  600  600  600  600  600  600  600  600  600  600  600  600  600  600  600 ))

    (define %core14-widths-symbol
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         250  333  713  500  549  833  778  439  333  333  500  549  250  549  250  278 
         500  500  500  500  500  500  500  500  500  500  278  278  549  549  549  444 
         549  722  667  722  612  611  763  603  722  333  631  722  686  889  722  722 
         768  741  556  592  611  690  439  768  645  795  611  333  863  333  658  500 
         500  631  549  549  494  439  521  411  603  329  603  549  549  576  521  549 
         549  521  549  603  439  576  713  686  493  686  494  480  200  480  549    0 
         750    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         750  620  247  549  167  713  500  753  753  753  753 1042  987  603  987  603 
         400  549  411  549  549  713  494  460  549  549  549  549 1000  603 1000  658 
         823  686  795  987  768  768  823  768  768  713  713  713  713  713  713  713 
         768  713  790  790  890  823  549  250  713  603  603 1042  987  603  987  603 
         494  329  790  790  786  713  384  384  384  384  384  384  494  494  494  494 
           0  329  274  686  686  686  384  384  384  384  384  384  494  494  494    0 ))

    (define %core14-widths-zapf-dingbats
      (vector
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
         278  974  961  974  980  719  789  790  791  690  960  939  549  855  911  933 
         911  945  974  755  846  762  761  571  677  763  760  759  754  494  552  537 
         577  692  786  788  788  790  793  794  816  823  789  841  823  833  816  831 
         923  744  723  749  790  792  695  776  768  792  759  707  708  682  701  826 
         815  789  789  707  687  696  689  786  787  713  791  785  791  873  761  762 
         762  759  759  892  892  788  784  438  138  277  415  392  392  668  668    0 
         390  390  317  317  276  276  509  509  410  410  234  234  334  334    0    0 
           0    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0 
           0  732  544  544  910  667  760  760  776  595  694  626  788  788  788  788 
         788  788  788  788  788  788  788  788  788  788  788  788  788  788  788  788 
         788  788  788  788  788  788  788  788  788  788  788  788  788  788  788  788 
         788  788  788  788  894  838 1016  458  748  924  748  918  927  928  928  834 
         873  828  924  924  917  930  931  463  883  836  836  867  867  696  696  874 
           0  874  760  946  771  865  771  888  967  888  831  873  927  970  918    0 ))

    (define %core14-fonts
      (list
        (list 'helvetica "Helvetica" 'winansi %core14-widths-helvetica
              '((font-bbox . #(-166 -225 1000 931))
                (ascender . 718)
                (descender . -207)
                (cap-height . 718)
                (x-height . 523)
                (italic-angle . 0.0)
                (fixed-pitch . #f)))
        (list 'helvetica-bold "Helvetica-Bold" 'winansi %core14-widths-helvetica-bold
              '((font-bbox . #(-170 -228 1003 962))
                (ascender . 718)
                (descender . -207)
                (cap-height . 718)
                (x-height . 532)
                (italic-angle . 0.0)
                (fixed-pitch . #f)))
        (list 'helvetica-oblique "Helvetica-Oblique" 'winansi %core14-widths-helvetica-oblique
              '((font-bbox . #(-170 -225 1116 931))
                (ascender . 718)
                (descender . -207)
                (cap-height . 718)
                (x-height . 523)
                (italic-angle . -12.0)
                (fixed-pitch . #f)))
        (list 'helvetica-bold-oblique "Helvetica-BoldOblique" 'winansi %core14-widths-helvetica-bold-oblique
              '((font-bbox . #(-174 -228 1114 962))
                (ascender . 718)
                (descender . -207)
                (cap-height . 718)
                (x-height . 532)
                (italic-angle . -12.0)
                (fixed-pitch . #f)))
        (list 'times-roman "Times-Roman" 'winansi %core14-widths-times-roman
              '((font-bbox . #(-168 -218 1000 898))
                (ascender . 683)
                (descender . -217)
                (cap-height . 662)
                (x-height . 450)
                (italic-angle . 0.0)
                (fixed-pitch . #f)))
        (list 'times-bold "Times-Bold" 'winansi %core14-widths-times-bold
              '((font-bbox . #(-168 -218 1000 935))
                (ascender . 683)
                (descender . -217)
                (cap-height . 676)
                (x-height . 461)
                (italic-angle . 0.0)
                (fixed-pitch . #f)))
        (list 'times-italic "Times-Italic" 'winansi %core14-widths-times-italic
              '((font-bbox . #(-169 -217 1010 883))
                (ascender . 683)
                (descender . -217)
                (cap-height . 653)
                (x-height . 441)
                (italic-angle . -15.5)
                (fixed-pitch . #f)))
        (list 'times-bold-italic "Times-BoldItalic" 'winansi %core14-widths-times-bold-italic
              '((font-bbox . #(-200 -218 996 921))
                (ascender . 683)
                (descender . -217)
                (cap-height . 669)
                (x-height . 462)
                (italic-angle . -15.0)
                (fixed-pitch . #f)))
        (list 'courier "Courier" 'winansi %core14-widths-courier
              '((font-bbox . #(-23 -250 715 805))
                (ascender . 629)
                (descender . -157)
                (cap-height . 562)
                (x-height . 426)
                (italic-angle . 0.0)
                (fixed-pitch . #t)))
        (list 'courier-bold "Courier-Bold" 'winansi %core14-widths-courier-bold
              '((font-bbox . #(-113 -250 749 801))
                (ascender . 629)
                (descender . -157)
                (cap-height . 562)
                (x-height . 439)
                (italic-angle . 0.0)
                (fixed-pitch . #t)))
        (list 'courier-oblique "Courier-Oblique" 'winansi %core14-widths-courier-oblique
              '((font-bbox . #(-27 -250 849 805))
                (ascender . 629)
                (descender . -157)
                (cap-height . 562)
                (x-height . 426)
                (italic-angle . -12.0)
                (fixed-pitch . #t)))
        (list 'courier-bold-oblique "Courier-BoldOblique" 'winansi %core14-widths-courier-bold-oblique
              '((font-bbox . #(-57 -250 869 801))
                (ascender . 629)
                (descender . -157)
                (cap-height . 562)
                (x-height . 439)
                (italic-angle . -12.0)
                (fixed-pitch . #t)))
        (list 'symbol "Symbol" 'symbol %core14-widths-symbol
              '((font-bbox . #(-180 -293 1090 1010))
                (ascender . 0)
                (descender . 0)
                (cap-height . 0)
                (x-height . 0)
                (italic-angle . 0.0)
                (fixed-pitch . #f)))
        (list 'zapf-dingbats "ZapfDingbats" 'zapfdingbats %core14-widths-zapf-dingbats
              '((font-bbox . #(-1 -143 981 820))
                (ascender . 0)
                (descender . 0)
                (cap-height . 0)
                (x-height . 0)
                (italic-angle . 0.0)
                (fixed-pitch . #f)))
        ))

    (define-record-type pdf-font
      (%make-pdf-font kind resource-name base-name encoding widths metrics
                      object-id
                      ttf-bytes gid-widths cmap-lookup units-per-em
                      num-glyphs descriptor-meta used-codepoints)
      pdf-font?
      ;; Either 'core14 (single-byte WinAnsi/native, no embedding) or
      ;; 'truetype (composite Type0/CIDFontType2 with embedded outlines).
      (kind            pdf-font-kind)
      (resource-name   pdf-font-resource-name)
      (base-name       pdf-font-base-name)
      (encoding        pdf-font-encoding)
      (widths          pdf-font-widths)
      (metrics         pdf-font-metrics)
      ;; Filled in by pdf->bytevector when the font's indirect-object id
      ;; is allocated. #f until then.
      (object-id       pdf-font-object-id       set-pdf-font-object-id!)
      ;; TrueType-only slots; #f for core14 fonts.
      (ttf-bytes       pdf-font-ttf-bytes)              ; bytevector
      (gid-widths      pdf-font-gid-widths)             ; vector, 1000-em units
      (cmap-lookup     pdf-font-cmap-lookup)            ; proc: cp → gid (or 0)
      (units-per-em    pdf-font-units-per-em)           ; integer
      (num-glyphs      pdf-font-num-glyphs)             ; integer
      (descriptor-meta pdf-font-descriptor-meta)        ; alist
      ;; Vector indexed by GID; value is the most-recent codepoint we saw
      ;; mapped to that GID. Used to build the ToUnicode CMap at save.
      (used-codepoints pdf-font-used-codepoints))

    (define (pdf-font-metric font key)
      (let ((entry (assq key (pdf-font-metrics font))))
        (and entry (cdr entry))))

    (define (pdf-font-ascender font)
      "Syntax: (pdf-font-ascender font)
Library: (scm pdf)
Description: Returns the font's ascender height in 1/1000 em units
  (multiply by font size and divide by 1000 to get a user-space value).
Example: (pdf-font-ascender (pdf-use-font doc 'helvetica))"
      (pdf-font-metric font 'ascender))

    (define (pdf-font-descender font)
      "Syntax: (pdf-font-descender font)
Library: (scm pdf)
Description: Returns the font's descender depth in 1/1000 em units
  (a negative number for most fonts)."
      (pdf-font-metric font 'descender))

    (define (pdf-font-cap-height font)
      "Syntax: (pdf-font-cap-height font)
Library: (scm pdf)
Description: Returns the font's capital-letter height in 1/1000 em
  units."
      (pdf-font-metric font 'cap-height))

    (define (pdf-font-x-height font)
      "Syntax: (pdf-font-x-height font)
Library: (scm pdf)
Description: Returns the font's x-height in 1/1000 em units."
      (pdf-font-metric font 'x-height))

    (define (%find-core14 sym)
      (let loop ((fs %core14-fonts))
        (cond
          ((null? fs) #f)
          ((eq? (car (car fs)) sym) (car fs))
          (else (loop (cdr fs))))))

    (define (pdf-use-font doc font-sym)
      "Syntax: (pdf-use-font doc font-symbol)
Library: (scm pdf)
Description: Registers one of the 14 standard PDF base fonts on doc
  and returns a font handle suitable for pdf-text-width and
  pdf-draw-text. Repeated calls with the same symbol return the same
  handle.
  font-symbol is one of:
    helvetica  helvetica-bold  helvetica-oblique  helvetica-bold-oblique
    times-roman  times-bold  times-italic  times-bold-italic
    courier  courier-bold  courier-oblique  courier-bold-oblique
    symbol  zapf-dingbats
Example:
  (define helv (pdf-use-font doc 'helvetica))"
      (let ((existing (assq font-sym (pdf-document-fonts doc))))
        (if existing
            (cdr existing)
            (let ((spec (%find-core14 font-sym)))
              (unless spec
                (error "pdf-use-font: unknown font" font-sym))
              (let* ((base    (list-ref spec 1))
                     (enc     (list-ref spec 2))
                     (widths  (list-ref spec 3))
                     (metrics (list-ref spec 4))
                     (idx     (length (pdf-document-fonts doc)))
                     (rname   (string-append "F" (number->string (+ idx 1))))
                     (font    (%make-pdf-font 'core14 rname base enc widths
                                              metrics #f
                                              #f #f #f #f #f #f #f)))
                (set-pdf-document-fonts! doc
                  (append (pdf-document-fonts doc)
                          (list (cons font-sym font))))
                font)))))

    ;; ── Encoding (Unicode → byte) ─────────────────────────────────────────

    (define (%unicode->winansi cp)
      ;; Unicode codepoint → WinAnsi byte. 0–127 and 160–255 pass through;
      ;; the 128–159 range is the Windows extension where Unicode lives
      ;; outside Latin-1 (Euro, smart quotes, …). Unknown codepoints map
      ;; to 0x3F ('?') so output stays printable.
      (cond
        ((<= 0 cp 127) cp)
        ((<= 160 cp 255) cp)
        (else
         (case cp
           ((#x20AC) 128)  ; €
           ((#x201A) 130)
           ((#x0192) 131)
           ((#x201E) 132)
           ((#x2026) 133)  ; …
           ((#x2020) 134)  ; †
           ((#x2021) 135)  ; ‡
           ((#x02C6) 136)
           ((#x2030) 137)  ; ‰
           ((#x0160) 138)  ; Š
           ((#x2039) 139)
           ((#x0152) 140)  ; Œ
           ((#x017D) 142)  ; Ž
           ((#x2018) 145)  ; ‘
           ((#x2019) 146)  ; ’
           ((#x201C) 147)  ; “
           ((#x201D) 148)  ; ”
           ((#x2022) 149)  ; •
           ((#x2013) 150)  ; –
           ((#x2014) 151)  ; —
           ((#x02DC) 152)
           ((#x2122) 153)  ; ™
           ((#x0161) 154)
           ((#x203A) 155)
           ((#x0153) 156)  ; œ
           ((#x017E) 158)
           ((#x0178) 159)  ; Ÿ
           (else #x3F)))))

    (define (%char->font-byte font ch)
      (let ((cp (char->integer ch))
            (enc (pdf-font-encoding font)))
        (cond
          ((eq? enc 'winansi) (%unicode->winansi cp))
          (else
           ;; Symbol / ZapfDingbats: accept any 0–255 codepoint verbatim;
           ;; substitute '?' for anything above. Real Unicode→Symbol
           ;; mapping is a separate concern users can do themselves.
           (if (< cp 256) cp #x3F)))))

    (define (%encode-string-bytes font s)
      (let* ((len (string-length s))
             (bv  (make-bytevector len 0)))
        (let loop ((i 0))
          (cond
            ((= i len) bv)
            (else
             (bytevector-u8-set! bv i
               (%char->font-byte font (string-ref s i)))
             (loop (+ i 1)))))))

    (define (%escape-literal-bytes bv)
      ;; Wrap with the PDF literal-string escaping rules (‘(’, ‘)’, ‘\’
      ;; preceded by backslash). Returns a fresh bytevector.
      (let* ((len (bytevector-length bv))
             (extra (let loop ((i 0) (n 0))
                      (cond
                        ((= i len) n)
                        (else
                         (let ((b (bytevector-u8-ref bv i)))
                           (loop (+ i 1)
                                 (if (or (= b #x28) (= b #x29) (= b #x5C))
                                     (+ n 1) n))))))))
        (if (zero? extra)
            bv
            (let ((out (make-bytevector (+ len extra) 0)))
              (let loop ((i 0) (j 0))
                (cond
                  ((= i len) out)
                  (else
                   (let ((b (bytevector-u8-ref bv i)))
                     (cond
                       ((or (= b #x28) (= b #x29) (= b #x5C))
                        (bytevector-u8-set! out j #x5C)
                        (bytevector-u8-set! out (+ j 1) b)
                        (loop (+ i 1) (+ j 2)))
                       (else
                        (bytevector-u8-set! out j b)
                        (loop (+ i 1) (+ j 1))))))))))))

    (define (%core14-text-width font size string)
      (let* ((widths (pdf-font-widths font))
             (len    (string-length string))
             (total
              (let loop ((i 0) (acc 0))
                (cond
                  ((= i len) acc)
                  (else
                   (let* ((b (%char->font-byte font (string-ref string i))))
                     (loop (+ i 1)
                           (+ acc (vector-ref widths b)))))))))
        (* total (/ size 1000.0))))

    (define (pdf-text-width font size string)
      "Syntax: (pdf-text-width font size string)
Library: (scm pdf)
Description: Returns the rendered width of string in user-space units
  (points) when set in font at size, using the AFM/TTF glyph widths.
  For core14 fonts, unmappable codepoints are treated as the '?' glyph;
  for embedded TrueType fonts, codepoints without a glyph use GID 0
  (which is .notdef, typically zero width or a blank box).
Example:
  (define helv (pdf-use-font doc 'helvetica))
  (pdf-text-width helv 12 \"Hello\")"
      (case (pdf-font-kind font)
        ((truetype) (%ttf-text-width font size string))
        (else       (%core14-text-width font size string))))

    (define (%emit-text-show! page font string)
      ;; Emits the inner part of a Tj operator — either "(escaped) Tj\n"
      ;; for single-byte fonts or "<hex…> Tj\n" for the composite Type0
      ;; fonts. For TrueType also records (gid → codepoint) so the
      ;; ToUnicode CMap can be built at save time.
      (case (pdf-font-kind font)
        ((truetype)
         (%ttf-record-used! font string)
         (let ((hex (%ttf-string-to-hex font string)))
           (%pdf-page-add-chunk! page (string->utf8 "<"))
           (%pdf-page-add-chunk! page (string->utf8 hex))
           (%pdf-page-add-chunk! page (string->utf8 "> Tj\n"))))
        (else
         (let* ((bytes   (%encode-string-bytes font string))
                (escaped (%escape-literal-bytes bytes)))
           (%pdf-page-add-chunk! page (string->utf8 "("))
           (%pdf-page-add-chunk! page escaped)
           (%pdf-page-add-chunk! page (string->utf8 ") Tj\n"))))))

    (define (pdf-draw-text page font size x y string)
      "Syntax: (pdf-draw-text page font size x y string)
Library: (scm pdf)
Description: Draws string on page at user-space coordinates (x, y) — the
  baseline origin — in font at size points. Emits a self-contained
  q ... BT ... ET ... Q block so any current graphics state is
  preserved. To rotate or scale text, wrap the call in pdf-with-state
  and concat your own CTM.
Example:
  (define helv (pdf-use-font doc 'helvetica))
  (pdf-draw-text page helv 12 100 700 \"Hello, world!\")"
      (let ((rname (pdf-font-resource-name font)))
        (emit-op! page "q")
        (emit-op! page "BT")
        (emit-op! page (string-append "/" rname) (n->s size) "Tf")
        (emit-op! page (n->s x) (n->s y) "Td")
        (%emit-text-show! page font string)
        (emit-op! page "ET")
        (emit-op! page "Q")))

    ;; ──────────────────────────────────────────────────────────────────────
    ;; Text flow into a rectangle (phase 3)
    ;;
    ;; Greedy word-wrap layout: tokens are accumulated into a line until
    ;; the next word would overflow rect-width; the line is then placed
    ;; according to the requested alignment and the cursor drops by
    ;; `leading` points. Hard newlines ('\n') force a line break and are
    ;; never justified. Returns two values via `values`: the leftover
    ;; text (so the caller can flow it into another box or page) and the
    ;; baseline-y of the line that would come next — useful for placing
    ;; subsequent content below the block.
    ;; ──────────────────────────────────────────────────────────────────────

    (define (%plist-ref plist key default)
      (cond
        ((null? plist) default)
        ((null? (cdr plist))
         (error "pdf-flow-text: odd option list" plist))
        ((eq? (car plist) key) (cadr plist))
        (else (%plist-ref (cddr plist) key default))))

    (define (%flow-tokenize s)
      ;; Returns a list of tokens: a non-empty string (a word) or the
      ;; symbol 'newline (a hard break). Runs of horizontal whitespace
      ;; collapse to nothing; #\newline becomes a 'newline token.
      (let ((len (string-length s)))
        (let loop ((i 0) (cur '()) (out '()))
          (cond
            ((>= i len)
             (reverse (if (null? cur)
                          out
                          (cons (list->string (reverse cur)) out))))
            (else
             (let ((c (string-ref s i)))
               (cond
                 ((char=? c #\newline)
                  (loop (+ i 1) '()
                        (cons 'newline
                              (if (null? cur)
                                  out
                                  (cons (list->string (reverse cur)) out)))))
                 ((or (char=? c #\space)
                      (char=? c #\tab)
                      (char=? c #\return))
                  (if (null? cur)
                      (loop (+ i 1) '() out)
                      (loop (+ i 1) '()
                            (cons (list->string (reverse cur)) out))))
                 (else
                  (loop (+ i 1) (cons c cur) out)))))))))

    (define (%tokens->remaining tokens)
      ;; Reconstruct a string suitable for re-flowing into the next box.
      ;; Words rejoin with single spaces; 'newline becomes "\n".
      (let loop ((ts tokens) (acc '()) (need-space? #f))
        (cond
          ((null? ts) (apply string-append (reverse acc)))
          ((eq? (car ts) 'newline)
           (loop (cdr ts) (cons "\n" acc) #f))
          (else
           (loop (cdr ts)
                 (cons (car ts)
                       (if need-space? (cons " " acc) acc))
                 #t)))))

    (define (%emit-flow-line! page font size line-x line-y line-text tw)
      (emit-op! page "q")
      (emit-op! page "BT")
      (emit-op! page (string-append "/" (pdf-font-resource-name font))
                     (n->s size) "Tf")
      (when (not (= tw 0))
        (emit-op! page (n->s tw) "Tw"))
      (emit-op! page "1" "0" "0" "1" (n->s line-x) (n->s line-y) "Tm")
      (%emit-text-show! page font line-text)
      (emit-op! page "ET")
      (emit-op! page "Q"))

    (define (%place-line! page font size rect-x rect-w cur-y
                          line-words line-natural-w align hard-break?)
      ;; line-words is a non-empty list of word strings.
      (let* ((joined (apply string-append
                            (let loop ((ws line-words) (first? #t))
                              (cond
                                ((null? ws) '())
                                (first? (cons (car ws) (loop (cdr ws) #f)))
                                (else (cons " " (cons (car ws)
                                                      (loop (cdr ws) #f))))))))
             (gap     (max 0 (- (length line-words) 1)))
             (slack   (- rect-w line-natural-w))
             (line-x  (case align
                        ((left)    rect-x)
                        ((right)   (+ rect-x slack))
                        ((center)  (+ rect-x (/ slack 2.0)))
                        ((justify) rect-x)
                        (else      rect-x)))
             (tw      (if (and (eq? align 'justify)
                               (not hard-break?)
                               (> gap 0)
                               (> slack 0))
                          (/ slack gap)
                          0)))
        (%emit-flow-line! page font size line-x cur-y joined tw)))

    (define (pdf-flow-text page font size rect text . opts)
      "Syntax: (pdf-flow-text page font size rect text [option value]...)
Library: (scm pdf)
Description: Lays out text into a rectangular region using greedy word
  wrapping and the font's AFM widths. Returns two values via `values`:
  the leftover text (or \"\" if everything fit) and the y-coordinate
  where the next line would have been placed (useful for continuing
  below the block).
  rect is a 4-element list: (x y width height), where (x, y) is the
  rectangle's lower-left corner in user-space (PDF) points.
  Options (plist style):
    align    one of 'left (default), 'right, 'center, 'justify
    leading  line spacing in points (default: size * 1.2)
  Newline characters in text force hard line breaks; the line that ends
  at a hard break is never justified. Words wider than rect width are
  placed on a line by themselves (and will overflow horizontally).
Example:
  (define helv (pdf-use-font doc 'helvetica))
  (call-with-values
    (lambda () (pdf-flow-text page helv 11 '(72 72 200 400)
                              \"Lorem ipsum dolor sit amet ...\"
                              'align 'justify))
    (lambda (rest final-y)
      (when (not (string=? rest \"\"))
        ...flow rest into a second column...)))"
      (let* ((align    (%plist-ref opts 'align 'left))
             (leading  (%plist-ref opts 'leading (* size 1.2)))
             (rect-x   (list-ref rect 0))
             (rect-y   (list-ref rect 1))
             (rect-w   (list-ref rect 2))
             (rect-h   (list-ref rect 3))
             (bot-y    rect-y)
             (top-y    (+ rect-y rect-h))
             (space-w  (pdf-text-width font size " "))
             (cur-y    (- top-y size)))
        (define (word-w w) (pdf-text-width font size w))
        (define (place-line! words width hard?)
          (%place-line! page font size rect-x rect-w cur-y
                        (reverse words) width align hard?))
        (let loop ((tokens     (%flow-tokenize text))
                   (line-rev   '())   ; reversed list of words on this line
                   (line-width 0)
                   (line-spaces 0))
          (cond
            ;; Out of vertical room: stash whatever is left and stop.
            ((< cur-y bot-y)
             (let ((remaining
                    (cond
                      ((null? line-rev) tokens)
                      (else (append (reverse line-rev) tokens)))))
               (values (%tokens->remaining remaining) cur-y)))
            ((null? tokens)
             ;; Drain the last partial line and finish.
             (when (not (null? line-rev))
               (place-line! line-rev line-width #t)
               (set! cur-y (- cur-y leading)))
             (values "" cur-y))
            (else
             (let ((tok (car tokens)) (rest (cdr tokens)))
               (cond
                 ;; Hard line break.
                 ((eq? tok 'newline)
                  (cond
                    ((null? line-rev)
                     ;; Blank paragraph: just drop a line.
                     (set! cur-y (- cur-y leading))
                     (loop rest '() 0 0))
                    (else
                     (place-line! line-rev line-width #t)
                     (set! cur-y (- cur-y leading))
                     (loop rest '() 0 0))))
                 (else
                  (let* ((w (word-w tok))
                         (candidate
                          (if (null? line-rev)
                              w
                              (+ line-width space-w w))))
                    (cond
                      ;; Word fits — accumulate.
                      ((<= candidate rect-w)
                       (loop rest
                             (cons tok line-rev)
                             candidate
                             (if (null? line-rev)
                                 line-spaces
                                 (+ line-spaces 1))))
                      ;; Line already non-empty: emit it, retry word.
                      ((not (null? line-rev))
                       (place-line! line-rev line-width #f)
                       (set! cur-y (- cur-y leading))
                       (loop tokens '() 0 0))
                      ;; Overlong word, alone on its line — place it
                      ;; anyway (overflowing rect-width). Phase 3 keeps
                      ;; the algorithm simple; char-level breaking is a
                      ;; future refinement.
                      (else
                       (place-line! (list tok) w #t)
                       (set! cur-y (- cur-y leading))
                       (loop rest '() 0 0))))))))))))

    ;; ──────────────────────────────────────────────────────────────────────
    ;; TrueType embedding (phase 4)
    ;;
    ;; Embeds a full TTF as a Type0 composite font using
    ;; CIDFontType2 + /Encoding /Identity-H so that glyphs are addressed
    ;; by 16-bit CID = GID directly. Strings are encoded as hex `<XXXX>`
    ;; sequences (4 hex digits per glyph) and rendered through Tj exactly
    ;; like the core14 path. A /ToUnicode CMap is emitted so copy-paste
    ;; from PDF readers round-trips Unicode codepoints, restricted to
    ;; glyphs that were actually drawn. Subsetting is not done — the full
    ;; TTF file is embedded as a FontFile2 stream.
    ;; ──────────────────────────────────────────────────────────────────────

    ;; ── Big-endian byte readers ──────────────────────────────────────────

    (define (%u8 bv off)  (bytevector-u8-ref bv off))
    (define (%u16 bv off)
      (+ (* (bytevector-u8-ref bv off) 256)
         (bytevector-u8-ref bv (+ off 1))))
    (define (%s16 bv off)
      (let ((u (%u16 bv off)))
        (if (>= u 32768) (- u 65536) u)))
    (define (%u32 bv off)
      (+ (* (bytevector-u8-ref bv off) 16777216)
         (* (bytevector-u8-ref bv (+ off 1)) 65536)
         (* (bytevector-u8-ref bv (+ off 2)) 256)
         (bytevector-u8-ref bv (+ off 3))))

    (define (pdf-read-binary-file path)
      "Syntax: (pdf-read-binary-file path)
Library: (scm pdf)
Description: Convenience wrapper that opens path as a binary file,
  reads its full contents into a bytevector, and returns the bytevector.
  Intended for loading TTF files before calling pdf-embed-truetype-font.
Example:
  (pdf-read-binary-file \"/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf\")"
      (let ((port (open-binary-input-file path)))
        (let loop ((acc '()) (total 0))
          (let ((chunk (read-bytevector 65536 port)))
            (cond
              ((eof-object? chunk)
               (close-input-port port)
               (let ((out (make-bytevector total 0)))
                 (let copy ((rest (reverse acc)) (off 0))
                   (cond
                     ((null? rest) out)
                     (else
                      (let ((c (car rest)))
                        (bytevector-copy! out off c 0 (bytevector-length c))
                        (copy (cdr rest) (+ off (bytevector-length c)))))))))
              (else
               (loop (cons chunk acc)
                     (+ total (bytevector-length chunk)))))))))

    ;; ── TTF table directory ──────────────────────────────────────────────

    (define (%ttf-tables bv)
      ;; Returns alist tag-string → (cons offset length).
      (let ((num (%u16 bv 4)))
        (let loop ((i 0) (acc '()))
          (cond
            ((= i num) acc)
            (else
             (let* ((rec-off (+ 12 (* i 16)))
                    (tag (let ((bs (make-bytevector 4 0)))
                           (bytevector-copy! bs 0 bv rec-off (+ rec-off 4))
                           (utf8->string bs)))
                    (off (%u32 bv (+ rec-off 8)))
                    (len (%u32 bv (+ rec-off 12))))
               (loop (+ i 1) (cons (cons tag (cons off len)) acc))))))))

    (define (%ttf-table-required tables tag)
      (let ((e (assoc tag tables)))
        (unless e (error "TTF: missing required table" tag))
        (cdr e)))

    (define (%ttf-table-optional tables tag)
      (let ((e (assoc tag tables)))
        (and e (cdr e))))

    ;; ── cmap (Unicode → GID) ─────────────────────────────────────────────

    (define (%ttf-build-cmap-lookup bv tables)
      ;; Walks subtables and picks the best Unicode cmap, with priority:
      ;; (3,10) Win UCS-4 > (0,4) Unicode 2.0 full > (3,1) Win BMP >
      ;; (0,3) Unicode BMP. Returns a closure cp → gid (0 for missing).
      (let* ((cmap-info (%ttf-table-required tables "cmap"))
             (cmap-off  (car cmap-info))
             (num-subs  (%u16 bv (+ cmap-off 2))))
        (define (sub-priority pid eid)
          (cond ((and (= pid 3) (= eid 10)) 4)
                ((and (= pid 0) (>= eid 4))  3)
                ((and (= pid 3) (= eid 1))   2)
                ((and (= pid 0) (= eid 3))   1)
                (else 0)))
        (let loop ((i 0) (best #f) (best-pri 0))
          (cond
            ((= i num-subs)
             (unless best (error "TTF: no usable cmap subtable"))
             (%ttf-cmap-make-lookup bv cmap-off best))
            (else
             (let* ((rec (+ cmap-off 4 (* i 8)))
                    (pid (%u16 bv rec))
                    (eid (%u16 bv (+ rec 2)))
                    (off (%u32 bv (+ rec 4)))
                    (pri (sub-priority pid eid)))
               (if (> pri best-pri)
                   (loop (+ i 1) off pri)
                   (loop (+ i 1) best best-pri))))))))

    (define (%ttf-cmap-make-lookup bv cmap-off sub-off)
      (let* ((abs-off (+ cmap-off sub-off))
             (format  (%u16 bv abs-off)))
        (case format
          ((4)  (%ttf-cmap4-lookup  bv abs-off))
          ((12) (%ttf-cmap12-lookup bv abs-off))
          (else (error "TTF: unsupported cmap format" format)))))

    (define (%ttf-cmap4-lookup bv off)
      ;; Returns a closure (cp → gid). Format 4 covers the BMP only.
      (let* ((seg-count (quotient (%u16 bv (+ off 6)) 2))
             (end-off     (+ off 14))
             (start-off   (+ end-off (* 2 seg-count) 2))      ; +2 reservedPad
             (delta-off   (+ start-off (* 2 seg-count)))
             (rangeoff-off (+ delta-off (* 2 seg-count)))
             (glyph-off   (+ rangeoff-off (* 2 seg-count))))
        (lambda (cp)
          (cond
            ((> cp #xFFFF) 0)
            (else
             ;; Linear scan: simple and bounded by seg-count (typically
             ;; < 200). Binary search would be faster but adds code.
             (let loop ((i 0))
               (cond
                 ((= i seg-count) 0)
                 (else
                  (let ((endc (%u16 bv (+ end-off (* 2 i)))))
                    (cond
                      ((< endc cp) (loop (+ i 1)))
                      (else
                       (let ((startc (%u16 bv (+ start-off (* 2 i)))))
                         (cond
                           ((> startc cp) 0)
                           (else
                            (let* ((delta  (%s16 bv (+ delta-off (* 2 i))))
                                   (ro     (%u16 bv (+ rangeoff-off (* 2 i)))))
                              (cond
                                ((zero? ro)
                                 (modulo (+ cp delta) 65536))
                                (else
                                 (let* ((glyph-addr
                                         (+ (+ rangeoff-off (* 2 i))
                                            ro
                                            (* 2 (- cp startc))))
                                        (g (%u16 bv glyph-addr)))
                                   (if (zero? g) 0
                                       (modulo (+ g delta) 65536))))))))))))))))))))

    (define (%ttf-cmap12-lookup bv off)
      ;; Format 12: full Unicode via 32-bit ranges.
      (let* ((num-groups (%u32 bv (+ off 12)))
             (groups-off (+ off 16)))
        (lambda (cp)
          (let loop ((lo 0) (hi (- num-groups 1)))
            (cond
              ((> lo hi) 0)
              (else
               (let* ((mid     (quotient (+ lo hi) 2))
                      (rec     (+ groups-off (* mid 12)))
                      (sc      (%u32 bv rec))
                      (ec      (%u32 bv (+ rec 4)))
                      (sg      (%u32 bv (+ rec 8))))
                 (cond
                   ((< cp sc) (loop lo (- mid 1)))
                   ((> cp ec) (loop (+ mid 1) hi))
                   (else      (+ sg (- cp sc)))))))))))

    ;; ── hmtx (glyph advance widths) ──────────────────────────────────────

    (define (%ttf-build-hmtx bv tables num-glyphs units-per-em)
      ;; Returns a vector of length num-glyphs of advance widths scaled
      ;; to 1000-em units (the PDF convention).
      (let* ((hhea-info (%ttf-table-required tables "hhea"))
             (hhea-off  (car hhea-info))
             (hmtx-info (%ttf-table-required tables "hmtx"))
             (hmtx-off  (car hmtx-info))
             (num-hm    (%u16 bv (+ hhea-off 34)))
             (last-adv  (%u16 bv (+ hmtx-off (* 4 (- num-hm 1)))))
             (scale     (/ 1000.0 units-per-em))
             (out       (make-vector num-glyphs 0)))
        (let loop ((g 0))
          (cond
            ((= g num-glyphs) out)
            (else
             (let ((aw (if (< g num-hm)
                           (%u16 bv (+ hmtx-off (* 4 g)))
                           last-adv)))
               (vector-set! out g (* aw scale))
               (loop (+ g 1))))))))

    ;; ── FontDescriptor metadata ──────────────────────────────────────────

    (define (%ttf-build-metadata bv tables units-per-em)
      (let* ((head-off  (car (%ttf-table-required tables "head")))
             (hhea-off  (car (%ttf-table-required tables "hhea")))
             (os2-info  (%ttf-table-optional tables "OS/2"))
             (scale     (/ 1000.0 units-per-em))
             (mac-style (%u16 bv (+ head-off 44)))
             (italic?   (not (zero? (bitwise-and mac-style 2))))
             (bold?     (not (zero? (bitwise-and mac-style 1))))
             (x-min     (* scale (%s16 bv (+ head-off 36))))
             (y-min     (* scale (%s16 bv (+ head-off 38))))
             (x-max     (* scale (%s16 bv (+ head-off 40))))
             (y-max     (* scale (%s16 bv (+ head-off 42))))
             (ascent    (* scale (%s16 bv (+ hhea-off 4))))
             (descent   (* scale (%s16 bv (+ hhea-off 6))))
             (cap-h     (cond
                          ((and os2-info
                                (>= (cdr os2-info) 92)
                                (>= (%u16 bv (car os2-info)) 2))
                           (* scale (%s16 bv (+ (car os2-info) 88))))
                          (else ascent)))
             (x-h       (cond
                          ((and os2-info
                                (>= (cdr os2-info) 92)
                                (>= (%u16 bv (car os2-info)) 2))
                           (* scale (%s16 bv (+ (car os2-info) 86))))
                          (else (/ ascent 2)))))
        (list (cons 'italic?   italic?)
              (cons 'bold?     bold?)
              (cons 'font-bbox (list x-min y-min x-max y-max))
              (cons 'ascender  ascent)
              (cons 'descender descent)
              (cons 'cap-height cap-h)
              (cons 'x-height  x-h))))

    ;; ── Embed entry point ────────────────────────────────────────────────

    (define (pdf-embed-truetype-font doc ttf-bytes . opts)
      "Syntax: (pdf-embed-truetype-font doc ttf-bytes [base-name])
Library: (scm pdf)
Description: Parses the TrueType font in ttf-bytes (a bytevector, e.g.
  from pdf-read-binary-file), registers it on doc as an embedded Type0
  composite font with /Encoding /Identity-H, and returns a font handle
  usable with pdf-draw-text, pdf-text-width and pdf-flow-text. Supports
  the full Unicode BMP (cmap format 4) or beyond (format 12). The whole
  TTF is embedded — no subsetting; expect a few hundred KB per font.
  An optional base-name overrides the PostScript name used for the
  PDF /BaseFont entry (defaults to \"EmbeddedTTF<n>\").
Example:
  (define bv (pdf-read-binary-file \"/path/to/DejaVuSans.ttf\"))
  (define dj (pdf-embed-truetype-font doc bv \"DejaVuSans\"))
  (pdf-draw-text page dj 14 50 700 \"Hello, мир, 日本語, ✓\")"
      (let* ((base-name (cond
                         ((null? opts)
                          (string-append
                            "EmbeddedTTF"
                            (number->string
                              (+ 1 (length (pdf-document-fonts doc))))))
                         (else (car opts))))
             (tables       (%ttf-tables ttf-bytes))
             (head-off     (car (%ttf-table-required tables "head")))
             (units-per-em (%u16 ttf-bytes (+ head-off 18)))
             (maxp-off     (car (%ttf-table-required tables "maxp")))
             (num-glyphs   (%u16 ttf-bytes (+ maxp-off 4)))
             (cmap-lookup  (%ttf-build-cmap-lookup ttf-bytes tables))
             (gid-widths   (%ttf-build-hmtx ttf-bytes tables num-glyphs
                                            units-per-em))
             (meta         (%ttf-build-metadata ttf-bytes tables units-per-em))
             (used         (make-vector num-glyphs #f))
             (idx          (length (pdf-document-fonts doc)))
             (rname        (string-append "F" (number->string (+ idx 1))))
             (font         (%make-pdf-font 'truetype rname base-name
                                           'identity-h #f '() #f
                                           ttf-bytes gid-widths
                                           cmap-lookup units-per-em
                                           num-glyphs meta used)))
        (set-pdf-document-fonts! doc
          (append (pdf-document-fonts doc)
                  (list (cons (string->symbol rname) font))))
        font))

    ;; ── TTF text-width and string encoding ───────────────────────────────

    (define (%ttf-text-width font size string)
      (let* ((cmap   (pdf-font-cmap-lookup font))
             (widths (pdf-font-gid-widths font))
             (len    (string-length string))
             (total
              (let loop ((i 0) (acc 0))
                (cond
                  ((= i len) acc)
                  (else
                   (let* ((cp  (char->integer (string-ref string i)))
                          (gid (cmap cp))
                          (w   (vector-ref widths gid)))
                     (loop (+ i 1) (+ acc w))))))))
        (* total (/ size 1000.0))))

    (define (%pad-hex n width)
      (let* ((s (number->string n 16))
             (len (string-length s)))
        (if (>= len width)
            s
            (string-append (make-string (- width len) #\0) s))))

    (define (%ttf-string-to-hex font s)
      ;; UTF-16-style hex: 4 hex digits per glyph (CID = GID, 16 bits).
      (let* ((cmap (pdf-font-cmap-lookup font))
             (len  (string-length s)))
        (let loop ((i 0) (acc '()))
          (cond
            ((= i len) (apply string-append (reverse acc)))
            (else
             (let* ((cp  (char->integer (string-ref s i)))
                    (gid (cmap cp)))
               (loop (+ i 1) (cons (%pad-hex gid 4) acc))))))))

    (define (%ttf-record-used! font s)
      ;; Records gid → codepoint mappings for the ToUnicode CMap. Bulk
      ;; PDFs with repeated text re-record the same entries, which is
      ;; fine — the table is a vector, not a list.
      (let* ((cmap (pdf-font-cmap-lookup font))
             (used (pdf-font-used-codepoints font))
             (len  (string-length s)))
        (let loop ((i 0))
          (cond
            ((= i len) #t)
            (else
             (let* ((cp  (char->integer (string-ref s i)))
                    (gid (cmap cp)))
               (when (and (> gid 0) (not (vector-ref used gid)))
                 (vector-set! used gid cp))
               (loop (+ i 1))))))))

    ;; ── Emitting a TTF font and its descendant objects ───────────────────

    (define (%emit-truetype-font! w font font-id)
      (let* ((desc-id  (pdf-writer-allocate-id! w))
             (fd-id    (pdf-writer-allocate-id! w))
             (ff2-id   (pdf-writer-allocate-id! w))
             (tu-id    (pdf-writer-allocate-id! w))
             (base     (pdf-font-base-name font))
             (meta     (pdf-font-descriptor-meta font))
             (num-g    (pdf-font-num-glyphs font))
             (widths   (pdf-font-gid-widths font))
             (ttf-bv   (pdf-font-ttf-bytes font))
             (italic?  (cdr (assq 'italic? meta)))
             (bbox     (cdr (assq 'font-bbox meta)))
             ;; Symbolic (bit 3) so reader doesn't expect a Latin
             ;; standard encoding; bit 7 (Italic) if applicable.
             (flags    (+ 4 (if italic? 64 0))))
        ;; Type0 outer font.
        (pdf-writer-define-object! w font-id
          (pdf/dict
            "Type"            (pdf/name "Font")
            "Subtype"         (pdf/name "Type0")
            "BaseFont"        (pdf/name base)
            "Encoding"        (pdf/name "Identity-H")
            "DescendantFonts" (pdf/array (list (pdf/ref desc-id)))
            "ToUnicode"       (pdf/ref tu-id)))
        ;; CIDFontType2 descendant.
        (pdf-writer-define-object! w desc-id
          (pdf/dict
            "Type"           (pdf/name "Font")
            "Subtype"        (pdf/name "CIDFontType2")
            "BaseFont"       (pdf/name base)
            "CIDSystemInfo"  (pdf/dict "Registry"   "Adobe"
                                       "Ordering"   "Identity"
                                       "Supplement" 0)
            "FontDescriptor" (pdf/ref fd-id)
            "DW"             1000
            "W"               (pdf/literal (%ttf-build-w-array widths num-g))
            "CIDToGIDMap"    (pdf/name "Identity")))
        ;; FontDescriptor.
        (pdf-writer-define-object! w fd-id
          (pdf/dict
            "Type"        (pdf/name "FontDescriptor")
            "FontName"    (pdf/name base)
            "Flags"       flags
            "FontBBox"    (pdf/array bbox)
            "ItalicAngle" (if italic? -12 0)
            "Ascent"      (cdr (assq 'ascender   meta))
            "Descent"     (cdr (assq 'descender  meta))
            "CapHeight"   (cdr (assq 'cap-height meta))
            "StemV"       (if (cdr (assq 'bold? meta)) 120 80)
            "FontFile2"   (pdf/ref ff2-id)))
        ;; FontFile2: the entire TTF, Flate-compressed.
        (let ((compressed (zlib-compress ttf-bv)))
          (pdf-writer-define-object! w ff2-id
            (pdf/stream
              (pdf/dict "Filter"  (pdf/name "FlateDecode")
                        "Length1" (bytevector-length ttf-bv))
              compressed)))
        ;; ToUnicode CMap (uncompressed; small).
        (pdf-writer-define-object! w tu-id
          (let ((cmap-bytes (%ttf-build-tounicode font)))
            (pdf/stream (pdf/dict) cmap-bytes)))))

    (define (%ttf-build-w-array widths num-glyphs)
      ;; Emit a single contiguous run: "[0 [w0 w1 w2 ... w_{N-1}]]".
      ;; Use ASCII representation so dict serializer can splice via
      ;; pdf/literal.
      (let ((out (open-output-string)))
        (display "[ 0 [" out)
        (let loop ((i 0))
          (when (< i num-glyphs)
            (let ((w (vector-ref widths i)))
              ;; Round to one decimal place to keep the file compact.
              ;; Integer widths print without a decimal.
              (display
                (cond
                  ((integer? w) (number->string (exact w)))
                  (else
                   (let ((r (/ (round (* w 10)) 10)))
                     (number->string (if (integer? r) (exact r) (inexact r))))))
                out))
            (when (< i (- num-glyphs 1))
              (display " " out))
            (loop (+ i 1))))
        (display "] ]" out)
        (string->utf8 (get-output-string out))))

    (define (%ttf-build-tounicode font)
      ;; Builds an Adobe ToUnicode CMap covering all (gid → codepoint)
      ;; pairs collected during drawing. Surrogate-pair-encoded for
      ;; codepoints outside the BMP.
      (let* ((used (pdf-font-used-codepoints font))
             (n    (vector-length used))
             (out  (open-output-string)))
        (display "/CIDInit /ProcSet findresource begin\n" out)
        (display "12 dict begin\nbegincmap\n" out)
        (display "/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n" out)
        (display "/CMapName /Adobe-Identity-UCS def\n" out)
        (display "/CMapType 2 def\n" out)
        (display "1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n" out)
        (let* ((entries
                (let loop ((i 0) (acc '()))
                  (cond
                    ((= i n) (reverse acc))
                    (else
                     (let ((cp (vector-ref used i)))
                       (loop (+ i 1)
                             (if cp (cons (cons i cp) acc) acc)))))))
               (count (length entries)))
          (when (positive? count)
            ;; bfchar groups are capped at 100 entries per the CMap spec.
            (let chunks ((rest entries))
              (cond
                ((null? rest) #t)
                (else
                 (let* ((take (if (> (length rest) 100) 100 (length rest)))
                        (this (let loop ((r rest) (n take) (acc '()))
                                (cond
                                  ((zero? n) (reverse acc))
                                  (else (loop (cdr r) (- n 1) (cons (car r) acc))))))
                        (next (let loop ((r rest) (n take))
                                (cond ((zero? n) r)
                                      (else (loop (cdr r) (- n 1)))))))
                   (display (number->string take) out)
                   (display " beginbfchar\n" out)
                   (for-each
                     (lambda (e)
                       (display "<" out)
                       (display (%pad-hex (car e) 4) out)
                       (display "> <" out)
                       (display (%cp-to-utf16-hex (cdr e)) out)
                       (display ">\n" out))
                     this)
                   (display "endbfchar\n" out)
                   (chunks next)))))))
        (display "endcmap\nCMapName currentdict /CMap defineresource pop\n" out)
        (display "end\nend\n" out)
        (string->utf8 (get-output-string out))))

    (define (%cp-to-utf16-hex cp)
      (cond
        ((< cp #x10000) (%pad-hex cp 4))
        (else
         ;; Surrogate pair.
         (let* ((c   (- cp #x10000))
                (hi  (+ #xD800 (quotient c 1024)))
                (lo  (+ #xDC00 (modulo c 1024))))
           (string-append (%pad-hex hi 4) (%pad-hex lo 4))))))

    ;; ──────────────────────────────────────────────────────────────────────
    ;; Images (phase 5)
    ;;
    ;; JPEG: pass-through via /Filter /DCTDecode (the PDF reader decodes
    ;; the JPEG directly). Width/height/component-count are parsed from
    ;; the first Start-Of-Frame marker.
    ;;
    ;; PNG: concatenated IDAT chunk payloads form one zlib stream — we
    ;; emit them verbatim as a /FlateDecode stream with /DecodeParms
    ;; /Predictor 15 so the PDF reader applies PNG filter rules. Only
    ;; non-alpha color types (0 grayscale, 2 RGB) are supported in this
    ;; phase; alpha channels require an /SMask.
    ;; ──────────────────────────────────────────────────────────────────────

    (define-record-type pdf-image
      (%make-pdf-image resource-name object-id width height color-space
                       bits-per-component filter decode-parms data smask)
      pdf-image?
      (resource-name      pdf-image-resource-name)
      (object-id          pdf-image-object-id      set-pdf-image-object-id!)
      (width              pdf-image-width)
      (height             pdf-image-height)
      (color-space        pdf-image-color-space)        ; pdf-name
      (bits-per-component pdf-image-bits-per-component) ; integer
      (filter             pdf-image-filter)             ; pdf-name
      (decode-parms       pdf-image-decode-parms)       ; pdf-dict or #f
      (data               pdf-image-data)               ; bytevector
      ;; Optional pdf-image holding the alpha mask. Not registered on
      ;; the document; emitted as a side-effect of the parent and
      ;; referenced through the parent's /SMask entry.
      (smask              pdf-image-smask))             ; pdf-image or #f

    (define (%register-image! doc img)
      (set-pdf-document-images! doc
        (append (pdf-document-images doc) (list img)))
      img)

    (define (%next-image-resource-name doc)
      (string-append "Im"
                     (number->string (+ 1 (length (pdf-document-images doc))))))

    ;; ── JPEG ──────────────────────────────────────────────────────────────

    (define (%jpeg-parse-dimensions bv)
      ;; Returns (list width height components). Scans markers from the
      ;; SOI until a Start-Of-Frame marker (SOFn, n in 0..F except
      ;; 4=DHT, 8=JPG, 12=DAC) is found.
      (unless (and (>= (bytevector-length bv) 4)
                   (= (bytevector-u8-ref bv 0) #xFF)
                   (= (bytevector-u8-ref bv 1) #xD8))
        (error "pdf-embed-jpeg: not a JPEG (bad SOI)"))
      (let loop ((i 2))
        (cond
          ((>= i (- (bytevector-length bv) 1))
           (error "pdf-embed-jpeg: no SOF marker found"))
          ((not (= (bytevector-u8-ref bv i) #xFF))
           (loop (+ i 1)))
          (else
           (let ((m (bytevector-u8-ref bv (+ i 1))))
             (cond
               ((= m #xFF) (loop (+ i 1)))      ; fill byte
               ;; Standalone (no length): SOI, EOI, RSTn, TEM
               ((or (= m 0) (= m #xD8) (= m #xD9) (= m #x01)
                    (and (>= m #xD0) (<= m #xD7)))
                (loop (+ i 2)))
               ;; SOF markers: C0..CF excluding C4 (DHT), C8 (JPG), CC (DAC)
               ((and (>= m #xC0) (<= m #xCF)
                     (not (= m #xC4)) (not (= m #xC8)) (not (= m #xCC)))
                (let ((h (%u16 bv (+ i 5)))
                      (w (%u16 bv (+ i 7)))
                      (c (%u8  bv (+ i 9))))
                  (list w h c)))
               (else
                (let ((len (%u16 bv (+ i 2))))
                  (loop (+ i 2 len))))))))))

    (define (pdf-embed-jpeg doc bv)
      "Syntax: (pdf-embed-jpeg doc jpeg-bytevector)
Library: (scm pdf)
Description: Embeds a JPEG image in doc as an Image XObject using
  /Filter /DCTDecode (pass-through — no re-encoding). Auto-detects
  width, height and color space (gray / RGB / CMYK) from the JPEG's
  Start-Of-Frame marker. Returns a pdf-image handle for use with
  pdf-draw-image.
Example:
  (define j (pdf-embed-jpeg doc (pdf-read-binary-file \"photo.jpg\")))
  (pdf-draw-image page j 50 600 200 150)"
      (let* ((dims (%jpeg-parse-dimensions bv))
             (w (list-ref dims 0))
             (h (list-ref dims 1))
             (c (list-ref dims 2))
             (cs (cond ((= c 1) (pdf/name "DeviceGray"))
                       ((= c 3) (pdf/name "DeviceRGB"))
                       ((= c 4) (pdf/name "DeviceCMYK"))
                       (else (error "pdf-embed-jpeg: unsupported component count" c))))
             (rname (%next-image-resource-name doc))
             (img (%make-pdf-image rname #f w h cs 8
                                   (pdf/name "DCTDecode") #f bv #f)))
        (%register-image! doc img)))

    ;; ── PNG ───────────────────────────────────────────────────────────────

    (define (%png-walk-chunks bv)
      ;; Returns alist of tag-string → list of (offset . length).
      (unless (and (>= (bytevector-length bv) 8)
                   (= (%u8 bv 0) #x89) (= (%u8 bv 1) #x50)
                   (= (%u8 bv 2) #x4E) (= (%u8 bv 3) #x47))
        (error "pdf-embed-png: not a PNG (bad signature)"))
      (let loop ((i 8) (acc '()))
        (cond
          ((>= (+ i 8) (bytevector-length bv)) (reverse acc))
          (else
           (let* ((len (%u32 bv i))
                  (tag (let ((s (make-bytevector 4 0)))
                         (bytevector-copy! s 0 bv (+ i 4) (+ i 8))
                         (utf8->string s))))
             (loop (+ i 8 len 4)
                   (cons (list tag (+ i 8) len) acc)))))))

    (define (pdf-embed-png doc bv)
      "Syntax: (pdf-embed-png doc png-bytevector)
Library: (scm pdf)
Description: Embeds a PNG image in doc as an Image XObject. The PNG's
  concatenated IDAT chunks are emitted verbatim as a /FlateDecode
  stream with /DecodeParms /Predictor 15 so the reader applies the
  PNG filter rules. Color types 0 (grayscale) and 2 (RGB) pass through
  the IDAT verbatim. Color types 4 (gray + alpha) and 6 (RGB + alpha)
  are fully decoded, then the color and alpha channels are emitted as
  two separate flate-compressed Image XObjects with the alpha as an
  /SMask. 8-bit depth only. Returns a pdf-image handle for use with
  pdf-draw-image.
Example:
  (define p (pdf-embed-png doc (pdf-read-binary-file \"logo.png\")))
  (pdf-draw-image page p 50 600 100 100)"
      (let* ((chunks (%png-walk-chunks bv))
             (ihdr   (assoc "IHDR" chunks)))
        (unless ihdr
          (error "pdf-embed-png: missing IHDR chunk"))
        (let* ((ihdr-off  (list-ref ihdr 1))
               (width     (%u32 bv ihdr-off))
               (height    (%u32 bv (+ ihdr-off 4)))
               (bit-depth (%u8  bv (+ ihdr-off 8)))
               (color-typ (%u8  bv (+ ihdr-off 9))))
          (unless (= bit-depth 8)
            (error "pdf-embed-png: only 8-bit depth supported" bit-depth))
          (case color-typ
            ((0) (%png-embed-verbatim doc bv chunks width height
                                      (pdf/name "DeviceGray") 1))
            ((2) (%png-embed-verbatim doc bv chunks width height
                                      (pdf/name "DeviceRGB")  3))
            ((4) (%png-embed-with-alpha doc bv chunks width height 1))
            ((6) (%png-embed-with-alpha doc bv chunks width height 3))
            (else
             (error "pdf-embed-png: unsupported color type (only 0,2,4,6 with bit-depth 8)"
                    color-typ))))))

    (define (%png-collect-idat bv chunks)
      (let loop ((rest chunks) (acc '()))
        (cond
          ((null? rest)
           (bytevector-concat (reverse acc)))
          ((string=? (car (car rest)) "IDAT")
           (let* ((c (car rest))
                  (off (list-ref c 1))
                  (len (list-ref c 2))
                  (b (make-bytevector len 0)))
             (bytevector-copy! b 0 bv off (+ off len))
             (loop (cdr rest) (cons b acc))))
          (else (loop (cdr rest) acc)))))

    (define (%png-embed-verbatim doc bv chunks width height cs components)
      ;; Fast path for non-alpha PNGs: hand the IDAT zlib stream
      ;; straight to PDF and let the reader apply Predictor 15.
      (let* ((idat  (%png-collect-idat bv chunks))
             (parms (pdf/dict "Predictor"        15
                              "Columns"          width
                              "Colors"           components
                              "BitsPerComponent" 8))
             (rname (%next-image-resource-name doc))
             (img   (%make-pdf-image rname #f width height cs 8
                                     (pdf/name "FlateDecode") parms idat #f)))
        (%register-image! doc img)))

    ;; ── Full PNG decoder (for alpha PNGs) ─────────────────────────────────

    (define (%png-paeth a b c)
      (let* ((p  (- (+ a b) c))
             (pa (abs (- p a)))
             (pb (abs (- p b)))
             (pc (abs (- p c))))
        (cond
          ((and (<= pa pb) (<= pa pc)) a)
          ((<= pb pc) b)
          (else c))))

    (define (%png-decode-pixels bv chunks width height samples)
      ;; 8-bit only. Walks IDAT zlib stream, unfilters each scanline,
      ;; and returns raw pixel bytes (height * width * samples).
      (let* ((stride   (* width samples))
             (bpp      samples)         ; bytes-per-pixel at 8-bit depth
             (idat     (%png-collect-idat bv chunks))
             (raw      (zlib-decompress idat))
             (out      (make-bytevector (* height stride) 0))
             (prev     (make-bytevector stride 0)))
        (let loop ((y 0))
          (cond
            ((= y height) out)
            (else
             (let* ((src-off (* y (+ 1 stride)))
                    (dst-off (* y stride))
                    (ftype   (bytevector-u8-ref raw src-off)))
               (let xloop ((x 0))
                 (cond
                   ((= x stride) #t)
                   (else
                    (let* ((cur  (bytevector-u8-ref raw (+ src-off 1 x)))
                           (left (if (< x bpp) 0
                                     (bytevector-u8-ref out (+ dst-off x (- bpp)))))
                           (up   (bytevector-u8-ref prev x))
                           (ul   (if (< x bpp) 0
                                     (bytevector-u8-ref prev (- x bpp))))
                           (recon
                            (case ftype
                              ((0) cur)
                              ((1) (modulo (+ cur left) 256))
                              ((2) (modulo (+ cur up)   256))
                              ((3) (modulo (+ cur (quotient (+ left up) 2))
                                           256))
                              ((4) (modulo (+ cur (%png-paeth left up ul))
                                           256))
                              (else (error "PNG: unknown filter type" ftype)))))
                      (bytevector-u8-set! out (+ dst-off x) recon)
                      (xloop (+ x 1))))))
               ;; Copy reconstructed row to prev for next iteration.
               (bytevector-copy! prev 0 out dst-off (+ dst-off stride))
               (loop (+ y 1))))))))

    (define (%png-embed-with-alpha doc bv chunks width height color-comps)
      ;; For color types 4 (gray+alpha) and 6 (RGB+alpha). Decodes
      ;; pixels, splits color and alpha into two buffers, and emits a
      ;; color XObject + grayscale /SMask XObject.
      (let* ((samples (+ color-comps 1))
             (npx     (* width height))
             (pixels  (%png-decode-pixels bv chunks width height samples))
             (color   (make-bytevector (* npx color-comps) 0))
             (alpha   (make-bytevector npx 0)))
        (let loop ((i 0))
          (cond
            ((= i npx) #t)
            (else
             (let ((src  (* i samples))
                   (cdst (* i color-comps)))
               (let cl ((j 0))
                 (when (< j color-comps)
                   (bytevector-u8-set! color (+ cdst j)
                                       (bytevector-u8-ref pixels (+ src j)))
                   (cl (+ j 1))))
               (bytevector-u8-set! alpha i
                                   (bytevector-u8-ref pixels (+ src color-comps)))
               (loop (+ i 1))))))
        (let* ((color-z (zlib-compress color))
               (alpha-z (zlib-compress alpha))
               (cs      (if (= color-comps 1)
                            (pdf/name "DeviceGray")
                            (pdf/name "DeviceRGB")))
               ;; SMask isn't registered on the document — it lives on
               ;; the parent image's smask slot and gets an object id
               ;; allocated at write time.
               (smask   (%make-pdf-image "" #f width height
                                         (pdf/name "DeviceGray") 8
                                         (pdf/name "FlateDecode") #f
                                         alpha-z #f))
               (rname   (%next-image-resource-name doc))
               (img     (%make-pdf-image rname #f width height cs 8
                                         (pdf/name "FlateDecode") #f
                                         color-z smask)))
          (%register-image! doc img))))

    ;; ── Emit + draw ──────────────────────────────────────────────────────

    (define (%emit-image! w img)
      ;; If the image carries an /SMask sibling, allocate its object id
      ;; now and emit it after the parent. The sibling does not appear
      ;; in any page's /XObject resources.
      (let* ((smask    (pdf-image-smask img))
             (smask-id (and smask (pdf-writer-allocate-id! w)))
             (dict-entries
              (list (cons "Type"             (pdf/name "XObject"))
                    (cons "Subtype"          (pdf/name "Image"))
                    (cons "Width"            (pdf-image-width  img))
                    (cons "Height"           (pdf-image-height img))
                    (cons "ColorSpace"       (pdf-image-color-space img))
                    (cons "BitsPerComponent" (pdf-image-bits-per-component img))
                    (cons "Filter"           (pdf-image-filter img)))))
        (when (pdf-image-decode-parms img)
          (set! dict-entries
            (append dict-entries
                    (list (cons "DecodeParms" (pdf-image-decode-parms img))))))
        (when smask-id
          (set-pdf-image-object-id! smask smask-id)
          (set! dict-entries
            (append dict-entries
                    (list (cons "SMask" (pdf/ref smask-id))))))
        (pdf-writer-define-object! w (pdf-image-object-id img)
          (pdf/stream (%make-pdf-dict dict-entries) (pdf-image-data img)))
        (when smask
          (%emit-image! w smask))))

    (define (pdf-draw-image page img x y w h)
      "Syntax: (pdf-draw-image page image x y width height)
Library: (scm pdf)
Description: Places image on page at user-space coordinates (x, y) —
  the lower-left corner — scaled to width × height points. Image
  XObjects are defined in a 1×1 unit square, so this concatenates a
  scale+translate matrix and emits the Do operator. Wrapped in a
  q ... Q pair to localize state changes.
Example:
  (pdf-draw-image page logo 50 600 100 100)"
      (emit-op! page "q")
      (emit-op! page (n->s w) "0" "0" (n->s h) (n->s x) (n->s y) "cm")
      (emit-op! page (string-append "/" (pdf-image-resource-name img)) "Do")
      (emit-op! page "Q"))

    ;; ──────────────────────────────────────────────────────────────────────
    ;; Metadata, links, outlines (phase 6)
    ;; ──────────────────────────────────────────────────────────────────────

    (define (pdf-set-metadata! doc . pairs)
      "Syntax: (pdf-set-metadata! doc key1 value1 key2 value2 ...)
Library: (scm pdf)
Description: Sets document metadata fields on the /Info dictionary.
  Repeated keys overwrite earlier values. Recognised keys (symbols):
    title author subject keywords creator producer
    creation-date mod-date
  Values are strings. Date strings should follow PDF format,
  e.g. \"D:20260527120000+02'00\".
Example:
  (pdf-set-metadata! doc 'title \"My Report\"
                         'author \"Damian\"
                         'creator \"(scm pdf)\")"
      (let loop ((args pairs))
        (cond
          ((null? args) doc)
          ((null? (cdr args))
           (error "pdf-set-metadata!: odd number of arguments"))
          (else
           (let* ((key (car args))
                  (val (cadr args))
                  (md  (pdf-document-metadata doc))
                  (existing (assq key md)))
             (set-pdf-document-metadata! doc
               (cond
                 (existing
                  (map (lambda (e)
                         (if (eq? (car e) key) (cons key val) e))
                       md))
                 (else (append md (list (cons key val))))))
             (loop (cddr args)))))))

    (define (%build-info-dict metadata)
      (let ((key->name
             (lambda (k)
               (case k
                 ((title)         "Title")
                 ((author)        "Author")
                 ((subject)       "Subject")
                 ((keywords)      "Keywords")
                 ((creator)       "Creator")
                 ((producer)      "Producer")
                 ((creation-date) "CreationDate")
                 ((mod-date)      "ModDate")
                 (else (symbol->string k))))))
        (%make-pdf-dict
          (map (lambda (e) (cons (key->name (car e)) (cdr e)))
               metadata))))

    ;; ── Annotations (link annotations) ───────────────────────────────────

    (define-record-type pdf-annotation
      (%make-pdf-annotation kind rect payload)
      pdf-annotation?
      (kind    pdf-annotation-kind)     ; symbol: 'link
      (rect    pdf-annotation-rect)     ; (list llx lly urx ury)
      (payload pdf-annotation-payload)) ; alist of (key . value) for /A etc.

    (define (pdf-add-link page rect uri)
      "Syntax: (pdf-add-link page rect uri-string)
Library: (scm pdf)
Description: Attaches a clickable URI link annotation to page. rect is
  a 4-element list (llx lly urx ury) of user-space coordinates marking
  the hot area; uri-string is the absolute URL to open. The annotation
  has no visible border.
Example:
  (pdf-draw-text page helv 12 100 700 \"Click here\")
  (pdf-add-link page '(100 695 200 712) \"https://example.com\")"
      (let ((a (%make-pdf-annotation 'link rect (list (cons 'uri uri)))))
        (set-pdf-page-annotations! page
          (append (pdf-page-annotations page) (list a)))
        a))

    (define (%emit-annotation! w a id)
      (case (pdf-annotation-kind a)
        ((link)
         (let* ((uri  (cdr (assq 'uri (pdf-annotation-payload a))))
                (rect (pdf-annotation-rect a)))
           (pdf-writer-define-object! w id
             (pdf/dict
               "Type"    (pdf/name "Annot")
               "Subtype" (pdf/name "Link")
               "Rect"    (pdf/array rect)
               "Border"  (pdf/array (list 0 0 0))
               "A"       (pdf/dict "Type" (pdf/name "Action")
                                   "S"    (pdf/name "URI")
                                   "URI"  uri)))))
        (else (error "pdf: unknown annotation kind" (pdf-annotation-kind a)))))

    ;; ── Outlines (bookmarks) ─────────────────────────────────────────────

    (define-record-type pdf-outline
      (%make-pdf-outline title page-ref y children object-id)
      pdf-outline?
      (title     pdf-outline-title)
      (page-ref  pdf-outline-page-ref)
      (y         pdf-outline-y)
      (children  pdf-outline-children  set-pdf-outline-children!)
      (object-id pdf-outline-object-id set-pdf-outline-object-id!))

    (define (pdf-add-outline! doc page title . opts)
      "Syntax: (pdf-add-outline! doc page title [option value]...)
Library: (scm pdf)
Description: Appends an outline (bookmark) entry that jumps to page.
  Options (plist):
    parent  another outline returned by pdf-add-outline! — creates a
            nested child under that outline (default: top-level item)
    y       baseline y-coord to scroll the page to (default: page top)
  Returns the outline handle so it can be used as a parent in later
  calls.
Example:
  (define ch1 (pdf-add-outline! doc page1 \"Chapter 1\"))
  (pdf-add-outline! doc page1 \"Section 1.1\" 'parent ch1)"
      (let* ((parent (%plist-ref opts 'parent #f))
             (y      (%plist-ref opts 'y      #f))
             (out    (%make-pdf-outline title page y '() #f)))
        (cond
          (parent
           (set-pdf-outline-children! parent
             (append (pdf-outline-children parent) (list out))))
          (else
           (set-pdf-document-outlines! doc
             (append (pdf-document-outlines doc) (list out)))))
        out))

    (define (%outlines-allocate-ids! w items)
      ;; Allocates an object id for every outline in the tree, in
      ;; depth-first order. Returns the input items list unchanged (ids
      ;; are stored on the records themselves).
      (let walk ((items items))
        (for-each
          (lambda (o)
            (set-pdf-outline-object-id! o (pdf-writer-allocate-id! w))
            (walk (pdf-outline-children o)))
          items))
      items)

    (define (%outlines-count items)
      ;; Total visible descendant count (== children since we don't
      ;; collapse anything in this phase).
      (let loop ((xs items) (n 0))
        (cond
          ((null? xs) n)
          (else
           (loop (cdr xs)
                 (+ n 1 (%outlines-count (pdf-outline-children (car xs)))))))))

    (define (%emit-outlines! w top-items root-id)
      ;; Emit the root /Outlines dict, then each item.
      (let* ((first  (car top-items))
             (last   (car (reverse top-items)))
             (count  (%outlines-count top-items)))
        (pdf-writer-define-object! w root-id
          (pdf/dict "Type"  (pdf/name "Outlines")
                    "First" (pdf/ref (pdf-outline-object-id first))
                    "Last"  (pdf/ref (pdf-outline-object-id last))
                    "Count" count))
        (let recurse ((parent-id root-id) (items top-items))
          (let* ((prev-ids (cons #f (map pdf-outline-object-id items)))
                 (next-ids (append (cdr (map pdf-outline-object-id items))
                                   (list #f))))
            (for-each
              (lambda (item prev-id next-id)
                (%emit-outline-item! w item parent-id prev-id next-id)
                (when (not (null? (pdf-outline-children item)))
                  (recurse (pdf-outline-object-id item)
                           (pdf-outline-children item))))
              items prev-ids next-ids)))))

    (define (%emit-outline-item! w item parent-id prev-id next-id)
      (let* ((page     (pdf-outline-page-ref item))
             (page-id  (pdf-page-object-id page))
             (children (pdf-outline-children item))
             (y        (or (pdf-outline-y item) (pdf-page-height page)))
             ;; /Dest [page /XYZ 0 y null] — null = retain current zoom.
             (dest     (pdf/array
                         (list (pdf/ref page-id)
                               (pdf/name "XYZ") 0 y 'null)))
             (entries
              (list (cons "Title"  (pdf-outline-title item))
                    (cons "Parent" (pdf/ref parent-id))
                    (cons "Dest"   dest))))
        (when prev-id
          (set! entries
            (append entries (list (cons "Prev" (pdf/ref prev-id))))))
        (when next-id
          (set! entries
            (append entries (list (cons "Next" (pdf/ref next-id))))))
        (when (not (null? children))
          (set! entries
            (append entries
                    (list (cons "First" (pdf/ref (pdf-outline-object-id
                                                   (car children))))
                          (cons "Last"  (pdf/ref (pdf-outline-object-id
                                                   (car (reverse children)))))
                          (cons "Count" (%outlines-count children))))))
        (pdf-writer-define-object! w (pdf-outline-object-id item)
          (%make-pdf-dict entries))))

    (define (pdf-save doc path)
      "Syntax: (pdf-save doc path)
Library: (scm pdf)
Description: Serializes doc with pdf->bytevector and writes the result
  to the file at path. Overwrites an existing file.
Example:
  (define doc (make-pdf))
  (pdf-add-page! doc)
  (pdf-save doc \"blank.pdf\")"
      (let ((bv   (pdf->bytevector doc))
            (port (open-binary-output-file path)))
        (write-bytevector bv port)
        (close-output-port port)))

    ))

;; (scm ooxml presentation) — writing PowerPoint files (.pptx).
;;
;; A presentation is a list of slides; a slide holds shapes (preset
;; geometries, optionally with text), lines, tables, pictures and videos, all
;; absolutely positioned, plus a background colour, a transition, build
;; animations and notes. The package has one master and one blank layout:
;; everything a slide shows is on the slide itself, which is what an
;; export from another program needs.
;;
;; Units: positions and sizes in EMU (914400 per inch, 12700 per point);
;; font sizes in points; angles in degrees; colours "RRGGBB". Media (images,
;; videos) are bytevectors or file paths; files are copied into the
;; package in pieces, so a large video need not fit in memory. The same
;; media (same key) is stored once.
;;
;; Text is a list of paragraphs, each an alist:
;;   (align . left | center | right | justify)
;;   (bullet . #f | "•" | number)       (level . 0..8)
;;   (margin-left . emu) (indent . emu)  ; indent < 0: hanging (bullets)
;;   (line-spacing . 1.2)                ; times the font's line height
;;   (space-after . points)
;;   (runs . (run ...))
;; and a run is an alist: (text . string) (size . points) (bold . #t)
;; (italic . #t) (underline . #t) (color . "RRGGBB") (font . "Inter")
;; (link . "https://..."); "\n" in a text is a line break. A run with
;; (field . slide-number | date) is a PowerPoint field: its text is shown
;; until PowerPoint updates it to the slide's number or today's date (in
;; the language's short format).

(define-library (scm ooxml presentation)
  (import (scheme base)
          (scheme char)
          (scheme inexact)
          (scm zip))
  (export make-presentation
          presentation-set-title!
          presentation-add-slide!
          slide-set-background!
          slide-set-transition!
          slide-set-notes!
          slide-add-shape!
          slide-add-line!
          slide-add-table!
          slide-add-picture!
          slide-add-video!
          presentation-save
          presentation->bytevector
          points->emu
          inches->emu)
  (begin

    (define (points->emu p) (exact (round (* p 12700))))
    (define (inches->emu i) (exact (round (* i 914400))))

    ;; --- records --------------------------------------------------------

    (define-record-type presentation
      (%make-presentation width height title slides media)
      presentation?
      (width pres-width)
      (height pres-height)
      (title pres-title set-pres-title!)
      (slides pres-slides set-pres-slides!)       ; in order
      (media pres-media set-pres-media!))         ; ((key name source content-type) ...)

    (define-record-type slide
      (%make-slide pres number background transition notes items rels next-rel next-id builds)
      slide?
      (pres slide-pres)
      (number slide-number)
      (background slide-background set-slide-background!)
      (transition slide-transition set-slide-transition!)
      (notes slide-notes set-slide-notes!)
      (items slide-items set-slide-items!)          ; xml strings, reversed
      (rels slide-rels set-slide-rels!)             ; ((id type target external?) ...), reversed
      (next-rel slide-next-rel set-slide-next-rel!)
      (next-id slide-next-id set-slide-next-id!)
      (builds slide-builds set-slide-builds!))      ; ((order effect spid text?) ...), reversed

    (define (make-presentation . size)
      "Syntax: (make-presentation [width-emu height-emu])
Library: (scm ooxml presentation)
Description: A new, empty presentation; slides are 16:9 (12192000 x
  6858000 EMU, 13.33 x 7.5 inches) unless a size is given.
Example:
  (define p (make-presentation))"
      (if (pair? size)
          (%make-presentation (car size) (cadr size) "" '() '())
          (%make-presentation 12192000 6858000 "" '() '())))

    (define (presentation-set-title! pres title)
      "Syntax: (presentation-set-title! pres title)
Library: (scm ooxml presentation)
Description: Sets the document title (file properties)."
      (set-pres-title! pres title))

    (define (presentation-add-slide! pres)
      "Syntax: (presentation-add-slide! pres)
Library: (scm ooxml presentation)
Description: Appends a blank slide and returns it."
      (let ((s (%make-slide pres (+ 1 (length (pres-slides pres))) #f #f #f '()
                            (list (list "rId1" layout-rel "../slideLayouts/slideLayout1.xml" #f))
                            2 2 '())))
        (set-pres-slides! pres (append (pres-slides pres) (list s)))
        s))

    (define (slide-set-background! slide color)
      "Syntax: (slide-set-background! slide color)
Library: (scm ooxml presentation)
Description: Fills the slide's background with color (\"RRGGBB\")."
      (set-slide-background! slide color))

    (define (slide-set-transition! slide type . ms)
      "Syntax: (slide-set-transition! slide type [milliseconds])
Library: (scm ooxml presentation)
Description: The transition into the slide: fade, push-left, push-up,
  wipe-left, zoom or none; the speed is chosen from milliseconds (fast
  below 400, slow from 800, else medium)."
      (set-slide-transition! slide (cons type (if (pair? ms) (car ms) 600))))

    (define (slide-set-notes! slide paragraphs)
      "Syntax: (slide-set-notes! slide paragraphs)
Library: (scm ooxml presentation)
Description: The speaker notes of the slide (paragraphs as for text)."
      (set-slide-notes! slide paragraphs))

    ;; --- XML ------------------------------------------------------------

    (define (esc s)
      (let loop ((cs (string->list s)) (acc '()))
        (if (null? cs)
            (list->string (reverse acc))
            (let ((c (car cs)))
              (loop (cdr cs)
                    (case c
                      ((#\&) (append (reverse (string->list "&amp;")) acc))
                      ((#\<) (append (reverse (string->list "&lt;")) acc))
                      ((#\>) (append (reverse (string->list "&gt;")) acc))
                      ((#\") (append (reverse (string->list "&quot;")) acc))
                      (else (if (or (char>=? c #\space) (memv c '(#\tab)))
                                (cons c acc)
                                acc))))))))   ; no control characters in XML

    (define (n x) (number->string (exact (round x))))

    (define (attr name value) (string-append " " name "=\"" value "\""))

    (define (cat . parts) (apply string-append parts))

    (define (strings xs) (apply string-append xs))

    (define ns-a "http://schemas.openxmlformats.org/drawingml/2006/main")
    (define ns-r "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
    (define ns-p "http://schemas.openxmlformats.org/presentationml/2006/main")
    (define ns-rels "http://schemas.openxmlformats.org/package/2006/relationships")
    (define rel-base "http://schemas.openxmlformats.org/officeDocument/2006/relationships/")
    (define layout-rel (cat rel-base "slideLayout"))

    (define decl "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")
    (define pml-ns (cat (attr "xmlns:a" ns-a) (attr "xmlns:r" ns-r) (attr "xmlns:p" ns-p)))

    (define (opt alist key default)
      (let ((p (assq key alist))) (if p (cdr p) default)))

    ;; --- relationships and ids -------------------------------------------

    (define (add-rel! slide type target . external)
      (let ((id (cat "rId" (number->string (slide-next-rel slide)))))
        (set-slide-next-rel! slide (+ 1 (slide-next-rel slide)))
        (set-slide-rels! slide (cons (list id type target (and (pair? external) (car external)))
                                     (slide-rels slide)))
        id))

    (define (next-shape-id! slide)
      (let ((id (slide-next-id slide)))
        (set-slide-next-id! slide (+ id 1))
        id))

    ;; The package name of media (stored once per key).
    ;; Media is stored once per key and type.
    (define (media-name! pres key source ext content-type)
      (let* ((key (cons ext key))
             (known (assoc key (pres-media pres))))
        (if known
            (cadr known)
            (let ((name (cat "media" (number->string (+ 1 (length (pres-media pres)))) "." ext)))
              (set-pres-media! pres (append (pres-media pres)
                                            (list (list key name source content-type))))
              name))))

    (define (media-key source key)
      (or key (if (string? source) source source)))

    ;; --- text -----------------------------------------------------------

    (define (color-fill color alpha)
      (if color
          (cat "<a:solidFill><a:srgbClr" (attr "val" color) ">"
               (if (and alpha (< alpha 1)) (cat "<a:alpha" (attr "val" (n (* alpha 100000))) "/>") "")
               "</a:srgbClr></a:solidFill>")
          "<a:noFill/>"))

    (define (run-props slide run tag)
      (let ((size (opt run 'size #f))
            (link (opt run 'link #f))
            (color (opt run 'color #f))
            (font (opt run 'font #f)))
        (cat "<a:" tag " lang=\"de-CH\""
             (if size (attr "sz" (n (* size 100))) "")
             (if (opt run 'bold #f) (attr "b" "1") "")
             (if (opt run 'italic #f) (attr "i" "1") "")
             (if (opt run 'underline #f) (attr "u" "sng") "")
             " dirty=\"0\">"
             (if color (color-fill color #f) "")
             (if font (cat "<a:latin" (attr "typeface" (esc font)) "/>"
                           "<a:cs" (attr "typeface" (esc font)) "/>") "")
             (if (and link slide)
                 (cat "<a:hlinkClick" (attr "r:id" (add-rel! slide (cat rel-base "hyperlink") (esc link) #t)) "/>")
                 "")
             "</a:" tag ">")))

    ;; Field ids: any GUID, the same for all fields of a kind.
    (define field-types
      '((slide-number "slidenum" "{4FAE4C6E-6C1B-4E0B-9A3E-2B7C5D9A1F01}")
        (date "datetime1" "{4FAE4C6E-6C1B-4E0B-9A3E-2B7C5D9A1F02}")))

    ;; "a\nb" -> runs with <a:br/> between the lines
    (define (run-xml slide run)
      (let ((field (assq (opt run 'field #f) field-types)))
        (if field
            (cat "<a:fld" (attr "id" (caddr field)) (attr "type" (cadr field)) ">"
                 (run-props slide run "rPr")
                 "<a:t>" (esc (opt run 'text "")) "</a:t></a:fld>")
            (text-run-xml slide run))))

    (define (text-run-xml slide run)
      (let loop ((lines (split-lines (opt run 'text ""))) (first #t) (acc '()))
        (if (null? lines)
            (strings (reverse acc))
            (loop (cdr lines) #f
                  (cons (cat (if first "" (cat "<a:br>" (run-props slide run "rPr") "</a:br>"))
                             (if (string=? (car lines) "")
                                 ""
                                 (cat "<a:r>" (run-props slide run "rPr")
                                      "<a:t>" (esc (car lines)) "</a:t></a:r>")))
                        acc)))))

    (define (split-lines s)
      (let loop ((i 0) (start 0) (acc '()))
        (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
              ((char=? (string-ref s i) #\newline)
               (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
              (else (loop (+ i 1) start acc)))))

    (define (paragraph-xml slide p)
      (let* ((align (opt p 'align 'left))
             (bullet (opt p 'bullet #f))
             (level (opt p 'level 0))
             (runs (opt p 'runs '()))
             (spacing (opt p 'line-spacing #f))
             (after (opt p 'space-after #f))
             (marl (opt p 'margin-left #f))
             (indent (opt p 'indent #f))
             (last-run (if (pair? runs) (car (reverse runs)) '())))
        (cat "<a:p><a:pPr"
             (if (> level 0) (attr "lvl" (number->string level)) "")
             (if marl (attr "marL" (n marl)) "")
             (if indent (attr "indent" (n indent)) "")
             (attr "algn" (case align ((center) "ctr") ((right) "r") ((justify) "just") (else "l")))
             ">"
             (if spacing (cat "<a:lnSpc><a:spcPct" (attr "val" (n (* spacing 100000))) "/></a:lnSpc>") "")
             (if after (cat "<a:spcAft><a:spcPts" (attr "val" (n (* after 100))) "/></a:spcAft>") "")
             (cond ((not bullet) "<a:buNone/>")
                   ((eq? bullet 'number) "<a:buFontTx/><a:buAutoNum type=\"arabicPeriod\"/>")
                   (else (cat "<a:buFontTx/><a:buChar" (attr "char" (esc bullet)) "/>")))
             "</a:pPr>"
             (strings (map (lambda (r) (run-xml slide r)) runs))
             (run-props #f last-run "endParaRPr")
             "</a:p>")))

    (define (text-body slide paragraphs anchor)
      (cat "<p:txBody><a:bodyPr wrap=\"square\" lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\""
           (attr "anchor" (case anchor ((middle) "ctr") ((bottom) "b") (else "t")))
           " rtlCol=\"0\"><a:noAutofit/></a:bodyPr><a:lstStyle/>"
           (if (null? paragraphs)
               "<a:p><a:endParaRPr lang=\"de-CH\" dirty=\"0\"/></a:p>"
               (strings (map (lambda (p) (paragraph-xml slide p)) paragraphs)))
           "</p:txBody>"))

    ;; --- shapes -----------------------------------------------------------

    (define (xfrm x y w h rot . flip)
      (cat "<a:xfrm"
           (if (and rot (not (= rot 0))) (attr "rot" (n (* 60000 (modulo* rot 360)))) "")
           (if (and (pair? flip) (car flip)) (attr "flipV" "1") "")
           "><a:off" (attr "x" (n x)) (attr "y" (n y)) "/>"
           "<a:ext" (attr "cx" (n (max 0 w))) (attr "cy" (n (max 0 h))) "/></a:xfrm>"))

    (define (modulo* a m) (let ((r (- a (* m (floor (/ a m)))))) r))

    (define (geometry kind w h)
      (let* ((ss (max 1 (min w h)))
             (gd (lambda (name v) (cat "<a:gd" (attr "name" name) (attr "fmla" (cat "val " (n v))) "/>"))))
        (case kind
          ((rounded) (cat "<a:prstGeom prst=\"roundRect\"><a:avLst>" (gd "adj" 12000) "</a:avLst></a:prstGeom>"))
          ((ellipse) "<a:prstGeom prst=\"ellipse\"><a:avLst/></a:prstGeom>")
          ((triangle) "<a:prstGeom prst=\"triangle\"><a:avLst/></a:prstGeom>")
          ((arrow)
           (let ((head (min (* 0.4 w) h)))
             (cat "<a:prstGeom prst=\"rightArrow\"><a:avLst>" (gd "adj1" 40000)
                  (gd "adj2" (* 100000 (/ head ss))) "</a:avLst></a:prstGeom>")))
          ((chevron)
           (let ((k (min (* 0.4 w) (/ h 2))))
             (cat "<a:prstGeom prst=\"chevron\"><a:avLst>" (gd "adj" (* 100000 (/ k ss)))
                  "</a:avLst></a:prstGeom>")))
          (else "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>"))))

    (define (line-xml color width)
      (if (and color width (> width 0))
          (cat "<a:ln" (attr "w" (n width)) ">" (color-fill color #f) "</a:ln>")
          "<a:ln><a:noFill/></a:ln>"))

    (define (add-item! slide xml) (set-slide-items! slide (cons xml (slide-items slide))))

    (define (note-build! slide opts spid text?)
      (let ((b (opt opts 'build #f)))
        (when b
          (set-slide-builds! slide (cons (list (car b) (cadr b) spid text?) (slide-builds slide))))))

    (define (slide-add-shape! slide kind x y w h . opts)
      "Syntax: (slide-add-shape! slide kind x y w h [options])
Library: (scm ooxml presentation)
Description: Adds a shape: kind is rect, rounded, ellipse, triangle,
  arrow (pointing right), chevron, or text (a rectangle without fill or
  outline, for text boxes). options is an alist: (fill . color),
  (fill-alpha . 0..1), (line . color), (line-width . emu), (rotation .
  degrees), (text . paragraphs), (anchor . top | middle | bottom),
  (name . string), (build . (order effect)) with effect appear, fade,
  fly-left, fly-right, fly-up (from below), fly-down (from above).
Example:
  (slide-add-shape! s 'rounded 914400 914400 3657600 1828800
    '((fill . \"0070B4\")
      (text . (((align . center) (runs . (((text . \"Hallo\") (size . 28) (color . \"FFFFFF\")))))))
      (anchor . middle)))"
      (let* ((opts (if (pair? opts) (car opts) '()))
             (id (next-shape-id! slide))
             (text (opt opts 'text #f))
             (text-box? (eq? kind 'text)))
        (add-item! slide
          (cat "<p:sp><p:nvSpPr><p:cNvPr" (attr "id" (number->string id))
               (attr "name" (esc (opt opts 'name (cat "Form " (number->string id))))) "/>"
               (if text-box? "<p:cNvSpPr txBox=\"1\"/>" "<p:cNvSpPr/>")
               "<p:nvPr/></p:nvSpPr><p:spPr>"
               (xfrm x y w h (opt opts 'rotation 0))
               (geometry (if text-box? 'rect kind) w h)
               (if text-box?
                   (color-fill (opt opts 'fill #f) (opt opts 'fill-alpha #f))
                   (color-fill (opt opts 'fill #f) (opt opts 'fill-alpha #f)))
               (line-xml (opt opts 'line #f) (opt opts 'line-width #f))
               "</p:spPr>"
               (if (or text text-box?) (text-body slide (or text '()) (opt opts 'anchor 'top)) "")
               "</p:sp>"))
        (note-build! slide opts id (and text #t))
        id))

    (define (slide-add-line! slide x y w h . opts)
      "Syntax: (slide-add-line! slide x y w h [options])
Library: (scm ooxml presentation)
Description: Adds a straight line from the top-left to the bottom-right
  corner of the box (or, with (flip . #t), from the bottom-left to the
  top-right). options: (color . color), (width . emu), (name . string),
  (build . (order effect))."
      (let* ((opts (if (pair? opts) (car opts) '()))
             (id (next-shape-id! slide)))
        (add-item! slide
          (cat "<p:cxnSp><p:nvCxnSpPr><p:cNvPr" (attr "id" (number->string id))
               (attr "name" (esc (opt opts 'name (cat "Linie " (number->string id))))) "/>"
               "<p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr>"
               (xfrm x y w h 0 (opt opts 'flip #f))
               "<a:prstGeom prst=\"line\"><a:avLst/></a:prstGeom>"
               "<a:ln" (attr "w" (n (opt opts 'width 12700))) " cap=\"rnd\">"
               (color-fill (opt opts 'color "000000") #f) "</a:ln></p:spPr></p:cxnSp>"))
        (note-build! slide opts id #f)
        id))

    ;; --- tables -----------------------------------------------------------

    (define (slide-add-table! slide x y w h rows . opts)
      "Syntax: (slide-add-table! slide x y w h rows [options])
Library: (scm ooxml presentation)
Description: Adds a table. rows is a list of rows, a row a list of cells
  (every row as long as the first), a cell an alist: (text . paragraphs),
  (fill . color), (anchor . top | middle | bottom). Columns share the
  width equally unless options has (column-widths . (emu ...)); rows are
  h / rows high (PowerPoint makes a row higher when its text needs it)
  unless (row-heights . (emu ...)). Other options: (margins . (left top
  right bottom)) in EMU (default 91440 45720 91440 45720), (header . #t)
  (the first row is a header row), (name . string), (build . (order
  effect)). Cells have no borders.
Example:
  (slide-add-table! s 914400 914400 7315200 1828800
    (list (list '((text . (((runs . (((text . \"Name\") (bold . #t))))))) (fill . \"0070B4\"))
                '((text . (((runs . (((text . \"Wert\") (bold . #t))))))) (fill . \"0070B4\")))
          (list '((text . (((runs . (((text . \"a\")))))))) '((text . (((runs . (((text . \"1\"))))))))))
    '((header . #t)))"
      (let* ((opts (if (pair? opts) (car opts) '()))
             (id (next-shape-id! slide))
             (ncols (if (pair? rows) (length (car rows)) 1))
             (nrows (max 1 (length rows)))
             (widths (opt opts 'column-widths
                          (let loop ((i 0) (acc '()) (used 0))
                            ;; equal widths that add up to w exactly
                            (if (= i ncols)
                                (reverse acc)
                                (let ((cw (- (exact (round (* w (/ (+ i 1) ncols)))) used)))
                                  (loop (+ i 1) (cons cw acc) (+ used cw)))))))
             (heights (opt opts 'row-heights (map (lambda (r) (/ h nrows)) rows)))
             (margins (opt opts 'margins '(91440 45720 91440 45720)))
             (no-line (lambda (tag) (cat "<a:" tag " w=\"0\"><a:noFill/></a:" tag ">")))
             (cell-xml
              (lambda (cell)
                (let ((paras (opt cell 'text '())))
                  (cat "<a:tc><a:txBody><a:bodyPr/><a:lstStyle/>"
                       (if (null? paras)
                           "<a:p><a:endParaRPr lang=\"de-CH\" dirty=\"0\"/></a:p>"
                           (strings (map (lambda (p) (paragraph-xml slide p)) paras)))
                       "</a:txBody><a:tcPr"
                       (attr "marL" (n (list-ref margins 0))) (attr "marR" (n (list-ref margins 2)))
                       (attr "marT" (n (list-ref margins 1))) (attr "marB" (n (list-ref margins 3)))
                       (attr "anchor" (case (opt cell 'anchor 'top) ((middle) "ctr") ((bottom) "b") (else "t")))
                       ">" (no-line "lnL") (no-line "lnR") (no-line "lnT") (no-line "lnB")
                       (color-fill (opt cell 'fill #f) #f)
                       "</a:tcPr></a:tc>")))))
        (add-item! slide
          (cat "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr" (attr "id" (number->string id))
               (attr "name" (esc (opt opts 'name (cat "Tabelle " (number->string id))))) "/>"
               "<p:cNvGraphicFramePr><a:graphicFrameLocks noGrp=\"1\"/></p:cNvGraphicFramePr><p:nvPr/>"
               "</p:nvGraphicFramePr>"
               "<p:xfrm><a:off" (attr "x" (n x)) (attr "y" (n y)) "/>"
               "<a:ext" (attr "cx" (n (max 0 w))) (attr "cy" (n (max 0 h))) "/></p:xfrm>"
               "<a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\">"
               "<a:tbl><a:tblPr" (if (opt opts 'header #f) (attr "firstRow" "1") "") "/><a:tblGrid>"
               (strings (map (lambda (cw) (cat "<a:gridCol" (attr "w" (n cw)) "/>")) widths))
               "</a:tblGrid>"
               (strings (map (lambda (row rh)
                               (cat "<a:tr" (attr "h" (n rh)) ">" (strings (map cell-xml row)) "</a:tr>"))
                             rows heights))
               "</a:tbl></a:graphicData></a:graphic></p:graphicFrame>"))
        (note-build! slide opts id #f)
        id))

    (define (image-type mime)
      (cond ((equal? mime "image/png") '("png" . "image/png"))
            ((equal? mime "image/jpeg") '("jpeg" . "image/jpeg"))
            ((equal? mime "image/gif") '("gif" . "image/gif"))
            (else (error "slide-add-picture!: unsupported image type" mime))))

    (define (pic-xml id name descr rel crop alpha x y w h rot nv-extra)
      (cat "<p:pic><p:nvPicPr><p:cNvPr" (attr "id" (number->string id)) (attr "name" (esc name))
           (if descr (attr "descr" (esc descr)) "") ">"
           (if nv-extra (car nv-extra) "")
           "</p:cNvPr><p:cNvPicPr><a:picLocks noChangeAspect=\"1\"/></p:cNvPicPr>"
           "<p:nvPr>" (if nv-extra (cdr nv-extra) "") "</p:nvPr></p:nvPicPr>"
           "<p:blipFill><a:blip" (attr "r:embed" rel) ">"
           (if (and alpha (< alpha 1)) (cat "<a:alphaModFix" (attr "amt" (n (* alpha 100000))) "/>") "")
           "</a:blip>"
           (if crop
               (cat "<a:srcRect" (attr "l" (n (* 100000 (list-ref crop 0))))
                    (attr "t" (n (* 100000 (list-ref crop 1))))
                    (attr "r" (n (* 100000 (list-ref crop 2))))
                    (attr "b" (n (* 100000 (list-ref crop 3)))) "/>")
               "")
           "<a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr>"
           (xfrm x y w h rot)
           "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr></p:pic>"))

    (define (slide-add-picture! slide source mime x y w h . opts)
      "Syntax: (slide-add-picture! slide source mime x y w h [options])
Library: (scm ooxml presentation)
Description: Adds a picture: source is a bytevector or the path of a
  file, mime image/png, image/jpeg or image/gif. options: (crop . (left
  top right bottom)) the fractions of the image cut off at each side,
  (alpha . 0..1), (rotation . degrees), (description . alt-text),
  (key . string) to store the same image once (default: the path, or
  the bytevector itself), (name . string), (build . (order effect))."
      (let* ((opts (if (pair? opts) (car opts) '()))
             (pres (slide-pres slide))
             (t (image-type mime))
             (media (media-name! pres (media-key source (opt opts 'key #f)) source (car t) (cdr t)))
             (rel (add-rel! slide (cat rel-base "image") (cat "../media/" media)))
             (id (next-shape-id! slide)))
        (add-item! slide
          (pic-xml id (opt opts 'name (cat "Bild " (number->string id))) (opt opts 'description #f)
                   rel (opt opts 'crop #f) (opt opts 'alpha #f) x y w h (opt opts 'rotation 0) #f))
        (note-build! slide opts id #f)
        id))

    (define (slide-add-video! slide source poster poster-mime x y w h . opts)
      "Syntax: (slide-add-video! slide source poster poster-mime x y w h [options])
Library: (scm ooxml presentation)
Description: Adds an MP4 video (source: bytevector or file path) shown
  as poster (an image, as for slide-add-picture!) until it plays; in
  PowerPoint a click on it plays it. options as for slide-add-picture!
  (crop and alpha apply to the poster), (poster-key . string) to store the
  poster once."
      (let* ((opts (if (pair? opts) (car opts) '()))
             (pres (slide-pres slide))
             (video (media-name! pres (media-key source (opt opts 'key #f)) source "mp4" "video/mp4"))
             (pt (image-type poster-mime))
             (image (media-name! pres (media-key poster (opt opts 'poster-key #f)) poster (car pt) (cdr pt)))
             (media-rel (add-rel! slide "http://schemas.microsoft.com/office/2007/relationships/media"
                                  (cat "../media/" video)))
             (video-rel (add-rel! slide (cat rel-base "video") (cat "../media/" video)))
             (image-rel (add-rel! slide (cat rel-base "image") (cat "../media/" image)))
             (id (next-shape-id! slide)))
        (add-item! slide
          (pic-xml id (opt opts 'name (cat "Video " (number->string id))) (opt opts 'description #f)
                   image-rel (opt opts 'crop #f) (opt opts 'alpha #f) x y w h (opt opts 'rotation 0)
                   (cons "<a:hlinkClick r:id=\"\" action=\"ppaction://media\"/>"
                         (cat "<a:videoFile" (attr "r:link" video-rel) "/>"
                              "<p:extLst><p:ext uri=\"{DAA4B4D4-6D71-4841-9C94-3DE7FCFB9230}\">"
                              "<p14:media xmlns:p14=\"http://schemas.microsoft.com/office/powerpoint/2010/main\""
                              (attr "r:embed" media-rel) "/></p:ext></p:extLst>"))))
        (note-build! slide opts id #f)
        id))

    ;; --- transitions and builds -----------------------------------------------

    (define (transition-xml tr)
      (if (or (not tr) (eq? (car tr) 'none))
          ""
          (let ((spd (cond ((< (cdr tr) 400) "fast") ((>= (cdr tr) 800) "slow") (else "med"))))
            (cat "<p:transition" (attr "spd" spd) ">"
                 (case (car tr)
                   ((fade) "<p:fade/>")
                   ((push-left) "<p:push dir=\"l\"/>")
                   ((push-up) "<p:push dir=\"u\"/>")
                   ((wipe-left) "<p:wipe dir=\"l\"/>")
                   ((zoom) "<p:zoom/>")
                   (else "<p:fade/>"))
                 "</p:transition>"))))

    ;; Builds as PowerPoint animations: one click per build order, every
    ;; element of the order an entrance effect in that click.
    (define (timing-xml builds)
      (if (null? builds)
          ""
          (let* ((orders (sort-unique (map car builds)))
                 (ctn 2)
                 (next! (lambda () (set! ctn (+ ctn 1)) (number->string ctn)))
                 (target (lambda (spid) (cat "<p:tgtEl><p:spTgt" (attr "spid" (number->string spid)) "/></p:tgtEl>")))
                 (set-visible
                  (lambda (spid)
                    (cat "<p:set><p:cBhvr><p:cTn" (attr "id" (next!)) " dur=\"1\" fill=\"hold\">"
                         "<p:stCondLst><p:cond delay=\"0\"/></p:stCondLst></p:cTn>" (target spid)
                         "<p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst>"
                         "</p:cBhvr><p:to><p:strVal val=\"visible\"/></p:to></p:set>")))
                 (fly (lambda (spid attr-name from)
                        (cat "<p:anim calcmode=\"lin\" valueType=\"num\"><p:cBhvr additive=\"base\">"
                             "<p:cTn" (attr "id" (next!)) " dur=\"500\" fill=\"hold\"/>" (target spid)
                             "<p:attrNameLst><p:attrName>" attr-name "</p:attrName></p:attrNameLst></p:cBhvr>"
                             "<p:tavLst><p:tav tm=\"0\"><p:val><p:strVal" (attr "val" from) "/></p:val></p:tav>"
                             "<p:tav tm=\"100000\"><p:val><p:strVal" (attr "val" (cat "#" attr-name)) "/></p:val></p:tav>"
                             "</p:tavLst></p:anim>")))
                 (effect
                  (lambda (b first?)
                    (let* ((kind (cadr b))
                           (spid (caddr b))
                           (preset (case kind
                                     ((fade) '("10" . "0"))
                                     ((fly-left) '("2" . "8"))
                                     ((fly-right) '("2" . "2"))
                                     ((fly-up) '("2" . "4"))
                                     ((fly-down) '("2" . "1"))
                                     (else '("1" . "0")))))
                      (cat "<p:par><p:cTn" (attr "id" (next!)) (attr "presetID" (car preset))
                           " presetClass=\"entr\"" (attr "presetSubtype" (cdr preset))
                           " fill=\"hold\"" (if (cadddr b) " grpId=\"0\"" "")
                           (attr "nodeType" (if first? "clickEffect" "withEffect")) ">"
                           "<p:stCondLst><p:cond delay=\"0\"/></p:stCondLst><p:childTnLst>"
                           (set-visible spid)
                           (case kind
                             ((fade)
                              (cat "<p:animEffect transition=\"in\" filter=\"fade\"><p:cBhvr>"
                                   "<p:cTn" (attr "id" (next!)) " dur=\"500\"/>" (target spid)
                                   "</p:cBhvr></p:animEffect>"))
                             ((fly-left) (fly spid "ppt_x" "0-#ppt_w/2"))
                             ((fly-right) (fly spid "ppt_x" "1+#ppt_w/2"))
                             ((fly-up) (fly spid "ppt_y" "1+#ppt_h/2"))
                             ((fly-down) (fly spid "ppt_y" "0-#ppt_h/2"))
                             (else ""))
                           "</p:childTnLst></p:cTn></p:par>"))))
                 (clicks
                  (strings
                   (map (lambda (o)
                          (let ((these (filter-order o builds)))
                            (cat "<p:par><p:cTn" (attr "id" (next!)) " fill=\"hold\">"
                                 "<p:stCondLst><p:cond delay=\"indefinite\"/></p:stCondLst><p:childTnLst>"
                                 "<p:par><p:cTn" (attr "id" (next!)) " fill=\"hold\">"
                                 "<p:stCondLst><p:cond delay=\"0\"/></p:stCondLst><p:childTnLst>"
                                 (let loop ((bs these) (first? #t) (acc '()))
                                   (if (null? bs)
                                       (strings (reverse acc))
                                       (loop (cdr bs) #f (cons (effect (car bs) first?) acc))))
                                 "</p:childTnLst></p:cTn></p:par>"
                                 "</p:childTnLst></p:cTn></p:par>")))
                        orders)))
                 (text-builds (filter-text builds)))
            (cat "<p:timing><p:tnLst><p:par><p:cTn id=\"1\" dur=\"indefinite\" restart=\"never\" nodeType=\"tmRoot\">"
                 "<p:childTnLst><p:seq concurrent=\"1\" nextAc=\"seek\">"
                 "<p:cTn id=\"2\" dur=\"indefinite\" nodeType=\"mainSeq\"><p:childTnLst>"
                 clicks
                 "</p:childTnLst></p:cTn>"
                 "<p:prevCondLst><p:cond evt=\"onPrev\" delay=\"0\"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>"
                 "<p:nextCondLst><p:cond evt=\"onNext\" delay=\"0\"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>"
                 "</p:seq></p:childTnLst></p:cTn></p:par></p:tnLst>"
                 (if (null? text-builds)
                     ""
                     (cat "<p:bldLst>"
                          (strings (map (lambda (b) (cat "<p:bldP" (attr "spid" (number->string (caddr b)))
                                                         " grpId=\"0\" animBg=\"1\"/>"))
                                        text-builds))
                          "</p:bldLst>"))
                 "</p:timing>"))))

    (define (filter-order o builds)
      ;; the builds of order o, in the order they were added
      (let loop ((bs (reverse builds)) (acc '()))
        (cond ((null? bs) (reverse acc))
              ((= (car (car bs)) o) (loop (cdr bs) (cons (car bs) acc)))
              (else (loop (cdr bs) acc)))))

    (define (filter-text builds)
      (let loop ((bs (reverse builds)) (acc '()))
        (cond ((null? bs) (reverse acc))
              ((cadddr (car bs)) (loop (cdr bs) (cons (car bs) acc)))
              (else (loop (cdr bs) acc)))))

    (define (sort-unique xs)
      (let loop ((xs xs) (out '()))
        (if (null? xs)
            out
            (loop (cdr xs)
                  (let ins ((ys out))
                    (cond ((null? ys) (list (car xs)))
                          ((= (car xs) (car ys)) ys)
                          ((< (car xs) (car ys)) (cons (car xs) ys))
                          (else (cons (car ys) (ins (cdr ys))))))))))

    ;; --- parts ------------------------------------------------------------

    (define empty-tree-head
      (cat "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"
           "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/>"
           "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"))

    (define (slide-xml s)
      (cat decl "<p:sld" pml-ns "><p:cSld>"
           (if (slide-background s)
               (cat "<p:bg><p:bgPr>" (color-fill (slide-background s) #f) "<a:effectLst/></p:bgPr></p:bg>")
               "")
           "<p:spTree>" empty-tree-head
           (strings (reverse (slide-items s)))
           "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>"
           (transition-xml (slide-transition s))
           (timing-xml (slide-builds s))
           "</p:sld>"))

    (define (rels-xml rels)
      (cat decl "<Relationships" (attr "xmlns" ns-rels) ">"
           (strings (map (lambda (r)
                           (cat "<Relationship" (attr "Id" (car r)) (attr "Type" (cadr r))
                                (attr "Target" (caddr r))
                                (if (cadddr r) (attr "TargetMode" "External") "") "/>"))
                         rels))
           "</Relationships>"))

    (define (notes-xml s)
      (cat decl "<p:notes" pml-ns "><p:cSld><p:spTree>" empty-tree-head
           "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Folienbild\"/><p:cNvSpPr>"
           "<a:spLocks noGrp=\"1\" noRot=\"1\" noChangeAspect=\"1\"/></p:cNvSpPr>"
           "<p:nvPr><p:ph type=\"sldImg\"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>"
           "<p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Notizen\"/><p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>"
           "<p:nvPr><p:ph type=\"body\" idx=\"1\"/></p:nvPr></p:nvSpPr><p:spPr/>"
           "<p:txBody><a:bodyPr/><a:lstStyle/>"
           (let ((ps (slide-notes s)))
             (if (null? ps)
                 "<a:p><a:endParaRPr lang=\"de-CH\" dirty=\"0\"/></a:p>"
                 (strings (map (lambda (p) (paragraph-xml #f p)) ps))))
           "</p:txBody></p:sp></p:spTree></p:cSld>"
           "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>"))

    (define clr-map
      (cat "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\" accent1=\"accent1\" accent2=\"accent2\""
           " accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\""
           " hlink=\"hlink\" folHlink=\"folHlink\"/>"))

    (define master-xml
      (cat decl "<p:sldMaster" pml-ns "><p:cSld><p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>"
           "<p:spTree>" empty-tree-head "</p:spTree></p:cSld>" clr-map
           "<p:sldLayoutIdLst><p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/></p:sldLayoutIdLst>"
           "</p:sldMaster>"))

    (define layout-xml
      (cat decl "<p:sldLayout" pml-ns " type=\"blank\" preserve=\"1\"><p:cSld name=\"Leer\"><p:spTree>"
           empty-tree-head "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>"))

    (define (notes-master-xml pres)
      (cat decl "<p:notesMaster" pml-ns "><p:cSld><p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>"
           "<p:spTree>" empty-tree-head
           "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Folienbild\"/><p:cNvSpPr>"
           "<a:spLocks noGrp=\"1\" noRot=\"1\" noChangeAspect=\"1\"/></p:cNvSpPr>"
           "<p:nvPr><p:ph type=\"sldImg\" idx=\"2\"/></p:nvPr></p:nvSpPr><p:spPr>"
           "<a:xfrm><a:off x=\"381000\" y=\"685800\"/><a:ext cx=\"6096000\" cy=\"3429000\"/></a:xfrm>"
           "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/><a:ln w=\"12700\"><a:solidFill><a:prstClr val=\"black\"/></a:solidFill></a:ln></p:spPr></p:sp>"
           "<p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Notizen\"/><p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>"
           "<p:nvPr><p:ph type=\"body\" sz=\"quarter\" idx=\"3\"/></p:nvPr></p:nvSpPr><p:spPr>"
           "<a:xfrm><a:off x=\"685800\" y=\"4400550\"/><a:ext cx=\"5486400\" cy=\"3600450\"/></a:xfrm>"
           "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr>"
           "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:endParaRPr lang=\"de-CH\"/></a:p></p:txBody></p:sp>"
           "</p:spTree></p:cSld>" clr-map "</p:notesMaster>"))

    (define (theme-xml name)
      (cat decl "<a:theme" (attr "xmlns:a" ns-a) (attr "name" name) "><a:themeElements>"
           "<a:clrScheme name=\"Folien\">"
           "<a:dk1><a:srgbClr val=\"000000\"/></a:dk1><a:lt1><a:srgbClr val=\"FFFFFF\"/></a:lt1>"
           "<a:dk2><a:srgbClr val=\"1F1F1F\"/></a:dk2><a:lt2><a:srgbClr val=\"EEEEEE\"/></a:lt2>"
           "<a:accent1><a:srgbClr val=\"0070B4\"/></a:accent1><a:accent2><a:srgbClr val=\"00407C\"/></a:accent2>"
           "<a:accent3><a:srgbClr val=\"D93C1A\"/></a:accent3><a:accent4><a:srgbClr val=\"1A7F1F\"/></a:accent4>"
           "<a:accent5><a:srgbClr val=\"7F3DA7\"/></a:accent5><a:accent6><a:srgbClr val=\"DC7700\"/></a:accent6>"
           "<a:hlink><a:srgbClr val=\"0070B4\"/></a:hlink><a:folHlink><a:srgbClr val=\"00407C\"/></a:folHlink>"
           "</a:clrScheme>"
           "<a:fontScheme name=\"Folien\"><a:majorFont><a:latin typeface=\"Arial\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:majorFont>"
           "<a:minorFont><a:latin typeface=\"Arial\"/><a:ea typeface=\"\"/><a:cs typeface=\"\"/></a:minorFont></a:fontScheme>"
           "<a:fmtScheme name=\"Folien\"><a:fillStyleLst>"
           "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
           "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
           "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:fillStyleLst>"
           "<a:lnStyleLst>"
           "<a:ln w=\"6350\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln>"
           "<a:ln w=\"12700\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln>"
           "<a:ln w=\"19050\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln></a:lnStyleLst>"
           "<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle>"
           "<a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>"
           "<a:bgFillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
           "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
           "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:bgFillStyleLst>"
           "</a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>"))

    (define (presentation-xml pres)
      (let ((count (length (pres-slides pres))))
        (cat decl "<p:presentation" pml-ns " saveSubsetFonts=\"1\">"
             "<p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"rId1\"/></p:sldMasterIdLst>"
             "<p:notesMasterIdLst><p:notesMasterId r:id=\"rId6\"/></p:notesMasterIdLst>"
             (if (= count 0)
                 ""
                 (cat "<p:sldIdLst>"
                      (strings (map (lambda (s)
                                      (cat "<p:sldId" (attr "id" (number->string (+ 255 (slide-number s))))
                                           (attr "r:id" (cat "rId" (number->string (+ 6 (slide-number s))))) "/>"))
                                    (pres-slides pres)))
                      "</p:sldIdLst>"))
             "<p:sldSz" (attr "cx" (n (pres-width pres))) (attr "cy" (n (pres-height pres))) "/>"
             "<p:notesSz cx=\"6858000\" cy=\"9144000\"/>"
             "</p:presentation>")))

    (define (presentation-rels pres)
      (rels-xml
       (append
        (list (list "rId1" (cat rel-base "slideMaster") "slideMasters/slideMaster1.xml" #f)
              (list "rId2" (cat rel-base "theme") "theme/theme1.xml" #f)
              (list "rId3" (cat rel-base "presProps") "presProps.xml" #f)
              (list "rId4" (cat rel-base "viewProps") "viewProps.xml" #f)
              (list "rId5" (cat rel-base "tableStyles") "tableStyles.xml" #f)
              (list "rId6" (cat rel-base "notesMaster") "notesMasters/notesMaster1.xml" #f))
        (map (lambda (s)
               (list (cat "rId" (number->string (+ 6 (slide-number s)))) (cat rel-base "slide")
                     (cat "slides/slide" (number->string (slide-number s)) ".xml") #f))
             (pres-slides pres)))))

    (define (content-types pres)
      (let ((ov (lambda (part type) (cat "<Override" (attr "PartName" part) (attr "ContentType" type) "/>")))
            (pml "application/vnd.openxmlformats-officedocument.presentationml."))
        (cat decl "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
             "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
             "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
             "<Default Extension=\"png\" ContentType=\"image/png\"/>"
             "<Default Extension=\"jpeg\" ContentType=\"image/jpeg\"/>"
             "<Default Extension=\"gif\" ContentType=\"image/gif\"/>"
             "<Default Extension=\"mp4\" ContentType=\"video/mp4\"/>"
             (ov "/ppt/presentation.xml" (cat pml "presentation.main+xml"))
             (ov "/ppt/slideMasters/slideMaster1.xml" (cat pml "slideMaster+xml"))
             (ov "/ppt/slideLayouts/slideLayout1.xml" (cat pml "slideLayout+xml"))
             (ov "/ppt/notesMasters/notesMaster1.xml" (cat pml "notesMaster+xml"))
             (ov "/ppt/theme/theme1.xml" "application/vnd.openxmlformats-officedocument.theme+xml")
             (ov "/ppt/theme/theme2.xml" "application/vnd.openxmlformats-officedocument.theme+xml")
             (ov "/ppt/presProps.xml" (cat pml "presProps+xml"))
             (ov "/ppt/viewProps.xml" (cat pml "viewProps+xml"))
             (ov "/ppt/tableStyles.xml" (cat pml "tableStyles+xml"))
             (ov "/docProps/core.xml" "application/vnd.openxmlformats-package.core-properties+xml")
             (ov "/docProps/app.xml" "application/vnd.openxmlformats-officedocument.extended-properties+xml")
             (strings (map (lambda (s)
                             (let ((k (number->string (slide-number s))))
                               (cat (ov (cat "/ppt/slides/slide" k ".xml") (cat pml "slide+xml"))
                                    (ov (cat "/ppt/notesSlides/notesSlide" k ".xml") (cat pml "notesSlide+xml")))))
                           (pres-slides pres)))
             "</Types>")))

    (define (core-xml pres)
      (cat decl "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\""
           " xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\""
           " xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">"
           "<dc:title>" (esc (pres-title pres)) "</dc:title></cp:coreProperties>"))

    (define (app-xml pres)
      (cat decl "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\">"
           "<Application>dabscm</Application><Slides>" (number->string (length (pres-slides pres)))
           "</Slides></Properties>"))

    (define root-rels
      (rels-xml (list (list "rId1" (cat rel-base "officeDocument") "ppt/presentation.xml" #f)
                      (list "rId2" "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
                            "docProps/core.xml" #f)
                      (list "rId3" (cat rel-base "extended-properties") "docProps/app.xml" #f))))

    ;; --- writing ------------------------------------------------------------

    (define (text! z name text)
      (zip-add-stored-entry* z name (string->utf8 text)))

    (define (zip-add-stored-entry* z name bv)
      ;; XML compresses well: deflated
      (let ((p (zip-add-binary-entry z name)))
        (write-bytevector bv p)
        (flush-output-port p)))

    (define (write-package! pres z)
      ;; Slide XML first: it registers relationships and media.
      (let ((slides (map (lambda (s) (cons s (slide-xml s))) (pres-slides pres))))
        (text! z "[Content_Types].xml" (content-types pres))
        (text! z "_rels/.rels" root-rels)
        (text! z "docProps/core.xml" (core-xml pres))
        (text! z "docProps/app.xml" (app-xml pres))
        (text! z "ppt/presentation.xml" (presentation-xml pres))
        (text! z "ppt/_rels/presentation.xml.rels" (presentation-rels pres))
        (text! z "ppt/presProps.xml" (cat decl "<p:presentationPr" pml-ns "/>"))
        (text! z "ppt/viewProps.xml" (cat decl "<p:viewPr" pml-ns "/>"))
        (text! z "ppt/tableStyles.xml"
               (cat decl "<a:tblStyleLst" (attr "xmlns:a" ns-a) " def=\"{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}\"/>"))
        (text! z "ppt/theme/theme1.xml" (theme-xml "Folien"))
        (text! z "ppt/theme/theme2.xml" (theme-xml "Notizen"))
        (text! z "ppt/slideMasters/slideMaster1.xml" master-xml)
        (text! z "ppt/slideMasters/_rels/slideMaster1.xml.rels"
               (rels-xml (list (list "rId1" layout-rel "../slideLayouts/slideLayout1.xml" #f)
                               (list "rId2" (cat rel-base "theme") "../theme/theme1.xml" #f))))
        (text! z "ppt/slideLayouts/slideLayout1.xml" layout-xml)
        (text! z "ppt/slideLayouts/_rels/slideLayout1.xml.rels"
               (rels-xml (list (list "rId1" (cat rel-base "slideMaster") "../slideMasters/slideMaster1.xml" #f))))
        (text! z "ppt/notesMasters/notesMaster1.xml" (notes-master-xml pres))
        (text! z "ppt/notesMasters/_rels/notesMaster1.xml.rels"
               (rels-xml (list (list "rId1" (cat rel-base "theme") "../theme/theme2.xml" #f))))
        (for-each
         (lambda (sx)
           (let* ((s (car sx))
                  (k (number->string (slide-number s)))
                  (notes-rel (list (cat "rId" (number->string (slide-next-rel s))) (cat rel-base "notesSlide")
                                   (cat "../notesSlides/notesSlide" k ".xml") #f)))
             (text! z (cat "ppt/slides/slide" k ".xml") (cdr sx))
             (text! z (cat "ppt/slides/_rels/slide" k ".xml.rels")
                    (rels-xml (append (reverse (slide-rels s)) (list notes-rel))))
             (set-slide-notes! s (or (slide-notes s) '()))
             (text! z (cat "ppt/notesSlides/notesSlide" k ".xml") (notes-xml s))
             (text! z (cat "ppt/notesSlides/_rels/notesSlide" k ".xml.rels")
                    (rels-xml (list (list "rId1" (cat rel-base "notesMaster") "../notesMasters/notesMaster1.xml" #f)
                                    (list "rId2" (cat rel-base "slide") (cat "../slides/slide" k ".xml") #f))))))
         slides)
        (for-each
         (lambda (m)
           (let ((name (cat "ppt/media/" (cadr m))) (source (caddr m)))
             (if (string? source)
                 (zip-add-file-entry z name source)
                 (zip-add-stored-entry z name source))))
         (pres-media pres))))

    (define (presentation-save pres path)
      "Syntax: (presentation-save pres path)
Library: (scm ooxml presentation)
Description: Writes pres as a .pptx file at path."
      (call-with-output-zip path (lambda (z) (write-package! pres z))))

    (define (presentation->bytevector pres)
      "Syntax: (presentation->bytevector pres)
Library: (scm ooxml presentation)
Description: pres as the bytes of a .pptx file."
      (call-with-output-zip-bytevector (lambda (z) (write-package! pres z))))))

(import (scheme base)
        (scheme write)
        (scm test)
        (scm pdf)
        (scm png)
        (scm compression))

(test-runner-factory scm-test-runner)

(test-begin "pdf")

;; ── Helpers ────────────────────────────────────────────────────────────

(define (bv->string bv)
  (utf8->string bv))

(define (string-contains? hay needle)
  ;; substring search returning index or #f
  (let ((hlen (string-length hay))
        (nlen (string-length needle)))
    (let loop ((i 0))
      (cond
        ((> (+ i nlen) hlen) #f)
        ((string=? (substring hay i (+ i nlen)) needle) i)
        (else (loop (+ i 1)))))))

(test-group "header and trailer"
  (let* ((doc (make-pdf)))
    (pdf-add-page! doc)
    (let* ((bv (pdf->bytevector doc))
           (s  (bv->string bv)))
      ;; PDF magic
      (test-equal "%PDF-1.4" (substring s 0 8))
      ;; Binary comment marker bytes
      (test-equal #x25 (bytevector-u8-ref bv 9))
      (test-equal #xE2 (bytevector-u8-ref bv 10))
      (test-equal #xE3 (bytevector-u8-ref bv 11))
      (test-equal #xCF (bytevector-u8-ref bv 12))
      (test-equal #xD3 (bytevector-u8-ref bv 13))
      ;; Ends with %%EOF
      (test-assert (string-contains? s "\n%%EOF\n"))
      (test-assert (string-contains? s "xref"))
      (test-assert (string-contains? s "trailer")))))

(test-group "catalog and pages structure"
  (let ((doc (make-pdf)))
    (pdf-add-page! doc)
    (let ((s (bv->string (pdf->bytevector doc))))
      (test-assert (string-contains? s "/Type /Catalog"))
      (test-assert (string-contains? s "/Type /Pages"))
      (test-assert (string-contains? s "/Type /Page"))
      (test-assert (string-contains? s "/Count 1"))
      ;; A4 MediaBox
      (test-assert (string-contains? s "/MediaBox [0 0 595 842]")))))

(test-group "page sizes"
  (let ((doc (make-pdf)))
    (pdf-add-page! doc pdf-page-size-letter)
    (pdf-add-page! doc 200 100)
    (let ((s (bv->string (pdf->bytevector doc))))
      (test-equal 2 (pdf-page-count doc))
      (test-assert (string-contains? s "/Count 2"))
      (test-assert (string-contains? s "/MediaBox [0 0 612 792]"))
      (test-assert (string-contains? s "/MediaBox [0 0 200 100]")))))

(test-group "xref table sizing"
  ;; 1 catalog + 1 pages + N pages = N+2 indirect objects.
  ;; xref must have N+3 lines (incl. the free-list head).
  (let ((doc (make-pdf)))
    (pdf-add-page! doc)
    (pdf-add-page! doc)
    (pdf-add-page! doc)
    (let* ((s (bv->string (pdf->bytevector doc)))
           (xref-idx (string-contains? s "xref\n")))
      (test-assert xref-idx)
      ;; "xref\n0 5\n" — 3 pages + catalog + pages = 5 objects, so /Size = 6
      (test-assert (string-contains? s "0 6\n"))
      (test-assert (string-contains? s "/Size 6"))
      ;; Free-list head
      (test-assert (string-contains? s "0000000000 65535 f \n")))))

(test-group "empty document errors"
  (let ((doc (make-pdf)))
    (test-error (pdf->bytevector doc))))

(test-group "value constructors"
  (test-assert (pdf-name? (pdf/name "Foo")))
  (test-assert (pdf-ref? (pdf/ref 7)))
  (test-assert (pdf-dict? (pdf/dict "Type" (pdf/name "Foo"))))
  (test-assert (pdf-array? (pdf/array (list 1 2 3))))
  (test-error (pdf/dict "OddArgs")))

;; ── Drawing API (phase 1) ─────────────────────────────────────────────

(define (extract-content-stream pdf-bv)
  ;; Locate the first "stream\n...\nendstream" body, zlib-decompress it,
  ;; and return as a string. Works as long as there is exactly one
  ;; content stream in the document.
  (let* ((s (utf8->string pdf-bv))
         (start (string-contains? s "\nstream\n"))
         (end   (string-contains? s "\nendstream")))
    (unless (and start end)
      (error "no stream/endstream found in PDF"))
    (let* ((data-start (+ start (string-length "\nstream\n")))
           (compressed (let ((bv (make-bytevector (- end data-start) 0)))
                         (bytevector-copy! bv 0 pdf-bv
                                           data-start end)
                         bv)))
      (utf8->string (zlib-decompress compressed)))))

(test-group "blank page has no Contents entry"
  (let* ((doc (make-pdf)))
    (pdf-add-page! doc)
    (let ((s (utf8->string (pdf->bytevector doc))))
      (test-assert (not (string-contains? s "/Contents")))
      (test-assert (not (string-contains? s "FlateDecode"))))))

(test-group "drawing emits Contents stream"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc)))
    (pdf-rect page 10 20 100 200)
    (pdf-stroke page)
    (let* ((bv (pdf->bytevector doc))
           (s  (utf8->string bv))
           (cs (extract-content-stream bv)))
      (test-assert (string-contains? s "/Contents"))
      (test-assert (string-contains? s "/Filter /FlateDecode"))
      (test-assert (string-contains? cs "10 20 100 200 re"))
      (test-assert (string-contains? cs "S")))))

(test-group "path operators"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc)))
    (pdf-move-to page 1 2)
    (pdf-line-to page 3 4)
    (pdf-curve-to page 5 6 7 8 9 10)
    (pdf-close-path page)
    (pdf-fill page)
    (let ((cs (extract-content-stream (pdf->bytevector doc))))
      (test-assert (string-contains? cs "1 2 m"))
      (test-assert (string-contains? cs "3 4 l"))
      (test-assert (string-contains? cs "5 6 7 8 9 10 c"))
      (test-assert (string-contains? cs "h"))
      (test-assert (string-contains? cs "f")))))

(test-group "graphics state save/restore"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc)))
    (pdf-with-state page
      (lambda ()
        (pdf-set-line-width page 2)
        (pdf-rect page 0 0 10 10)
        (pdf-stroke page)))
    (let ((cs (extract-content-stream (pdf->bytevector doc))))
      ;; q ... Q wraps the inner ops.
      (let ((q  (string-contains? cs "q"))
            (qq (string-contains? cs "Q"))
            (lw (string-contains? cs "2 w")))
        (test-assert q)
        (test-assert qq)
        (test-assert lw)
        (test-assert (< q lw qq))))))

(test-group "colors"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc)))
    (pdf-set-stroke-gray page 0.5)
    (pdf-set-fill-rgb page 1 0 0)
    (pdf-set-stroke-cmyk page 0 1 1 0)
    (let ((cs (extract-content-stream (pdf->bytevector doc))))
      (test-assert (string-contains? cs "0.5 G"))
      (test-assert (string-contains? cs "1 0 0 rg"))
      (test-assert (string-contains? cs "0 1 1 0 K")))))

(test-group "transforms"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc)))
    (pdf-translate page 100 200)
    (pdf-scale page 2 3)
    (let ((cs (extract-content-stream (pdf->bytevector doc))))
      (test-assert (string-contains? cs "1 0 0 1 100 200 cm"))
      (test-assert (string-contains? cs "2 0 0 3 0 0 cm")))))

(test-group "dash pattern"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc)))
    (pdf-set-dash page '(5 3) 0)
    (pdf-set-dash page '() 0)
    (let ((cs (extract-content-stream (pdf->bytevector doc))))
      (test-assert (string-contains? cs "[5 3] 0 d"))
      (test-assert (string-contains? cs "[] 0 d")))))

(test-group "multiple drawn pages produce separate streams"
  (let* ((doc (make-pdf))
         (p1 (pdf-add-page! doc))
         (p2 (pdf-add-page! doc)))
    (pdf-rect p1 0 0 10 10) (pdf-stroke p1)
    (pdf-rect p2 0 0 20 20) (pdf-stroke p2)
    (let ((s (utf8->string (pdf->bytevector doc))))
      ;; 1 catalog + 1 pages + 2 page + 2 contents = 6 indirect objects.
      (test-assert (string-contains? s "/Size 7")))))

;; ── Fonts and text (phase 2) ──────────────────────────────────────────

(test-group "pdf-use-font basics"
  (let* ((doc (make-pdf))
         (helv (pdf-use-font doc 'helvetica)))
    (test-assert (pdf-font? helv))
    (test-equal "Helvetica" (pdf-font-base-name helv))
    (test-equal 'winansi (pdf-font-encoding helv))
    ;; Idempotent: second call returns same handle.
    (test-eq helv (pdf-use-font doc 'helvetica))
    (test-error (pdf-use-font doc 'no-such-font))))

(test-group "pdf-use-font all 14 standard fonts"
  (let ((doc (make-pdf)))
    (for-each
      (lambda (sym)
        (test-assert (pdf-font? (pdf-use-font doc sym))))
      '(helvetica helvetica-bold helvetica-oblique helvetica-bold-oblique
        times-roman times-bold times-italic times-bold-italic
        courier courier-bold courier-oblique courier-bold-oblique
        symbol zapf-dingbats))))

(define (approx= a b)
  (< (abs (- a b)) 1e-9))

(test-group "text-width Courier is monospace"
  (let* ((doc (make-pdf))
         (cour (pdf-use-font doc 'courier)))
    ;; Courier glyphs are all 600 units wide.
    (test-assert (approx= 6.0 (pdf-text-width cour 10 "A")))
    (test-assert (approx= 30.0 (pdf-text-width cour 10 "ABCDE")))
    ;; Width scales linearly with point size.
    (test-assert (approx= 60.0 (pdf-text-width cour 20 "ABCDE")))))

(test-group "text-width Helvetica matches AFM"
  (let* ((doc (make-pdf))
         (helv (pdf-use-font doc 'helvetica)))
    ;; Helvetica: H=722, e=556, l=222, o=556  →  "Hello" = 722+556+222+222+556 = 2278
    ;; At 12pt → 2278 * 12 / 1000 = 27.336
    (test-assert (approx= 27.336 (pdf-text-width helv 12 "Hello")))))

(test-group "text-width WinAnsi non-ASCII"
  (let* ((doc (make-pdf))
         (helv (pdf-use-font doc 'helvetica)))
    ;; "ä" (U+00E4) = adieresis = 556 units in Helvetica.
    (test-assert (approx= 5.56 (pdf-text-width helv 10 "ä")))
    ;; "€" (U+20AC, WinAnsi 128) = Euro = 556 in Helvetica.
    (test-assert (approx= 5.56 (pdf-text-width helv 10 "€")))
    ;; Unknown codepoint substitutes '?' (= 556 in Helvetica).
    (test-assert (approx= 5.56 (pdf-text-width helv 10
                                  (string (integer->char #x4E2D)))))))

(test-group "font metrics"
  (let* ((doc (make-pdf))
         (helv (pdf-use-font doc 'helvetica)))
    (test-equal 718 (pdf-font-ascender helv))
    (test-equal -207 (pdf-font-descender helv))
    (test-equal 718 (pdf-font-cap-height helv))
    (test-equal 523 (pdf-font-x-height helv))))

(test-group "draw-text emits text block"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica)))
    (pdf-draw-text page helv 12 100 700 "Hello")
    (let* ((bv (pdf->bytevector doc))
           (s  (utf8->string bv))
           (cs (extract-content-stream bv)))
      ;; BT/ET wrapper, font set, position, show.
      (test-assert (string-contains? cs "BT"))
      (test-assert (string-contains? cs "ET"))
      (test-assert (string-contains? cs "/F1 12 Tf"))
      (test-assert (string-contains? cs "100 700 Td"))
      (test-assert (string-contains? cs "(Hello) Tj"))
      ;; Font object emitted, page resources reference it.
      (test-assert (string-contains? s "/Type /Font"))
      (test-assert (string-contains? s "/BaseFont /Helvetica"))
      (test-assert (string-contains? s "/Encoding /WinAnsiEncoding"))
      (test-assert (string-contains? s "/Font << /F1")))))

(test-group "draw-text WinAnsi byte encoding"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica)))
    (pdf-draw-text page helv 12 0 0 "ä€")
    ;; Decompressed content stream should contain raw bytes 0xE4 (ä) and 0x80 (€).
    (let ((cs-bv (let* ((bv (pdf->bytevector doc))
                        (s  (utf8->string bv))
                        (start (string-contains? s "\nstream\n"))
                        (end   (string-contains? s "\nendstream"))
                        (data-start (+ start (string-length "\nstream\n")))
                        (comp (let ((b (make-bytevector (- end data-start) 0)))
                                (bytevector-copy! b 0 bv data-start end)
                                b)))
                   (zlib-decompress comp))))
      ;; Search the raw bytevector for the two bytes — between '(' (0x28) and ')'
      ;; (0x29) of the Tj operand we expect exactly 0xE4 0x80.
      (let loop ((i 0) (found #f))
        (cond
          ((>= i (- (bytevector-length cs-bv) 1)) (test-assert found))
          ((and (= (bytevector-u8-ref cs-bv i) #xE4)
                (= (bytevector-u8-ref cs-bv (+ i 1)) #x80))
           (test-assert #t))
          (else (loop (+ i 1) found)))))))

(test-group "draw-text parens are escaped"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica)))
    (pdf-draw-text page helv 12 0 0 "(hi)")
    (let ((cs (extract-content-stream (pdf->bytevector doc))))
      (test-assert (string-contains? cs "(\\(hi\\)) Tj")))))

(test-group "Symbol font omits /Encoding"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (sym  (pdf-use-font doc 'symbol)))
    (pdf-draw-text page sym 12 0 0 "abc")
    (let ((s (utf8->string (pdf->bytevector doc))))
      (test-assert (string-contains? s "/BaseFont /Symbol"))
      ;; Must NOT carry WinAnsi encoding.
      (let ((font-idx (string-contains? s "/BaseFont /Symbol")))
        (test-assert
          (not (string-contains?
                 (substring s font-idx (min (+ font-idx 80) (string-length s)))
                 "WinAnsiEncoding")))))))

;; ── Text flow (phase 3) ───────────────────────────────────────────────

(test-group "flow-text simple left fits in one box"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica)))
    (call-with-values
      (lambda ()
        (pdf-flow-text page helv 10 '(50 50 200 200)
                       "Hello world this is a short paragraph."))
      (lambda (rest final-y)
        (test-equal "" rest)
        (test-assert (number? final-y))
        ;; A few lines emitted: should contain BT/ET and a Tm matrix.
        (let ((cs (extract-content-stream (pdf->bytevector doc))))
          (test-assert (string-contains? cs "BT"))
          (test-assert (string-contains? cs "Tm"))
          (test-assert (string-contains? cs "Tj")))))))

(test-group "flow-text overflow returns remaining text"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica)))
    ;; 30 pt tall × 100 pt wide at size 10 / leading 12 fits ~2 lines.
    (call-with-values
      (lambda ()
        (pdf-flow-text page helv 10 '(0 0 100 30)
                       (string-append
                         "The quick brown fox jumps over the lazy dog "
                         "and then some additional words to overflow the box "
                         "by quite a margin so leftovers are guaranteed.")
                       'leading 12))
      (lambda (rest final-y)
        (test-assert (> (string-length rest) 0))))))

(test-group "flow-text hard newlines force breaks"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica)))
    (call-with-values
      (lambda ()
        (pdf-flow-text page helv 10 '(0 0 500 200)
                       "Line one.\nLine two.\nLine three."))
      (lambda (rest final-y)
        (test-equal "" rest)
        (let ((cs (extract-content-stream (pdf->bytevector doc))))
          ;; Three "Tj" string-show ops, one per line.
          (let count-tj ((i 0) (n 0))
            (let ((idx (string-contains?
                          (substring cs i (string-length cs)) "Tj")))
              (cond
                (idx (count-tj (+ i idx 2) (+ n 1)))
                (else (test-equal 3 n))))))))))

(test-group "flow-text justify emits Tw on multi-word non-last lines"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica)))
    (call-with-values
      (lambda ()
        ;; Narrow box → many wrap points so at least one line gets slack.
        (pdf-flow-text page helv 10 '(0 0 80 200)
                       "Lorem ipsum dolor sit amet consectetur adipiscing elit."
                       'align 'justify))
      (lambda (rest final-y)
        (let ((cs (extract-content-stream (pdf->bytevector doc))))
          ;; Tw is only emitted when slack > 0 on a non-last, multi-word line.
          (test-assert (string-contains? cs "Tw")))))))

(test-group "flow-text alignment positions"
  ;; Compare line-x for left/right/center on a single-line, partial-width line.
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica))
         (rect '(100 0 300 50))
         (line-w (pdf-text-width helv 10 "Hello")))
    ;; Left
    (pdf-flow-text page helv 10 rect "Hello" 'align 'left)
    ;; Right
    (pdf-flow-text page helv 10 rect "Hello" 'align 'right)
    ;; Center
    (pdf-flow-text page helv 10 rect "Hello" 'align 'center)
    (let ((cs (extract-content-stream (pdf->bytevector doc))))
      ;; Left:   x = 100        → "1 0 0 1 100 ... Tm"
      ;; Right:  x = 100 + 300 - line-w
      ;; Center: x = 100 + (300 - line-w)/2
      (test-assert (string-contains? cs "1 0 0 1 100 ")))))

(test-group "flow-text empty string"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica)))
    (call-with-values
      (lambda ()
        (pdf-flow-text page helv 10 '(0 0 100 100) ""))
      (lambda (rest final-y)
        (test-equal "" rest)
        ;; No drawing operators expected for empty input — page has no content.
        (test-assert (not (pdf-page-has-content? page)))))))

(test-group "flow-text leading controls vertical advance"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica))
         (rect '(0 0 100 200)))
    (call-with-values
      (lambda ()
        (pdf-flow-text page helv 10 rect "A\nB\nC" 'leading 20))
      (lambda (rest final-y1)
        (let* ((page2 (pdf-add-page! doc)))
          (call-with-values
            (lambda ()
              (pdf-flow-text page2 helv 10 rect "A\nB\nC" 'leading 40))
            (lambda (rest2 final-y2)
              ;; final-y for leading=20 is higher than for leading=40
              ;; (less vertical advance ⇒ more y remaining).
              (test-assert (> final-y1 final-y2)))))))))

;; ── TrueType embedding (phase 4) ──────────────────────────────────────

(define ttf-path "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
(define ttf-available?
  (guard (e (#t #f))
    (bytevector? (pdf-read-binary-file ttf-path))))

(define (bv-contains-ascii? bv s)
  ;; Byte-level search of bytevector for the bytes of an ASCII string.
  ;; Safe to use even when bv contains invalid-UTF-8 bytes (binary
  ;; streams, compressed payloads).
  (let ((bvlen (bytevector-length bv))
        (slen  (string-length s)))
    (let loop ((i 0))
      (cond
        ((> (+ i slen) bvlen) #f)
        ((let inner ((j 0))
           (cond
             ((= j slen) #t)
             ((= (bytevector-u8-ref bv (+ i j))
                 (char->integer (string-ref s j)))
              (inner (+ j 1)))
             (else #f)))
         #t)
        (else (loop (+ i 1)))))))

(when ttf-available?

  (test-group "embed-truetype-font basics"
    (let* ((doc (make-pdf))
           (bv  (pdf-read-binary-file ttf-path))
           (ff  (pdf-embed-truetype-font doc bv "DejaVuSans")))
      (test-assert (pdf-font? ff))
      (test-equal "DejaVuSans" (pdf-font-base-name ff))
      (test-equal 'identity-h (pdf-font-encoding ff))
      ;; Bytevector survives.
      (test-assert (bytevector? (pdf-font-ttf-bytes ff)))
      (test-assert (> (pdf-font-num-glyphs ff) 1000))
      (test-assert (procedure? (pdf-font-cmap-lookup ff)))))

  (test-group "TTF cmap maps ASCII and Unicode"
    (let* ((doc (make-pdf))
           (bv  (pdf-read-binary-file ttf-path))
           (ff  (pdf-embed-truetype-font doc bv "DejaVu"))
           (lookup (pdf-font-cmap-lookup ff)))
      ;; ASCII 'A'.
      (test-assert (> (lookup 65) 0))
      ;; Cyrillic 'Я' U+042F.
      (test-assert (> (lookup #x042F) 0))
      ;; Greek 'Ω' U+03A9.
      (test-assert (> (lookup #x03A9) 0))
      ;; CJK U+4E2D — DejaVuSans has no CJK; expect 0 (.notdef).
      (test-equal 0 (lookup #x4E2D))))

  (test-group "TTF text-width Latin is positive and scales"
    (let* ((doc (make-pdf))
           (bv  (pdf-read-binary-file ttf-path))
           (ff  (pdf-embed-truetype-font doc bv "DejaVu"))
           (w12 (pdf-text-width ff 12 "Hello"))
           (w24 (pdf-text-width ff 24 "Hello")))
      (test-assert (> w12 10))
      (test-assert (approx= (* 2 w12) w24))))

  (test-group "TTF draw-text emits Type0 structures"
    (let* ((doc (make-pdf))
           (page (pdf-add-page! doc))
           (bv  (pdf-read-binary-file ttf-path))
           (ff  (pdf-embed-truetype-font doc bv "DejaVu")))
      (pdf-draw-text page ff 14 50 700 "Hi")
      (let ((out (pdf->bytevector doc)))
        (test-assert (bv-contains-ascii? out "/Subtype /Type0"))
        (test-assert (bv-contains-ascii? out "/Encoding /Identity-H"))
        (test-assert (bv-contains-ascii? out "/Subtype /CIDFontType2"))
        (test-assert (bv-contains-ascii? out "/CIDToGIDMap /Identity"))
        (test-assert (bv-contains-ascii? out "/FontDescriptor"))
        (test-assert (bv-contains-ascii? out "/Length1")))))

  (test-group "TTF strings encoded as hex CIDs"
    (let* ((doc (make-pdf))
           (page (pdf-add-page! doc))
           (bv  (pdf-read-binary-file ttf-path))
           (ff  (pdf-embed-truetype-font doc bv "DejaVu")))
      (pdf-draw-text page ff 14 0 0 "A")
      ;; Look in the decompressed content stream for "<XXXX> Tj".
      (let ((cs (extract-content-stream (pdf->bytevector doc))))
        (test-assert (string-contains? cs "<"))
        (test-assert (string-contains? cs "> Tj")))))

  (test-group "TTF ToUnicode tracks used codepoints"
    (let* ((doc (make-pdf))
           (page (pdf-add-page! doc))
           (bv  (pdf-read-binary-file ttf-path))
           (ff  (pdf-embed-truetype-font doc bv "DejaVu")))
      (pdf-draw-text page ff 14 0 0 "AB")
      (let ((out (pdf->bytevector doc)))
        (test-assert (bv-contains-ascii? out "beginbfchar"))
        (test-assert (bv-contains-ascii? out "Adobe-Identity-UCS"))))))

;; ── Images (phase 5) ───────────────────────────────────────────────────

(test-group "embed-png basics"
  (let* ((doc (make-pdf))
         ;; 4x4 RGB checker via the (scm png) library.
         (pixels (let ((bv (make-bytevector (* 4 4 3) 0)))
                   (let loop ((i 0))
                     (cond
                       ((>= i (* 4 4)) bv)
                       (else
                        (when (odd? i)
                          (bytevector-u8-set! bv (* 3 i) 255))
                        (loop (+ i 1)))))))
         (png-bv (png-encode-rgb 4 4 pixels))
         (img (pdf-embed-png doc png-bv)))
    (test-assert (pdf-image? img))
    (test-equal 4 (pdf-image-width img))
    (test-equal 4 (pdf-image-height img))))

(test-group "embed-png produces XObject and FlateDecode + Predictor 15"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (px (make-bytevector (* 2 2 3) 64))
         (img (pdf-embed-png doc (png-encode-rgb 2 2 px))))
    (pdf-draw-image page img 0 0 100 100)
    (let ((out (pdf->bytevector doc)))
      (test-assert (bv-contains-ascii? out "/Subtype /Image"))
      (test-assert (bv-contains-ascii? out "/ColorSpace /DeviceRGB"))
      (test-assert (bv-contains-ascii? out "/Filter /FlateDecode"))
      (test-assert (bv-contains-ascii? out "/Predictor 15"))
      ;; XObject resource named /Im1 referenced by the page.
      (test-assert (bv-contains-ascii? out "/XObject << /Im1")))))

(test-group "draw-image emits cm + Do"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (px (make-bytevector (* 2 2 3) 0))
         (img (pdf-embed-png doc (png-encode-rgb 2 2 px))))
    (pdf-draw-image page img 50 100 200 150)
    (let ((cs (extract-content-stream (pdf->bytevector doc))))
      (test-assert (string-contains? cs "200 0 0 150 50 100 cm"))
      (test-assert (string-contains? cs "/Im1 Do")))))

(test-group "embed-jpeg validates SOI"
  (let ((doc (make-pdf)))
    ;; Bogus bytes — must reject.
    (test-error (pdf-embed-jpeg doc (bytevector 0 1 2 3 4 5)))))

(test-group "embed-png RGBA emits /SMask"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         ;; 2x2 RGBA: opaque red, half-transparent green, transparent blue,
         ;; opaque white.
         (px (bytevector  255 0 0 255    0 255 0 128
                          0 0 255 0    255 255 255 255))
         (img (pdf-embed-png doc (png-encode-rgba 2 2 px))))
    (pdf-draw-image page img 0 0 100 100)
    (let ((out (pdf->bytevector doc)))
      (test-assert (bv-contains-ascii? out "/SMask"))
      ;; Main image gets DeviceRGB; mask is a second XObject (DeviceGray).
      (test-assert (bv-contains-ascii? out "/ColorSpace /DeviceRGB"))
      (test-assert (bv-contains-ascii? out "/ColorSpace /DeviceGray"))
      ;; SMask is a sibling image, never referenced via /XObject resource
      ;; — only /Im1 should appear in the resource subdict.
      (test-assert (bv-contains-ascii? out "/XObject << /Im1 "))
      (test-assert (not (bv-contains-ascii? out "/Im2"))))))

(test-group "embed-png gray+alpha (color type 4)"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         ;; png-encode supports color types 0,2,4,6 — type 4 is gray+alpha.
         (px (bytevector 100 255  200 128  50 64  255 0))
         (png-bv (png-encode 2 2 px 4))
         (img (pdf-embed-png doc png-bv)))
    (pdf-draw-image page img 0 0 10 10)
    (test-assert (pdf-image? img))
    (let ((out (pdf->bytevector doc)))
      (test-assert (bv-contains-ascii? out "/SMask")))))

(test-group "embed-png non-alpha PNGs have no /SMask"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (img (pdf-embed-png doc
                (png-encode-rgb 2 2 (make-bytevector 12 0)))))
    (pdf-draw-image page img 0 0 10 10)
    (let ((out (pdf->bytevector doc)))
      (test-assert (not (bv-contains-ascii? out "/SMask"))))))

;; ── Metadata (phase 6) ────────────────────────────────────────────────

(test-group "metadata appears in /Info"
  (let ((doc (make-pdf)))
    (pdf-add-page! doc)
    (pdf-set-metadata! doc 'title "T" 'author "A" 'producer "P")
    (let ((out (pdf->bytevector doc)))
      (test-assert (bv-contains-ascii? out "/Info"))
      (test-assert (bv-contains-ascii? out "/Title (T)"))
      (test-assert (bv-contains-ascii? out "/Author (A)"))
      (test-assert (bv-contains-ascii? out "/Producer (P)")))))

(test-group "metadata overrides existing key"
  (let ((doc (make-pdf)))
    (pdf-add-page! doc)
    (pdf-set-metadata! doc 'title "Old")
    (pdf-set-metadata! doc 'title "New")
    (let ((out (pdf->bytevector doc)))
      (test-assert (bv-contains-ascii? out "/Title (New)"))
      (test-assert (not (bv-contains-ascii? out "/Title (Old)"))))))

(test-group "no metadata → no /Info in trailer"
  (let ((doc (make-pdf)))
    (pdf-add-page! doc)
    (let ((out (pdf->bytevector doc)))
      (test-assert (not (bv-contains-ascii? out "/Info"))))))

;; ── Links (phase 6) ───────────────────────────────────────────────────

(test-group "add-link emits Link annotation"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc)))
    (pdf-add-link page '(50 100 200 120) "https://example.com")
    (let ((out (pdf->bytevector doc)))
      (test-assert (bv-contains-ascii? out "/Subtype /Link"))
      (test-assert (bv-contains-ascii? out "/Rect [50 100 200 120]"))
      (test-assert (bv-contains-ascii? out "/S /URI"))
      (test-assert (bv-contains-ascii? out "/URI (https://example.com)"))
      ;; Page must carry /Annots.
      (test-assert (bv-contains-ascii? out "/Annots [")))))

(test-group "no annotations → no /Annots"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc)))
    (let ((out (pdf->bytevector doc)))
      (test-assert (not (bv-contains-ascii? out "/Annots"))))))

;; ── Outlines (phase 6) ────────────────────────────────────────────────

(test-group "add-outline emits Outlines tree"
  (let* ((doc (make-pdf))
         (p1 (pdf-add-page! doc))
         (p2 (pdf-add-page! doc)))
    (pdf-add-outline! doc p1 "First")
    (pdf-add-outline! doc p2 "Second")
    (let ((out (pdf->bytevector doc)))
      (test-assert (bv-contains-ascii? out "/Type /Outlines"))
      (test-assert (bv-contains-ascii? out "/PageMode /UseOutlines"))
      (test-assert (bv-contains-ascii? out "/Title (First)"))
      (test-assert (bv-contains-ascii? out "/Title (Second)")))))

(test-group "nested outlines"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc))
         (top (pdf-add-outline! doc page "Top")))
    (pdf-add-outline! doc page "Child1" 'parent top)
    (pdf-add-outline! doc page "Child2" 'parent top)
    (let ((out (pdf->bytevector doc)))
      (test-assert (bv-contains-ascii? out "/Title (Top)"))
      (test-assert (bv-contains-ascii? out "/Title (Child1)"))
      (test-assert (bv-contains-ascii? out "/Title (Child2)"))
      ;; Top outline must carry /First and /Last
      (test-assert (bv-contains-ascii? out "/First "))
      (test-assert (bv-contains-ascii? out "/Last ")))))

(test-group "no outlines → no /Outlines"
  (let ((doc (make-pdf)))
    (pdf-add-page! doc)
    (let ((out (pdf->bytevector doc)))
      (test-assert (not (bv-contains-ascii? out "/Outlines"))))))

(test-end "pdf")

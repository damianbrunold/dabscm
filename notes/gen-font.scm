;; Generates the font libraries of dabscm: the glyph outlines, advances
;; and kerning of a font family for the characters below, extracted with
;; (scm truetype) so that text can be rendered without a font file.
;;
;; Usage (from the repository root):
;;   scm notes/gen-font.scm dejavu [directory-with-the-ttf-files]
;;   scm notes/gen-font.scm inter directory-with-the-ttf-files
;;   scm notes/gen-font.scm roboto-slab directory-with-the-ttf-files
;;
;;   dejavu  scm-lib/libraries/scm-fonts-dejavu.sld: DejaVu Sans and Sans
;;           Bold. The directory defaults to /usr/share/fonts/truetype/dejavu
;;           (Debian's fonts-dejavu-core).
;;   inter   scm-lib/libraries/scm-fonts-inter.sld: Inter Regular and
;;           Black, with the OpenType features below applied. The directory
;;           holds Inter-Regular.ttf, Inter-Black.ttf and LICENSE.txt, as in
;;           extras/ttf/ and the root of the Inter release zip
;;           (https://github.com/rsms/inter/releases, 4.1 for the current
;;           file); LICENSE.txt is copied into the library.
;;   roboto-slab  scm-lib/libraries/scm-fonts-roboto-slab.sld: Roboto Slab
;;           Regular and Bold. The directory holds RobotoSlab-Regular.ttf,
;;           RobotoSlab-Bold.ttf (fonts/ttf/) and LICENSE.txt of
;;           https://github.com/googlefonts/robotoslab (version 2.002, commit
;;           67af3ce for the current file); LICENSE.txt is copied into the
;;           library.
;;
;; Composite glyphs are resolved into plain contours and coordinates
;; rounded to font units; features and kerning are resolved too, so the
;; library holds the glyphs as they are drawn.

(import (scheme base)
        (scheme char)
        (scheme write)
        (scheme file)
        (scheme process-context)
        (scm module)
        (srfi 1))

(define root
  (let* ((s (car (command-line)))
         (i (let loop ((i (- (string-length s) 1)))
              (cond ((< i 0) #f)
                    ((char=? (string-ref s i) #\/) i)
                    (else (loop (- i 1)))))))
    ;; notes/ is one level below the root
    (string-append (if i (substring s 0 i) ".") "/..")))

(module-search-path! (cons (string-append root "/scm-lib/libraries") (module-search-path)))
(import (scm truetype))

(define family
  (if (> (length (command-line)) 1)
      (cadr (command-line))
      (begin (display "Usage: scm notes/gen-font.scm dejavu|inter|roboto-slab [directory]\n"
                      (current-error-port))
             (exit 2))))

(define font-dir
  (cond ((> (length (command-line)) 2) (caddr (command-line)))
        ((string=? family "dejavu") "/usr/share/fonts/truetype/dejavu")
        (else (display (string-append family " needs the directory of the ttf files\n") (current-error-port))
              (exit 2))))

;; The features the canton of Zurich's web design system prescribes for
;; Inter (ss07 square punctuation, ss08 square quotes, cv03 open six,
;; cv04 open nine, cv10 capital G with spur), and tnum, the tabular
;; figures its infographic rules ask for ("Versalziffern gleicher
;; Breite"). See the dashboards project's docs/design.md for the sources.
(define inter-features '("ss07" "ss08" "cv03" "cv04" "cv10" "tnum"))

(define (range a b) (map integer->char (iota (+ (- b a) 1) a)))

;; ASCII, Latin-1, the rest of Windows-1252, and what charts and
;; dashboards use: typographic quotes and dashes, the Swiss thousands
;; separator (U+2019), thin and narrow spaces, minus, arrows, comparisons,
;; and superscript and subscript digits (m², NO₂, CO₂); and modern Greek
;; (with tonos and dialytika, also for symbols such as Δ, μ, σ) and
;; Cyrillic (U+0400 to U+045F: Russian, Ukrainian, Belarusian, Serbian,
;; Macedonian, Bulgarian; plus Ґ ґ).
(define charset
  (delete-duplicates
   (append (range #x20 #x7E)
           (range #xA0 #xFF)
           (list (integer->char #x2070))
           (range #x2074 #x2079)
           (range #x2080 #x2089)
           (map integer->char
                '(#x152 #x153 #x160 #x161 #x178 #x17D #x17E #x192 #x2C6 #x2DC
                  #x2007 #x2009 #x200A #x202F
                  #x2010 #x2011 #x2012 #x2013 #x2014 #x2015
                  #x2018 #x2019 #x201A #x201C #x201D #x201E
                  #x2020 #x2021 #x2022 #x2026 #x2030 #x2032 #x2033 #x2039 #x203A
                  #x20AC #x2122 #x2190 #x2191 #x2192 #x2193 #x2212 #x2248 #x2260
                  #x2264 #x2265 #x221E #x25B2 #x25BC #x25CF))
           ;; Greek: tonos, the accented capitals, the alphabets
           (range #x384 #x38A)
           (list (integer->char #x38C))
           (range #x38E #x3A1)
           (range #x3A3 #x3CE)
           ;; Cyrillic
           (range #x400 #x45F)
           (list (integer->char #x490) (integer->char #x491)))))

(define (read-text name)
  (call-with-input-file (string-append font-dir "/" name)
    (lambda (p) (let loop ((acc '()))
                  (let ((s (read-string 65536 p)))
                    (if (eof-object? s) (apply string-append (reverse acc)) (loop (cons s acc))))))))

(define (comment-lines text)
  (apply string-append
         (map (lambda (line)
                (if (string=? line "") ";;\n" (string-append ";;   " line "\n")))
              (split-lines text))))

(define (split-lines s)
  (let loop ((i 0) (start 0) (acc '()))
    (cond ((= i (string-length s))
           (reverse (if (< start i) (cons (substring s start i) acc) acc)))
          ((char=? (string-ref s i) #\newline)
           (loop (+ i 1) (+ i 1)
                 (cons (let ((l (substring s start i)))
                         (if (and (> (string-length l) 0)
                                  (char=? (string-ref l (- (string-length l) 1)) #\return))
                             (substring l 0 (- (string-length l) 1))
                             l))
                       acc)))
          (else (loop (+ i 1) start acc)))))

(define (load-ttf name)
  (let ((path (string-append font-dir "/" name)))
    (call-with-port (open-binary-input-file path)
      (lambda (p) (read-bytevector 10000000 p)))))

;; contour -> vector x0 y0 f0 x1 y1 f1 ..., f 1 for on-curve
(define (pack contour)
  (list->vector
   (append-map (lambda (pt)
                 (list (exact (round (car pt))) (exact (round (cadr pt)))
                       (if (caddr pt) 1 0)))
               contour)))

(define (glyph-data font)
  (filter-map (lambda (c)
                (let ((g (font-glyph font c)))
                  (and g (cons* c (car g) (map pack (cdr g))))))
              charset))

;; the script of a letter (latin, greek, cyrillic), or #f for anything
;; else (digits, punctuation, symbols, spaces)
(define (script c)
  (let ((n (char->integer c)))
    (cond ((and (>= n #x370) (< n #x400)) 'greek)
          ((and (>= n #x400) (< n #x530)) 'cyrillic)
          ((and (char-alphabetic? c) (< n #x370)) 'latin)
          (else #f))))

;; Pairs of letters from two different scripts never meet in text: their
;; kerning is left out (it would more than double the tables).
(define (kerning-data font)
  (let ((chars (filter (lambda (c) (font-glyph font c)) charset)))
    (append-map (lambda (a)
                  (filter-map (lambda (b)
                                (let ((sa (script a)) (sb (script b)))
                                  (and (or (not sa) (not sb) (eq? sa sb))
                                       (let ((k (font-kerning font a b)))
                                         (and (not (= k 0)) (list a b k))))))
                              chars))
                chars)))

;; ASCII graphic characters as themselves, everything else as #\xHEX, so
;; the file reads the same on every implementation
(define (char-literal c)
  (let ((n (char->integer c)))
    (cond ((= n 32) "#\\space")
          ((< 32 n 127) (string #\# #\\ c))
          (else (string-append "#\\x" (number->string n 16))))))

(define (emit-font port name font)
  (let ((glyphs (glyph-data font))
        (kerning (kerning-data font)))
    (display (string-append "    ;; " name ": " (number->string (length glyphs))
                            " glyphs, " (number->string (length kerning))
                            " kerning pairs\n")
             (current-error-port))
    (write-string (string-append "    (define %" name "-metrics '") port)
    (write (list (font-units-per-em font) (font-ascent font) (font-descent font)) port)
    (write-string ")\n" port)
    (write-string (string-append "    (define %" name "-glyphs '(\n") port)
    (for-each (lambda (g)
                (write-string (string-append "      (" (char-literal (car g)) " ") port)
                (write (cadr g) port)
                (for-each (lambda (v) (write-string " " port) (write v port)) (cddr g))
                (write-string ")\n" port))
              glyphs)
    (write-string "      ))\n" port)
    (write-string (string-append "    (define %" name "-kerning '(\n") port)
    (let loop ((ks kerning) (i 0))
      (unless (null? ks)
        (when (= 0 (modulo i 6)) (write-string "      " port))
        (let ((k (car ks)))
          (write-string (string-append "(" (char-literal (car k)) " " (char-literal (cadr k))
                                       " " (number->string (caddr k)) ")")
                        port))
        (write-string (if (= 5 (modulo i 6)) "\n" " ") port)
        (loop (cdr ks) (+ i 1))))
    (write-string "\n      ))\n\n" port)))

(define dejavu-header "\
;; (scm fonts dejavu) — DejaVu Sans and DejaVu Sans Bold, as fonts for
;; (scm truetype), so text can be rendered without a font file.
;;
;; GENERATED by notes/gen-font.scm from the DejaVu fonts; do not
;; edit by hand. Covers ASCII, Latin-1, the rest of Windows-1252, some
;; typographic characters (quotes, dashes, spaces, minus, arrows),
;; superscript and subscript digits, Greek and Cyrillic; other characters
;; are drawn as \"?\".
;; Hinting is not included.
;;
;; The glyph data is a subset of the DejaVu fonts, under their licence:
;;
;;   Copyright (c) 2003 by Bitstream, Inc. All Rights Reserved.
;;   Bitstream Vera is a trademark of Bitstream, Inc.
;;   DejaVu changes are in public domain.
;;
;;   Permission is hereby granted, free of charge, to any person obtaining
;;   a copy of the fonts accompanying this license (\"Fonts\") and
;;   associated documentation files (the \"Font Software\"), to reproduce
;;   and distribute the Font Software, including without limitation the
;;   rights to use, copy, merge, publish, distribute, and/or sell copies
;;   of the Font Software, and to permit persons to whom the Font Software
;;   is furnished to do so, subject to the following conditions:
;;
;;   The above copyright and trademark notices and this permission notice
;;   shall be included in all copies of one or more of the Font Software
;;   typefaces.
;;
;;   The Font Software may be modified, altered, or added to, and in
;;   particular the designs of glyphs or characters in the Fonts may be
;;   modified and additional glyphs or characters may be added to the
;;   Fonts, only if the fonts are renamed to names not containing either
;;   the words \"Bitstream\" or the word \"Vera\".
;;
;;   This License becomes null and void to the extent applicable to Fonts
;;   or Font Software that has been modified and is distributed under the
;;   \"Bitstream Vera\" names.
;;
;;   The Font Software may be sold as part of a larger software package
;;   but no copy of one or more of the Font Software typefaces may be sold
;;   by itself.
;;
;;   THE FONT SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND,
;;   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
;;   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
;;   OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL
;;   BITSTREAM OR THE GNOME FOUNDATION BE LIABLE FOR ANY CLAIM, DAMAGES OR
;;   OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL,
;;   OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR
;;   OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT
;;   SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.
;;
;;   Except as contained in this notice, the names of Gnome, the Gnome
;;   Foundation, and Bitstream Inc., shall not be used in advertising or
;;   otherwise to promote the sale, use or other dealings in this Font
;;   Software without prior written authorization from the Gnome
;;   Foundation or Bitstream Inc., respectively.

(define-library (scm fonts dejavu)
  (export dejavu-sans
          dejavu-sans-bold)
  (import (scheme base)
          (scm truetype))
  (begin

")

(define (inter-header license)
  (string-append "\
;; (scm fonts inter) — Inter Regular and Inter Black, as fonts for
;; (scm truetype), so text can be rendered without a font file.
;;
;; GENERATED by notes/gen-font.scm from the Inter 4.1 release; do not edit
;; by hand. Covers ASCII, Latin-1, the rest of Windows-1252, some
;; typographic characters (quotes, dashes, spaces, minus, arrows),
;; superscript and subscript digits, Greek and Cyrillic; other characters
;; are drawn as \"?\".
;; Hinting is not included.
;;
;; The glyphs are those with these OpenType features applied:
;;   "
                 (fold (lambda (f acc) (string-append acc " " f))
                       (car inter-features) (cdr inter-features))
                 "
;; as the canton of Zurich's web design system sets Inter (and tabular
;; figures for charts). The kerning is Inter's GPOS pair kerning.
;;
;; The glyph data is a subset of Inter, under its licence. Inter declares
;; no Reserved Font Name, so the subset keeps its name.
;;
" (comment-lines license) "
(define-library (scm fonts inter)
  (export inter-regular
          inter-black)
  (import (scheme base)
          (scm truetype))
  (begin

"))

(define (footer names)
  (string-append "\
    ;; (x0 y0 f0 x1 ...) -> ((x0 y0 on?) ...)
    (define (unpack v)
      (let loop ((i (- (vector-length v) 3)) (acc '()))
        (if (< i 0)
            acc
            (loop (- i 3)
                  (cons (list (vector-ref v i) (vector-ref v (+ i 1))
                              (= 1 (vector-ref v (+ i 2))))
                        acc)))))

    (define (build metrics glyphs kerning)
      (make-outline-font
       (car metrics) (cadr metrics) (caddr metrics)
       (map (lambda (g) (cons* (car g) (cadr g) (map unpack (cddr g)))) glyphs)
       (map (lambda (k) (cons (cons (car k) (cadr k)) (caddr k))) kerning)))

    (define (cons* a b . rest)
      (if (null? rest) (cons a b) (cons a (apply cons* b rest))))

    (define (caddr l) (car (cddr l)))

" (apply string-append
         (map (lambda (n)
                (string-append "    (define " (car n) " (build %" (cdr n) "-metrics %"
                               (cdr n) "-glyphs %" (cdr n) "-kerning))\n"))
              names))
"
))
"))

;; Roboto Slab is set as it comes: no features, its GPOS kerning.
(define (roboto-slab-header license)
  (string-append "\
;; (scm fonts roboto-slab) — Roboto Slab Regular and Roboto Slab Bold, as
;; fonts for (scm truetype), so text can be rendered without a font file.
;;
;; GENERATED by notes/gen-font.scm from Roboto Slab 2.002; do not edit by
;; hand. Covers ASCII, Latin-1, the rest of Windows-1252, some
;; typographic characters (quotes, dashes, spaces, minus, arrows),
;; superscript and subscript digits, Greek and Cyrillic; other characters
;; are drawn as \"?\".
;; Hinting is not included. The kerning is Roboto Slab's GPOS pair
;; kerning.
;;
;; The glyph data is a subset of Roboto Slab, under its licence, the
;; Apache License 2.0:
;;
;;   Copyright 2018 The Roboto Slab Project Authors
;;   (https://github.com/googlefonts/robotoslab)
;;   Roboto Slab is a trademark of Google.
;;
" (comment-lines license) "
(define-library (scm fonts roboto-slab)
  (export roboto-slab-regular
          roboto-slab-bold)
  (import (scheme base)
          (scm truetype))
  (begin

"))

;; family -> (library file, header, ((export . data name) (ttf file . features)) ...)
(define (generate out header fonts)
  (call-with-output-file out
    (lambda (port)
      (write-string header port)
      (for-each (lambda (f)
                  (emit-font port (cdar f)
                             (read-truetype (load-ttf (cadr f))
                                            (list (cons 'features (cddr f))))))
                fonts)
      (write-string (footer (map car fonts)) port)))
  (display (string-append "wrote " out "\n") (current-error-port)))

(define (library name) (string-append root "/scm-lib/libraries/scm-fonts-" name ".sld"))

(cond
 ((string=? family "dejavu")
  (generate (library "dejavu") dejavu-header
            (list (cons '("dejavu-sans" . "sans") '("DejaVuSans.ttf"))
                  (cons '("dejavu-sans-bold" . "sans-bold") '("DejaVuSans-Bold.ttf")))))
 ((string=? family "inter")
  (generate (library "inter") (inter-header (read-text "LICENSE.txt"))
            (list (cons '("inter-regular" . "regular") (cons "Inter-Regular.ttf" inter-features))
                  (cons '("inter-black" . "black") (cons "Inter-Black.ttf" inter-features)))))
 ((string=? family "roboto-slab")
  (generate (library "roboto-slab") (roboto-slab-header (read-text "LICENSE.txt"))
            (list (cons '("roboto-slab-regular" . "regular") (list "RobotoSlab-Regular.ttf"))
                  (cons '("roboto-slab-bold" . "bold") (list "RobotoSlab-Bold.ttf")))))
 (else (display "Unknown family; use dejavu, inter or roboto-slab\n" (current-error-port)) (exit 2)))

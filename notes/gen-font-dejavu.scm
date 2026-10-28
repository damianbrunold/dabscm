;; Generates scm-lib/libraries/scm-fonts-dejavu.sld: the glyph outlines,
;; advances and kerning of DejaVu Sans and DejaVu Sans Bold for the
;; characters below, extracted with (scm truetype) so that text can be
;; rendered without a font file.
;;
;; Usage (from the repository root):
;;   scm notes/gen-font-dejavu.scm [directory-with-the-ttf-files]
;;
;; The directory defaults to /usr/share/fonts/truetype/dejavu (Debian's
;; fonts-dejavu-core). Composite glyphs are resolved into plain contours
;; and coordinates rounded to font units.

(import (scheme base)
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

(define font-dir
  (if (> (length (command-line)) 1)
      (cadr (command-line))
      "/usr/share/fonts/truetype/dejavu"))

(define (range a b) (map integer->char (iota (+ (- b a) 1) a)))

;; ASCII, Latin-1, the rest of Windows-1252, and what charts and
;; dashboards use: typographic quotes and dashes, the Swiss thousands
;; separator (U+2019), thin and narrow spaces, minus, arrows, comparisons.
(define charset
  (delete-duplicates
   (append (range #x20 #x7E)
           (range #xA0 #xFF)
           (map integer->char
                '(#x152 #x153 #x160 #x161 #x178 #x17D #x17E #x192 #x2C6 #x2DC
                  #x2007 #x2009 #x200A #x202F
                  #x2010 #x2011 #x2012 #x2013 #x2014 #x2015
                  #x2018 #x2019 #x201A #x201C #x201D #x201E
                  #x2020 #x2021 #x2022 #x2026 #x2030 #x2032 #x2033 #x2039 #x203A
                  #x20AC #x2122 #x2190 #x2191 #x2192 #x2193 #x2212 #x2248 #x2260
                  #x2264 #x2265 #x221E #x25B2 #x25BC #x25CF)))))

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

(define (kerning-data font)
  (let ((chars (filter (lambda (c) (font-glyph font c)) charset)))
    (append-map (lambda (a)
                  (filter-map (lambda (b)
                                (let ((k (font-kerning font a b)))
                                  (and (not (= k 0)) (list a b k))))
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

(define header "\
;; (scm fonts dejavu) — DejaVu Sans and DejaVu Sans Bold, as fonts for
;; (scm truetype), so text can be rendered without a font file.
;;
;; GENERATED by notes/gen-font-dejavu.scm from the DejaVu fonts; do not
;; edit by hand. Covers ASCII, Latin-1, the rest of Windows-1252 and some
;; typographic characters (quotes, dashes, spaces, minus, arrows); other
;; characters are drawn as \"?\". Hinting is not included.
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

(define footer "\
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

    (define dejavu-sans (build %sans-metrics %sans-glyphs %sans-kerning))
    (define dejavu-sans-bold (build %sans-bold-metrics %sans-bold-glyphs %sans-bold-kerning))

))
")

(define out (string-append root "/scm-lib/libraries/scm-fonts-dejavu.sld"))

(call-with-output-file out
  (lambda (port)
    (write-string header port)
    (emit-font port "sans" (read-truetype (load-ttf "DejaVuSans.ttf")))
    (emit-font port "sans-bold" (read-truetype (load-ttf "DejaVuSans-Bold.ttf")))
    (write-string footer port)))

(display (string-append "wrote " out "\n") (current-error-port))

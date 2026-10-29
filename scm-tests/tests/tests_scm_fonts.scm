(import (scheme base)
        (scheme file)
        (scm test)
        (scm fs)
        (scm zip)
        (scm truetype)
        (scm fonts inter)
        (scm fonts dejavu)
        (scm fonts))

(test-runner-factory scm-test-runner)

(test-begin "scm fonts")

;; Font files made from the built-in fonts, so the tests need no font
;; package: "Inter" Regular and Black, "DejaVu Sans" Regular and Bold.

(define (write-file path bv)
  (call-with-port (open-binary-output-file path) (lambda (p) (write-bytevector bv p))))

(define inter-400 (font->truetype inter-regular "Inter" "Regular"))
(define inter-900 (font->truetype inter-black "Inter" "Black"))
(define dejavu-400 (font->truetype dejavu-sans "DejaVu Sans" "Regular"))
(define dejavu-700 (font->truetype dejavu-sans-bold "DejaVu Sans" "Bold"))

;; A directory without an index: fonts at the top and one level down,
;; a licence beside them, and a file that is not a font.
(define plain (mktempdir '(prefix . "scm-fonts-plain")))
(make-directory (join-path plain "inter"))
(write-file (join-path plain "inter" "Inter-Regular.ttf") inter-400)
(write-file (join-path plain "inter" "Inter-Black.ttf") inter-900)
(write-file (join-path plain "inter" "LICENSE.txt") (string->utf8 "Inter licence"))
(write-file (join-path plain "DejaVuSans.ttf") dejavu-400)
(write-file (join-path plain "broken.ttf") (string->utf8 "not a font"))

;; A zip with an index, which names faces as given (the index is trusted:
;; here it calls the DejaVu Bold file "Test Sans", italic).
(define zip-dir (mktempdir '(prefix . "scm-fonts-zip")))
(define zip-path (join-path zip-dir "fonts.zip"))
(let ((z (open-output-zip-file zip-path)))
  (for-each (lambda (e)
              (let ((p (zip-add-binary-entry z (car e))))
                (write-bytevector (cdr e) p)
                (flush-output-port p)))
            (list (cons "test/TestSans-BoldItalic.ttf" dejavu-700)
                  (cons "test/OFL.txt" (string->utf8 "Test licence"))
                  (cons "fonts-index.scm"
                        (string->utf8
                         "(((family . \"Test Sans\") (weight . 700) (italic . #t)
                            (file . \"test/TestSans-BoldItalic.ttf\") (license . \"test/OFL.txt\")))"))))
  (close-output-zip z))

(test-group "search path"
  (test-assert (list? (font-search-path)))
  (font-search-path! (list plain zip-path "/no/such/directory"))
  (test-equal (list plain zip-path "/no/such/directory") (font-search-path)))

(test-group "families and faces"
  (test-equal '("DejaVu Sans" "Inter" "Test Sans") (font-families))
  (test-equal '((400 #f) (900 #f)) (font-faces "Inter"))
  (test-equal '((400 #f) (900 #f)) (font-faces "inter"))
  (test-equal '((700 #t)) (font-faces "Test Sans"))
  (test-equal '() (font-faces "Nope")))

(test-group "find-font"
  (let ((f (find-font "Inter")))
    (test-assert (font? f))
    (test-equal (font-glyph inter-regular #\a) (font-glyph f #\a))
    ;; read once
    (test-assert (eq? f (find-font "Inter" 'regular 'normal))))
  ;; the nearest weight: 700 has none, the heavier 900 is next
  (test-equal (font-glyph inter-black #\a) (font-glyph (find-font "Inter" 'bold) #\a))
  ;; 300: the lighter side first, none, then the nearest heavier
  (test-equal (font-glyph inter-regular #\a) (font-glyph (find-font "Inter" 300) #\a))
  ;; no italic: the upright face
  (test-equal (font-glyph inter-regular #\a) (font-glyph (find-font "Inter" 400 'italic) #\a))
  ;; from the zip, by its index
  (test-equal (font-glyph dejavu-sans-bold #\a) (font-glyph (find-font "Test Sans" 400 'italic) #\a))
  (test-equal #f (find-font "Nope"))
  ;; options go to read-truetype: another font object
  (test-assert (not (eq? (find-font "Inter") (find-font "Inter" 400 'normal '((features "tnum"))))))
  (test-error (find-font "Inter" 'heavy))
  (test-error (find-font "Inter" 400 'oblique)))

(test-group "find-font-file"
  (test-equal inter-900 (find-font-file "Inter" 900))
  (test-equal dejavu-700 (find-font-file "Test Sans"))
  (test-equal '((family . "DejaVu Sans") (style . "Regular") (weight . 400) (italic . #f))
              (truetype-info (find-font-file "DejaVu Sans")))
  (test-equal #f (find-font-file "Nope")))

(test-group "licences"
  (test-equal "Inter licence" (font-license "Inter"))
  (test-equal "Test licence" (font-license "Test Sans"))
  (test-equal #f (font-license "DejaVu Sans"))
  (test-equal #f (font-license "Nope")))

(test-group "changing the path"
  (font-search-path! (list zip-path))
  (test-equal '("Test Sans") (font-families))
  (test-equal #f (find-font "Inter"))
  (font-search-path! '())
  (test-equal '() (font-families)))

(for-each (lambda (f) (delete-file (join-path plain "inter" f))) (directory-files (join-path plain "inter")))
(delete-directory (join-path plain "inter"))
(for-each (lambda (f) (delete-file (join-path plain f))) (directory-files plain))
(delete-directory plain)
(delete-file zip-path)
(delete-directory zip-dir)

(test-end "scm fonts")

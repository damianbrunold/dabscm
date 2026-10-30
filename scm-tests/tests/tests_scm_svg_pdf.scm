(import (scheme base) (srfi 13) (scm pdf) (scm svg pdf) (scm fonts dejavu) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm svg pdf")

(define (pdf-text bv)
  (let ((s (make-string (bytevector-length bv))))
    (do ((i 0 (+ i 1))) ((= i (bytevector-length bv)) s)
      (string-set! s i (integer->char (bytevector-u8-ref bv i))))))

(define svg
  "<svg xmlns='http://www.w3.org/2000/svg' width='200' height='100' viewBox='0 0 100 50'>
     <style>.a{fill:#2a78d6} .t{font-size:8px;font-weight:bold}</style>
     <rect class='a' x='5' y='5' width='40' height='20' rx='3'/>
     <path d='M50 5 A10 10 0 0 1 70 5 Z' fill='red' fill-opacity='0.5'/>
     <line x1='0' y1='45' x2='100' y2='45' stroke='black' stroke-dasharray='2 1'/>
     <g transform='rotate(-90 80 30)'><text x='80' y='30' class='t' text-anchor='middle'>Hi</text></g>
   </svg>")

(test-group "size"
  (call-with-values (lambda () (svg-size svg))
    (lambda (w h) (test-equal '(200 100) (list (exact w) (exact h))))))

(test-group "document"
  (let ((s (pdf-text (svg->pdf svg '((width . 400) (margin . 10))))))
    (test-assert (string-prefix? "%PDF-" s))
    (test-assert (string-contains s "/MediaBox [0 0 420 220]"))
    (test-assert (string-contains s "/FontFile2"))       ; text embedded as text
    (test-assert (string-contains s "/ca 0.5")))         ; fill opacity
  ;; a rotation leaves tiny values such as 6e-17 in the matrix: PDF has
  ;; no exponent notation (no text here, so no binary font data)
  (let ((s (pdf-text (svg->pdf "<svg width='10' height='10'><g transform='rotate(90 5 5)'><rect width='3' height='4'/></g></svg>"))))
    (test-assert (not (string-contains s "e-")))))

(test-group "on a page"
  (let* ((doc (make-pdf))
         (page (pdf-add-page! doc)))
    (call-with-values (lambda () (svg->pdf-page! doc page svg 50 800 '((width . 300))))
      (lambda (w h) (test-equal '(300 150) (list (exact (round w)) (exact (round h))))))
    ;; the same font is embedded once per document
    (test-assert (eq? (svg-pdf-font doc dejavu-sans) (svg-pdf-font doc dejavu-sans)))))

(test-end "scm svg pdf")

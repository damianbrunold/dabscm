(import (scheme base)
        (scheme write)
        (scm test)
        (scm qr))

(test-runner-factory scm-test-runner)

(test-begin "qr")

(test-group "matrix dimensions"
  ;; Version 1 → 21x21
  (let ((qm (qr-encode "hi" 'L)))
    (test-equal 21 (qr-matrix-size qm))
    (test-equal 1 (qr-matrix-version qm))
    (test-equal 0 (qr-matrix-ec-level qm)))
  ;; Version selection grows with data length.
  (let ((qm (qr-encode (make-string 100 #\x) 'M)))
    (test-assert (>= (qr-matrix-version qm) 6))
    (test-equal (+ 17 (* 4 (qr-matrix-version qm)))
                (qr-matrix-size qm))))

(test-group "finder patterns present"
  ;; The 7x7 finder pattern must appear at the three corners.
  (let ((qm (qr-encode "hello" 'M)))
    (define (finder-ok? y x)
      (and
        ;; outer ring dark
        (= 1 (qr-matrix-ref qm y x))
        (= 1 (qr-matrix-ref qm y (+ x 6)))
        (= 1 (qr-matrix-ref qm (+ y 6) x))
        (= 1 (qr-matrix-ref qm (+ y 6) (+ x 6)))
        ;; centre 3x3 dark
        (= 1 (qr-matrix-ref qm (+ y 3) (+ x 3)))))
    (test-assert (finder-ok? 0 0))
    (test-assert (finder-ok? 0 (- (qr-matrix-size qm) 7)))
    (test-assert (finder-ok? (- (qr-matrix-size qm) 7) 0))))

(test-group "always-dark module"
  ;; Position (4*v + 9, 8) is always dark.
  (let* ((qm (qr-encode "X" 'L))
         (v (qr-matrix-version qm)))
    (test-equal 1 (qr-matrix-ref qm (+ (* 4 v) 9) 8))))

(test-group "mask selection in range"
  (let ((qm (qr-encode "test" 'M)))
    (test-assert (<= 0 (qr-matrix-mask qm) 7))))

(test-group "renderings"
  (let ((qm (qr-encode "hi" 'M)))
    ;; PNG output is a non-empty bytevector starting with the PNG signature.
    (let ((png (qr->png qm 4 4)))
      (test-assert (bytevector? png))
      (test-equal #x89 (bytevector-u8-ref png 0))
      (test-equal #x50 (bytevector-u8-ref png 1)))
    ;; SVG output is a string containing an <svg ...> element.
    (let ((svg (qr->svg qm)))
      (test-assert (string? svg))
      (test-assert (> (string-length svg) 30)))
    ;; ASCII output is non-empty.
    (let ((s (qr->ascii qm)))
      (test-assert (string? s))
      (test-assert (> (string-length s) 0)))))

(test-group "error correction levels"
  (for-each
    (lambda (ec)
      (let ((qm (qr-encode "data" ec)))
        (test-assert (qr-matrix? qm))))
    '(L M Q H)))

(test-group "round-trip via bytevector"
  (let* ((bv (bytevector 1 2 3 4 5))
         (qm (qr-encode bv 'L)))
    (test-assert (qr-matrix? qm))))

(test-end "qr")

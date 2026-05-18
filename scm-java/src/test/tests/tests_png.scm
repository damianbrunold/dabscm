(import (scheme base)
        (scheme write)
        (scm test)
        (scm png))

(test-runner-factory scm-test-runner)

(test-begin "png")

(test-group "crc32"
  ;; Canonical "123456789" test vector.
  (test-equal #xCBF43926 (crc32 (string->utf8 "123456789")))
  ;; Empty bytevector → 0.
  (test-equal 0 (crc32 (make-bytevector 0 0)))
  ;; PNG IHDR test: CRC over "IEND" should be #xae426082.
  (test-equal #xAE426082 (crc32 (string->utf8 "IEND"))))

(test-group "png signature"
  (let ((bv (png-encode-grayscale 2 2 (bytevector 0 255 255 0))))
    ;; PNG signature: 8 bytes 89 50 4E 47 0D 0A 1A 0A
    (test-equal #x89 (bytevector-u8-ref bv 0))
    (test-equal #x50 (bytevector-u8-ref bv 1))
    (test-equal #x4E (bytevector-u8-ref bv 2))
    (test-equal #x47 (bytevector-u8-ref bv 3))
    (test-equal #x0D (bytevector-u8-ref bv 4))
    (test-equal #x0A (bytevector-u8-ref bv 5))
    (test-equal #x1A (bytevector-u8-ref bv 6))
    (test-equal #x0A (bytevector-u8-ref bv 7))))

(test-group "png chunks structure"
  ;; A correctly-built PNG ends with an IEND chunk: length=0, type=IEND, crc.
  (let ((bv (png-encode-grayscale 1 1 (bytevector 128))))
    (let ((len (bytevector-length bv)))
      ;; IEND chunk is 12 bytes at the end: 4 length + 4 type + 0 data + 4 crc
      (test-equal 0 (bytevector-u8-ref bv (- len 12)))
      (test-equal 0 (bytevector-u8-ref bv (- len 11)))
      (test-equal 0 (bytevector-u8-ref bv (- len 10)))
      (test-equal 0 (bytevector-u8-ref bv (- len  9)))
      (test-equal (char->integer #\I) (bytevector-u8-ref bv (- len 8)))
      (test-equal (char->integer #\E) (bytevector-u8-ref bv (- len 7)))
      (test-equal (char->integer #\N) (bytevector-u8-ref bv (- len 6)))
      (test-equal (char->integer #\D) (bytevector-u8-ref bv (- len 5))))))

(test-group "png ihdr width/height"
  ;; IHDR data starts at offset 16 (after sig + 4 length + 4 type "IHDR").
  (let ((bv (png-encode-rgb 5 3 (make-bytevector (* 5 3 3) 0))))
    ;; width big-endian at offset 16..19
    (test-equal 0 (bytevector-u8-ref bv 16))
    (test-equal 0 (bytevector-u8-ref bv 17))
    (test-equal 0 (bytevector-u8-ref bv 18))
    (test-equal 5 (bytevector-u8-ref bv 19))
    (test-equal 0 (bytevector-u8-ref bv 20))
    (test-equal 0 (bytevector-u8-ref bv 21))
    (test-equal 0 (bytevector-u8-ref bv 22))
    (test-equal 3 (bytevector-u8-ref bv 23))
    ;; bit depth = 8
    (test-equal 8 (bytevector-u8-ref bv 24))
    ;; color type = 2 (RGB)
    (test-equal 2 (bytevector-u8-ref bv 25))))

(test-group "png rgba"
  (let ((bv (png-encode-rgba 1 1 (bytevector 255 128 64 200))))
    ;; color type = 6
    (test-equal 6 (bytevector-u8-ref bv 25))
    ;; ensure it's nontrivially sized (signature + IHDR + IDAT + IEND)
    (test-assert (> (bytevector-length bv) 50))))

(test-group "png length mismatch errors"
  (test-error (png-encode 4 4 (bytevector 0 0 0) 0)))

(test-end "png")

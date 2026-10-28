;; Tests for (scm zip): writing and reading archives, files in pieces.

(import (scheme base)
        (scheme file)
        (scm test)
        (scm fs)
        (scm zip))

(test-runner-factory scm-test-runner)
(test-begin "scm zip")

(define dir (mktempdir '(prefix . "scm-zip-test")))
(define (path name) (string-append dir "/" name))

(define (write-bytes! file bv)
  (let ((p (open-binary-output-file file)))
    (write-bytevector bv p)
    (close-port p)))

(define (read-bytes file)
  (let* ((p (open-binary-input-file file))
         (bv (read-bytevector (file-size file) p)))
    (close-port p)
    (if (eof-object? bv) (bytevector) bv)))

;; 300 kB that compress well, and 1 kB of varied bytes
(define big (make-bytevector 300000 65))
(define small (let ((bv (make-bytevector 1000)))
                (do ((i 0 (+ i 1))) ((= i 1000) bv)
                  (bytevector-u8-set! bv i (modulo (* i 7) 256)))))
(write-bytes! (path "big.bin") big)
(write-bytes! (path "small.bin") small)

(test-group "writing"
  (call-with-output-zip (path "a.zip")
    (lambda (z)
      (let ((p (zip-add-text-entry z "readme.txt")))
        (write-string "Hallo" p)
        (flush-output-port p))          ; before the next entry, as with all text entries
      (zip-add-file-entry z "data/big.bin" (path "big.bin") #t)
      (zip-add-file-entry z "data/small.bin" (path "small.bin"))
      (zip-add-stored-entry z "stored.txt" (string->utf8 "abc"))))
  ;; the big file was deflated, the small one stored
  (test-assert (< (file-size (path "a.zip")) 100000)))

(test-group "reading"
  (call-with-input-zip (path "a.zip")
    (lambda (z)
      (test-equal '("readme.txt" "data/big.bin" "data/small.bin" "stored.txt") (zip-entry-names z))
      (test-equal 300000 (zip-entry-size z "data/big.bin"))
      (test-equal 1000 (zip-entry-size z "data/small.bin"))
      (test-equal small (zip-read-entry-bytevector z "data/small.bin"))
      (test-equal "Hallo" (utf8->string (zip-read-entry-bytevector z "readme.txt")))
      (test-equal 300000 (zip-extract-entry z "data/big.bin" (path "out.bin")))
      (test-equal big (read-bytes (path "out.bin")))
      (test-equal 1000 (zip-extract-entry z "data/small.bin" (path "out2.bin") 1000))
      ;; over the limit: an error, and no file left behind
      (test-error (zip-extract-entry z "data/big.bin" (path "out3.bin") 1000))
      (test-assert (not (file-exists? (path "out3.bin"))))
      (test-error (zip-entry-size z "missing"))
      (test-error (zip-extract-entry z "missing" (path "x"))))))

(for-each (lambda (f) (when (file-exists? (path f)) (delete-file (path f))))
          '("big.bin" "small.bin" "a.zip" "out.bin" "out2.bin"))
(delete-directory dir)

(test-end "scm zip")

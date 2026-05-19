(import (scheme base)
        (scheme file)
        (scheme write)
        (scm fs)
        (scm fs-find)
        (scm archive)
        (scm test)
        (srfi 1)
        (srfi 132))

(test-runner-factory scm-test-runner)

(define base (mktempdir '(prefix . "arch-test")))

(test-begin "scm-archive")

(let ((src (string-append base "/src")))
  (make-directory src)
  (call-with-port (open-output-file (string-append src "/one.txt"))
    (lambda (p) (display "hello\n" p)))
  (call-with-port (open-output-file (string-append src "/two.txt"))
    (lambda (p) (display "world\n" p)))

  (test-group "tar roundtrip"
    (cond
      ((which "tar")
       (let ((tgz (string-append base "/archive.tar.gz")))
         (test-equal #t (tar-create tgz (list src)))
         (test-equal #t (>= (length (tar-list tgz)) 2))
         (let ((out (string-append base "/out")))
           (make-directory out)
           (test-equal #t (tar-extract tgz `(work-dir . ,out)))
           (test-equal 2 (length (find out '(type . file)))))))
      (else
       (test-equal #t #t))))

  (test-group "gzip / gunzip"
    (let ((f (string-append base "/big")))
      (call-with-port (open-output-file f)
        (lambda (p) (display "abcabcabc" p)))
      (test-equal #t (gzip f 'keep))
      (test-equal #t (file-exists? (string-append f ".gz")))
      (test-equal #t (file-exists? f)))))

(rm base 'recursive)

(test-end "scm-archive")

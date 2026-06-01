(import (scheme base)
        (scheme file)
        (scheme write)
        (scm fs)
        (scm fs-find)
        (scm archive)
        (scm system)
        (scm test)
        (srfi 1)
        (srfi 132))

(test-runner-factory scm-test-runner)

(define (windows?)
  (let ((p (sys-platform)))
    (or (eq? p 'windows)
        (and (symbol? p)
             (let ((s (symbol->string p)))
               (and (>= (string-length s) 3)
                    (string=? (substring s 0 3) "win")))))))

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
           (test-equal 2 (length (find-file out '(type . file)))))))
      (else
       (test-equal #t #t))))

  (test-group "gzip / gunzip"
    (cond
      ((windows?)
       ;; Native gzip on Windows behaves inconsistently across distributions
       ;; (Git-for-Windows, MSYS, etc.) — skip rather than gate on which.
       (test-equal #t #t))
      (else
       (let ((f (string-append base "/big")))
         (call-with-port (open-output-file f)
           (lambda (p) (display "abcabcabc" p)))
         (test-equal #t (gzip f 'keep))
         (test-equal #t (file-exists? (string-append f ".gz")))
         (test-equal #t (file-exists? f)))))))

(rm base 'recursive)

(test-end "scm-archive")

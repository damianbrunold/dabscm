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

(define (file-contents path)
  (call-with-port (open-input-file path)
    (lambda (p)
      (let loop ((acc '()))
        (let ((c (read-char p)))
          (if (eof-object? c)
              (list->string (reverse acc))
              (loop (cons c acc))))))))

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

  ;; The 'pure option forces the built-in pure-Scheme USTAR implementation,
  ;; so these run regardless of whether a native tar is present.
  (test-group "tar pure fallback"
    ;; .tar.gz round-trip
    (let ((tgz (string-append base "/pure.tar.gz"))
          (out (string-append base "/pure-out")))
      (test-equal #t (tar-create tgz (list src) 'pure))
      (test-equal #t (>= (length (tar-list tgz 'pure)) 2))
      (make-directory out)
      (test-equal #t (tar-extract tgz 'pure `(work-dir . ,out)))
      (let ((files (find-file out '(type . file))))
        (test-equal 2 (length files))
        ;; contents preserved byte-for-byte
        (test-equal '("hello\n" "world\n")
                    (list-sort string<? (map file-contents files)))))
    ;; plain .tar (no compression)
    (let ((tar (string-append base "/pure.tar"))
          (out (string-append base "/pure-out-plain")))
      (test-equal #t (tar-create tar (list src) 'pure))
      (test-equal #t (>= (length (tar-list tar 'pure)) 2))
      (make-directory out)
      (test-equal #t (tar-extract tar 'pure `(work-dir . ,out)))
      (test-equal 2 (length (find-file out '(type . file)))))
    ;; bzip2/xz require native tar even in pure mode
    (test-equal 'errored
                (guard (e (#t 'errored))
                  (tar-create (string-append base "/x.tar.bz2") (list src) 'pure)))
    ;; cross-compatibility with native tar when it is available
    (when (which "tar")
      (let ((from-pure (string-append base "/cross-pure.tar.gz"))
            (from-native (string-append base "/cross-native.tar.gz")))
        ;; native tar reads a pure-created archive
        (test-equal #t (tar-create from-pure (list src) 'pure))
        (test-equal #t (>= (length (tar-list from-pure)) 2))
        ;; the pure reader reads a native-created archive
        (test-equal #t (tar-create from-native (list src)))
        (test-equal #t (>= (length (tar-list from-native 'pure)) 2)))))

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

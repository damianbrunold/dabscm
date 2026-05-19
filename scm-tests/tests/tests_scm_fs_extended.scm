(import (scheme base)
        (scheme file)
        (scheme write)
        (scm fs)
        (scm test))

(test-runner-factory scm-test-runner)

(define base (mktempdir '(prefix . "scmfs-test")))

(test-begin "scm-fs-extended")

(test-group "touch"
  (let ((f (string-append base "/touched"))
        (g (string-append base "/never")))
    (test-equal #f (file-exists? f))
    (test-equal #t (touch f))
    (test-equal #t (file-exists? f))
    (test-equal #f (touch g 'no-create))
    (test-equal #f (file-exists? g))))

(test-group "mktemp / mktempdir"
  (let ((f (mktemp)))
    (test-equal #t (file-exists? f))
    (delete-file f))
  (let ((d (mktempdir)))
    (test-equal #t (directory-exists? d))
    (delete-directory d))
  (let ((p (mktemp '(prefix . "scmtest"))))
    (test-equal #t (file-exists? p))
    (test-equal #t
      (let* ((bn (base-name p))
             (n  (string-length bn)))
        (and (>= n 7)
             (string=? (substring bn 0 7) "scmtest"))))
    (delete-file p)))

(test-group "stat"
  (let ((f (string-append base "/sized")))
    (call-with-port (open-output-file f)
      (lambda (p) (display "hello" p)))
    (let ((s (stat f)))
      (test-equal #t (cdr (assq 'exists s)))
      (test-equal 'file (cdr (assq 'type s)))
      (test-equal 5 (cdr (assq 'size s)))))
  (let ((s2 (stat (string-append base "/missing"))))
    (test-equal #f (cdr (assq 'exists s2)))
    (test-equal 'missing (cdr (assq 'type s2)))))

(test-group "rm options"
  (let ((f (string-append base "/to-delete")))
    (touch f)
    (test-equal #t (file-exists? f))
    (rm f)
    (test-equal #f (file-exists? f))
    (test-equal #f (rm f 'force)))
  (let ((d (string-append base "/subtree")))
    (make-directory d)
    (touch (string-append d "/inner"))
    (rm d 'recursive)
    (test-equal #f (directory-exists? d))))

(test-group "cp and mv"
  (let ((a (string-append base "/cp-src.txt"))
        (b (string-append base "/cp-dst.txt"))
        (c (string-append base "/cp-moved.txt")))
    (call-with-port (open-output-file a)
      (lambda (p) (display "abc" p)))
    (cp a b)
    (test-equal #t (file-exists? b))
    (mv b c)
    (test-equal #f (file-exists? b))
    (test-equal #t (file-exists? c)))
  (let ((sd (string-append base "/src-dir"))
        (dd (string-append base "/dst-dir")))
    (make-directory sd)
    (touch (string-append sd "/x"))
    (cp sd dd 'recursive)
    (test-equal #t (directory-exists? dd))
    (test-equal #t (file-exists? (string-append dd "/x")))))

(rm base 'recursive)

(test-end "scm-fs-extended")

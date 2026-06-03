(import (scheme base)
        (scheme file)
        (scheme write)
        (scm test)
        (scm io)
        (scm fs))

(test-runner-factory scm-test-runner)

(test-begin "scm-io")

(define test-base (normalized-path (join-path (special-folder-temp) "scm-io-test")))

(define (setup)
  (when (directory-exists? test-base)
    (delete-directory test-base))
  (make-directory test-base))

(define (teardown)
  (when (directory-exists? test-base)
    (delete-directory test-base)))

(define (write-text path text . opts)
  (let ((p (apply open-output-file path opts)))
    (display text p)
    (close-output-port p)))

;; --- file->string ---
(test-group "file->string"
  (setup)
  (let ((path (join-path test-base "plain.txt")))
    (write-text path "line one\nline two\nline three\n")
    (test-equal "line one\nline two\nline three\n" (file->string path))
    ;; empty file yields empty string
    (write-text (join-path test-base "empty.txt") "")
    (test-equal "" (file->string (join-path test-base "empty.txt")))
    ;; no trailing newline
    (write-text (join-path test-base "notrail.txt") "abc")
    (test-equal "abc" (file->string (join-path test-base "notrail.txt"))))
  (teardown))

;; --- file->lines ---
(test-group "file->lines"
  (setup)
  (let ((path (join-path test-base "lines.txt")))
    (write-text path "alpha\nbeta\ngamma\n")
    (test-equal '("alpha" "beta" "gamma") (file->lines path))
    ;; trailing newline does not produce a trailing empty line
    (write-text (join-path test-base "one.txt") "solo\n")
    (test-equal '("solo") (file->lines (join-path test-base "one.txt")))
    ;; no trailing newline still yields the final line
    (write-text (join-path test-base "notrail.txt") "x\ny")
    (test-equal '("x" "y") (file->lines (join-path test-base "notrail.txt")))
    ;; empty file yields empty list
    (write-text (join-path test-base "empty.txt") "")
    (test-equal '() (file->lines (join-path test-base "empty.txt"))))
  (teardown))

;; --- missing file: file->* returns #f ---
(test-group "missing-file"
  (setup)
  (test-equal #f (file->string (join-path test-base "does-not-exist.txt")))
  (test-equal #f (file->lines (join-path test-base "does-not-exist.txt")))
  (teardown))

;; --- read-file-* raising variants ---
(define (raised? thunk)
  (guard (e (#t #t)) (thunk) #f))

(test-group "read-file-success"
  (setup)
  (let ((path (join-path test-base "plain.txt")))
    (write-text path "line one\nline two\n")
    (test-equal "line one\nline two\n" (read-file-string path))
    (test-equal '("line one" "line two") (read-file-lines path)))
  (teardown))

(test-group "read-file-missing-raises"
  (setup)
  (let ((path (join-path test-base "does-not-exist.txt")))
    (test-equal #t (raised? (lambda () (read-file-string path))))
    (test-equal #t (raised? (lambda () (read-file-lines path)))))
  (teardown))

;; --- deflate option round-trips ---
(test-group "deflate"
  (setup)
  (let ((path (join-path test-base "data.def")))
    (write-text path "compressed one\ncompressed two\n" 'deflate)
    (test-equal "compressed one\ncompressed two\n" (file->string path 'deflate))
    (test-equal '("compressed one" "compressed two") (file->lines path 'deflate)))
  (teardown))

;; --- encoding option round-trips ---
(test-group "encoding"
  (setup)
  (let ((path (join-path test-base "latin.txt")))
    (write-text path "caf\xe9;" 'latin-1)
    (test-equal "caf\xe9;" (file->string path 'latin-1))
    (test-equal '("caf\xe9;") (file->lines path 'latin-1)))
  (teardown))

(test-end "scm-io")

(import (scheme base) (scm fs) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-file-lock")

(test-group "file-lock / file-unlock: exclusion and release"
  (let* ((dir (mktempdir '(prefix . "lock-test")))
         (path (join-path dir "x.lock")))
    (let ((h1 (file-lock path)))
      (test-assert h1)                       ;; acquired
      (test-equal #f (file-lock path))       ;; same lock held -> #f
      (test-equal #t (file-unlock h1))       ;; release succeeds
      (let ((h2 (file-lock path)))           ;; re-acquire after release
        (test-assert h2)
        (test-equal #t (file-unlock h2))))))

(test-group "file-lock: creates missing parent directories"
  (let* ((dir (mktempdir '(prefix . "lock-test")))
         (path (join-path (join-path dir "sub") "y.lock")))
    (let ((h (file-lock path)))
      (test-assert h)
      (test-equal #t (path-exists? path))
      (test-equal #t (file-unlock h)))))

(test-group "file-unlock: non-lock argument returns #f"
  (test-equal #f (file-unlock 42)))

(test-end "scm-file-lock")

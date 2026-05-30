(import (scheme base)
        (scheme file)
        (scheme write)
        (srfi 1)
        (scm test)
        (scm fs))

(test-runner-factory scm-test-runner)

(test-begin "scm-fs-symlink")

;; Work in a fresh temp directory.
(define test-base
  (normalized-path (join-path (special-folder-temp) "scm-fs-symlink-test")))

(define (setup)
  (when (directory-exists? test-base)
    (delete-directory test-base))
  (make-directory test-base)
  (make-directory (join-path test-base "sub"))
  (let ((p (open-output-file (join-path test-base "file.txt"))))
    (display "hello" p)
    (close-output-port p)))

(define (cleanup)
  (when (directory-exists? test-base)
    (delete-directory test-base)))

;; Look up the type symbol for a name in a directory-entries result.
(define (entry-type entries name)
  (let ((pair (assoc name entries)))
    (and pair (cdr pair))))

(setup)

;; Probe whether the platform allows creating symlinks (Windows without the
;; symlink privilege returns #f). All symlink-creation tests are gated on this,
;; mirroring how the dabsync test suite gates its Windows-only behaviour.
(define link-path (join-path test-base "link-to-file"))
(define symlink-supported?
  (begin
    (make-symlink "file.txt" link-path)
    (file-symlink? link-path)))

(test-group "file-symlink? on non-links"
  (test-equal #f (file-symlink? (join-path test-base "file.txt")))
  (test-equal #f (file-symlink? (join-path test-base "sub")))
  (test-equal #f (file-symlink? (join-path test-base "does-not-exist"))))

(test-group "path-exists? vs file-exists?"
  ;; path-exists? is the lexists-style check (no follow); file-exists? follows
  ;; and is #f for a directory.
  (test-equal #t (path-exists? (join-path test-base "file.txt")))
  (test-equal #t (path-exists? (join-path test-base "sub")))
  (test-equal #t (file-exists? (join-path test-base "file.txt")))
  (test-equal #f (file-exists? (join-path test-base "sub")))
  (test-equal #f (path-exists? (join-path test-base "does-not-exist"))))

(when symlink-supported?
  (test-group "symlink create / detect / read"
    ;; A link to a file is reported as a symlink, not followed.
    (test-equal #t (file-symlink? link-path))
    (test-equal "file.txt" (read-symlink link-path))
    ;; A link to a directory is also reported as a symlink.
    (let ((dlink (join-path test-base "link-to-sub")))
      (make-symlink "sub" dlink)
      (test-equal #t (file-symlink? dlink))
      (test-equal "sub" (read-symlink dlink)))
    ;; A dangling link still counts as a symlink and as path-exists?.
    ;; A dangling link still counts as a symlink and as path-exists?.
    ;; (file-exists? on a dangling link is intentionally not asserted: it
    ;; differs across platforms — .NET's File.Exists reports the link as
    ;; existing, while java.nio follows it and reports #f.)
    (let ((dangling (join-path test-base "dangling")))
      (make-symlink "nonexistent-target" dangling)
      (test-equal #t (file-symlink? dangling))
      (test-equal #t (path-exists? dangling))
      (test-equal "nonexistent-target" (read-symlink dangling)))))

(test-group "read-symlink on non-link"
  (test-equal #f (read-symlink (join-path test-base "file.txt"))))

(test-group "directory-entries type tagging"
  (let ((entries (directory-entries test-base)))
    (test-equal 'file (entry-type entries "file.txt"))
    (test-equal 'directory (entry-type entries "sub"))
    (when symlink-supported?
      (test-equal 'symlink (entry-type entries "link-to-file")))))

(test-group "set-file-modification-time! round-trip"
  (let ((f (join-path test-base "file.txt"))
        (when-ms 1700000000000))
    (set-file-modification-time! f when-ms)
    ;; Allow a small tolerance for filesystems with coarse mtime resolution.
    (test-assert (< (abs (- (file-modification-timestamp f) when-ms)) 2000))))

(cleanup)
(test-equal #f (directory-exists? test-base))

(test-end "scm-fs-symlink")

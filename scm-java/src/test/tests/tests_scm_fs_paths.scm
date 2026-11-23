(import (scheme base)
        (scm fs)
        (scm test))

(test-runner-factory scm-test-runner)

;; The expected paths use the system's separator: / on POSIX, \ on Windows,
;; where a path without a drive (/a) is on the current directory's drive.
(define sep path-sep)
(define root
  (cond-expand
   (windows (string-append (substring (current-directory) 0 2) "\\"))
   (else "/")))
(define (sep-join parts)
  (if (null? parts)
      ""
      (let loop ((acc (car parts)) (rest (cdr parts)))
        (if (null? rest)
            acc
            (loop (string-append acc sep (car rest)) (cdr rest))))))
(define (rooted . parts) (string-append root (sep-join parts)))

(test-begin "scm-fs-paths")

(test-group "directory-name"
  (test-equal (rooted "a" "b") (directory-name "/a/b/c"))
  ;; a trailing separator is not a component (as with POSIX dirname)
  (test-equal (rooted "a") (directory-name "/a/b/"))
  (test-equal root (directory-name "/a"))
  ;; the root has no parent
  (test-equal #f (directory-name "/"))
  ;; relative paths are made absolute
  (test-equal (current-directory) (directory-name "some-file"))
  (test-equal (string-append (current-directory) sep "a") (directory-name "a/b"))
  (cond-expand
   (windows
    (test-equal "C:\\a\\b" (directory-name "C:\\a\\b\\c"))
    (test-equal "C:\\a" (directory-name "C:\\a\\b\\"))
    (test-equal "C:\\" (directory-name "C:\\a"))
    (test-equal #f (directory-name "C:\\"))
    ;; forward slashes become backslashes
    (test-equal "C:\\a" (directory-name "C:/a/b")))
   (else)))

(test-group "base-name"
  (test-equal "c" (base-name "/a/b/c"))
  (test-equal "b" (base-name "/a/b/"))
  (test-equal "a.txt" (base-name "a.txt"))
  (cond-expand
   (windows
    (test-equal "b.txt" (base-name "C:\\a\\b.txt"))
    (test-equal "b" (base-name "C:\\a\\b\\"))
    (test-equal "c" (base-name "a/b\\c")))
   (else)))

(test-group "join-path"
  (test-equal (string-append "/usr" sep "local" sep "bin") (join-path "/usr" "local" "bin"))
  ;; a separator at the end or the start of a part is not doubled
  (test-equal "/usr/local" (join-path "/usr/" "local"))
  (test-equal "/usr/local" (join-path "/usr" "/local"))
  (test-equal "/usr/local" (join-path "/usr/" "/local"))
  (test-equal "a" (join-path "a"))
  (test-equal (string-append sep "x") (join-path "" "x"))
  (test-equal "" (join-path))
  ;; parts that are not strings are converted as display shows them
  (test-equal (sep-join '("cfg" "A_2026")) (join-path "cfg" 'A_2026))
  (test-equal (sep-join '("a" "12" "x" "#f")) (join-path "a" 12 #\x #f))
  (test-equal (sep-join '("x" "y")) (join-path 'x "y"))
  (cond-expand
   (windows
    (test-equal "C:\\a\\b" (join-path "C:\\a" "b"))
    (test-equal "C:\\a\\b" (join-path "C:\\a\\" "b"))
    (test-equal "C:\\a\\b" (join-path "C:\\a" "\\b"))
    (test-equal "a\\b" (join-path "a\\" "/b")))
   (else)))

(test-end "scm-fs-paths")

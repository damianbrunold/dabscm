(import (scheme base)
        (scm fs)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-fs-paths")

(test-group "directory-name"
  (test-equal "/a/b" (directory-name "/a/b/c"))
  ;; a trailing separator is not a component (as with POSIX dirname)
  (test-equal "/a" (directory-name "/a/b/"))
  (test-equal "/" (directory-name "/a"))
  ;; the root has no parent
  (test-equal #f (directory-name "/"))
  ;; relative paths are made absolute
  (test-equal (current-directory) (directory-name "some-file")))

(test-group "base-name"
  (test-equal "c" (base-name "/a/b/c"))
  (test-equal "b" (base-name "/a/b/"))
  (test-equal "a.txt" (base-name "a.txt")))

(test-group "join-path"
  (test-equal "/usr/local/bin" (join-path "/usr" "local" "bin"))
  (test-equal "/usr/local" (join-path "/usr/" "local"))
  (test-equal "/usr/local" (join-path "/usr" "/local"))
  (test-equal "/usr/local" (join-path "/usr/" "/local"))
  (test-equal "a" (join-path "a"))
  (test-equal "/x" (join-path "" "x"))
  (test-equal "" (join-path)))

(test-end "scm-fs-paths")

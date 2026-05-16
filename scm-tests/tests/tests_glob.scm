(import (scheme base)
        (scheme file)
        (scheme char)
        (srfi 1)
        (srfi 132)
        (scm test)
        (scm glob)
        (scm fs))

(test-runner-factory scm-test-runner)

(test-begin "glob")

;; --- glob-match? basic patterns ---

(test-group "literal matching"
  ;; Literal matching
  (test-equal #t (glob-match? "foo" "foo"))
  (test-equal #f (glob-match? "foo" "bar"))
  (test-equal #t (glob-match? "" ""))
  (test-equal #f (glob-match? "foo" ""))
  (test-equal #f (glob-match? "" "foo")))

(test-group "star wildcard"
  ;; Star wildcard
  (test-equal #t (glob-match? "*" "foo"))
  (test-equal #t (glob-match? "*" ""))
  (test-equal #t (glob-match? "*.scm" "foo.scm"))
  (test-equal #t (glob-match? "*.scm" "bar.scm"))
  (test-equal #f (glob-match? "*.scm" "foo.txt"))
  (test-equal #t (glob-match? "foo*" "foobar"))
  (test-equal #t (glob-match? "foo*" "foo"))
  (test-equal #t (glob-match? "f*o" "foo"))
  (test-equal #t (glob-match? "f*o" "fo"))
  (test-equal #t (glob-match? "f*o" "fxyzvo"))
  (test-equal #f (glob-match? "*" (join-path "foo" "bar")))  ; * does not cross path separator
  (test-equal #f (glob-match? "*.scm" (join-path "src" "foo.scm"))))

(test-group "question mark wildcard"
  ;; Question mark wildcard
  (test-equal #t (glob-match? "?" "a"))
  (test-equal #f (glob-match? "?" ""))
  (test-equal #f (glob-match? "?" "ab"))
  (test-equal #t (glob-match? "??" "ab"))
  (test-equal #t (glob-match? "?.txt" "a.txt"))
  (test-equal #f (glob-match? "?.txt" "ab.txt"))
  (test-equal #f (glob-match? "?" path-sep)))  ; ? does not match path separator

(test-group "character classes"
  ;; Character classes
  (test-equal #t (glob-match? "[abc]" "a"))
  (test-equal #t (glob-match? "[abc]" "b"))
  (test-equal #f (glob-match? "[abc]" "d"))
  (test-equal #t (glob-match? "[a-z]" "m"))
  (test-equal #f (glob-match? "[a-z]" "A"))
  (test-equal #t (glob-match? "[a-zA-Z]" "A"))
  (test-equal #t (glob-match? "[!abc]" "d"))
  (test-equal #f (glob-match? "[!abc]" "a"))
  (test-equal #t (glob-match? "[^abc]" "d"))
  (test-equal #f (glob-match? "[^abc]" "b"))
  (test-equal #t (glob-match? "[]]" "]"))  ; ] as first char is literal
  (test-equal #t (glob-match? "file[0-9].txt" "file3.txt"))
  (test-equal #f (glob-match? "file[0-9].txt" "fileA.txt")))

(test-group "globstar **"
  ;; Globstar **
  (test-equal #t (glob-match? "**" "foo"))
  (test-equal #t (glob-match? "**" (join-path "foo" "bar")))
  (test-equal #t (glob-match? "**" (join-path "foo" "bar" "baz")))
  (test-equal #t (glob-match? "**" ""))
  (test-equal #t (glob-match? (join-path "src" "**" "*.scm") (join-path "src" "foo.scm")))
  (test-equal #t (glob-match? (join-path "src" "**" "*.scm") (join-path "src" "lib" "foo.scm")))
  (test-equal #t (glob-match? (join-path "src" "**" "*.scm") (join-path "src" "a" "b" "c" "foo.scm")))
  (test-equal #f (glob-match? (join-path "src" "**" "*.scm") (join-path "src" "foo.txt")))
  (test-equal #t (glob-match? (string-append "**" path-sep "*.scm") "foo.scm"))
  (test-equal #t (glob-match? (string-append "**" path-sep "*.scm") (join-path "a" "b" "foo.scm")))
  (test-equal #t (glob-match? (string-append "**" path-sep "foo") "foo"))
  (test-equal #t (glob-match? (string-append "**" path-sep "foo") (join-path "a" "b" "foo"))))

(test-group "combined patterns"
  ;; Combined patterns
  (test-equal #t (glob-match? (join-path "src" "*" "test?.scm") (join-path "src" "lib" "test1.scm")))
  (test-equal #f (glob-match? (join-path "src" "*" "test?.scm") (join-path "src" "lib" "test12.scm")))
  (test-equal #t (glob-match? "[abc]*.txt" "apple.txt"))
  (test-equal #f (glob-match? "[abc]*.txt" "dog.txt")))

;; --- glob filesystem tests with temp directory ---

(test-group "glob filesystem"
  ;; Use normalized-path to avoid double slashes from special-folder-temp
  (define test-base (normalized-path (join-path (special-folder-temp) "scm-glob-test")))
  (define (setup-test-dirs)
    (when (directory-exists? test-base)
      (delete-directory test-base))
    (make-directory test-base)
    (make-directory (join-path test-base "src"))
    (make-directory (join-path test-base "src" "lib"))
    (make-directory (join-path test-base "src" "test"))
    (make-directory (join-path test-base ".hidden"))
    ;; Create test files
    (for-each (lambda (parts)
                (let ((port (open-output-file (apply join-path test-base parts))))
                  (close-output-port port)))
              '(("readme.txt") ("notes.txt")
                ("src" "main.scm") ("src" "util.scm")
                ("src" "lib" "helper.scm") ("src" "lib" "core.scm")
                ("src" "test" "test1.scm") ("src" "test" "test2.scm")
                (".hidden" "secret.txt") (".dotfile"))))
  (define (cleanup-test-dirs)
    (when (directory-exists? test-base)
      (delete-directory test-base)))
  (setup-test-dirs)

  ;; glob with no wildcards returns the path if it exists
  (test-equal (list (join-path test-base "readme.txt"))
  (glob (join-path test-base "readme.txt")))

  ;; glob on non-existent file returns empty list
  (test-equal '()
  (glob (join-path test-base "nonexistent_xyz.txt")))

  ;; glob on non-existent directory returns empty list
  (test-equal '()
  (glob (join-path test-base "nonexistent_dir_xyz" "*.scm")))

  ;; glob with ? wildcard on filenames
  (test-equal '("test1.scm" "test2.scm")
  (let ((results (glob (join-path test-base "src" "test" "test?.scm"))))
    (list-sort string<? (map base-name results))))

  ;; * matches files in directory
  (test-equal '("notes.txt" "readme.txt")
  (let ((results (glob (join-path test-base "*.txt"))))
    (list-sort string<?
      (map (lambda (p) (base-name p)) results))))

  ;; * does not match dotfiles
  (test-equal #t
  (let ((results (glob (join-path test-base "*"))))
    (not (member ".dotfile" (map base-name results)))))

  ;; .* matches dotfiles
  (test-equal #t
  (let ((results (glob (join-path test-base ".*"))))
    (and (member ".dotfile" (map base-name results)) #t)))

  ;; ** recursive globstar
  (test-equal '("core.scm" "helper.scm" "main.scm" "test1.scm" "test2.scm" "util.scm")
  (let ((results (glob (join-path test-base "**" "*.scm"))))
    (list-sort string<?
      (map base-name results))))

  ;; ** with intermediate directory
  (test-equal #t
  (let ((results (glob (join-path test-base "src" "**" "*.scm"))))
    (= (length results) 6)))

  ;; Single directory level with *
  (test-equal '("main.scm" "util.scm")
  (let ((results (glob (join-path test-base "src" "*.scm"))))
    (list-sort string<?
      (map base-name results))))

  ;; Nested specific directory
  (test-equal '("core.scm" "helper.scm")
  (let ((results (glob (join-path test-base "src" "lib" "*.scm"))))
    (list-sort string<?
      (map base-name results))))

  (cleanup-test-dirs)
  ;; Verify cleanup
  (test-equal #f (directory-exists? test-base)))

(test-end "glob")

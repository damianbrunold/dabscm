(import (scheme base)
        (scheme char)
        (scm test)
        (srfi 13))

(test-runner-factory scm-test-runner)

(test-begin "srfi-13")

;; Selectors
(test-group "selectors"
  (test-equal "Hello" (string-take "Hello, World!" 5))
  (test-equal "World!" (string-drop "Hello, World!" 7))
  (test-equal "World!" (string-take-right "Hello, World!" 6))
  (test-equal "Hello" (string-drop-right "Hello, World!" 8)))

;; Predicates
(test-group "predicates"
  (test-equal #t (string-null? ""))
  (test-equal #f (string-null? "a"))
  (test-equal #t (string-every char-alphabetic? "Hello"))
  (test-equal #f (string-every char-alphabetic? "Hello1"))
  (test-equal #t (string-any char-numeric? "Hello123"))
  (test-equal #f (string-any char-numeric? "Hello")))

;; Search
(test-group "search"
  (test-equal 0 (string-index "Hello, World!" char-upper-case?))
  (test-equal 7 (string-index "hello, World!" char-upper-case?))
  (test-equal #f (string-index "hello" char-upper-case?))
  (test-equal 7 (string-index-right "Hello, World!" char-upper-case?))
  (test-equal 3 (string-skip "   hello" char-whitespace?))
  (test-equal 4 (string-skip-right "hello   " char-whitespace?)))

;; Trim
(test-group "trim"
  (test-equal "hello  " (string-trim "  hello  "))
  (test-equal "  hello" (string-trim-right "  hello  "))
  (test-equal "hello" (string-trim-both "  hello  "))
  (test-equal "hello" (string-trim "xxxhello" (lambda (c) (char=? c #\x)))))

;; Prefix / Suffix
(test-group "prefix-suffix"
  (test-equal #t (string-prefix? "Hell" "Hello, World!"))
  (test-equal #f (string-prefix? "hell" "Hello, World!"))
  (test-equal #t (string-prefix-ci? "hell" "Hello, World!"))
  (test-equal #t (string-suffix? "orld!" "Hello, World!"))
  (test-equal #t (string-suffix-ci? "ORLD!" "Hello, World!"))
  (test-equal 5 (string-prefix-length "Hello" "Hello, World!"))
  (test-equal 5 (string-suffix-length "orld!" "Hello, World!")))

;; Contains
(test-group "contains"
  (test-equal 7 (string-contains "Hello, World!" "World"))
  (test-equal #f (string-contains "Hello, World!" "world"))
  (test-equal 7 (string-contains-ci "Hello, World!" "world"))
  (test-equal #f (string-contains "Hello" "xyz")))

;; Fold and map
(test-group "fold-and-map"
  (test-equal '(#\c #\b #\a) (string-fold (lambda (c acc) (cons c acc)) '() "abc"))
  (test-equal '(#\a #\b #\c) (string-fold-right cons '() "abc"))
  (test-equal 2 (string-count "Hello, World!" char-upper-case?))
  (test-equal "HELLO" (string-map char-upcase "hello"))
  (test-equal "olleh" (string-reverse "hello")))

;; for-each
(test-group "for-each"
  (test-equal '(#\c #\b #\a)
    (let ((result '()))
      (string-for-each (lambda (c) (set! result (cons c result))) "abc")
      result))
  (test-equal '(2 1 0)
    (let ((result '()))
      (string-for-each-index (lambda (i) (set! result (cons i result))) "abc")
      result)))

;; Constructors
(test-group "constructors"
  (test-equal "abcde" (string-tabulate (lambda (i) (integer->char (+ i 97))) 5))
  (test-equal "abcde" (string-unfold (lambda (x) (> x 5))
                   (lambda (x) (integer->char (+ x 96)))
                   (lambda (x) (+ x 1))
                   1))
  (test-equal "abc" (reverse-list->string '(#\c #\b #\a)))
  (test-equal "World!" (substring/shared "Hello, World!" 7))
  (test-equal "World" (substring/shared "Hello, World!" 7 12)))

;; Padding
(test-group "padding"
  (test-equal "   hello" (string-pad "hello" 8))
  (test-equal "hello   " (string-pad-right "hello" 8))
  (test-equal "llo" (string-pad "hello" 3))
  (test-equal "---hello" (string-pad "hello" 8 #\-)))

;; Concatenate
(test-group "concatenate"
  (test-equal "Hello, World!" (string-concatenate '("Hello" ", " "World" "!")))
  (test-equal "Hello, World!" (string-concatenate-reverse '("World!" " " "Hello,"))))

;; Case
(test-group "case"
  (test-equal "Hello World" (string-titlecase "hello world"))
  (test-equal "Hello-World Test" (string-titlecase "hello-world test")))

;; Tokenize, filter, delete
(test-group "tokenize-filter-delete"
  (test-equal '("foo" "bar" "baz") (string-tokenize "  foo  bar  baz  "))
  (test-equal "hllwrld" (string-filter char-alphabetic? "h3ll0 w0rld"))
  (test-equal "hll wrld" (string-delete char-numeric? "h3ll0 w0rld")))

;; xsubstring
(test-group "xsubstring"
  (test-equal "abcabc" (xsubstring "abc" 0 6))
  (test-equal "bca" (xsubstring "abc" 1 4)))

;; Compare
(test-group "compare"
  (test-equal 'less (string-compare "abc" "abd" (lambda (i) 'less) (lambda (i) 'equal) (lambda (i) 'greater)))
  (test-equal 'equal (string-compare "abc" "abc" (lambda (i) 'less) (lambda (i) 'equal) (lambda (i) 'greater)))
  (test-equal 'greater (string-compare "abd" "abc" (lambda (i) 'less) (lambda (i) 'equal) (lambda (i) 'greater))))

;; Hash
(test-group "hash"
  (test-equal #t (integer? (string-hash "hello")))
  (test-equal #t (integer? (string-hash-ci "HELLO")))
  (test-equal #t (= (string-hash "hello" (expt 2 32)) (string-hash-ci "HELLO" (expt 2 32)))))

;; SRFI-13 comparison procedures
(test-group "comparison-procedures"
  (test-equal 3 (string= "abc" "abc"))
  (test-equal #f (string= "abc" "abd"))
  (test-equal 0 (string<> "abc" "def"))
  (test-equal #f (string<> "abc" "abc"))
  (test-equal 2 (string< "abc" "abd"))
  (test-equal #f (string< "abd" "abc"))
  (test-equal 2 (string> "abd" "abc"))
  (test-equal #f (string> "abc" "abd"))
  (test-equal 3 (string<= "abc" "abc"))
  (test-equal #f (string<= "abd" "abc"))
  (test-equal 3 (string>= "abc" "abc"))
  (test-equal #f (string>= "abc" "abd"))
  ;; case-insensitive
  (test-equal 3 (string-ci= "ABC" "abc"))
  (test-equal #f (string-ci= "ABC" "abd"))
  (test-equal #f (string-ci<> "ABC" "abc"))
  (test-equal 0 (string-ci<> "abc" "def"))
  (test-equal 2 (string-ci< "ABC" "abd"))
  (test-equal 2 (string-ci> "abd" "ABC"))
  (test-equal 3 (string-ci<= "ABC" "abc"))
  (test-equal 3 (string-ci>= "ABC" "abc"))
  ;; with start/end
  (test-equal 5 (string= "xxabc" "abc" 2 5 0 3))
  (test-equal 4 (string< "xxabc" "abd" 2 5 0 3)))

;; string-map with start/end (unified)
(test-group "string-map-start-end"
  (test-equal "EL" (string-map char-upcase "hello" 1 3))
  (test-equal "ELLO" (string-map char-upcase "hello" 1))
  ;; string-for-each with start/end
  (test-equal '(#\l #\e)
    (let ((r '()))
      (string-for-each (lambda (c) (set! r (cons c r))) "hello" 1 3)
      r)))

;; string-upcase / string-downcase with start/end
(test-group "upcase-downcase-start-end"
  (test-equal "EL" (string-upcase "hello" 1 3))
  (test-equal "el" (string-downcase "HELLO" 1 3))
  (test-equal "HELLO" (string-upcase "hello"))
  (test-equal "hello" (string-downcase "HELLO")))

;; string-titlecase with start/end (returns substring)
(test-group "titlecase-start-end"
  (test-equal "Hello World" (string-titlecase "hello world"))
  (test-equal "World" (string-titlecase "hello world" 6 11))
  (test-equal "Quick" (string-titlecase "the QUICK brown fox" 4 9)))

;; Low-level procedures
(test-group "low-level"
  (test-equal #t (substring-spec-ok? "hello" 0 5))
  (test-equal #f (substring-spec-ok? "hello" 3 2))
  (test-equal #f (substring-spec-ok? "hello" 0 6))
  (test-equal #f (substring-spec-ok? "hello" -1 3)))

;; Re-exports from (scheme base) accessible via (srfi 13)
(test-group "re-exports"
  (test-equal #t (string? "hello"))
  (test-equal 5 (string-length "hello"))
  (test-equal #\e (string-ref "hello" 1))
  (test-equal "hello" (string-copy "hello"))
  (test-equal "hello" (string-append "hel" "lo"))
  (test-equal '(#\a #\b #\c) (string->list "abc"))
  (test-equal "abc" (list->string '(#\a #\b #\c)))
  (test-equal "xxx" (make-string 3 #\x)))

;; string-unfold with base string (base is leftmost)
(test-group "string-unfold-base"
  (test-equal "Zabc" (string-unfold (lambda (x) (> x 3))
                   (lambda (x) (integer->char (+ x 96)))
                   (lambda (x) (+ x 1))
                   1 "Z"))
  (test-equal "(abc)" (string-unfold (lambda (x) (> x 3))
                       (lambda (x) (integer->char (+ x 96)))
                       (lambda (x) (+ x 1))
                       1 "(" (lambda (x) ")")))
  ;; string-unfold-right with base string (base is rightmost)
  (test-equal "cbaZ" (string-unfold-right (lambda (x) (> x 3))
                         (lambda (x) (integer->char (+ x 96)))
                         (lambda (x) (+ x 1))
                         1 "Z"))
  (test-equal "(cba)" (string-unfold-right (lambda (x) (> x 3))
                         (lambda (x) (integer->char (+ x 96)))
                         (lambda (x) (+ x 1))
                         1 ")" (lambda (x) "("))))

;; string-every returns last predicate value
(test-group "string-every-return-value"
  (test-equal #\o (string-every (lambda (c) (if (char-alphabetic? c) c #f)) "hello"))
  (test-equal #t (string-every char-alphabetic? ""))
  (test-equal #f (string-every char-alphabetic? "hello1")))

;; string-compare-ci with start/end preserves original indices
(test-group "string-compare-ci-start-end"
  (test-equal '(less 4) (string-compare-ci "xxABC" "yyABD"
      (lambda (i) (list 'less i))
      (lambda (i) (list 'equal i))
      (lambda (i) (list 'greater i))
      2 5 2 5))
  (test-equal '(equal 5) (string-compare-ci "xxABC" "yyABC"
      (lambda (i) (list 'less i))
      (lambda (i) (list 'equal i))
      (lambda (i) (list 'greater i))
      2 5 2 5)))

;; kmp-step with i=-1 does not crash
(test-group "kmp-step"
  (test-equal -1 (let ((rv (make-kmp-restart-vector "abc")))
      (kmp-step "abc" rv #\x -1 char=? 0)))
  (test-equal 1 (let ((rv (make-kmp-restart-vector "abc")))
      (kmp-step "abc" rv #\a -1 char=? 0))))

;; string-contains-ci with start2/end2
(test-group "string-contains-ci-start-end"
  (test-equal 6 (string-contains-ci "Hello World" "xxWORLDxx" 0 11 2 7))
  (test-equal #f (string-contains-ci "Hello World" "xyz" 0 11 0 3)))

;; string-parse-start+end returns 3 values
(test-group "string-parse-start-end"
  (test-equal '((extra) 1 4)
    (call-with-values
      (lambda () (string-parse-start+end 'test "hello" '(1 4 extra)))
      (lambda (rest start end) (list rest start end))))
  ;; let-string-start+end 3-binding form
  (test-equal '(1 4 (extra))
    (let-string-start+end (start end rest) 'test "hello" '(1 4 extra)
      (list start end rest)))
  ;; let-string-start+end 2-binding form
  (test-equal '(1 4)
    (let-string-start+end (start end) 'test "hello" '(1 4)
      (list start end))))

(test-end "srfi-13")

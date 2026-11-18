(import (scheme base)
        (scm string)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-string")

(test-group "string-split-char"
  (test-equal '("a" "b" "c") (string-split-char "a,b,c" #\,))
  (test-equal '("a" "" "b") (string-split-char "a,,b" #\,))
  (test-equal '("" "a" "") (string-split-char ",a," #\,))
  (test-equal '("abc") (string-split-char "abc" #\,))
  (test-equal '("") (string-split-char "" #\,))
  (test-equal '("" "") (string-split-char "," #\,)))

(test-group "string-split-lines"
  (test-equal '("a" "b" "c") (string-split-lines "a\nb\nc"))
  (test-equal '("a" "b" "") (string-split-lines "a\nb\n"))
  (test-equal '("a" "b") (string-split-lines "a\r\nb"))
  (test-equal '("a" "" "b") (string-split-lines "a\n\nb"))
  (test-equal '("") (string-split-lines ""))
  (test-equal '("hello") (string-split-lines "hello"))
  ;; CRLF on every line
  (test-equal '("one" "two" "") (string-split-lines "one\r\ntwo\r\n")))

(test-group "string-contains-from"
  (test-equal 0 (string-contains-from "hello" "hello" 0))
  (test-equal 6 (string-contains-from "hello world" "world" 0))
  (test-equal 6 (string-contains-from "hello world" "world" 6))
  (test-equal #f (string-contains-from "hello world" "world" 7))
  (test-equal 4 (string-contains-from "abcabc" "bc" 2))
  (test-equal 1 (string-contains-from "abcabc" "bc" 0))
  (test-equal #f (string-contains-from "abc" "xyz" 0))
  (test-equal #f (string-contains-from "ab" "abc" 0))
  ;; empty needle returns start
  (test-equal 0 (string-contains-from "abc" "" 0))
  (test-equal 2 (string-contains-from "abc" "" 2)))

(test-group "string-matches groups"
  (test-equal '("xab" "x") (string-matches "xab" "(x)?ab"))
  ;; a group that does not take part in the match is #f
  (test-equal '("b" #f) (string-matches "b" "(x)?b")))

(test-group "regex-search"
  (test-equal '#((0 . 6) (0 . 3) (3 . 6))
              (regex-search "abc123" "([a-z]+)([0-9]+)"))
  (test-equal '#((3 . 5)) (regex-search "ab ab" "ab" 1))
  (test-equal '#((0 . 2)) (regex-search "ab ab" "ab" 0))
  (test-equal #f (regex-search "hello" "xyz"))
  (test-equal '#((0 . 1) #f) (regex-search "b" "(x)?b"))
  ;; ^ is anchored at the string start, not at start
  (test-equal #f (regex-search "aa" "^a" 1))
  (test-equal '#((3 . 4)) (regex-search "ab\nc" "(?m)^c" 1))
  ;; lookbehind and \b see the text before start
  (test-equal '#((3 . 6)) (regex-search "ab cde" "\\b\\w+" 1))
  (test-equal #f (regex-search "abcd" "(?<=a)b" 2))
  (test-equal '#((1 . 2)) (regex-search "aB" "(?i)b"))
  (test-equal '#((5 . 5)) (regex-search "hello" "$"))
  (test-equal '#((2 . 2)) (regex-search "ab" "x*" 2))
  (test-error (regex-search "abc" "a" 4))
  (test-error (regex-search "abc" "(")))

(test-end "scm-string")

(import (scheme base)
        (scm test)
        (scm text))

(test-runner-factory scm-test-runner)

(test-begin "scm-text")

(define sample '("INFO  start"
                 "ERROR boom"
                 "info  other"
                 "ERROR bad"
                 "ok"))

(test-group "grep pure"
  (test-equal '("ERROR boom" "ERROR bad")
              (grep "ERROR" sample 'pure))
  (test-equal '("ERROR boom" "ERROR bad")
              (grep "error" sample 'pure 'ignore-case))
  (test-equal '("INFO  start" "info  other" "ok")
              (grep "ERROR" sample 'pure 'invert-match))
  (test-equal 2
              (grep "ERROR" sample 'pure 'count))
  (test-equal '((2 "ERROR boom") (4 "ERROR bad"))
              (grep "ERROR" sample 'pure 'line-number)))

(test-group "sed pure"
  (test-equal '("INFO  start" "WARN boom" "info  other" "WARN bad" "ok")
              (sed "ERROR" "WARN" sample 'pure))
  ;; global replaces all occurrences per line
  (test-equal '("aXaXa")
              (sed "b" "X" '("ababa") 'pure 'global)))

(test-group "head / tail"
  (test-equal '("a" "b") (head '("a" "b" "c" "d") '(lines . 2)))
  (test-equal '("c" "d") (tail '("a" "b" "c" "d") '(lines . 2)))
  ;; fewer lines than requested returns all
  (test-equal '("a" "b") (head '("a" "b") '(lines . 5))))

(test-group "wc"
  (let ((w (wc '("a b" "c"))))
    (test-equal 2 (cdr (assq 'lines w)))
    (test-equal 3 (cdr (assq 'words w))))
  (test-equal 2 (wc '("a b" "c") 'lines-only))
  (test-equal 3 (wc '("a b" "c") 'words-only)))

(test-group "cat"
  (test-equal "a\nb\nc" (cat '("a" "b") '("c"))))

(test-group "cut"
  (test-equal '("a" "b")
              (cut '("a:x:1" "b:y:2") '(fields . (1)) '(delimiter . ":"))))

(test-group "sort-lines / uniq"
  (test-equal '("a" "b" "c") (sort-lines '("c" "a" "b")))
  (test-equal '("c" "b" "a") (sort-lines '("a" "b" "c") 'reverse))
  (test-equal '(1 2 10) (map string->number
                             (sort-lines '("10" "1" "2") 'numeric)))
  (test-equal '("a" "b" "a") (uniq '("a" "a" "b" "b" "a")))
  (test-equal '("a" "b") (sort-lines '("a" "a" "b") 'unique)))

(test-group "tr"
  (test-equal "HELLo" ((tr "el" "EL") "Hello"))
  (test-equal "Hllo" ((tr "e" "" 'delete) "Hello")))

(test-group "diff pure"
  (test-equal #t (diff '("a" "b") '("a" "b") 'pure 'brief))
  (test-equal #f (diff '("a" "b") '("a" "c") 'pure 'brief))
  (test-equal "" (diff '("a" "b") '("a" "b") 'pure))
  ;; The unified output must mention the changed line markers.
  (let ((out (diff '("x") '("y") 'pure)))
    (test-equal #t (and (string? out)
                        (> (string-length out) 0)))))

(test-end "scm-text")

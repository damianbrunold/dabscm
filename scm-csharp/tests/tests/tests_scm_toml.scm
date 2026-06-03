(import (scheme base) (scheme inexact) (scm toml) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-toml")

(test-group "toml-parse: scalars"
  (test-equal '(("a" . 42))     (toml-parse "a = 42"))
  (test-equal '(("a" . -7))     (toml-parse "a = -7"))
  (test-equal '(("a" . 2.5))    (toml-parse "a = 2.5"))
  (test-equal '(("a" . 1000.0)) (toml-parse "a = 1e3"))
  (test-equal '(("a" . #t))     (toml-parse "a = true"))
  (test-equal '(("a" . #f))     (toml-parse "a = false"))
  (test-equal '(("a" . "hi"))   (toml-parse "a = \"hi\""))
  ;; underscores and non-decimal bases
  (test-equal '(("a" . 1000))   (toml-parse "a = 1_000"))
  (test-equal '(("a" . 255))    (toml-parse "a = 0xFF"))
  (test-equal '(("a" . 15))     (toml-parse "a = 0o17"))
  (test-equal '(("a" . 5))      (toml-parse "a = 0b101")))

(test-group "toml-parse: float specials"
  (test-assert (infinite? (toml-ref (toml-parse "a = inf") "a")))
  (test-assert (let ((v (toml-ref (toml-parse "a = -inf") "a")))
                 (and (infinite? v) (negative? v))))
  (test-assert (nan? (toml-ref (toml-parse "a = nan") "a"))))

(test-group "toml-parse: strings"
  (test-equal '(("s" . "a\nb\t\"c")) (toml-parse "s = \"a\\nb\\t\\\"c\""))
  (test-equal '(("s" . "é"))         (toml-parse "s = \"\\u00e9\""))
  ;; literal strings have no escapes
  (test-equal '(("s" . "C:\\path"))  (toml-parse "s = 'C:\\path'"))
  ;; multi-line basic: leading newline trimmed
  (test-equal '(("s" . "hello\nworld")) (toml-parse "s = \"\"\"\nhello\nworld\"\"\""))
  ;; line-ending backslash trims the newline and following whitespace
  (test-equal '(("s" . "ab")) (toml-parse "s = \"\"\"a\\\n   b\"\"\""))
  ;; multi-line literal: no escapes, leading newline trimmed
  (test-equal '(("s" . "raw\\n")) (toml-parse "s = '''\nraw\\n'''")))

(test-group "toml-parse: arrays"
  (test-equal '(("a" . #()))      (toml-parse "a = []"))
  (test-equal '(("a" . #(1 2 3))) (toml-parse "a = [1, 2, 3]"))
  (test-equal '(("a" . #(#(1 2) #(3)))) (toml-parse "a = [[1, 2], [3]]"))
  ;; multi-line arrays with a trailing comma
  (test-equal '(("a" . #(1 2 3))) (toml-parse "a = [\n  1,\n  2,\n  3,\n]")))

(test-group "toml-parse: tables and dotted keys"
  (test-equal '(("owner" ("name" . "Tom") ("age" . 36)))
              (toml-parse "[owner]\nname = \"Tom\"\nage = 36"))
  (test-equal '(("a" ("b" ("c" . 1)) ("d" . 2)))
              (toml-parse "a.b.c = 1\na.d = 2"))
  (test-equal '(("a" ("b" ("c" . 1))))
              (toml-parse "[a.b]\nc = 1"))
  ;; quoted keys
  (test-equal '(("a.b" . 1)) (toml-parse "\"a.b\" = 1")))

(test-group "toml-parse: inline tables"
  (test-equal '(("p" ("x" . 1) ("y" . 2))) (toml-parse "p = { x = 1, y = 2 }"))
  (test-equal '(("p")) (toml-parse "p = {}")))

(test-group "toml-parse: array of tables"
  (test-equal '(("p" . #((("n" . "a")) (("n" . "b")))))
              (toml-parse "[[p]]\nn = \"a\"\n[[p]]\nn = \"b\""))
  (test-equal '(("fruit" . #((("name" . "apple") ("physical" ("color" . "red")))
                             (("name" . "banana")))))
              (toml-parse (string-append
                           "[[fruit]]\nname = \"apple\"\n"
                           "[fruit.physical]\ncolor = \"red\"\n"
                           "[[fruit]]\nname = \"banana\"\n"))))

(test-group "toml-parse: date-times"
  (let ((dt (toml-ref (toml-parse "d = 1979-05-27T07:32:00Z") "d")))
    (test-assert (toml-datetime? dt))
    (test-equal 'offset-date-time (toml-datetime-kind dt))
    (test-equal "1979-05-27T07:32:00Z" (toml-datetime-text dt)))
  (test-equal 'offset-date-time
              (toml-datetime-kind (toml-ref (toml-parse "d = 1979-05-27T00:32:00-07:00") "d")))
  (test-equal 'local-date-time
              (toml-datetime-kind (toml-ref (toml-parse "d = 1979-05-27T07:32:00") "d")))
  (test-equal 'local-date
              (toml-datetime-kind (toml-ref (toml-parse "d = 1979-05-27") "d")))
  (test-equal 'local-time
              (toml-datetime-kind (toml-ref (toml-parse "d = 07:32:00.5") "d")))
  ;; a space may separate date and time
  (test-equal 'local-date-time
              (toml-datetime-kind (toml-ref (toml-parse "d = 1979-05-27 07:32:00") "d"))))

(test-group "toml-parse: comments and blank lines"
  (test-equal '(("a" . 1)) (toml-parse "# header comment\na = 1 # trailing\n"))
  (test-equal '(("a" . 1) ("b" . 2)) (toml-parse "\n\na = 1\n\n  \nb = 2\n")))

(test-group "toml->string: scalars and tables"
  (test-equal "a = 1\n" (toml->string '(("a" . 1))))
  (test-equal "a = true\nb = false\n" (toml->string '(("a" . #t) ("b" . #f))))
  (test-equal "s = \"a\\nb\\\"c\"\n" (toml->string '(("s" . "a\nb\"c"))))
  (test-equal "d = 1.0\n" (toml->string '(("d" . 1.0))))
  ;; keys that are not bare keys get quoted
  (test-equal "\"a b\" = 1\n" (toml->string '(("a b" . 1))))
  ;; arrays
  (test-equal "a = [1, 2, 3]\n" (toml->string '(("a" . #(1 2 3)))))
  ;; nested tables become [header] sections, scalars first
  (test-equal "x = 1\n\n[t]\ny = 2\n" (toml->string '(("x" . 1) ("t" ("y" . 2))))))

(test-group "toml->string: float specials"
  (test-equal "a = inf\n"  (toml->string `(("a" . ,+inf.0))))
  (test-equal "a = -inf\n" (toml->string `(("a" . ,-inf.0))))
  (test-equal "a = nan\n"  (toml->string `(("a" . ,+nan.0)))))

(test-group "round-trip parse <-> string"
  (let ((doc (toml-parse (string-append
                          "title = \"x\"\n"
                          "nums = [1, 2, 3]\n"
                          "pi = 3.5\n"
                          "[owner]\n"
                          "name = \"Tom\"\n"
                          "[[items]]\n"
                          "id = 1\n"
                          "[[items]]\n"
                          "id = 2\n"))))
    (test-equal doc (toml-parse (toml->string doc)))))

(test-group "toml-read: from a port"
  (test-equal '(("a" . 1)) (toml-read (open-input-string "a = 1")))
  (test-assert (eof-object? (toml-read (open-input-string "")))))

(test-group "toml-ref"
  (test-equal 2       (toml-ref '(("a" . 1) ("b" . 2)) "b"))
  (test-equal #f      (toml-ref '(("a" . 1)) "z"))
  (test-equal 'missing (toml-ref '(("a" . 1)) "z" 'missing))
  (test-equal #f      (toml-ref '() "a")))

(test-group "toml-datetime constructor"
  (let ((dt (make-toml-datetime 'local-date "2020-01-01")))
    (test-assert (toml-datetime? dt))
    (test-equal 'local-date (toml-datetime-kind dt))
    (test-equal "2020-01-01" (toml-datetime-text dt))
    ;; datetimes write out their raw text, unquoted
    (test-equal "d = 2020-01-01\n" (toml->string (list (cons "d" dt))))))

(test-group "toml-parse: malformed input raises"
  (test-error (toml-parse "a ="))
  (test-error (toml-parse "a = [1, 2"))
  (test-error (toml-parse "a = 1\na = 2"))
  (test-error (toml-parse "= 1"))
  (test-error (toml-parse "a = \"unterminated")))

(test-end "scm-toml")

(import (scheme base) (scm net http forms) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-http-forms")

(test-group "parse-www-form"
  (test-equal '() (parse-www-form ""))
  (test-equal '() (parse-www-form #f))
  (test-equal '(("a" . "1")) (parse-www-form "a=1"))
  (test-equal '(("a" . "1") ("b" . "2")) (parse-www-form "a=1&b=2"))
  ;; keys with no '=' get empty string
  (test-equal '(("flag" . "")) (parse-www-form "flag"))
  ;; percent and '+' decoding applies to keys and values
  (test-equal '(("name" . "Ada Lovelace"))
              (parse-www-form "name=Ada+Lovelace"))
  (test-equal '(("name" . "a/b"))
              (parse-www-form "name=a%2Fb"))
  ;; '=' inside a value is preserved
  (test-equal '(("eq" . "1=2"))
              (parse-www-form "eq=1=2")))

(test-group "form-ref"
  (define f '(("name" . "Ada") ("age" . "37")))
  (test-equal "Ada" (form-ref f "name"))
  (test-equal "37"  (form-ref f "age"))
  (test-equal #f    (form-ref f "missing"))
  (test-equal "default" (form-ref f "missing" "default")))

(test-group "form-refs-by-prefix"
  (define f '(("opt-a" . "1") ("name" . "x") ("opt-b" . "2")))
  (test-equal '(("opt-a" . "1") ("opt-b" . "2"))
              (form-refs-by-prefix f "opt-"))
  (test-equal '() (form-refs-by-prefix f "zzz-"))
  ;; empty prefix returns all
  (test-equal f (form-refs-by-prefix f "")))

(test-end "scm-http-forms")

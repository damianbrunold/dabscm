(import (scheme base) (scm database postgres) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-db-postgres")

;; Network-dependent functionality (pg-connect, queries) is not tested
;; here. These tests cover the quoting helpers, which are pure and
;; safety-critical: every caller that builds SQL strings depends on
;; them to neutralise user-controlled input.

(test-group "pg-quote-literal"
  (test-equal "''" (pg-quote-literal ""))
  (test-equal "'hello'" (pg-quote-literal "hello"))
  ;; The classic injection target: O'Brien.
  (test-equal "'O''Brien'" (pg-quote-literal "O'Brien"))
  ;; Multiple single quotes.
  (test-equal "''''''" (pg-quote-literal "''"))
  ;; Backslash stays literal (standard_conforming_strings=on assumption).
  (test-equal "'a\\nb'" (pg-quote-literal "a\\nb"))
  ;; Newlines, semicolons, comment markers pass through as-is.
  (test-equal "'a;b--c'" (pg-quote-literal "a;b--c"))
  (test-equal "'a\nb'" (pg-quote-literal "a\nb")))

(test-group "pg-quote-int"
  (test-equal "42"   (pg-quote-int 42))
  (test-equal "0"    (pg-quote-int 0))
  (test-equal "-7"   (pg-quote-int -7))
  ;; Numeric strings are accepted and normalised.
  (test-equal "42"   (pg-quote-int "42"))
  (test-equal "-7"   (pg-quote-int "-7"))
  ;; Non-integer string is rejected (would otherwise enable injection).
  (test-equal #t
    (guard (exn (#t #t))
      (pg-quote-int "1; DROP TABLE users--")
      #f))
  (test-equal #t
    (guard (exn (#t #t))
      (pg-quote-int "1.5")
      #f))
  (test-equal #t
    (guard (exn (#t #t))
      (pg-quote-int 'symbol)
      #f)))

(test-end "scm-db-postgres")

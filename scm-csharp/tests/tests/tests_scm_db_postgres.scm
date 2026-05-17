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

(test-group "pg-format-sql: value→literal conversion"
  (test-equal "WHERE x = 42"
              (pg-format-sql "WHERE x = $1" '(42)))
  (test-equal "WHERE x = -7"
              (pg-format-sql "WHERE x = $1" '(-7)))
  ;; Strings are quoted; embedded single quotes doubled.
  (test-equal "WHERE name = 'O''Brien'"
              (pg-format-sql "WHERE name = $1" '("O'Brien")))
  ;; #f → NULL, #t → TRUE (symmetric with read-side: NULL is reported as #f)
  (test-equal "WHERE x IS NULL OR y = NULL"
              (pg-format-sql "WHERE x IS NULL OR y = $1" '(#f)))
  (test-equal "WHERE enabled = TRUE"
              (pg-format-sql "WHERE enabled = $1" '(#t)))
  ;; Real numbers convert via inexact.
  (test-equal "INSERT VALUES (0.5)"
              (pg-format-sql "INSERT VALUES ($1)" '(1/2)))
  ;; Bytevectors as bytea hex literals.
  (test-equal "INSERT VALUES ('\\x00ff'::bytea)"
              (pg-format-sql "INSERT VALUES ($1)" '(#u8(0 255))))
  ;; Unsupported types raise.
  (test-equal #t
              (guard (exn (#t #t))
                (pg-format-sql "$1" '(symbol))
                #f)))

(test-group "pg-format-sql: IN-lists from list params"
  ;; A list expands to a parenthesised IN-list. Elements use the same
  ;; conversion rules.
  (test-equal "WHERE id IN (1, 2, 3)"
              (pg-format-sql "WHERE id IN $1" '((1 2 3))))
  (test-equal "WHERE name IN ('a', 'O''Brien')"
              (pg-format-sql "WHERE name IN $1" '(("a" "O'Brien"))))
  ;; Mixed types, including NULL via #f.
  (test-equal "(1, NULL, 'x')"
              (pg-format-sql "$1" '((1 #f "x"))))
  ;; Empty list → (NULL) so `x IN $1` is always false rather than a
  ;; SQL syntax error.
  (test-equal "WHERE id IN (NULL)"
              (pg-format-sql "WHERE id IN $1" '(())))
  ;; List works as one positional param among others.
  (test-equal "a = 'x' AND b IN (1, 2)"
              (pg-format-sql "a = $1 AND b IN $2" '("x" (1 2))))
  ;; Vectors are accepted with the same semantics.
  (test-equal "WHERE id IN (1, 2, 3)"
              (pg-format-sql "WHERE id IN $1" '(#(1 2 3))))
  (test-equal "WHERE id IN (NULL)"
              (pg-format-sql "WHERE id IN $1" '(#()))))

(test-group "pg-format-sql: multiple params, reuse, ordering"
  (test-equal "a = 'foo' AND b = 'bar' AND a = 'foo'"
              (pg-format-sql "a = $1 AND b = $2 AND a = $1"
                             '("foo" "bar")))
  (test-equal "10 + 20 = 30"
              (pg-format-sql "$1 + $2 = $3" '(10 20 30)))
  ;; Multi-digit placeholder numbers.
  (test-equal "x=10, y=11"
              (pg-format-sql "x=$10, y=$11"
                             '(0 0 0 0 0 0 0 0 0 10 11))))

(test-group "pg-format-sql: substitution skipped inside strings/idents"
  ;; A '$1' inside a single-quoted SQL literal is verbatim, not a placeholder.
  (test-equal "WHERE name = '$1 literal'"
              (pg-format-sql "WHERE name = '$1 literal'" '("unused")))
  ;; Doubled single quotes ('') inside a string literal don't terminate it.
  (test-equal "WHERE x = 'O''Brien $1'"
              (pg-format-sql "WHERE x = 'O''Brien $1'" '("unused")))
  ;; Inside a quoted identifier — same.
  (test-equal "SELECT \"col $1\" FROM t"
              (pg-format-sql "SELECT \"col $1\" FROM t" '("unused")))
  ;; Inside line comment, then real substitution on next line.
  (test-equal "-- $1 ignored\nWHERE x = 42"
              (pg-format-sql "-- $1 ignored\nWHERE x = $2"
                             '("unused" 42)))
  ;; Inside block comment.
  (test-equal "/* $1 */ WHERE x = 'y'"
              (pg-format-sql "/* $1 */ WHERE x = $2"
                             '("unused" "y")))
  ;; Inside dollar-quoted string (the seed format used by the migrations).
  (test-equal "INSERT $seed$body has $1 in it$seed$ HERE 'y'"
              (pg-format-sql "INSERT $seed$body has $1 in it$seed$ HERE $1"
                             '("y")))
  ;; Empty-tag dollar quote.
  (test-equal "$$contains $1$$ and 'y'"
              (pg-format-sql "$$contains $1$$ and $1" '("y"))))

(test-group "pg-format-sql: errors"
  ;; $0 is not a valid placeholder (params are 1-indexed).
  (test-equal #t
              (guard (exn (#t #t))
                (pg-format-sql "$0" '("x"))
                #f))
  ;; $N where N > param count.
  (test-equal #t
              (guard (exn (#t #t))
                (pg-format-sql "$3" '("only-one"))
                #f))
  ;; Unterminated single-quoted string.
  (test-equal #t
              (guard (exn (#t #t))
                (pg-format-sql "WHERE x = 'unclosed" '())
                #f)))

(test-group "pg-format-sql: empty / lone-$ edge cases"
  ;; No placeholders, no params.
  (test-equal "SELECT 1" (pg-format-sql "SELECT 1" '()))
  ;; Lone $ not followed by digit/letter passes through.
  (test-equal "money=$ value"
              (pg-format-sql "money=$ value" '()))
  ;; Empty template.
  (test-equal "" (pg-format-sql "" '())))

(test-end "scm-db-postgres")

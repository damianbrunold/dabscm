;; Regressions for bugs scm lint found: procedures that used names their
;; library did not import (they failed with "... is not bound" when
;; called) and a docstring cut short by unescaped quotes.

(import (scheme base)
        (scheme complex)
        (scheme read)
        (only (srfi 13) string-contains)
        (srfi 64)
        (scm compile)
        (scm doc)
        (scm io)
        (scm ooxml word-reader)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "lint regressions")

(test-group "(scm compile) atom?"
  (test-equal #t (atom? 42))
  (test-equal #t (atom? 'x))
  (test-equal #t (atom? "s"))
  (test-equal #t (atom? #\a))
  (test-equal #t (atom? #f))
  (test-equal #f (atom? '(1))))

(test-group "(scheme complex) angle of a negative real"
  (test-assert (< (abs (- (angle -1.0) 3.141592653589793)) 1e-12))
  (test-equal 0.0 (angle 1.0)))

(test-group "(scm io) with-input-from-string"
  (test-equal 'hello (with-input-from-string "hello" read)))

(test-group "(srfi 64) test-read-eval-string"
  (test-equal 3 (test-read-eval-string "(+ 1 2)")))

(test-group "(scm ooxml word-reader) docstring"
  (test-assert (string-contains (procedure-doc paragraph-heading-level)
                                "the German \"berschrift1\" are recognised")))

(test-end "lint regressions")

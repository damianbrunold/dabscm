;; (scm doc): procedure-doc of a procedure, or of a symbol naming a
;; primitive or a procedure of the program (native once returned #f for
;; symbols)

(import (scheme base)
        (scheme char)
        (scm doc)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-doc")

(define (double x)
  "Syntax: (double x)\nDescription: Twice x."
  (* 2 x))

(define (doc-start d) (and (string? d) (substring d 0 (min 18 (string-length d)))))

(test-group "procedure-doc"
  (test-equal "Syntax: (car pair)" (doc-start (procedure-doc car)))
  (test-equal "Syntax: (car pair)" (doc-start (procedure-doc 'car)))
  (test-equal "Syntax: (string-up" (doc-start (procedure-doc string-upcase)))
  (test-equal "Syntax: (double x)\nDescription: Twice x." (procedure-doc double))
  (test-equal "Syntax: (double x)\nDescription: Twice x." (procedure-doc 'double))
  (test-equal #f (procedure-doc 'no-such-binding-anywhere))
  (test-equal #f (procedure-doc (lambda (x) x))))

(test-end "scm-doc")

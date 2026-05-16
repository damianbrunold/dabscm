(import (scheme base)
        (scm test)
        (srfi 2))

(test-runner-factory scm-test-runner)

(test-begin "srfi-2")

;; Basic (var expr) form
(test-equal 10 (and-let* ((x 5) (y (* x 2))) y))
;; Short-circuit on #f
(test-equal #f (and-let* ((x #f) (y 1)) y))
;; Multiple bindings
(test-equal 7 (and-let* ((x 3) (y 4) (z (+ x y))) z))

;; (expr) form — test without binding
(test-equal 5 (and-let* (((= 1 1)) (x 5)) x))
(test-equal #f (and-let* (((= 1 2)) (x 5)) x))
;; Mix of forms
(test-equal 30 (and-let* ((x 3) ((> x 0)) (y (* x 10))) y))
(test-equal #f (and-let* ((x -1) ((> x 0)) (y (* x 10))) y))

;; Bare var form — test existing variable
(test-equal 42 (let ((myval 42)) (and-let* (myval) myval)))

;; Bare var form — #f short-circuits
(test-equal #f (let ((myfalse #f)) (and-let* (myfalse) myfalse)))

;; Empty bindings — just execute body
(test-equal 99 (and-let* () 99))
(test-equal 3 (and-let* () (+ 1 2)))

(test-end "srfi-2")

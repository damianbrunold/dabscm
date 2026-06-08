(import (scheme base)
        (scheme write)
        (srfi 1)
        (scm test)
        (scm geiser))

(test-runner-factory scm-test-runner)

(test-begin "geiser")

;; Helpers to pull fields out of the retort alist that geiser:eval returns:
;;   ((result <string>) (output . <string>))
(define (retort-result r) (cadr (assq 'result r)))
(define (retort-output r) (cdr (assq 'output r)))

(test-group "geiser:eval result/output shape"
  (let ((r (geiser:eval #f '(+ 1 2))))
    (test-equal "3" (retort-result r))
    (test-equal "" (retort-output r)))
  ;; Output produced by the evaluated form is captured into the output field,
  ;; not printed to the real stdout.
  (let ((r (geiser:eval #f '(begin (display "hi") 42))))
    (test-equal "42" (retort-result r))
    (test-equal "hi" (retort-output r)))
  ;; Strings are written (machine readable) so geiser can read them back.
  (let ((r (geiser:eval #f '(string-append "a" "b"))))
    (test-equal "\"ab\"" (retort-result r))))

(test-group "geiser:eval error handling"
  ;; Errors are reported in the result, never raised to the driving REPL.
  (let ((r (geiser:eval #f '(car '()))))
    (test-assert (string? (retort-result r)))
    (test-assert (> (string-length (retort-result r)) 0))))

(test-group "geiser:completions"
  (let ((cs (geiser:completions "ca")))
    (test-assert (list? cs))
    (test-assert (member "car" cs))
    (test-assert (member "cadr" cs))
    ;; Every completion actually starts with the prefix.
    (test-assert (every (lambda (s) (string=? "ca" (substring s 0 2))) cs))))

(test-group "geiser:module-completions"
  (let ((ms (geiser:module-completions "(scheme")))
    (test-assert (member "(scheme base)" ms))))

(test-group "geiser:autodoc"
  ;; (map proc list1 list2 ...) -> required proc list1 list2, optional "..."
  (let* ((ad (geiser:autodoc '(map)))
         (entry (car ad))
         (args (cadr (cadr entry)))      ; the list of arg groups
         (required (cdr (assoc "required" args)))
         (optional (cdr (assoc "optional" args))))
    (test-equal 'map (car entry))
    (test-assert (memq 'proc required))
    (test-assert (member "..." optional)))
  ;; Unknown symbols degrade gracefully to (id ()).
  (test-equal '(definitely-not-bound-xyz ())
              (car (geiser:autodoc '(definitely-not-bound-xyz)))))

(test-group "geiser:macroexpand"
  (test-assert (string? (geiser:macroexpand '(when #t 1)))))

(test-group "geiser:locations (not tracked)"
  (test-equal '() (geiser:symbol-location 'car))
  (test-equal '() (geiser:module-location '(scheme base))))

(test-end "geiser")

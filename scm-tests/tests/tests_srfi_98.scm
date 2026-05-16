(import (scheme base)
        (scm test)
        (srfi 98))

(test-runner-factory scm-test-runner)

(test-begin "srfi-98")

;; get-environment-variables returns a list
(test-assert (list? (get-environment-variables)))
;; Each element is a pair of strings
(test-assert (let ((vars (get-environment-variables)))
  (and (pair? vars) (pair? (car vars))
       (string? (caar vars)) (string? (cdar vars)))))
;; get-environment-variable returns #f for undefined variable
(test-equal #f (get-environment-variable "THIS_VAR_IS_CERTAINLY_NOT_SET_SPLG"))
;; get-environment-variable returns a string for defined variables
(test-assert (string? (get-environment-variable "PATH")))

(test-end "srfi-98")

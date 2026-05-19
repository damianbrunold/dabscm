(import (scheme base)
        (scm sysadmin)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-sysadmin")

;; This suite simply confirms that the umbrella library re-exports the
;; expected vocabulary, by exercising one symbol from each underlying
;; library through the (scm sysadmin) import.

(test-group "re-exports"
  ;; (scm fs)
  (test-equal #t (procedure? mktemp))
  (test-equal #t (procedure? touch))
  (test-equal #t (procedure? rm))
  ;; (scm fs-find)
  (test-equal #t (procedure? find))
  (test-equal #t (procedure? du))
  ;; (scm text)
  (test-equal #t (procedure? grep))
  (test-equal #t (procedure? diff))
  ;; (scm archive)
  (test-equal #t (procedure? tar-create))
  (test-equal #t (procedure? gzip))
  ;; (scm net-remote)
  (test-equal #t (procedure? curl))
  (test-equal #t (procedure? ssh))
  ;; (scm system)
  (test-equal #t (procedure? sys-platform))
  (test-equal #t (procedure? run-program/capture)))

(test-end "scm-sysadmin")

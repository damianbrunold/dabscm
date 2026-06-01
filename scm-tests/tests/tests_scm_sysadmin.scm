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
  (test-equal #t (procedure? find-file))
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
  (test-equal #t (procedure? run-program/capture))
  (test-equal #t (procedure? current-pid))
  (test-equal #t (procedure? parent-pid))
  (test-equal #t (procedure? ps))
  (test-equal #t (procedure? ps-info))
  (test-equal #t (procedure? pgrep))
  (test-equal #t (procedure? pkill))
  (test-equal #t (procedure? kill)))

(test-group "process-management"
  (let ((pid (current-pid)))
    (test-equal #t (integer? pid))
    (test-equal #t (positive? pid))
    ;; ps-info on the current pid must succeed and report our pid.
    (let ((info (ps-info pid)))
      (test-equal #t (pair? info))
      (test-equal pid (cdr (assq 'pid info))))
    ;; ps returns a non-empty list containing an alist for our own pid.
    (let* ((all (ps))
           (mine (let loop ((xs all))
                   (cond ((null? xs) #f)
                         ((equal? (cdr (assq 'pid (car xs))) pid) (car xs))
                         (else (loop (cdr xs)))))))
      (test-equal #t (pair? all))
      (test-equal #t (pair? mine)))
    ;; ps-info on a definitely-unused pid returns #f.
    (test-equal #f (ps-info 2147483646))
    ;; kill on a definitely-unused pid returns #f rather than raising.
    (test-equal #f (kill 2147483646))))

(test-end "scm-sysadmin")

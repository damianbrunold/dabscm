;; r-convert.scm — translates an analysis script between R (tidyverse)
;; and (scm data), best effort, with (scm data r).
;;
;;   scm r-convert.scm analysis.R      prints the (scm data) translation
;;   scm r-convert.scm analysis.scm    prints the R translation
;;
;; What has no counterpart is marked in the output (TODO comments,
;; r:unsupported, stop("TODO …")) and, for R input, listed at the end.

(import (scheme base)
        (scheme process-context)
        (scheme write)
        (srfi 13)
        (scm data r))

(define args (cdr (command-line)))

(when (null? args)
  (display "usage: scm r-convert.scm file.R | file.scm\n" (current-error-port))
  (exit 2))

(define path (car args))

(cond
 ((or (string-suffix-ci? ".r" path) (string-suffix-ci? ".rmd" path))
  (let-values (((text unsupported) (r-file->scm path)))
    (display text)
    (unless (null? unsupported)
      (display "\n;; not translated:\n")
      (for-each (lambda (s) (display ";;   ") (display s) (newline)) unsupported))))
 (else
  (display (scm-file->r path))))

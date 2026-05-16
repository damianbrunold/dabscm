(define-library (scm string)
  (import (scm core))
  (export string-matches
          string-replace-all
          string-split
          string-split-vector
          symbol-starts-with?)
  (begin
    (define string-matches (%primitive "string-matches"))
    (define string-replace-all (%primitive "string-replace-all"))
    (define string-split (%primitive "string-split"))
    (define string-split-vector (%primitive "string-split-vector"))
    (define symbol-starts-with? (%primitive "symbol-starts-with?"))))

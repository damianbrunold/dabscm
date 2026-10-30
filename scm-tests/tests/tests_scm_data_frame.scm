(import (scheme base) (srfi 13) (scm data core) (scm data frame) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-frame")

(define df (tibble (splg 'BEW8 'GYN2 'URO1.1.1) (pts 6441.0 1728.5 na) (n 10 20 30)))

(test-group "construction"
  (test-equal 3 (df-nrow df))
  (test-equal 3 (df-ncol df))
  (test-equal '(splg pts n) (df-names df))
  (test-equal '((splg . symbol) (pts . real) (n . int)) (df-types df))
  (test-equal 3 (df-nrow (make-df '((a . #(1 2 3)) (b . ("x" "y" "z"))))))
  ;; a single value is recycled
  (test-equal #(0 0) (df-column (make-df '((a . #(1 2)) (b . 0))) 'b))
  (let ((r (rows->df '(a b) '((1 "x") (2 "y") (3)))))
    (test-equal "y" (df-ref r 1 'b))
    (test-assert (na? (df-ref r 2 'b))))
  (let ((a (alists->df '(((a . 1)) ((a . 2) (b . "x"))))))
    (test-equal '(a b) (df-names a))
    (test-assert (na? (df-ref a 0 'b))))
  (test-equal '(b a) (df-names (alists->df '(((a . 1) (b . 2))) '(b a))))
  (test-error (make-df '((a . #(1 2)) (b . #(1)))))
  (test-error (make-df '((a . #(1)) (a . #(2))))))

(test-group "access"
  (test-equal #(10 20 30) (df-column df 'n))
  (test-equal 20 (df-ref df 1 'n))
  (test-equal '((splg . GYN2) (pts . 1728.5) (n . 20)) (df-row df 1))
  (test-equal '(BEW8 6441.0 10) (car (df->rows df)))
  (test-equal 3 (length (df->alists df)))
  (test-error (df-column df 'nope))
  (test-assert (df-has-column? df 'pts))
  (test-assert (not (df-has-column? df 'x))))

(test-group "column operations"
  (test-equal '(splg pts n m) (df-names (df-with-column df 'm 1)))
  (test-equal #(1 2 3) (df-column (df-with-column df 'n '(1 2 3)) 'n))
  (test-equal '(n splg) (df-names (df-select-columns df '(n splg))))
  (test-equal '(splg n) (df-names (df-drop-columns df '(pts))))
  (test-equal '(x pts n) (df-names (df-rename-columns df '((splg . x)))))
  (test-equal #(30 10) (df-column (df-take df #(2 0)) 'n))
  (test-equal '(splg) (df-groups (df-set-groups df '(splg))))
  ;; grouping survives column changes, renames follow
  (test-equal '(x) (df-groups (df-rename-columns (df-set-groups df '(splg)) '((splg . x)))))
  (test-equal '() (df-groups (df-drop-columns (df-set-groups df '(splg)) '(splg)))))

(test-group "printing"
  (let ((s (df->string df)))
    (test-assert (string? s))
    (test-assert (string-contains s "3 × 3"))
    (test-assert (string-contains s "<dbl>"))
    (test-assert (string-contains s "1728.5")))
  (test-assert (string-contains (df->string (tibble (a 1 2 3)) 2) "1 more rows")))

(test-end "scm-data-frame")

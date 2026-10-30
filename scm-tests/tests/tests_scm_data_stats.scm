(import (scheme base) (scm data core) (scm data frame) (scm data stats) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-stats")

;; reference values computed with R 4.x
(define xs '(2 4 4 4 5 5 7 9))

(test-group "location and spread"
  (test-equal 40 (sum xs))
  (test-equal 6 (sum (list 1 2 na 3)))
  (test-equal 5.0 (mean xs))
  (test-equal 2.5 (mean #(1 2 3 4)))
  (test-assert (na? (mean '())))
  (test-equal 9/2 (median xs))
  (test-equal 1.75 (quantile '(1 2 3 4) 0.25))
  (test-equal '(4 11/2) (quantile xs '(1/4 3/4)))   ; R: 4.0 5.5
  (test-approximate 4.571429 (var xs) 1e-6)          ; R: var(x)
  (test-approximate 2.13809 (sd xs) 1e-5)            ; R: sd(x)
  (test-equal 3/2 (iqr xs))                          ; R: IQR(x) = 1.5
  (test-equal '(1 7) (value-range (list 3 na 1 7)))
  (test-assert (na? (var '(1))))
  (test-equal 1.5 (weighted-mean '(1 3) '(3 1))))

(test-group "transformations"
  (test-equal '(1 3 na 6) (map (lambda (x) (if (na? x) 'na x)) (cumsum (list 1 2 na 3)))
              )
  (test-equal '(1.5 3 1.5 4) (ranks '(10 20 10 30)))
  (test-equal '(1 3 1 4) (ranks '(10 20 10 30) 'min))
  (test-equal '(1 2 1 3) (ranks '(10 20 10 30) 'dense))
  (test-equal '(-1.0 0.0 1.0) (zscore '(1 2 3)))
  (test-equal 0.25 (pct-change 200 250))
  (test-assert (na? (pct-change 0 5))))

(test-group "association"
  (test-equal 2.0 (cov '(1 2 3) '(2 4 6)))
  (test-approximate 0.8 (cor '(1 2 3 4) '(1 3 2 4)) 1e-9)
  ;; R: cor(c(1,2,3,4,5), c(5,6,7,8,7), method="spearman") = 0.8207827
  (test-approximate 0.8207827 (cor '(1 2 3 4 5) '(5 6 7 8 7) 'spearman) 1e-6)
  (let ((m (lm-simple '(1 2 3 4) '(3 5 7 9))))
    (test-equal 2.0 (cdr (assq 'slope m)))
    (test-equal 1.0 (cdr (assq 'intercept m)))
    (test-equal 1.0 (cdr (assq 'r2 m))))
  ;; R: summary(lm(y ~ x))$r.squared for x=1:5, y=c(2,4,5,4,5) = 0.6
  (test-approximate 0.6 (cdr (assq 'r2 (lm-simple '(1 2 3 4 5) '(2 4 5 4 5)))) 1e-9))

(test-group "tables"
  (let ((f (freq '(b a b c b))))
    (test-equal #(a b c) (df-column f 'value))
    (test-equal #(1 3 1) (df-column f 'n))
    (test-equal 0.6 (df-ref f 1 'share)))
  (test-equal #(b a c) (df-column (freq '(b a b c b) 'by-count) 'value))
  (let ((t (crosstab '(a a b) '(x y x))))
    (test-equal '(row x y) (df-names t))
    (test-equal #(1 1) (df-column t 'x)))
  (let ((t (crosstab '(a a b) '(x y x) #t)))
    (test-equal '(row x y total) (df-names t))
    (test-equal #(a b "total") (df-column t 'row))
    (test-equal #(2 1 3) (df-column t 'total)))
  (let ((h (histogram-bins '(1 2 2 3 7) 3)))
    (test-equal #(3 1 1) (df-column h 'n))
    (test-equal 1 (df-ref h 0 'from)))
  (let ((h (histogram-bins '(0.5 1 9.9 10) 'width 5)))
    (test-equal #(0 5 10) (df-column h 'from))
    (test-equal #(2 1 1) (df-column h 'n))))

(test-end "scm-data-stats")

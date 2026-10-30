(import (scheme base) (scm data core) (scm data frame) (scm data tests) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-tests")

;; reference values computed with R 4.x (stats package); data sets are
;; R's sleep and mtcars

(define (ref h key) (htest-ref h key))

(test-group "distributions"
  (test-approximate 3.1780538303479458 (lgamma 5) 1e-12)
  (test-approximate 0.5723649429247001 (lgamma 0.5) 1e-12)
  (test-approximate 0.9750021048517795 (pnorm 1.96) 1e-12)
  (test-approximate 0.0249978951482205 (pnorm 1.96 0 1 #f) 1e-14)
  (test-approximate 1.959963984540054 (qnorm 0.975) 1e-12)
  (test-approximate -2.326347874040841 (qnorm 0.01) 1e-12)
  (test-approximate 9.865876450377e-10 (pnorm -6) 1e-20)
  (test-approximate 0.3989422804014327 (dnorm 0) 1e-14)
  (test-approximate 2.228138851964939 (qt 0.975 10) 1e-9)
  (test-approximate 0.975 (pt 2.228138851964939 10) 1e-12)
  (test-approximate 0.05 (* 2 (pt -2.228138851964939 10)) 1e-10)
  (test-approximate 12.70620473617471 (qt 0.975 1) 1e-8)
  (test-approximate 3.841458820694124 (qchisq 0.95 1) 1e-9)
  (test-approximate 0.05 (pchisq 3.841458820694124 1 #f) 1e-10)
  (test-approximate 0.2150138 (pchisq 5.7947 4 #f) 1e-6)   ; exp(-x/2)(1+x/2)
  (test-approximate 4.964602743730711 (qf 0.95 1 10) 1e-8)
  (test-approximate 0.05 (pf 4.964602743730711 1 10 #f) 1e-10)
  (test-approximate 0.6875 (pbeta 0.5 2 3) 1e-12)
  (test-approximate 0.375 (dbinom 2 4 0.5) 1e-12)
  (test-approximate 0.6875 (pbinom 2 4 0.5) 1e-12)
  (test-approximate 0.3125 (pbinom 2 4 0.5 #f) 1e-12)
  (test-equal 5 (qbinom 0.5 10 0.5))
  (test-approximate 0.9196986029286058 (ppois 2 1) 1e-12)
  (test-approximate 0.3678794411714423 (dpois 0 1) 1e-12))

(define g1 '(0.7 -1.6 -0.2 -1.2 -0.1 3.4 3.7 0.8 0.0 2.0))
(define g2 '(1.9 0.8 1.1 0.1 -0.1 4.4 5.5 1.6 4.6 3.4))
(define sleep
  (make-df (list (cons 'extra (list->vector (append g1 g2)))
                 (cons 'group (list->vector (append (make-list 10 "1") (make-list 10 "2")))))))

(test-group "t-test"
  ;; t.test(extra ~ group, data = sleep)
  (let ((h (t-test sleep '(extra ~ group))))
    (test-equal "Welch Two Sample t-test" (htest-method h))
    (test-approximate -1.860813 (ref h 'statistic) 1e-6)
    (test-approximate 17.77647 (ref h 'parameter) 1e-5)
    (test-approximate 0.07939414 (ref h 'p-value) 1e-7)
    (test-approximate -3.3654832 (car (ref h 'conf-int)) 1e-6)
    (test-approximate 0.2054832 (cadr (ref h 'conf-int)) 1e-6)
    (test-equal '(0.75 2.33) (map (lambda (x) (/ (round (* x 100)) 100)) (ref h 'estimate)))
    (test-equal '("mean in group 1" "mean in group 2") (map car (htest-estimate h))))
  ;; var.equal = TRUE
  (let ((h (t-test g1 g2 'var-equal #t)))
    (test-equal 18 (ref h 'parameter))
    (test-approximate 0.07918671 (ref h 'p-value) 1e-7)
    (test-approximate -3.363874 (car (ref h 'conf-int)) 1e-6))
  ;; paired
  (let ((h (t-test g1 g2 'paired #t)))
    (test-approximate -4.062128 (ref h 'statistic) 1e-6)
    (test-equal 9 (ref h 'parameter))
    (test-approximate 0.002832890 (ref h 'p-value) 1e-8)
    (test-approximate -2.4598858 (car (ref h 'conf-int)) 1e-6)
    (test-approximate -0.7001142 (cadr (ref h 'conf-int)) 1e-6))
  ;; one sample, one-sided
  (let ((h (t-test g2 'mu 1 'alternative 'greater)))
    (test-approximate 2.100553 (ref h 'statistic) 1e-6)
    (test-approximate 0.03252994 (ref h 'p-value) 1e-7)
    (test-assert (= (cadr (ref h 'conf-int)) +inf.0)))
  (test-assert (string? (htest->string (t-test sleep '(extra ~ group)))))
  (let ((t (tidy (t-test sleep '(extra ~ group)))))
    (test-equal '(estimate estimate1 estimate2 statistic p-value parameter conf-low conf-high method alternative)
                (df-names t))
    (test-approximate -1.58 (df-ref t 0 'estimate) 1e-12)))

(test-group "wilcoxon"
  ;; wilcox.test(extra ~ group, data = sleep): ties -> normal approximation
  (let ((h (wilcox-test sleep '(extra ~ group))))
    (test-equal 25.5 (ref h 'statistic))
    (test-approximate 0.06932758 (ref h 'p-value) 1e-6))
  ;; paired, with a zero difference and ties
  (let ((h (wilcox-test g1 g2 'paired #t)))
    (test-equal 0.0 (ref h 'statistic))
    (test-approximate 0.009090698 (ref h 'p-value) 1e-7))
  ;; exact rank sum: 2/35
  (let ((h (wilcox-test '(1 2 3) '(4 5 6 7))))
    (test-equal "Wilcoxon rank sum exact test" (htest-method h))
    (test-equal 0.0 (ref h 'statistic))
    (test-approximate (/ 2.0 35) (ref h 'p-value) 1e-12))
  ;; exact signed rank: wilcox.test(c(1.83,0.50,1.62,2.48,1.68,1.88,1.55,3.06,1.30), mu = 1)
  ;; differences 0.83 -0.5 0.62 1.48 0.68 0.88 0.55 2.06 0.3: the one negative has
  ;; rank 2 -> V = 43, p = 2 * P(V <= 2) = 2 * 3/512
  (let ((h (wilcox-test '(1.83 0.50 1.62 2.48 1.68 1.88 1.55 3.06 1.30) 'mu 1)))
    (test-equal 43.0 (ref h 'statistic))
    (test-approximate 0.01171875 (ref h 'p-value) 1e-10)))

(test-group "chi-squared"
  ;; chisq.test(rbind(c(762, 327, 468), c(484, 239, 477)))
  (let ((h (chisq-test '((762 327 468) (484 239 477)))))
    (test-approximate 30.07015 (ref h 'statistic) 1e-5)
    (test-equal 2 (ref h 'parameter))
    (test-approximate 2.953589e-07 (ref h 'p-value) 1e-12)
    (test-approximate 703.6714 (car (car (ref h 'expected))) 1e-4))
  ;; goodness of fit
  (let ((h (chisq-test '(89 37 30 28 2) 'p '(0.40 0.20 0.20 0.19 0.01))))
    (test-approximate 5.794709 (ref h 'statistic) 1e-6)
    (test-equal 4 (ref h 'parameter))
    (test-approximate 0.2150 (ref h 'p-value) 1e-4))
  ;; 2x2 with Yates: chisq.test(matrix(c(12, 5, 7, 7), 2)) -> rows (12 7) (5 7)
  ;; E = 10.4194 8.5806 / 6.5806 5.4194, |O-E| = 1.5806, X2 = 1.0806^2 * sum(1/E)
  (let ((h (chisq-test '((12 7) (5 7)))))
    (test-approximate (* 1.0806451612903225 1.0806451612903225
                         (+ (/ 1 (/ (* 19 17) 31.0)) (/ 1 (/ (* 19 14) 31.0))
                            (/ 1 (/ (* 12 17) 31.0)) (/ 1 (/ (* 12 14) 31.0))))
                      (ref h 'statistic) 1e-9)))

(test-group "fisher, binomial, proportions"
  ;; fisher.test(TeaTasting)
  (let ((h (fisher-test '((3 1) (1 3)))))
    (test-approximate 0.4857143 (ref h 'p-value) 1e-7)
    (test-approximate 6.408309 (ref h 'estimate) 1e-4)
    (test-approximate 0.2117329 (car (ref h 'conf-int)) 1e-5)   ; R's uniroot tolerance
    ;; R: 621.9337 (uniroot's default tolerance); the exact root is 626.24
    (test-approximate 626.2 (cadr (ref h 'conf-int)) 0.5))
  (let ((h (fisher-test '((3 1) (1 3)) 'alternative 'greater)))
    (test-approximate 0.2428571 (ref h 'p-value) 1e-7)
    (test-approximate 0.3135693 (car (ref h 'conf-int)) 1e-5))
  ;; binom.test(682, 925, p = 0.75)
  (let ((h (binom-test 682 925 'p 0.75)))
    (test-approximate 0.3824916 (ref h 'p-value) 1e-6)
    (test-approximate 0.7076683 (car (ref h 'conf-int)) 1e-6)
    (test-approximate 0.7654066 (cadr (ref h 'conf-int)) 1e-6)
    (test-approximate 0.7372973 (ref h 'estimate) 1e-6))
  ;; prop.test(smokers, patients)
  (let ((h (prop-test '(83 90 129 70) '(86 93 136 82))))
    (test-approximate 12.6 (ref h 'statistic) 1e-2)
    (test-equal 3 (ref h 'parameter))
    (test-approximate 0.005585 (ref h 'p-value) 1e-6))
  ;; one sample with continuity correction: (|682 - 693.75| - 0.5)^2 / 173.4375
  (test-approximate 0.7297297 (ref (prop-test 682 925 'p 0.75) 'statistic) 1e-6))

(define cx '(44.4 45.9 41.9 53.3 44.7 44.1 50.7 45.2 60.1))
(define cy '(2.6 3.1 2.5 5.0 3.6 4.0 5.2 2.8 3.8))

(test-group "correlation"
  (let ((h (cor-test cx cy)))
    (test-approximate 1.841083 (ref h 'statistic) 1e-6)
    (test-equal 7 (ref h 'parameter))
    (test-approximate 0.1081731 (ref h 'p-value) 1e-6)
    (test-approximate 0.5711816 (ref h 'estimate) 1e-7)
    (test-approximate -0.1497426 (car (ref h 'conf-int)) 1e-6)
    (test-approximate 0.8955795 (cadr (ref h 'conf-int)) 1e-6))
  (let ((h (cor-test cx cy 'method 'kendall)))
    (test-equal 26 (ref h 'statistic))
    (test-approximate 0.4444444 (ref h 'estimate) 1e-7)
    (test-approximate 0.1194389 (ref h 'p-value) 1e-6))
  (let ((h (cor-test cx cy 'method 'spearman)))
    (test-approximate 48.0 (ref h 'statistic) 1e-9)
    (test-approximate 0.6 (ref h 'estimate) 1e-12)))

(define mpg '(21.0 21.0 22.8 21.4 18.7 18.1 14.3 24.4 22.8 19.2 17.8 16.4 17.3 15.2 10.4 10.4
              14.7 32.4 30.4 33.9 21.5 15.5 15.2 13.3 19.2 27.3 26.0 30.4 15.8 19.7 15.0 21.4))
(define wt '(2.620 2.875 2.320 3.215 3.440 3.460 3.570 3.190 3.150 3.440 3.440 4.070 3.730 3.780
             5.250 5.424 5.345 2.200 1.615 1.835 2.465 3.520 3.435 3.840 3.845 1.935 2.140 1.513
             3.170 2.770 3.570 2.780))
(define hp '(110 110 93 110 175 105 245 62 95 123 123 180 180 180 205 215 230 66 52 65 97 150 150
             245 175 66 91 113 264 175 335 109))
(define mtcars (make-df (list (cons 'mpg (list->vector mpg)) (cons 'wt (list->vector wt))
                              (cons 'hp (list->vector hp)))))

(test-group "normality, KS, k groups"
  ;; shapiro.test(mtcars$mpg)
  (let ((h (shapiro-test mpg)))
    (test-approximate 0.94756 (ref h 'statistic) 1e-5)
    (test-approximate 0.1229 (ref h 'p-value) 1e-4))
  ;; two-sample exact: 2 / choose(6, 3)
  (let ((h (ks-test '(1 2 3) '(4 5 6))))
    (test-equal 1.0 (ref h 'statistic))
    (test-approximate 0.1 (ref h 'p-value) 1e-12))
  ;; one sample, n = 1: P(D >= d) = 1 - (2d - 1) for d >= 1/2
  (let ((h (ks-test '(0.0) (lambda (q) (pnorm q)))))
    (test-approximate 0.5 (ref h 'statistic) 1e-12)
    (test-approximate 1.0 (ref h 'p-value) 1e-12))
  (let ((h (ks-test '(0.9) (lambda (q) q))))
    (test-approximate 0.9 (ref h 'statistic) 1e-12)
    (test-approximate 0.2 (ref h 'p-value) 1e-9))
  ;; kruskal.test example of R's documentation (Hollander & Wolfe)
  (let ((h (kruskal-test '((2.9 3.0 2.5 2.6 3.2) (3.8 2.7 4.0 2.4) (2.8 3.4 3.7 2.2 2.0)))))
    (test-approximate 0.7714286 (ref h 'statistic) 1e-6)
    (test-equal 2 (ref h 'parameter))
    (test-approximate 0.68 (ref h 'p-value) 1e-3))
  ;; Welch F with two groups is the Welch t squared
  (let ((h (oneway-test sleep '(extra ~ group)))
        (t (t-test sleep '(extra ~ group))))
    (test-approximate (* (ref t 'statistic) (ref t 'statistic)) (ref h 'statistic) 1e-9)
    (test-approximate (ref t 'p-value) (ref h 'p-value) 1e-9))
  ;; equal variances: F = t^2 of the pooled test
  (let ((h (oneway-test (list g1 g2) 'var-equal #t)))
    (test-approximate 0.07918671 (ref h 'p-value) 1e-7)))

(test-group "p-adjust"
  (define ps '(0.01 0.02 0.03 0.04 0.05))
  (test-equal '(0.05 0.1 0.15 0.2 0.25) (map (lambda (x) (/ (round (* x 1000)) 1000)) (p-adjust ps 'bonferroni)))
  (test-equal '(0.05 0.08 0.09 0.09 0.09) (map (lambda (x) (/ (round (* x 1000)) 1000)) (p-adjust ps 'holm)))
  (test-equal '(0.05 0.05 0.05 0.05 0.05) (map (lambda (x) (/ (round (* x 1000)) 1000)) (p-adjust ps 'BH)))
  (test-equal '(0.05 0.05 0.05 0.05 0.05) (map (lambda (x) (/ (round (* x 1000)) 1000)) (p-adjust ps 'hochberg)))
  (test-approximate 0.1141667 (car (p-adjust ps 'BY)) 1e-6)
  (test-assert (na? (cadr (p-adjust (list 0.01 na 0.02) 'holm)))))

(test-group "lm"
  ;; lm(mpg ~ wt, mtcars)
  (let* ((fit (lm mtcars '(mpg ~ wt)))
         (s (lm-summary fit))
         (co (cdr (assq 'coefficients s))))
    (test-approximate 37.285126 (cdr (assoc "(Intercept)" (lm-coefficients fit))) 1e-5)
    (test-approximate -5.344472 (cdr (assoc "wt" (lm-coefficients fit))) 1e-5)
    (test-approximate 1.877627 (df-ref co 0 'std-error) 1e-5)
    (test-approximate 0.559101 (df-ref co 1 'std-error) 1e-5)
    (test-approximate -9.559044 (df-ref co 1 'statistic) 1e-5)
    (test-approximate 0.7528328 (cdr (assq 'r-squared s)) 1e-7)
    (test-approximate 0.7445939 (cdr (assq 'adj-r-squared s)) 1e-7)
    (test-approximate 3.045882 (cdr (assq 'sigma s)) 1e-6)
    (test-approximate 91.37533 (cdr (assq 'f-statistic s)) 1e-4))
  ;; lm(mpg ~ wt + hp, mtcars)
  (let* ((fit (lm mtcars '(mpg ~ wt + hp)))
         (s (lm-summary fit)))
    (test-approximate 37.22727 (cdr (assoc "(Intercept)" (lm-coefficients fit))) 1e-5)
    (test-approximate -3.87783 (cdr (assoc "wt" (lm-coefficients fit))) 1e-5)
    (test-approximate -0.03177295 (cdr (assoc "hp" (lm-coefficients fit))) 1e-7)
    (test-approximate 0.8267855 (cdr (assq 'r-squared s)) 1e-7)
    (test-approximate (+ 37.22727 (* -3.87783 3.0) (* -0.03177295 120))
                      (vector-ref (predict fit (make-df '((wt . #(3.0)) (hp . #(120))))) 0) 1e-4)
    (test-assert (string? (lm->string fit))))
  ;; a factor: two groups -> the slope is the difference of the means
  (let ((fit (lm sleep '(extra ~ group))))
    (test-equal '("(Intercept)" "group2") (map car (lm-coefficients fit)))
    (test-approximate 0.75 (cdar (lm-coefficients fit)) 1e-12)
    (test-approximate 1.58 (cdadr (lm-coefficients fit)) 1e-12)))

(test-end "scm-data-tests")

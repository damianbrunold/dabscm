(define-library (scm data tests)
  (import (scheme base)
          (scheme inexact)
          (scheme write)
          (srfi 1)
          (srfi 132)
          (scm data core)
          (scm data frame)
          (scm data expr))
  (export lgamma
          lbeta
          lchoose
          pgamma-regularized
          pbeta-regularized
          dnorm pnorm qnorm
          dt pt qt
          dchisq pchisq qchisq
          dF pf qf
          dbeta pbeta qbeta
          dbinom pbinom qbinom
          dpois ppois
          htest?
          htest-method
          htest-data-name
          htest-statistic
          htest-parameter
          htest-p-value
          htest-conf-int
          htest-conf-level
          htest-estimate
          htest-null-value
          htest-alternative
          htest-extra
          htest-ref
          htest->string
          htest-print
          tidy
          t-test
          wilcox-test
          chisq-test
          fisher-test
          binom-test
          prop-test
          cor-test
          shapiro-test
          ks-test
          oneway-test
          kruskal-test
          p-adjust
          lm
          lm?
          lm-coefficients
          lm-residuals
          lm-fitted
          lm-summary
          lm->string
          lm-print
          predict)
  (begin

    ;; ================================================================
    ;; (scm data tests) — probability distributions and hypothesis
    ;; tests, following R's stats package: the same names (pnorm, qt …),
    ;; the same defaults and the same p-values and confidence intervals
    ;; as R, within floating point. Tests take lists or vectors, or a
    ;; frame and a formula such as '(extra ~ group); options come as
    ;; 'key value pairs ('alternative 'less, 'conf-level 0.9 …). They
    ;; return an htest record that prints like R's (htest-print) and
    ;; turns into a one-row frame like broom's (tidy). lm fits linear
    ;; models by QR decomposition.
    ;; ================================================================

    (define eps 1e-15)
    (define fpmin 1e-300)
    (define pi (* 4 (atan 1)))
    (define +inf +inf.0)
    (define -inf -inf.0)

    (define (opt opts key dflt)
      (let loop ((o opts))
        (cond ((or (null? o) (null? (cdr o))) dflt)
              ((eq? (car o) key) (cadr o))
              (else (loop (cddr o))))))

    (define (sq x) (* x x))

    (define (->list xs) (if (vector? xs) (vector->list xs) xs))

    (define (numbers xs)
      (map inexact (filter (lambda (x) (not (na? x))) (->list xs))))

    (define (lsum l) (fold + 0 l))

    (define (lmean l) (/ (lsum l) (length l)))

    (define (lvar l)
      (let ((m (lmean l)))
        (/ (lsum (map (lambda (x) (sq (- x m))) l)) (- (length l) 1))))

    (define (clamp01 p) (max 0.0 (min 1.0 p)))

    ;; --- special functions -------------------------------------------

    (define lanczos
      '(0.99999999999980993 676.5203681218851 -1259.1392167224028
        771.32342877765313 -176.61502916214059 12.507343278686905
        -0.13857109526572012 9.9843695780195716e-6 1.5056327351493116e-7))

    (define (lgamma x)
      "Syntax: (lgamma x)
Library: (scm data tests)
Description: The natural logarithm of the absolute value of the gamma
  function (Lanczos approximation, about 15 digits).
Example:
  (lgamma 5) => 3.1780538303479458 ; log(24)"
      (let ((x (inexact x)))
        (if (< x 0.5)
            (- (log (/ pi (abs (sin (* pi x))))) (lgamma (- 1 x)))
            (let* ((x (- x 1))
                   (t (+ x 7.5))
                   (a (let loop ((cs (cdr lanczos)) (i 1) (a (car lanczos)))
                        (if (null? cs) a (loop (cdr cs) (+ i 1) (+ a (/ (car cs) (+ x i))))))))
              (+ (* 0.5 (log (* 2 pi))) (* (+ x 0.5) (log t)) (- t) (log a))))))

    (define (lbeta a b)
      "Syntax: (lbeta a b)
Library: (scm data tests)
Description: The natural logarithm of the beta function B(a, b).
Example:
  (lbeta 2 3) => -2.4849066497880004 ; log(1/12)"
      (- (+ (lgamma a) (lgamma b)) (lgamma (+ a b))))

    (define (lchoose n k)
      "Syntax: (lchoose n k)
Library: (scm data tests)
Description: The natural logarithm of the binomial coefficient n over k.
Example:
  (exp (lchoose 5 2)) => 10.000000000000002"
      (- (lgamma (+ n 1)) (lgamma (+ k 1)) (lgamma (+ (- n k) 1))))

    ;; regularized lower incomplete gamma P(a, x) by its series
    (define (gamma-series a x)
      (let loop ((ap a) (del (/ 1.0 a)) (sum (/ 1.0 a)) (i 0))
        (if (or (< (abs del) (* (abs sum) eps)) (> i 10000))
            (* sum (exp (- (* a (log x)) x (lgamma a))))
            (let* ((ap (+ ap 1)) (del (* del (/ x ap))))
              (loop ap del (+ sum del) (+ i 1))))))

    ;; regularized upper incomplete gamma Q(a, x) by its continued fraction
    (define (gamma-cf a x)
      (let ((b (+ x 1.0 (- a))))
        (let loop ((i 1) (b b) (c (/ 1.0 fpmin)) (d (/ 1.0 b)) (h (/ 1.0 b)))
          (let* ((an (* (- i) (- i a)))
                 (b (+ b 2.0))
                 (d (let ((d (+ (* an d) b))) (if (< (abs d) fpmin) fpmin d)))
                 (c (let ((c (+ b (/ an c)))) (if (< (abs c) fpmin) fpmin c)))
                 (d (/ 1.0 d))
                 (del (* d c))
                 (h (* h del)))
            (if (or (< (abs (- del 1.0)) eps) (> i 10000))
                (* (exp (- (* a (log x)) x (lgamma a))) h)
                (loop (+ i 1) b c d h))))))

    (define (pgamma-regularized a x . upper)
      "Syntax: (pgamma-regularized a x [upper?])
Library: (scm data tests)
Description: The regularized incomplete gamma function P(a, x), or
  Q(a, x) = 1 - P(a, x) with upper? #t, each computed directly so that
  small tail values keep their precision.
Example:
  (pgamma-regularized 1 1) => 0.6321205588285577"
      (let ((upper? (and (pair? upper) (car upper)))
            (a (inexact a)) (x (inexact x)))
        (cond ((<= x 0) (if upper? 1.0 0.0))
              ((= x +inf) (if upper? 0.0 1.0))
              ((< x (+ a 1))
               (let ((p (gamma-series a x))) (if upper? (- 1.0 p) p)))
              (else
               (let ((q (gamma-cf a x))) (if upper? q (- 1.0 q)))))))

    (define (beta-cf a b x)
      (let* ((qab (+ a b)) (qap (+ a 1)) (qam (- a 1))
             (guard (lambda (v) (if (< (abs v) fpmin) fpmin v)))
             (d0 (/ 1.0 (guard (- 1.0 (/ (* qab x) qap))))))
        (let loop ((m 1) (c 1.0) (d d0) (h d0))
          (let* ((m2 (* 2 m))
                 (aa (/ (* m (- b m) x) (* (+ qam m2) (+ a m2))))
                 (d (/ 1.0 (guard (+ 1.0 (* aa d)))))
                 (c (guard (+ 1.0 (/ aa c))))
                 (h (* h d c))
                 (aa (/ (* (- (+ a m)) (+ qab m) x) (* (+ a m2) (+ qap m2))))
                 (d (/ 1.0 (guard (+ 1.0 (* aa d)))))
                 (c (guard (+ 1.0 (/ aa c))))
                 (del (* d c))
                 (h (* h del)))
            (if (or (< (abs (- del 1.0)) eps) (> m 10000))
                h
                (loop (+ m 1) c d h))))))

    ;; I_x(a, b), computed directly on the side where the continued
    ;; fraction converges and by 1 - I_{1-x}(b, a) on the other
    (define (ibeta x a b)
      (cond ((<= x 0) 0.0)
            ((>= x 1) 1.0)
            (else
             (let ((bt (exp (- (+ (* a (log x)) (* b (log (- 1.0 x)))) (lbeta a b)))))
               (if (< x (/ (+ a 1) (+ a b 2)))
                   (/ (* bt (beta-cf a b x)) a)
                   (- 1.0 (/ (* bt (beta-cf b a (- 1.0 x))) b)))))))

    (define (pbeta-regularized x a b . upper)
      "Syntax: (pbeta-regularized x a b [upper?])
Library: (scm data tests)
Description: The regularized incomplete beta function I_x(a, b), or
  1 - I_x(a, b) with upper? #t (computed as I_{1-x}(b, a)).
Example:
  (pbeta-regularized 0.5 2 2) => 0.5"
      (let ((x (inexact x)) (a (inexact a)) (b (inexact b)))
        (if (and (pair? upper) (car upper))
            (ibeta (- 1.0 x) b a)
            (ibeta x a b))))

    ;; lower tail unless the option list says otherwise
    (define (lower? rest) (or (null? rest) (car rest)))

    ;; inverts an increasing cdf on (lo, hi), widening the bracket as needed
    (define (invert cdf p lo hi . bounds)
      (let* ((min-lo (if (pair? bounds) (car bounds) -inf))
             (max-hi (if (and (pair? bounds) (pair? (cdr bounds))) (cadr bounds) +inf)))
        (let widen ((lo lo) (hi hi) (i 0))
          (cond ((and (> (cdf lo) p) (> lo min-lo) (< i 200))
                 (widen (if (> min-lo -inf)
                            (+ min-lo (/ (- lo min-lo) 2))
                            (- lo (* 2 (max 1 (abs lo)))))
                        lo (+ i 1)))
                ((and (< (cdf hi) p) (< hi max-hi) (< i 200))
                 (widen hi (if (< max-hi +inf)
                               (- max-hi (/ (- max-hi hi) 2))
                               (+ hi (* 2 (max 1 (abs hi)))))
                        (+ i 1)))
                (else
                 (let loop ((lo lo) (hi hi) (i 0))
                   (let ((mid (/ (+ lo hi) 2)))
                     (if (or (> i 200) (<= (- hi lo) (* 1e-15 (max 1.0 (abs mid)))))
                         mid
                         (if (< (cdf mid) p)
                             (loop mid hi (+ i 1))
                             (loop lo mid (+ i 1)))))))))))

    (define (tail-p p rest)
      ;; quantile functions take an upper-tail p with lower? #f
      (if (lower? rest) p (- 1.0 p)))

    ;; --- normal ----------------------------------------------------------

    (define (dnorm x . ms)
      "Syntax: (dnorm x [mean sd])
Library: (scm data tests)
Description: The normal density.
Example:
  (dnorm 0) => 0.3989422804014327"
      (let* ((m (if (pair? ms) (car ms) 0)) (s (if (and (pair? ms) (pair? (cdr ms))) (cadr ms) 1))
             (z (/ (- x m) s)))
        (/ (exp (* -0.5 z z)) (* s (sqrt (* 2 pi))))))

    (define (erfc-pos x)
      (pgamma-regularized 0.5 (* x x) #t))

    (define (pnorm x . rest)
      "Syntax: (pnorm q [mean sd [lower?]])
Library: (scm data tests)
Description: The normal distribution function P(X <= q); with lower? #f
  the upper tail P(X > q).
Example:
  (pnorm 1.96) => 0.9750021048517795"
      (let* ((m (if (pair? rest) (car rest) 0))
             (s (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) 1))
             (low (if (and (pair? rest) (pair? (cdr rest)) (pair? (cddr rest))) (caddr rest) #t))
             (z (/ (- x m) s))
             (z (if low z (- z))))
        (cond ((= z +inf) 1.0)
              ((= z -inf) 0.0)
              ((< z 0) (* 0.5 (erfc-pos (/ (- z) (sqrt 2.0)))))
              (else (- 1.0 (* 0.5 (erfc-pos (/ z (sqrt 2.0)))))))))

    (define (poly x cs)
      (fold-right (lambda (c acc) (+ c (* x acc))) 0.0 cs))

    ;; Wichura's AS241 (PPND16)
    (define (qnorm-std p)
      (let ((q (- p 0.5)))
        (cond
         ((<= p 0) -inf)
         ((>= p 1) +inf)
         ((<= (abs q) 0.425)
          (let ((r (- 0.180625 (* q q))))
            (/ (* q (poly r '(3.387132872796366608 133.14166789178437745 1971.5909503065514427
                              13731.693765509461125 45921.953931549871457 67265.770927008700853
                              33430.575583588128105 2509.0809287301226727)))
               (poly r '(1.0 42.313330701600911252 687.1870074920579083 5394.1960214247511077
                         21213.794301586595867 39307.89580009271061 28729.085735721942674
                         5226.495278852545925)))))
         (else
          (let* ((r (if (< q 0) p (- 1 p)))
                 (r (sqrt (- (log r))))
                 (val (if (<= r 5)
                          (let ((r (- r 1.6)))
                            (/ (poly r '(1.42343711074968357734 4.6303378461565452959 5.7694972214606914055
                                         3.64784832476320460504 1.27045825245236838258 0.24178072517745061177
                                         0.0227238449892691845833 7.7454501427834140764e-4))
                               (poly r '(1.0 2.05319162663775882187 1.6763848301838038494
                                         0.68976733498510000455 0.14810397642748007459
                                         0.0151986665636164571966 5.475938084995344946e-4
                                         1.05075007164441684324e-9))))
                          (let ((r (- r 5)))
                            (/ (poly r '(6.6579046435011037772 5.4637849111641143699 1.7848265399172913358
                                         0.29656057182850489123 0.026532189526576123093
                                         0.0012426609473880784386 2.71155556874348757815e-5
                                         2.01033439929228813265e-7))
                               (poly r '(1.0 0.59983220655588793769 0.13692988092273580531
                                         0.0148753612908506148525 7.868691311456132591e-4
                                         1.8463183175100546818e-5 1.4215117583164458887e-7
                                         2.04426310338993978564e-15)))))))
            (if (< q 0) (- val) val))))))

    (define (qnorm p . rest)
      "Syntax: (qnorm p [mean sd [lower?]])
Library: (scm data tests)
Description: The normal quantile function (Wichura's AS241).
Example:
  (qnorm 0.975) => 1.959963984540054"
      (let* ((m (if (pair? rest) (car rest) 0))
             (s (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) 1))
             (low (if (and (pair? rest) (pair? (cdr rest)) (pair? (cddr rest))) (caddr rest) #t)))
        (+ m (* s (qnorm-std (if low (inexact p) (- 1.0 p)))))))

    ;; --- t, chi-squared, F, beta -----------------------------------------

    (define (dt x n)
      "Syntax: (dt x df)
Library: (scm data tests)
Description: The density of Student's t distribution.
Example:
  (dt 0 10) => 0.389108383966031"
      (exp (- (+ (lgamma (/ (+ n 1) 2)) (* (- (/ (+ n 1) 2)) (log (+ 1 (/ (* x x) n)))))
              (lgamma (/ n 2)) (* 0.5 (log (* n pi))))))

    (define (pt x n . rest)
      "Syntax: (pt q df [lower?])
Library: (scm data tests)
Description: The distribution function of Student's t distribution.
Example:
  (pt 2.228139 10) => 0.975"
      (let* ((x (inexact x)) (n (inexact n))
             (x (if (lower? rest) x (- x))))
        (cond ((= x +inf) 1.0)
              ((= x -inf) 0.0)
              (else
               ;; P(T > |x|) = I_{n/(n+x^2)}(n/2, 1/2) / 2
               (let ((tail (* 0.5 (ibeta (/ n (+ n (* x x))) (/ n 2) 0.5))))
                 (if (> x 0) (- 1.0 tail) tail))))))

    (define (qt p n . rest)
      "Syntax: (qt p df [lower?])
Library: (scm data tests)
Description: The quantile function of Student's t distribution.
Example:
  (qt 0.975 10) => 2.2281388519649385"
      (let ((p (tail-p (inexact p) rest)))
        (cond ((<= p 0) -inf)
              ((>= p 1) +inf)
              ((< p 0.5) (- (invert (lambda (x) (pt x n #f)) p 0.0 2.0 0.0)))
              (else (invert (lambda (x) (pt x n)) p 0.0 2.0 0.0)))))

    (define (dchisq x k)
      "Syntax: (dchisq x df)
Library: (scm data tests)
Description: The density of the chi-squared distribution.
Example:
  (dchisq 1 2) => 0.30326532985631671"
      (if (<= x 0)
          0.0
          (exp (- (+ (* (- (/ k 2) 1) (log x)) (/ x -2)) (* (/ k 2) (log 2)) (lgamma (/ k 2))))))

    (define (pchisq x k . rest)
      "Syntax: (pchisq q df [lower?])
Library: (scm data tests)
Description: The distribution function of the chi-squared distribution;
  (pchisq q df #f) is the p-value of a chi-squared statistic.
Example:
  (pchisq 3.841459 1 #f) => 0.05"
      (pgamma-regularized (/ k 2) (/ x 2) (not (lower? rest))))

    (define (qchisq p k . rest)
      "Syntax: (qchisq p df [lower?])
Library: (scm data tests)
Description: The quantile function of the chi-squared distribution.
Example:
  (qchisq 0.95 1) => 3.841458820694124"
      (let ((p (tail-p (inexact p) rest)))
        (cond ((<= p 0) 0.0)
              ((>= p 1) +inf)
              (else (invert (lambda (x) (pchisq x k)) p 0.0 (max 1.0 (* 2 k)) 0.0)))))

    (define (dF x d1 d2)
      "Syntax: (dF x df1 df2)
Library: (scm data tests)
Description: The density of the F distribution (dF, not df as in R, so
  that it does not take the usual name of a data frame).
Example:
  (dF 1 5 10) => 0.4954798"
      (if (<= x 0)
          0.0
          (exp (- (+ (* (/ d1 2) (log (/ d1 d2))) (* (- (/ d1 2) 1) (log x))
                     (* (- (/ (+ d1 d2) 2)) (log (+ 1 (/ (* d1 x) d2)))))
                  (lbeta (/ d1 2) (/ d2 2))))))

    (define (pf x d1 d2 . rest)
      "Syntax: (pf q df1 df2 [lower?])
Library: (scm data tests)
Description: The distribution function of the F distribution.
Example:
  (pf 4.964603 1 10 #f) => 0.05"
      (cond ((<= x 0) (if (lower? rest) 0.0 1.0))
            ((= x +inf) (if (lower? rest) 1.0 0.0))
            (else
             (let ((z (/ (* d1 x) (+ (* d1 x) d2))))
               (pbeta-regularized z (/ d1 2) (/ d2 2) (not (lower? rest)))))))

    (define (qf p d1 d2 . rest)
      "Syntax: (qf p df1 df2 [lower?])
Library: (scm data tests)
Description: The quantile function of the F distribution.
Example:
  (qf 0.95 1 10) => 4.9646027437307"
      (let ((p (tail-p (inexact p) rest)))
        (cond ((<= p 0) 0.0)
              ((>= p 1) +inf)
              (else (invert (lambda (x) (pf x d1 d2)) p 0.0 2.0 0.0)))))

    (define (dbeta x a b)
      "Syntax: (dbeta x a b)
Library: (scm data tests)
Description: The density of the beta distribution.
Example:
  (dbeta 0.5 2 2) => 1.5"
      (if (or (< x 0) (> x 1))
          0.0
          (exp (- (+ (* (- a 1) (log x)) (* (- b 1) (log (- 1 x)))) (lbeta a b)))))

    (define (pbeta x a b . rest)
      "Syntax: (pbeta q a b [lower?])
Library: (scm data tests)
Description: The distribution function of the beta distribution.
Example:
  (pbeta 0.5 2 3) => 0.6875"
      (pbeta-regularized (max 0 (min 1 x)) a b (not (lower? rest))))

    (define (qbeta p a b . rest)
      "Syntax: (qbeta p a b [lower?])
Library: (scm data tests)
Description: The quantile function of the beta distribution.
Example:
  (qbeta 0.5 2 2) => 0.5"
      (let ((p (tail-p (inexact p) rest)))
        (cond ((<= p 0) 0.0)
              ((>= p 1) 1.0)
              (else (invert (lambda (x) (pbeta x a b)) p 0.0 1.0 0.0 1.0)))))

    ;; --- binomial, Poisson --------------------------------------------------

    (define (dbinom k n p)
      "Syntax: (dbinom k n p)
Library: (scm data tests)
Description: The binomial probability P(X = k) for n trials with success
  probability p.
Example:
  (dbinom 2 4 0.5) => 0.375"
      (cond ((or (< k 0) (> k n) (not (integer? k))) 0.0)
            ((= p 0) (if (= k 0) 1.0 0.0))
            ((= p 1) (if (= k n) 1.0 0.0))
            (else (exp (+ (lchoose n k) (* k (log p)) (* (- n k) (log (- 1 p))))))))

    (define (pbinom k n p . rest)
      "Syntax: (pbinom q n p [lower?])
Library: (scm data tests)
Description: The binomial distribution function P(X <= q); with lower?
  #f P(X > q).
Example:
  (pbinom 2 4 0.5) => 0.6875"
      (let* ((k (floor k))
             (lo (cond ((< k 0) 0.0)
                       ((>= k n) 1.0)
                       (else #f))))
        (cond (lo (if (lower? rest) lo (- 1.0 lo)))
              ((lower? rest) (ibeta (- 1.0 p) (- n k) (+ k 1)))
              (else (ibeta (inexact p) (+ k 1) (- n k))))))

    (define (qbinom p n prob . rest)
      "Syntax: (qbinom p n prob [lower?])
Library: (scm data tests)
Description: The smallest k with P(X <= k) >= p.
Example:
  (qbinom 0.5 10 0.5) => 5"
      (let ((p (tail-p (inexact p) rest)))
        (let loop ((k 0))
          (if (or (>= k n) (>= (pbinom k n prob) (* p (- 1 (* 64 eps))))) k (loop (+ k 1))))))

    (define (dpois k lam)
      "Syntax: (dpois k lambda)
Library: (scm data tests)
Description: The Poisson probability P(X = k).
Example:
  (dpois 0 1) => 0.36787944117144233"
      (if (or (< k 0) (not (integer? k)))
          0.0
          (exp (- (* k (log lam)) lam (lgamma (+ k 1))))))

    (define (ppois k lam . rest)
      "Syntax: (ppois q lambda [lower?])
Library: (scm data tests)
Description: The Poisson distribution function P(X <= q).
Example:
  (ppois 2 1) => 0.9196986029286058"
      (let ((k (floor k)))
        (if (< k 0)
            (if (lower? rest) 0.0 1.0)
            (pgamma-regularized (+ k 1) lam (lower? rest)))))

    ;; --- formatting (R's significant-digit style) ----------------------------

    (define (digits->string r d)
      ;; r an exact integer holding the value times 10^d
      (let* ((neg (< r 0))
             (s (number->string (abs r)))
             (s (if (<= (string-length s) d)
                    (string-append (make-string (+ 1 (- d (string-length s))) #\0) s)
                    s))
             (int (substring s 0 (- (string-length s) d)))
             (frac (substring s (- (string-length s) d) (string-length s)))
             (frac (let loop ((f frac))
                     (if (and (> (string-length f) 0)
                              (char=? (string-ref f (- (string-length f) 1)) #\0))
                         (loop (substring f 0 (- (string-length f) 1)))
                         f))))
        (string-append (if neg "-" "") int (if (string=? frac "") "" ".") frac)))

    (define (signif x k)
      (cond ((na? x) "NA")
            ((not (real? x)) (let ((p (open-output-string))) (display x p) (get-output-string p)))
            ((= x +inf) "Inf")
            ((= x -inf) "-Inf")
            ((not (= x x)) "NaN")
            ((zero? x) "0")
            (else
             (let* ((ax (abs (exact x)))
                    (e (let ((e (exact (floor (/ (log (inexact ax)) (log 10))))))
                         (cond ((>= ax (expt 10 (+ e 1))) (+ e 1))
                               ((< ax (expt 10 e)) (- e 1))
                               (else e))))
                    (r (round (* (exact x) (expt 10 (- (- k 1) e))))))
               ;; rounding can carry into the next power of ten
               (let-values (((r e) (if (>= (abs r) (expt 10 k)) (values (round (/ r 10)) (+ e 1)) (values r e))))
                 (if (or (< e -4) (>= e 15))
                     (string-append (digits->string r (- k 1))
                                    (if (< e 0) "e-" "e+")
                                    (let ((s (number->string (abs e))))
                                      (if (< (string-length s) 2) (string-append "0" s) s)))
                     (let ((d (- (- k 1) e)))
                       (if (>= d 0)
                           (digits->string r d)
                           (number->string (* r (expt 10 (- d))))))))))))

    (define (fmt-pval p)
      (if (and (real? p) (< p 2.220446e-16)) "< 2.2e-16" (string-append "= " (signif p 4))))

    ;; --- htest ---------------------------------------------------------------

    (define-record-type <htest>
      (make-htest method data-name statistic parameter p-value conf-int conf-level
                  estimate null-value alternative extra)
      htest?
      (method htest-method)
      (data-name htest-data-name)
      (statistic htest-statistic)       ; ((name . value)) or ()
      (parameter htest-parameter)       ; ((name . value) …)
      (p-value htest-p-value)
      (conf-int htest-conf-int)         ; (lo hi) or #f
      (conf-level htest-conf-level)
      (estimate htest-estimate)         ; ((name . value) …)
      (null-value htest-null-value)     ; ((name . value)) or ()
      (alternative htest-alternative)   ; two-sided less greater
      (extra htest-extra))              ; alist of further results

    (define (htest-ref h key)
      "Syntax: (htest-ref htest key)
Library: (scm data tests)
Description: One value of a test result: statistic, parameter (a list
  when there are several), p-value, conf-int, conf-level, estimate (a
  list when there are several), null-value, alternative, method, or a
  key of the extra results (e.g. expected for chisq-test).
Example:
  (htest-ref (t-test '(1 2 3 4)) 'p-value)"
      (define (vals al) (if (and (pair? al) (null? (cdr al))) (cdar al) (map cdr al)))
      (case key
        ((statistic) (vals (htest-statistic h)))
        ((parameter df) (vals (htest-parameter h)))
        ((p-value) (htest-p-value h))
        ((conf-int) (htest-conf-int h))
        ((conf-level) (htest-conf-level h))
        ((estimate) (vals (htest-estimate h)))
        ((null-value) (vals (htest-null-value h)))
        ((alternative) (htest-alternative h))
        ((method) (htest-method h))
        ((data-name) (htest-data-name h))
        (else (let ((p (assq key (htest-extra h)))) (if p (cdr p) (error "htest-ref: no such value" key))))))

    (define (alt-phrase h)
      (let* ((nv (htest-null-value h))
             (what (if (pair? nv) (caar nv) #f))
             (v (if (pair? nv) (cdar nv) #f)))
        (if (not what)
            #f
            (string-append "alternative hypothesis: "
                           (if (> (length nv) 1) "" "true ")
                           what " is "
                           (case (htest-alternative h)
                             ((less) "less than ")
                             ((greater) "greater than ")
                             (else "not equal to "))
                           (signif v 7)))))

    (define (htest->string h)
      "Syntax: (htest->string htest)
Library: (scm data tests)
Description: The test result as text, in the layout of R's print.htest.
Example:
  (display (htest->string (t-test '(1 2 3 4))))"
      (let ((out (open-output-string)))
        (define (w . xs) (for-each (lambda (x) (display x out)) xs))
        (w "\n\t" (htest-method h) "\n\n")
        (w "data:  " (htest-data-name h) "\n")
        (let ((parts (append
                      (map (lambda (s) (string-append (car s) " = " (signif (cdr s) 5))) (htest-statistic h))
                      (map (lambda (s) (string-append (car s) " = " (signif (cdr s) 5))) (htest-parameter h))
                      (if (htest-p-value h) (list (string-append "p-value " (fmt-pval (htest-p-value h)))) '()))))
          (w (fold-right (lambda (s acc) (if (string=? acc "") s (string-append s ", " acc))) "" parts) "\n"))
        (let ((a (alt-phrase h))) (when a (w a "\n")))
        (when (htest-conf-int h)
          (w (signif (* 100 (htest-conf-level h)) 7) " percent confidence interval:\n "
             (signif (car (htest-conf-int h)) 7) " " (signif (cadr (htest-conf-int h)) 7) "\n"))
        (when (pair? (htest-estimate h))
          (w "sample estimates:\n")
          (let* ((names (map car (htest-estimate h)))
                 (vals (map (lambda (e) (signif (cdr e) 7)) (htest-estimate h)))
                 (widths (map (lambda (n v) (max (string-length n) (string-length v))) names vals))
                 (pad (lambda (s n) (string-append (make-string (- n (string-length s)) #\space) s))))
            (for-each (lambda (n wd) (w (pad n wd) " ")) names widths)
            (w "\n")
            (for-each (lambda (v wd) (w (pad v wd) " ")) vals widths)
            (w "\n")))
        (w "\n")
        (get-output-string out)))

    (define (htest-print h . port)
      "Syntax: (htest-print htest [port])
Library: (scm data tests)
Description: Writes the test result like R prints it.
Example:
  (htest-print (t-test '(1 2 3 4)))"
      (display (htest->string h) (if (pair? port) (car port) (current-output-port))))

    (define (tidy h)
      "Syntax: (tidy htest-or-lm)
Library: (scm data tests)
Description: A test result as a one-row frame in the style of broom's
  tidy: estimate (for two estimates their difference, then estimate1 and
  estimate2), statistic, p-value, parameter (df1/df2 for two), conf-low,
  conf-high, method and alternative; columns without a value are left
  out. For an lm fit, the coefficient table.
Example:
  (tidy (t-test '(1 2 3 4)))"
      (if (lm? h)
          (cdr (assq 'coefficients (lm-summary h)))
          (let* ((est (htest-estimate h))
                 (est-cols (cond ((null? est) '())
                                 ((null? (cdr est)) (list (cons 'estimate (vector (cdar est)))))
                                 ((and (= (length est) 2) (assq 'difference (htest-extra h)))
                                  (list (cons 'estimate (vector (cdr (assq 'difference (htest-extra h)))))
                                        (cons 'estimate1 (vector (cdar est)))
                                        (cons 'estimate2 (vector (cdadr est)))))
                                 (else (map (lambda (e i) (cons (string->symbol (string-append "estimate" (number->string i)))
                                                                (vector (cdr e))))
                                            est (iota (length est) 1)))))
                 (par (htest-parameter h))
                 (par-cols (cond ((null? par) '())
                                 ((null? (cdr par)) (list (cons 'parameter (vector (cdar par)))))
                                 (else (map (lambda (p i) (cons (string->symbol (string-append "parameter" (number->string i)))
                                                                (vector (cdr p))))
                                            par (iota (length par) 1))))))
            (make-df (append est-cols
                             (if (pair? (htest-statistic h)) (list (cons 'statistic (vector (cdar (htest-statistic h))))) '())
                             (list (cons 'p-value (vector (htest-p-value h))))
                             par-cols
                             (if (htest-conf-int h)
                                 (list (cons 'conf-low (vector (car (htest-conf-int h))))
                                       (cons 'conf-high (vector (cadr (htest-conf-int h)))))
                                 '())
                             (list (cons 'method (vector (htest-method h)))
                                   (cons 'alternative (vector (symbol->string (htest-alternative h))))))))))

    ;; --- argument handling -------------------------------------------------

    (define (formula? x) (and (list? x) (memq '~ x) #t))

    (define (formula-lhs f) (let loop ((f f) (acc '())) (if (eq? (car f) '~) (reverse acc) (loop (cdr f) (cons (car f) acc)))))
    (define (formula-rhs f) (cdr (memq '~ f)))

    (define (name-of x) (if (symbol? x) (symbol->string x) (let ((p (open-output-string))) (write x p) (get-output-string p))))

    ;; frame + (y ~ g) -> (values data-name levels samples), samples a list
    ;; of number lists in level order
    (define (split-by-formula d f)
      (let* ((lhs (formula-lhs f)) (rhs (formula-rhs f)))
        (unless (and (= (length lhs) 1) (= (length rhs) 1) (symbol? (car lhs)))
          (error "formula must be (y ~ g)" f))
        (let* ((y (df-column d (car lhs)))
               (g (df-column d (car rhs)))
               (keep (filter (lambda (i) (not (or (na? (vector-ref y i)) (na? (vector-ref g i)))))
                             (iota (vector-length y))))
               (levels (list-sort value<? (delete-duplicates (map (lambda (i) (vector-ref g i)) keep)))))
          (values (string-append (name-of (car lhs)) " by " (name-of (car rhs)))
                  levels
                  (map (lambda (l) (map (lambda (i) (inexact (vector-ref y i)))
                                        (filter (lambda (i) (equal? (vector-ref g i) l)) keep)))
                       levels)))))

    (define (level-name l) (if (string? l) l (name-of l)))

    (define (check-alt alt)
      (unless (memq alt '(two-sided less greater))
        (error "alternative must be two-sided, less or greater" alt))
      alt)

    ;; p-value of a statistic with a symmetric continuous null distribution
    (define (p-from-cdf cdf stat alt)
      (case alt
        ((less) (cdf stat #t))
        ((greater) (cdf stat #f))
        (else (min 1.0 (* 2 (min (cdf stat #t) (cdf stat #f)))))))

    ;; --- t test ----------------------------------------------------------

    (define (t-test x . args)
      "Syntax: (t-test x [y] option ...) or (t-test df '(y ~ g) option ...)
Library: (scm data tests)
Description: Student's t test, as R's t.test: one sample (x alone), two
  samples (Welch unless 'var-equal #t), or paired ('paired #t). With a
  frame and a formula (y ~ g), g must have two levels; (y ~ 1) is the
  one-sample test. Options: 'alternative two-sided|less|greater, 'mu 0,
  'paired #f, 'var-equal #f, 'conf-level 0.95. na values are dropped
  (pairwise when paired).
Example:
  (t-test '(0.7 -1.6 -0.2) '(1.9 0.8 1.1) 'var-equal #t)"
      (if (data-frame? x)
          (let ((f (car args)) (opts (cdr args)))
            (if (equal? (formula-rhs f) '(1))
                (t-test-impl (numbers (df-column x (car (formula-lhs f)))) #f opts
                             (name-of (car (formula-lhs f))) #f)
                (let-values (((dname levels samples) (split-by-formula x f)))
                  (unless (= (length levels) 2) (error "t-test: the grouping needs exactly 2 levels" levels))
                  (t-test-impl (car samples) (cadr samples) opts dname
                               (map level-name levels)))))
          (let-values (((y opts) (if (and (pair? args) (not (symbol? (car args))))
                                     (values (car args) (cdr args))
                                     (values #f args))))
            (if (and y (opt opts 'paired #f))
                (let* ((ps (filter (lambda (p) (not (or (na? (car p)) (na? (cdr p)))))
                                   (map cons (->list x) (->list y)))))
                  (t-test-impl (map (lambda (p) (inexact (car p))) ps)
                               (map (lambda (p) (inexact (cdr p))) ps) opts "x and y" #f))
                (t-test-impl (numbers x) (and y (numbers y)) opts (if y "x and y" "x") #f)))))

    (define (t-test-impl x y opts dname groups)
      (let* ((alt (check-alt (opt opts 'alternative 'two-sided)))
             (mu (opt opts 'mu 0))
             (paired (opt opts 'paired #f))
             (var-equal (opt opts 'var-equal #f))
             (conf (opt opts 'conf-level 0.95))
             (x (if (and y paired) (map - x y) x))
             (y (if paired #f y)))
        (let-values
            (((method stat df se est est-names diff)
              (cond
               ((not y)
                (let ((n (length x)))
                  (when (< n 2) (error "t-test: not enough observations"))
                  (values (if paired "Paired t-test" "One Sample t-test")
                          #f (- n 1) (sqrt (/ (lvar x) n)) (lmean x)
                          (list (if paired "mean difference" "mean of x")) #f)))
               (else
                (let* ((nx (length x)) (ny (length y))
                       (mx (lmean x)) (my (lmean y))
                       (vx (lvar x)) (vy (lvar y)))
                  (when (or (< nx 2) (< ny 2)) (error "t-test: not enough observations"))
                  (let-values (((df se)
                                (if var-equal
                                    (let ((v (/ (+ (* (- nx 1) vx) (* (- ny 1) vy)) (+ nx ny -2))))
                                      (values (+ nx ny -2) (sqrt (* v (+ (/ 1 nx) (/ 1 ny))))))
                                    (let ((sx (/ vx nx)) (sy (/ vy ny)))
                                      (values (/ (sq (+ sx sy)) (+ (/ (sq sx) (- nx 1)) (/ (sq sy) (- ny 1))))
                                              (sqrt (+ sx sy)))))))
                    (values (if var-equal " Two Sample t-test" "Welch Two Sample t-test")
                            #f df se (list mx my)
                            (if groups
                                (map (lambda (g) (string-append "mean in group " g)) groups)
                                '("mean of x" "mean of y"))
                            (- mx my))))))))
          (let* ((center (if (list? est) diff est))
                 (tstat (/ (- center mu) se))
                 (pval (p-from-cdf (lambda (s low) (pt s df low)) tstat alt))
                 (cint (case alt
                         ((less) (list -inf (+ tstat (qt conf df))))
                         ((greater) (list (- tstat (qt conf df)) +inf))
                         (else (let ((q (qt (- 1 (/ (- 1 conf) 2)) df))) (list (- tstat q) (+ tstat q))))))
                 (cint (map (lambda (c) (+ mu (* c se))) cint)))
            (make-htest method dname
                        (list (cons "t" tstat))
                        (list (cons "df" df))
                        pval cint conf
                        (map cons est-names (if (list? est) est (list est)))
                        (list (cons (cond (paired "mean difference")
                                          (y "difference in means")
                                          (else "mean"))
                                    mu))
                        alt
                        (append (list (cons 'stderr se))
                                (if diff (list (cons 'difference diff)) '())))))))

    ;; --- Wilcoxon -----------------------------------------------------------

    (define (ranks-of l)
      ;; average ranks of the numbers in l (in order), and the tie counts
      (let* ((v (list->vector l))
             (n (vector-length v))
             (idx (list->vector (list-sort (lambda (i j) (< (vector-ref v i) (vector-ref v j))) (iota n))))
             (r (make-vector n 0)))
        (let loop ((i 0) (ties '()))
          (if (>= i n)
              (values (vector->list r) ties)
              (let run ((j i))
                (if (and (< (+ j 1) n) (= (vector-ref v (vector-ref idx (+ j 1))) (vector-ref v (vector-ref idx i))))
                    (run (+ j 1))
                    (let ((avg (/ (+ i j 2) 2)))
                      (do ((k i (+ k 1))) ((> k j)) (vector-set! r (vector-ref idx k) avg))
                      (loop (+ j 1) (if (> j i) (cons (+ (- j i) 1) ties) ties)))))))))

    ;; coefficients of a polynomial as a vector of exact counts
    (define (signrank-counts n)
      ;; prod_{i=1..n} (1 + q^i)
      (let* ((len (+ 1 (quotient (* n (+ n 1)) 2)))
             (c (make-vector len 0)))
        (vector-set! c 0 1)
        (do ((i 1 (+ i 1))) ((> i n) c)
          (do ((s (- len 1) (- s 1))) ((< s i))
            (vector-set! c s (+ (vector-ref c s) (vector-ref c (- s i))))))))

    (define (ranksum-counts m n)
      ;; Gaussian binomial [m+n choose m]_q = prod_{i=1..m} (1 - q^(n+i)) / (1 - q^i)
      (let* ((len (+ 1 (* m n)))
             (c (make-vector len 0)))
        (vector-set! c 0 1)
        (do ((i 1 (+ i 1))) ((> i m) c)
          (let ((k (+ n i)))
            (do ((s (- len 1) (- s 1))) ((< s k))
              (vector-set! c s (- (vector-ref c s) (vector-ref c (- s k))))))
          (do ((s i (+ s 1))) ((>= s len))
            (vector-set! c s (+ (vector-ref c s) (vector-ref c (- s i))))))))

    ;; P(S <= q) for a count vector
    (define (counts-cdf c q)
      (let ((total (fold + 0 (vector->list c))))
        (if (< q 0)
            0.0
            (inexact (/ (let loop ((s 0) (acc 0))
                          (if (or (> s q) (>= s (vector-length c))) acc (loop (+ s 1) (+ acc (vector-ref c s)))))
                        total)))))

    (define (exact-discrete-p c stat center alt)
      ;; R's convention for exact Wilcoxon / Kendall p-values
      (let ((upper (lambda (q) (- 1.0 (counts-cdf c q)))))
        (case alt
          ((less) (counts-cdf c stat))
          ((greater) (upper (- stat 1)))
          (else (min 1.0 (* 2 (if (> stat center) (upper (- stat 1)) (counts-cdf c stat))))))))

    (define (normal-p z sigma correct alt)
      (let* ((corr (if correct
                       (case alt ((less) -0.5) ((greater) 0.5) (else (* 0.5 (if (> z 0) 1 (if (< z 0) -1 0)))))
                       0))
             (zz (/ (- z corr) sigma)))
        (values zz (p-from-cdf (lambda (s low) (pnorm s 0 1 low)) zz alt))))

    (define (wilcox-test x . args)
      "Syntax: (wilcox-test x [y] option ...) or (wilcox-test df '(y ~ g) option ...)
Library: (scm data tests)
Description: The Wilcoxon signed-rank test (x alone, or paired) or rank-sum
  (Mann-Whitney) test, as R's wilcox.test: exact p-values below 50
  observations without ties (and zeros), else the normal approximation
  with tie correction and continuity correction. Options: 'alternative,
  'mu 0, 'paired #f, 'exact 'auto|#t|#f, 'correct #t.
Example:
  (wilcox-test '(1 2 3) '(4 5 6 7))"
      (if (data-frame? x)
          (let-values (((dname levels samples) (split-by-formula x (car args))))
            (unless (= (length levels) 2) (error "wilcox-test: the grouping needs exactly 2 levels" levels))
            (wilcox-impl (car samples) (cadr samples) (cdr args) dname))
          (let-values (((y opts) (if (and (pair? args) (not (symbol? (car args))))
                                     (values (car args) (cdr args))
                                     (values #f args))))
            (if (and y (opt opts 'paired #f))
                (let ((ps (filter (lambda (p) (not (or (na? (car p)) (na? (cdr p)))))
                                  (map cons (->list x) (->list y)))))
                  (wilcox-impl (map (lambda (p) (inexact (- (car p) (cdr p)))) ps) #f opts "x and y"))
                (wilcox-impl (numbers x) (and y (numbers y)) opts (if y "x and y" "x"))))))

    (define (wilcox-impl x y opts dname)
      (let* ((alt (check-alt (opt opts 'alternative 'two-sided)))
             (mu (opt opts 'mu 0))
             (paired (opt opts 'paired #f))
             (exact-opt (opt opts 'exact 'auto))
             (correct (opt opts 'correct #t)))
        (if (not y)
            (let* ((d (map (lambda (v) (- v mu)) x))
                   (zeros? (any zero? d))
                   (d (remove zero? d))
                   (n (length d)))
              (let-values (((r ties) (ranks-of (map abs d))))
                (let* ((v (lsum (map (lambda (ri di) (if (> di 0) ri 0)) r d)))
                       (exact? (if (eq? exact-opt 'auto) (and (< n 50) (null? ties) (not zeros?)) exact-opt))
                       (method (if paired "Wilcoxon signed rank" "Wilcoxon signed rank"))
                       (method (string-append method (if exact? " exact test"
                                                         (if correct " test with continuity correction" " test")))))
                  (let-values (((p) (if exact?
                                        (exact-discrete-p (signrank-counts n) v (/ (* n (+ n 1)) 4) alt)
                                        (let-values (((z p) (normal-p (- v (/ (* n (+ n 1)) 4))
                                                                      (sqrt (- (/ (* n (+ n 1) (+ (* 2 n) 1)) 24)
                                                                               (/ (lsum (map (lambda (t) (- (* t t t) t)) ties)) 48)))
                                                                      correct alt)))
                                          p))))
                    (make-htest method dname (list (cons "V" (inexact v))) '() p #f #f '()
                                (list (cons (if paired "location shift" "location") mu)) alt '())))))
            (let* ((nx (length x)) (ny (length y)))
              (let-values (((r ties) (ranks-of (append (map (lambda (v) (- v mu)) x) y))))
                (let* ((w (- (lsum (take r nx)) (/ (* nx (+ nx 1)) 2)))
                       (exact? (if (eq? exact-opt 'auto) (and (< nx 50) (< ny 50) (null? ties)) exact-opt))
                       (method (string-append "Wilcoxon rank sum"
                                              (if exact? " exact test"
                                                  (if correct " test with continuity correction" " test")))))
                  (let ((p (if exact?
                               (exact-discrete-p (ranksum-counts nx ny) w (/ (* nx ny) 2) alt)
                               (let-values (((z p) (normal-p (- w (/ (* nx ny) 2))
                                                             (sqrt (* (/ (* nx ny) 12)
                                                                      (- (+ nx ny 1)
                                                                         (/ (lsum (map (lambda (t) (- (* t t t) t)) ties))
                                                                            (* (+ nx ny) (+ nx ny -1))))))
                                                             correct alt)))
                                 p))))
                    (make-htest method dname (list (cons "W" (inexact w))) '() p #f #f '()
                                (list (cons "location shift" mu)) alt '()))))))))

    ;; --- chi-squared --------------------------------------------------------

    (define (matrix-rows m)
      ;; list of lists of numbers from a list/vector of rows or a frame
      (cond ((data-frame? m)
             (let ((cols (filter (lambda (c) (let ((v (df-column m c)))
                                               (and (> (vector-length v) 0)
                                                    (every (lambda (x) (and (real? x) (not (na? x)))) (vector->list v)))))
                                 (df-names m))))
               (map (lambda (i) (map (lambda (c) (vector-ref (df-column m c) i)) cols))
                    (iota (df-nrow m)))))
            ((vector? m) (map ->list (vector->list m)))
            (else (map ->list m))))

    (define (table-of xs ys)
      (let* ((ps (filter (lambda (p) (not (or (na? (car p)) (na? (cdr p))))) (map cons (->list xs) (->list ys))))
             (rk (list-sort value<? (delete-duplicates (map car ps))))
             (ck (list-sort value<? (delete-duplicates (map cdr ps)))))
        (map (lambda (r) (map (lambda (c) (count (lambda (p) (and (equal? (car p) r) (equal? (cdr p) c))) ps)) ck)) rk)))

    (define (chisq-test x . args)
      "Syntax: (chisq-test x [y] option ...)
Library: (scm data tests)
Description: Pearson's chi-squared test, as R's chisq.test: for a
  contingency table (a list or vector of rows, or a frame whose numeric
  columns are the table, such as crosstab gives without margins), for two
  vectors of categories (cross-tabulated), or a goodness-of-fit test for
  one vector of counts against 'p (default: equal; 'rescale-p #t scales p
  to sum 1). 2x2 tables get Yates' correction unless 'correct #f.
  (htest-ref h 'expected) and 'residuals give the expected counts and
  Pearson residuals.
Example:
  (chisq-test '((762 327 468) (484 239 477)))"
      (let-values (((y opts) (if (and (pair? args) (not (symbol? (car args))))
                                 (values (car args) (cdr args))
                                 (values #f args))))
        (let* ((correct (opt opts 'correct #t))
               (table (cond (y (table-of x y))
                            ((data-frame? x) (matrix-rows x))
                            ((and (pair? (->list x)) (or (pair? (car (->list x))) (vector? (car (->list x)))))
                             (matrix-rows x))
                            (else #f))))
          (if (and table (> (length table) 1) (> (length (car table)) 1))
              (let* ((table (map (lambda (r) (map inexact r)) table))
                     (n (lsum (map lsum table)))
                     (sr (map lsum table))
                     (sc (apply map (lambda col (lsum col)) table))
                     (e (map (lambda (r) (map (lambda (c) (/ (* r c) n)) sc)) sr))
                     (two (and correct (= (length sr) 2) (= (length sc) 2)))
                     (yates (if two
                                (min 0.5 (apply min (append-map (lambda (o ex) (map (lambda (a b) (abs (- a b))) o ex)) table e)))
                                0))
                     (stat (lsum (append-map (lambda (o ex) (map (lambda (a b) (/ (sq (- (abs (- a b)) yates)) b)) o ex)) table e)))
                     (dfree (* (- (length sr) 1) (- (length sc) 1))))
                (make-htest (if two "Pearson's Chi-squared test with Yates' continuity correction" "Pearson's Chi-squared test")
                            (if y "x and y" "x")
                            (list (cons "X-squared" stat)) (list (cons "df" dfree))
                            (pchisq stat dfree #f) #f #f '() '() 'two-sided
                            (list (cons 'expected e)
                                  (cons 'observed table)
                                  (cons 'residuals (map (lambda (o ex) (map (lambda (a b) (/ (- a b) (sqrt b))) o ex)) table e)))))
              (let* ((obs (map inexact (if table (car table) (->list x))))
                     (k (length obs))
                     (n (lsum obs))
                     (p (map inexact (->list (opt opts 'p (make-list k (/ 1 k))))))
                     (p (if (opt opts 'rescale-p #f) (map (lambda (v) (/ v (lsum p))) p) p))
                     (e (map (lambda (pi) (* n pi)) p))
                     (stat (lsum (map (lambda (o ex) (/ (sq (- o ex)) ex)) obs e))))
                (unless (< (abs (- (lsum p) 1)) 1e-8) (error "chisq-test: probabilities must sum to 1" p))
                (make-htest "Chi-squared test for given probabilities" "x"
                            (list (cons "X-squared" stat)) (list (cons "df" (- k 1)))
                            (pchisq stat (- k 1) #f) #f #f '() '() 'two-sided
                            (list (cons 'expected e) (cons 'observed obs)
                                  (cons 'residuals (map (lambda (o ex) (/ (- o ex) (sqrt ex))) obs e)))))))))

    ;; --- Fisher -------------------------------------------------------------

    (define (uniroot f lo hi)
      ;; bisection to full precision; f(lo) and f(hi) differ in sign
      (let ((flo (f lo)))
        (let loop ((lo lo) (hi hi) (flo flo) (i 0))
          (let ((mid (/ (+ lo hi) 2)))
            (if (or (> i 300) (<= (- hi lo) (* 1e-14 (max 1e-300 (abs mid)))))
                mid
                (let ((fm (f mid)))
                  (if (eqv? (> fm 0) (> flo 0))
                      (loop mid hi fm (+ i 1))
                      (loop lo mid flo (+ i 1)))))))))

    (define (fisher-test x . opts)
      "Syntax: (fisher-test table option ...)
Library: (scm data tests)
Description: Fisher's exact test for a 2x2 table (rows as lists, or a
  frame as for chisq-test), as R's fisher.test: the p-value sums the
  probabilities of tables no more likely than the observed one; the
  estimate is the conditional maximum likelihood odds ratio with its
  exact confidence interval. Options: 'alternative, 'or 1 (odds ratio
  under the null), 'conf-level 0.95.
Example:
  (fisher-test '((3 1) (1 3)))"
      (let* ((t (matrix-rows x))
             (_ (unless (and (= (length t) 2) (= (length (car t)) 2) (= (length (cadr t)) 2))
                  (error "fisher-test: only 2x2 tables are supported" x)))
             (alt (check-alt (opt opts 'alternative 'two-sided)))
             (or0 (opt opts 'or 1))
             (conf (opt opts 'conf-level 0.95))
             (a (car (car t))) (b (cadr (car t))) (c (car (cadr t))) (d (cadr (cadr t)))
             (m (+ a c)) (n (+ b d)) (k (+ a b))
             (lo (max 0 (- k n))) (hi (min k m))
             (support (iota (+ 1 (- hi lo)) lo))
             (logdc (map (lambda (s) (- (+ (lchoose m s) (lchoose n (- k s))) (lchoose (+ m n) k))) support)))
        (define (dnhyper ncp)
          (let* ((d (map (lambda (l s) (+ l (* (log ncp) s))) logdc support))
                 (mx (apply max d))
                 (d (map (lambda (v) (exp (- v mx))) d))
                 (tot (lsum d)))
            (map (lambda (v) (/ v tot)) d)))
        (define (mnhyper ncp)
          (cond ((= ncp 0) lo)
                ((= ncp +inf) hi)
                (else (lsum (map * support (dnhyper ncp))))))
        (define (pnhyper q ncp upper)
          (cond ((= ncp 1)
                 (lsum (map (lambda (s l) (if (if upper (>= s q) (<= s q)) (exp l) 0)) support logdc)))
                ((= ncp 0) (if upper (if (<= q lo) 1.0 0.0) (if (>= q lo) 1.0 0.0)))
                ((= ncp +inf) (if upper (if (<= q hi) 1.0 0.0) (if (>= q hi) 1.0 0.0)))
                (else (lsum (map (lambda (s p) (if (if upper (>= s q) (<= s q)) p 0)) support (dnhyper ncp))))))
        (define (mle)
          (cond ((= a lo) 0.0)
                ((= a hi) +inf)
                (else
                 (let ((mu (mnhyper 1.0)))
                   (cond ((> mu a) (uniroot (lambda (t) (- (mnhyper t) a)) 0.0 1.0))
                         ((< mu a) (/ 1.0 (uniroot (lambda (t) (- (mnhyper (/ 1.0 t)) a)) 1e-300 1.0)))
                         (else 1.0))))))
        (define (ncp-u alpha)
          (if (= a hi)
              +inf
              (let ((p (pnhyper a 1.0 #f)))
                (cond ((< p alpha) (uniroot (lambda (t) (- (pnhyper a t #f) alpha)) 0.0 1.0))
                      ((> p alpha) (/ 1.0 (uniroot (lambda (t) (- (pnhyper a (/ 1.0 t) #f) alpha)) 1e-300 1.0)))
                      (else 1.0)))))
        (define (ncp-l alpha)
          (if (= a lo)
              0.0
              (let ((p (pnhyper a 1.0 #t)))
                (cond ((> p alpha) (uniroot (lambda (t) (- (pnhyper a t #t) alpha)) 0.0 1.0))
                      ((< p alpha) (/ 1.0 (uniroot (lambda (t) (- (pnhyper a (/ 1.0 t) #t) alpha)) 1e-300 1.0)))
                      (else 1.0)))))
        (let* ((pval (case alt
                       ((less) (pnhyper a or0 #f))
                       ((greater) (pnhyper a or0 #t))
                       (else
                        (if (= or0 0)
                            (if (= a lo) 1.0 0.0)
                            (let* ((dd (dnhyper (inexact or0)))
                                   (obs (list-ref dd (- a lo))))
                              (min 1.0 (lsum (filter (lambda (v) (<= v (* obs (+ 1 1e-7)))) dd))))))))
               (cint (case alt
                       ((less) (list 0.0 (ncp-u (- 1 conf))))
                       ((greater) (list (ncp-l (- 1 conf)) +inf))
                       (else (let ((al (/ (- 1 conf) 2))) (list (ncp-l al) (ncp-u al)))))))
          (make-htest "Fisher's Exact Test for Count Data" "x" '() '() pval cint conf
                      (list (cons "odds ratio" (mle)))
                      (list (cons "odds ratio" or0)) alt '()))))

    ;; --- binomial and proportions -------------------------------------------

    (define (binom-test x n . opts)
      "Syntax: (binom-test successes trials option ...)
Library: (scm data tests)
Description: The exact binomial test, as R's binom.test, with the
  Clopper-Pearson confidence interval. Options: 'p 0.5, 'alternative,
  'conf-level 0.95.
Example:
  (binom-test 682 925 'p 0.75)"
      (let* ((p (opt opts 'p 0.5))
             (alt (check-alt (opt opts 'alternative 'two-sided)))
             (conf (opt opts 'conf-level 0.95))
             (pval (case alt
                     ((less) (pbinom x n p))
                     ((greater) (pbinom (- x 1) n p #f))
                     (else
                      (cond ((= p 0) (if (= x 0) 1.0 0.0))
                            ((= p 1) (if (= x n) 1.0 0.0))
                            (else
                             (let* ((d (* (dbinom x n p) (+ 1 1e-7))) (m (* n p)))
                               (cond ((= x m) 1.0)
                                     ((< x m)
                                      (let ((y (count (lambda (i) (<= (dbinom i n p) d))
                                                      (iota (+ 1 (- n (exact (ceiling m)))) (exact (ceiling m))))))
                                        (min 1.0 (+ (pbinom x n p) (pbinom (- n y) n p #f)))))
                                     (else
                                      (let ((y (count (lambda (i) (<= (dbinom i n p) d))
                                                      (iota (+ 1 (exact (floor m)))))))
                                        (min 1.0 (+ (pbinom (- y 1) n p) (pbinom (- x 1) n p #f))))))))))))
             (p-l (lambda (alpha) (if (= x 0) 0.0 (qbeta alpha x (+ (- n x) 1)))))
             (p-u (lambda (alpha) (if (= x n) 1.0 (qbeta (- 1 alpha) (+ x 1) (- n x)))))
             (cint (case alt
                     ((less) (list 0.0 (p-u (- 1 conf))))
                     ((greater) (list (p-l (- 1 conf)) 1.0))
                     (else (let ((al (/ (- 1 conf) 2))) (list (p-l al) (p-u al)))))))
        (make-htest "Exact binomial test" "x and n"
                    (list (cons "number of successes" x))
                    (list (cons "number of trials" n))
                    pval cint conf
                    (list (cons "probability of success" (inexact (/ x n))))
                    (list (cons "probability of success" p)) alt '())))

    (define (prop-test x n . opts)
      "Syntax: (prop-test successes trials option ...)
Library: (scm data tests)
Description: The test of equal (or given) proportions, as R's prop.test:
  successes and trials are numbers (one group) or lists (k groups).
  One group gets Wilson's score interval, two groups the interval of the
  difference, both with continuity correction (k <= 2) unless
  'correct #f. Options: 'p (null proportion(s)), 'alternative,
  'conf-level, 'correct.
Example:
  (prop-test '(83 90 129 70) '(86 93 136 82))"
      (let* ((xs (map inexact (if (number? x) (list x) (->list x))))
             (ns (map inexact (if (number? n) (list n) (->list n))))
             (k (length xs))
             (p0 (let ((p (opt opts 'p #f))) (and p (if (number? p) (list p) (->list p)))))
             (alt (check-alt (opt opts 'alternative 'two-sided)))
             (conf (opt opts 'conf-level 0.95))
             (correct (opt opts 'correct #t))
             (est (map / xs ns))
             (yates0 (if (and correct (<= k 2)) 0.5 0.0))
             (z (qnorm (if (eq? alt 'two-sided) (/ (+ 1 conf) 2) conf)))
             (yates (cond ((and (= k 1) p0) (min yates0 (abs (- (car xs) (* (car ns) (car p0))))))
                          ((and (= k 1)) (min yates0 (abs (- (car xs) (* (car ns) 0.5)))))
                          ((and (= k 2) (not p0))
                           (min yates0 (/ (abs (- (car est) (cadr est))) (lsum (map (lambda (v) (/ 1 v)) ns)))))
                          (else yates0)))
             (p0 (if (and (= k 1) (not p0)) '(0.5) p0))
             (cint (cond
                    ((= k 1)
                     (let* ((nn (car ns)) (e (car est)) (z22n (/ (* z z) (* 2 nn)))
                            (bound (lambda (pc sign)
                                     (/ (+ pc z22n (* sign z (sqrt (+ (/ (* pc (- 1 pc)) nn) (/ z22n (* 2 nn))))))
                                        (+ 1 (* 2 z22n)))))
                            (pc-u (+ e (/ yates nn)))
                            (pu (if (>= pc-u 1) 1.0 (bound pc-u 1)))
                            (pc-l (- e (/ yates nn)))
                            (pl (if (<= pc-l 0) 0.0 (bound pc-l -1))))
                       (case alt
                         ((less) (list 0.0 (min pu 1.0)))
                         ((greater) (list (max pl 0.0) 1.0))
                         (else (list (max pl 0.0) (min pu 1.0))))))
                    ((and (= k 2) (not p0))
                     (let* ((delta (- (car est) (cadr est)))
                            (width (+ (* z (sqrt (lsum (map (lambda (e nn) (/ (* e (- 1 e)) nn)) est ns))))
                                      (* yates (lsum (map (lambda (v) (/ 1 v)) ns))))))
                       (case alt
                         ((less) (list -1.0 (min (+ delta width) 1.0)))
                         ((greater) (list (max (- delta width) -1.0) 1.0))
                         (else (list (max (- delta width) -1.0) (min (+ delta width) 1.0))))))
                    (else #f)))
             (ps (or p0 (make-list k (/ (lsum xs) (lsum ns)))))
             (dfree (if p0 k (- k 1)))
             (obs (append xs (map - ns xs)))
             (ex (append (map * ns ps) (map (lambda (nn p) (* nn (- 1 p))) ns ps)))
             (stat (lsum (map (lambda (o e) (/ (sq (- (abs (- o e)) yates)) e)) obs ex)))
             (pval (if (and (not (eq? alt 'two-sided)) (or (= k 1) (and (= k 2) (not p0))))
                       (let ((zz (* (sqrt stat)
                                    (let ((dlt (if (= k 1) (- (car est) (car ps)) (- (car est) (cadr est)))))
                                      (cond ((> dlt 0) 1) ((< dlt 0) -1) (else 0))))))
                         (pnorm zz 0 1 (eq? alt 'less)))
                       (pchisq stat dfree #f))))
        (make-htest (string-append (if (= k 1) "1-sample proportions test" (string-append (number->string k) "-sample test for "
                                                                                           (if p0 "given proportions" "equality of proportions")))
                                   (if (> yates 0) " with continuity correction" " without continuity correction"))
                    "x out of n"
                    (list (cons "X-squared" stat)) (list (cons "df" dfree))
                    pval cint conf
                    (if (= k 1)
                        (list (cons "p" (car est)))
                        (map (lambda (e i) (cons (string-append "prop " (number->string i)) e)) est (iota k 1)))
                    (if (= k 1) (list (cons "p" (car ps))) '())
                    alt '())))

    ;; --- correlation --------------------------------------------------------

    (define (paired-numbers x y)
      (let ((ps (filter (lambda (p) (not (or (na? (car p)) (na? (cdr p))))) (map cons (->list x) (->list y)))))
        (values (map (lambda (p) (inexact (car p))) ps) (map (lambda (p) (inexact (cdr p))) ps))))

    (define (pearson x y)
      (let* ((mx (lmean x)) (my (lmean y))
             (sxy (lsum (map (lambda (a b) (* (- a mx) (- b my))) x y)))
             (sxx (lsum (map (lambda (a) (sq (- a mx))) x)))
             (syy (lsum (map (lambda (b) (sq (- b my))) y))))
        (/ sxy (sqrt (* sxx syy)))))

    (define (kendall-counts n)
      ;; number of permutations of n by inversions: prod_{i=1..n} (1 + q + … + q^(i-1))
      (let* ((len (+ 1 (quotient (* n (- n 1)) 2)))
             (c (make-vector len 0)))
        (vector-set! c 0 1)
        (do ((i 2 (+ i 1))) ((> i n) c)
          ;; multiply by (1 - q^i)/(1 - q): prefix sums, then subtract shifted
          (do ((s 1 (+ s 1))) ((>= s len))
            (vector-set! c s (+ (vector-ref c s) (vector-ref c (- s 1)))))
          (do ((s (- len 1) (- s 1))) ((< s i))
            (vector-set! c s (- (vector-ref c s) (vector-ref c (- s i))))))))

    (define (tie-counts l)
      (let-values (((r ties) (ranks-of l))) ties))

    (define (cor-test x y . opts)
      "Syntax: (cor-test x y option ...)
Library: (scm data tests)
Description: Test of association, as R's cor.test: 'method pearson
  (t test with Fisher's z confidence interval), kendall (exact below 50
  pairs without ties, else normal with tie correction) or spearman (the
  t approximation, as R with exact = FALSE). Options: 'alternative,
  'conf-level, 'exact 'auto|#f.
Example:
  (cor-test '(1 2 3 4 5) '(2 1 4 3 5))"
      (let-values (((x y) (paired-numbers x y)))
        (let* ((alt (check-alt (opt opts 'alternative 'two-sided)))
               (method (opt opts 'method 'pearson))
               (conf (opt opts 'conf-level 0.95))
               (n (length x)))
          (case method
            ((pearson)
             (let* ((r (pearson x y)) (dfree (- n 2))
                    (tstat (/ (* r (sqrt dfree)) (sqrt (- 1 (* r r)))))
                    (pval (p-from-cdf (lambda (s low) (pt s dfree low)) tstat alt))
                    (cint (and (> n 3)
                               (let ((z (atanh* r)) (sigma (/ 1 (sqrt (- n 3)))))
                                 (case alt
                                   ((less) (list -1.0 (tanh* (+ z (* sigma (qnorm conf))))))
                                   ((greater) (list (tanh* (- z (* sigma (qnorm conf)))) 1.0))
                                   (else (let ((q (qnorm (/ (+ 1 conf) 2))))
                                           (list (tanh* (- z (* sigma q))) (tanh* (+ z (* sigma q)))))))))))
               (make-htest "Pearson's product-moment correlation" "x and y"
                           (list (cons "t" tstat)) (list (cons "df" dfree)) pval cint (and cint conf)
                           (list (cons "cor" r)) (list (cons "correlation" 0)) alt '())))
            ((spearman)
             (let-values (((rx tx) (ranks-of x)) ((ry ty) (ranks-of y)))
               (let* ((rho (pearson rx ry))
                      (s (* (/ (- (* n n n) n) 6) (- 1 rho)))
                      (tstat (/ rho (sqrt (/ (- 1 (* rho rho)) (- n 2)))))
                      (pval (p-from-cdf (lambda (v low) (pt v (- n 2) low)) tstat alt)))
                 (make-htest "Spearman's rank correlation rho" "x and y"
                             (list (cons "S" s)) '() pval #f #f
                             (list (cons "rho" rho)) (list (cons "rho" 0)) alt '()))))
            ((kendall)
             (let* ((pairs (append-map (lambda (i) (map (lambda (j) (cons i j)) (iota (- n i 1) (+ i 1)))) (iota n)))
                    (xv (list->vector x)) (yv (list->vector y))
                    (sgn (lambda (v) (cond ((> v 0) 1) ((< v 0) -1) (else 0))))
                    (s (lsum (map (lambda (p) (* (sgn (- (vector-ref xv (car p)) (vector-ref xv (cdr p))))
                                                 (sgn (- (vector-ref yv (car p)) (vector-ref yv (cdr p))))))
                                  pairs)))
                    (xt (tie-counts x)) (yt (tie-counts y))
                    (t0 (/ (* n (- n 1)) 2))
                    (t1 (/ (lsum (map (lambda (t) (* t (- t 1))) xt)) 2))
                    (t2 (/ (lsum (map (lambda (t) (* t (- t 1))) yt)) 2))
                    (tau (/ s (sqrt (* (- t0 t1) (- t0 t2)))))
                    (exact? (let ((e (opt opts 'exact 'auto)))
                              (if (eq? e 'auto) (and (< n 50) (null? xt) (null? yt)) e))))
               (if exact?
                   (let ((q (exact (round (/ (* (+ tau 1) n (- n 1)) 4)))))
                     (make-htest "Kendall's rank correlation tau" "x and y"
                                 (list (cons "T" q)) '()
                                 (exact-discrete-p (kendall-counts n) q (/ (* n (- n 1)) 4) alt)
                                 #f #f (list (cons "tau" (inexact tau))) (list (cons "tau" 0)) alt '()))
                   (let* ((v0 (* n (- n 1) (+ (* 2 n) 5)))
                          (f1 (lambda (ts g) (lsum (map g ts))))
                          (vt (f1 xt (lambda (t) (* t (- t 1) (+ (* 2 t) 5)))))
                          (vu (f1 yt (lambda (t) (* t (- t 1) (+ (* 2 t) 5)))))
                          (v1 (* (f1 xt (lambda (t) (* t (- t 1)))) (f1 yt (lambda (t) (* t (- t 1))))))
                          (v2 (* (f1 xt (lambda (t) (* t (- t 1) (- t 2)))) (f1 yt (lambda (t) (* t (- t 1) (- t 2))))))
                          (var-s (+ (/ (- v0 vt vu) 18) (/ v1 (* 2 n (- n 1))) (/ v2 (* 9 n (- n 1) (- n 2)))))
                          (z (/ s (sqrt var-s))))
                     (make-htest "Kendall's rank correlation tau" "x and y"
                                 (list (cons "z" (inexact z))) '()
                                 (p-from-cdf (lambda (v low) (pnorm v 0 1 low)) z alt)
                                 #f #f (list (cons "tau" (inexact tau))) (list (cons "tau" 0)) alt '())))))
            (else (error "cor-test: method must be pearson, kendall or spearman" method))))))

    (define (atanh* r) (* 0.5 (log (/ (+ 1 r) (- 1 r)))))
    (define (tanh* z) (let ((e (exp (* 2 z)))) (/ (- e 1) (+ e 1))))

    ;; --- Shapiro-Wilk (Royston 1995, algorithm AS R94) ------------------------

    (define (shapiro-test x)
      "Syntax: (shapiro-test x)
Library: (scm data tests)
Description: The Shapiro-Wilk normality test (Royston's algorithm, as R's
  shapiro.test) for 3 to 5000 values.
Example:
  (shapiro-test '(2.1 3.4 1.9 5.6 4.4 3.3 2.8))"
      (let* ((xs (list->vector (list-sort < (numbers x))))
             (n (vector-length xs)))
        (when (or (< n 3) (> n 5000)) (error "shapiro-test: sample size must be between 3 and 5000" n))
        (let* ((nn2 (quotient n 2))
               (an (inexact n))
               (a (make-vector (+ nn2 1) 0.0)))
          (if (= n 3)
              (vector-set! a 1 (sqrt 0.5))
              (let* ((an25 (+ an 0.25))
                     (_ (do ((i 1 (+ i 1))) ((> i nn2))
                          (vector-set! a i (qnorm (/ (- i 0.375) an25)))))
                     (summ2 (* 2 (lsum (map (lambda (i) (sq (vector-ref a i))) (iota nn2 1)))))
                     (ssumm2 (sqrt summ2))
                     (rsn (/ 1 (sqrt an)))
                     (a1 (- (poly rsn '(0.0 0.221157 -0.147981 -2.07119 4.434685 -2.706056))
                            (/ (vector-ref a 1) ssumm2))))
                (let-values (((i1 fac)
                              (if (> n 5)
                                  (let* ((a2 (+ (/ (- (vector-ref a 2)) ssumm2)
                                                (poly rsn '(0.0 0.042981 -0.293762 -1.752461 5.682633 -3.582633))))
                                         (fac (sqrt (/ (- summ2 (* 2 (sq (vector-ref a 1))) (* 2 (sq (vector-ref a 2))))
                                                       (- 1 (* 2 (sq a1)) (* 2 (sq a2)))))))
                                    (vector-set! a 2 a2)
                                    (values 3 fac))
                                  (values 2 (sqrt (/ (- summ2 (* 2 (sq (vector-ref a 1))))
                                                     (- 1 (* 2 (sq a1)))))))))
                  (vector-set! a 1 a1)
                  (do ((i i1 (+ i 1))) ((> i nn2))
                    (vector-set! a i (/ (vector-ref a i) (- fac)))))))
          (let* ((range (- (vector-ref xs (- n 1)) (vector-ref xs 0))))
            (when (< range 1e-19) (error "shapiro-test: all values are identical"))
            ;; full coefficient vector, antisymmetric
            (let* ((coef (map (lambda (i)
                                (let ((j (- n 1 i)))
                                  (cond ((< i j) (- (vector-ref a (+ i 1))))
                                        ((> i j) (vector-ref a (+ j 1)))
                                        (else 0.0))))
                              (iota n)))
                   (xr (map (lambda (v) (/ v range)) (vector->list xs)))
                   (sa (lmean coef)) (sx (lmean xr))
                   (ssa (lsum (map (lambda (c) (sq (- c sa))) coef)))
                   (ssx (lsum (map (lambda (v) (sq (- v sx))) xr)))
                   (sax (lsum (map (lambda (c v) (* (- c sa) (- v sx))) coef xr)))
                   (ssassx (sqrt (* ssa ssx)))
                   (w1 (/ (* (- ssassx sax) (+ ssassx sax)) (* ssa ssx)))
                   (w (- 1 w1))
                   (pw (cond
                        ((= n 3) (max 0.0 (* 1.90985931710274 (- (asin (sqrt w)) 1.04719755119660))))
                        ((<= n 11)
                         (let ((gamma (poly an '(-2.273 0.459)))
                               (y (log w1)))
                           (if (>= y gamma)
                               1e-99
                               (let ((y (- (log (- gamma y))))
                                     (m (poly an '(0.544 -0.39978 0.025054 -6.714e-4)))
                                     (s (exp (poly an '(1.3822 -0.77857 0.062767 -0.0020322)))))
                                 (pnorm y m s #f)))))
                        (else
                         (let ((xx (log an)))
                           (pnorm (log w1)
                                  (poly xx '(-1.5861 -0.31082 -0.083751 0.0038915))
                                  (exp (poly xx '(-0.4803 -0.082676 0.0030302)))
                                  #f))))))
              (make-htest "Shapiro-Wilk normality test" "x" (list (cons "W" w)) '() pw #f #f '() '() 'two-sided '()))))))

    ;; --- Kolmogorov-Smirnov --------------------------------------------------

    ;; Marsaglia, Tsang & Wang (2003): P(D_n < d)
    (define (kolmogorov-exact n d)
      (let* ((k (+ (exact (floor (* n d))) 1))
             (m (- (* 2 k) 1))
             (h (- k (* n d)))
             (hm (make-vector (* m m) 0.0)))
        (define (at i j) (+ (* i m) j))
        (define (mmul a b)
          (let ((c (make-vector (* m m) 0.0)))
            (do ((i 0 (+ i 1))) ((= i m) c)
              (do ((j 0 (+ j 1))) ((= j m))
                (let loop ((kk 0) (s 0.0))
                  (if (= kk m)
                      (vector-set! c (at i j) s)
                      (loop (+ kk 1) (+ s (* (vector-ref a (at i kk)) (vector-ref b (at kk j)))))))))))
        ;; -> (values matrix exponent)
        (define (mpow a ea p)
          (if (= p 1)
              (values a ea)
              (let-values (((v ev) (mpow a ea (quotient p 2))))
                (let* ((b (mmul v v)) (eb (* 2 ev)))
                  (let-values (((v ev) (if (odd? p) (values (mmul a b) (+ ea eb)) (values b eb))))
                    (if (> (vector-ref v (at (quotient m 2) (quotient m 2))) 1e140)
                        (values (vector-map (lambda (x) (* x 1e-140)) v) (+ ev 140))
                        (values v ev)))))))
        (do ((i 0 (+ i 1))) ((= i m))
          (do ((j 0 (+ j 1))) ((= j m))
            (vector-set! hm (at i j) (if (< (+ (- i j) 1) 0) 0.0 1.0))))
        (do ((i 0 (+ i 1))) ((= i m))
          (vector-set! hm (at i 0) (- (vector-ref hm (at i 0)) (expt h (+ i 1))))
          (vector-set! hm (at (- m 1) i) (- (vector-ref hm (at (- m 1) i)) (expt h (- m i)))))
        (vector-set! hm (at (- m 1) 0) (+ (vector-ref hm (at (- m 1) 0))
                                          (if (> (- (* 2 h) 1) 0) (expt (- (* 2 h) 1) m) 0.0)))
        (do ((i 0 (+ i 1))) ((= i m))
          (do ((j 0 (+ j 1))) ((= j m))
            (when (> (+ (- i j) 1) 0)
              (do ((g 1 (+ g 1))) ((> g (+ (- i j) 1)))
                (vector-set! hm (at i j) (/ (vector-ref hm (at i j)) g))))))
        (let-values (((q eq) (mpow hm 0 n)))
          (let loop ((i 1) (s (vector-ref q (at (- k 1) (- k 1)))) (eq eq))
            (if (> i n)
                (* s (expt 10.0 eq))
                (let ((s (/ (* s i) n)))
                  (if (< s 1e-140)
                      (loop (+ i 1) (* s 1e140) (- eq 140))
                      (loop (+ i 1) s eq))))))))

    ;; limiting distribution: P(sqrt(n) D <= x)
    (define (kolmogorov-limit x)
      (cond ((<= x 0) 0.0)
            ((< x 1)
             (let ((z (/ (- (/ (* pi pi) 8)) (* x x))) (w (log x)))
               (/ (lsum (map (lambda (k) (exp (- (* k k z) w))) '(1 3 5 7 9 11 13 15 17 19)))
                  0.398942280401432678)))
            (else
             (let loop ((k 1) (s -1) (old 0.0) (new 1.0))
               (if (or (< (abs (- old new)) 1e-12) (> k 100))
                   new
                   (loop (+ k 1) (- s) new (+ new (* 2 s (exp (* -2 x x k k))))))))))

    ;; P(D < d) for two samples without ties (R's psmirnov2x)
    (define (smirnov-exact d m n)
      (let-values (((m n) (if (> m n) (values n m) (values m n))))
        (let* ((q (/ (+ 0.5 (floor (- (* d m n) 1e-7))) (* m n)))
               (u (make-vector (+ n 1) 0.0)))
          (do ((j 0 (+ j 1))) ((> j n))
            (vector-set! u j (if (> (/ j n) q) 0.0 1.0)))
          (do ((i 1 (+ i 1))) ((> i m) (vector-ref u n))
            (let ((w (/ i (+ i n))))
              (vector-set! u 0 (if (> (/ i m) q) 0.0 (* w (vector-ref u 0))))
              (do ((j 1 (+ j 1))) ((> j n))
                (vector-set! u j (if (> (abs (- (/ i m) (/ j n))) q)
                                     0.0
                                     (+ (* w (vector-ref u j)) (vector-ref u (- j 1)))))))))))

    (define (ks-test x y . opts)
      "Syntax: (ks-test x y option ...)
Library: (scm data tests)
Description: The Kolmogorov-Smirnov test, as R's ks.test: y is either a
  second sample, or a distribution function (a procedure of one
  argument, e.g. (lambda (q) (pnorm q 0 1))). Exact p-values for one
  sample below 100 values and for two samples with m*n < 10000 (two-sided,
  no ties); otherwise the asymptotic distribution. Options: 'alternative
  two-sided|less|greater, 'exact 'auto|#f.
Example:
  (ks-test '(0.1 -0.4 1.2 0.8 -1.5) pnorm)"
      (let* ((alt (check-alt (opt opts 'alternative 'two-sided)))
             (exact-opt (opt opts 'exact 'auto))
             (xs (list-sort < (numbers x)))
             (n (length xs))
             (ties? (lambda (l) (let loop ((l l)) (and (pair? l) (pair? (cdr l)) (or (= (car l) (cadr l)) (loop (cdr l))))))))
        (if (procedure? y)
            (let* ((fs (map (lambda (v) (inexact (y v))) xs))
                   (dplus (apply max (map (lambda (f i) (- (/ i n) f)) fs (iota n 1))))
                   (dminus (apply max (map (lambda (f i) (- f (/ (- i 1) n))) fs (iota n 1))))
                   (d (case alt ((greater) dplus) ((less) dminus) (else (max dplus dminus))))
                   (exact? (if (eq? exact-opt 'auto) (and (< n 100) (not (ties? xs))) exact-opt))
                   (pval (cond ((not (eq? alt 'two-sided)) (exp (* -2 n d d)))
                               (exact? (- 1 (kolmogorov-exact n d)))
                               (else (- 1 (kolmogorov-limit (* (sqrt n) d)))))))
              (make-htest (string-append (if (and exact? (eq? alt 'two-sided)) "Exact one-sample" "Asymptotic one-sample")
                                         " Kolmogorov-Smirnov test")
                          "x" (list (cons (case alt ((greater) "D^+") ((less) "D^-") (else "D")) (inexact d)))
                          '() (clamp01 pval) #f #f '() '() alt '()))
            (let* ((ys (list-sort < (numbers y)))
                   (m (length ys))
                   (pts (list-sort < (append xs ys)))
                   (cdf (lambda (l v) (/ (count (lambda (a) (<= a v)) l) (length l))))
                   (diffs (map (lambda (v) (- (cdf xs v) (cdf ys v))) pts))
                   (d (case alt
                        ((greater) (apply max 0 diffs))
                        ((less) (apply max 0 (map - diffs)))
                        (else (apply max (map abs diffs)))))
                   (exact? (if (eq? exact-opt 'auto) (and (< (* n m) 10000) (not (ties? pts))) exact-opt))
                   (pval (cond ((not (eq? alt 'two-sided)) (exp (* -2 (/ (* n m) (+ n m)) d d)))
                               (exact? (- 1 (smirnov-exact d n m)))
                               (else (- 1 (kolmogorov-limit (* (sqrt (/ (* n m) (+ n m))) d)))))))
              (make-htest (string-append (if (and exact? (eq? alt 'two-sided)) "Exact two-sample" "Asymptotic two-sample")
                                         " Kolmogorov-Smirnov test")
                          "x and y" (list (cons (case alt ((greater) "D^+") ((less) "D^-") (else "D")) (inexact d)))
                          '() (clamp01 pval) #f #f '() '() alt '())))))

    ;; --- k groups --------------------------------------------------------------

    ;; groups from a frame+formula, or from a list of samples
    (define (k-samples x args)
      (if (data-frame? x)
          (let-values (((dname levels samples) (split-by-formula x (car args))))
            (values dname samples (cdr args)))
          (values "x" (map numbers (->list x)) args)))

    (define (oneway-test x . args)
      "Syntax: (oneway-test df '(y ~ g) option ...) or (oneway-test samples option ...)
Library: (scm data tests)
Description: Test of equal means in k groups, as R's oneway.test: Welch's
  F test, or the classic one-way ANOVA F test with 'var-equal #t.
  samples is a list of lists of numbers.
Example:
  (oneway-test '((1 2 3) (2 3 4) (5 6 7)) 'var-equal #t)"
      (let-values (((dname samples opts) (k-samples x args)))
        (let* ((k (length samples))
               (ns (map length samples))
               (ms (map lmean samples))
               (vs (map lvar samples))
               (var-equal (opt opts 'var-equal #f)))
          (if var-equal
              (let* ((n (lsum ns))
                     (m (/ (lsum (map * ns ms)) n))
                     (ssb (lsum (map (lambda (ni mi) (* ni (sq (- mi m)))) ns ms)))
                     (ssw (lsum (map (lambda (ni vi) (* (- ni 1) vi)) ns vs)))
                     (d1 (- k 1)) (d2 (- n k))
                     (f (/ (/ ssb d1) (/ ssw d2))))
                (make-htest "One-way analysis of means" dname (list (cons "F" f))
                            (list (cons "num df" d1) (cons "denom df" d2))
                            (pf f d1 d2 #f) #f #f '() '() 'two-sided
                            (list (cons 'ss-between ssb) (cons 'ss-within ssw))))
              (let* ((ws (map / ns vs))
                     (sw (lsum ws))
                     (tmp (/ (lsum (map (lambda (wi ni) (/ (sq (- 1 (/ wi sw))) (- ni 1))) ws ns)) (- (* k k) 1)))
                     (m (/ (lsum (map * ws ms)) sw))
                     (f (/ (lsum (map (lambda (wi mi) (* wi (sq (- mi m)))) ws ms))
                           (* (- k 1) (+ 1 (* 2 (- k 2) tmp)))))
                     (d2 (/ 1 (* 3 tmp))))
                (make-htest "One-way analysis of means (not assuming equal variances)" dname
                            (list (cons "F" f)) (list (cons "num df" (- k 1)) (cons "denom df" d2))
                            (pf f (- k 1) d2 #f) #f #f '() '() 'two-sided '()))))))

    (define (kruskal-test x . args)
      "Syntax: (kruskal-test df '(y ~ g)) or (kruskal-test samples)
Library: (scm data tests)
Description: The Kruskal-Wallis rank sum test, as R's kruskal.test (with
  the tie correction). samples is a list of lists of numbers.
Example:
  (kruskal-test '((2.9 3.0 2.5 2.6 3.2) (3.8 2.7 4.0 2.4) (2.8 3.4 3.7 2.2 2.0)))"
      (let-values (((dname samples opts) (k-samples x args)))
        (let* ((k (length samples))
               (ns (map length samples))
               (n (lsum ns)))
          (let-values (((r ties) (ranks-of (apply append samples))))
            (let* ((rsums (let loop ((r r) (ns ns) (acc '()))
                            (if (null? ns) (reverse acc)
                                (loop (drop r (car ns)) (cdr ns) (cons (lsum (take r (car ns))) acc)))))
                   (h (- (* (/ 12 (* n (+ n 1))) (lsum (map (lambda (s ni) (/ (* s s) ni)) rsums ns)))
                         (* 3 (+ n 1))))
                   (h (inexact (/ h (- 1 (/ (lsum (map (lambda (t) (- (* t t t) t)) ties)) (- (* n n n) n)))))))
              (make-htest "Kruskal-Wallis rank sum test" dname
                          (list (cons "Kruskal-Wallis chi-squared" h)) (list (cons "df" (- k 1)))
                          (pchisq h (- k 1) #f) #f #f '() '() 'two-sided '()))))))

    ;; --- multiple testing ----------------------------------------------------------

    (define (p-adjust ps . method)
      "Syntax: (p-adjust p-values [method])
Library: (scm data tests)
Description: Adjusts p-values for multiple comparisons, as R's p.adjust:
  holm (default), hochberg, bonferroni, BH (or fdr), BY or none.
  Returns a list in the input order; na stays na.
Example:
  (p-adjust '(0.01 0.02 0.03) 'bonferroni) => (0.03 0.06 0.09)"
      (let* ((method (if (pair? method) (car method) 'holm))
             (l (->list ps))
             (idx (filter (lambda (i) (not (na? (list-ref l i)))) (iota (length l))))
             (n (length idx))
             (p (list->vector (map (lambda (i) (inexact (list-ref l i))) idx)))
             (order-up (list-sort (lambda (i j) (< (vector-ref p i) (vector-ref p j))) (iota n)))
             (order-down (reverse order-up))
             (out (make-vector n 0.0)))
        (define (cum f init order factor)
          ;; running f over p[o]*factor(rank) in the given order
          (let loop ((os order) (rank 0) (acc init))
            (unless (null? os)
              (let ((v (f acc (min 1.0 (* (vector-ref p (car os)) (factor rank))))))
                (vector-set! out (car os) (min 1.0 v))
                (loop (cdr os) (+ rank 1) v)))))
        (case method
          ((bonferroni) (do ((i 0 (+ i 1))) ((= i n)) (vector-set! out i (min 1.0 (* n (vector-ref p i))))))
          ((holm) (cum max 0.0 order-up (lambda (r) (- n r))))
          ((hochberg) (cum min 1.0 order-down (lambda (r) (+ r 1))))
          ((BH bh fdr) (cum min 1.0 order-down (lambda (r) (/ n (- n r)))))
          ((BY by) (let ((q (lsum (map (lambda (i) (/ 1.0 i)) (iota n 1)))))
                     (cum min 1.0 order-down (lambda (r) (* q (/ n (- n r)))))))
          ((none) (do ((i 0 (+ i 1))) ((= i n)) (vector-set! out i (vector-ref p i))))
          (else (error "p-adjust: unknown method" method)))
        (let ((res (list-copy l)))
          (for-each (lambda (i k) (set-car! (list-tail res i) (vector-ref out k))) idx (iota n))
          res)))

    ;; --- linear models ---------------------------------------------------------------

    (define-record-type <lm>
      (make-lm formula terms coefficients residuals fitted rank df-residual
               xtx-inv y-mean intercept? levels n)
      lm?
      (formula lm-formula)
      (terms lm-terms)                 ; list of term names (strings), with "(Intercept)"
      (coefficients lm-coef-vector)
      (residuals lm-residual-vector)
      (fitted lm-fitted-vector)
      (rank lm-rank)
      (df-residual lm-df-residual)
      (xtx-inv lm-xtx-inv)
      (y-mean lm-y-mean)
      (intercept? lm-intercept?)
      (levels lm-levels)               ; alist column -> levels (for factors)
      (n lm-n))

    (define (numeric-column? v)
      (every (lambda (x) (or (na? x) (real? x))) (vector->list v)))

    (define (parse-rhs rhs d response)
      ;; -> (values intercept? columns)
      (let loop ((ts rhs) (sign '+) (icpt #t) (cols '()))
        (cond ((null? ts) (values icpt (reverse cols)))
              ((memq (car ts) '(+ -)) (loop (cdr ts) (car ts) icpt cols))
              ((eqv? (car ts) 0) (loop (cdr ts) '+ #f cols))
              ((eqv? (car ts) 1) (loop (cdr ts) '+ (eq? sign '+) cols))
              ((eq? (car ts) '|.|)
               (loop (cdr ts) '+ icpt
                     (append (reverse (remove (lambda (c) (or (eq? c response) (memq c cols))) (df-names d))) cols)))
              ((symbol? (car ts))
               (loop (cdr ts) '+ icpt (if (eq? sign '-) (remove (lambda (c) (eq? c (car ts))) cols) (cons (car ts) cols))))
              (else (error "lm: unsupported formula term" (car ts))))))

    (define (lm d formula)
      "Syntax: (lm df formula)
Library: (scm data tests)
Description: Fits a linear model by least squares (Householder QR), as
  R's lm. formula is a list such as (y ~ x1 + x2), (y ~ .) for all other
  columns, with 0 or - 1 to drop the intercept. Non-numeric columns are
  factors, coded against their first level (sorted), named like R's
  (column name followed by the level). Rows with na are dropped. See
  lm-summary, lm-coefficients, predict and tidy.
Example:
  (lm mtcars '(mpg ~ wt + hp))"
      (let* ((response (car (formula-lhs formula))))
        (let-values (((icpt cols) (parse-rhs (formula-rhs formula) d response)))
          (let* ((yv (df-column d response))
                 (nrow (df-nrow d))
                 (keep (filter (lambda (i)
                                 (and (not (na? (vector-ref yv i)))
                                      (every (lambda (c) (not (na? (vector-ref (df-column d c) i)))) cols)))
                               (iota nrow)))
                 (levels (filter-map (lambda (c)
                                       (let ((v (df-column d c)))
                                         (and (not (numeric-column? v))
                                              (cons c (list-sort value<? (delete-duplicates
                                                                          (map (lambda (i) (vector-ref v i)) keep)))))))
                                     cols))
                 (terms (append (if icpt '("(Intercept)") '())
                                (append-map (lambda (c)
                                              (let ((lv (assq c levels)))
                                                (if lv
                                                    (map (lambda (l) (string-append (symbol->string c) (level-name l))) (cdr (cdr lv)))
                                                    (list (symbol->string c)))))
                                            cols)))
                 (row-x (lambda (i)
                          (append (if icpt '(1.0) '())
                                  (append-map (lambda (c)
                                                (let ((lv (assq c levels)) (v (vector-ref (df-column d c) i)))
                                                  (if lv
                                                      (map (lambda (l) (if (equal? v l) 1.0 0.0)) (cdr (cdr lv)))
                                                      (list (inexact v)))))
                                              cols))))
                 (x (map row-x keep))
                 (y (map (lambda (i) (inexact (vector-ref yv i))) keep)))
            (lm-fit formula terms x y icpt levels)))))

    (define (lm-fit formula terms x y icpt levels)
      (let* ((n (length y)) (p (length terms))
             (a (list->vector (map list->vector x)))   ; n rows of p
             (b (list->vector y))
             (rdiag (make-vector p 0.0)))
        ;; Householder QR in place: a holds R above the diagonal and the
        ;; reflectors below it; b becomes Q^T y
        (define (aref i j) (vector-ref (vector-ref a i) j))
        (define (aset! i j v) (vector-set! (vector-ref a i) j v))
        (define (r i j) (if (= i j) (vector-ref rdiag i) (aref i j)))
        (when (< n p) (error "lm: fewer observations than coefficients"))
        (do ((k 0 (+ k 1))) ((= k p))
          (let* ((norm (sqrt (let loop ((i k) (s 0.0)) (if (= i n) s (loop (+ i 1) (+ s (sq (aref i k)))))))))
            (when (< norm 1e-12) (error "lm: the model matrix is singular (collinear terms)" (list-ref terms k)))
            (let ((alpha (if (> (aref k k) 0) (- norm) norm)))
              ;; v = x - alpha e1, stored in column k rows k..n-1
              (aset! k k (- (aref k k) alpha))
              (let ((vnorm2 (let loop ((i k) (s 0.0)) (if (= i n) s (loop (+ i 1) (+ s (sq (aref i k))))))))
                (define (reflect! get set)
                  (let ((s (let loop ((i k) (s 0.0)) (if (= i n) s (loop (+ i 1) (+ s (* (aref i k) (get i))))))))
                    (do ((i k (+ i 1))) ((= i n))
                      (set i (- (get i) (/ (* 2 s (aref i k)) vnorm2))))))
                (do ((j (+ k 1) (+ j 1))) ((= j p))
                  (reflect! (lambda (i) (aref i j)) (lambda (i v) (aset! i j v))))
                (reflect! (lambda (i) (vector-ref b i)) (lambda (i v) (vector-set! b i v))))
              (vector-set! rdiag k alpha))))
        ;; back substitution R beta = (Q^T y)[0..p)
        (let ((beta (make-vector p 0.0)))
          (do ((i (- p 1) (- i 1))) ((< i 0))
            (vector-set! beta i (/ (- (vector-ref b i)
                                      (let loop ((j (+ i 1)) (s 0.0)) (if (= j p) s (loop (+ j 1) (+ s (* (r i j) (vector-ref beta j)))))))
                                   (r i i))))
          ;; R^-1 (upper triangular), then (X^T X)^-1 = R^-1 R^-T
          (let ((rinv (make-vector (* p p) 0.0)))
            (do ((j 0 (+ j 1))) ((= j p))
              (vector-set! rinv (+ (* j p) j) (/ 1.0 (r j j)))
              (do ((i (- j 1) (- i 1))) ((< i 0))
                (vector-set! rinv (+ (* i p) j)
                             (/ (- (let loop ((k (+ i 1)) (s 0.0))
                                     (if (> k j) s (loop (+ k 1) (+ s (* (r i k) (vector-ref rinv (+ (* k p) j))))))))
                                (r i i)))))
            (let* ((xtx-inv (list->vector
                             (map (lambda (i)
                                    (list->vector
                                     (map (lambda (j)
                                            (let loop ((k 0) (s 0.0))
                                              (if (= k p) s
                                                  (loop (+ k 1) (+ s (* (vector-ref rinv (+ (* i p) k)) (vector-ref rinv (+ (* j p) k))))))))
                                          (iota p))))
                                  (iota p))))
                   (fitted (map (lambda (row) (lsum (map * row (vector->list beta)))) x))
                   (resid (map - y fitted)))
              (make-lm formula terms beta (list->vector resid) (list->vector fitted) p (- n p)
                       xtx-inv (lmean y) icpt levels n))))))

    (define (lm-coefficients m)
      "Syntax: (lm-coefficients lm)
Library: (scm data tests)
Description: The coefficients as an alist (term name . estimate).
Example:
  (lm-coefficients (lm df '(y ~ x)))"
      (map cons (lm-terms m) (vector->list (lm-coef-vector m))))

    (define (lm-residuals m)
      "Syntax: (lm-residuals lm)
Library: (scm data tests)
Description: The residuals as a list.
Example:
  (lm-residuals fit)"
      (vector->list (lm-residual-vector m)))

    (define (lm-fitted m)
      "Syntax: (lm-fitted lm)
Library: (scm data tests)
Description: The fitted values as a list.
Example:
  (lm-fitted fit)"
      (vector->list (lm-fitted-vector m)))

    (define (lm-summary m)
      "Syntax: (lm-summary lm)
Library: (scm data tests)
Description: The summary of a fit, as R's summary.lm, as an alist:
  coefficients (a frame: term estimate std-error statistic p-value),
  sigma (residual standard error), df, r-squared, adj-r-squared,
  f-statistic, f-df1, f-df2, f-p-value.
Example:
  (cdr (assq 'r-squared (lm-summary fit)))"
      (let* ((res (lm-residuals m))
             (n (lm-n m)) (p (lm-rank m)) (rdf (lm-df-residual m))
             (rss (lsum (map sq res)))
             (sigma2 (/ rss rdf))
             (fitted (lm-fitted m))
             (mss (if (lm-intercept? m)
                      (let ((mf (lmean fitted))) (lsum (map (lambda (f) (sq (- f mf))) fitted)))
                      (lsum (map sq fitted))))
             (df-int (if (lm-intercept? m) 1 0))
             (r2 (/ mss (+ mss rss)))
             (adj (- 1 (* (- 1 r2) (/ (- n df-int) rdf))))
             (fdf1 (- p df-int))
             (fstat (if (> fdf1 0) (/ (/ mss fdf1) sigma2) na))
             (coefs (vector->list (lm-coef-vector m)))
             (ses (map (lambda (i) (sqrt (* sigma2 (vector-ref (vector-ref (lm-xtx-inv m) i) i)))) (iota p)))
             (ts (map / coefs ses))
             (ps (map (lambda (t) (* 2 (pt (abs t) rdf #f))) ts)))
        (list (cons 'coefficients
                    (make-df (list (cons 'term (list->vector (lm-terms m)))
                                   (cons 'estimate (list->vector coefs))
                                   (cons 'std-error (list->vector ses))
                                   (cons 'statistic (list->vector ts))
                                   (cons 'p-value (list->vector ps)))))
              (cons 'sigma (sqrt sigma2))
              (cons 'df rdf)
              (cons 'r-squared r2)
              (cons 'adj-r-squared adj)
              (cons 'f-statistic fstat)
              (cons 'f-df1 fdf1)
              (cons 'f-df2 rdf)
              (cons 'f-p-value (if (na? fstat) na (pf fstat fdf1 rdf #f))))))

    (define (lm->string m)
      "Syntax: (lm->string lm)
Library: (scm data tests)
Description: The summary of a fit as text, in the layout of R's
  print(summary(fit)).
Example:
  (display (lm->string fit))"
      (let* ((s (lm-summary m))
             (get (lambda (k) (cdr (assq k s))))
             (coefs (get 'coefficients))
             (out (open-output-string))
             (stars (lambda (p) (cond ((< p 0.001) "***") ((< p 0.01) "**") ((< p 0.05) "*") ((< p 0.1) ".") (else ""))))
             (rows (map (lambda (i)
                          (list (vector-ref (df-column coefs 'term) i)
                                (signif (vector-ref (df-column coefs 'estimate) i) 5)
                                (signif (vector-ref (df-column coefs 'std-error) i) 5)
                                (signif (vector-ref (df-column coefs 'statistic) i) 4)
                                (let ((p (vector-ref (df-column coefs 'p-value) i)))
                                  (if (< p 2e-16) "<2e-16" (signif p 3)))
                                (stars (vector-ref (df-column coefs 'p-value) i))))
                        (iota (df-nrow coefs))))
             (header '("" "Estimate" "Std. Error" "t value" "Pr(>|t|)" ""))
             (widths (apply map (lambda col (apply max (map string-length col))) (cons header rows)))
             (pad-l (lambda (s n) (string-append s (make-string (- n (string-length s)) #\space))))
             (pad-r (lambda (s n) (string-append (make-string (- n (string-length s)) #\space) s))))
        (define (w . xs) (for-each (lambda (x) (display x out)) xs))
        (w "\nCall:\nlm(formula = ")
        (for-each (lambda (t i) (w (if (> i 0) " " "") (if (symbol? t) (symbol->string t) t))) (lm-formula m) (iota (length (lm-formula m))))
        (w ")\n\nCoefficients:\n")
        (for-each (lambda (row)
                    (w (pad-l (car row) (car widths)))
                    (for-each (lambda (c wd) (w " " (pad-r c wd))) (cdr (take row 5)) (cdr (take widths 5)))
                    (w " " (list-ref row 5) "\n"))
                  (cons header rows))
        (w "---\nSignif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1\n\n")
        (w "Residual standard error: " (signif (get 'sigma) 4) " on " (get 'df) " degrees of freedom\n")
        (w "Multiple R-squared:  " (signif (get 'r-squared) 4) ",\tAdjusted R-squared:  " (signif (get 'adj-r-squared) 4) "\n")
        (unless (na? (get 'f-statistic))
          (w "F-statistic: " (signif (get 'f-statistic) 4) " on " (get 'f-df1) " and " (get 'f-df2) " DF,  p-value: "
             (let ((p (get 'f-p-value))) (if (< p 2.2e-16) "< 2.2e-16" (signif p 4))) "\n"))
        (w "\n")
        (get-output-string out)))

    (define (lm-print m . port)
      "Syntax: (lm-print lm [port])
Library: (scm data tests)
Description: Writes the summary of a fit like R prints summary(fit).
Example:
  (lm-print fit)"
      (display (lm->string m) (if (pair? port) (car port) (current-output-port))))

    (define (predict m d)
      "Syntax: (predict lm df)
Library: (scm data tests)
Description: The predictions of a fit for the rows of df (a vector; na
  where a predictor is na or a factor level is unknown).
Example:
  (predict fit (tibble (wt 3.0) (hp 120)))"
      (let* ((formula (lm-formula m))
             (response (car (formula-lhs formula))))
        (let-values (((icpt cols) (parse-rhs (formula-rhs formula) d response)))
          (let ((beta (vector->list (lm-coef-vector m))))
            (vector-map
             (lambda (i)
               (call/cc
                (lambda (k)
                  (let ((row (append (if icpt '(1.0) '())
                                     (append-map
                                      (lambda (c)
                                        (let ((lv (assq c (lm-levels m))) (v (vector-ref (df-column d c) i)))
                                          (cond ((na? v) (k na))
                                                (lv (unless (member v (cdr lv)) (k na))
                                                    (map (lambda (l) (if (equal? v l) 1.0 0.0)) (cddr lv)))
                                                (else (list (inexact v))))))
                                      cols))))
                    (lsum (map * row beta))))))
             (list->vector (iota (df-nrow d))))))))))

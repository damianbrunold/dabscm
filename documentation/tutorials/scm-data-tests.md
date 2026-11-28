---
title: "(scm data tests): hypothesis tests and linear models"
part: libraries
order: 1036
libraries: (scm data tests)
summary: Comparing two groups with the t-test and the Wilcoxon test, reading the result, tests as data frames; proportions with exact and approximate tests, tables with Fisher's and the chi-squared test; correlation tests; checking normality; many tests at once with p-adjust; linear models with several predictors and predictions; the distributions behind them.
---
# (scm data tests): hypothesis tests and linear models

`(scm data tests)` has the classic tests and linear models of R's `stats`
package, with the same names, defaults and results (they are checked
against R). An analysis written in R can be redone here and give the
same p-values.

```scheme
(import (scheme base) (scheme write) (scm data))

(define (round4 x) (/ (round (* 10000 x)) 10000))
```

## Two groups

Twelve tasters scored the same tea, half of them brewed in a pot, half
from a bag. Is the difference more than chance?

```scheme
(define taste
  (tibble (method "pot" "pot" "pot" "pot" "pot" "pot" "bag" "bag" "bag" "bag" "bag" "bag")
          (score 7.5 8 6.5 8.5 7 9 6 5.5 7 6.5 5 6)))

(define h (t-test taste '(score ~ method)))
(round4 (htest-ref h 'statistic))           ;; => -3.6556
(round4 (htest-ref h 'p-value))             ;; => 0.005
(map round4 (htest-ref h 'conf-int))        ;; => (-2.8275 -0.6725)
```

The formula `score ~ method` reads "score, by method". The test takes a
data frame and a formula, or two lists of numbers. `htest-print` shows
the result as R does:

```text
	Welch Two Sample t-test

data:  score by method
t = -3.6556, df = 9.3077, p-value = 0.004982
alternative hypothesis: true difference in means is not equal to 0
95 percent confidence interval:
 -2.827493 -0.6725073
sample estimates:
mean in group bag mean in group pot
                6              7.75
```

- The p-value of 0.005 says: if the method made no difference, a gap
  this large would turn up in about 1 of 200 such tastings. That is
  usually taken as evidence of a real difference.
- The confidence interval says by how much: the bag scores between 0.7
  and 2.8 points lower. It is often more useful than the p-value.
- The default is Welch's test, which does not assume equal variances, as
  in R. `'var-equal #t` gives the classic pooled test, `'paired #t` the
  paired test for before/after measurements on the same people.

Options are pairs of a symbol and a value, after the data:

```scheme
(round4 (htest-ref (t-test taste '(score ~ method) 'alternative 'less) 'p-value)) ;; => 0.0025
(round4 (htest-ref (t-test (list 3.0 3.5 2.5 4.0 3.0 5.5 3.0 2.0 4.5 3.0) 'mu 3) 'p-value)) ;; => 0.2471
```

The first asks only whether bag scores are *lower* (a one-sided test);
the second whether a mean differs from 3.

Scores are not really measurements on a scale, and twelve tasters are
few. The Wilcoxon rank-sum test assumes less, only that higher means
better:

```scheme
(round4 (htest-ref (wilcox-test taste '(score ~ method)) 'p-value)) ;; => 0.0126
```

## Tests as data frames

`tidy` turns a result into a one-row data frame, so that many tests can
be collected into one table with `bind-rows`, for a report:

```scheme
(df-names (tidy h))
;; => (estimate estimate1 estimate2 statistic p-value parameter conf-low conf-high method alternative)
(df-column (tidy h) 'method)                ;; => #("Welch Two Sample t-test")
```

## Proportions

14 of 20 visitors preferred the new blend. Is that more than half?

```scheme
(define b (binom-test 14 20 0.5))
(round4 (htest-ref b 'p-value))             ;; => 0.1153
(map round4 (htest-ref b 'conf-int))        ;; => (0.4572 0.8811)
(round4 (htest-ref (prop-test 14 20) 'p-value)) ;; => 0.1175
```

70 % sounds clear, but with 20 people it could easily be chance: the
interval reaches down to 46 %. `binom-test` is exact, `prop-test` the
normal approximation; with small numbers prefer the exact test.

## Tables

Does the preference depend on the city? A table of counts:

```scheme
(define tab
  (crosstab '("Zurich" "Zurich" "Bern" "Bern" "Zurich" "Bern" "Zurich" "Bern")
            '("yes" "no" "no" "no" "yes" "yes" "yes" "no")))
(df-print tab)
;; prints: # A data frame: 2 × 3
;; prints:   row        no    yes
;; prints:   <chr>   <int>  <int>
;; prints: 1 Bern        3      1
;; prints: 2 Zurich      1      3

(round4 (htest-ref (fisher-test tab) 'p-value)) ;; => 0.4857
```

Fisher's exact test is right for small 2×2 tables like this one; for
larger tables and larger counts, `chisq-test`. It also tests counts
against expected shares (a goodness-of-fit test):

```scheme
;; 60 sales: do they follow the planned shares of 50, 30 and 20 %?
(round4 (htest-ref (chisq-test '(30 20 10) 'p '(0.5 0.3 0.2)) 'p-value)) ;; => 0.7575
```

## Correlation and normality

```scheme
(define c (cor-test '(70 75 80 85 90 95) '(2 3 3 5 6 8)))
(round4 (htest-ref c 'estimate))            ;; => 0.9704
(round4 (htest-ref c 'p-value))             ;; => 0.0013
(round4 (htest-ref (cor-test '(70 75 80 85 90 95) '(2 3 3 5 6 8) 'method 'spearman) 'estimate)) ;; => 0.9856

(round4 (htest-ref (shapiro-test (list 3.0 3.5 2.5 4.0 3.0 5.5 3.0 2.0 4.5 3.0)) 'p-value)) ;; => 0.3619
```

A Shapiro-Wilk p-value above 0.05 means the data do not contradict a
normal distribution; with few values the test has little power, so look
at a histogram too. `ks-test` compares a sample with a distribution or
two samples with each other; `oneway-test` and `kruskal-test` compare
more than two groups.

## Many tests

Test twenty teas and one will look "significant" by chance at the 5 %
level. `p-adjust` corrects a list of p-values:

```scheme
(define ps '(0.01 0.04 0.03 0.2))
(p-adjust ps 'bonferroni)                   ;; => (0.04 0.16 0.12 0.8)
(map round4 (p-adjust ps 'holm))            ;; => (0.04 0.09 0.09 0.2)
(map round4 (p-adjust ps 'BH))              ;; => (0.04 0.0533 0.0533 0.2)
```

Bonferroni and Holm control the chance of *any* false finding; BH
(Benjamini-Hochberg) the expected *share* of false findings, which keeps
more power when many tests are run.

## Linear models

How does bitterness depend on water temperature and brewing time? `lm`
fits a model with several predictors:

```scheme
(define brews
  (tibble (temp 70 75 80 85 90 95) (minutes 3 2 4 3 5 4) (bitter 2 3 3 5 6 8)))

(define m (lm brews '(bitter ~ temp + minutes)))
(round4 (vector-ref (predict m (tibble (temp 88) (minutes 3))) 0)) ;; => 6.1167
```

`lm-print` writes the summary in R's layout:

```text
Call:
lm(formula = bitter ~ temp + minutes)

Coefficients:
            Estimate Std. Error t value Pr(>|t|)
(Intercept)  -15.778     2.5469  -6.195  0.00847 **
temp         0.26111   0.038356   6.808  0.00648 **
minutes     -0.36111    0.34209  -1.056    0.369
---
Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

Residual standard error: 0.6009 on 3 degrees of freedom
Multiple R-squared:  0.9575,	Adjusted R-squared:  0.9292
F-statistic: 33.81 on 2 and 3 DF,  p-value: 0.008757
```

Each degree adds about 0.26 points of bitterness at a fixed brewing
time; the brewing time has no clear effect in these six brews (p = 0.37).
A text column among the predictors is coded as dummy variables, as in R.
`lm-summary` gives the same numbers as data.

## Distributions

The tests are built on the distributions, which are there as well, with
R's names: `d…` the density, `p…` the cumulative probability, `q…` the
quantile:

```scheme
(round4 (pnorm 1.96))                       ;; => 0.975
(round4 (qnorm 0.975))                      ;; => 1.96
(round4 (qt 0.975 10))                      ;; => 2.2281
(round4 (dbinom 3 10 0.5))                  ;; => 0.1172
(round4 (pchisq 3.84 1))                    ;; => 0.95
```

The F distribution's density is `dF`, not R's `df`, which is what every
script calls its data frame.

## Where next

- [Statistics](scm-data-stats.md), [charts](scm-data-plot.md) to look at
  the data before testing it, [reports](scm-data-report.md).
- Reference: `(scm data tests)`.

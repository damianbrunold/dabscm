# `(scm data tests)`

Distributions and hypothesis tests as in R — t, Wilcoxon, chi-squared, Fisher, lm, …

## Overview

Probability distributions and hypothesis tests that follow R's `stats`
package: the same names, defaults, p-values and confidence intervals (checked
against R). Tests take lists or vectors, or a data frame and a formula such as
`'(extra ~ group)`; options come as `'key value` pairs (`'alternative 'less`,
`'conf-level 0.9`, `'paired #t`, …).

| Area | Procedures |
|---|---|
| Distributions | `dnorm` `pnorm` `qnorm`, `dt` `pt` `qt`, `dchisq` `pchisq` `qchisq`, `dF` `pf` `qf`, `dbeta` `pbeta` `qbeta`, `dbinom` `pbinom` `qbinom`, `dpois` `ppois`, `lgamma`, incomplete gamma and beta |
| Location | `t-test` (one sample, Welch, pooled, paired), `wilcox-test` (exact or normal approximation, as R) |
| Counts | `chisq-test` (contingency table or goodness of fit), `fisher-test` (2×2), `binom-test`, `prop-test` |
| Association | `cor-test` (Pearson, Kendall, Spearman) |
| Distribution | `shapiro-test`, `ks-test` (one and two samples) |
| k groups | `oneway-test` (Welch or classic ANOVA), `kruskal-test` |
| Multiple tests | `p-adjust` (holm, hochberg, bonferroni, BH, BY) |
| Linear models | `lm` (QR; factors dummy-coded), `lm-summary`, `lm-print`, `predict` |

A test returns an `htest`: `htest-print` writes it in R's layout, `htest-ref`
reads one value, `tidy` turns it into a one-row frame like broom's.

`dF` is the F density (R's `df`), renamed so it does not take the name every
script gives its data frame.

## Common uses

```scheme
(define h (t-test sleep '(extra ~ group)))
(htest-print h)                       ; t = -1.8608, df = 17.776, p-value = 0.07939
(htest-ref h 'p-value)
(df-print (tidy (chisq-test (crosstab (df-column d 'a) (df-column d 'b)))))
(lm-print (lm mtcars '(mpg ~ wt + hp)))
(p-adjust ps 'BH)
```


## Exports

### `binom-test`

```
Syntax: (binom-test successes trials option ...)
Library: (scm data tests)
Description: The exact binomial test, as R's binom.test, with the
  Clopper-Pearson confidence interval. Options: 'p 0.5, 'alternative,
  'conf-level 0.95.
Example:
  (binom-test 682 925 'p 0.75)
```

### `chisq-test`

```
Syntax: (chisq-test x [y] option ...)
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
  (chisq-test '((762 327 468) (484 239 477)))
```

### `cor-test`

```
Syntax: (cor-test x y option ...)
Library: (scm data tests)
Description: Test of association, as R's cor.test: 'method pearson
  (t test with Fisher's z confidence interval), kendall (exact below 50
  pairs without ties, else normal with tie correction) or spearman (the
  t approximation, as R with exact = FALSE). Options: 'alternative,
  'conf-level, 'exact 'auto|#f.
Example:
  (cor-test '(1 2 3 4 5) '(2 1 4 3 5))
```

### `dF`

```
Syntax: (dF x df1 df2)
Library: (scm data tests)
Description: The density of the F distribution (dF, not df as in R, so
  that it does not take the usual name of a data frame).
Example:
  (dF 1 5 10) => 0.4954798
```

### `dbeta`

```
Syntax: (dbeta x a b)
Library: (scm data tests)
Description: The density of the beta distribution.
Example:
  (dbeta 0.5 2 2) => 1.5
```

### `dbinom`

```
Syntax: (dbinom k n p)
Library: (scm data tests)
Description: The binomial probability P(X = k) for n trials with success
  probability p.
Example:
  (dbinom 2 4 0.5) => 0.375
```

### `dchisq`

```
Syntax: (dchisq x df)
Library: (scm data tests)
Description: The density of the chi-squared distribution.
Example:
  (dchisq 1 2) => 0.30326532985631671
```

### `dnorm`

```
Syntax: (dnorm x [mean sd])
Library: (scm data tests)
Description: The normal density.
Example:
  (dnorm 0) => 0.3989422804014327
```

### `dpois`

```
Syntax: (dpois k lambda)
Library: (scm data tests)
Description: The Poisson probability P(X = k).
Example:
  (dpois 0 1) => 0.36787944117144233
```

### `dt`

```
Syntax: (dt x df)
Library: (scm data tests)
Description: The density of Student's t distribution.
Example:
  (dt 0 10) => 0.389108383966031
```

### `fisher-test`

```
Syntax: (fisher-test table option ...)
Library: (scm data tests)
Description: Fisher's exact test for a 2x2 table (rows as lists, or a
  frame as for chisq-test), as R's fisher.test: the p-value sums the
  probabilities of tables no more likely than the observed one; the
  estimate is the conditional maximum likelihood odds ratio with its
  exact confidence interval. Options: 'alternative, 'or 1 (odds ratio
  under the null), 'conf-level 0.95.
Example:
  (fisher-test '((3 1) (1 3)))
```

### `htest->string`

```
Syntax: (htest->string htest)
Library: (scm data tests)
Description: The test result as text, in the layout of R's print.htest.
Example:
  (display (htest->string (t-test '(1 2 3 4))))
```

### `htest-alternative`

*(no documentation)*

### `htest-conf-int`

*(no documentation)*

### `htest-conf-level`

*(no documentation)*

### `htest-data-name`

*(no documentation)*

### `htest-estimate`

*(no documentation)*

### `htest-extra`

*(no documentation)*

### `htest-method`

*(no documentation)*

### `htest-null-value`

*(no documentation)*

### `htest-p-value`

*(no documentation)*

### `htest-parameter`

*(no documentation)*

### `htest-print`

```
Syntax: (htest-print htest [port])
Library: (scm data tests)
Description: Writes the test result like R prints it.
Example:
  (htest-print (t-test '(1 2 3 4)))
```

### `htest-ref`

```
Syntax: (htest-ref htest key)
Library: (scm data tests)
Description: One value of a test result: statistic, parameter (a list
  when there are several), p-value, conf-int, conf-level, estimate (a
  list when there are several), null-value, alternative, method, or a
  key of the extra results (e.g. expected for chisq-test).
Example:
  (htest-ref (t-test '(1 2 3 4)) 'p-value)
```

### `htest-statistic`

*(no documentation)*

### `htest?`

*(no documentation)*

### `kruskal-test`

```
Syntax: (kruskal-test df '(y ~ g)) or (kruskal-test samples)
Library: (scm data tests)
Description: The Kruskal-Wallis rank sum test, as R's kruskal.test (with
  the tie correction). samples is a list of lists of numbers.
Example:
  (kruskal-test '((2.9 3.0 2.5 2.6 3.2) (3.8 2.7 4.0 2.4) (2.8 3.4 3.7 2.2 2.0)))
```

### `ks-test`

```
Syntax: (ks-test x y option ...)
Library: (scm data tests)
Description: The Kolmogorov-Smirnov test, as R's ks.test: y is either a
  second sample, or a distribution function (a procedure of one
  argument, e.g. (lambda (q) (pnorm q 0 1))). Exact p-values for one
  sample below 100 values and for two samples with m*n < 10000 (two-sided,
  no ties); otherwise the asymptotic distribution. Options: 'alternative
  two-sided|less|greater, 'exact 'auto|#f.
Example:
  (ks-test '(0.1 -0.4 1.2 0.8 -1.5) pnorm)
```

### `lbeta`

```
Syntax: (lbeta a b)
Library: (scm data tests)
Description: The natural logarithm of the beta function B(a, b).
Example:
  (lbeta 2 3) => -2.4849066497880004 ; log(1/12)
```

### `lchoose`

```
Syntax: (lchoose n k)
Library: (scm data tests)
Description: The natural logarithm of the binomial coefficient n over k.
Example:
  (exp (lchoose 5 2)) => 10.000000000000002
```

### `lgamma`

```
Syntax: (lgamma x)
Library: (scm data tests)
Description: The natural logarithm of the absolute value of the gamma
  function (Lanczos approximation, about 15 digits).
Example:
  (lgamma 5) => 3.1780538303479458 ; log(24)
```

### `lm`

```
Syntax: (lm df formula)
Library: (scm data tests)
Description: Fits a linear model by least squares (Householder QR), as
  R's lm. formula is a list such as (y ~ x1 + x2), (y ~ .) for all other
  columns, with 0 or - 1 to drop the intercept. Non-numeric columns are
  factors, coded against their first level (sorted), named like R's
  (column name followed by the level). Rows with na are dropped. See
  lm-summary, lm-coefficients, predict and tidy.
Example:
  (lm mtcars '(mpg ~ wt + hp))
```

### `lm->string`

```
Syntax: (lm->string lm)
Library: (scm data tests)
Description: The summary of a fit as text, in the layout of R's
  print(summary(fit)).
Example:
  (display (lm->string fit))
```

### `lm-coefficients`

```
Syntax: (lm-coefficients lm)
Library: (scm data tests)
Description: The coefficients as an alist (term name . estimate).
Example:
  (lm-coefficients (lm df '(y ~ x)))
```

### `lm-fitted`

```
Syntax: (lm-fitted lm)
Library: (scm data tests)
Description: The fitted values as a list.
Example:
  (lm-fitted fit)
```

### `lm-print`

```
Syntax: (lm-print lm [port])
Library: (scm data tests)
Description: Writes the summary of a fit like R prints summary(fit).
Example:
  (lm-print fit)
```

### `lm-residuals`

```
Syntax: (lm-residuals lm)
Library: (scm data tests)
Description: The residuals as a list.
Example:
  (lm-residuals fit)
```

### `lm-summary`

```
Syntax: (lm-summary lm)
Library: (scm data tests)
Description: The summary of a fit, as R's summary.lm, as an alist:
  coefficients (a frame: term estimate std-error statistic p-value),
  sigma (residual standard error), df, r-squared, adj-r-squared,
  f-statistic, f-df1, f-df2, f-p-value.
Example:
  (cdr (assq 'r-squared (lm-summary fit)))
```

### `lm?`

*(no documentation)*

### `oneway-test`

```
Syntax: (oneway-test df '(y ~ g) option ...) or (oneway-test samples option ...)
Library: (scm data tests)
Description: Test of equal means in k groups, as R's oneway.test: Welch's
  F test, or the classic one-way ANOVA F test with 'var-equal #t.
  samples is a list of lists of numbers.
Example:
  (oneway-test '((1 2 3) (2 3 4) (5 6 7)) 'var-equal #t)
```

### `p-adjust`

```
Syntax: (p-adjust p-values [method])
Library: (scm data tests)
Description: Adjusts p-values for multiple comparisons, as R's p.adjust:
  holm (default), hochberg, bonferroni, BH (or fdr), BY or none.
  Returns a list in the input order; na stays na.
Example:
  (p-adjust '(0.01 0.02 0.03) 'bonferroni) => (0.03 0.06 0.09)
```

### `pbeta`

```
Syntax: (pbeta q a b [lower?])
Library: (scm data tests)
Description: The distribution function of the beta distribution.
Example:
  (pbeta 0.5 2 3) => 0.6875
```

### `pbeta-regularized`

```
Syntax: (pbeta-regularized x a b [upper?])
Library: (scm data tests)
Description: The regularized incomplete beta function I_x(a, b), or
  1 - I_x(a, b) with upper? #t (computed as I_{1-x}(b, a)).
Example:
  (pbeta-regularized 0.5 2 2) => 0.5
```

### `pbinom`

```
Syntax: (pbinom q n p [lower?])
Library: (scm data tests)
Description: The binomial distribution function P(X <= q); with lower?
  #f P(X > q).
Example:
  (pbinom 2 4 0.5) => 0.6875
```

### `pchisq`

```
Syntax: (pchisq q df [lower?])
Library: (scm data tests)
Description: The distribution function of the chi-squared distribution;
  (pchisq q df #f) is the p-value of a chi-squared statistic.
Example:
  (pchisq 3.841459 1 #f) => 0.05
```

### `pf`

```
Syntax: (pf q df1 df2 [lower?])
Library: (scm data tests)
Description: The distribution function of the F distribution.
Example:
  (pf 4.964603 1 10 #f) => 0.05
```

### `pgamma-regularized`

```
Syntax: (pgamma-regularized a x [upper?])
Library: (scm data tests)
Description: The regularized incomplete gamma function P(a, x), or
  Q(a, x) = 1 - P(a, x) with upper? #t, each computed directly so that
  small tail values keep their precision.
Example:
  (pgamma-regularized 1 1) => 0.6321205588285577
```

### `pnorm`

```
Syntax: (pnorm q [mean sd [lower?]])
Library: (scm data tests)
Description: The normal distribution function P(X <= q); with lower? #f
  the upper tail P(X > q).
Example:
  (pnorm 1.96) => 0.9750021048517795
```

### `ppois`

```
Syntax: (ppois q lambda [lower?])
Library: (scm data tests)
Description: The Poisson distribution function P(X <= q).
Example:
  (ppois 2 1) => 0.9196986029286058
```

### `predict`

```
Syntax: (predict lm df)
Library: (scm data tests)
Description: The predictions of a fit for the rows of df (a vector; na
  where a predictor is na or a factor level is unknown).
Example:
  (predict fit (tibble (wt 3.0) (hp 120)))
```

### `prop-test`

```
Syntax: (prop-test successes trials option ...)
Library: (scm data tests)
Description: The test of equal (or given) proportions, as R's prop.test:
  successes and trials are numbers (one group) or lists (k groups).
  One group gets Wilson's score interval, two groups the interval of the
  difference, both with continuity correction (k <= 2) unless
  'correct #f. Options: 'p (null proportion(s)), 'alternative,
  'conf-level, 'correct.
Example:
  (prop-test '(83 90 129 70) '(86 93 136 82))
```

### `pt`

```
Syntax: (pt q df [lower?])
Library: (scm data tests)
Description: The distribution function of Student's t distribution.
Example:
  (pt 2.228139 10) => 0.975
```

### `qbeta`

```
Syntax: (qbeta p a b [lower?])
Library: (scm data tests)
Description: The quantile function of the beta distribution.
Example:
  (qbeta 0.5 2 2) => 0.5
```

### `qbinom`

```
Syntax: (qbinom p n prob [lower?])
Library: (scm data tests)
Description: The smallest k with P(X <= k) >= p.
Example:
  (qbinom 0.5 10 0.5) => 5
```

### `qchisq`

```
Syntax: (qchisq p df [lower?])
Library: (scm data tests)
Description: The quantile function of the chi-squared distribution.
Example:
  (qchisq 0.95 1) => 3.841458820694124
```

### `qf`

```
Syntax: (qf p df1 df2 [lower?])
Library: (scm data tests)
Description: The quantile function of the F distribution.
Example:
  (qf 0.95 1 10) => 4.9646027437307
```

### `qnorm`

```
Syntax: (qnorm p [mean sd [lower?]])
Library: (scm data tests)
Description: The normal quantile function (Wichura's AS241).
Example:
  (qnorm 0.975) => 1.959963984540054
```

### `qt`

```
Syntax: (qt p df [lower?])
Library: (scm data tests)
Description: The quantile function of Student's t distribution.
Example:
  (qt 0.975 10) => 2.2281388519649385
```

### `shapiro-test`

```
Syntax: (shapiro-test x)
Library: (scm data tests)
Description: The Shapiro-Wilk normality test (Royston's algorithm, as R's
  shapiro.test) for 3 to 5000 values.
Example:
  (shapiro-test '(2.1 3.4 1.9 5.6 4.4 3.3 2.8))
```

### `t-test`

```
Syntax: (t-test x [y] option ...) or (t-test df '(y ~ g) option ...)
Library: (scm data tests)
Description: Student's t test, as R's t.test: one sample (x alone), two
  samples (Welch unless 'var-equal #t), or paired ('paired #t). With a
  frame and a formula (y ~ g), g must have two levels; (y ~ 1) is the
  one-sample test. Options: 'alternative two-sided|less|greater, 'mu 0,
  'paired #f, 'var-equal #f, 'conf-level 0.95. na values are dropped
  (pairwise when paired).
Example:
  (t-test '(0.7 -1.6 -0.2) '(1.9 0.8 1.1) 'var-equal #t)
```

### `tidy`

```
Syntax: (tidy htest-or-lm)
Library: (scm data tests)
Description: A test result as a one-row frame in the style of broom's
  tidy: estimate (for two estimates their difference, then estimate1 and
  estimate2), statistic, p-value, parameter (df1/df2 for two), conf-low,
  conf-high, method and alternative; columns without a value are left
  out. For an lm fit, the coefficient table.
Example:
  (tidy (t-test '(1 2 3 4)))
```

### `wilcox-test`

```
Syntax: (wilcox-test x [y] option ...) or (wilcox-test df '(y ~ g) option ...)
Library: (scm data tests)
Description: The Wilcoxon signed-rank test (x alone, or paired) or rank-sum
  (Mann-Whitney) test, as R's wilcox.test: exact p-values below 50
  observations without ties (and zeros), else the normal approximation
  with tie correction and continuity correction. Options: 'alternative,
  'mu 0, 'paired #f, 'exact 'auto|#t|#f, 'correct #t.
Example:
  (wilcox-test '(1 2 3) '(4 5 6 7))
```


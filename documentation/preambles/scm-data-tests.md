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

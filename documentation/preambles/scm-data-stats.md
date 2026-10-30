## Overview

Descriptive statistics on lists or vectors (`na` skipped): `sum` `mean`
`weighted-mean` `median` `quantile` (R type 7) `var` `sd` (n-1) `iqr`
`value-range` `cumsum` `ranks` `zscore` `cov` `cor` (Pearson or Spearman)
`pct-change` `lm-simple`, and as data frames `freq`, `crosstab` and
`histogram-bins`.

## Common uses

```scheme
(quantile '(1 2 3 4) 0.25)          ;; => 1.75
(cor xs ys 'spearman)
(df-print (freq (df-column cases 'splg) 'by-count))
```

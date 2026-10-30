# `(scm data stats)`

Descriptive statistics — quantiles, correlation, frequency tables, regression

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


## Exports

### `cor`

```
Syntax: (cor xs ys [method])
Library: (scm data stats)
Description: The correlation coefficient; method pearson (default) or
  spearman (Pearson on the average ranks).
Example:
  (cor '(1 2 3 4) '(1 3 2 4)) => 0.8
```

### `cov`

```
Syntax: (cov xs ys)
Library: (scm data stats)
Description: The sample covariance of two equally long lists (pairs with
  a na are skipped).
Example:
  (cov '(1 2 3) '(2 4 6)) => 2.0
```

### `crosstab`

```
Syntax: (crosstab row-values col-values [margins?])
Library: (scm data stats)
Description: A two-way frequency table as a data frame: a column row with
  the distinct row values, then one column per distinct column value
  (named after it) holding counts. With margins? #t a total column and
  a total row are added.
Example:
  (crosstab '(a a b) '(x y x) #t)
```

### `cumsum`

```
Syntax: (cumsum xs)
Library: (scm data stats)
Description: The running sums, as a list; na stays na and is skipped.
Example:
  (cumsum (list 1 2 na 3)) => (1 3 na 6)
```

### `freq`

```
Syntax: (freq xs [sort])
Library: (scm data stats)
Description: A frequency table as a data frame with columns value, n and
  share (fraction); sorted by value, or by descending n with 'by-count.
  na values are counted as their own value.
Example:
  (freq '(a b a)) ; value a b, n 2 1, share 0.667 0.333
```

### `histogram-bins`

```
Syntax: (histogram-bins xs [bins | 'width w])
Library: (scm data stats)
Description: Bins numbers for a histogram: a data frame with columns from,
  to and n (left-closed bins [from, to), the last one closed). The number
  of bins defaults to Sturges' rule; give a count, or 'width w for fixed
  width bins starting at a multiple of w.
Example:
  (histogram-bins '(1 2 2 3 7) 3)
```

### `iqr`

```
Syntax: (iqr xs)
Library: (scm data stats)
Description: The interquartile range, quantile 0.75 minus quantile 0.25.
Example:
  (iqr '(1 2 3 4 5)) => 2
```

### `lm-simple`

```
Syntax: (lm-simple xs ys)
Library: (scm data stats)
Description: Least-squares line y = intercept + slope * x; returns an
  alist ((intercept . a) (slope . b) (r2 . r²) (n . pairs)).
Example:
  (lm-simple '(1 2 3) '(2 4 6)) => ((intercept . 0.0) (slope . 2.0) (r2 . 1.0) (n . 3))
```

### `mean`

```
Syntax: (mean xs)
Library: (scm data stats)
Description: The arithmetic mean (inexact); na if there are no values.
Example:
  (mean #(1 2 3 4)) => 2.5
```

### `median`

```
Syntax: (median xs)
Library: (scm data stats)
Description: The median (middle value, or mean of the two middle values).
Example:
  (median '(3 1 2 10)) => 5/2
```

### `pct-change`

```
Syntax: (pct-change from to)
Library: (scm data stats)
Description: The relative change (to - from) / from as a fraction; na if
  from is 0 or a value is na.
Example:
  (pct-change 200 250) => 0.25
```

### `quantile`

```
Syntax: (quantile xs p)
Library: (scm data stats)
Description: The p-quantile (0 <= p <= 1) with linear interpolation (R's
  type 7, also pandas' default); p may be a list, giving a list.
Example:
  (quantile '(1 2 3 4) 0.25) => 1.75
```

### `ranks`

```
Syntax: (ranks xs [ties])
Library: (scm data stats)
Description: The rank of each value (1 = smallest) as a list; ties is
  average (default, as R's rank), min or dense. na stays na.
Example:
  (ranks '(10 20 10 30)) => (1.5 3 1.5 4)
```

### `sd`

```
Syntax: (sd xs)
Library: (scm data stats)
Description: The sample standard deviation, (sqrt (var xs)).
Example:
  (sd '(2 4 4 4 5 5 7 9)) => 2.138089935299395
```

### `sum`

```
Syntax: (sum xs)
Library: (scm data stats)
Description: The sum of the numbers in the list or vector xs (na skipped).
Example:
  (sum (list 1 2 na 3)) => 6
```

### `value-range`

```
Syntax: (value-range xs)
Library: (scm data stats)
Description: The list (min max) of the numbers, #f if there are none.
Example:
  (value-range (list 3 na 1 7)) => (1 7)
```

### `var`

```
Syntax: (var xs)
Library: (scm data stats)
Description: The sample variance (divided by n-1); na for fewer than 2
  values.
Example:
  (var '(1 2 3 4)) => 1.6666666666666667
```

### `weighted-mean`

```
Syntax: (weighted-mean xs weights)
Library: (scm data stats)
Description: The mean of xs weighted by ws (pairs with a na are skipped).
Example:
  (weighted-mean '(1 3) '(3 1)) => 1.5
```

### `zscore`

```
Syntax: (zscore xs)
Library: (scm data stats)
Description: The standardised values (x - mean) / sd, as a list.
Example:
  (zscore '(1 2 3)) => (-1.0 0.0 1.0)
```


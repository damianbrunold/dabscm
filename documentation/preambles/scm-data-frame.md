## Overview

A data frame is an immutable table of named columns (vectors of equal length),
like an R tibble or a pandas DataFrame. Operations return new frames and share
unchanged columns. Cells are numbers, strings, booleans, dates, symbols, lists
or `na`. A frame may carry grouping columns, set by `group-by`.

## Common uses

```scheme
(define df (tibble (splg 'BEW8 'GYN2) (points 6441 1728)))
(df-print df)                      ; aligned text table with column types
(df-column df 'points)             ;; => #(6441 1728)
(df-row df 0)                      ;; => ((splg . BEW8) (points . 6441))
(alists->df '(((a . 1)) ((a . 2) (b . "x"))))   ; rows as alists
```

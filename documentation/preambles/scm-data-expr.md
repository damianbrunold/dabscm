## Overview

The expression language of the data-frame verbs. A bare symbol names a column;
numbers, strings and quoted data are constants; `,x` splices in a Scheme value
and `(,proc a b)` calls a Scheme procedure per row. Expressions are compiled
once per verb into closures over the row index.

The vocabulary covers arithmetic, comparison (numbers, strings, symbols,
dates), logic, `if`/`case-when`/`in`/`coalesce`, string and date functions,
aggregates (`n` `sum` `mean` `median` `quantile` `sd` …) and window functions
(`lag` `lead` `cumsum` `rank` `share` …). Add functions with
`define-df-function`.

## Common uses

```scheme
(mutate df (share (/ points (sum points)))            ; per group when grouped
           (band (case-when ((< points 10) 'low) ((< points 50) 'mid) (else 'high))))
(define-df-function 'sq 'scalar (lambda (x) (* x x)))
```

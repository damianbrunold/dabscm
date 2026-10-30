# `(scm data expr)`

Column expressions for data-frame verbs — vocabulary and compiler

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


## Exports

### `all-rows`

*(no documentation)*

### `compile-expr`

```
Syntax: (compile-expr df expr)
Library: (scm data expr)
Description: Compiles a column expression against the columns of df into
  a procedure (lambda (i rows) value): the value for row i, with rows the
  vector of row indices of its group (used by aggregates and window
  functions; (all-rows df) when ungrouped). See the library comment for
  the vocabulary.
Example:
  ((compile-expr df '(* pts 2)) 0 (all-rows df))
```

### `define-df-function`

```
Syntax: (define-df-function name kind proc)
Library: (scm data expr)
Description: Adds a function to the expression vocabulary. kind is
  scalar (called per row, returns na if an argument is na), raw (per row,
  gets na unchanged), agg (called with the list of the group's non-na
  values of the first argument plus the other arguments, returns one
  value) or window (called with the vector of the group's values plus the
  other arguments, returns a vector of the same length).
Example:
  (define-df-function 'sq 'scalar (lambda (x) (* x x)))
  (mutate df (pts2 (sq pts)))
```

### `df-function-names`

*(no documentation)*

### `expr-uses-aggregate?`

```
Syntax: (expr-uses-aggregate? expr)
Library: (scm data expr)
Description: True if the expression calls an aggregate function (or (n)).
Example:
  (expr-uses-aggregate? '(/ (sum pts) (n))) => #t
```

### `value<?`

```
Syntax: (value<? a b)
Library: (scm data expr)
Description: Total order used for sorting and grouping: numbers, strings,
  symbols and dates in their natural order, #f before #t; values of
  different types by type; na sorts last.
Example:
  (value<? "a" "b") => #t
```

### `value=?`

*(no documentation)*


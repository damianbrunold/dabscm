## Overview

dplyr/tidyr-style operations. Each is a macro (columns as bare names, Scheme
values via unquote) and a procedure (`df-…`, with quoted expressions). `->`
threads a frame through a pipeline.

| Rows | `where` `arrange` `distinct` `head` `tail` `slice` `sample-n` |
|---|---|
| Columns | `select` `rename` `mutate` `transmute` `relocate` `pull` |
| Groups | `group-by` `ungroup` `summarise` `tally` `add-count` |
| Combining | `left-join` `inner-join` `full-join` `semi-join` `anti-join` `bind-rows` `bind-cols` |
| Reshaping | `pivot-longer` `pivot-wider` `unnest-longer` `separate` |
| Missing | `drop-na` `replace-na` `fill-down` `fill-up` |

## Common uses

```scheme
(-> pts
    (where (in splg ,mfzo-splgs))
    (group-by splg year model)
    (summarise (points (sum points)))
    (pivot-wider (names-from year model) (values-from points))
    (left-join limits (by splg)))
```

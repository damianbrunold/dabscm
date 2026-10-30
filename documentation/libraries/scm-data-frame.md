# `(scm data frame)`

Column-oriented data frames — construction, access, printing

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


## Exports

### `alists->df`

```
Syntax: (alists->df alists [names])
Library: (scm data frame)
Description: A frame from a list of rows given as alists ((key . value) …),
  keys being symbols or strings. Columns are the keys in order of first
  appearance (or the given names); missing keys become na.
Example:
  (df-names (alists->df '(((a . 1)) ((a . 2) (b . 3))))) => (a b)
```

### `data-frame?`

*(no documentation)*

### `df->alists`

```
Syntax: (df->alists df)
Library: (scm data frame)
Description: The rows as a list of alists.
Example:
  (df->alists (tibble (a 1))) => (((a . 1)))
```

### `df->rows`

```
Syntax: (df->rows df)
Library: (scm data frame)
Description: The rows as a list of lists, cells in column order.
Example:
  (df->rows (tibble (a 1 2) (b 3 4))) => ((1 3) (2 4))
```

### `df->string`

```
Syntax: (df->string df [n])
Library: (scm data frame)
Description: The first n rows (default 10) as an aligned text table with
  the column types under the header.
Example:
  (display (df->string (tibble (a 1 2))))
```

### `df-column`

```
Syntax: (df-column df name)
Library: (scm data frame)
Description: The vector of column name (do not mutate it).
Example:
  (df-column (tibble (a 1 2)) 'a) => #(1 2)
```

### `df-column-type`

*(no documentation)*

### `df-columns`

```
Syntax: (df-columns df)
Library: (scm data frame)
Description: The columns as an alist ((name . vector) …).
Example:
  (df-columns (tibble (a 1))) => ((a . #(1)))
```

### `df-drop-columns`

*(no documentation)*

### `df-glimpse`

```
Syntax: (df-glimpse df [port])
Library: (scm data frame)
Description: Prints one line per column: name, type and the first values,
  like dplyr's glimpse.
Example:
  (df-glimpse (tibble (a 1 2)))
```

### `df-groups`

*(no documentation)*

### `df-has-column?`

*(no documentation)*

### `df-head-string`

*(no documentation)*

### `df-names`

*(no documentation)*

### `df-ncol`

*(no documentation)*

### `df-nrow`

*(no documentation)*

### `df-print`

*(no documentation)*

### `df-ref`

```
Syntax: (df-ref df row name)
Library: (scm data frame)
Description: The cell in row i (0-based) of column name.
Example:
  (df-ref (tibble (a 1 2)) 1 'a) => 2
```

### `df-rename-columns`

```
Syntax: (df-rename-columns df renames)
Library: (scm data frame)
Description: Renames columns; renames is an alist ((old . new) …).
Example:
  (df-names (df-rename-columns (tibble (a 1)) '((a . x)))) => (x)
```

### `df-row`

```
Syntax: (df-row df i)
Library: (scm data frame)
Description: Row i (0-based) as an alist ((name . value) …).
Example:
  (df-row (tibble (a 1 2) (b 3 4)) 0) => ((a . 1) (b . 3))
```

### `df-select-columns`

```
Syntax: (df-select-columns df names)
Library: (scm data frame)
Description: A frame with only the given columns, in the given order.
Example:
  (df-names (df-select-columns (tibble (a 1) (b 2)) '(b))) => (b)
```

### `df-set-groups`

```
Syntax: (df-set-groups df names)
Library: (scm data frame)
Description: The same frame grouped by the given columns ('() ungroups).
Example:
  (df-groups (df-set-groups (tibble (a 1)) '(a))) => (a)
```

### `df-take`

```
Syntax: (df-take df indices)
Library: (scm data frame)
Description: A frame with the rows at the given 0-based indices (a vector
  or list), in that order; an index may repeat.
Example:
  (df-column (df-take (tibble (a 10 20 30)) #(2 0)) 'a) => #(30 10)
```

### `df-types`

```
Syntax: (df-types df)
Library: (scm data frame)
Description: The column types as an alist ((name . type) …), see
  column-type in (scm data core).
Example:
  (df-types (tibble (a 1 2) (b "x" na))) => ((a . int) (b . string))
```

### `df-with-column`

```
Syntax: (df-with-column df name values)
Library: (scm data frame)
Description: Adds column name at the end, or replaces it in place. values
  is a vector, a list, or one value recycled to all rows.
Example:
  (df-names (df-with-column (tibble (a 1)) 'b 0)) => (a b)
```

### `df-with-columns`

```
Syntax: (df-with-columns df columns)
Library: (scm data frame)
Description: df-with-column for each (name . values) of an alist.
Example:
  (df-ncol (df-with-columns (tibble (a 1)) '((b . 2) (c . 3)))) => 3
```

### `empty-df`

*(no documentation)*

### `make-df`

```
Syntax: (make-df columns)
Library: (scm data frame)
Description: A frame from an alist of (name . values), values being a
  vector or a list. A single non-list value is recycled to the length of
  the other columns.
Example:
  (df-nrow (make-df '((a . #(1 2 3)) (b . ("x" "y" "z"))))) => 3
```

### `rows->df`

```
Syntax: (rows->df names rows)
Library: (scm data frame)
Description: A frame from a list of rows; each row is a list or vector of
  cells in the order of names. Short rows are filled with na.
Example:
  (df-ref (rows->df '(a b) '((1 "x") (2 "y"))) 1 'b) => "y"
```

### `tibble`

*(no documentation)*


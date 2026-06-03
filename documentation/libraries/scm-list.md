# `(scm list)`

Extended list operations — higher-order, sorting, accessors

## Overview

`(scm list)` is a small grab-bag of list helpers that complement the much larger
SRFI-1 list library. For general higher-order list work (fold, map variants,
filter, take/drop, …) prefer `(srfi 1)`; this library adds a few extras such as
deduplication, partitioning by position, and alist zipping.

## Common uses

Remove duplicates (`uniq` collapses adjacent duplicates, `unique`/`univ` remove
all):

```scheme
(import (scm list))

(uniq   '(a a b b b c))      ;; => (a b c)
(unique '("a" "a" "b" "b"))  ;; => ("a" "b")
```

Split a list into its even- and odd-indexed elements (returns two values):

```scheme
(split '(a b c d e))   ;; => (a c e) and (b d)
```

Zip two lists into an association list:

```scheme
(zip-alist '(1 2 3) '(a b c))   ;; => ((1 . a) (2 . b) (3 . c))
```


## Exports

### `get-property`

```
Syntax: (get-property lst name) (get-property lst name default)
Library: (scm core)
Description: Searches for name in the property list lst. Each element may be a symbol (flag) or a (name value) pair. Returns the value, the symbol itself (for flags), or default/#f if not found.
Example:
  (get-property '((x 1) (y 2)) 'x) => 1
  (get-property '(foo bar) 'foo) => foo
```

### `get-property-list`

```
Syntax: (get-property-list lst name) (get-property-list lst name default)
Library: (scm core)
Description: Searches for name in the property list lst. Returns the cdr of the matching pair (the full value list), or default/#f if not found.
Example:
  (get-property-list '((x 1 2) (y 3)) 'x) => (1 2)
```

### `nil`

*(no documentation)*

### `rest`

```
Syntax: (cdr pair)
Library: (scheme base)
Description: Returns the cdr of pair. It is an error if pair is not a pair.
Example:
  (cdr '((a) b c)) => (b c)
  (cdr '(1 . 2)) => 2
```

### `split`

```
Syntax: (split ls)
Library: (scm list)
Description: Splits a list into two lists: elements at odd positions and elements
at even positions (0-indexed). Returns the two lists as multiple values.
Example:
  (split '(a b c d e)) => (a c e) (b d)
```

### `uniq`

```
Syntax: (uniq list)
Library: (scm list)
Description: Removes consecutive duplicate elements from list using eq? for
comparison. The list should be sorted if all duplicates are to be removed.
Example:
  (uniq '(a a b b b c)) => (a b c)
```

### `unique`

```
Syntax: (unique list)
Library: (scm list)
Description: Removes consecutive duplicate elements from list using equal? for
comparison. The list should be sorted if all duplicates are to be removed.
Example:
  (unique '("a" "a" "b" "b")) => ("a" "b")
```

### `univ`

```
Syntax: (univ list)
Library: (scm list)
Description: Removes consecutive duplicate elements from list using eqv? for
comparison. The list should be sorted if all duplicates are to be removed.
Example:
  (univ '(1 1 2 2 3)) => (1 2 3)
```

### `zip-alist`

```
Syntax: (zip-alist a b)
Library: (scm list)
Description: Combines two lists of equal length into a single association list,
pairing each element from a with the corresponding element from b. Raises an
error if the lists have different lengths.
Example:
  (zip-alist '(1 2 3) '(a b c)) => ((1 . a) (2 . b) (3 . c))
```


## Overview

`(scm csv)` splits a single line of CSV-style text into its fields. It takes the
line and a separator, strips a pair of surrounding double-quotes from each field,
and returns the fields as a **vector**.

## Common uses

```scheme
(import (scm csv))

(csv-line->fields "a,b,c" ",")       ;; => #("a" "b" "c")
(csv-line->fields "\"x\",\"y\",z" ",")  ;; => #("x" "y" "z")
```

Pass the symbol `trim` as a third argument to also trim whitespace from each
field:

```scheme
(csv-line->fields "a, b , c" "," 'trim)   ;; => #("a" "b" "c")
```

It operates on one line at a time and splits purely on the separator, so a
separator character **inside** a quoted field is not treated specially — use a
fuller parser if your data embeds the separator in quoted values.

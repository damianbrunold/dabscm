## Overview

`(scm json)` is a low-level, streaming JSON reader: open a reader over a file or
string, then pull top-level objects from it one at a time. It's well suited to
large inputs or newline-delimited JSON. For parsing a whole document into Scheme
data — and for *writing* JSON — use the higher-level `(scm json simple)`.

## Common uses

```scheme
(import (scm json))

(define r (open-json-string "{\"a\": 1, \"b\": [2, 3]}"))
(json-next-object r)    ;; => the next parsed object, or #f at end
(close-json r)
```

Read from a file with `open-json-file`, and pull successive objects with
`json-next-object` (returns `#f` when exhausted). `json-attribute` reads a named
attribute from a reader.

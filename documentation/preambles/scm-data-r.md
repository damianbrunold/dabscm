## Overview

Translates analysis code between R and `(scm data)`, best effort, in both
directions. It covers the common subset of the tidyverse: pipes (`%>%`, `|>`),
the dplyr and tidyr verbs, readr/readxl/writexl/sf input and output, ggplot2
chains (geoms, `labs`, scales, facets, maps with `geom_sf`), the stats tests
and `lm`.

- **R → Scheme**: `r->scm-string` (or `r-file->scm`) parses R with its real
  grammar (precedence, newlines, named arguments, formulas, functions) and maps
  pipes to `->`, verbs to verbs and ggplot `+` chains to `ggplot` forms. Inside
  verbs a name is a column unless the script assigned it, then it is spliced in
  with unquote. What has no counterpart is marked `(r:unsupported "…")` inline
  or `;; TODO (R): …` for a whole statement or step, and listed as the second
  value; the translation never fails.
- **Scheme → R**: `scm->r-string` (or `scm-file->r`) writes pipe-style R with
  the `library()` calls it needs; values unquoted into verb expressions become
  `!!`, reports become R Markdown (`report->rmd`). Unknown forms become R calls
  with R-style names, or `stop("TODO scheme: …")`.

`r-parse`/`r-deparse` give access to the R syntax tree, `scm-pretty` to the
code printer.

## Common uses

```scheme
(import (scm data r))

(let-values (((code unsupported) (r-file->scm "analysis.R")))
  (display code))
(display (scm-file->r "analysis.scm"))
```

From the shell: `scm examples/r-convert.scm analysis.R` (or `analysis.scm`).

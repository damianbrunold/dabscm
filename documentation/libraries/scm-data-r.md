# `(scm data r)`

Translating analysis code between R (tidyverse) and (scm data), both ways

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


## Exports

### `r->scm`

```
Syntax: (r->scm r-source)
Library: (scm data r)
Description: Translates R source text (or a list of R syntax trees from
  r-parse) to (scm data) code: returns two values, the list of top-level
  forms (an import first; comments as (:comment text), see scm-pretty)
  and the list of R snippets that had no translation. See
  r->scm-string for text.
Example:
  (r->scm "d <- read_csv('a.csv') |> filter(x > 1)")
```

### `r->scm-string`

```
Syntax: (r->scm-string r-source)
Library: (scm data r)
Description: Translates R source text to (scm data) code as text,
  pretty-printed; returns two values, the text and the list of R snippets
  without a translation (also marked in the text as TODO or
  r:unsupported).
Example:
  (r->scm-string "mtcars |> group_by(cyl) |> summarise(m = mean(mpg))")
```

### `r-deparse`

```
Syntax: (r-deparse tree)
Library: (scm data r)
Description: R source text of an R syntax tree as r-parse returns it (one
  line; parentheses added where precedence needs them).
Example:
  (r-deparse (car (r-parse "f(x = 1) + 2"))) => "f(x = 1) + 2"
```

### `r-file->scm`

```
Syntax: (r-file->scm path)
Library: (scm data r)
Description: r->scm-string on the contents of an R script.
Example:
  (r-file->scm "analysis.R")
```

### `r-parse`

```
Syntax: (r-parse text)
Library: (scm data r)
Description: Parses R source text into a list of statements, as R syntax
  trees: numbers, strings, #t/#f and symbols as themselves, calls as
  (:call f (name . argument) …) — operators too, as R sees them, e.g.
  x + 1 is (:call + (#f . x) (#f . 1)) — and functions as (:function
  ((parameter . default) …) body).
Example:
  (r-parse "x <- 1 + 2") => ((:call <- (#f . x) (#f . (:call + (#f . 1) (#f . 2)))))
```

### `report->rmd`

```
Syntax: (report->rmd report-form)
Library: (scm data r)
Description: R Markdown text for a report written as a (report …) form
  (as data): the title in the YAML header, headings and text as
  Markdown, tables as knitr::kable chunks and figures as chunks printing
  the plot.
Example:
  (report->rmd '(report (title "T") (h2 "A") (p "text") (table ,df)))
```

### `scm->r`

```
Syntax: (scm->r forms)
Library: (scm data r)
Description: Translates (scm data) code, a list of top-level forms (or a
  string to read them from), to R: returns two values, the list of R
  statements as R syntax trees (comments as (:comment text)) and the
  library names they need.
Example:
  (scm->r '((define d (-> (read-csv "a.csv") (where (> x 1))))))
```

### `scm->r-string`

```
Syntax: (scm->r-string forms)
Library: (scm data r)
Description: Translates (scm data) code (a list of forms, or Scheme
  source text) to R source text: library() calls for what it uses, then
  the statements, pipes and ggplot chains broken over lines.
Example:
  (display (scm->r-string "(define d (-> (read-csv \"a.csv\") (where (> x 1))))"))
```

### `scm-file->r`

```
Syntax: (scm-file->r path)
Library: (scm data r)
Description: scm->r-string on the forms of a Scheme file.
Example:
  (display (scm-file->r "analysis.scm"))
```

### `scm-pretty`

```
Syntax: (scm-pretty datum [indent])
Library: (scm data r)
Description: A Scheme datum as code text, broken over lines and indented
  where it does not fit in 80 columns; (:comment text) as ;; comment
  lines (where a list breaks) or #| |# (inside a line).
Example:
  (display (scm-pretty '(define x (-> df (where (> a 1)) (mutate (b (* a 2)))))))
```


---
title: "(scm data r): translating between R and (scm data)"
part: libraries
order: 1041
libraries: (scm data r)
summary: Translating a tidyverse script to (scm data), how columns and script variables are told apart, what cannot be translated and how it is marked, translating Scheme analyses back to R, R syntax trees, reports as R Markdown, the r-convert script.
---
# (scm data r): translating between R and (scm data)

Many analyses exist as R scripts, and many readers know R. `(scm data
r)` translates the common tidyverse subset in both directions: dplyr
and tidyr verbs, pipes, readr/readxl input and output, ggplot2 charts,
the classic tests and `lm`. It is imported on its own, not through
`(scm data)`.

```scheme
(import (scheme base) (scheme write) (scm data r))
```

## R to Scheme

`r->scm-string` returns two values: the Scheme program and the list of
what it could not translate.

```scheme
(define r-script "library(dplyr)
sales <- read_csv(\"sales.csv\")
min_kg <- 2
per_shop <- sales %>%
  filter(kg >= min_kg, shop != \"Basel\") %>%
  group_by(shop) %>%
  summarise(n = n(), kg = sum(kg)) %>%
  arrange(desc(kg))
ggplot(per_shop, aes(x = shop, y = kg)) + geom_col() + labs(title = \"Kilograms\")
t.test(score ~ method, data = taste)
")

(define-values (scm-code unsupported) (r->scm-string r-script))
(display scm-code)
;; prints: ;; translated from R by (scm data r)
;; prints: (import (scheme base) (scheme write) (srfi 1) (scm data))
;; prints: (define sales (read-csv "sales.csv"))
;; prints: (define min_kg 2)
;; prints: (define per_shop
;; prints:   (-> sales
;; prints:       (where (>= kg ,min_kg) (!= shop "Basel"))
;; prints:       (group-by shop)
;; prints:       (summarise (n (n)) (kg (sum kg)))
;; prints:       (arrange (desc kg))))
;; prints: (save-plot (ggplot per_shop
;; prints:                    (aes (x shop) (y kg))
;; prints:                    (geom-col)
;; prints:                    (labs (title "Kilograms")))
;; prints:            "plot.png")
;; prints: (htest-print (t-test taste '(score ~ method)))
unsupported                                 ;; => ()
```

- **Pipes:** `%>%` and `|>` become `->`, `filter` becomes `where`.
- **Charts:** a ggplot `+` chain becomes one `ggplot` form, saved to a
  file because a script has no plot window.
- **Tests:** print as in R.
- **Names:** stay as they are (`per_shop`); R's dots become valid
  Scheme names.

Inside a verb, R looks a name up among the columns first, then among the
script's variables. The translation decides once: `min_kg` was assigned
in the script, so it is a value and gets the comma; `kg` and `shop`
were not, so they are columns.

## What does not translate

Whatever has no counterpart is marked, never dropped, and the
translation always produces a program:

```scheme
(define-values (code2 todo) (r->scm-string "x <- sapply(1:10, function(i) i^2)\ndf %>% mutate(m = rollmean(v, 3))"))
todo                                        ;; => ("sapply(1:10, function(i) i^2)" "rollmean(v, 3)")
```

In the code, an unsupported expression appears as `(r:unsupported
"…")` at its place, and a whole statement as a `;; TODO (R): …`
comment, so the result runs up to the first gap and shows what is left
to port by hand.

## Scheme to R

`scm->r-string` goes the other way, writing pipe-style R with the
`library` calls it needs. It takes the program as text or as data:

```scheme
(display (scm->r-string "(define per-shop (-> sales (where (>= kg ,min-kg)) (group-by shop) (summarise (kg (sum kg))) (arrange (desc kg))))"))
;; prints: # translated from Scheme by (scm data r)
;; prints: library(dplyr)
;; prints:
;; prints: per_shop <- sales |>
;; prints:   filter(kg >= min_kg) |>
;; prints:   group_by(shop) |>
;; prints:   summarise(kg = sum(kg)) |>
;; prints:   arrange(desc(kg))
```

A value spliced into an expression becomes the variable when it is a
name, as above, and `!!` (dplyr's own unquote) when it is an expression.
Reports become R Markdown with `report->rmd`. This is the way to hand
an analysis to colleagues who work in R, or to check a result against
R.

## Files and the command line

`r-file->scm` and `scm-file->r` translate files. The script
`examples/r-convert.scm` in the dabscm repository does it from the shell,
choosing the direction from the extension:

```sh
scm examples/r-convert.scm analysis.R        # writes the Scheme version to standard output
scm examples/r-convert.scm analysis.scm      # writes R
```

## The R syntax tree

The translator parses R with its real grammar (precedence, newlines,
named arguments, formulas, functions). `r-parse` gives the tree, for
tools of your own, and `r-deparse` writes R from a tree:

```scheme
(r-parse "a <- b + 2 * c")
;; => ((:call <- (#f . a) (#f :call + (#f . b) (#f :call * (#f . 2) (#f . c)))))
(display (r-deparse (car (r-parse "f(x, y = 2)"))))
;; prints: f(x, y = 2)
```

`r-parse` returns the list of statements. A call is `(:call function
argument …)`; each argument is a pair of its name (`#f` when positional)
and its value.

## Where next

- [Data frames](scm-data.md) and the other `(scm data)` chapters for what
  the translated code does.
- Reference: `(scm data r)`.

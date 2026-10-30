# `(scm data report)`

Reports with tables and charts rendered to HTML and Markdown

## Overview

Reports as data: `report` quasiquotes a list of blocks (title, headings,
paragraphs with inline markup, lists, notes, code, tables from data frames and
figures from plots), rendered to a self-contained HTML page (light and dark
theme, inline SVG charts, table of contents) or to GitHub-flavoured Markdown
with the figures written as PNG or SVG files next to it.

## Common uses

```scheme
(write-report
  (report (title "MFZO v1 vs v2") (date)
          (h2 "Points")
          (p "Totals rise by " (b ,(fmt-pct-change a b)) ".")
          (table ,per-splg (columns (splg "SPLG") (v1 "2024 v1" num)) (total-row))
          (figure ,plot (caption "Points per SPLG")))
  "report.html")                    ; or "report.md"
```


## Exports

### `make-report`

```
Syntax: (make-report blocks)
Library: (scm data report)
Description: A report from a list of blocks (the procedure behind the
  report macro).
Example:
  (make-report (list '(title "Hello") (list 'table df)))
```

### `report`

*(no documentation)*

### `report->html`

```
Syntax: (report->html report [toc?])
Library: (scm data report)
Description: The report as one self-contained HTML page (string): inline
  CSS with a light and a dark theme, charts as inline SVG, and a table of
  contents of the h2 headings when there are at least three (toc? #f to
  leave it out).
Example:
  (report->html doc)
```

### `report->markdown`

```
Syntax: (report->markdown report [figure-writer])
Library: (scm data report)
Description: The report as GitHub-flavoured Markdown (string). Figures are
  passed to figure-writer, (lambda (plot number) …) returning the image
  path to link (write-report sets one up that writes PNG files); without
  one, figures become a placeholder line.
Example:
  (report->markdown doc)
```

### `write-report`

```
Syntax: (write-report report path [figure-format])
Library: (scm data report)
Description: Writes the report to path, as HTML (.html) or Markdown (.md).
  For Markdown, figures are written next to the file as
  <name>-fig<n>.png (figure-format png, the default) or .svg, and linked.
Example:
  (write-report doc "report.html")
  (write-report doc "report.md" 'svg)
```


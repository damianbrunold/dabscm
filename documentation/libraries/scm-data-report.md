# `(scm data report)`

Reports with tables and charts rendered to HTML, Markdown and PDF

## Overview

Reports as data: `report` quasiquotes a list of blocks (title, headings,
paragraphs with inline markup, lists, notes, code, tables from data frames and
figures from plots), rendered to a self-contained HTML page (light and dark
theme, inline SVG charts, table of contents), to GitHub-flavoured Markdown
with the figures written as PNG or SVG files next to it, or to PDF
(`report->pdf`): A4 pages with embedded fonts, tables whose header repeats
after a page break, figures as vector graphics, the headings as bookmarks and
a footer with the title and page numbers.

## Common uses

```scheme
(write-report
  (report (title "MFZO v1 vs v2") (date)
          (h2 "Points")
          (p "Totals rise by " (b ,(fmt-pct-change a b)) ".")
          (table ,per-splg (columns (splg "SPLG") (v1 "2024 v1" num)) (total-row))
          (figure ,plot (caption "Points per SPLG")))
  "report.html")                    ; or "report.md", "report.pdf"
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

### `report->pdf`

```
Syntax: (report->pdf report [options])
Library: (scm data report)
Description: The report as a PDF document (bytevector): A4 pages with the
  text in embedded fonts, tables (header repeated after a page break,
  wide tables wrapped), figures as vector graphics, h1–h3 as bookmarks
  and a footer with the title and page numbers. options is an alist:
  (page-size . (w . h)) in points (pdf-page-size-a4 by default, see
  (scm pdf)), (margin . pt) 56, (font-size . pt) 10, (font . family) a
  family found by (scm fonts) for the text and the figures, DejaVu Sans
  by default, (mono-font . family) for code, (footer . #f) to leave the
  footer out.
Example:
  (call-with-port (open-binary-output-file "r.pdf")
    (lambda (o) (write-bytevector (report->pdf doc) o)))
```

### `write-report`

```
Syntax: (write-report report path [figure-format])
Library: (scm data report)
Description: Writes the report to path, as HTML (.html), Markdown (.md)
  or PDF (.pdf, see report->pdf). For Markdown, figures are written next
  to the file as
  <name>-fig<n>.png (figure-format png, the default) or .svg, and linked.
Example:
  (write-report doc "report.html")
  (write-report doc "report.md" 'svg)
```


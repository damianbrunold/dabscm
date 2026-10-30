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

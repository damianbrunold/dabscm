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

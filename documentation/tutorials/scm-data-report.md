---
title: "(scm data report): reports in HTML, Markdown and PDF"
part: libraries
order: 1039
libraries: (scm data report)
summary: A report as data with titles, paragraphs, inline markup, lists, notes, tables from data frames with labelled and formatted columns and total rows, and charts as figures; blocks built conditionally; the same report as a self-contained HTML page, as Markdown with image files, and as a paginated PDF; a monthly report script.
---
# (scm data report): reports in HTML, Markdown and PDF

The last step of an analysis is a document for people. `(scm data
report)` describes a report as data (headings, text, tables from data
frames, charts) and renders the same description as an HTML page,
Markdown or PDF.

```scheme
(import (scheme base) (scheme file) (scheme write) (only (srfi 13) string-contains)
        (scm fs) (scm data))

(define per-shop
  (tibble (shop "Zurich" "Bern" "Basel")
          (kg 384.5 124 72)
          (share 0.66 0.21 0.12)))

(define chart (ggplot per-shop (aes (x shop) (y kg)) (geom-col) (labs (x #f) (y "kg"))))
```

## A report

`report` quasiquotes its blocks, so computed values, frames and charts
come in with unquote:

```scheme
(define r
  (report
   (title "Sales March 2025")
   (date "2025-04-01")
   (h2 "Summary")
   (p "Zurich sold " (b ,(fmt-num 384.5)) " kg, " (i "two thirds") " of the total.")
   (table ,per-shop
          (columns (shop "Shop") (kg "Kilograms" num) (share "Share" pct))
          (total-row "Total" (kg)))
   (figure ,chart (caption "Kilograms per shop"))
   (ul "Zurich up" "Basel new")
   (note "Preliminary figures.")))
```

As Markdown, the structure is easy to see:

```scheme
(display (report->markdown r))
;; prints: # Sales March 2025
;; prints:
;; prints: 2025-04-01
;; prints:
;; prints: ## Summary
;; prints:
;; prints: Zurich sold **385** kg, *two thirds* of the total.
;; prints:
;; prints: | Shop | Kilograms | Share |
;; prints: |---|---:|---:|
;; prints: | Zurich | 385 | 66 % |
;; prints: | Bern | 124 | 21 % |
;; prints: | Basel | 72 | 12 % |
;; prints: | **Total** | **581** |  |
;; prints:
;; prints: *[Figure 1]*
;; prints:
;; prints: *Figure 1: Kilograms per shop*
;; prints:
;; prints: - Zurich up
;; prints: - Basel new
;; prints:
;; prints: > Preliminary figures.
;; prints:
```

- **Blocks:** `title`, `subtitle`, `date` (today without an argument),
  `h1`–`h3`, `p`, `ul`, `ol`, `note`, `pre`, `hr`, `page-break`,
  `table`, `figure`.
- **Inline:** strings, numbers, `b`, `i`, `code`, `(link url text)`,
  `br`.
- **Table columns:** a label and a format, here `num` (thousands
  separators) and `pct`. The others are `int`, `pct1`, `dec1`, `dec2`,
  `text`, or any procedure such as `(lambda (x) (fmt-num x 2))`.
- **Total row:** sums the named columns, or the numeric ones without a
  percent format. `(max-rows n)` cuts long tables.
- **Markdown figures:** without a place for image files, a figure is a
  placeholder; `write-report` writes the images (below).

## Blocks built in code

`,@` splices a list of blocks, for parts that depend on the data:

```scheme
(define (warnings frame)
  (let ((low (where frame (< kg 100))))
    (if (zero? (df-nrow low))
        '()
        `((h2 "Attention")
          (p ,(number->string (df-nrow low)) " shop(s) sold less than 100 kg.")))))

(define r2 (report (title "Check") ,@(warnings per-shop)))
(and (string-contains (report->markdown r2) "1 shop(s) sold less than 100 kg.") #t) ;; => #t
(report->markdown (report (title "Check") ,@(warnings (where per-shop (> kg 100)))))
;; => "# Check\n\n"
```

## HTML, Markdown, PDF

`write-report` picks the format by the file extension:

```scheme
(define dir (mktempdir '(prefix . "report")))
(write-report r (join-path dir "march.html"))
(write-report r (join-path dir "march.md"))
(write-report r (join-path dir "march.pdf"))

(map (lambda (f) (file-exists? (join-path dir f))) '("march.html" "march.md" "march-fig1.png" "march.pdf"))
;; => (#t #t #t #t)
```

- **HTML** is one self-contained page: the CSS (with a dark theme)
  and the charts as inline SVG are inside, so the file can be mailed or
  put on a share as it is. With three or more `h2` headings it gets a
  table of contents.
- **Markdown** links its figures as image files next to it
  (`march-fig1.png`; pass `'svg` for SVG). Good for a wiki or a Git
  repository.
- **PDF** has A4 pages, embedded fonts, tables whose header repeats on
  every page, charts as vector graphics, bookmarks for the headings and
  a footer with the title and page numbers. `report->pdf` takes options
  for the page size, margins, font size and font.

The same renderers are there as procedures returning strings or bytes,
for a web server that answers with a report:

```scheme
(define page (report->html r))
(substring page 0 15)                       ;; => "<!DOCTYPE html>"
(and (string-contains page "<svg") #t)      ;; => #t
(utf8->string (bytevector-copy (report->pdf r) 0 5)) ;; => "%PDF-"
(rm dir 'recursive)
```

## Example: a monthly report script

A script that a scheduled job runs on the first of each month: read the
month's sales, summarise them, write the report. The analysis is
ordinary verbs; the report only arranges the results.

```scheme no-test
(import (scheme base) (scheme process-context) (scm data))

(define month (or (and (pair? (cdr (command-line))) (cadr (command-line))) "2025-03"))
(define sales (read-csv (string-append "exports/sales-" month ".csv")))

(define per-shop
  (-> sales
      (group-by shop)
      (summarise (kg (sum kg)) (revenue (sum (* kg price))))
      (mutate (share (/ revenue (sum revenue))))
      (arrange (desc revenue))))

(define per-day
  (-> sales (group-by date) (summarise (revenue (sum (* kg price))))))

(write-report
 (report
  (title "Sales " ,month)
  (date)
  (p "Revenue: " (b ,(fmt-num (sum (df-column per-shop 'revenue)))) " CHF.")
  (h2 "Shops")
  (table ,per-shop (columns (shop "Shop") (kg "kg" dec1) (revenue "CHF" num) (share "Share" pct))
         (total-row "Total" (kg revenue)))
  (h2 "Days")
  (figure ,(ggplot per-day (aes (x date) (y revenue)) (geom-line) (labs (x #f) (y "CHF")))))
 (string-append "reports/sales-" month ".pdf"))
```

## Where next

- [Charts](scm-data-plot.md), [statistics and formatting](scm-data-stats.md),
  [data frames](scm-data.md).
- [Markdown](scm-markdown.md), [PDF](scm-pdf.md) and [Word](scm-word.md)
  for documents built by hand.
- `(scm data r)` turns a report into R Markdown: [R translation](scm-data-r.md).
- Reference: `(scm data report)`.

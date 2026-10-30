(define-library (scm data report)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (srfi 1)
          (srfi 13)
          (scm fs)
          (scm html builder)
          (scm datetime)
          (scm data core)
          (scm data format)
          (scm data frame)
          (scm data plot)
          (scm pdf)
          (scm svg pdf)
          (scm truetype)
          (scm fonts)
          (scm fonts dejavu))
  (export report
          make-report
          report->html
          report->markdown
          report->pdf
          write-report)
  (begin

    ;; ================================================================
    ;; (scm data report) — reports as data, rendered to a self-contained
    ;; HTML page, to Markdown or to PDF. A report quasiquotes its blocks, so
    ;; computed values, frames and plots come in with unquote:
    ;;
    ;;   (report
    ;;     (title "MFZO v1 vs v2") (subtitle "ZH hospitals") (date)
    ;;     (h2 "Points")
    ;;     (p "Totals rise by " (b ,(fmt-pct-change a b)) ".")
    ;;     (table ,per-splg (columns (splg "SPLG") (v1 "2024 v1" num) …) (total-row))
    ;;     (figure ,plot (caption "Points per SPLG"))
    ;;     (ul "first" "second"))
    ;;
    ;; ,@ splices a list of blocks in (e.g. ones built conditionally).
    ;; Blocks: (title s) (subtitle s) (date [s]) (h1 …) (h2 …) (h3 …)
    ;;   (p …) (ul item …) (ol item …) (note …) (pre "text") (hr)
    ;;   (page-break) (table df option …) (figure plot option …)
    ;; Inline: strings, numbers, (b …) (i …) (code s) (link url text …) (br)
    ;; table options: (columns (col [label [format [align]]]) …) with
    ;;   format a procedure or num, int, pct, pct1, dec1, dec2, text;
    ;;   (total-row [label] [(col …)]) sums the given columns (default: the
    ;;   numeric ones without a percent format); (max-rows n);
    ;;   (caption s). Numbers are right-aligned, integers get thousands
    ;;   separators, other reals one decimal.
    ;; figure options: (caption s) (alt s)
    ;; ================================================================

    (define-syntax report
      (syntax-rules ()
        ((_ block ...) (make-report (quasiquote (block ...))))))

    (define (make-report blocks)
      "Syntax: (make-report blocks)
Library: (scm data report)
Description: A report from a list of blocks (the procedure behind the
  report macro).
Example:
  (make-report (list '(title \"Hello\") (list 'table df)))"
      (cons 'report blocks))

    (define (blocks doc)
      (if (and (pair? doc) (eq? (car doc) 'report)) (cdr doc) (error "not a report" doc)))

    (define (opt opts key dflt)
      (let ((o (find (lambda (o) (and (pair? o) (eq? (car o) key))) opts)))
        (if o (if (null? (cdr o)) #t (cadr o)) dflt)))

    (define (opt-all opts key)
      (let ((o (find (lambda (o) (and (pair? o) (eq? (car o) key))) opts)))
        (and o (cdr o))))

    (define (today-string)
      (fmt-date (string->day (today))))

    ;; --- tables ------------------------------------------------------

    ;; -> (values headers rows aligns), all cells as strings
    (define (table-cells df opts)
      (let* ((specs (or (opt-all opts 'columns)
                        (map list (df-names df))))
             (specs (map (lambda (s) (if (symbol? s) (list s) s)) specs))
             (names (map car specs))
             (cols (map (lambda (n) (df-column df n)) names))
             (types (map column-type cols))
             (fmts (map (lambda (s c t) (column-formatter (and (> (length s) 2) (caddr s)) c t)) specs cols types))
             (aligns (map (lambda (s t) (cond ((> (length s) 3) (cadddr s))
                                              ((memq t '(int real)) 'right)
                                              (else 'left)))
                          specs types))
             (headers (map (lambda (s) (if (> (length s) 1) (fmt-value (cadr s)) (symbol->string (car s)))) specs))
             (n (df-nrow df))
             (max-rows (opt opts 'max-rows #f))
             (shown (if (and max-rows (> n max-rows)) max-rows n))
             (rows (list-tabulate shown (lambda (i) (map (lambda (c f) (f (vector-ref c i))) cols fmts))))
             (total (opt-all opts 'total-row))
             (total-label (if (and (pair? total) (string? (car total))) (car total) "Total"))
             ;; summed columns: as given, else the numeric ones without a percent format
             (summed (cond ((and (pair? total) (find list? total)) => (lambda (l) l))
                           (else (filter-map (lambda (s t) (and (memq t '(int real))
                                                                (not (memq (and (> (length s) 2) (caddr s)) '(pct pct1)))
                                                                (car s)))
                                             specs types))))
             (rows (if total
                       (append rows
                               (list (map (lambda (name c f j)
                                            (cond ((memq name summed)
                                                   (f (fold (lambda (x s) (if (real? x) (+ s x) s)) 0 (vector->list c))))
                                                  ((= j 0) total-label)
                                                  (else "")))
                                          names cols fmts (iota (length cols)))))
                       rows)))
        (values headers rows aligns (and total #t) (and max-rows (> n max-rows) (- n max-rows)))))

    (define (column-formatter spec col type)
      (cond ((procedure? spec) (lambda (x) (if (na? x) "" (fmt-value (spec x)))))
            ((eq? spec 'num) (lambda (x) (if (na? x) "" (fmt-num x 0))))
            ((eq? spec 'int) (lambda (x) (if (na? x) "" (fmt-int x))))
            ((eq? spec 'dec1) (lambda (x) (if (na? x) "" (fmt-num x 1))))
            ((eq? spec 'dec2) (lambda (x) (if (na? x) "" (fmt-num x 2))))
            ((eq? spec 'pct) (lambda (x) (if (na? x) "" (fmt-pct x 0))))
            ((eq? spec 'pct1) (lambda (x) (if (na? x) "" (fmt-pct x 1))))
            ((eq? spec 'text) (lambda (x) (if (na? x) "" (fmt-value x))))
            ((eq? type 'int) (lambda (x) (if (na? x) "" (fmt-int x))))
            ((eq? type 'real)
             (let ((whole? (every (lambda (x) (or (na? x) (integer? x))) (vector->list col))))
               (lambda (x) (cond ((na? x) "") ((integer? x) (fmt-num x (if whole? 0 1))) (else (fmt-num x 1))))))
            (else (lambda (x) (if (na? x) "" (fmt-value x))))))

    ;; --- HTML --------------------------------------------------------

    (define (inline->sxml x)
      (cond ((string? x) x)
            ((number? x) (fmt-value x))
            ((symbol? x) (symbol->string x))
            ((na? x) (na-string))
            ((not (pair? x)) (fmt-value x))
            (else
             (case (car x)
               ((b) `(strong ,@(map inline->sxml (cdr x))))
               ((i) `(em ,@(map inline->sxml (cdr x))))
               ((code) `(code ,@(map inline->sxml (cdr x))))
               ((br) '(br))
               ((link) `(a (@ (href ,(cadr x))) ,@(map inline->sxml (if (null? (cddr x)) (list (cadr x)) (cddr x)))))
               (else (fmt-value x))))))

    (define (slug s)
      (let ((t (string-map (lambda (c) (if (or (char-alphabetic? c) (char-numeric? c)) (char-downcase c) #\-))
                           s)))
        (string-trim-both t #\-)))

    (define (inline-text x)
      (cond ((string? x) x)
            ((pair? x) (if (eq? (car x) 'link)
                           (string-concatenate (map inline-text (if (null? (cddr x)) (list (cadr x)) (cddr x))))
                           (string-concatenate (map inline-text (cdr x)))))
            (else (fmt-value x))))

    (define (block->sxml b fig-no)
      (case (car b)
        ((title) `(h1 (@ (class "title")) ,@(map inline->sxml (cdr b))))
        ((subtitle) `(p (@ (class "subtitle")) ,@(map inline->sxml (cdr b))))
        ((date) `(p (@ (class "date")) ,(if (pair? (cdr b)) (inline->sxml (cadr b)) (today-string))))
        ((h1 h2 h3)
         (let ((text (string-concatenate (map inline-text (cdr b)))))
           `(,(car b) (@ (id ,(slug text))) ,@(map inline->sxml (cdr b)))))
        ((p) `(p ,@(map inline->sxml (cdr b))))
        ((note) `(aside (@ (class "note")) ,@(map inline->sxml (cdr b))))
        ((pre) `(pre ,@(map (lambda (x) (if (string? x) x (fmt-value x))) (cdr b))))
        ((hr) '(hr))
        ((page-break) '(div (@ (class "page-break"))))
        ((ul ol) `(,(car b) ,@(map (lambda (item)
                                     (if (and (pair? item) (eq? (car item) 'li))
                                         `(li ,@(map inline->sxml (cdr item)))
                                         `(li ,(inline->sxml item))))
                                   (cdr b))))
        ((table)
         (call-with-values (lambda () (table-cells (cadr b) (cddr b)))
           (lambda (headers rows aligns total? more)
             (let ((cls (lambda (a) (if (eq? a 'right) "num" "txt")))
                   (caption (opt (cddr b) 'caption #f))
                   (n (length rows)))
               `(div (@ (class "table-wrap"))
                     (table
                      ,@(if caption `((caption ,caption)) '())
                      (thead (tr ,@(map (lambda (h a) `(th (@ (class ,(cls a))) ,h)) headers aligns)))
                      (tbody ,@(map (lambda (r k)
                                      `(tr ,@(if (and total? (= k (- n 1))) '((@ (class "total"))) '())
                                           ,@(map (lambda (c a) `(td (@ (class ,(cls a))) ,c)) r aligns)))
                                    rows (iota n))))
                     ,@(if more `((p (@ (class "more")) ,(string-append "… " (number->string more) " more rows"))) '()))))))
        ((figure)
         (let ((caption (opt (cddr b) 'caption #f))
               (p (cadr b)))
           `(figure ,(plot->svg p)
                    ,@(if caption `((figcaption ,(string-append "Figure " (number->string fig-no) ": ") ,caption)) '()))))
        ((raw-html) (raw (cadr b)))
        (else (error "report: unknown block" (car b)))))

    (define page-css "
:root{--bg:#f9f9f7;--surface:#fcfcfb;--ink:#0b0b0b;--ink2:#52514e;--muted:#898781;--line:#e1e0d9;--accent:#2a78d6;--note:#eef4fc;color-scheme:light}
@media (prefers-color-scheme: dark){:root:not([data-theme=\"light\"]){--bg:#0d0d0d;--surface:#1a1a19;--ink:#f0efec;--ink2:#c3c2b7;--muted:#898781;--line:#2c2c2a;--accent:#3987e5;--note:#1c2633;color-scheme:dark}}
:root[data-theme=\"dark\"]{--bg:#0d0d0d;--surface:#1a1a19;--ink:#f0efec;--ink2:#c3c2b7;--muted:#898781;--line:#2c2c2a;--accent:#3987e5;--note:#1c2633;color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 system-ui,-apple-system,\"Segoe UI\",sans-serif}
main{max-width:860px;margin:0 auto;padding:40px 16px 64px}
h1.title{font-size:28px;line-height:1.2;margin:0 0 6px}
.subtitle{color:var(--ink2);font-size:17px;margin:0 0 4px}
.date{color:var(--muted);font-size:13px;margin:0 0 28px}
h1,h2,h3{line-height:1.25}
h2{font-size:21px;margin:36px 0 10px;padding-top:8px;border-top:1px solid var(--line)}
h3{font-size:17px;margin:24px 0 8px}
a{color:var(--accent)}
code{font:13px ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--surface);border:1px solid var(--line);border-radius:4px;padding:1px 4px}
pre{font:13px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--surface);border:1px solid var(--line);border-radius:6px;padding:12px;overflow-x:auto}
aside.note{background:var(--note);border-left:3px solid var(--accent);border-radius:4px;padding:10px 14px;margin:16px 0}
.table-wrap{overflow-x:auto;margin:14px 0}
table{border-collapse:collapse;font-size:14px;background:var(--surface);min-width:50%}
caption{text-align:left;color:var(--ink2);font-size:13px;padding-bottom:6px}
th,td{padding:6px 12px;border-bottom:1px solid var(--line)}
th{font-weight:600;color:var(--ink2);text-align:left;border-bottom-color:var(--muted)}
td.num,th.num{text-align:right;font-variant-numeric:tabular-nums}
tr.total td{font-weight:600;border-top:1px solid var(--muted);border-bottom:none}
p.more{color:var(--muted);font-size:13px}
figure{margin:18px 0}
figure svg{max-width:100%;height:auto;display:block;border-radius:8px}
figcaption{color:var(--ink2);font-size:13px;margin-top:6px}
nav.toc{font-size:14px;margin:0 0 24px}
nav.toc ol{padding-left:20px;margin:4px 0}
.page-break{break-after:page}
@media print{body{background:#fff}main{max-width:none;padding:0}}
")

    (define (report->html doc . opts)
      "Syntax: (report->html report [toc?])
Library: (scm data report)
Description: The report as one self-contained HTML page (string): inline
  CSS with a light and a dark theme, charts as inline SVG, and a table of
  contents of the h2 headings when there are at least three (toc? #f to
  leave it out).
Example:
  (report->html doc)"
      (let* ((bs (blocks doc))
             (title (let ((t (find (lambda (b) (eq? (car b) 'title)) bs)))
                      (if t (string-concatenate (map inline-text (cdr t))) "Report")))
             (h2s (filter (lambda (b) (eq? (car b) 'h2)) bs))
             (toc? (and (or (null? opts) (car opts)) (>= (length h2s) 3)))
             (fig 0)
             (body (append-map
                    (lambda (b)
                      (let ((x (block->sxml b (if (eq? (car b) 'figure) (begin (set! fig (+ fig 1)) fig) fig))))
                        ;; the table of contents goes after the header blocks
                        (if (and toc? (eq? b (find (lambda (b) (not (memq (car b) '(title subtitle date)))) bs)))
                            (list `(nav (@ (class "toc"))
                                        (strong "Contents")
                                        (ol ,@(map (lambda (h)
                                                     (let ((t (string-concatenate (map inline-text (cdr h)))))
                                                       `(li (a (@ (href ,(string-append "#" (slug t)))) ,t))))
                                                   h2s)))
                                  x)
                            (list x))))
                    bs)))
        (string-append
         "<!DOCTYPE html>\n"
         (html->string
          `(html (@ (lang "en"))
                 (head (meta (@ (charset "utf-8")))
                       (meta (@ (name "viewport") (content "width=device-width, initial-scale=1")))
                       (title ,title)
                       (style ,(raw (string-append page-css (plot-css)))))
                 (body (main ,@body)))))))

    ;; --- Markdown ----------------------------------------------------

    (define (md-escape s)
      (let ((out (open-output-string)))
        (string-for-each (lambda (c)
                           (when (memv c '(#\* #\_ #\` #\\ #\[ #\] #\< #\>)) (write-char #\\ out))
                           (write-char c out))
                         s)
        (get-output-string out)))

    (define (inline->md x)
      (cond ((string? x) (md-escape x))
            ((and (pair? x) (memq (car x) '(b i code link br)))
             (case (car x)
               ((b) (string-append "**" (string-concatenate (map inline->md (cdr x))) "**"))
               ((i) (string-append "*" (string-concatenate (map inline->md (cdr x))) "*"))
               ((code) (string-append "`" (string-concatenate (map inline-text (cdr x))) "`"))
               ((br) "  \n")
               ((link) (string-append "[" (string-concatenate (map inline->md (if (null? (cddr x)) (list (cadr x)) (cddr x))))
                                      "](" (cadr x) ")"))))
            (else (md-escape (inline-text x)))))

    (define (md-cell s)
      (string-map (lambda (c) (if (char=? c #\newline) #\space c))
                  (let ((out (open-output-string)))
                    (string-for-each (lambda (c) (when (char=? c #\|) (write-char #\\ out)) (write-char c out)) s)
                    (get-output-string out))))

    (define (report->markdown doc . opts)
      "Syntax: (report->markdown report [figure-writer])
Library: (scm data report)
Description: The report as GitHub-flavoured Markdown (string). Figures are
  passed to figure-writer, (lambda (plot number) …) returning the image
  path to link (write-report sets one up that writes PNG files); without
  one, figures become a placeholder line.
Example:
  (report->markdown doc)"
      (let ((writer (and (pair? opts) (car opts)))
            (out (open-output-string))
            (fig 0))
        (define (line . xs) (for-each (lambda (x) (write-string x out)) xs) (newline out))
        (for-each
         (lambda (b)
           (case (car b)
             ((title) (line "# " (string-concatenate (map inline->md (cdr b)))) (line))
             ((subtitle) (line "*" (string-concatenate (map inline->md (cdr b))) "*") (line))
             ((date) (line (if (pair? (cdr b)) (inline->md (cadr b)) (today-string))) (line))
             ((h1) (line "# " (string-concatenate (map inline->md (cdr b)))) (line))
             ((h2) (line "## " (string-concatenate (map inline->md (cdr b)))) (line))
             ((h3) (line "### " (string-concatenate (map inline->md (cdr b)))) (line))
             ((p) (line (string-concatenate (map inline->md (cdr b)))) (line))
             ((note) (line "> " (string-concatenate (map inline->md (cdr b)))) (line))
             ((pre) (line "```") (for-each (lambda (x) (line (if (string? x) x (fmt-value x)))) (cdr b)) (line "```") (line))
             ((hr page-break) (line "---") (line))
             ((ul ol)
              (for-each (lambda (item k)
                          (line (if (eq? (car b) 'ul) "- " (string-append (number->string k) ". "))
                                (if (and (pair? item) (eq? (car item) 'li))
                                    (string-concatenate (map inline->md (cdr item)))
                                    (inline->md item))))
                        (cdr b) (iota (length (cdr b)) 1))
              (line))
             ((table)
              (call-with-values (lambda () (table-cells (cadr b) (cddr b)))
                (lambda (headers rows aligns total? more)
                  (let ((caption (opt (cddr b) 'caption #f)))
                    (when caption (line "*" (md-escape caption) "*") (line))
                    (line "| " (string-join (map md-cell headers) " | ") " |")
                    (line "|" (string-join (map (lambda (a) (if (eq? a 'right) "---:" "---")) aligns) "|") "|")
                    (for-each (lambda (r k)
                                (let ((cells (map md-cell r)))
                                  (line "| " (string-join (if (and total? (= k (- (length rows) 1)))
                                                              (map (lambda (c) (if (string=? c "") c (string-append "**" c "**"))) cells)
                                                              cells)
                                                          " | ")
                                        " |")))
                              rows (iota (length rows)))
                    (when more (line) (line "*… " (number->string more) " more rows*"))
                    (line)))))
             ((figure)
              (set! fig (+ fig 1))
              (let* ((caption (opt (cddr b) 'caption #f))
                     (alt (opt (cddr b) 'alt (or caption (string-append "Figure " (number->string fig)))))
                     (path (and writer (writer (cadr b) fig))))
                (line (if path
                          (string-append "![" (md-escape alt) "](" path ")")
                          (string-append "*[Figure " (number->string fig) "]*")))
                (when caption (line) (line "*Figure " (number->string fig) ": " (md-escape caption) "*"))
                (line)))
             ((raw-html) (line (cadr b)) (line))
             (else (error "report: unknown block" (car b)))))
         (blocks doc))
        (get-output-string out)))


    ;; --- PDF ---------------------------------------------------------

    ;; Reports are laid out on pages of (scm pdf): text in embedded fonts
    ;; (DejaVu Sans by default), tables with their header repeated on each
    ;; page, figures as vector graphics, h1/h2/h3 as bookmarks, and a
    ;; footer with the title and the page number.

    (define (hex->rgb s)
      (map (lambda (i) (/ (string->number (substring s i (+ i 2)) 16) 255.0)) '(1 3 5)))

    (define c-ink (hex->rgb "#0b0b0b"))
    (define c-ink2 (hex->rgb "#52514e"))
    (define c-muted (hex->rgb "#898781"))
    (define c-line (hex->rgb "#e1e0d9"))
    (define c-rule (hex->rgb "#c3c2b7"))
    (define c-accent (hex->rgb "#2a78d6"))
    (define c-note (hex->rgb "#eef4fc"))
    (define c-code (hex->rgb "#f3f3f1"))

    ;; inline content -> tokens #(text style link space-before?); style is
    ;; regular, bold, italic, bold-italic or mono; a forced break is #(br)
    (define (inline-tokens xs)
      (define (style+ style add)
        (case add
          ((bold) (case style ((italic bold-italic) 'bold-italic) ((mono) 'mono) (else 'bold)))
          ((italic) (case style ((bold bold-italic) 'bold-italic) ((mono) 'mono) (else 'italic)))
          (else add)))
      (define (runs x style link)
        (cond ((string? x) (list (list x style link)))
              ((and (pair? x) (memq (car x) '(b i code link br)))
               (case (car x)
                 ((b) (append-map (lambda (y) (runs y (style+ style 'bold) link)) (cdr x)))
                 ((i) (append-map (lambda (y) (runs y (style+ style 'italic) link)) (cdr x)))
                 ((code) (list (list (string-concatenate (map inline-text (cdr x))) 'mono link)))
                 ((br) (list 'br))
                 ((link) (append-map (lambda (y) (runs y style (cadr x)))
                                     (if (null? (cddr x)) (list (cadr x)) (cddr x))))))
              (else (list (list (inline-text x) style link)))))
      (let loop ((rs (append-map (lambda (x) (runs x 'regular #f)) xs)) (space? #f) (acc '()))
        (cond
         ((null? rs) (reverse acc))
         ((eq? (car rs) 'br) (loop (cdr rs) #f (cons (vector 'br) acc)))
         (else
          (let* ((text (car (car rs))) (style (cadr (car rs))) (link (caddr (car rs)))
                 (n (string-length text)))
            ;; words of this run; a space at a run boundary belongs to the next word
            (let words ((i 0) (space? space?) (acc acc))
              (cond
               ((>= i n) (loop (cdr rs) space? acc))
               ((char-whitespace? (string-ref text i)) (words (+ i 1) #t acc))
               (else
                (let ((e (or (string-index text char-whitespace? i) n)))
                  (words e #f (cons (vector (substring text i e) style link space?) acc)))))))))))

    (define (report->pdf doc . options)
      "Syntax: (report->pdf report [options])
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
  (call-with-port (open-binary-output-file \"r.pdf\")
    (lambda (o) (write-bytevector (report->pdf doc) o)))"
      (let* ((options (if (pair? options) (car options) '()))
             (option (lambda (k d) (let ((p (assq k options))) (if p (cdr p) d))))
             (size (option 'page-size pdf-page-size-a4))
             (pw (car size)) (ph (cdr size))
             (margin (option 'margin 56))
             (base (option 'font-size 10))
             (family (option 'font #f))
             (f-regular (or (and family (find-font family 400)) dejavu-sans))
             (f-bold (or (and family (find-font family 700)) dejavu-sans-bold))
             (f-mono #f)
             (pdf (make-pdf))
             (left margin)
             (width (- pw (* 2 margin)))
             (top (- ph margin))
             (bottom (+ margin 16))
             (pages '())
             (page #f)
             (y top)
             (fig 0)
             (outline-h1 #f)
             (outline-h2 #f)
             (previous #f)
             (bs (blocks doc))
             (title (let ((t (find (lambda (b) (eq? (car b) 'title)) bs)))
                      (and t (string-concatenate (map inline-text (cdr t)))))))
        (define (font-of style)
          (case style
            ((bold bold-italic) f-bold)
            ((mono)
             (unless f-mono
               (set! f-mono (or (let ((m (option 'mono-font #f))) (and m (find-font m 400)))
                                (find-font "JetBrains Mono" 400)
                                (find-font "IBM Plex Mono" 400)
                                f-regular)))
             f-mono)
            (else f-regular)))
        (define (text-width style sz s) (font-text-width (font-of style) sz s))
        (define (new-page!)
          (set! page (pdf-add-page! pdf pw ph))
          (set! pages (cons page pages))
          (set! y top))
        (define (at-top?) (and page (= y top)))
        (define (need! h) (when (or (not page) (< (- y h) bottom)) (new-page!)))
        (define (gap! h) (unless (at-top?) (set! y (- y h))))
        (define (fill-rgb! c) (apply pdf-set-fill-rgb page c))
        (define (draw-string! style sz x by s colour)
          (let ((font (font-of style)))
            (pdf-with-state page
              (lambda ()
                (fill-rgb! colour)
                (apply pdf-draw-text page (svg-pdf-font pdf font) sz x by s
                       'kerning (lambda (a b) (* 1000 (/ (font-kerning font a b) (font-units-per-em font))))
                       (if (memq style '(italic bold-italic)) '(skew 11) '()))))))
        (define (rect! x ry w h colour)
          (pdf-with-state page (lambda () (fill-rgb! colour) (pdf-rect page x ry w h) (pdf-fill page))))
        (define (hline! x1 x2 ly colour lw)
          (pdf-with-state page
            (lambda ()
              (apply pdf-set-stroke-rgb page colour)
              (pdf-set-line-width page lw)
              (pdf-move-to page x1 ly) (pdf-line-to page x2 ly) (pdf-stroke page))))
        ;; tokens -> lines, each a list of (token . x-offset)
        (define (break-lines tokens sz w)
          (let ((space (text-width 'regular sz " ")))
            (let loop ((ts tokens) (line '()) (lw 0) (lines '()))
              (cond
               ((null? ts) (reverse (if (null? line) lines (cons (reverse line) lines))))
               ((eq? (vector-ref (car ts) 0) 'br) (loop (cdr ts) '() 0 (cons (reverse line) lines)))
               (else
                (let* ((t (car ts))
                       (tw (text-width (vector-ref t 1) sz (vector-ref t 0)))
                       (sp (if (and (pair? line) (vector-ref t 3)) space 0)))
                  (if (and (pair? line) (> (+ lw sp tw) w))
                      (loop ts '() 0 (cons (reverse line) lines))
                      (loop (cdr ts) (cons (cons t (+ lw sp)) line) (+ lw sp tw) lines))))))))
        (define (draw-line! line x by sz colour)
          (for-each (lambda (p)
                      (let* ((t (car p)) (tx (+ x (cdr p))) (link (vector-ref t 2))
                             (s (vector-ref t 0)) (style (vector-ref t 1)))
                        (draw-string! style sz tx by s (if link c-accent colour))
                        (when link
                          (pdf-add-link page (list tx (- by (* 0.25 sz)) (+ tx (text-width style sz s)) (+ by (* 0.8 sz)))
                                        link))))
                    line))
        ;; flows inline content at x with width w; returns nothing, moves y
        (define (flow! xs sz lead x w colour)
          (for-each (lambda (line)
                      (need! lead)
                      (draw-line! line x (- y (* 0.5 (- lead sz)) (* 0.8 sz)) sz colour)
                      (set! y (- y lead)))
                    (break-lines (inline-tokens xs) sz w)))
        (define (heading! b sz before)
          (let ((text (string-concatenate (map inline-text (cdr b)))))
            ;; keep the heading with what follows it
            (gap! before)
            (need! (+ (* 1.4 sz) (* 3 1.45 base)))
            (when (and (eq? (car b) 'h2) (not (at-top?)) (not (eq? previous 'hr)))
              (hline! left (+ left width) (+ y 6) c-line 0.6))
            (case (car b)
              ((h1) (set! outline-h1 (pdf-add-outline! pdf page text 'y y)) (set! outline-h2 #f))
              ((h2) (set! outline-h2 (if outline-h1
                                         (pdf-add-outline! pdf page text 'y y 'parent outline-h1)
                                         (pdf-add-outline! pdf page text 'y y))))
              ((h3) (if outline-h2
                        (pdf-add-outline! pdf page text 'y y 'parent outline-h2)
                        (pdf-add-outline! pdf page text 'y y))))
            (flow! (map (lambda (x) (list 'b x)) (cdr b)) sz (* 1.3 sz) left width c-ink)
            (set! y (- y (* 0.4 sz)))))
        ;; a cell's text wrapped to width w -> list of strings
        (define (wrap-plain s style sz w)
          (map (lambda (line) (string-join (map (lambda (p) (vector-ref (car p) 0)) line) " "))
               (let ((lines (break-lines (inline-tokens (list s)) sz w)))
                 (if (null? lines) '(()) lines))))
        (define (table! df opts)
          (call-with-values (lambda () (table-cells df opts))
            (lambda (headers rows aligns total? more)
              (let* ((sz (- base 1)) (lead (* 1.3 sz)) (px 6) (py 3.5)
                     (caption (opt opts 'caption #f))
                     (ncol (length headers))
                     (natural (map (lambda (j)
                                     (+ (* 2 px)
                                        (apply max (text-width 'bold sz (list-ref headers j))
                                               (map (lambda (r) (text-width 'regular sz (list-ref r j))) rows))))
                                   (iota ncol)))
                     (total-w (fold + 0 natural))
                     ;; too wide: columns wider than a fair share give up the excess
                     (widths (if (<= total-w width)
                                 natural
                                 (let* ((fair (/ width ncol))
                                        (small (fold + 0 (filter (lambda (w) (<= w fair)) natural)))
                                        (big (fold + 0 (filter (lambda (w) (> w fair)) natural)))
                                        (k (/ (- width small) big)))
                                   (map (lambda (w) (if (<= w fair) w (* w k))) natural))))
                     (xs (let loop ((ws widths) (x left) (acc '()))
                           (if (null? ws) (reverse acc) (loop (cdr ws) (+ x (car ws)) (cons x acc)))))
                     (tw (fold + 0 widths)))
                (define (row-lines cells style)
                  (map (lambda (c w) (wrap-plain c style sz (- w (* 2 px)))) cells widths))
                (define (row-height lines) (+ (* 2 py) (* lead (apply max 1 (map length lines)))))
                (define (draw-row! lines style colour)
                  (let ((h (row-height lines)))
                    (for-each (lambda (cell-lines x w a)
                                (let loop ((ls cell-lines) (k 0))
                                  (unless (null? ls)
                                    (let* ((s (car ls))
                                           (sw (text-width style sz s))
                                           (tx (if (eq? a 'right) (- (+ x w) px sw) (+ x px))))
                                      (draw-string! style sz tx (- y py (* k lead) (* 0.5 (- lead sz)) (* 0.8 sz)) s colour)
                                      (loop (cdr ls) (+ k 1))))))
                              lines xs widths aligns)
                    (set! y (- y h))))
                (define (header!)
                  (let ((ls (row-lines headers 'bold)))
                    (draw-row! ls 'bold c-ink2)
                    (hline! left (+ left tw) y c-rule 0.8)))
                (gap! 4)
                ;; a table that fits on a page is not split
                (let ((whole (+ (if caption (* 1.4 sz) 0)
                                (row-height (row-lines headers 'bold))
                                (fold + 0 (map (lambda (r) (row-height (row-lines r 'regular))) rows)))))
                  (when (<= whole (- top bottom)) (need! whole)))
                (when caption
                  (need! (+ (* 1.4 sz) (* 3 lead)))
                  (flow! (list caption) sz (* 1.4 sz) left width c-ink2))
                (need! (+ (row-height (row-lines headers 'bold)) (* 2 lead)))
                (header!)
                (for-each (lambda (r k)
                            (let* ((total-row? (and total? (= k (- (length rows) 1))))
                                   (style (if total-row? 'bold 'regular))
                                   (ls (row-lines r style))
                                   (h (row-height ls)))
                              (when (< (- y h) bottom)
                                (new-page!)
                                (header!))
                              (when total-row? (hline! left (+ left tw) y c-rule 0.8))
                              (draw-row! ls style c-ink)
                              (unless total-row? (hline! left (+ left tw) y c-line 0.5))))
                          rows (iota (length rows)))
                (when more
                  (set! y (- y 3))
                  (flow! (list (string-append "… " (number->string more) " more rows")) sz lead left width c-muted))
                (set! y (- y 8))))))
        (define (figure! p opts)
          (set! fig (+ fig 1))
          (let* ((svg (plot->svg p))
                 (caption (opt opts 'caption #f))
                 (avail (- top bottom 30)))
            (let-values (((w h) (svg-size svg)))
              (let* ((fw (min width (* 0.75 w)))
                     (fw (if (> (* fw (/ h w)) avail) (* avail (/ w h)) fw))
                     (fh (* fw (/ h w))))
                (gap! 6)
                (need! (+ fh (if caption 20 0)))
                (svg->pdf-page! pdf page svg left y
                                (list (cons 'width fw)
                                      (cons 'fonts (list (cons 'normal f-regular) (cons 'bold f-bold)))))
                (set! y (- y fh 4))
                (when caption
                  (flow! (list (string-append "Figure " (number->string fig) ": ") caption)
                         (- base 1) (* 1.4 (- base 1)) left width c-ink2))
                (set! y (- y 10))))))
        (define (pre! strings)
          (let* ((sz (- base 1.5)) (lead (* 1.35 sz)) (pad 6)
                 (lines (append-map (lambda (s) (string-split-lines (if (string? s) s (fmt-value s)))) strings))
                 (blank? (lambda (l) (string-null? (string-trim-both l))))
                 (lines (reverse (drop-while blank? (reverse (drop-while blank? lines)))))
                 (lines (map (lambda (l) (string-map (lambda (c) (if (char=? c #\tab) #\space c)) l)) lines))
                 (maxw (- width (* 2 pad)))
                 ;; long lines are cut into pieces that fit
                 (lines (append-map (lambda (l)
                                      (let loop ((l l) (acc '()))
                                        (if (or (string-null? l) (<= (text-width 'mono sz l) maxw))
                                            (reverse (cons l acc))
                                            (let fit ((k (- (string-length l) 1)))
                                              (if (or (<= k 1) (<= (text-width 'mono sz (substring l 0 k)) maxw))
                                                  (loop (substring l k (string-length l)) (cons (substring l 0 k) acc))
                                                  (fit (- k 1)))))))
                                    lines)))
            (gap! 4)
            (need! (+ lead pad))
            (rect! left (- y pad) width pad c-code)
            (set! y (- y pad))
            (for-each (lambda (l)
                        (when (< (- y lead) bottom)
                          (new-page!))
                        (rect! left (- y lead) width lead c-code)
                        (draw-string! 'mono sz (+ left pad) (- y (* 0.5 (- lead sz)) (* 0.8 sz)) l c-ink)
                        (set! y (- y lead)))
                      lines)
            (rect! left (- y pad) width pad c-code)
            (set! y (- y pad 8))))
        (define (note! xs)
          (let* ((sz base) (lead (* 1.45 sz)) (pad 8)
                 (lines (break-lines (inline-tokens xs) sz (- width (* 2 pad) 3)))
                 (h (+ (* 2 pad) (* lead (length lines)))))
            (gap! 4)
            (if (> h (- top bottom))
                (flow! xs sz lead left width c-ink)
                (begin
                  (need! h)
                  (rect! left (- y h) width h c-note)
                  (rect! left (- y h) 3 h c-accent)
                  (let loop ((ls lines) (ly (- y pad)))
                    (unless (null? ls)
                      (draw-line! (car ls) (+ left 3 pad) (- ly (* 0.5 (- lead sz)) (* 0.8 sz)) sz c-ink)
                      (loop (cdr ls) (- ly lead))))
                  (set! y (- y h))))
            (set! y (- y 8))))
        (define (list! b)
          (let ((sz base) (lead (* 1.45 base)) (indent 16))
            (for-each (lambda (item k)
                        (let ((xs (if (and (pair? item) (eq? (car item) 'li)) (cdr item) (list item)))
                              (marker (if (eq? (car b) 'ul) "•" (string-append (number->string k) "."))))
                          (need! lead)
                          (draw-string! 'regular sz (+ left 3) (- y (* 0.5 (- lead sz)) (* 0.8 sz)) marker c-ink2)
                          (flow! xs sz lead (+ left indent) (- width indent) c-ink)
                          (set! y (- y 2))))
                      (cdr b) (iota (length (cdr b)) 1))
            (set! y (- y 6))))
        (define (block! b)
          (case (car b)
            ((title) (need! 40) (flow! (map (lambda (x) (list 'b x)) (cdr b)) 22 28 left width c-ink) (set! y (- y 2)))
            ((subtitle) (need! 18) (flow! (cdr b) 13 18 left width c-ink2))
            ((date) (need! 14) (flow! (list (if (pair? (cdr b)) (inline-text (cadr b)) (today-string))) 9 13 left width c-muted)
                    (set! y (- y 12)))
            ((h1) (heading! b 18 14))
            ((h2) (heading! b 14 14))
            ((h3) (heading! b 11.5 8))
            ((p) (flow! (cdr b) base (* 1.45 base) left width c-ink) (set! y (- y 7)))
            ((note) (note! (cdr b)))
            ((pre) (pre! (cdr b)))
            ((hr) (need! 14) (hline! left (+ left width) (- y 7) c-line 0.6) (set! y (- y 14)))
            ((page-break) (unless (at-top?) (new-page!)))
            ((ul ol) (list! b))
            ((table) (table! (cadr b) (cddr b)))
            ((figure) (figure! (cadr b) (cddr b)))
            ((raw-html) #f)
            (else (error "report: unknown block" (car b)))))
        (new-page!)
        (for-each (lambda (b) (block! b) (set! previous (car b))) bs)
        (when title (pdf-set-metadata! pdf 'title title 'creator "dabscm (scm data report)"))
        (when (option 'footer #t)
          (let ((n (length pages)))
            (for-each (lambda (pg i)
                        (set! page pg)
                        (let ((fy (- margin 18)) (num (string-append (number->string i) " / " (number->string n))))
                          (when title (draw-string! 'regular 8 left fy title c-muted))
                          (draw-string! 'regular 8 (- (+ left width) (text-width 'regular 8 num)) fy num c-muted)))
                      (reverse pages) (iota n 1))))
        (pdf->bytevector pdf)))

    (define (string-split-lines s)
      (let loop ((i 0) (start 0) (acc '()))
        (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
              ((char=? (string-ref s i) #\newline) (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
              (else (loop (+ i 1) start acc)))))

    (define (write-report doc path . opts)
      "Syntax: (write-report report path [figure-format])
Library: (scm data report)
Description: Writes the report to path, as HTML (.html), Markdown (.md)
  or PDF (.pdf, see report->pdf). For Markdown, figures are written next
  to the file as
  <name>-fig<n>.png (figure-format png, the default) or .svg, and linked.
Example:
  (write-report doc \"report.html\")
  (write-report doc \"report.md\" 'svg)"
      (cond
       ((or (string-suffix-ci? ".html" path) (string-suffix-ci? ".htm" path))
        (call-with-output-file path (lambda (o) (write-string (report->html doc) o))))
       ((string-suffix-ci? ".md" path)
        (let* ((fmt (if (pair? opts) (car opts) 'png))
               (dir (directory-name path))
               (base (let ((b (base-name path))) (substring b 0 (- (string-length b) 3))))
               (writer (lambda (p n)
                         (let* ((file (string-append base "-fig" (number->string n) "." (symbol->string fmt)))
                                (full (if (and dir (not (string=? dir ""))) (join-path dir file) file)))
                           (save-plot p full)
                           file))))
          (call-with-output-file path (lambda (o) (write-string (report->markdown doc writer) o)))))
       ((string-suffix-ci? ".pdf" path)
        (let ((bv (report->pdf doc)))
          (call-with-port (open-binary-output-file path) (lambda (o) (write-bytevector bv o)))))
       (else (error "write-report: use a .html, .md or .pdf file name" path))))))

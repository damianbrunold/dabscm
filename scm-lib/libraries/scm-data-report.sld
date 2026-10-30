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
          (scm data plot))
  (export report
          make-report
          report->html
          report->markdown
          write-report)
  (begin

    ;; ================================================================
    ;; (scm data report) — reports as data, rendered to a self-contained
    ;; HTML page or to Markdown. A report quasiquotes its blocks, so
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

    (define (write-report doc path . opts)
      "Syntax: (write-report report path [figure-format])
Library: (scm data report)
Description: Writes the report to path, as HTML (.html) or Markdown (.md).
  For Markdown, figures are written next to the file as
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
       (else (error "write-report: use a .html or .md file name" path))))))

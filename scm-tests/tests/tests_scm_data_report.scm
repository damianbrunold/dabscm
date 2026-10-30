(import (scheme base) (scheme file) (srfi 1) (srfi 13) (scm fs) (scm data) (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-data-report")

(define pts (tibble (splg 'BEW8 'GYN2) (v1 6441 1728.5) (v2 8694 1994)))
(define plot (ggplot pts (aes (x splg) (y v1)) (geom-col)))
(define gain (fmt-pct-change 8169.5 10688))

(define doc
  (report (title "MFZO") (subtitle "v1 vs v2") (date "2026-10-30")
          (h2 "Points")
          (p "Totals rise by " (b ,gain) ", see " (link "https://example.org" "here") ".")
          (table ,(mutate pts (d (/ (- v2 v1) v1)))
                 (columns (splg "SPLG") (v1 "v1" num) (v2 "v2") (d "Δ" pct))
                 (total-row) (caption "ZH"))
          (figure ,plot (caption "Points"))
          (h2 "Notes") (ul "a" (li "b " (i "c"))) (ol "x")
          (note "careful") (pre "code") (hr)
          (h2 "End")))

(define (has? s sub) (and (string-contains s sub) #t))

(test-group "html"
  (let ((h (report->html doc)))
    (test-assert (string-prefix? "<!DOCTYPE html>" h))
    (test-assert (has? h "<title>MFZO</title>"))
    (test-assert (has? h "<h1 class=\"title\">MFZO</h1>"))
    (test-assert (has? h "<strong>+31 %</strong>"))
    (test-assert (has? h "<a href=\"https://example.org\">here</a>"))
    ;; table: right-aligned numbers, formats, total row without the % column
    (test-assert (has? h "<th class=\"num\">v1</th>"))
    (test-assert (has? h "<td class=\"num\">1&#39;729</td>"))
    (test-assert (has? h "<td class=\"num\">35 %</td>"))
    (test-assert (has? h "<tr class=\"total\"><td class=\"txt\">Total</td><td class=\"num\">8&#39;170</td><td class=\"num\">10&#39;688</td><td class=\"num\"></td></tr>"))
    ;; inline chart, caption, table of contents (3 h2), dark mode css
    (test-assert (has? h "<svg"))
    (test-assert (has? h "Figure 1: "))
    (test-assert (has? h "<nav class=\"toc\">"))
    (test-assert (has? h "href=\"#points\""))
    (test-assert (has? h "prefers-color-scheme: dark"))
    (test-assert (has? h "<aside class=\"note\">careful</aside>"))
    (test-assert (not (has? (report->html doc #f) "<nav class=\"toc\">")))))

(test-group "markdown"
  (let ((m (report->markdown doc (lambda (p n) (string-append "fig" (number->string n) ".png")))))
    (test-assert (string-prefix? "# MFZO\n\n*v1 vs v2*\n\n2026-10-30\n" m))
    (test-assert (has? m "Totals rise by **+31 %**, see [here](https://example.org)."))
    (test-assert (has? m "| SPLG | v1 | v2 | Δ |\n|---|---:|---:|---:|\n| BEW8 | 6'441 | 8'694 | 35 % |"))
    (test-assert (has? m "| **Total** | **8'170** | **10'688** |  |"))
    (test-assert (has? m "![Points](fig1.png)"))
    (test-assert (has? m "- b *c*"))
    (test-assert (has? m "1. x"))
    (test-assert (has? m "> careful"))
    (test-assert (has? m "```\ncode\n```")))
  (test-assert (has? (report->markdown (report (p "a*b_c|d"))) "a\\*b\\_c|d"))
  ;; spliced blocks
  (let ((extra '((p "one") (p "two"))))
    (test-assert (has? (report->markdown (report (h2 "x") ,@extra)) "one\n\ntwo"))))

(test-group "write-report"
  (let ((dir (mktempdir)))
    (write-report doc (join-path dir "r.html"))
    (test-assert (file-exists? (join-path dir "r.html")))
    (write-report doc (join-path dir "r.md"))
    (test-assert (file-exists? (join-path dir "r-fig1.png")))
    (write-report doc (join-path dir "s.md") 'svg)
    (test-assert (file-exists? (join-path dir "s-fig1.svg")))
    (write-report doc (join-path dir "r.pdf"))
    (test-assert (file-exists? (join-path dir "r.pdf")))
    (test-error (write-report doc (join-path dir "r.docx")))))

(test-group "umbrella helpers"
  (define spec '((years . (2024 2025)) (out . "report") (regroup . #f) (n . 5) (mode . v1)))
  (test-equal spec (script-args spec #f '()))
  (test-equal '((years 2023 2024) (out . "x") (regroup . #t) (n . 7) (mode . v2))
              (script-args spec #f '("years=2023,2024" "out=x" "regroup=yes" "n=7" "mode=v2")))
  (test-error (script-args spec #f '("n=abc")))
  (test-equal '((out . #f) (keys . ()) (on . #t))
              (script-args '((out string #f) (keys list-symbol ()) (on bool #t)) #f '()))
  (test-equal '((out . "x") (keys a b) (on . #f))
              (script-args '((out string #f) (keys list-symbol ()) (on bool #t)) #f '("out=x" "keys=a,b" "on=no")))
  (test-equal 42 (with-timing "answer" (lambda () 42))))

;; PDF: the bytes as a Latin-1 string, to look for structure
(define (pdf-text bv)
  (let ((s (make-string (bytevector-length bv))))
    (do ((i 0 (+ i 1))) ((= i (bytevector-length bv)) s)
      (string-set! s i (integer->char (bytevector-u8-ref bv i))))))

(define (count-matches s pat)
  (let loop ((i 0) (n 0))
    (let ((j (string-contains s pat i)))
      (if j (loop (+ j 1) (+ n 1)) n))))

(test-group "pdf"
  (let* ((bv (report->pdf doc))
         (s (pdf-text bv)))
    (test-assert (string-prefix? "%PDF-" s))
    (test-assert (<= 1 (count-matches s "/Type /Page ") 3))
    (test-assert (string-contains s "/Outlines"))
    (test-assert (string-contains s "(Points)"))          ; an h2 as a bookmark
    (test-assert (string-contains s "/Title (MFZO)")))
  ;; a long table goes over several pages
  (let* ((big (make-df (list (cons 'i (list->vector (list-tabulate 120 (lambda (i) i)))))))
         (s (pdf-text (report->pdf (report (title "Long") (table ,big))))))
    (test-assert (>= (count-matches s "/Type /Page ") 3)))
  (let* ((s (pdf-text (plot->pdf plot))))
    (test-assert (string-prefix? "%PDF-" s))
    (test-equal 1 (count-matches s "/Type /Page "))
    (test-assert (string-contains s "/FontFile2"))))

(test-end "scm-data-report")

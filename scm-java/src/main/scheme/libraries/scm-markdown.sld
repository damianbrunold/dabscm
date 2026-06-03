(define-library (scm markdown)
  (import (scm core)
          (scheme base)
          (scheme char)
          (srfi 13))
  (export parse-markdown
          markdown->html)
  (begin

    ;; ================================================================
    ;; (scm markdown) — a small, dependency-free Markdown parser and
    ;; HTML renderer for a practical CommonMark subset. parse-markdown
    ;; turns Markdown text into an s-expression AST you can walk; and
    ;; markdown->html renders that AST to an HTML fragment.
    ;;
    ;; Supported block constructs:
    ;;   - ATX headings            # .. ###### (trailing #'s stripped)
    ;;   - fenced code blocks      ``` or ~~~, with optional info string
    ;;   - blockquotes             > ... (parsed recursively)
    ;;   - bullet lists            -, *, + markers
    ;;   - ordered lists           1. / 1) markers
    ;;   - thematic breaks         ---  ***  ___
    ;;   - paragraphs              (soft line breaks join with a space)
    ;;
    ;; Supported inline constructs:
    ;;   - code spans              `code` (and ``code with ` inside``)
    ;;   - strong                  **text**  __text__
    ;;   - emphasis                *text*    _text_
    ;;   - links                   [text](url)
    ;;   - backslash escapes       \* \_ \` \[ ...
    ;;
    ;; Not supported (by design — keep it small): setext headings,
    ;; reference links, images, raw HTML, tables, nested lists, and the
    ;; full CommonMark emphasis flanking rules (a pragmatic approximation
    ;; is used; intraword underscores are treated as literal text).
    ;;
    ;; AST shape:
    ;;   block  = (heading <level> <inline> ...)
    ;;          | (paragraph <inline> ...)
    ;;          | (code-block <info-or-#f> <text>)
    ;;          | (blockquote <block> ...)
    ;;          | (bullet-list <item> ...)
    ;;          | (ordered-list <start> <item> ...)
    ;;          | (thematic-break)
    ;;   item   = (item <inline> ...)
    ;;   inline = <string>                       ; literal text
    ;;          | (strong <inline> ...)
    ;;          | (emph   <inline> ...)
    ;;          | (code   <string>)
    ;;          | (link   (<inline> ...) <url>)
    ;; ================================================================

    ;; ---- small string helpers --------------------------------------

    (define (ascii-alnum? c)
      (or (char<=? #\a c #\z) (char<=? #\A c #\Z) (char<=? #\0 c #\9)))

    (define (ws? c) (or (char=? c #\space) (char=? c #\tab)))

    (define (trim-left s)
      (let ((n (string-length s)))
        (let loop ((i 0))
          (if (and (< i n) (ws? (string-ref s i)))
              (loop (+ i 1))
              (substring s i n)))))

    (define (blank-line? line)
      (string-every (lambda (c) (char-whitespace? c)) line))

    (define (string->lines s)
      ;; split on newline; a trailing \r on a line is dropped
      (let ((n (string-length s))
            (out '())
            (cur (open-output-string)))
        (define (flush!)
          (set! out (cons (get-output-string cur) out))
          (set! cur (open-output-string)))
        (let loop ((i 0))
          (cond
            ((>= i n) (flush!) (reverse out))
            (else
             (let ((c (string-ref s i)))
               (cond
                 ((char=? c #\newline) (flush!) (loop (+ i 1)))
                 ((char=? c #\return)
                  (flush!)
                  (if (and (< (+ i 1) n) (char=? (string-ref s (+ i 1)) #\newline))
                      (loop (+ i 2))
                      (loop (+ i 1))))
                 (else (write-char c cur) (loop (+ i 1))))))))))

    ;; ---- inline parsing --------------------------------------------

    (define (parse-inlines s)
      (let ((n (string-length s)))
        (let loop ((i 0) (buf '()) (acc '()))
          (define (flush)
            (if (null? buf) acc (cons (list->string (reverse buf)) acc)))
          (if (>= i n)
              (reverse (flush))
              (let ((c (string-ref s i)))
                (cond
                  ((char=? c #\\)
                   (if (< (+ i 1) n)
                       (loop (+ i 2) (cons (string-ref s (+ i 1)) buf) acc)
                       (loop (+ i 1) (cons c buf) acc)))
                  ((char=? c #\`)
                   (let ((res (scan-code s i n)))
                     (if res
                         (loop (cdr res) '() (cons (car res) (flush)))
                         (loop (+ i 1) (cons c buf) acc))))
                  ((char=? c #\[)
                   (let ((res (scan-link s i n)))
                     (if res
                         (loop (cdr res) '() (cons (car res) (flush)))
                         (loop (+ i 1) (cons c buf) acc))))
                  ((or (char=? c #\*) (char=? c #\_))
                   (let ((res (scan-emph s i n)))
                     (if res
                         (loop (cdr res) '() (cons (car res) (flush)))
                         (loop (+ i 1) (cons c buf) acc))))
                  (else (loop (+ i 1) (cons c buf) acc))))))))

    (define (delim-run-len s i n d)
      (let loop ((k i)) (if (and (< k n) (char=? (string-ref s k) d)) (loop (+ k 1)) (- k i))))

    (define (non-all-space? s)
      (string-any (lambda (c) (not (char=? c #\space))) s))

    (define (code-trim s)
      (let ((len (string-length s)))
        (if (and (>= len 2)
                 (char=? (string-ref s 0) #\space)
                 (char=? (string-ref s (- len 1)) #\space)
                 (non-all-space? s))
            (substring s 1 (- len 1))
            s)))

    (define (scan-code s i n)
      ;; i points at a backtick; match a run of equal length
      (let* ((open-len (delim-run-len s i n #\`))
             (content-start (+ i open-len)))
        (let find ((j content-start))
          (cond
            ((>= j n) #f)
            ((char=? (string-ref s j) #\`)
             (let ((run (delim-run-len s j n #\`)))
               (if (= run open-len)
                   (cons (list 'code (code-trim (substring s content-start j)))
                         (+ j open-len))
                   (find (+ j run)))))
            (else (find (+ j 1)))))))

    (define (scan-link s i n)
      ;; i points at '['
      (let find-close ((j (+ i 1)) (depth 1))
        (cond
          ((>= j n) #f)
          ((char=? (string-ref s j) #\\) (find-close (+ j 2) depth))
          ((char=? (string-ref s j) #\[) (find-close (+ j 1) (+ depth 1)))
          ((char=? (string-ref s j) #\])
           (if (> depth 1)
               (find-close (+ j 1) (- depth 1))
               (if (and (< (+ j 1) n) (char=? (string-ref s (+ j 1)) #\())
                   (let url-find ((k (+ j 2)))
                     (cond
                       ((>= k n) #f)
                       ((char=? (string-ref s k) #\))
                        (cons (list 'link
                                    (parse-inlines (substring s (+ i 1) j))
                                    (string-trim-both (substring s (+ j 2) k)))
                              (+ k 1)))
                       (else (url-find (+ k 1)))))
                   #f)))
          (else (find-close (+ j 1) depth)))))

    (define (scan-emph s i n)
      ;; i points at '*' or '_'
      (let* ((d (string-ref s i))
             (strong (and (< (+ i 1) n) (char=? (string-ref s (+ i 1)) d)))
             (dl (if strong 2 1))
             (open-end (+ i dl)))
        (cond
          ((>= open-end n) #f)
          ;; opening must not be followed by a space
          ((char-whitespace? (string-ref s open-end)) #f)
          ;; intraword underscore: leave as literal
          ((and (char=? d #\_) (> i 0) (ascii-alnum? (string-ref s (- i 1)))) #f)
          (else
           (let find ((j open-end))
             (cond
               ((>= j n) #f)
               ((and (char=? (string-ref s j) d)
                     (>= (delim-run-len s j n d) dl)
                     (> j open-end)
                     ;; closing must not be preceded by a space
                     (not (char-whitespace? (string-ref s (- j 1))))
                     ;; for single emph, don't treat the start of a longer run as the closer
                     (or (= dl 2)
                         (not (and (< (+ j 1) n) (char=? (string-ref s (+ j 1)) d))))
                     ;; intraword underscore closing guard
                     (or (not (char=? d #\_))
                         (let ((after (+ j dl)))
                           (or (>= after n) (not (ascii-alnum? (string-ref s after)))))))
                (cons (cons (if strong 'strong 'emph)
                            (parse-inlines (substring s open-end j)))
                      (+ j dl)))
               (else (find (+ j 1)))))))))

    ;; ---- block parsing ---------------------------------------------

    (define (atx-heading line)
      ;; returns (level . rest-string) or #f
      (let* ((l (trim-left line))
             (n (string-length l)))
        (let count ((i 0))
          (if (and (< i n) (< i 6) (char=? (string-ref l i) #\#))
              (count (+ i 1))
              (if (and (> i 0)
                       (or (= i n) (char=? (string-ref l i) #\space)))
                  (let* ((rest (string-trim-both (substring l i n)))
                         ;; strip a trailing run of #'s (closing sequence)
                         (rest (string-trim-right rest #\#))
                         (rest (string-trim-right rest)))
                    (cons i rest))
                  #f)))))

    (define (thematic-break? line)
      (let ((l (string-trim-both line)))
        (and (>= (string-length l) 3)
             (let ((c (string-ref l 0)))
               (and (or (char=? c #\-) (char=? c #\*) (char=? c #\_))
                    (string-every (lambda (ch) (or (char=? ch c) (char=? ch #\space))) l)
                    (>= (string-count l (lambda (ch) (char=? ch c))) 3))))))

    (define (fence-marker line)
      ;; returns (fence-char . info-string) or #f
      (let* ((l (trim-left line))
             (n (string-length l)))
        (and (>= n 3)
             (let ((c (string-ref l 0)))
               (and (or (char=? c #\`) (char=? c #\~))
                    (>= (delim-run-len l 0 n c) 3)
                    (let ((len (delim-run-len l 0 n c)))
                      (cons c (string-trim-both (substring l len n)))))))))

    (define (fence-close? line fence-char)
      (let* ((l (trim-left line))
             (n (string-length l)))
        (and (>= n 3)
             (char=? (string-ref l 0) fence-char)
             (= (delim-run-len l 0 n fence-char) n))))

    (define (blockquote-line? line)
      (let ((l (trim-left line)))
        (and (> (string-length l) 0) (char=? (string-ref l 0) #\>))))

    (define (blockquote-strip line)
      (let* ((l (trim-left line))
             (l (substring l 1 (string-length l))))
        (if (and (> (string-length l) 0) (char=? (string-ref l 0) #\space))
            (substring l 1 (string-length l))
            l)))

    (define (bullet-content line)
      ;; returns content string or #f
      (let* ((l (trim-left line))
             (n (string-length l)))
        (and (>= n 2)
             (let ((c (string-ref l 0)))
               (and (or (char=? c #\-) (char=? c #\*) (char=? c #\+))
                    (char=? (string-ref l 1) #\space)
                    (string-trim-both (substring l 2 n)))))))

    (define (ordered-content line)
      ;; returns (start . content) or #f
      (let* ((l (trim-left line))
             (n (string-length l)))
        (let count ((i 0))
          (if (and (< i n) (char-numeric? (string-ref l i)))
              (count (+ i 1))
              (and (> i 0)
                   (< i n)
                   (or (char=? (string-ref l i) #\.) (char=? (string-ref l i) #\)))
                   (< (+ i 1) n)
                   (char=? (string-ref l (+ i 1)) #\space)
                   (cons (string->number (substring l 0 i))
                         (string-trim-both (substring l (+ i 2) n))))))))

    (define (block-start? line)
      (or (blank-line? line)
          (thematic-break? line)
          (atx-heading line)
          (fence-marker line)
          (blockquote-line? line)
          (bullet-content line)
          (ordered-content line)))

    (define (parse-markdown s)
      "Syntax: (parse-markdown s)
Library: (scm markdown)
Description: Parses the Markdown text in string s into a list of block nodes
  (an s-expression AST). See the library header for the supported subset and
  the node shapes. Use markdown->html to render the result, or walk the AST
  yourself to target another backend.
Example:
  (parse-markdown \"# Title\\n\\nHello **world**\")
    => ((heading 1 \"Title\") (paragraph \"Hello \" (strong \"world\")))"
      (let* ((lines (list->vector (string->lines s)))
             (n (vector-length lines)))
        (define (ln i) (vector-ref lines i))
        (let loop ((i 0) (acc '()))
          (if (>= i n)
              (reverse acc)
              (let ((line (ln i)))
                (cond
                  ((blank-line? line) (loop (+ i 1) acc))
                  ((thematic-break? line) (loop (+ i 1) (cons '(thematic-break) acc)))
                  ((atx-heading line)
                   => (lambda (h)
                        (loop (+ i 1)
                              (cons (cons 'heading (cons (car h) (parse-inlines (cdr h)))) acc))))
                  ((fence-marker line)
                   => (lambda (f)
                        (let ((res (collect-fence lines n i (car f) (cdr f))))
                          (loop (cdr res) (cons (car res) acc)))))
                  ((blockquote-line? line)
                   (let ((res (collect-blockquote lines n i)))
                     (loop (cdr res) (cons (car res) acc))))
                  ((or (bullet-content line) (ordered-content line))
                   (let ((res (collect-list lines n i)))
                     (loop (cdr res) (cons (car res) acc))))
                  (else
                   (let ((res (collect-paragraph lines n i)))
                     (loop (cdr res) (cons (car res) acc))))))))))

    (define (collect-fence lines n start fence-char info)
      (let loop ((i (+ start 1)) (body '()))
        (cond
          ((>= i n)
           (cons (list 'code-block (if (string=? info "") #f info)
                       (string-join (reverse body) "\n"))
                 i))
          ((fence-close? (vector-ref lines i) fence-char)
           (cons (list 'code-block (if (string=? info "") #f info)
                       (string-join (reverse body) "\n"))
                 (+ i 1)))
          (else (loop (+ i 1) (cons (vector-ref lines i) body))))))

    (define (collect-blockquote lines n start)
      (let loop ((i start) (body '()))
        (if (and (< i n) (blockquote-line? (vector-ref lines i)))
            (loop (+ i 1) (cons (blockquote-strip (vector-ref lines i)) body))
            (cons (cons 'blockquote (parse-markdown (string-join (reverse body) "\n")))
                  i))))

    (define (collect-list lines n start)
      (let ((ordered (and (ordered-content (vector-ref lines start)) #t)))
        (let loop ((i start) (items '()) (start-num #f))
          (if (>= i n)
              (cons (finish-list ordered (reverse items) start-num) i)
              (let* ((line (vector-ref lines i))
                     (b (and (not ordered) (bullet-content line)))
                     (o (and ordered (ordered-content line))))
                (cond
                  (b (loop (+ i 1) (cons (cons 'item (parse-inlines b)) items) start-num))
                  (o (loop (+ i 1)
                           (cons (cons 'item (parse-inlines (cdr o))) items)
                           (or start-num (car o))))
                  (else (cons (finish-list ordered (reverse items) start-num) i))))))))

    (define (finish-list ordered items start-num)
      (if ordered
          (cons 'ordered-list (cons (or start-num 1) items))
          (cons 'bullet-list items)))

    (define (collect-paragraph lines n start)
      (let loop ((i start) (body '()))
        (if (and (< i n) (not (block-start? (vector-ref lines i))))
            (loop (+ i 1) (cons (string-trim-both (vector-ref lines i)) body))
            (cons (cons 'paragraph (parse-inlines (string-join (reverse body) " ")))
                  i))))

    ;; ---- HTML rendering --------------------------------------------

    (define (esc-text s)
      (let ((out (open-output-string)))
        (string-for-each
          (lambda (c)
            (cond
              ((char=? c #\&) (write-string "&amp;" out))
              ((char=? c #\<) (write-string "&lt;" out))
              ((char=? c #\>) (write-string "&gt;" out))
              (else (write-char c out))))
          s)
        (get-output-string out)))

    (define (esc-attr s)
      (let ((out (open-output-string)))
        (string-for-each
          (lambda (c)
            (cond
              ((char=? c #\&) (write-string "&amp;" out))
              ((char=? c #\<) (write-string "&lt;" out))
              ((char=? c #\>) (write-string "&gt;" out))
              ((char=? c #\") (write-string "&quot;" out))
              (else (write-char c out))))
          s)
        (get-output-string out)))

    (define (render-inline node)
      (cond
        ((string? node) (esc-text node))
        ((pair? node)
         (case (car node)
           ((strong) (string-append "<strong>" (render-inlines (cdr node)) "</strong>"))
           ((emph)   (string-append "<em>" (render-inlines (cdr node)) "</em>"))
           ((code)   (string-append "<code>" (esc-text (cadr node)) "</code>"))
           ((link)   (string-append "<a href=\"" (esc-attr (caddr node)) "\">"
                                    (render-inlines (cadr node)) "</a>"))
           (else "")))
        (else "")))

    (define (render-inlines nodes)
      (apply string-append (map render-inline nodes)))

    (define (render-block node)
      (case (car node)
        ((heading)
         (let ((level (number->string (cadr node))))
           (string-append "<h" level ">" (render-inlines (cddr node)) "</h" level ">")))
        ((paragraph)
         (string-append "<p>" (render-inlines (cdr node)) "</p>"))
        ((code-block)
         (let ((info (cadr node)))
           (string-append "<pre><code"
                          (if info
                              (string-append " class=\"language-" (esc-attr info) "\"")
                              "")
                          ">" (esc-text (caddr node)) "</code></pre>")))
        ((blockquote)
         (string-append "<blockquote>\n" (render-blocks (cdr node)) "\n</blockquote>"))
        ((bullet-list)
         (string-append "<ul>\n" (render-items (cdr node)) "</ul>"))
        ((ordered-list)
         (let ((start (cadr node)))
           (string-append "<ol"
                          (if (and (number? start) (not (= start 1)))
                              (string-append " start=\"" (number->string start) "\"")
                              "")
                          ">\n" (render-items (cddr node)) "</ol>")))
        ((thematic-break) "<hr>")
        (else "")))

    (define (render-items items)
      (apply string-append
             (map (lambda (it) (string-append "<li>" (render-inlines (cdr it)) "</li>\n"))
                  items)))

    (define (render-blocks blocks)
      (string-join (map render-block blocks) "\n"))

    (define (markdown->html s)
      "Syntax: (markdown->html s)
Library: (scm markdown)
Description: Renders the Markdown text in string s to an HTML fragment (no
  surrounding <html>/<body>). Text and link URLs are HTML-escaped. See the
  library header for the supported Markdown subset.
Example:
  (markdown->html \"# Hi\\n\\nA *para*.\")
    => \"<h1>Hi</h1>\\n<p>A <em>para</em>.</p>\""
      (render-blocks (parse-markdown s)))
))

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
    ;;   - nested lists            by indentation (a deeper-indented item
    ;;                             starts a sub-list under the item above it)
    ;;   - thematic breaks         ---  ***  ___
    ;;   - paragraphs              (soft line breaks join with a space)
    ;;
    ;; Supported inline constructs:
    ;;   - code spans              `code` (and ``code with ` inside``)
    ;;   - strong                  **text**  __text__
    ;;   - emphasis                *text*    _text_
    ;;   - links                   [text](url) — URLs with an unsafe scheme
    ;;                             (javascript:, data:, ...) are dropped and
    ;;                             only the link text is rendered
    ;;   - backslash escapes       \* \_ \` \[ ...
    ;;   - hard line breaks        a line ending in a backslash \ or in two
    ;;                             or more spaces forces a <br>; the line
    ;;                             break is kept while the text stays in the
    ;;                             normal proportional font (unlike a fenced
    ;;                             code block, which keeps breaks but renders
    ;;                             in a monospace font)
    ;;
    ;; Not supported (by design — keep it small): setext headings,
    ;; reference links, images, raw HTML, tables, and the full CommonMark
    ;; emphasis flanking rules (a pragmatic approximation is used; intraword
    ;; underscores are treated as literal text). Blank lines terminate a
    ;; list, so only "tight" lists are produced.
    ;;
    ;; AST shape:
    ;;   block  = (heading <level> <inline> ...)
    ;;          | (paragraph <inline> ...)
    ;;          | (code-block <info-or-#f> <text>)
    ;;          | (blockquote <block> ...)
    ;;          | (bullet-list <item> ...)
    ;;          | (ordered-list <start> <item> ...)
    ;;          | (thematic-break)
    ;;   item   = (item <inline> ... <list-block> ...)  ; trailing sub-lists
    ;;            where <list-block> is a (bullet-list ...) / (ordered-list ...)
    ;;   inline = <string>                       ; literal text
    ;;          | (strong <inline> ...)
    ;;          | (emph   <inline> ...)
    ;;          | (code   <string>)
    ;;          | (link   (<inline> ...) <url>)
    ;;          | (break)                        ; hard line break -> <br>
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

    (define (line-indent line)
      ;; Number of leading-whitespace columns; a tab advances to the next
      ;; multiple of 4. Used to decide list nesting depth.
      (let ((n (string-length line)))
        (let loop ((i 0) (col 0))
          (if (< i n)
              (let ((c (string-ref line i)))
                (cond
                  ((char=? c #\space) (loop (+ i 1) (+ col 1)))
                  ((char=? c #\tab) (loop (+ i 1) (+ col (- 4 (modulo col 4)))))
                  (else col)))
              col))))

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

    (define (list-item line)
      ;; (type content start-num indent), where type is 'bullet or 'ordered
      ;; and start-num is #f for bullets; or #f when line is not a list item.
      (let ((o (ordered-content line)))
        (if o
            (list 'ordered (cdr o) (car o) (line-indent line))
            (let ((b (bullet-content line)))
              (and b (list 'bullet b #f (line-indent line)))))))

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
      ;; Parse one list whose items share the indentation of lines[start].
      ;; A line indented deeper than this level begins a nested list that
      ;; hangs off the item above it; a shallower or non-item line ends the
      ;; list. Returns (list-node . next-index).
      (let* ((first (list-item (vector-ref lines start)))
             (level (list-ref first 3))
             (ordered (eq? (car first) 'ordered)))
        (let loop ((i start) (items '()) (start-num #f))
          (let ((it (and (< i n) (list-item (vector-ref lines i)))))
            (if (and it
                     (eq? (eq? (car it) 'ordered) ordered)
                     (= (list-ref it 3) level))
                ;; A sibling item at this level. Consume it, then absorb any
                ;; deeper-indented lines that follow as nested child lists.
                (let ((content (cadr it))
                      (num (caddr it)))
                  (let gather ((j (+ i 1)) (children '()))
                    (let ((nx (and (< j n) (list-item (vector-ref lines j)))))
                      (if (and nx (> (list-ref nx 3) level))
                          (let ((sub (collect-list lines n j)))
                            (gather (cdr sub) (cons (car sub) children)))
                          (loop j
                                (cons (cons 'item
                                            (append (parse-inlines content)
                                                    (reverse children)))
                                      items)
                                (or start-num num))))))
                (cons (finish-list ordered (reverse items) start-num) i))))))

    (define (finish-list ordered items start-num)
      (if ordered
          (cons 'ordered-list (cons (or start-num 1) items))
          (cons 'bullet-list items)))

    (define (hard-break-line? raw)
      ;; A CommonMark hard line break: the raw line ends with a backslash or
      ;; with two or more spaces. The break is kept as a <br> while the text
      ;; stays in the normal proportional font.
      (let ((len (string-length raw)))
        (and (> len 0)
             (or (char=? (string-ref raw (- len 1)) #\\)
                 (and (>= len 2)
                      (char=? (string-ref raw (- len 1)) #\space)
                      (char=? (string-ref raw (- len 2)) #\space))))))

    (define (strip-hard-break raw)
      ;; The content of a hard-break line, with its trailing backslash marker
      ;; removed (trailing spaces are dropped by the trim).
      (let ((r (string-trim-right raw)))
        (string-trim-both
          (if (and (> (string-length r) 0)
                   (char=? (string-ref r (- (string-length r) 1)) #\\))
              (substring r 0 (- (string-length r) 1))
              r))))

    (define (paragraph-inlines raw-lines)
      ;; Group a paragraph's raw lines into segments separated by hard line
      ;; breaks. Within a segment, lines are joined with a space (soft break)
      ;; and parsed as one run of inlines; segments are joined by (break)
      ;; nodes. A trailing marker on the final line has no following line and
      ;; is ignored.
      (let loop ((lines raw-lines) (seg '()) (acc '()))
        (cond
          ((null? lines)
           (if (null? seg)
               acc
               (append acc (parse-inlines (string-join (reverse seg) " ")))))
          ((and (pair? (cdr lines)) (hard-break-line? (car lines)))
           (let ((seg (cons (strip-hard-break (car lines)) seg)))
             (loop (cdr lines) '()
                   (append acc
                           (parse-inlines (string-join (reverse seg) " "))
                           (list '(break))))))
          (else
           (loop (cdr lines)
                 (cons (string-trim-both (car lines)) seg)
                 acc)))))

    (define (collect-paragraph lines n start)
      (let loop ((i start) (body '()))
        (if (and (< i n) (not (block-start? (vector-ref lines i))))
            (loop (+ i 1) (cons (vector-ref lines i) body))
            (cons (cons 'paragraph (paragraph-inlines (reverse body)))
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

    (define (url-has-foreign-scheme? u)
      ;; #t when a ':' appears before the first '/', '?' or '#' — i.e. the
      ;; URL carries an explicit scheme rather than being relative.
      (let ((n (string-length u)))
        (let loop ((i 0))
          (and (< i n)
               (let ((c (string-ref u i)))
                 (cond
                   ((char=? c #\:) #t)
                   ((or (char=? c #\/) (char=? c #\?) (char=? c #\#)) #f)
                   (else (loop (+ i 1)))))))))

    (define (safe-url? raw)
      ;; Allow http(s), mailto, tel, ftp and scheme-less (relative) URLs.
      ;; Everything else — javascript:, data:, vbscript:, ... — is rejected
      ;; so markdown->html stays XSS-safe on untrusted input.
      (let* ((u (string-trim-both raw))
             (lc (string-downcase u)))
        (and (> (string-length u) 0)
             (or (string-prefix? "http://" lc)
                 (string-prefix? "https://" lc)
                 (string-prefix? "mailto:" lc)
                 (string-prefix? "tel:" lc)
                 (string-prefix? "ftp://" lc)
                 (not (url-has-foreign-scheme? u))))))

    (define (render-inline node)
      (cond
        ((string? node) (esc-text node))
        ((pair? node)
         (case (car node)
           ((strong) (string-append "<strong>" (render-inlines (cdr node)) "</strong>"))
           ((emph)   (string-append "<em>" (render-inlines (cdr node)) "</em>"))
           ((code)   (string-append "<code>" (esc-text (cadr node)) "</code>"))
           ((break)  "<br>")
           ((link)
            (let ((url (caddr node)))
              (if (safe-url? url)
                  (string-append "<a href=\"" (esc-attr url) "\">"
                                 (render-inlines (cadr node)) "</a>")
                  ;; Unsafe scheme: drop the anchor, keep the text.
                  (render-inlines (cadr node)))))
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

    (define (inline-node? x)
      (or (string? x)
          (and (pair? x) (memq (car x) '(strong emph code link break)))))

    (define (split-leading-inlines nodes)
      ;; An item's children are its inline content followed by any nested
      ;; list blocks. Split at the first block node.
      (let loop ((ns nodes) (inl '()))
        (if (and (pair? ns) (inline-node? (car ns)))
            (loop (cdr ns) (cons (car ns) inl))
            (values (reverse inl) ns))))

    (define (render-items items)
      (apply string-append
             (map (lambda (it)
                    (call-with-values
                      (lambda () (split-leading-inlines (cdr it)))
                      (lambda (inlines blocks)
                        (string-append
                          "<li>"
                          (render-inlines inlines)
                          (if (null? blocks)
                              ""
                              (string-append "\n" (render-blocks blocks) "\n"))
                          "</li>\n"))))
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

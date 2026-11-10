;; (scm html parser) — a forgiving HTML parser producing SXML.
;;
;; It reads HTML the way browsers do in the cases real pages need:
;; unclosed <p>, <li>, <td> ... are closed by what follows, stray end
;; tags are ignored, void elements need no end tag, the contents of
;; <script>, <style>, <textarea> and <title> are read as text, and
;; character references are decoded with the complete HTML5 list. A
;; document always becomes (html (head ...) (body ...)).
;;
;; Not done (the full HTML5 tree construction algorithm is much larger):
;; misnested formatting elements (<b><p>x</b>y</p>) are not reopened,
;; tables get no implied <tbody> and misplaced content is not moved out
;; of them, and SVG names are not restored to camel case (viewBox comes
;; out as viewbox).
(define-library (scm html parser)
  (import (scheme base)
          (scm html)
          (scm string))
  (export html->sxml
          html-fragment->sxml
          sxml-attribute
          sxml-attributes
          sxml-children
          sxml-find
          sxml-tag
          sxml-text)
  (begin

    ;; --- the tree while it is built ---------------------------------

    ;; kids are kept in reverse order until the tree is converted
    (define-record-type node
      (make-node tag attrs kids)
      node?
      (tag node-tag)
      (attrs node-attrs set-node-attrs!)
      (kids node-kids set-node-kids!))

    (define void-tags
      '("area" "base" "br" "col" "embed" "hr" "img" "input" "link" "meta"
        "param" "source" "track" "wbr" "keygen" "frame" "basefont" "bgsound"))

    ;; contents read as text, as they are
    (define raw-text-tags
      '("script" "style" "xmp" "iframe" "noembed" "noframes" "noscript"))

    ;; contents read as text, character references decoded
    (define escapable-text-tags '("title" "textarea"))

    ;; start tags that close an open <p>
    (define p-closers
      '("address" "article" "aside" "blockquote" "center" "details" "dialog"
        "dir" "div" "dl" "fieldset" "figcaption" "figure" "footer" "form" "h1"
        "h2" "h3" "h4" "h5" "h6" "header" "hgroup" "hr" "main" "menu" "nav"
        "ol" "p" "pre" "section" "table" "ul" "li" "dd" "dt" "listing"
        "plaintext" "search" "summary"))

    (define scope-boundaries
      '("html" "table" "td" "th" "caption" "marquee" "object" "applet"
        "template" "button" "svg" "math"))

    (define table-tags
      '("table" "thead" "tbody" "tfoot" "tr" "td" "th" "caption" "colgroup"))

    (define heading-tags '("h1" "h2" "h3" "h4" "h5" "h6"))

    (define head-tags
      '("meta" "link" "title" "script" "style" "base" "noscript" "template"
        "basefont" "bgsound"))

    ;; --- characters -------------------------------------------------

    (define (ws? c)
      (or (char=? c #\space)
          (char=? c #\tab)
          (char=? c #\newline)
          (char=? c #\return)
          (char=? c (integer->char 12))))

    (define (ascii-alpha? c)
      (or (and (char>=? c #\a) (char<=? c #\z))
          (and (char>=? c #\A) (char<=? c #\Z))))

    (define (ascii-downcase s)
      (string-map (lambda (c)
                    (if (and (char>=? c #\A) (char<=? c #\Z))
                        (integer->char (+ (char->integer c) 32))
                        c))
                  s))

    (define (blank? s)
      (let loop ((i 0))
        (or (= i (string-length s))
            (and (ws? (string-ref s i)) (loop (+ i 1))))))

    ;; CR LF and CR become LF, as the HTML input stream has them
    (define (normalize-newlines s)
      (if (string-contains-from s "\r" 0)
          (string-replace-all (string-replace-all s "\r\n" "\n") "\r" "\n")
          s))

    (define (find-char s ch start)
      (and (< start (string-length s))
           (string-contains-from s (string ch) start)))

    (define (starts-at? s str i)
      (let ((m (string-length str)))
        (and (<= (+ i m) (string-length s))
             (let cmp ((k 0))
               (or (= k m)
                   (and (char=? (string-ref s (+ i k)) (string-ref str k))
                        (cmp (+ k 1))))))))

    (define (find-string s str start)
      (and (<= start (string-length s)) (string-contains-from s str start)))

    ;; index of the "</tag" that ends a text element, or #f
    (define (find-end-tag s tag start)
      (let ((n (string-length s))
            (len (string-length tag)))
        (let loop ((i start))
          (let ((k (find-string s "</" i)))
            (cond ((not k) #f)
                  ((and (<= (+ k 2 len) n)
                        (string=? (ascii-downcase
                                   (substring s (+ k 2) (+ k 2 len)))
                                  tag)
                        (or (= (+ k 2 len) n)
                            (let ((c (string-ref s (+ k 2 len))))
                              (or (ws? c) (char=? c #\>) (char=? c #\/)))))
                   k)
                  (else (loop (+ k 2))))))))

    ;; --- tags -------------------------------------------------------

    (define (name-char? c) (not (or (ws? c) (char=? c #\>) (char=? c #\/))))

    ;; Reads the start tag whose name begins at j. Returns
    ;; (name attrs self-closing? next-index); attrs is an alist in source
    ;; order, the first of repeated names kept.
    (define (read-start-tag s j)
      (let* ((n (string-length s))
             (name-end (let loop ((k j))
                         (if (and (< k n) (name-char? (string-ref s k)))
                             (loop (+ k 1))
                             k)))
             (name (ascii-downcase (substring s j name-end))))
        (define (skip-ws k)
          (if (and (< k n) (ws? (string-ref s k))) (skip-ws (+ k 1)) k))
        (define (add name value attrs)
          (if (assoc name attrs) attrs (cons (cons name value) attrs)))
        (let loop ((k name-end) (attrs '()))
          (let ((k (skip-ws k)))
            (cond ((>= k n) (list name (reverse attrs) #f n))
                  ((char=? (string-ref s k) #\>)
                   (list name (reverse attrs) #f (+ k 1)))
                  ((char=? (string-ref s k) #\/)
                   (if (and (< (+ k 1) n) (char=? (string-ref s (+ k 1)) #\>))
                       (list name (reverse attrs) #t (+ k 2))
                       (loop (+ k 1) attrs)))
                  (else (let* ((ae (let scan ((m (+ k 1)))
                                     (if
                                      (and
                                       (< m n)
                                       (let ((c (string-ref s m)))
                                         (not
                                          (or (ws? c)
                                              (memv c '(#\= #\> #\/))))))
                                      (scan (+ m 1))
                                      m)))
                               (aname (ascii-downcase (substring s k ae)))
                               (m (skip-ws ae)))
                          (if (and (< m n) (char=? (string-ref s m) #\=))
                              (let ((v0 (skip-ws (+ m 1))))
                                (if (and (< v0 n)
                                         (memv (string-ref s v0) '(#\" #\')))
                                    (let
                                        ((ve
                                          (or
                                           (find-char s
                                                      (string-ref s v0)
                                                      (+ v0 1))
                                           n)))
                                      (loop
                                       (min n (+ ve 1))
                                       (add
                                        aname
                                        (html-unescape
                                         (substring s (+ v0 1) ve)
                                         #t)
                                        attrs)))
                                    (let
                                        ((ve
                                          (let scan ((v v0))
                                            (if
                                             (and
                                              (< v n)
                                              (not (ws? (string-ref s v)))
                                              (not
                                               (char=? (string-ref s v) #\>)))
                                             (scan (+ v 1))
                                             v))))
                                      (loop
                                       ve
                                       (add
                                        aname
                                        (html-unescape (substring s v0 ve) #t)
                                        attrs)))))
                              (loop m (add aname "" attrs))))))))))

    ;; --- tree construction ------------------------------------------

    ;; Parses s; returns the html node of a document, or the root node
    ;; holding a fragment.
    (define (parse s fragment?)
      (let* ((s (normalize-newlines s))
             (n (string-length s))
             (root (make-node "#root" '() '()))
             (html (make-node "html" '() '()))
             (head (make-node "head" '() '()))
             (body (make-node "body" '() '()))
             (in-body? fragment?)
             (stack (list (if fragment? root head))))
        (define (bottom? nd) (or (eq? nd root) (eq? nd head) (eq? nd body)))
        (define (current) (car stack))
        (define (append-kid! x)
          (set-node-kids! (current) (cons x (node-kids (current)))))
        (define (append-text! str)
          (unless (string=? str "")
            (let ((k (node-kids (current))))
              (if (and (pair? k) (string? (car k)))
                  (set-car! k (string-append (car k) str))
                  (append-kid! str)))))
        (define (to-body!)
          (set! in-body? #t)
          (set! stack (list body)))
        (define (merge-attrs! nd attrs)
          (set-node-attrs! nd
                           (append (node-attrs nd)
                                   (filter-attrs attrs (node-attrs nd)))))
        (define (open? tag boundaries)
          (let loop ((st stack))
            (cond ((bottom? (car st)) #f)
                  ((string=? (node-tag (car st)) tag) #t)
                  ((member (node-tag (car st)) boundaries) #f)
                  (else (loop (cdr st))))))
        (define (pop-until! tag)
          (let loop ()
            (unless (bottom? (current))
              (let ((t (node-tag (current))))
                (set! stack (cdr stack))
                (unless (string=? t tag) (loop))))))
        (define (close! tag boundaries)
          (when (open? tag boundaries) (pop-until! tag)))
        (define (foreign?)
          (let loop ((st stack))
            (and (pair? st)
                 (or (member (node-tag (car st)) '("svg" "math"))
                     (loop (cdr st))))))
        ;; -> the new node when it stays open (its contents follow), else #f
        (define (start-tag! name attrs self-closing?)
          (cond ((string=? name "html") (merge-attrs! html attrs) #f)
                ((string=? name "head")
                 (unless in-body? (merge-attrs! head attrs))
                 #f)
                ((string=? name "body")
                 (unless fragment?
                   (unless in-body? (to-body!))
                   (merge-attrs! body attrs))
                 #f)
                (else (when
                          (and (not in-body?)
                               (eq? (current) head)
                               (not (member name head-tags)))
                        (to-body!))
                      (let ((name (if (string=? name "image") "img" name)))
                        (when (member name p-closers)
                          (close! "p" scope-boundaries))
                        (cond ((string=? name "li")
                               (close! "li"
                                       (append '("ul" "ol")
                                               scope-boundaries)))
                              ((member name '("dd" "dt"))
                               (close! "dd" (cons "dl" scope-boundaries))
                               (close! "dt" (cons "dl" scope-boundaries)))
                              ((member name heading-tags)
                               (when
                                   (member (node-tag (current)) heading-tags)
                                 (pop-until! (node-tag (current)))))
                              ((member name '("td" "th"))
                               (close! "td" '("tr" "table"))
                               (close! "th" '("tr" "table")))
                              ((string=? name "tr") (close! "tr" '("table")))
                              ((member name '("thead" "tbody" "tfoot"))
                               (for-each (lambda (t) (close! t '("table")))
                                         '("thead" "tbody" "tfoot")))
                              ((member name '("option" "optgroup"))
                               (close! "option" '("select"))
                               (when (string=? name "optgroup")
                                 (close! "optgroup" '("select"))))
                              ((member name '("a" "button" "nobr"))
                               (close! name scope-boundaries)))
                        (let ((nd (make-node name attrs '())))
                          (append-kid! nd)
                          (if (or (member name void-tags)
                                  (and self-closing?
                                       (or (foreign?)
                                           (member name '("svg" "math")))))
                              #f
                              (begin
                                (set! stack (cons nd stack))
                                nd)))))))
        (define (end-tag! name)
          (cond ((string=? name "br") (start-tag! "br" '() #t))
                ((member name '("html" "head" "body")) #f)
                ((member name table-tags) (close! name '()))
                (else (close! name
                              '("table" "td" "th" "caption" "button" "object"
                                "template")))))
        (define (skip-past-gt i)
          (let ((e (find-char s #\> i))) (if e (+ e 1) n)))
        (define (text! str)
          (cond (in-body? (append-text! str))
                ((not (eq? (current) head)) (append-text! str))
                ((blank? str) #f)
                (else (to-body!) (append-text! str))))
        (let loop ((i 0))
          (when (< i n)
            (if (char=? (string-ref s i) #\<)
                (let ((c1 (if (< (+ i 1) n) (string-ref s (+ i 1)) #\space)))
                  (cond ((starts-at? s "<!--" i)
                         (let ((e (find-string s "-->" (+ i 4))))
                           (loop (if e (+ e 3) n))))
                        ((starts-at? s "<![CDATA[" i)
                         (let ((e (or (find-string s "]]>" (+ i 9)) n)))
                           (text! (substring s (+ i 9) e))
                           (loop (min n (+ e 3)))))
                        ((or (char=? c1 #\!) (char=? c1 #\?))
                         (loop (skip-past-gt i)))
                        ((char=? c1 #\/)
                         (let
                             ((c2 (if (< (+ i 2) n)
                                      (string-ref s (+ i 2))
                                      #\space)))
                           (if (ascii-alpha? c2)
                               (let
                                   ((e (let scan ((k (+ i 2)))
                                         (if
                                          (and (< k n)
                                               (name-char? (string-ref s k)))
                                          (scan (+ k 1))
                                          k))))
                                 (end-tag!
                                  (ascii-downcase (substring s (+ i 2) e)))
                                 (loop (skip-past-gt e)))
                               (loop (skip-past-gt i)))))
                        ((ascii-alpha? c1)
                         (let* ((tag (read-start-tag s (+ i 1)))
                                (name (car tag))
                                (next (list-ref tag 3))
                                (nd (start-tag! name
                                                (list-ref tag 1)
                                                (list-ref tag 2))))
                           (cond ((and nd
                                       (or (member name raw-text-tags)
                                           (member name escapable-text-tags)))
                                  (let*
                                      ((k (or (find-end-tag s name next) n))
                                       (text (substring s next k)))
                                    (append-text!
                                     (if (member name escapable-text-tags)
                                         (html-unescape text)
                                         text))
                                    (pop-until! name)
                                    (loop (if (< k n) (skip-past-gt k) n))))
                                 ;; a newline right after <pre> belongs to the markup
                                 ((and nd
                                       (member name '("pre" "listing"))
                                       (< next n)
                                       (char=? (string-ref s next) #\newline))
                                  (loop (+ next 1)))
                                 (else (loop next)))))
                        (else (text! "<") (loop (+ i 1)))))
                (let ((e (or (find-char s #\< i) n)))
                  (text! (html-unescape (substring s i e)))
                  (loop e)))))
        (if fragment?
            root
            (begin
              (set-node-kids! html (list body head))
              html))))

    (define (filter-attrs attrs existing)
      (let loop ((as attrs) (acc '()))
        (cond ((null? as) (reverse acc))
              ((assoc (caar as) existing) (loop (cdr as) acc))
              (else (loop (cdr as) (cons (car as) acc))))))

    (define (node->sxml nd)
      (let ((kids (map (lambda (k) (if (string? k) k (node->sxml k)))
                       (reverse (node-kids nd))))
            (attrs (node-attrs nd)))
        (cons (string->symbol (node-tag nd))
              (if (null? attrs)
                  kids
                  (cons (cons '@
                              (map (lambda (a)
                                     (list (string->symbol (car a)) (cdr a)))
                                   attrs))
                        kids)))))

    ;; --- entry points -----------------------------------------------

    (define (html->sxml s)
      "Syntax: (html->sxml string)
Library: (scm html parser)
Description: Parses the HTML document in string and returns it as SXML,
  in the shape (scm html builder) renders: (tag (@ (name \"value\") ...)
  child ...), tag and attribute names as lower-case symbols, attribute
  values and text as strings with character references decoded. Like a
  browser it always returns (html (head ...) (body ...)), puts head
  elements before the content into head, closes elements that the
  markup leaves open (<p>, <li>, <td> ...) and ignores stray end tags.
  The contents of script and style are kept as text; comments and the
  doctype are dropped. It accepts any input without raising an error.
Example:
  (html->sxml \"<title>T</title><p class=x>a<br>b<p>c &amp; d\")
  => (html (head (title \"T\"))
           (body (p (@ (class \"x\")) \"a\" (br) \"b\") (p \"c & d\")))"
      (node->sxml (parse s #f)))

    (define (html-fragment->sxml s)
      "Syntax: (html-fragment->sxml string)
Library: (scm html parser)
Description: Parses a piece of HTML (the content of an element, such as
  a comment someone wrote or an e-mail body) and returns the list of its
  top-level nodes: elements as in html->sxml, and strings. html, head
  and body tags in it are ignored. The list renders back with
  html->string.
Example:
  (html-fragment->sxml \"Hello <b>world</b><ul><li>a<li>b</ul>\")
  => (\"Hello \" (b \"world\") (ul (li \"a\") (li \"b\")))"
      (map (lambda (k) (if (string? k) k (node->sxml k)))
           (reverse (node-kids (parse s #t)))))

    ;; --- working with the tree --------------------------------------

    (define (sxml-tag node)
      "Syntax: (sxml-tag node)
Library: (scm html parser)
Description: The tag of the SXML element node as a symbol, or #f when
  node is text (a string) or not an element.
Example:
  (sxml-tag '(p (@ (class \"x\")) \"a\")) => p
  (sxml-tag \"a\") => #f"
      (and (pair? node) (symbol? (car node)) (car node)))

    (define (sxml-attributes node)
      "Syntax: (sxml-attributes node)
Library: (scm html parser)
Description: The attributes of the SXML element node as a list of (name
  value) lists, () when it has none.
Example:
  (sxml-attributes '(a (@ (href \"/x\") (id \"y\")) \"z\"))
  => ((href \"/x\") (id \"y\"))"
      (if (and (sxml-tag node)
               (pair? (cdr node))
               (pair? (cadr node))
               (eq? (car (cadr node)) '@))
          (cdr (cadr node))
          '()))

    (define (sxml-attribute node name)
      "Syntax: (sxml-attribute node name)
Library: (scm html parser)
Description: The value of attribute name (a symbol or string) of the
  SXML element node, or #f when it has no such attribute.
Example:
  (sxml-attribute '(a (@ (href \"/x\")) \"z\") 'href) => \"/x\"
  (sxml-attribute '(a \"z\") \"href\") => #f"
      (let* ((name (if (string? name) (string->symbol name) name))
             (a (assq name (sxml-attributes node))))
        (and a (pair? (cdr a)) (cadr a))))

    (define (sxml-children node)
      "Syntax: (sxml-children node)
Library: (scm html parser)
Description: The children (elements and strings) of the SXML element
  node, without its attributes; () for text.
Example:
  (sxml-children '(p (@ (class \"x\")) \"a\" (b \"c\"))) => (\"a\" (b \"c\"))"
      (cond ((not (sxml-tag node)) '())
            ((null? (sxml-attributes node))
             (if (and (pair? (cdr node))
                      (pair? (cadr node))
                      (eq? (car (cadr node)) '@))
                 (cddr node)
                 (cdr node)))
            (else (cddr node))))

    (define (sxml-text node)
      "Syntax: (sxml-text node)
Library: (scm html parser)
Description: The text of node: a string itself, an element the text of
  all its descendants in order (without the contents of script and
  style), a list of nodes their texts joined. White space is kept as it
  is.
Example:
  (sxml-text '(p \"a \" (b \"b\") (script \"x()\") \" c\")) => \"a b c\""
      (let ((out (open-output-string)))
        (let walk ((x node))
          (cond ((string? x) (write-string x out))
                ((sxml-tag x)
                 (unless (memq (car x) '(script style))
                   (for-each walk (sxml-children x))))
                ((pair? x) (for-each walk x))
                (else #f)))
        (get-output-string out)))

    (define (sxml-find node which)
      "Syntax: (sxml-find node which)
Library: (scm html parser)
Description: The elements in node (an element or a list of nodes),
  node itself included, in document order, that which selects: which is
  a tag (symbol or string) or a predicate on elements.
Example:
  (sxml-find (html->sxml \"<p>a <a href=x>b</a></p><a href=y>c</a>\") 'a)
  => ((a (@ (href \"x\")) \"b\") (a (@ (href \"y\")) \"c\"))
  (sxml-find doc (lambda (e) (sxml-attribute e 'id)))"
      (let ((match? (cond ((procedure? which) which)
                          ((string? which)
                           (let ((t (string->symbol which)))
                             (lambda (e) (eq? (car e) t))))
                          (else (lambda (e) (eq? (car e) which)))))
            (acc '()))
        (let walk ((x node))
          (cond ((sxml-tag x)
                 (when (match? x) (set! acc (cons x acc)))
                 (for-each walk (sxml-children x)))
                ((pair? x) (for-each walk x))
                (else #f)))
        (reverse acc)))))

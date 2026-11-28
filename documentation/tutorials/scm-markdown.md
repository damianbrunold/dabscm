---
title: (scm markdown): Markdown to HTML and beyond
part: libraries
order: 1018
libraries: (scm markdown)
summary: Rendering Markdown safely, the supported syntax, tables and heading anchors, the AST, writing your own renderers (plain text, a table of contents, link checks), Markdown in a web page.
---
# (scm markdown): Markdown to HTML and beyond

`(scm markdown)` turns Markdown into HTML, or into a tree you can walk to
produce anything else. It renders the pages of this documentation, these
tutorials included.

```scheme
(import (scheme base) (scheme write) (srfi 1) (srfi 13) (scm markdown))
```

## Rendering

```scheme
(markdown->html "# Shopping\n\nBuy **tea** and *cake*, see [the list](list.html).")
;; => "<h1>Shopping</h1>\n<p>Buy <strong>tea</strong> and <em>cake</em>, see <a href=\"list.html\">the list</a>.</p>"

(markdown->html "- tea\n- cake\n  (chocolate)")
;; => "<ul>\n<li>tea</li>\n<li>cake (chocolate)</li>\n</ul>"
```

Text is escaped, and links with dangerous schemes are not made links, so
Markdown from users (comments, descriptions) can be shown as it is:

```scheme
(markdown->html "1 < 2 & <script>alert(1)</script>")
;; => "<p>1 &lt; 2 &amp; &lt;script&gt;alert(1)&lt;/script&gt;</p>"
(markdown->html "[click](javascript:alert(1))") ;; => "<p>click</p>"
```

## What is supported

| Markdown | gives |
|---|---|
| `# Title` … `###### Title` | headings |
| blank-line separated text | paragraphs; two trailing spaces or `\` force a line break |
| `- item`, `* item`, `1. item` | lists, nested by indentation; an item may continue on the next lines |
| `> text` | block quotes |
| ```` ``` ```` fences, with a language | code blocks |
| `---` | a horizontal rule |
| `\| a \| b \|` with a `\|---\|---\|` row | tables, aligned with `:` |
| `**strong**`, `*emphasis*`, `` `code` ``, `[text](url)` | inline markup |

Images, raw HTML, reference links and setext headings (underlined with
`===`) are left out on purpose: the subset is small and predictable.

## Tables and heading anchors

```scheme
(markdown->html "| tea | price |\n|:--|--:|\n| green | 4.50 |")
;; => "<table>\n<thead>\n<tr><th style=\"text-align: left\">tea</th><th style=\"text-align: right\">price</th></tr>\n</thead>\n<tbody>\n<tr><td style=\"text-align: left\">green</td><td style=\"text-align: right\">4.50</td></tr>\n</tbody>\n</table>"

(markdown->html "## Next steps" 'heading-ids)
;; => "<h2 id=\"next-steps\">Next steps</h2>"
```

With `'heading-ids`, headings get the ids GitHub gives them, so links like
`page.html#next-steps` work.

## The tree

`parse-markdown` returns the blocks of the document as lists:

```scheme
(parse-markdown "# Teas\n\nWe sell *green* tea.\n\n1. Sencha\n2. Matcha\n\n```scheme\n(brew 'sencha)\n```")
;; => ((heading 1 "Teas") (paragraph "We sell " (emph "green") " tea.") (ordered-list 1 (item "Sencha") (item "Matcha")) (code-block "scheme" "(brew 'sencha)"))
```

Blocks are `heading`, `paragraph`, `bullet-list`, `ordered-list` (with the
start number), `blockquote`, `code-block` (language or `#f`, text),
`thematic-break` and `table`. Inside them, text is strings and `strong`,
`emph`, `code`, `link` (text, URL) and `break` nodes. A list item holds
its text followed by any nested lists.

## A plain-text renderer

Walking the tree gives other output formats. Plain text, for e-mails or a
terminal:

```scheme
(define (inline->text x)
  (cond ((string? x) x)
        ((eq? (car x) 'link)
         (string-append (inlines->text (cadr x)) " <" (caddr x) ">"))
        ((eq? (car x) 'break) "\n")
        ((eq? (car x) 'code) (cadr x))
        (else (inlines->text (cdr x)))))

(define (inlines->text xs) (apply string-append (map inline->text xs)))

(define (block->text b)
  (case (car b)
    ((heading) (let ((t (inlines->text (cddr b))))
                 (string-append t "\n" (make-string (string-length t) (if (= (cadr b) 1) #\= #\-)))))
    ((paragraph) (inlines->text (cdr b)))
    ((bullet-list) (string-join (map (lambda (it) (string-append "* " (item->text it))) (cdr b)) "\n"))
    ((ordered-list)
     (string-join (map (lambda (it n) (string-append (number->string n) ". " (item->text it)))
                       (cddr b) (iota (length (cddr b)) (cadr b)))
                  "\n"))
    ((code-block) (string-join (map (lambda (l) (string-append "    " l))
                                    (string-tokenize (caddr b) (char-set-complement (char-set #\newline))))
                               "\n"))
    (else "")))

(define (item->text it)
  (inlines->text (filter (lambda (x) (or (string? x) (memq (car x) '(strong emph code link break)))) (cdr it))))

(define (markdown->text md)
  (string-join (map block->text (parse-markdown md)) "\n\n"))

(display (markdown->text "# Order 42\n\nThanks for buying **tea**, see [your account](https://shop.example/me).\n\n1. Sencha\n2. Matcha"))
;; prints: Order 42
;; prints: ========
;; prints: 
;; prints: Thanks for buying tea, see your account <https://shop.example/me>.
;; prints: 
;; prints: 1. Sencha
;; prints: 2. Matcha
```

## A table of contents

The headings and `markdown-heading-id` give a table of contents that links
to the anchors `'heading-ids` creates:

```scheme
(define (toc md)
  (filter-map (lambda (b)
                (and (eq? (car b) 'heading) (> (cadr b) 1)
                     (let ((t (inlines->text (cddr b))))
                       (string-append (make-string (* 2 (- (cadr b) 2)) #\space)
                                      "- [" t "](#" (markdown-heading-id t) ")"))))
              (parse-markdown md)))

(toc "# Guide\n\n## Getting started\n\n### Installing on Linux\n\n## FAQ")
;; => ("- [Getting started](#getting-started)" "  - [Installing on Linux](#installing-on-linux)" "- [FAQ](#faq)")
```

The result is Markdown again, ready to be put in front of the document.

## Collecting links

Before publishing, list the links to check them:

```scheme
(define (links md)
  (define (walk x)
    (cond ((string? x) '())
          ((eq? (car x) 'link) (cons (caddr x) (append-map walk (cadr x))))
          ((eq? (car x) 'code-block) '())
          (else (append-map walk (filter pair? (cdr x))))))
  (append-map walk (parse-markdown md)))

(links "See [the guide](guide.html) and [Scheme](https://en.wikipedia.org/wiki/Scheme_(programming_language)).\n\n- [x](x.html)")
;; => ("guide.html" "https://en.wikipedia.org/wiki/Scheme_(programming_language)" "x.html")
```

## Markdown in a web page

Rendered Markdown is HTML that is safe to embed: insert it with `raw` from
[`(scm html builder)`](scm-html.md), which would otherwise escape it again:

```scheme
(import (scm html builder))

(define comment "Great **tea**! <b>really</b>")
(html->string `(article (@ (class "comment")) ,(raw (markdown->html comment))))
;; => "<article class=\"comment\"><p>Great <strong>tea</strong>! &lt;b&gt;really&lt;/b&gt;</p></article>"
```

## Where next

- [`(scm html)`](scm-html.md), `(scm ooxml word)` (the Word version of this
  documentation is rendered from the same tree).
- Reference: `(scm markdown)`.

---
title: (scm html), builder and parser: writing and reading HTML
part: libraries
order: 1019
libraries: (scm html) (scm html builder) (scm html parser)
summary: Escaping and unescaping, building pages from SXML with safe defaults, components as procedures, layouts, parsing real-world HTML, finding elements and text, scraping, rewriting a page.
---
# (scm html), builder and parser: writing and reading HTML

- `(scm html)`: escaping, unescaping, removing tags;
- `(scm html builder)`: HTML from trees, escaped by default;
- `(scm html parser)`: trees from HTML as browsers read it.

Both use the same tree form, SXML, so a parsed page can be changed and
written back.

```scheme
(import (scheme base) (scheme write) (srfi 1) (only (srfi 13) string-prefix?)
        (scm html) (scm html builder) (scm html parser))
```

## Escaping

```scheme
(html-escape "Fish & Chips <today>")        ;; => "Fish &amp; Chips &lt;today&gt;"
(html-attr-escape "say \"hi\"")             ;; => "say &quot;hi&quot;"
(html-unescape "caf&eacute; &amp; cr&#232;me &euro;5") ;; => "café & crème €5"
(strip-html-tags "<p>Hello   <b>world</b></p>") ;; => "Hello world"
```

Escaping is what stops injected scripts (cross-site scripting). It is easy
to forget with string concatenation, which is why the builder does it
for you.

## Building HTML

A tree is `(tag (@ (attribute value) ...) content ...)`; strings and
numbers in it are escaped:

```scheme
(html->string '(p (@ (class "note")) "Price: " (b 4.5) " < 5"))
;; => "<p class=\"note\">Price: <b>4.5</b> &lt; 5</p>"
(html->string '(p "line" (br) (img (@ (src "logo.png") (alt "")))))
;; => "<p>line<br><img src=\"logo.png\" alt=\"\"></p>"
(html->string '(input (@ (type "checkbox") (checked #t) (disabled #f))))
;; => "<input type=\"checkbox\" checked>"
```

`#t` writes a boolean attribute, `#f` leaves it out, and void elements
like `br` and `img` get no end tag.

User input stays text, whatever it contains:

```scheme
(define name "<script>steal()</script>")
(html->string `(p "Hello, " ,name))
;; => "<p>Hello, &lt;script&gt;steal()&lt;/script&gt;</p>"
```

HTML you trust (rendered Markdown, a snippet of your own) goes in `raw`.
That includes inline scripts and styles, whose contents the builder
escapes like any other text:

```scheme
(html->string `(div ,(raw "<em>trusted</em>")))
;; => "<div><em>trusted</em></div>"
(html->string `(script ,(raw "if (a < b) start();")))
;; => "<script>if (a < b) start();</script>"
```

## Components

Components are procedures that return trees. Quasiquote and `,@` splice
lists:

```scheme
(define (product-card p)
  `(div (@ (class "card"))
        (h3 ,(car p))
        (p (@ (class "price")) ,(number->string (cadr p)) " CHF")
        ,(and (caddr p) '(span (@ (class "badge")) "new"))))

(define (product-list products)
  `(ul ,@(map (lambda (p) `(li ,(product-card p))) products)))

(html->string (product-list '(("Sencha" 4.5 #t) ("Earl Grey" 3.9 #f))))
;; => "<ul><li><div class=\"card\"><h3>Sencha</h3><p class=\"price\">4.5 CHF</p><span class=\"badge\">new</span></div></li><li><div class=\"card\"><h3>Earl Grey</h3><p class=\"price\">3.9 CHF</p></div></li></ul>"
```

`#f` in a tree writes nothing, so optional parts are plain `and`/`if`.

## Pages

`html5` wraps head and body into a document with its doctype. A layout is
a component that takes the content:

```scheme
(define (layout title . content)
  (html5 `(head (meta (@ (charset "utf-8"))) (title ,title))
         `(body (header (a (@ (href "/")) "Teashop"))
                (main ,@content))))

(html->string (layout "Home" '(h1 "Welcome")))
;; => "<!doctype html>\n<html><head><meta charset=\"utf-8\"><title>Home</title></head><body><header><a href=\"/\">Teashop</a></header><main><h1>Welcome</h1></main></body></html>"
```

`html->port` writes to a port instead, for example straight into an HTTP
response.

## Parsing

`html->sxml` reads a page the way browsers do: missing end tags, unquoted
attributes and stray markup are all fine:

```scheme
(html->sxml "<title>Teas</title><p class=intro>Green<br>tea<p>Black &amp; strong")
;; => (html (head (title "Teas")) (body (p (@ (class "intro")) "Green" (br) "tea") (p "Black & strong")))

(html-fragment->sxml "Read <a href=/faq>the FAQ</a> &copy; 2025")
;; => ("Read " (a (@ (href "/faq")) "the FAQ") " © 2025")
```

A document always comes back as `(html (head ...) (body ...))`; a fragment
as a list of nodes. Tag and attribute names are lower-case symbols,
references are decoded.

## Finding things

```scheme
(define page (html->sxml "<html><head><title>Teashop</title></head><body>
<nav><a href=\"/\">Home</a> <a href=\"/teas\">Teas</a></nav>
<div id=\"main\"><h1>Our teas</h1>
<table><tr><td>Sencha</td><td>4.50</td></tr><tr><td>Matcha</td><td>12.00</td></tr></table>
<a href=\"https://tea.example\" rel=\"nofollow\">Supplier</a></div>
<script>track()</script></body></html>"))

(sxml-text (car (sxml-find page 'title)))  ;; => "Teashop"
(map (lambda (a) (sxml-attribute a 'href)) (sxml-find page 'a))
;; => ("/" "/teas" "https://tea.example")
(define main (car (sxml-find page (lambda (e) (equal? (sxml-attribute e 'id) "main")))))
(sxml-tag main)                             ;; => div
(sxml-text (car (sxml-find main 'h1)))      ;; => "Our teas"
(sxml-attributes (last (sxml-find page 'a))) ;; => ((href "https://tea.example") (rel "nofollow"))
```

`sxml-find` searches the whole tree by tag or by predicate. `sxml-text`
gives the text a reader sees, without the contents of `script` and
`style`.

## Example: scraping a table

```scheme
(define (table-rows tree)
  (map (lambda (tr) (map sxml-text (sxml-find tr 'td)))
       (sxml-find tree 'tr)))

(table-rows page)                           ;; => (("Sencha" "4.50") ("Matcha" "12.00"))
(map (lambda (row) (cons (car row) (string->number (cadr row)))) (table-rows page))
;; => (("Sencha" . 4.5) ("Matcha" . 12.0))
```

## Example: rewriting a page

Parse, change the tree, write it back. Here external links get
`target="_blank"` and `rel="noopener"`:

```scheme
(define (external? href)
  (and href (or (string-prefix? "http://" href) (string-prefix? "https://" href))))

(define (rewrite node)
  (cond ((not (pair? node)) node)
        ((eq? (car node) '@) node)
        ((and (eq? (car node) 'a) (external? (sxml-attribute node 'href)))
         `(a (@ ,@(sxml-attributes node) (target "_blank") (rel "noopener"))
             ,@(map rewrite (sxml-children node))))
        (else (cons (car node) (map rewrite (cdr node))))))

(html->string (map rewrite (html-fragment->sxml "<p>See <a href=\"/a\">a</a> and <a href=\"https://x.org\">x</a>.</p>")))
;; => "<p>See <a href=\"/a\">a</a> and <a href=\"https://x.org\" target=\"_blank\" rel=\"noopener\">x</a>.</p>"
```

The same pattern sanitizes HTML from outside: keep a list of allowed tags
and attributes, and turn everything else into its children or drop it.

## Where next

- [`(scm markdown)`](scm-markdown.md), `(scm net http server)` for serving
  pages, [`(scm xml)`](scm-xml.md) for XML (HTML is not XML).
- Reference: `(scm html)`, `(scm html builder)`, `(scm html parser)`.

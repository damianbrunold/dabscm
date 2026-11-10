## Overview

`(scm html parser)` reads HTML into SXML the way browsers read real pages:
end tags the markup leaves out are implied (`<p>`, `<li>`, `<td>`, `<option>` …),
stray end tags are ignored, void elements need no end tag, and the contents of
`<script>`, `<style>`, `<title>` and `<textarea>` are read as text. Character
references are decoded with the complete HTML5 list (see `html-unescape` in
`(scm html)`). It accepts any input without raising an error.

The tree has the shape `(scm html builder)` renders, so a parsed page can be
changed and written back with `html->string`:

- `"text"` — text, references decoded
- `(tag (@ (name "value") ...) child ...)` — an element; tag and attribute names
  are lower-case symbols, the `(@ ...)` list is left out when there are no
  attributes

## Common uses

```scheme
(import (scm html parser))

(html->sxml "<title>T</title><p class=x>a<br>b<p>c &amp; d")
;; => (html (head (title "T"))
;;          (body (p (@ (class "x")) "a" (br) "b") (p "c & d")))

(html-fragment->sxml "Hello <b>world</b><ul><li>a<li>b</ul>")
;; => ("Hello " (b "world") (ul (li "a") (li "b")))
```

A document always comes back as `(html (head ...) (body ...))`: head elements
before the content go into `head`, everything else into `body`. A fragment (the
content of an element, such as a comment or an e-mail body) comes back as the list
of its top-level nodes.

The tree helpers find elements and read them:

```scheme
(define doc (html->sxml page))

(map (lambda (a) (sxml-attribute a 'href)) (sxml-find doc 'a))   ;; all links
(sxml-text (car (sxml-find doc 'title)))                           ;; the title
(sxml-find doc (lambda (e) (equal? (sxml-attribute e 'id) "main")))
(sxml-children (car (sxml-find doc 'ul)))                          ;; its items
```

`sxml-text` leaves out the contents of `script` and `style`, so it gives the text
a reader sees (white space as it is in the source).

## Limits

The parser follows the HTML5 tree construction rules where pages depend on them,
not in full: formatting elements closed in the wrong order (`<b><p>x</b>y</p>`)
are not reopened, tables get no implied `<tbody>` and content misplaced in a table
is not moved before it, and SVG names are not restored to camel case (`viewBox`
comes out as `viewbox`). A `/` before `>` closes an element only in SVG and
MathML, as in browsers.

# `(scm html parser)`

Forgiving HTML parser producing SXML, as browsers read pages

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


## Exports

### `html->sxml`

```
Syntax: (html->sxml string)
Library: (scm html parser)
Description: Parses the HTML document in string and returns it as SXML,
  in the shape (scm html builder) renders: (tag (@ (name "value") ...)
  child ...), tag and attribute names as lower-case symbols, attribute
  values and text as strings with character references decoded. Like a
  browser it always returns (html (head ...) (body ...)), puts head
  elements before the content into head, closes elements that the
  markup leaves open (<p>, <li>, <td> ...) and ignores stray end tags.
  The contents of script and style are kept as text; comments and the
  doctype are dropped. It accepts any input without raising an error.
Example:
  (html->sxml "<title>T</title><p class=x>a<br>b<p>c &amp; d")
  => (html (head (title "T"))
           (body (p (@ (class "x")) "a" (br) "b") (p "c & d")))
```

### `html-fragment->sxml`

```
Syntax: (html-fragment->sxml string)
Library: (scm html parser)
Description: Parses a piece of HTML (the content of an element, such as
  a comment someone wrote or an e-mail body) and returns the list of its
  top-level nodes: elements as in html->sxml, and strings. html, head
  and body tags in it are ignored. The list renders back with
  html->string.
Example:
  (html-fragment->sxml "Hello <b>world</b><ul><li>a<li>b</ul>")
  => ("Hello " (b "world") (ul (li "a") (li "b")))
```

### `sxml-attribute`

```
Syntax: (sxml-attribute node name)
Library: (scm html parser)
Description: The value of attribute name (a symbol or string) of the
  SXML element node, or #f when it has no such attribute.
Example:
  (sxml-attribute '(a (@ (href "/x")) "z") 'href) => "/x"
  (sxml-attribute '(a "z") "href") => #f
```

### `sxml-attributes`

```
Syntax: (sxml-attributes node)
Library: (scm html parser)
Description: The attributes of the SXML element node as a list of (name
  value) lists, () when it has none.
Example:
  (sxml-attributes '(a (@ (href "/x") (id "y")) "z"))
  => ((href "/x") (id "y"))
```

### `sxml-children`

```
Syntax: (sxml-children node)
Library: (scm html parser)
Description: The children (elements and strings) of the SXML element
  node, without its attributes; () for text.
Example:
  (sxml-children '(p (@ (class "x")) "a" (b "c"))) => ("a" (b "c"))
```

### `sxml-find`

```
Syntax: (sxml-find node which)
Library: (scm html parser)
Description: The elements in node (an element or a list of nodes),
  node itself included, in document order, that which selects: which is
  a tag (symbol or string) or a predicate on elements.
Example:
  (sxml-find (html->sxml "<p>a <a href=x>b</a></p><a href=y>c</a>") 'a)
  => ((a (@ (href "x")) "b") (a (@ (href "y")) "c"))
  (sxml-find doc (lambda (e) (sxml-attribute e 'id)))
```

### `sxml-tag`

```
Syntax: (sxml-tag node)
Library: (scm html parser)
Description: The tag of the SXML element node as a symbol, or #f when
  node is text (a string) or not an element.
Example:
  (sxml-tag '(p (@ (class "x")) "a")) => p
  (sxml-tag "a") => #f
```

### `sxml-text`

```
Syntax: (sxml-text node)
Library: (scm html parser)
Description: The text of node: a string itself, an element the text of
  all its descendants in order (without the contents of script and
  style), a list of nodes their texts joined. White space is kept as it
  is.
Example:
  (sxml-text '(p "a " (b "b") (script "x()") " c")) => "a b c"
```


## Overview

`(scm markdown)` is a small, dependency-free Markdown parser and HTML renderer
covering a practical CommonMark subset. It has two entry points: `parse-markdown`
turns Markdown text into an s-expression AST you can walk, and `markdown->html`
renders that AST to an HTML fragment.

It is the engine behind this documentation site's library preambles, but it is
written to be reusable anywhere you need to turn Markdown into HTML or into your
own output format.

## Rendering Markdown to HTML

The common case is one call:

```scheme
(import (scm markdown))

(markdown->html "# Title\n\nHello **world** and `code`.")
;; => "<h1>Title</h1>\n<p>Hello <strong>world</strong> and <code>code</code>.</p>"
```

Text and link URLs are HTML-escaped for you, so user-supplied content is safe to
render.

## Walking the AST

When you want to target something other than HTML (a Word document, a terminal,
LaTeX, …), parse to the AST and walk it yourself:

```scheme
(parse-markdown "- one\n- two")
;; => ((bullet-list (item "one") (item "two")))

(parse-markdown "See [docs](http://example.com).")
;; => ((paragraph "See " (link ("docs") "http://example.com") "."))
```

Block nodes are `heading`, `paragraph`, `code-block`, `blockquote`,
`bullet-list`, `ordered-list`, `table` and `thematic-break`. Inline nodes are plain
strings plus `strong`, `emph`, `code` and `link`. See the library source header
for the exact shapes.

## Tables and heading anchors

GitHub-style pipe tables are supported, with column alignment from the
delimiter row:

```scheme
(markdown->html "| fruit | kg |\n|:--|--:|\n| apples | 3 |")
;; => "<table>\n<thead>\n<tr><th style=\"text-align: left\">fruit</th>..."

(parse-markdown "| a | b |\n|---|---|\n| 1 | 2 |")
;; => ((table (align #f #f) (header ("a") ("b")) (row ("1") ("2"))))
```

With the option `'heading-ids`, `markdown->html` gives every heading an `id`
as GitHub does, so that links like `page.html#next-steps` work;
`markdown-heading-id` computes such an id:

```scheme
(markdown->html "## Next steps" 'heading-ids)
;; => "<h2 id=\"next-steps\">Next steps</h2>"
```

## Supported subset

- ATX headings (`#` … `######`), with trailing `#`s stripped
- Fenced code blocks (` ``` ` or `~~~`) with an optional info/language string
- Bullet lists (`-`, `*`, `+`) and ordered lists (`1.` / `1)`)
- Blockquotes (`>`), parsed recursively
- Thematic breaks (`---`, `***`, `___`)
- Tables (`| a | b |` with a `|---|:-:|` delimiter row)
- Inline code, `**strong**`, `*emphasis*`, `[links](url)` and backslash escapes

By design it does **not** handle setext headings, reference links, images, raw
HTML or "loose" lists — keep the input simple and predictable.

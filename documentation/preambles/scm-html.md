## Overview

`(scm html)` provides the small, safety-critical HTML string operations: escaping
text and attribute values, decoding character references, and stripping tags from
a fragment. For building HTML from a tree see `(scm html builder)`, for reading
HTML into a tree `(scm html parser)`.

## Common uses

```scheme
(import (scm html))

(html-escape "a <b> & c")     ;; => "a &lt;b&gt; &amp; c"
(html-attr-escape "x\"y")     ;; => escaped for use in an attribute value

(strip-html-tags "<p>hello   <b>world</b></p>")   ;; => "hello world"
(strip-html-tags "plain")                          ;; => "plain"

(html-unescape "a &amp; b &auml; &#8364;")   ;; => "a & b ä €"
```

`strip-html-tags` removes tags and collapses whitespace, but does not decode HTML
entities — decode them with `html-unescape`, and escape again with `html-escape` if
you re-emit the result into HTML.

`html-unescape` decodes references as browsers do: all HTML5 named references,
numeric ones, and the legacy names that work without a semicolon (`&copy 2024`).
For attribute values pass `#t` as a second argument, which leaves `&copy=1` in a
URL alone.

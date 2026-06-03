## Overview

`(scm html)` provides the small, safety-critical HTML string operations: escaping
text and attribute values, and stripping tags from a fragment. For building HTML
from a tree see `(scm html builder)`.

## Common uses

```scheme
(import (scm html))

(html-escape "a <b> & c")     ;; => "a &lt;b&gt; &amp; c"
(html-attr-escape "x\"y")     ;; => escaped for use in an attribute value

(strip-html-tags "<p>hello   <b>world</b></p>")   ;; => "hello world"
(strip-html-tags "plain")                          ;; => "plain"
```

`strip-html-tags` removes tags and collapses whitespace, but does not decode HTML
entities — escape again with `html-escape` if you re-emit the result into HTML.

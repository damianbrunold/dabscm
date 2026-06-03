# `(scm html)`

HTML escaping and tag stripping

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


## Exports

### `html-attr-escape`

```
Syntax: (html-escape s)
Library: (scm html)
Description: Escapes the five HTML metacharacters (&, <, >, ", ') in s so the result is safe to splice into HTML text content or attribute values.
Example:
  (html-escape "a < b & c") => "a &lt; b &amp; c"
```

### `html-escape`

```
Syntax: (html-escape s)
Library: (scm html)
Description: Escapes the five HTML metacharacters (&, <, >, ", ') in s so the result is safe to splice into HTML text content or attribute values.
Example:
  (html-escape "a < b & c") => "a &lt; b &amp; c"
```

### `strip-html-tags`

```
Syntax: (strip-html-tags s)
Library: (scm html)
Description: Removes anything that looks like an HTML tag (text from < to >)
  and collapses runs of whitespace into single spaces. Intended for plain-text
  contexts like tooltip values where you want a readable string. Does NOT
  decode HTML entities — call html-escape afterwards if you re-emit into HTML.
Example:
  (strip-html-tags "<p>hello   <b>world</b></p>") => "hello world"
  (strip-html-tags "plain") => "plain"
```


# `(scm html)`

HTML escaping, unescaping and tag stripping

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

### `html-unescape`

```
Syntax: (html-unescape s [attribute?])
Library: (scm html)
Description: Decodes the character references in s as a browser does:
  all 2125 HTML5 named references (&amp; &auml; &rarr; ...), decimal
  and hexadecimal ones (&#228; &#xE4;; 128 to 159 as Windows-1252, 0,
  surrogates and values beyond U+10FFFF as U+FFFD), and the legacy names
  that work without a semicolon (&copy 2024). Anything else is left as
  it is. With attribute? true, s is an attribute value: a legacy name
  without semicolon followed by a letter, digit or = is not decoded
  (so &copy=1 in a URL stays).
Example:
  (html-unescape "a &amp; b &lt;&#228;&#xE4;&auml") => "a & b <äää"
  (html-unescape "&notin; &notit;") => "∉ ¬it;"
  (html-unescape "?a=1&copy=2" #t) => "?a=1&copy=2"
```

### `strip-html-tags`

```
Syntax: (strip-html-tags s)
Library: (scm html)
Description: Removes anything that looks like an HTML tag (text from < to >)
  and collapses runs of whitespace into single spaces. Intended for plain-text
  contexts like tooltip values where you want a readable string. Does NOT
  decode HTML entities (html-unescape does) — call html-escape afterwards if
  you re-emit into HTML.
Example:
  (strip-html-tags "<p>hello   <b>world</b></p>") => "hello world"
  (strip-html-tags "plain") => "plain"
```


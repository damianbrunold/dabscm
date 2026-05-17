# `(scm html builder)`

## Exports

### `html->port`

```
Syntax: (html->port port sxml)
Library: (scm html builder)
Description: Walks sxml and writes the HTML5 representation to port.
  Useful for streaming responses or appending to a larger string-port.
Example:
  (html->port (current-output-port) '(p "hi"))
```

### `html->string`

```
Syntax: (html->string sxml)
Library: (scm html builder)
Description: Walks sxml and returns the HTML5 representation as a string.
  String and number text is escaped automatically; (raw "...") wrappers
  pass through verbatim. Attribute values follow the same rules; an
  attribute whose value is #f is omitted, #t emits the name as a boolean
  attribute.
Example:
  (html->string `(p (@ (class "hi")) "hello " ,user))
  ;; → "<p class=\"hi\">hello &lt;input&gt;</p>" when user is "<input>"
```

### `html5`

```
Syntax: (html5 body ...)
Library: (scm html builder)
Description: Returns SXML for a complete HTML5 document. The body
  arguments are spliced into a single <html> element, prefixed by the
  HTML5 doctype declaration. Render with html->string or html->port.
Example:
  (html->string
    (html5 '(head (title "hi"))
           '(body (p "hello"))))
  ;; → "<!doctype html>\n<html><head><title>hi</title></head>..."
```

### `raw`

```
Syntax: (raw s)
Library: (scm html builder)
Description: Wraps a string so the HTML builder emits it verbatim, without
  escaping. Use for trusted HTML fragments (rendered markdown, server-
  generated SVG, content from another HTML builder pass). Passing user
  input through raw defeats the library's XSS protection — only use it
  with HTML you produced yourself.
Example:
  (html->string `(div ,(raw "<b>bold</b>"))) => "<div><b>bold</b></div>"
```

### `raw-value`

*(no documentation)*

### `raw?`

*(no documentation)*


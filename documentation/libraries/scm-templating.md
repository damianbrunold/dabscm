# `(scm templating)`

Text templating with variable substitution

## Overview

`(scm templating)` fills `{{placeholder}}` markers in a template string from a
context (an association list of name → value). It can render a template given
inline or from a file, and a reusable engine can be created for repeated use.

## Common uses

```scheme
(import (scm templating))

(template-render "Hello {{name}}!" (list (cons "name" "Ada")))
;; => "Hello Ada!"
```

Render a template stored in a file with `template-render-file`, or build a
reusable engine with `make-template-engine` and render through
`template-engine-render`.


## Exports

### `make-template-engine`

```
Syntax: (make-template-engine directory)
Library: (scm templating)
Description: A renderer for the templates in directory: use it with
  template-engine-render and a path relative to directory.
Example:
  (define engine (make-template-engine "templates"))
```

### `template-context`

```
Syntax: (template-context key value ...)
Library: (scm templating)
Description: An alist ((key . value) ...) from alternating keys and values,
  the context the render procedures take.
Example:
  (template-context 'name "Ada" 'year 1843) => ((name . "Ada") (year . 1843))
```

### `template-engine-render`

```
Syntax: (template-engine-render engine path context)
Library: (scm templating)
Description: Renders the template file path (relative to the engine's
  directory) with context, as template-render-file does.
Example:
  (template-engine-render engine "page.html" '((title . "News")))
```

### `template-render`

```
Syntax: (template-render template context)
Library: (scm templating)
Description: Fills the template string from context (an alist with symbol or
  string keys) and returns the result. {{a.b.0}} inserts a value, following
  keys and list/vector indexes (missing values give ""); {% for x in path %}
  ... {% endfor %} loops over a list or vector; {% if path %} ... {% else %}
  ... {% endif %} tests a value (false when missing, #f, empty or "");
  {% include "file" %} inserts a template file relative to the current
  directory. Values are inserted as they are, without HTML escaping.
Example:
  (template-render "Hello {{name}}!" '((name . "Ada"))) => "Hello Ada!"
```

### `template-render-file`

```
Syntax: (template-render-file path context)
Library: (scm templating)
Description: Like template-render, with the template read from the file at
  path; {% include %} paths are relative to its directory.
Example:
  (template-render-file "mail.txt" '((name . "Ada")))
```


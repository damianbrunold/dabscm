# `(scm geiser)`

## Exports

### `geiser:add-to-load-path`

```
Syntax: (geiser:add-to-load-path directory)
Library: (scm geiser)
Description: Geiser protocol entry point. Prepends directory to the module
search path.
```

### `geiser:autodoc`

```
Syntax: (geiser:autodoc ids)
Library: (scm geiser)
Description: Geiser protocol entry point for autodoc (echo-area signatures).
Given a list of operator symbols, returns their argument descriptions derived
from the documented Syntax: lines.
Example:
  (geiser:autodoc '(map))
```

### `geiser:completions`

```
Syntax: (geiser:completions prefix)
Library: (scm geiser)
Description: Geiser protocol entry point for identifier completion. Returns the
list of names visible in the current module that start with prefix.
Example:
  (geiser:completions "ca") => ("caar" "cadr" "car" "case" ...)
```

### `geiser:eval`

```
Syntax: (geiser:eval module form)
Library: (scm geiser)
Description: Geiser protocol entry point. Evaluates form in the namespace of
module (a library-name list, or #f for the REPL namespace) while capturing
default output, and returns an association list of the form
((result <printed-value>) (output . <captured-output>)) that the Geiser Emacs
frontend reads back. Evaluation errors are reported in the result instead of
being raised.
Example:
  (geiser:eval #f '(+ 1 2)) => ((result "3") (output . ""))
```

### `geiser:load-file`

```
Syntax: (geiser:load-file path)
Library: (scm geiser)
Description: Geiser protocol entry point used when loading a file from Emacs.
Loads path while capturing output and returns the same retort alist as
geiser:eval.
Example:
  (geiser:load-file "foo.scm")
```

### `geiser:macroexpand`

```
Syntax: (geiser:macroexpand form)
Library: (scm geiser)
Description: Geiser protocol entry point for macro expansion. Returns the fully
expanded form rendered as a string.
Example:
  (geiser:macroexpand '(when #t 1)) => "(if #t (begin 1) )"
```

### `geiser:module-completions`

```
Syntax: (geiser:module-completions prefix)
Library: (scm geiser)
Description: Geiser protocol entry point for module-name completion. Returns the
list of loaded module names (as written strings) starting with prefix.
Example:
  (geiser:module-completions "(scheme") => ("(scheme base)" ...)
```

### `geiser:module-exports`

```
Syntax: (geiser:module-exports module)
Library: (scm geiser)
Description: Geiser protocol entry point for the module browser. Returns the
exported bindings of module grouped into procs/syntax/vars.
```

### `geiser:module-location`

```
Syntax: (geiser:module-location module)
Library: (scm geiser)
Description: Geiser protocol entry point for jumping to a module definition. Not
tracked in this implementation; always returns the empty list.
```

### `geiser:newline`

```
Syntax: (geiser:newline)
Library: (scm geiser)
Description: Geiser protocol entry point. Writes a newline to the current output
port.
```

### `geiser:no-values`

```
Syntax: (geiser:no-values)
Library: (scm geiser)
Description: Geiser protocol entry point representing the absence of a value.
Returns an unspecified value.
```

### `geiser:symbol-location`

```
Syntax: (geiser:symbol-location symbol)
Library: (scm geiser)
Description: Geiser protocol entry point for jumping to a definition. Per-symbol
source locations are not tracked in this implementation, so this always returns
the empty list (Geiser then reports no location).
```


## Overview

`(scm source)` reads Scheme source text into a concrete syntax tree (CST)
that keeps everything the ordinary reader throws away: `;`, `#| |#` and
`#;` comments, the exact spelling of every atom (`#x1F`, `|a b|`,
`#\space`, here-strings), bracket style and the whitespace in front of each
node. Writing the tree back with `cst->string` gives the original text byte
for byte. It is the basis of `scm fmt` ([(scm source format)](scm-source-format.md))
and `scm lint` ([(scm source lint)](scm-source-lint.md)), and also offers
what both tools share: finding source files, reading `scm-tools.toml` and
resolving what an import set makes visible.

Every node has a kind (`file`, `list`, `vector`, `bytevector`, `prefix`,
`label`, `datum-comment`, `atom`, `dot`, `comment`, `block-comment`,
`directive`), its own text, a start position (line from 1, column from 0),
the whitespace before it, its children and, for containers, the closing
delimiter with the whitespace before it.

## Common uses

Walk the top-level forms of a file with their positions and comments:

```scheme
(import (scm source))

(for-each (lambda (node)
            (display (list (cst-kind node) (cst-line node) (cst-col node)))
            (newline))
          (cst-children (source-read-file "app.sld")))
```

Get the datums back, exactly as `read` would see them:

```scheme
(cst->datum (source-read-string "(a #;b c) ; done"))  ;; => ((a c))
```

Read errors carry the position:

```scheme
(guard (e ((source-read-error-position e) => (lambda (pos) pos)))
  (source-read-string "(define (f x)" "f.scm"))
;; => ("f.scm" 1 0)
```

What an import makes visible (built-in libraries are loaded, project
libraries are read statically from their `.sld` files):

```scheme
(define cache (make-import-cache '("src")))
(map import-binding-name
     (import-set-bindings '(only (scheme base) car cdr) cache))
;; => (car cdr)
```

## Tool configuration: scm-tools.toml

`scm fmt` and `scm lint` take their settings from the nearest
`scm-tools.toml` in the file's directory or a parent directory
(`tools-config`). Paths in it are relative to the file's directory:

```toml
exclude = ["generated/**", "vendor/**"]   # both tools skip these

[format]
width = 78
keep-breaks = false
sort-imports = true
sort-exports = true
library-path = ["src"]          # where project libraries' .sld files are

[format.indent]                 # body indentation of your own macros
"with-db-tx" = 1                # 1 distinguished argument, then the body
"router-add!" = 3

[lint]
disable = ["if-without-else"]
enable = ["unused-parameter"]
docstring-libraries = ["scm"]   # (scm ...) exports need docstrings
exclude = ["tests/fixtures/**"]
```

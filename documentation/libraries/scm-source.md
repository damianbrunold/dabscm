# `(scm source)`

Lossless Scheme source reader (CST with comments), import resolution, tool config

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


## Exports

### `collect-source-files`

```
Syntax: (collect-source-files paths [excludes])
Library: (scm source)
Description: Expands the list paths into the Scheme source files a tool
  should process. A file is taken as it is; a directory is searched
  recursively for *.scm and *.sld files, skipping hidden directories and
  build, dist, node_modules, bin and obj. excludes is a list of glob
  patterns matched against the path relative to the directory given and
  against the base name; matching files and directories are left out.
  The result keeps the order of paths, each directory's files sorted.
Example:
  (collect-source-files '("src" "main.scm") '("*-generated.sld"))
    => ("src/a.sld" "src/sub/b.scm" "main.scm")
```

### `cst->datum`

```
Syntax: (cst->datum node)
Library: (scm source)
Description: Returns the datum node denotes, as the ordinary reader would
  read it. For a file node, returns the list of its top-level datums.
  Comment nodes have no datum; for them the result is the eof object.
Example:
  (cst->datum (car (cst-children (source-read-string "'(a #;b c)"))))
    => (quote (a c))
```

### `cst->string`

```
Syntax: (cst->string node)
Library: (scm source)
Description: Writes node back as source text. For a file node read by
  source-read-string this is exactly the original text. The node's own
  pre whitespace is not included; that of its children is.
Example:
  (cst->string (source-read-string "(a  [b] ; c\n)")) => "(a  [b] ; c\n)"
```

### `cst-children`

*(no documentation)*

### `cst-close`

*(no documentation)*

### `cst-code?`

```
Syntax: (cst-code? node)
Library: (scm source)
Description: Returns #t if node denotes a datum (anything but a comment,
  a directive or the dot of a dotted list).
Example:
  (cst-code? (car (cst-children (source-read-string "42")))) => #t
```

### `cst-col`

*(no documentation)*

### `cst-comment?`

```
Syntax: (cst-comment? node)
Library: (scm source)
Description: Returns #t if node is a comment of any kind (; comment,
  #| |# block comment, #; datum comment) or a #! directive, that is a
  node with no datum of its own.
Example:
  (cst-comment? (car (cst-children (source-read-string "; x")))) => #t
```

### `cst-container?`

```
Syntax: (cst-container? node)
Library: (scm source)
Description: Returns #t if node is a list, vector or bytevector.
Example:
  (cst-container? (car (cst-children (source-read-string "#(1 2)")))) => #t
```

### `cst-kind`

*(no documentation)*

### `cst-line`

*(no documentation)*

### `cst-newlines-before`

```
Syntax: (cst-newlines-before node)
Library: (scm source)
Description: Returns the number of line breaks in the whitespace in front
  of node: 0 if it is on the same line as what precedes it, 2 or more if
  a blank line separates them.
Example:
  (map cst-newlines-before
       (cst-children (source-read-string "a b\n\nc")))
    => (0 0 2)
```

### `cst-node?`

*(no documentation)*

### `cst-pre`

*(no documentation)*

### `cst-text`

*(no documentation)*

### `cst-trailing-comment?`

```
Syntax: (cst-trailing-comment? node)
Library: (scm source)
Description: Returns #t if node is a ; comment that follows other code on
  the same line (an end-of-line comment), #f for a comment on a line of
  its own and for every other node.
Example:
  (map cst-trailing-comment?
       (cst-children (source-read-string "(a) ; x\n; y")))
    => (#f #t #f)
```

### `import-binding-kind`

```
Syntax: (import-binding-kind binding)
Library: (scm source)
Description: Returns what an import binding (from import-set-bindings)
  is: syntax (a macro or core form), procedure, value or unknown.
Example:
  (import-binding-kind (car (import-set-bindings '(only (scheme base) when)
                                                  (make-import-cache '()))))
    => syntax
```

### `import-binding-library`

```
Syntax: (import-binding-library binding)
Library: (scm source)
Description: Returns the name of the library that defines an import
  binding (from import-set-bindings); for a re-exported name this is the
  library it comes from originally, when that is known.
Example:
  (import-binding-library (car (import-set-bindings '(only (scheme base) car)
                                                     (make-import-cache '()))))
    => (scheme base)
```

### `import-binding-name`

```
Syntax: (import-binding-name binding)
Library: (scm source)
Description: Returns the name an import binding (from
  import-set-bindings) makes visible, a symbol.
Example:
  (import-binding-name (car (import-set-bindings '(only (scheme base) car)
                                                  (make-import-cache '()))))
    => car
```

### `import-set-bindings`

```
Syntax: (import-set-bindings import-set cache)
Library: (scm source)
Description: Returns the bindings an import set (a datum such as
  (scheme base) or (only (srfi 1) fold)) makes visible, as a list of
  vectors #(name library original-name kind), kind being syntax,
  procedure, value or unknown. Returns #f when the library cannot be
  found or its exports cannot be determined statically. cache comes from
  make-import-cache.
Example:
  (map import-binding-name
       (import-set-bindings '(only (scheme base) car) (make-import-cache '())))
    => (car)
```

### `library-file-name`

```
Syntax: (library-file-name name)
Library: (scm source)
Description: Returns the file name a library name maps to: its parts
  joined with - plus .sld.
Example:
  (library-file-name '(scm net http)) => "scm-net-http.sld"
```

### `make-cst-node`

*(no documentation)*

### `make-import-cache`

```
Syntax: (make-import-cache lib-dirs)
Library: (scm source)
Description: Returns a cache for import-set-bindings that finds the
  .sld files of non-built-in libraries in the list of directories
  lib-dirs (the module search path is searched as well).
Example:
  (make-import-cache '("src"))
```

### `same-import-binding?`

```
Syntax: (same-import-binding? a b)
Library: (scm source)
Description: Returns #t if the import bindings a and b (from
  import-set-bindings) certainly denote the same binding: the same
  library and original name, or for built-in libraries the identical
  value. #f means different or unknown.
Example:
  (let ((c (make-import-cache '())))
    (same-import-binding? (car (import-set-bindings '(only (scheme base) car) c))
                          (car (import-set-bindings '(only (scm core) car) c))))
    => #t
```

### `source-read-error-position`

```
Syntax: (source-read-error-position obj)
Library: (scm source)
Description: Returns (file line col) when obj is an error raised by
  source-read-string or source-read-file, otherwise #f. line counts from
  1, col from 0.
Example:
  (guard (e (#t (source-read-error-position e)))
    (source-read-string "(a" "x.scm"))
    => ("x.scm" 1 0)
```

### `source-read-file`

```
Syntax: (source-read-file path)
Library: (scm source)
Description: Reads the Scheme source file at path (UTF-8) into a CST and
  returns its file node, like source-read-string. Read errors name path.
Example:
  (cst->string (source-read-file "lib.sld")) ; the file's text, unchanged
```

### `source-read-string`

```
Syntax: (source-read-string str [file])
Library: (scm source)
Description: Reads all of the Scheme source text str into a CST and
  returns its file node. Nothing is lost: comments, whitespace and the
  exact spelling of every atom are kept, so (cst->string (source-read-string
  s)) is s again. file (default "<string>") is only used in error
  messages. A malformed text (an unclosed list, an unexpected closing
  bracket, an unterminated string or comment) raises an error whose
  position source-read-error-position returns.
Example:
  (map cst-kind (cst-children (source-read-string "(a b) ; c")))
    => (list comment)
```

### `tools-config`

```
Syntax: (tools-config path)
Library: (scm source)
Description: Returns the configuration for the source tools (scm fmt,
  scm lint) that applies to the file or directory path: the parsed TOML
  of the nearest scm-tools.toml in path's directory or one of its
  parents, as an alist with string keys (see (scm toml)), plus the entry
  ("dir" . directory-of-the-config-file). Without a config file the
  result is (). Results are cached per directory.
Example:
  (tools-config-ref (tools-config "src/a.sld") '("format" "width") 78)
    => 78
```

### `tools-config-ref`

```
Syntax: (tools-config-ref cfg keys default)
Library: (scm source)
Description: Looks up the path of string keys in the alist cfg returned
  by tools-config and returns the value found, or default. TOML arrays
  come back as lists.
Example:
  (tools-config-ref '(("lint" ("disable" . #("x")))) '("lint" "disable") '())
    => ("x")
```

### `tools-excluded?`

```
Syntax: (tools-excluded? file section)
Library: (scm source)
Description: Returns #t if the scm-tools.toml that applies to file
  excludes it: the top-level exclude list or the one in the table named
  section ("format" or "lint"). Patterns are globs matched against
  the path relative to the config file's directory; "dir/**" excludes
  everything under dir.
Example:
  (tools-excluded? "scm-java/src/x.sld" "lint") => #t ; with exclude = ["scm-java/**"]
```


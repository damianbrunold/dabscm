# `(scm text)`

Text processing utilities — awk, sed, grep, cut, sort, diff, and more

## Overview

`(scm text)` is a toolbox of Unix-style text utilities — `grep`, `sed`, `awk`,
`cut`, `sort-lines`, `head`, `tail`, `uniq`, `wc`, `tr`, `diff`, `cat`, `tee`,
`hexdump`. Each takes a *source* that may be a filename string, a list of strings
(one per line), or an input port, so you can pipe data through them in Scheme.
Where a matching native tool is on PATH it may be used; pass `'pure` to force the
pure-Scheme path.

## Common uses

Working on a list of lines (no files needed):

```scheme
(import (scm text))

(grep "b" '("alpha" "beta" "bravo"))         ;; => ("beta" "bravo")
(sort-lines '("charlie" "alpha" "bravo"))    ;; => ("alpha" "bravo" "charlie")
(sed "a" "A" '("banana") 'pure)              ;; => ("bAnana")
```

Or against a file:

```scheme
(grep "ERROR" "log.txt" 'ignore-case 'line-number)
```

Options are trailing symbols (e.g. `'ignore-case`, `'invert-match`,
`'line-number`, `'count`) mirroring the familiar command-line flags.


## Exports

### `awk`

```
Syntax: (awk action src [option ...])
Library: (scm text)
Description: For each line of src, splits the line into fields and calls
  action with three arguments: the field list, the 1-based line number,
  and the original line. Returns the list of action results (with #f
  results filtered out, matching awk's pattern-action style where lines
  without a print produce no output).
  Options:
    '(delimiter . str) — field separator (default any run of whitespace)
    '(filter . pred)   — only call action when (pred fields line-no line)
                         returns true; equivalent to an awk pattern
Example:
  ;; print second field of each line
  (awk (lambda (fs n l) (list-ref fs 1)) "data.tsv")
  ;; filter and reformat /etc/passwd: name:uid for shells of /bin/bash
  (awk (lambda (fs n l)
         (string-append (list-ref fs 0) ":" (list-ref fs 2)))
       "/etc/passwd"
       '(delimiter . ":")
       `(filter . ,(lambda (fs n l)
                     (and (> (length fs) 6)
                          (string=? (list-ref fs 6) "/bin/bash")))))
```

### `cat`

```
Syntax: (cat src ...)
Library: (scm text)
Description: Returns the concatenated contents of all src arguments as a
  single string, joining lines with newline. Each src is a filename, port,
  or list of strings.
Example:
  (cat "a.txt" "b.txt")
```

### `cut`

```
Syntax: (cut src [option ...])
Library: (scm text)
Description: Selects fields from each line of src. Options:
  '(fields . (n ...)) — 1-based field indices to keep (required);
  '(delimiter . str) — field separator (default tab).
Example:
  (cut "/etc/passwd" '(fields . (1 3)) '(delimiter . ":"))
```

### `diff`

```
Syntax: (diff a b [option ...])
Library: (scm text)
Description: Compares two text inputs a and b and returns a unified-diff
  string (or #t when 'brief and inputs are identical, #f when different).
  a and b may each be a filename string, an input port, or a list of
  lines. Options:
    'unified                 — produce unified diff (default; -u)
    'brief                   — return #t/#f only (-q)
    'ignore-case             — case-insensitive comparison (-i)
    'ignore-whitespace       — ignore whitespace differences (-w, native only)
    '(context-lines . n)     — n lines of context (default 3, -U n)
    '(label-a . str)         — label for file a in the header
    '(label-b . str)         — label for file b in the header
    'pure                    — force pure-Scheme path (LCS-based)
  When the native diff command is on PATH and both inputs are filenames,
  diff shells out for full feature parity.
Example:
  (diff "old.txt" "new.txt")
  (diff a-lines b-lines 'brief)
```

### `grep`

```
Syntax: (grep pattern src [option ...])
Library: (scm text)
Description: Returns the list of lines in src matching pattern. src may
  be a filename string, a list of strings, or an input port. Options:
  'ignore-case (-i), 'invert-match (-v), 'line-number (-n) (returns
  (list line-no line) pairs), 'count (-c) (returns integer match count),
  'fixed-strings (-F) (literal match; this is also the default in pure
  mode), 'pure (force pure-Scheme path).
  When 'pure is not set and the native grep command is on PATH and src
  is a filename, grep shells out to it for full POSIX regex support.
Example:
  (grep "ERROR" "log.txt" 'ignore-case 'line-number)
```

### `head`

```
Syntax: (head src [option ...])
Library: (scm text)
Description: Returns the first n lines of src (default 10). Options:
  '(lines . n) sets the count.
Example:
  (head "log.txt" '(lines . 5))
```

### `hexdump`

```
Syntax: (hexdump bv [option ...])
Library: (scm text)
Description: Formats a bytevector as a canonical hex+ASCII dump (similar
  to xxd or hexdump -C), returning a string. Options:
    '(width . n)    — bytes per row (default 16)
    '(offset . n)   — starting offset for the address column (default 0)
    'no-ascii       — omit the trailing ASCII gutter
Example:
  (display (hexdump (string->utf8 "hello world")))
```

### `sed`

```
Syntax: (sed pattern replacement src [option ...])
Library: (scm text)
Description: Substitutes pattern with replacement in each line of src.
  Options: 'global (g flag, replace all occurrences per line; default is
  first occurrence only), 'ignore-case (i flag), 'pure (force pure path).
  When the native sed command is on PATH and 'pure is not set, sed shells
  out to it. The pure path treats pattern as a literal string.
Example:
  (sed "foo" "bar" "in.txt" 'global)
```

### `sort-lines`

```
Syntax: (sort-lines src [option ...])
Library: (scm text)
Description: Returns the lines of src sorted lexicographically. Options:
  'reverse (-r), 'numeric (-n), 'unique (-u).
  Named sort-lines (not sort) to avoid clashing with srfi 132 sort.
Example:
  (sort-lines "names.txt" 'reverse)
```

### `tail`

```
Syntax: (tail src [option ...])
Library: (scm text)
Description: Returns the last n lines of src (default 10). Options:
  '(lines . n) sets the count.
Example:
  (tail "log.txt" '(lines . 5))
```

### `tee`

```
Syntax: (tee text file ...)
Library: (scm text)
Description: Writes text (a string, or a list of strings joined by
  newline) to each file path, and returns text. Mirrors `tee` reading
  stdin and writing to multiple destinations.
Example:
  (tee "hello\n" "/tmp/a" "/tmp/b")
```

### `tr`

```
Syntax: (tr from to [option ...])
Library: (scm text)
Description: Returns a procedure that translates characters in a string:
  each char in `from` is replaced by the char at the same index in `to`.
  When called on a string, returns the translated string. Option 'delete
  drops chars in `from` instead (to may be "").
Example:
  ((tr "abc" "xyz") "banana") => "yxnxnx"
```

### `uniq`

```
Syntax: (uniq lines)
Library: (scm text)
Description: Returns lines with consecutive duplicates collapsed to a
  single entry. Matches the behavior of Linux uniq (input should usually
  be sorted first).
Example:
  (uniq '("a" "a" "b" "a")) => ("a" "b" "a")
```

### `wc`

```
Syntax: (wc src [option ...])
Library: (scm text)
Description: Returns an alist with keys lines, words, chars for src.
  Options: 'lines-only ('-l), 'words-only ('-w), 'chars-only ('-c) return
  just that integer instead of the full alist.
Example:
  (wc "log.txt") => ((lines . 1234) (words . 9876) (chars . 54321))
```


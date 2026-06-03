# `(scm string)`

Extended string operations — search, split, trim, convert

## Overview

`(scm string)` adds string operations that aren't in the SRFI-13 string library —
regular-expression matching and splitting, literal replace-all, and convenience
splitters. For standard, predicate-based string work prefer `(srfi 13)`; reach
for this library when you need regex or the line/field helpers.

## Common uses

Split on a regex (whitespace by default), or on a literal separator:

```scheme
(import (scm string))

(string-split "a b c")          ;; => ("a" "b" "c")
(string-split "a,b,c" ",")      ;; => ("a" "b" "c")
(string-split-char "a,b,,c" #\,);; => ("a" "b" "" "c")
(string-split-lines "a\nb\n")   ;; => ("a" "b" "")
```

Match a regular expression — the result is the full match followed by any groups,
or `#f`:

```scheme
(string-matches "abc123" "([a-z]+)([0-9]+)")  ;; => ("abc123" "abc" "123")
(string-matches "hello" "xyz")                ;; => #f
```

Replace every occurrence of a literal substring:

```scheme
(string-replace-all "a.b.c" "." "/")   ;; => "a/b/c"
```


## Exports

### `string-contains-from`

```
Syntax: (string-contains-from haystack needle start)
Library: (scm string)
Description: Returns the index in haystack at or after start where needle
  first occurs, or #f if it does not. Allocation-free char-by-char scan;
  suitable for parsers operating on large strings.
Example:
  (string-contains-from "hello world" "world" 0) => 6
  (string-contains-from "abcabc" "bc" 2) => 4
  (string-contains-from "abc" "xyz" 0) => #f
```

### `string-matches`

```
Syntax: (string-matches s pattern)
Library: (scm string)
Description: Matches the string s against the regular expression pattern. Returns a list of match strings (the full match followed by any groups) if successful, or #f if there is no match.
Example:
  (string-matches "hello" "hel+o") => ("hello")
  (string-matches "abc123" "([a-z]+)([0-9]+)") => ("abc123" "abc" "123")
  (string-matches "hello" "xyz") => #f
```

### `string-replace-all`

```
Syntax: (string-replace-all s pattern replacement)
Library: (scm string)
Description: Returns a new string with all occurrences of pattern in s replaced by replacement.
Example:
  (string-replace-all "hello world" "world" "there") => "hello there"
  (string-replace-all "aabbcc" "b" "x") => "aaxxcc"
```

### `string-replace-all-regex`

```
Syntax: (string-replace-all-regex s pattern replacement)
Library: (scm string)
Description: Returns a new string with all matches of the regular expression pattern in s replaced by replacement. The replacement may refer to captured groups with ~0 (the whole match), ~1, ~2, ... (parenthesized groups). Use ~~ for a literal tilde. References to groups that did not participate in the match expand to the empty string.
Example:
  (string-replace-all-regex "hello world" "o" "0") => "hell0 w0rld"
  (string-replace-all-regex "2024-01-31" "([0-9]+)-([0-9]+)-([0-9]+)" "~3.~2.~1") => "31.01.2024"
  (string-replace-all-regex "abc123def456" "[0-9]+" "#") => "abc#def#"
```

### `string-split`

```
Syntax: (string-split s pattern?)
Library: (scm string)
Description: Splits the string s at occurrences of the regular expression pattern and returns a list of the resulting substrings. Defaults to splitting on whitespace.
Example:
  (string-split "a b c") => ("a" "b" "c")
  (string-split "a,b,c" ",") => ("a" "b" "c")
```

### `string-split-char`

```
Syntax: (string-split-char s ch)
Library: (scm string)
Description: Splits string s into a list of substrings on every occurrence of
  character ch. Adjacent delimiters produce empty strings; the result always
  has at least one element.
Example:
  (string-split-char "a,b,,c" #\,) => ("a" "b" "" "c")
  (string-split-char "" #\,) => ("")
```

### `string-split-lines`

```
Syntax: (string-split-lines s)
Library: (scm string)
Description: Splits string s into lines on newline (LF), dropping a trailing
  carriage return (CR) on each line. Empty lines are preserved.
Example:
  (string-split-lines "a\nb\n") => ("a" "b" "")
  (string-split-lines "a\r\nb") => ("a" "b")
```

### `string-split-vector`

```
Syntax: (string-split-vector s pattern?)
Library: (scm string)
Description: Splits the string s at occurrences of the regular expression pattern and returns a vector of the resulting substrings. Defaults to splitting on whitespace.
Example:
  (string-split-vector "a b c") => #("a" "b" "c")
  (string-split-vector "a,b,c" ",") => #("a" "b" "c")
```

### `symbol-starts-with?`

```
Syntax: (symbol-starts-with? sym str)
Library: (scm string)
Description: Returns #t if the string representation of sym starts with str, #f otherwise. str may be a string or a symbol.
Example:
  (symbol-starts-with? 'foobar "foo") => #t
  (symbol-starts-with? 'foobar "bar") => #f
```


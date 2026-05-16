# `(scm string)`

Extended string operations — search, split, trim, convert

## Exports

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

### `string-split`

```
Syntax: (string-split s pattern?)
Library: (scm string)
Description: Splits the string s at occurrences of the regular expression pattern and returns a list of the resulting substrings. Defaults to splitting on whitespace.
Example:
  (string-split "a b c") => ("a" "b" "c")
  (string-split "a,b,c" ",") => ("a" "b" "c")
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


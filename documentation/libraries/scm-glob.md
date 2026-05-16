# `(scm glob)`

Filename globbing and pattern matching

## Exports

### `glob`

```
Syntax: (glob pattern)
Library: (scm glob)
Description: Returns a sorted list of file and directory paths matching
  the glob pattern. Supports * (any characters except path separator),
  ? (single character), [...] character classes, and ** (recursive
  globstar matching zero or more directory levels). Dotfiles are not
  matched by *, ?, or ** unless the pattern segment explicitly starts
  with a dot. Returns an empty list if no matches are found or the
  base directory does not exist.
Example:
  (glob "src/*.scm") => ("src/bar.scm" "src/foo.scm")
  (glob "**/*.sld") => ("lib/a.sld" "lib/sub/b.sld")
```

### `glob-match?`

```
Syntax: (glob-match? pattern string)
Library: (scm glob)
Description: Tests whether string matches the glob pattern. Supports *
  (any characters except path separator), ? (single character except path
  separator), [...] character classes with ranges and negation ([!...]),
  and ** (matches zero or more path segments including separators).
  This is a pure string operation with no filesystem access.
Example:
  (glob-match? "*.scm" "foo.scm")       => #t
  (glob-match? "src/**/*.scm" "src/lib/foo.scm") => #t
  (glob-match? "[abc].txt" "b.txt")     => #t
```


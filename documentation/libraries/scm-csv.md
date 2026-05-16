# `(scm csv)`

CSV parsing

## Exports

### `csv-line->fields`

```
Syntax: (csv-line->fields str sep) (csv-line->fields str sep 'trim)
Library: (scm core)
Description: Splits a CSV line string using the given separator, stripping surrounding double-quotes from each field. When 'trim is given as a third argument, also trims whitespace from each field.
Example:
  (csv-line->fields "a,b,c" ",") => ("a" "b" "c")
  (csv-line->fields "\"hello\",world" ",") => ("hello" "world")
```


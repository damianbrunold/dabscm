# `(scm net http forms)`

application/x-www-form-urlencoded form and query parsing

## Exports

### `form-ref`

```
Syntax: (form-ref form key [default])
Library: (scm net http forms)
Description: Returns the value of key in form (an alist from parse-www-form),
  or default if missing, or #f if no default is supplied.
Example:
  (form-ref '(("a" . "1")) "a") => "1"
  (form-ref '() "a" "-") => "-"
```

### `form-refs-by-prefix`

```
Syntax: (form-refs-by-prefix form prefix)
Library: (scm net http forms)
Description: Returns all (key . value) pairs from form whose key starts with
  prefix. Order is preserved.
Example:
  (form-refs-by-prefix '(("opt-a" . "1") ("name" . "x") ("opt-b" . "2")) "opt-")
  => (("opt-a" . "1") ("opt-b" . "2"))
```

### `parse-www-form`

```
Syntax: (parse-www-form body)
Library: (scm net http forms)
Description: Parses an application/x-www-form-urlencoded body or query
  string into an alist of decoded (key . value) string pairs. Empty body
  or #f → '(). Keys with no '=' map to empty-string values.
Example:
  (parse-www-form "name=Ada&age=37") => (("name" . "Ada") ("age" . "37"))
  (parse-www-form "") => ()
```


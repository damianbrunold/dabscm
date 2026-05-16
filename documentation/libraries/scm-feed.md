# `(scm feed)`

## Exports

### `local-name`

*(no documentation)*

### `parse-feed-bytevector`

```
Syntax: (parse-feed-bytevector bv)
Library: (scm feed)
Description: Parses an Atom or RSS 2.0 feed from an in-memory bytevector.
  Same result shape as parse-feed-file. Use this when fetching feed bytes
  over HTTP so the XML declaration's encoding is honoured.
Example:
  (parse-feed-bytevector (http-response-body resp))
```

### `parse-feed-file`

```
Syntax: (parse-feed-file path)
Library: (scm feed)
Description: Parses an Atom or RSS 2.0 feed from a file. Returns a pair
  (feed-title . entries), where entries is a list of alists with keys
  'title', 'link', 'guid', 'summary', 'published' (all strings; missing
  fields default to ''). Dates are returned verbatim — use parse-pubdate
  from (scm datetime) to convert.
Example:
  (parse-feed-file "/tmp/feed.xml")
    => ("Example" (("title" . "Post 1") ("link" . "...") ...))
```

### `parse-feed-string`

```
Syntax: (parse-feed-string s)
Library: (scm feed)
Description: Parses an Atom or RSS 2.0 feed from an in-memory string.
  Same result shape as parse-feed-file.
Example:
  (parse-feed-string "<rss>...</rss>") => ("Example" (... ...))
```

### `qname-field`

*(no documentation)*


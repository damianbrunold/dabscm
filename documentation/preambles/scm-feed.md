## Overview

`(scm feed)` parses Atom and RSS 2.0 feeds. The three entry points differ only in
where the bytes come from; each returns `(cons feed-title entries)`, where
`entries` is a list of alists with the string keys `title`, `link`, `guid`,
`summary`, and `published` (missing fields default to `""`).

## Common uses

```scheme
(import (scm feed))

(parse-feed-file "/tmp/feed.xml")
;; => ("Example Blog" (("title" . "Post 1") ("link" . "...") ...) ...)

(parse-feed-string "<rss>...</rss>")
```

Use `parse-feed-bytevector` when you already have the feed as bytes (e.g. a
download). Pair with `(scm datetime)`'s `parse-pubdate` to turn the `published`
strings into epoch seconds.

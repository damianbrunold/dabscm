## Overview

`(scm datetime)` parses and formats dates and times, working in Unix epoch
seconds. It understands ISO 8601, RFC 822, and feed-style publication dates, and
provides the current time. For the full SRFI time/date data types see
`(srfi 19)`; this library is a lightweight convenience layer.

## Common uses

Parse various date formats to epoch seconds:

```scheme
(import (scm datetime))

(parse-iso8601 "2024-05-16T12:34:56Z")          ;; => 1715862896
(parse-iso8601 "2024-05-16T14:34:56+02:00")     ;; => 1715862896
(parse-rfc822  "Thu, 16 May 2024 12:34:56 +0200") ;; => 1715855696
```

Format epoch seconds back to ISO 8601, and read the clock:

```scheme
(format-iso8601 1715862896)   ;; => "2024-05-16T12:34:56Z"
(now)                         ;; current time, epoch seconds
(today)                       ;; start of today, epoch seconds
```

`parse-pubdate` accepts either ISO 8601 or RFC 822 input, which is handy when
processing feeds (see `(scm feed)`).

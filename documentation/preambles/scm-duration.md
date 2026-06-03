## Overview

`(scm duration)` converts between human-friendly duration strings and a plain
number of seconds — handy for config values and command-line options like
`--timeout 30s`.

## Usage

```scheme
(import (scm duration))

(parse-duration "30")    ;; => 30      ; a bare number is seconds
(parse-duration "10m")   ;; => 600
(parse-duration "3h")    ;; => 10800
(parse-duration "1d")    ;; => 86400
(parse-duration "x")     ;; => #f      ; unparseable input

(format-duration 3600)   ;; => "1h"
(format-duration 90)     ;; => "90s"
```

`parse-duration` accepts a bare integer or one suffixed with `s`/`m`/`h`/`d`
(seconds/minutes/hours/days), and returns `#f` for anything it cannot parse.
`format-duration` is the inverse: it uses a `d`/`h`/`m` suffix when the value
divides evenly, otherwise a plain seconds value with an `s` suffix.

# `(scm duration)`

Duration string parsing and formatting (seconds, minutes, hours, days)

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


## Exports

### `format-duration`

```
Syntax: (format-duration seconds)
Library: (scm duration)
Description: Human-readable inverse of parse-duration. Emits a d/h/m suffix
  when seconds divides evenly by 86400/3600/60; otherwise emits a plain
  seconds value with the s suffix. Non-integer or negative input is
  rendered as the integer itself (or empty string for non-numbers).
Example:
  (format-duration 3600)  => "1h"
  (format-duration 86400) => "1d"
  (format-duration 90)    => "90s"
  (format-duration 0)     => "0s"
```

### `parse-duration`

```
Syntax: (parse-duration s)
Library: (scm duration)
Description: Parses a duration string into a non-negative integer number of
  seconds. Accepts a bare integer (interpreted as seconds), or an integer
  suffixed with one of s/m/h/d (seconds/minutes/hours/days). Returns #f
  if s is not a string, is empty, or does not parse.
Example:
  (parse-duration "30")  => 30
  (parse-duration "30s") => 30
  (parse-duration "10m") => 600
  (parse-duration "3h")  => 10800
  (parse-duration "1d")  => 86400
  (parse-duration "x")   => #f
```


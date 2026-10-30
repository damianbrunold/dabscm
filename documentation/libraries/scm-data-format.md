# `(scm data format)`

Number, percent and date formatting with thousands separators

## Overview

Formatting for reports, tables and chart axes, rounding half away from zero.
The parameter `data-locale` holds the separators (Swiss `'` and `.` by default);
`na-string` the text for missing values.

## Common uses

```scheme
(fmt-num 24973.25 1)              ;; => "24'973.3"
(fmt-pct 0.2345)                  ;; => "23.5 %"
(fmt-pct-change 20316 24973)      ;; => "+23 %"
(fmt-si 12345)                    ;; => "12.3k"
```


## Exports

### `data-locale`

*(no documentation)*

### `fmt-date`

```
Syntax: (fmt-date day [style])
Library: (scm data format)
Description: Formats a date: iso (default, 2024-03-11) or dmy (11.03.2024).
Example:
  (fmt-date (ymd->day 2024 3 11) 'dmy) => "11.03.2024"
```

### `fmt-int`

```
Syntax: (fmt-int x)
Library: (scm data format)
Description: (fmt-num x 0): rounded, with thousands separators.
Example:
  (fmt-int 1234567) => "1'234'567"
```

### `fmt-num`

```
Syntax: (fmt-num x [decimals [thousands?]])
Library: (scm data format)
Description: Formats a number with a fixed number of decimals (default 0)
  and thousands separators from data-locale (pass #f as thousands? to
  leave them out). na gives (na-string).
Example:
  (fmt-num 24973.25 1) => "24'973.3"
  (fmt-num -0.04 1)    => "0.0"
```

### `fmt-pct`

```
Syntax: (fmt-pct fraction [decimals])
Library: (scm data format)
Description: Formats a fraction as percent with a space before % (default
  1 decimal).
Example:
  (fmt-pct 0.2345) => "23.5 %"
```

### `fmt-pct-change`

```
Syntax: (fmt-pct-change from to [decimals])
Library: (scm data format)
Description: The relative change from a to b as a signed percent (default
  0 decimals); "n/a" when a is 0 and b is not.
Example:
  (fmt-pct-change 20316 24973) => "+23 %"
```

### `fmt-si`

```
Syntax: (fmt-si x [decimals])
Library: (scm data format)
Description: Short form with k / M / G suffix (default 1 decimal), for
  axis labels.
Example:
  (fmt-si 12345) => "12.3k"
```

### `fmt-value`

```
Syntax: (fmt-value x)
Library: (scm data format)
Description: Generic display form of a cell value, used when printing data
  frames: integers plain, reals with up to 4 decimals, dates ISO, strings
  as they are, na as (na-string), lists and other values written.
Example:
  (fmt-value 2.50) => "2.5"
```

### `na-string`

*(no documentation)*


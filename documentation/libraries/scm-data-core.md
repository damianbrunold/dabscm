# `(scm data core)`

Data-frame base — missing value na, calendar dates, type inference

## Overview

The base shared by the `(scm data …)` libraries: the missing value `na`, a
calendar date type (days since 1970-01-01, e.g. `(ymd->day 2024 3 11)`,
`string->day` for ISO and DD.MM.YYYY), value and column type detection, and the
string parsing and type inference used by the readers.


## Exports

### `column-type`

```
Syntax: (column-type vector)
Library: (scm data core)
Description: The type of a column: the common value-type of its non-NA
  values; int and real together give real; na if all are NA, mixed if
  the values have different types.
Example:
  (column-type (vector 1 2.5 na)) => real
```

### `day->string`

```
Syntax: (day->string day [style])
Library: (scm data core)
Description: Formats a date. style is iso (default, "2024-03-11") or
  dmy ("11.03.2024").
Example:
  (day->string (ymd->day 2024 3 11) 'dmy) => "11.03.2024"
```

### `day->ymd`

```
Syntax: (day->ymd day)
Library: (scm data core)
Description: The list (year month day-of-month) of a date.
Example:
  (day->ymd (ymd->day 2024 2 29)) => (2024 2 29)
```

### `day-from-number`

```
Syntax: (day-from-number n)
Library: (scm data core)
Description: The date n days after 1970-01-01 (n may be negative).
Example:
  (day->string (day-from-number 0)) => "1970-01-01"
```

### `day-month`

*(no documentation)*

### `day-number`

*(no documentation)*

### `day-weekday`

```
Syntax: (day-weekday day)
Library: (scm data core)
Description: ISO weekday of a date: 1 = Monday … 7 = Sunday.
Example:
  (day-weekday (ymd->day 2026 10 30)) => 5
```

### `day-year`

*(no documentation)*

### `day?`

*(no documentation)*

### `infer-column`

```
Syntax: (infer-column string-vector [na-strings [decimal-char]])
Library: (scm data core)
Description: Guesses the type of a column of strings and converts it:
  int if every non-missing cell is an integer, else real if all are
  numbers (a value with a leading zero such as "007" is a code, and
  keeps the column a string), else bool (TRUE/FALSE, or t/f as Postgres sends them), else date (ISO or DD.MM.YYYY), else
  string. Cells in na-strings (default "", NA, N/A, NULL, #N/A) become
  na. Returns the converted vector.
Example:
  (infer-column (vector "1" "" "3")) => #(1 na 3)
```

### `na`

*(no documentation)*

### `na?`

```
Syntax: (na? x)
Library: (scm data core)
Description: True if x is the missing value na. Data frames use na for
  missing cells; aggregates skip it, arithmetic with it yields na.
Example:
  (na? na) => #t
  (na? 0)  => #f
```

### `parse-cell`

```
Syntax: (parse-cell string type [decimal-char])
Library: (scm data core)
Description: Converts a string to a value of the given column type (int,
  real, bool, date, symbol, string). Returns na when the string can't be
  read as that type. decimal-char (default #\.) is the decimal separator.
Example:
  (parse-cell "1,5" 'real #\,) => 1.5
```

### `string->day`

```
Syntax: (string->day s)
Library: (scm data core)
Description: Parses an ISO date "YYYY-MM-DD" (also "YYYYMMDD" and the
  Swiss "DD.MM.YYYY"); returns #f when s is not such a date.
Example:
  (day->ymd (string->day "11.03.2024")) => (2024 3 11)
```

### `value-type`

```
Syntax: (value-type x)
Library: (scm data core)
Description: The data type of one value: na, int (exact integer), real
  (any other real number), string, bool, date, symbol, list or other.
Example:
  (value-type 1.5) => real
```

### `ymd->day`

```
Syntax: (ymd->day year month day)
Library: (scm data core)
Description: The date for a year, month (1-12) and day of month.
Example:
  (day-number (ymd->day 1970 1 2)) => 1
```


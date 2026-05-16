# `(scm datetime)`

Date and time operations

## Exports

### `string->date-days`

```
Syntax: (string->date-days s format?)
Library: (scm string)
Description: Parses the date string s in yyyyMMdd format and returns the number of days since the OLE Automation epoch (December 30, 1899). Returns #f if parsing fails.
Example:
  (string->date-days "20240101") => 45292
  (string->date-days "invalid") => #f
```

### `string->date-seconds`

```
Syntax: (string->date-seconds s format?)
Library: (scm string)
Description: Parses the date/time string s (in formats like yyyyMMddHHmmss, yyyyMMddHHmm, yyyyMMddHH, or yyyyMMdd) and returns the number of seconds since the Unix epoch. Returns #f if parsing fails.
Example:
  (string->date-seconds "20240101120000") => 1704110400
  (string->date-seconds "invalid") => #f
```

### `timestamp`

```
Syntax: (timestamp)
Library: (scm system)
Description: Returns the current time as the number of milliseconds since the epoch (January 1, year 1).
Example:
  (timestamp) => 63850000000000
```

### `timestamp->string`

```
Syntax: (timestamp->string ms format?)
Library: (scm system)
Description: Formats a timestamp (milliseconds) as a date string. The optional format may be isodatetime, isodate, datetime, date, or a custom .NET format string; defaults to isodatetime.
Example:
  (timestamp->string (timestamp)) => "20260318-153045"
  (timestamp->string (timestamp) 'isodate) => "20260318"
```


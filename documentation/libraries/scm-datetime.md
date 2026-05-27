# `(scm datetime)`

Date and time operations

## Exports

### `format-iso8601`

```
Syntax: (format-iso8601 unix-seconds)
Library: (scm datetime)
Description: Formats a Unix-seconds integer as an ISO 8601 UTC string
  ('YYYY-MM-DDTHH:MM:SSZ'). Negative inputs (pre-1970) are not supported.
Example:
  (format-iso8601 1715862896) => "2024-05-16T12:34:56Z"
  (format-iso8601 (parse-iso8601 "2024-05-16T14:34:56+02:00"))
    => "2024-05-16T12:34:56Z"
```

### `now`

```
Syntax: (now)
Syntax: (now format)
Library: (scm datetime)
Description: Returns the current local date and time as a string. Time is
  24-hour. Default format is ISO 'YYYY-MM-DD HH:MM'. format='short returns
  'YYYYMMDD-HHMM'; format='dmyhs returns 'DD.MM.YYYY HH.MM'.
Example:
  (now)        => "2026-05-27 07:32"
  (now 'short) => "20260527-0732"
  (now 'dmyhs) => "27.05.2026 07.32"
```

### `parse-iso8601`

```
Syntax: (parse-iso8601 s)
Library: (scm datetime)
Description: Parses an ISO 8601 / RFC 3339 date string (e.g. used by Atom
  feeds) and returns Unix seconds, or #f on failure. Accepts date-only
  ('2024-05-16'), date+time with 'T' or space separator, and a trailing
  timezone offset (Z, +02:00, -0500). Fractional seconds are ignored.
Example:
  (parse-iso8601 "2024-05-16T12:34:56Z")      => 1715862896
  (parse-iso8601 "2024-05-16T14:34:56+02:00") => 1715862896
  (parse-iso8601 "2024-05-16")                => 1715817600
  (parse-iso8601 "bogus") => #f
```

### `parse-pubdate`

```
Syntax: (parse-pubdate s)
Library: (scm datetime)
Description: Best-effort date parser for feed pubdates. Tries ISO 8601 first
  if s looks ISO-shaped (hyphen at position 4), otherwise RFC 822. Falls
  back to the other format on failure. Returns Unix seconds, or #f.
Example:
  (parse-pubdate "2024-05-16T12:34:56Z")             => 1715862896
  (parse-pubdate "Thu, 16 May 2024 12:34:56 +0000")  => 1715862896
  (parse-pubdate "") => #f
```

### `parse-rfc822`

```
Syntax: (parse-rfc822 s)
Library: (scm datetime)
Description: Parses an RFC 822 / RFC 2822 date string (e.g. used by RSS 2.0
  pubDate elements) and returns Unix seconds, or #f on failure. The leading
  day-of-week prefix is optional. Two-digit years are mapped to 20XX.
Example:
  (parse-rfc822 "Thu, 16 May 2024 12:34:56 +0200") => 1715855696
  (parse-rfc822 "16 May 2024 12:34:56 GMT")       => 1715862896
  (parse-rfc822 "bogus") => #f
```

### `string->date-days`

```
Syntax: (string->date-days s format?)
Library: (scm datetime)
Description: Parses the date string s in yyyyMMdd format and returns the number of days since the OLE Automation epoch (December 30, 1899). Returns #f if parsing fails.
Example:
  (string->date-days "20240101") => 45292
  (string->date-days "invalid") => #f
```

### `string->date-seconds`

```
Syntax: (string->date-seconds s format?)
Library: (scm datetime)
Description: Parses the date/time string s (in formats like yyyyMMddHHmmss, yyyyMMddHHmm, yyyyMMddHH, or yyyyMMdd) and returns the number of seconds since the Unix epoch. Returns #f if parsing fails.
Example:
  (string->date-seconds "20240101120000") => 1704110400
  (string->date-seconds "invalid") => #f
```

### `time`

```
Syntax: (time)
Syntax: (time format)
Library: (scm datetime)
Description: Returns the current local time as a string. Time is 24-hour.
  Default format is ISO 'HH:MM'. format='short returns 'HHMM'.
Example:
  (time)        => "07:32"
  (time 'short) => "0732"
```

### `timestamp`

```
Syntax: (timestamp)
Library: (scm datetime)
Description: Returns the current time as the number of milliseconds since the epoch (January 1, year 1).
Example:
  (timestamp) => 63850000000000
```

### `timestamp->string`

```
Syntax: (timestamp->string ms format?)
Library: (scm datetime)
Description: Formats a timestamp (milliseconds) as a date string. The optional format may be isodatetime, isodate, datetime, date, or a custom .NET format string; defaults to isodatetime.
Example:
  (timestamp->string (timestamp)) => "20260318-153045"
  (timestamp->string (timestamp) 'isodate) => "20260318"
```

### `today`

```
Syntax: (today)
Syntax: (today format)
Library: (scm datetime)
Description: Returns the current local date as a string. Default format is
  ISO 'YYYY-MM-DD'. format='short returns 'YYYYMMDD' (no separators);
  format='dmy returns 'DD.MM.YYYY'.
Example:
  (today)        => "2026-05-27"
  (today 'short) => "20260527"
  (today 'dmy)   => "27.05.2026"
```


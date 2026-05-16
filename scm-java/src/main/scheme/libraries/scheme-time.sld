(define-library (scheme time)
  (export current-second current-jiffy jiffies-per-second)
  (begin
    (define current-jiffy (%primitive "%jiffy"))
    (define (jiffies-per-second)
      "Syntax: (jiffies-per-second)
Library: (scheme time)
Description: Returns the number of jiffies per second as an exact integer.
A jiffy is an implementation-defined unit of time. In this implementation
one jiffy equals one microsecond, so jiffies-per-second returns 1000000.
Example:
  (jiffies-per-second) => 1000000"
      1000000)
    (define (current-second)
      "Syntax: (current-second)
Library: (scheme time)
Description: Returns an inexact real number representing the current time
measured in seconds since the Unix epoch (January 1, 1970 00:00:00 UTC).
The value is derived from current-jiffy divided by jiffies-per-second.
Example:
  (current-second) => 1710000000.123456"
      (/ (current-jiffy) 1000000.0))))

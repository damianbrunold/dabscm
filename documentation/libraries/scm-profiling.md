# `(scm profiling)`

Execution profiling and performance measurement

## Exports

### `profile-data`

```
Syntax: (profile-data)
Library: (scm profiling)
Description: Returns profiling data as a list of lists, each of the
form (name calls total-jiffies), sorted by total-jiffies descending.
Example:
  (profile-data)
  => (("(my lib):proc-a" 1000 4523400) ...)
```

### `profile-instrument!`

```
Syntax: (profile-instrument! spec ...)
Library: (scm profiling)
Description: Instruments procedures for profiling. Each spec is a list
whose car is a library name (as a list of symbols). The remaining
elements are symbols naming the procedures to instrument. If no
symbols are given, all procedures defined in the library are
instrumented (including primitives bound in the library, but
excluding imported bindings).
Example:
  (profile-instrument! '((scheme base) map for-each))
  (profile-instrument! '((my lib)))
```

### `profile-report`

```
Syntax: (profile-report)
       (profile-report port)
Library: (scm profiling)
Description: Prints a formatted profiling report showing procedure
name, call count, total time in ms, average time in ms, and
percentage of total time. Output goes to the current output port
or to the given port.
Example:
  (profile-report)
```

### `profile-reset!`

```
Syntax: (profile-reset!)
Library: (scm profiling)
Description: Resets all profiling counters and durations to zero.
Instrumented procedures remain in place.
Example:
  (profile-reset!)
```

### `profile-uninstrument!`

```
Syntax: (profile-uninstrument!)
Library: (scm profiling)
Description: Removes all instrumentation, restoring the original
procedures. Clears all profiling data.
Example:
  (profile-uninstrument!)
```


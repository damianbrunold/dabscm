## Overview

The base shared by the `(scm data …)` libraries: the missing value `na`, a
calendar date type (days since 1970-01-01, e.g. `(ymd->day 2024 3 11)`,
`string->day` for ISO and DD.MM.YYYY), value and column type detection, and the
string parsing and type inference used by the readers.

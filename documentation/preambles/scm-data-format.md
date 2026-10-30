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

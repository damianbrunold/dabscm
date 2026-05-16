# `(scm math)`

Math constants and non-standard numeric operations

## Exports

### `E`

*(no documentation)*

### `PI`

*(no documentation)*

### `factorial`

```
Syntax: (factorial n)
Library: (scm math)
Description: Returns the factorial of non-negative integer n (n!). Uses tail
recursion via a named let accumulator.
Example:
  (factorial 0) => 1
  (factorial 5) => 120
```

### `magnitude`

```
Syntax: (magnitude z)
Library: (scheme complex)
Description: Returns the magnitude of the complex number z.
  For real numbers, equivalent to abs.
Example:
  (magnitude -3.0) => 3.0
  (magnitude 3+4i) => 5.0
```

### `nil`

*(no documentation)*

### `sign`

```
Syntax: (sign n)
Library: (scm math)
Description: Returns -1 if n is negative, +1 if n is positive, or 0 if n is zero.
Example:
  (sign -5) => -1
  (sign 0)  => 0
  (sign 3)  => 1
```


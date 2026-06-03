# `(scheme inexact)`

Inexact number operations and trigonometry

## Overview

`(scheme inexact)` provides the transcendental and inexact numeric operations:
the trig and exponential/log functions, `sqrt`, and the predicates for special
values (`nan?`, `infinite?`, `finite?`).

## Common uses

```scheme
(import (scheme base) (scheme inexact))

(sqrt 2)            ;; => 1.4142135623730951
(sin 0)             ;; => 0.0
(exp 1)             ;; => 2.718281828459045
(log 100 10)        ;; => 2.0   (log base 10)

(nan? +nan.0)       ;; => #t
(infinite? +inf.0)  ;; => #t
(finite? 1.0)       ;; => #t
```


## Exports

### `acos`

```
Syntax: (acos z)
Library: (scheme inexact)
Description: Returns the arc cosine of z. The result is in radians.
Example:
  (acos 1.0) => 0.0
  (acos 0.0) => 1.5707963267948966
```

### `asin`

```
Syntax: (asin z)
Library: (scheme inexact)
Description: Returns the arc sine of z. The result is in radians.
Example:
  (asin 0.0) => 0.0
  (asin 1.0) => 1.5707963267948966
```

### `atan`

```
Syntax: (atan z) (atan y x)
Library: (scheme inexact)
Description: Returns the arc tangent of z, or of y/x when two arguments are given. The result is in radians.
Example:
  (atan 0.0) => 0.0
  (atan 1.0 1.0) => 0.7853981633974483
```

### `cos`

```
Syntax: (cos z)
Library: (scheme inexact)
Description: Returns the cosine of z. The argument is in radians.
Example:
  (cos 0.0) => 1.0
  (cos 3.141592653589793) => -1.0
```

### `exp`

```
Syntax: (exp num)
Library: (scheme inexact)
Description: Returns e raised to the power of num, where e is the base of the
natural logarithm. The result is an inexact real number.
Example:
  (exp 0)   => 1.0
  (exp 1)   => 2.718281828459045
  (exp 2)   => 7.38905609893065
```

### `finite?`

```
Syntax: (finite? x)
Library: (scheme inexact)
Description: Returns #t if x is finite (not infinite and not NaN). For complex
  numbers, returns #t if both components are finite.
Example:
  (finite? 1.0)    => #t
  (finite? +inf.0) => #f
  (finite? +nan.0) => #f
  (finite? 1)      => #t
```

### `infinite?`

```
Syntax: (infinite? x)
Library: (scheme inexact)
Description: Returns #t if x is infinite. For complex numbers, returns #t
  if either component is infinite.
Example:
  (infinite? +inf.0) => #t
  (infinite? -inf.0) => #t
  (infinite? 1.0)    => #f
  (infinite? 1)      => #f
```

### `log`

```
Syntax: (log z) (log z base)
Library: (scheme inexact)
Description: Returns the natural logarithm of z, or the logarithm of z to base if given.
Example:
  (log 1.0) => 0.0
  (log 8.0 2.0) => 3.0
```

### `nan?`

```
Syntax: (nan? x)
Library: (scheme inexact)
Description: Returns #t if x is a NaN (not-a-number) value. For complex
  numbers, returns #t if either component is NaN.
Example:
  (nan? +nan.0) => #t
  (nan? 1.0)    => #f
  (nan? 1)      => #f
```

### `sin`

```
Syntax: (sin z)
Library: (scheme inexact)
Description: Returns the sine of z, where z is in radians. Returns an inexact result.
Example:
  (sin 0) => 0.0
  (sin (/ (acos -1) 2)) => 1.0
```

### `sqrt`

```
Syntax: (sqrt z)
Library: (scheme inexact)
Description: Returns the principal square root of z. Returns an exact integer when the result is an exact integer, otherwise returns an inexact number.
Example:
  (sqrt 4) => 2
  (sqrt 2) => 1.4142135623730951
  (sqrt 9) => 3
```

### `tan`

```
Syntax: (tan z)
Library: (scheme inexact)
Description: Returns the trigonometric tangent of z, where z is in radians.
Example:
  (tan 0) => 0.0
  (tan (/ (* 3.14159265 1) 4)) => 1.0
```


# `(scheme complex)`

Complex number arithmetic

## Exports

### `angle`

```
Syntax: (angle z)
Library: (scheme complex)
Description: Returns the angle (argument) of the complex number z in radians.
  For positive reals, returns 0.0. For negative reals, returns pi.
Example:
  (angle 1.0)  => 0.0
  (angle -1.0) => 3.141592653589793
```

### `imag-part`

```
Syntax: (imag-part z)
Library: (scheme complex)
Description: Returns the imaginary part of the complex number z. For real
  numbers, returns 0 (exact or inexact matching z's exactness).
Example:
  (imag-part 3.0)  => 0.0
  (imag-part 1+2i) => 2
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

### `make-polar`

```
Syntax: (make-polar r theta)
Library: (scheme complex)
Description: Returns the complex number r * e^(i*theta).
Example:
  (make-polar 1 0) => 1.0
  (make-polar 1 1) => 0.5403023058681398+0.8414709848078965i
```

### `make-rectangular`

```
Syntax: (make-rectangular x y)
Library: (scheme complex)
Description: Returns the complex number x + yi.
Example:
  (make-rectangular 1 2) => 1+2i
  (make-rectangular 3 0) => 3
```

### `real-part`

```
Syntax: (real-part z)
Library: (scheme complex)
Description: Returns the real part of the complex number z. For real numbers,
  returns z unchanged.
Example:
  (real-part 3.0)  => 3.0
  (real-part 1+2i) => 1
```


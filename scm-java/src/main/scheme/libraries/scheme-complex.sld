(define-library (scheme complex)
  (import (scheme base))
  (export angle imag-part magnitude make-polar make-rectangular real-part)
  (begin

    (define (real-part z)
      "Syntax: (real-part z)
Library: (scheme complex)
Description: Returns the real part of the complex number z. For real numbers,
  returns z unchanged.
Example:
  (real-part 3.0)  => 3.0
  (real-part 1+2i) => 1"
      (if (real? z)
          z
          ((%primitive "complex-real-part") z)))

    (define (imag-part z)
      "Syntax: (imag-part z)
Library: (scheme complex)
Description: Returns the imaginary part of the complex number z. For real
  numbers, returns 0 (exact or inexact matching z's exactness).
Example:
  (imag-part 3.0)  => 0.0
  (imag-part 1+2i) => 2"
      (if (real? z)
          (if (inexact? z) 0.0 0)
          ((%primitive "complex-imag-part") z)))

    (define (magnitude z)
      "Syntax: (magnitude z)
Library: (scheme complex)
Description: Returns the magnitude of the complex number z.
  For real numbers, equivalent to abs.
Example:
  (magnitude -3.0) => 3.0
  (magnitude 3+4i) => 5.0"
      (if (real? z)
          (abs z)
          ((%primitive "complex-magnitude") z)))

    (define (angle z)
      "Syntax: (angle z)
Library: (scheme complex)
Description: Returns the angle (argument) of the complex number z in radians.
  For positive reals, returns 0.0. For negative reals, returns pi.
Example:
  (angle 1.0)  => 0.0
  (angle -1.0) => 3.141592653589793"
      (if (real? z)
          (if (negative? z) (acos -1.0) 0.0)
          ((%primitive "complex-angle") z)))

    (define make-rectangular (%primitive "make-rectangular"))

    (define make-polar (%primitive "make-polar"))))

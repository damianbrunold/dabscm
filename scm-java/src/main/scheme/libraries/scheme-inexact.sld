(define-library (scheme inexact)
  (import (scm core))
  (export acos
          asin
          atan
          cos
          exp
          finite?
          infinite?
          log
          nan?
          sin
          sqrt
          tan)
  (begin
    (define expt (%primitive "expt"))
    (define E (%primitive "E"))
    (define real? (%primitive "real?"))
    (define not (%primitive "not"))
    (define = (%primitive "="))

    (define acos (%primitive "acos"))
    (define asin (%primitive "asin"))
    (define atan (%primitive "atan"))
    (define cos (%primitive "cos"))
    (define sin (%primitive "sin"))
    (define tan (%primitive "tan"))
    (define log (%primitive "log"))
    (define sqrt (%primitive "sqrt"))
    (define (exp num)
      "Syntax: (exp num)
Library: (scheme inexact)
Description: Returns e raised to the power of num, where e is the base of the
natural logarithm. The result is an inexact real number.
Example:
  (exp 0)   => 1.0
  (exp 1)   => 2.718281828459045
  (exp 2)   => 7.38905609893065"
      (expt E num))

    (define complex-real-part (%primitive "complex-real-part"))
    (define complex-imag-part (%primitive "complex-imag-part"))
    (define complex? (%primitive "complex?"))

    (define (nan? x)
      "Syntax: (nan? x)
Library: (scheme inexact)
Description: Returns #t if x is a NaN (not-a-number) value. For complex
  numbers, returns #t if either component is NaN.
Example:
  (nan? +nan.0) => #t
  (nan? 1.0)    => #f
  (nan? 1)      => #f"
      (if (real? x)
          (not (= x x))
          (if (complex? x)
              (or (nan? (complex-real-part x))
                  (nan? (complex-imag-part x)))
              #f)))

    (define (infinite? x)
      "Syntax: (infinite? x)
Library: (scheme inexact)
Description: Returns #t if x is infinite. For complex numbers, returns #t
  if either component is infinite.
Example:
  (infinite? +inf.0) => #t
  (infinite? -inf.0) => #t
  (infinite? 1.0)    => #f
  (infinite? 1)      => #f"
      (if (real? x)
          (or (= x +inf.0) (= x -inf.0))
          (if (complex? x)
              (or (infinite? (complex-real-part x))
                  (infinite? (complex-imag-part x)))
              #f)))

    (define (finite? x)
      "Syntax: (finite? x)
Library: (scheme inexact)
Description: Returns #t if x is finite (not infinite and not NaN). For complex
  numbers, returns #t if both components are finite.
Example:
  (finite? 1.0)    => #t
  (finite? +inf.0) => #f
  (finite? +nan.0) => #f
  (finite? 1)      => #t"
      (if (real? x)
          (and (not (infinite? x)) (not (nan? x)))
          (if (complex? x)
              (and (finite? (complex-real-part x))
                   (finite? (complex-imag-part x)))
              #f)))))

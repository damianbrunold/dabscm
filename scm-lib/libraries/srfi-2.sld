(define-library (srfi 2)
  (import (scheme base))
  (export and-let*)
  (begin
    (define-syntax and-let*
      "Syntax: (and-let* ((var expr) ...) body ...)
Library: (srfi 2)
Description: Like let*, but short-circuits on #f. Each clause can be (var expr)
to bind var, (expr) to test expr without binding, or a bare var to test it.
Example:
  (and-let* ((x 5) (y (* x 2))) y) => 10
  (and-let* ((x #f) (y 1)) y) => #f"
      (syntax-rules ()
        ((and-let* () body ...)
         (begin body ...))
        ((and-let* ((var expr) rest ...) body ...)
         (let ((var expr))
           (if var (and-let* (rest ...) body ...) #f)))
        ((and-let* ((expr) rest ...) body ...)
         (let ((t expr))
           (if t (and-let* (rest ...) body ...) #f)))
        ((and-let* (var rest ...) body ...)
         (if var (and-let* (rest ...) body ...) #f))))))

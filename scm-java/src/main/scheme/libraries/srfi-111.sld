(define-library (srfi 111)
  (import (scheme base))
  (export box
          box?
          set-box!
          unbox)
  (begin
    (define-record-type <box>
      (box value)
      box?
      (value unbox set-box!))))

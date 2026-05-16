(import (scheme base))

; Transformer must be syntax-rules; a plain lambda is rejected
(let-syntax ((bad-mac
              (lambda (form)
                (UNDEFINED-FUNCTION-XYZ form))))
  (bad-mac 42))

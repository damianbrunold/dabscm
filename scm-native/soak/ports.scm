;; String, bytevector and file ports dropped without closing; files
;; written through an output port left open
(import (scheme base) (scheme write) (scheme file) (scheme read) (scm fs) (soak lib))

(define in-file "soak-ports-in.tmp")
(call-with-output-file in-file
  (lambda (p) (do ((i 0 (+ i 1))) ((= i 200)) (write (list i "line" i) p) (newline p))))

(soak "ports"
      (lambda (round)
        (do ((i 0 (+ i 1))) ((= i (scale 300)))
          (read (open-input-string "(a b c)"))
          (let ((o (open-output-string))) (write i o) (get-output-string o))
          (read-u8 (open-input-bytevector (bytevector 1 2 3)))
          (let ((p (open-input-file in-file))) (read p) (read-line p))
          (let ((p (open-output-file "soak-ports-out.tmp"))) (write i p)))))

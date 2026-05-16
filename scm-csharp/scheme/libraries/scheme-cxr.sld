(define-library (scheme cxr)
  (export caaaar
          caaadr
          caaar
          caadar
          caaddr
          caadr
          cadaar
          cadadr
          cadar
          caddar
          cadddr
          caddr
          cdaaar
          cdaadr
          cdaar
          cdadar
          cdaddr
          cdadr
          cddaar
          cddadr
          cddar
          cdddar
          cddddr
          cdddr)
  (begin
    (define (caaar pair)
      "Syntax: (caaar pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (car pair))). Accesses the car of the
car of the car of a nested pair structure.
Example:
  (caaar '(((1 2) 3) 4)) => 1"
      (car (car (car pair))))
    (define (caadr pair)
      "Syntax: (caadr pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (cdr pair))). Accesses the car of the
car of the cdr of a nested pair structure.
Example:
  (caadr '(1 (2 3) 4)) => 2"
      (car (car (cdr pair))))
    (define (cadar pair)
      "Syntax: (cadar pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (car pair))). Accesses the car of the
cdr of the car of a nested pair structure.
Example:
  (cadar '((1 2) 3)) => 2"
      (car (cdr (car pair))))
    (define (caddr pair)
      "Syntax: (caddr pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (cdr pair))). Returns the third element
of a list.
Example:
  (caddr '(1 2 3 4)) => 3"
      (car (cdr (cdr pair))))
    (define (cdaar pair)
      "Syntax: (cdaar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (car pair))). Accesses the cdr of the
car of the car of a nested pair structure.
Example:
  (cdaar '(((1 2) 3) 4)) => (2)"
      (cdr (car (car pair))))
    (define (cdadr pair)
      "Syntax: (cdadr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (cdr pair))). Accesses the cdr of the
car of the cdr of a nested pair structure.
Example:
  (cdadr '(1 (2 3) 4)) => (3)"
      (cdr (car (cdr pair))))
    (define (cddar pair)
      "Syntax: (cddar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (car pair))). Accesses the cdr of the
cdr of the car of a nested pair structure.
Example:
  (cddar '((1 2 3) 4)) => (3)"
      (cdr (cdr (car pair))))
    (define (cdddr pair)
      "Syntax: (cdddr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (cdr pair))). Returns the tail of a
list starting after the third element.
Example:
  (cdddr '(1 2 3 4 5)) => (4 5)"
      (cdr (cdr (cdr pair))))
    (define (caaaar pair)
      "Syntax: (caaaar pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (car (car pair)))). Accesses the car of
four nested car operations on a pair structure.
Example:
  (caaaar '((((1 2) 3) 4) 5)) => 1"
      (car (car (car (car pair)))))
    (define (caaadr pair)
      "Syntax: (caaadr pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (car (cdr pair)))). Accesses the car of
the car of the car of the cdr of a nested pair structure.
Example:
  (caaadr '(1 ((2 3) 4) 5)) => 2"
      (car (car (car (cdr pair)))))
    (define (caadar pair)
      "Syntax: (caadar pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (cdr (car pair)))). Accesses the car of
the car of the cdr of the car of a nested pair structure.
Example:
  (caadar '((1 (2 3)) 4)) => 2"
      (car (car (cdr (car pair)))))
    (define (caaddr pair)
      "Syntax: (caaddr pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (cdr (cdr pair)))). Accesses the car of
the car of the third tail of a nested pair structure.
Example:
  (caaddr '(1 2 (3 4) 5)) => 3"
      (car (car (cdr (cdr pair)))))
    (define (cadaar pair)
      "Syntax: (cadaar pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (car (car pair)))). Accesses the car of
the cdr of the car of the car of a nested pair structure.
Example:
  (cadaar '(((1 2) 3) 4)) => 2"
      (car (cdr (car (car pair)))))
    (define (cadadr pair)
      "Syntax: (cadadr pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (car (cdr pair)))). Accesses the car of
the cdr of the car of the cdr of a nested pair structure.
Example:
  (cadadr '(1 (2 3) 4)) => 3"
      (car (cdr (car (cdr pair)))))
    (define (caddar pair)
      "Syntax: (caddar pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (cdr (car pair)))). Accesses the car of
the cdr of the cdr of the car of a nested pair structure.
Example:
  (caddar '((1 2 3) 4)) => 3"
      (car (cdr (cdr (car pair)))))
    (define (cadddr pair)
      "Syntax: (cadddr pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (cdr (cdr pair)))). Returns the fourth
element of a list.
Example:
  (cadddr '(1 2 3 4 5)) => 4"
      (car (cdr (cdr (cdr pair)))))
    (define (cdaaar pair)
      "Syntax: (cdaaar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (car (car pair)))). Accesses the cdr of
the car of the car of the car of a nested pair structure.
Example:
  (cdaaar '((((1 2) 3) 4) 5)) => (2)"
      (cdr (car (car (car pair)))))
    (define (cdaadr pair)
      "Syntax: (cdaadr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (car (cdr pair)))). Accesses the cdr of
the car of the car of the cdr of a nested pair structure.
Example:
  (cdaadr '(1 ((2 3) 4) 5)) => (3)"
      (cdr (car (car (cdr pair)))))
    (define (cdadar pair)
      "Syntax: (cdadar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (cdr (car pair)))). Accesses the cdr of
the car of the cdr of the car of a nested pair structure.
Example:
  (cdadar '((1 (2 3)) 4)) => (3)"
      (cdr (car (cdr (car pair)))))
    (define (cdaddr pair)
      "Syntax: (cdaddr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (cdr (cdr pair)))). Accesses the cdr of
the car of the third tail of a nested pair structure.
Example:
  (cdaddr '(1 2 (3 4) 5)) => (4)"
      (cdr (car (cdr (cdr pair)))))
    (define (cddaar pair)
      "Syntax: (cddaar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (car (car pair)))). Accesses the cdr of
the cdr of the car of the car of a nested pair structure.
Example:
  (cddaar '(((1 2 3) 4) 5)) => (3)"
      (cdr (cdr (car (car pair)))))
    (define (cddadr pair)
      "Syntax: (cddadr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (car (cdr pair)))). Accesses the cdr of
the cdr of the car of the cdr of a nested pair structure.
Example:
  (cddadr '(1 (2 3 4) 5)) => (4)"
      (cdr (cdr (car (cdr pair)))))
    (define (cdddar pair)
      "Syntax: (cdddar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (cdr (car pair)))). Accesses the cdr of
the cdr of the cdr of the car of a nested pair structure.
Example:
  (cdddar '((1 2 3 4) 5)) => (4)"
      (cdr (cdr (cdr (car pair)))))
    (define (cddddr pair)
      "Syntax: (cddddr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (cdr (cdr pair)))). Returns the tail of
a list starting after the fourth element.
Example:
  (cddddr '(1 2 3 4 5 6)) => (5 6)"
      (cdr (cdr (cdr (cdr pair)))))))

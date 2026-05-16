(define-library (scm list)
  (import (scm core) (scheme base) (scheme cxr))
  (export get-property
          get-property-list
          nil
          rest
          split
          uniq
          unique
          univ
          zip-alist)
  (begin
    (define values (%primitive "values"))
    (define call-with-values (%primitive "call-with-values"))
    (define car (%primitive "car"))
    (define cdr (%primitive "cdr"))
    (define cadr (%primitive "cadr"))
    (define cons (%primitive "cons"))
    (define null? (%primitive "null?"))
    (define eq? (%primitive "eq?"))
    (define eqv? (%primitive "eqv?"))
    (define equal? (%primitive "equal?"))
    (define error (%primitive "error"))

    (define get-property (%primitive "get-property"))
    (define get-property-list (%primitive "get-property-list"))
    (define nil (%primitive "nil"))

    (define rest cdr)

    (define (split ls)
      "Syntax: (split ls)
Library: (scm list)
Description: Splits a list into two lists: elements at odd positions and elements
at even positions (0-indexed). Returns the two lists as multiple values.
Example:
  (split '(a b c d e)) => (a c e) (b d)"
      (if (or (null? ls) (null? (cdr ls)))
          (values ls '())
          (call-with-values
              (lambda () (split (cddr ls)))
            (lambda (odds evens)
              (values (cons (car ls) odds)
                      (cons (cadr ls) evens))))))

    (define (zip-alist a b)
      "Syntax: (zip-alist a b)
Library: (scm list)
Description: Combines two lists of equal length into a single association list,
pairing each element from a with the corresponding element from b. Raises an
error if the lists have different lengths.
Example:
  (zip-alist '(1 2 3) '(a b c)) => ((1 . a) (2 . b) (3 . c))"
      (cond ((null? a)
             (if (null? b)
                 '()
                 (error 'zip-alist "lists have different lengths")))
            ((null? b)
             (error 'zip-alist "lists have different lengths"))
            (else
             (cons (cons (car a) (car b)) (zip-alist (cdr a) (cdr b))))))

    (define (uniq list)
      "Syntax: (uniq list)
Library: (scm list)
Description: Removes consecutive duplicate elements from list using eq? for
comparison. The list should be sorted if all duplicates are to be removed.
Example:
  (uniq '(a a b b b c)) => (a b c)"
      (let loop ((list list) (result '()))
        (cond ((null? list) (reverse result))
              ((null? result) (loop (cdr list) (cons (car list) result)))
              (else
               (if (eq? (car list) (car result))
                   (loop (cdr list) result)
                   (loop (cdr list) (cons (car list) result)))))))

    (define (univ list)
      "Syntax: (univ list)
Library: (scm list)
Description: Removes consecutive duplicate elements from list using eqv? for
comparison. The list should be sorted if all duplicates are to be removed.
Example:
  (univ '(1 1 2 2 3)) => (1 2 3)"
      (let loop ((list list) (result '()))
        (cond ((null? list) (reverse result))
              ((null? result) (loop (cdr list) (cons (car list) result)))
              (else
               (if (eqv? (car list) (car result))
                   (loop (cdr list) result)
                   (loop (cdr list) (cons (car list) result)))))))

    (define (unique list)
      "Syntax: (unique list)
Library: (scm list)
Description: Removes consecutive duplicate elements from list using equal? for
comparison. The list should be sorted if all duplicates are to be removed.
Example:
  (unique '(\"a\" \"a\" \"b\" \"b\")) => (\"a\" \"b\")"
      (let loop ((list list) (result '()))
        (cond ((null? list) (reverse result))
              ((null? result) (loop (cdr list) (cons (car list) result)))
              (else
               (if (equal? (car list) (car result))
                   (loop (cdr list) result)
                   (loop (cdr list) (cons (car list) result)))))))))

(define-library (scheme base)
  (import (scm core) (scheme cxr) (scm compile))
  (export *
          +
          -
          /
          <
          <=
          =
          >
          >=
          abs
          and
          append
          apply
          assoc
          assq
          assv
          begin
          boolean=?
          boolean?
          caar
          cadr
          call-with-current-continuation
          call-with-port
          call-with-values
          call/cc
          car
          case
          cdar
          cddr
          cdr
          ceiling
          char->integer
          char<=?
          char<?
          char=?
          char>=?
          char>?
          char?
          close-input-port
          close-output-port
          close-port
          complex?
          cond
          cond-expand
          cons
          char-ready?
          current-error-port
          current-input-port
          current-output-port
          define
          define-record-type
          define-syntax
          define-values
          denominator
          dynamic-wind
          do
          eof-object
          eof-object?
          eq?
          equal?
          eqv?
          error
          error-object-irritants
          error-object-message
          error-object?
          even?
          exact
          exact-integer?
          exact-integer-sqrt
          exact?
          expt
          features
          floor
          floor-quotient
          floor-remainder
          floor/
          flush-output-port
          for-each
          gcd
          get-output-string
          if
          include
          inexact
          inexact?
          integer->char
          integer?
          lambda
          lcm
          length
          let
          let*
          let*-values
          let-syntax
          let-values
          letrec
          letrec*
          letrec-syntax
          list
          list->string
          list->vector
          list-copy
          list-ref
          list-set!
          list-tail
          list?
          make-parameter
          make-string
          make-vector
          map
          max
          member
          memq
          memv
          min
          modulo
          negative?
          newline
          not
          null?
          number->string
          number?
          numerator
          odd?
          open-input-string
          open-output-string
          or
          pair?
          parameterize
          peek-char
          port?
          positive?
          procedure?
          quasiquote
          quote
          quotient
          rational?
          rationalize
          read-char
          read-line
          read-string
          real?
          remainder
          reverse
          round
          set!
          set-car!
          set-cdr!
          symbol=?
          square
          string
          string->list
          string->number
          string->symbol
          string->vector
          string-append
          string-copy
          string-copy!
          string-fill!
          string-length
          string-ref
          string-set!
          string<=?
          string<?
          string=?
          string>=?
          string>?
          string?
          substring
          symbol->string
          symbol?
          syntax-error
          truncate
          truncate-quotient
          truncate-remainder
          truncate/
          unless
          values
          vector
          vector->list
          vector->string
          vector-append
          vector-copy
          vector-copy!
          vector-fill!
          vector-for-each
          vector-length
          vector-map
          vector-ref
          vector-set!
          vector?
          when
          binary-port?
          bytevector
          bytevector-append
          bytevector-copy
          bytevector-copy!
          bytevector-length
          bytevector-u8-ref
          bytevector-u8-set!
          bytevector?
          get-output-bytevector
          input-port-open?
          make-bytevector
          open-input-bytevector
          open-output-bytevector
          output-port-open?
          peek-u8
          read-bytevector
          read-bytevector!
          read-u8
          u8-ready?
          string->utf8
          textual-port?
          utf8->string
          write-bytevector
          write-char
          write-string
          write-u8
          zero?
          file-error?
          guard
          guard-aux
          raise
          raise-continuable
          read-error?
          with-exception-handler
          make-list
          string-map
          string-for-each
          include-ci
          input-port?
          output-port?)
  (begin
    (define * (%primitive "*"))
    (define + (%primitive "+"))
    (define - (%primitive "-"))
    (define / (%primitive "/"))
    (define < (%primitive "<"))
    (define <= (%primitive "<="))
    (define = (%primitive "="))
    (define > (%primitive ">"))
    (define >= (%primitive ">="))
    (define ceiling (%primitive "ceiling"))
    (define floor (%primitive "floor"))
    (define round (%primitive "round"))
    (define truncate (%primitive "truncate"))
    (define quotient (%primitive "quotient"))
    (define remainder (%primitive "remainder"))
    (define modulo (%primitive "modulo"))
    (define expt (%primitive "expt"))
    (define exact (%primitive "exact"))
    (define inexact (%primitive "inexact"))
    (define sqrt (%primitive "sqrt"))

    (define boolean? (%primitive "boolean?"))
    (define not (%primitive "not"))

    (define eq? (%primitive "eq?"))
    (define eqv? (%primitive "eqv?"))
    (define equal? (%primitive "equal?"))

    (define car (%primitive "car"))
    (define cdr (%primitive "cdr"))
    (define caar (%primitive "caar"))
    (define cadr (%primitive "cadr"))
    (define cons (%primitive "cons"))
    (define set-car! (%primitive "set-car!"))
    (define set-cdr! (%primitive "set-cdr!"))
    (define pair? (%primitive "pair?"))
    (define null? (%primitive "null?"))
    (define list-ref (%primitive "list-ref"))
    (define append (%primitive "append"))
    (define memq (%primitive "memq"))
    (define memv (%primitive "memv"))
    (define (member obj list . rest)
      "Syntax: (member obj list)
       (member obj list compare)
Library: (scheme base)
Description: Returns the first sublist of list whose car is obj, where the
  sublists of list are the non-empty lists returned by (list-tail list k) for
  k less than the length of list. If obj does not occur in list, #f is
  returned. The optional compare argument specifies the equality predicate to
  use; it defaults to equal?.
Example:
  (member 2 '(1 2 3))   => (2 3)
  (member 'd '(a b c))  => #f
  (member 2.0 '(1 2 3) =) => (2 3)"
      (let ((compare (if (null? rest) equal? (car rest))))
        (let loop ((l list))
          (cond ((null? l) #f)
                ((compare obj (car l)) l)
                (else (loop (cdr l)))))))

    (define char? (%primitive "char?"))
    (define char->integer (%primitive "char->integer"))
    (define integer->char (%primitive "integer->char"))
    (define char=? (%primitive "char=?"))
    (define char<? (%primitive "char<?"))
    (define char<=? (%primitive "char<=?"))
    (define char>? (%primitive "char>?"))
    (define char>=? (%primitive "char>=?"))

    (define string (%primitive "string"))
    (define make-string (%primitive "make-string"))
    (define string-length (%primitive "string-length"))
    (define string-ref (%primitive "string-ref"))
    (define string-set! (%primitive "string-set!"))
    (define string=? (%primitive "string=?"))
    (define string<? (%primitive "string<?"))
    (define string<=? (%primitive "string<=?"))
    (define string>? (%primitive "string>?"))
    (define string>=? (%primitive "string>=?"))
    (define substring (%primitive "substring"))
    (define string-append (%primitive "string-append"))
    (define string->symbol (%primitive "string->symbol"))
    (define symbol->string (%primitive "symbol->string"))

    (define vector (%primitive "vector"))
    (define make-vector (%primitive "make-vector"))
    (define vector-length (%primitive "vector-length"))
    (define vector-ref (%primitive "vector-ref"))
    (define vector-set! (%primitive "vector-set!"))

    (define symbol? (%primitive "symbol?"))
    (define string? (%primitive "string?"))
    (define vector? (%primitive "vector?"))

    (define values (%primitive "values"))
    (define apply (%primitive "apply"))
    (define call-with-current-continuation
      (%primitive "call-with-current-continuation"))
    (define call-with-values (%primitive "call-with-values"))

    (define call/cc call-with-current-continuation)

    ;; Primitive bindings for exception handlers
    (define %exception-handlers-get (%primitive "%exception-handlers-get"))
    (define %exception-handlers-set! (%primitive "%exception-handlers-set!"))
    (define %make-error-object (%primitive "%make-error-object"))
    (define %raise-fatal (%primitive "%raise-fatal"))

    ;; dynamic-wind + call/cc integration (R7RS)
    ;; winders lives in the VM instance (per-thread) accessed via %winders-get/%winders-set!
    ;; Helper functions are top-level defines (with % prefix) instead of being
    ;; inside a (let () ...) block, because set! on imported globals inside a
    ;; let body with internal defines doesn't compile correctly under the Expander.
    (define %winders-get (%primitive "%winders-get"))
    (define %winders-set! (%primitive "%winders-set!"))
    (define (%common-tail x y)
      (let ((lx (length x)) (ly (length y)))
        (do ((x (if (> lx ly) (list-tail x (- lx ly)) x) (cdr x))
             (y (if (> ly lx) (list-tail y (- ly lx)) y) (cdr y)))
            ((eq? x y) x))))
    (define (%do-wind new)
      (let ((tail (%common-tail new (%winders-get))))
        (let f ((l (%winders-get)))
          (if (not (eq? l tail))
              (begin
                (%winders-set! (cdr l))
                ((cdar l))
                (f (cdr l)))))
        (let f ((l new))
          (if (not (eq? l tail))
              (begin
                (f (cdr l))
                ((caar l))
                (%winders-set! l))))))
    (define call/cc
      (let ((c (%primitive "call-with-current-continuation")))
        (lambda (f)
          (c (lambda (k)
               (f (let ((save-winders (%winders-get))
                        (save-handlers (%exception-handlers-get)))
                    (lambda x
                      (if (not (eq? save-winders (%winders-get))) (%do-wind save-winders))
                      (%exception-handlers-set! save-handlers)
                      (apply k x)))))))))
    (define call-with-current-continuation call/cc)
    (define (dynamic-wind in body out)
      (in)
      (%winders-set! (cons (cons in out) (%winders-get)))
      (let ((ans (body)))
        (%winders-set! (cdr (%winders-get)))
        (out)
        ans))
    ;; R7RS exception handling
    (define (with-exception-handler handler thunk)
      "Syntax: (with-exception-handler handler thunk)
Library: (scheme base)
Description: Calls thunk with handler installed as the current exception handler.
Example:
  (with-exception-handler (lambda (e) 42) (lambda () (raise 'oops))) => 42"
      (let ((saved (%exception-handlers-get)))
        (%exception-handlers-set! (cons handler saved))
        (let ((result (thunk)))
          (%exception-handlers-set! saved)
          result)))
    (define (raise condition)
      "Syntax: (raise obj)
Library: (scheme base)
Description: Raises an exception by invoking the current exception handler on obj.
Example:
  (guard (e (#t (error-object-message e)))
    (raise (make-error-object \"oops\" '()))) => \"oops\""
      (let ((hs (%exception-handlers-get)))
        (if (null? hs)
            (%raise-fatal condition)
            (let ((handler (car hs)))
              (%exception-handlers-set! (cdr hs))
              (handler condition)
              (%raise-fatal (%make-error-object
                              "raise: exception handler returned"
                              (list condition)))))))
    (define (raise-continuable condition)
      "Syntax: (raise-continuable obj)
Library: (scheme base)
Description: Like raise, but if the handler returns, its value becomes the return value.
Example:
  (with-exception-handler (lambda (e) 42) (lambda () (+ 1 (raise-continuable 'oops)))) => 43"
      (let ((hs (%exception-handlers-get)))
        (if (null? hs)
            (%raise-fatal condition)
            (let ((handler (car hs)))
              (%exception-handlers-set! (cdr hs))
              (let ((result (handler condition)))
                (%exception-handlers-set! hs)
                result)))))

    (define close-input-port (%primitive "close-input-port"))
    (define close-output-port (%primitive "close-output-port"))
    (define open-input-string (%primitive "open-input-string"))
    (define open-output-string (%primitive "open-output-string"))
    (define get-output-string (%primitive "get-output-string"))
    (define peek-char (%primitive "peek-char"))
    (define read-char (%primitive "read-char"))
    (define (char-ready? . args)
      "Syntax: (char-ready?)
       (char-ready? port)
Library: (scheme base)
Description: Returns #t if a character is ready on the input port and returns
  #f if the function would have to wait. If char-ready returns #t then the
  next read-char operation on the given port is guaranteed not to hang. If the
  port is at end of file then char-ready? returns #t. This implementation
  always returns #t.
Example:
  (char-ready?)         => #t
  (char-ready? (current-input-port)) => #t"
      #t)
    (define read-line (%primitive "read-line"))
    (define write-char (%primitive "write-char"))
    (define newline (%primitive "newline"))
    (define eof-object? (%primitive "eof-object?"))
    (define flush-output-port (%primitive "flush-output-port"))

    ;; error routes through raise so with-exception-handler can catch it
    (define (error msg . irritants)
      "Syntax: (error message obj ...)
Library: (scheme base)
Description: Raises an exception as if by calling raise on a newly allocated
  error object which encapsulates the information provided. The message is a
  string describing the error. The objects are arbitrary values which are
  stored in the error object and can be retrieved using error-object-irritants.
  Also accepts SRFI-23 style (error who message irritant ...) where who is a
  symbol.
Example:
  (error \"not a number\" 42)
  (error 'my-proc \"invalid argument\" 'foo)"
      (if (symbol? msg)
          ;; SRFI-23: (error who message irritant ...)
          (raise (%make-error-object
                   (string-append (symbol->string msg) ": " (car irritants))
                   (cdr irritants)))
          ;; R7RS: (error message irritant ...)
          (raise (%make-error-object msg irritants))))
    (define error-object? (%primitive "error-object?"))
    (define error-object-message (%primitive "error-object-message"))
    (define error-object-irritants (%primitive "error-object-irritants"))
    (define read-error? (%primitive "read-error?"))
    (define file-error? (%primitive "file-error?"))

    (define include (%primitive "include"))

    (define number->string (%primitive "number->string"))
    (define string->number (%primitive "string->number"))
    (define exact? (%primitive "exact?"))
    (define inexact (%primitive "inexact"))
    (define exact (%primitive "exact"))
    (define integer? (%primitive "integer?"))
    (define number? (%primitive "number?"))
    (define real? (%primitive "real?"))

    (define input-port? (%primitive "input-port?"))
    (define output-port? (%primitive "output-port?"))
    (define binary-port? (%primitive "binary-port?"))
    (define textual-port? (%primitive "textual-port?"))
    (define input-port-open? (%primitive "input-port-open?"))
    (define output-port-open? (%primitive "output-port-open?"))

    (define bytevector? (%primitive "bytevector?"))
    (define make-bytevector (%primitive "make-bytevector"))
    (define bytevector (%primitive "bytevector"))
    (define bytevector-length (%primitive "bytevector-length"))
    (define bytevector-u8-ref (%primitive "bytevector-u8-ref"))
    (define bytevector-u8-set! (%primitive "bytevector-u8-set!"))
    (define bytevector-copy (%primitive "bytevector-copy"))
    (define bytevector-copy! (%primitive "bytevector-copy!"))
    (define bytevector-append (%primitive "bytevector-append"))
    (define utf8->string (%primitive "utf8->string"))
    (define string->utf8 (%primitive "string->utf8"))

    (define open-input-bytevector (%primitive "open-input-bytevector"))
    (define open-output-bytevector (%primitive "open-output-bytevector"))
    (define get-output-bytevector (%primitive "get-output-bytevector"))
    (define read-u8 (%primitive "read-u8"))
    (define peek-u8 (%primitive "peek-u8"))
    (define write-u8 (%primitive "write-u8"))
    (define (u8-ready? . args)
      "Syntax: (u8-ready?)
       (u8-ready? port)
Library: (scheme base)
Description: Returns #t if a byte is ready on the binary input port and returns
  #f otherwise. If the port is at end of file then u8-ready? returns #t. This
  implementation always returns #t.
Example:
  (u8-ready? (open-input-bytevector #u8(1 2 3))) => #t"
      #t)
    (define read-bytevector (%primitive "read-bytevector"))
    (define read-bytevector! (%primitive "read-bytevector!"))
    (define write-bytevector (%primitive "write-bytevector"))

    (define length (%primitive "length"))
    (define (zero? n)
      "Syntax: (zero? z)
Library: (scheme base)
Description: Returns #t if z is zero, #f otherwise.
Example:
  (zero? 0)   => #t
  (zero? 1)   => #f
  (zero? 0.0) => #t"
      (= n 0))
    (define (positive? num)
      "Syntax: (positive? x)
Library: (scheme base)
Description: Returns #t if x is positive, #f otherwise.
Example:
  (positive? 1)  => #t
  (positive? -1) => #f
  (positive? 0)  => #f"
      (> num 0))
    (define (negative? num)
      "Syntax: (negative? x)
Library: (scheme base)
Description: Returns #t if x is negative, #f otherwise.
Example:
  (negative? -1) => #t
  (negative? 1)  => #f
  (negative? 0)  => #f"
      (< num 0))
    (define (inexact? n)
      "Syntax: (inexact? z)
Library: (scheme base)
Description: Returns #t if z is inexact (i.e., not exact), #f otherwise.
Example:
  (inexact? 1.0) => #t
  (inexact? 1)   => #f"
      (not (exact? n)))
    (define complex? (%primitive "complex?"))
    (define (rational? x)
      "Syntax: (rational? obj)
Library: (scheme base)
Description: Returns #t if obj is a rational number. All finite real numbers
  (including inexact reals like 1.0 and 1.5) are rational. +inf.0, -inf.0,
  and +nan.0 are not rational.
Example:
  (rational? 1)      => #t
  (rational? 1/2)    => #t
  (rational? 1.0)    => #t
  (rational? +inf.0) => #f
  (rational? +nan.0) => #f"
      (and (real? x)
           (not (= x +inf.0))
           (not (= x -inf.0))
           (= x x)))

    (define (rationalize x y)
      "Syntax: (rationalize x y)
Library: (scheme base)
Description: Returns the simplest rational number within y of x. The simplest
  rational is the one with the smallest denominator. If x is exact, returns an
  exact result; if inexact, returns an inexact result.
Example:
  (rationalize (exact .3) 1/10) => 1/3
  (rationalize .3 1/10) => 0.3333333333333333"
      (define (simplest lo hi)
        (cond
          ((>= (floor lo) lo)
           ;; lo is an integer — it's the simplest
           (exact (floor lo)))
          ((<= (ceiling lo) hi)
           ;; there's an integer in the interval
           (exact (ceiling lo)))
          (else
           ;; no integer in interval — recurse on reciprocals
           (let ((n (floor lo)))
             (+ n (/ 1 (simplest (/ 1 (- hi n)) (/ 1 (- lo n)))))))))
      (let ((result
             (if (zero? y)
                 (exact x)
                 (let ((lo (- (exact x) (abs (exact y))))
                       (hi (+ (exact x) (abs (exact y)))))
                   (cond
                     ((<= lo 0 hi) 0)
                     ((positive? lo) (simplest lo hi))
                     (else (- (simplest (- hi) (- lo)))))))))
        (if (inexact? x) (inexact result) result)))

    (define (procedure? obj)
      "Syntax: (procedure? obj)
Library: (scheme base)
Description: Returns #t if obj is a procedure, #f otherwise. A procedure is
  either a lambda (user-defined closure) or a primitive (built-in procedure).
Example:
  (procedure? car)       => #t
  (procedure? (lambda (x) x)) => #t
  (procedure? 42)        => #f"
      (or (lambda? obj)
          (primitive? obj)))

    (define list? (%primitive "list?"))

    (define (abs n)
      "Syntax: (abs x)
Library: (scheme base)
Description: Returns the absolute value of its argument.
Example:
  (abs -7) => 7
  (abs 7)  => 7
  (abs 0)  => 0"
      (if (< n 0)
          (- n)
          n))

    (define (gcd . ls)
      "Syntax: (gcd n1 ...)
Library: (scheme base)
Description: Returns the greatest common divisor of its arguments. The result
  is always non-negative. With no arguments, returns 0.
Example:
  (gcd 32 -36) => 4
  (gcd)        => 0
  (gcd 32 -36 12) => 4"
      (let ((gcd2 (lambda (a b)
		    (let loop ((a (abs a)) (b (abs b)))
		      (cond
		       ((= b 0) a)
		       (else (loop b (modulo a b))))))))
        (if (= (length ls) 2)
	    (apply gcd2 ls)
	    (let loop ((ls ls) (g 0))
	      (if (null? ls)
	          g
	          (loop (cdr ls) (gcd2 (car ls) g)))))))

    (define (lcm . ls)
      "Syntax: (lcm n1 ...)
Library: (scheme base)
Description: Returns the least common multiple of its arguments. The result
  is always non-negative. With no arguments, returns 1.
Example:
  (lcm 32 -36) => 288
  (lcm)        => 1
  (lcm 32 -36 12) => 288"
      (let ((lcm2 (lambda (a b)
		    (abs (/ (* a b) (gcd a b))))))
        (if (= (length ls) 2)
	    (apply lcm2 ls)
	    (let loop ((ls ls) (r 1))
	      (if (null? ls)
	          r
	          (loop (cdr ls) (lcm2 (car ls) r)))))))

    ;; multi-list map (R7RS)
    ;; map is defined in library.scm (scm core) and re-exported here.

    (define (for-each f ls . more)
      "Syntax: (for-each proc list1 list2 ...)
Library: (scheme base)
Description: The arguments to for-each are like the arguments to map, but
  for-each calls proc for its side effects rather than for its values. Unlike
  map, for-each is guaranteed to call proc on the elements of the lists in
  order from the first element(s) to the last. The return values of for-each
  are unspecified.
Example:
  (for-each display '(a b c))    ; displays abc
  (for-each + '(1 2 3) '(4 5 6)) ; calls +, side effects only"
      (do ((ls ls (cdr ls)) (more more (map cdr more)))
          ((null? ls))
        (apply f (car ls) (map car more))))

    ;; string->list with optional start/end
    (define (string->list s . args)
      "Syntax: (string->list string)
       (string->list string start)
       (string->list string start end)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated list of the characters of string
  between start and end. start defaults to 0 and end defaults to the length
  of string.
Example:
  (string->list \"abc\")     => (#\\a #\\b #\\c)
  (string->list \"abc\" 1)   => (#\\b #\\c)
  (string->list \"abc\" 1 2) => (#\\b)"
      (let* ((start (if (null? args) 0 (car args)))
             (end   (if (or (null? args) (null? (cdr args)))
                        (string-length s)
                        (cadr args))))
        (do ((i (- end 1) (- i 1))
             (ls '() (cons (string-ref s i) ls)))
            ((< i start) ls))))

    (define (list->string ls)
      "Syntax: (list->string list)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated string formed from the characters in
  list. It is an error if any element of list is not a character.
Example:
  (list->string '(#\\a #\\b #\\c)) => \"abc\"
  (list->string '())              => \"\""
      (let ((s (make-string (length ls))))
        (do ((ls ls (cdr ls)) (i 0 (+ i 1)))
            ((null? ls) s)
          (string-set! s i (car ls)))))

    (define (string-fill! s c . args)
      "Syntax: (string-fill! string char)
       (string-fill! string char start)
       (string-fill! string char start end)
Library: (scheme base) (srfi 13)
Description: Stores char in every element of the given string between start
  and end. start defaults to 0 and end defaults to the length of the string.
Example:
  (let ((s (make-string 3 #\\a)))
    (string-fill! s #\\x)
    s) => \"xxx\"
  (let ((s (string-copy \"hello\")))
    (string-fill! s #\\x 1 3)
    s) => \"hxxlo\""
      (let* ((start (if (null? args) 0 (car args)))
             (end   (if (or (null? args) (null? (cdr args)))
                        (string-length s) (cadr args))))
        (do ((i start (+ i 1)))
            ((= i end))
          (string-set! s i c))))

    ;; string-copy with optional start/end
    (define (string-copy s . args)
      "Syntax: (string-copy string)
       (string-copy string start)
       (string-copy string start end)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated copy of the part of the given string
  between start and end. start defaults to 0 and end defaults to the length
  of the string.
Example:
  (string-copy \"abc\")     => \"abc\"
  (string-copy \"abc\" 1)   => \"bc\"
  (string-copy \"abc\" 1 2) => \"b\""
      (if (null? args)
          (substring s 0 (string-length s))
          (let* ((start (car args))
                 (end (if (null? (cdr args)) (string-length s) (cadr args))))
            (substring s start end))))

    ;; string-copy!
    (define (string-copy! to at from . args)
      "Syntax: (string-copy! to at from)
       (string-copy! to at from start)
       (string-copy! to at from start end)
Library: (scheme base) (srfi 13)
Description: Copies the characters of string from between start and end to
  string to, starting at at. The order in which characters are copied is
  unspecified, except that if the source and destination overlap, copying
  takes place as if the source is first copied into a temporary string and
  then into the destination. start defaults to 0 and end defaults to the
  length of from.
Example:
  (let ((s (string-copy \"hello\")))
    (string-copy! s 1 \"xyz\" 0 2)
    s) => \"hxylo\""
      (let* ((start (if (null? args) 0 (car args)))
             (end   (if (or (null? args) (null? (cdr args)))
                        (string-length from) (cadr args))))
        (if (and (eq? to from) (> at start))
            ;; Copy backwards to handle overlap correctly
            (do ((i (- end 1) (- i 1)))
                ((< i start))
              (string-set! to (+ at (- i start)) (string-ref from i)))
            (do ((i start (+ i 1)))
                ((= i end))
              (string-set! to (+ at (- i start)) (string-ref from i))))))

    (define (vector-fill! v x . args)
      "Syntax: (vector-fill! vector fill)
       (vector-fill! vector fill start)
       (vector-fill! vector fill start end)
Library: (scheme base)
Description: Stores fill in every element of vector between start and end.
  start defaults to 0 and end defaults to the length of the vector.
Example:
  (let ((v (make-vector 3 0)))
    (vector-fill! v 5)
    v) => #(5 5 5)
  (let ((v (vector 1 2 3 4 5)))
    (vector-fill! v 0 1 3)
    v) => #(1 0 0 4 5)"
      (let* ((start (if (null? args) 0 (car args)))
             (end   (if (or (null? args) (null? (cdr args)))
                        (vector-length v) (cadr args))))
        (do ((i start (+ i 1)))
            ((= i end))
          (vector-set! v i x))))

    (define (list->vector ls)
      "Syntax: (list->vector list)
Library: (scheme base)
Description: Returns a newly created vector initialized to the elements of
  the argument list.
Example:
  (list->vector '(a b c)) => #(a b c)
  (list->vector '())      => #()"
      (let ((s (make-vector (length ls))))
        (do ((ls ls (cdr ls)) (i 0 (+ i 1)))
            ((null? ls) s)
          (vector-set! s i (car ls)))))

    ;; vector-copy with optional start/end
    (define (vector-copy v . args)
      "Syntax: (vector-copy vector)
       (vector-copy vector start)
       (vector-copy vector start end)
Library: (scheme base)
Description: Returns a newly allocated copy of the elements of the given
  vector between start and end. start defaults to 0 and end defaults to the
  length of the vector.
Example:
  (vector-copy '#(a b c d e) 2 4) => #(c d)
  (vector-copy '#(a b c))         => #(a b c)"
      (let* ((start (if (null? args) 0 (car args)))
             (end   (if (or (null? args) (null? (cdr args)))
                        (vector-length v) (cadr args)))
             (r (make-vector (- end start))))
        (do ((i start (+ i 1)))
            ((= i end) r)
          (vector-set! r (- i start) (vector-ref v i)))))

    ;; vector-copy!
    (define (vector-copy! to at from . args)
      "Syntax: (vector-copy! to at from)
       (vector-copy! to at from start)
       (vector-copy! to at from start end)
Library: (scheme base)
Description: Copies the elements of vector from between start and end to
  vector to, starting at at. The order in which elements are copied is
  unspecified, except that if the source and destination overlap, copying
  takes place as if the source is first copied into a temporary vector and
  then into the destination. start defaults to 0 and end defaults to the
  length of from.
Example:
  (let ((v (vector 1 2 3 4 5)))
    (vector-copy! v 1 '#(10 11 12) 1 3)
    v) => #(1 11 12 4 5)"
      (let* ((start (if (null? args) 0 (car args)))
             (end   (if (or (null? args) (null? (cdr args)))
                        (vector-length from) (cadr args))))
        (if (and (eq? to from) (> at start))
            ;; Copy backwards to handle overlap correctly
            (do ((i (- end 1) (- i 1)))
                ((< i start))
              (vector-set! to (+ at (- i start)) (vector-ref from i)))
            (do ((i start (+ i 1)))
                ((= i end))
              (vector-set! to (+ at (- i start)) (vector-ref from i))))))

    (define (numerator x)
      "Syntax: (numerator q)
Library: (scheme base)
Description: Returns the numerator of q, where q is a rational number. If q
  is an integer, the numerator is q itself. For inexact reals, returns the
  numerator as an inexact number.
Example:
  (numerator (/ 6 4)) => 3
  (numerator 7)       => 7
  (numerator 1.5)     => 3.0"
      ((%primitive "rational-numerator") x))
    (define (denominator x)
      "Syntax: (denominator q)
Library: (scheme base)
Description: Returns the denominator of q, where q is a rational number. If q
  is an integer, the denominator is 1. For inexact reals, returns the
  denominator as an inexact number.
Example:
  (denominator (/ 6 4)) => 2
  (denominator 7)       => 1
  (denominator 1.5)     => 2.0"
      ((%primitive "rational-denominator") x))

    ;; square
    (define (square x)
      "Syntax: (square z)
Library: (scheme base)
Description: Returns the square of z. This is equivalent to (* z z).
Example:
  (square 5)   => 25
  (square -3)  => 9
  (square 2.0) => 4.0"
      (* x x))

    ;; exact-integer-sqrt (R7RS 6.2.6)
    (define (exact-integer-sqrt k)
      "Syntax: (exact-integer-sqrt k)
Library: (scheme base)
Description: Returns two non-negative exact integer values s and r such that
  k = s^2 + r and k < (s+1)^2. In other words, s is the largest integer such
  that s^2 is not greater than k, and r is the remainder.
Example:
  (exact-integer-sqrt 4) => 2 0
  (exact-integer-sqrt 5) => 2 1
  (exact-integer-sqrt 14) => 3 5"
      (cond
        ((negative? k) (error "exact-integer-sqrt: negative argument" k))
        ((zero? k) (values 0 0))
        ((<= k 4503599627370496) ;; 2^52 — safe for double precision
         (let ((s (exact (floor (sqrt (inexact k))))))
           (values s (- k (* s s)))))
        (else
         ;; Newton's method for arbitrary precision integers
         (let* ((bit-len (let loop ((n k) (bits 0))
                           (if (zero? n) bits (loop (quotient n 2) (+ bits 1)))))
                (init (expt 2 (quotient (+ bit-len 1) 2))))
           (let loop ((s init))
             (let ((s1 (quotient (+ s (quotient k s)) 2)))
               (if (< s1 s)
                   (loop s1)
                   (values s (- k (* s s))))))))))

    ;; boolean=?
    (define (boolean=? b . rest)
      "Syntax: (boolean=? boolean1 boolean2 ...)
Library: (scheme base)
Description: Returns #t if all the arguments are booleans with the same truth
  value, #f otherwise.
Example:
  (boolean=? #t #t)    => #t
  (boolean=? #f #f)    => #t
  (boolean=? #t #f)    => #f
  (boolean=? #t #t #t) => #t"
      (let loop ((rest rest))
        (or (null? rest)
            (and (eq? b (car rest))
                 (loop (cdr rest))))))

    ;; exact-integer?
    (define (exact-integer? x)
      "Syntax: (exact-integer? z)
Library: (scheme base)
Description: Returns #t if z is both exact and an integer, #f otherwise.
Example:
  (exact-integer? 1)   => #t
  (exact-integer? 1.0) => #f
  (exact-integer? 1/2) => #f"
      (and (exact? x) (integer? x)))

    ;; floor-quotient, floor-remainder, floor/
    (define (floor-quotient n d)
      "Syntax: (floor-quotient n1 n2)
Library: (scheme base)
Description: Returns the floor quotient of n1 divided by n2. The floor
  quotient is the largest integer not larger than the real-valued quotient
  n1/n2. It satisfies n1 = q*n2 + r where q is the floor quotient.
Example:
  (floor-quotient 5 2)   => 2
  (floor-quotient -5 2)  => -3
  (floor-quotient 5 -2)  => -3"
      (exact (floor (/ n d))))
    (define (floor-remainder n d)
      "Syntax: (floor-remainder n1 n2)
Library: (scheme base)
Description: Returns the floor remainder of n1 divided by n2. The floor
  remainder r satisfies n1 = (floor-quotient n1 n2)*n2 + r. The result has
  the same sign as n2.
Example:
  (floor-remainder 5 2)   => 1
  (floor-remainder -5 2)  => 1
  (floor-remainder 5 -2)  => -1"
      (- n (* (floor-quotient n d) d)))
    (define (floor/ n d)
      "Syntax: (floor/ n1 n2)
Library: (scheme base)
Description: Returns two values: the floor quotient and the floor remainder
  of n1 divided by n2. Equivalent to calling floor-quotient and
  floor-remainder separately, but potentially more efficient.
Example:
  (floor/ 5 2)  => 2 1
  (floor/ -5 2) => -3 1"
      (values (floor-quotient n d) (floor-remainder n d)))

    ;; truncate-quotient, truncate-remainder, truncate/
    (define truncate-quotient quotient)
    (define truncate-remainder remainder)
    (define (truncate/ n d)
      "Syntax: (truncate/ n1 n2)
Library: (scheme base)
Description: Returns two values: the truncate quotient and the truncate
  remainder of n1 divided by n2. The truncate quotient is the integer of
  largest absolute value that is not larger than the real-valued quotient n1/n2.
  Equivalent to calling quotient and remainder separately.
Example:
  (truncate/ 5 2)  => 2 1
  (truncate/ -5 2) => -2 -1"
      (values (quotient n d) (remainder n d)))

    ;; list-set!
    (define (list-set! lst k val)
      "Syntax: (list-set! list k obj)
Library: (scheme base)
Description: Stores obj in element k of list. It is an error if k is not a
  valid index of list. The result is unspecified.
Example:
  (let ((ls (list 'a 'b 'c)))
    (list-set! ls 1 'x)
    ls) => (a x c)"
      (set-car! (list-tail lst k) val))

    ;; list-copy
    (define (list-copy lst)
      "Syntax: (list-copy obj)
Library: (scheme base)
Description: Returns a newly allocated copy of the given list. Only the pairs
  themselves are copied; the cars of the result are the same (in the sense of
  eqv?) as the cars of list. If the last cdr of the list is not the empty
  list, the result is an improper list with the same final cdr as the
  argument.
Example:
  (list-copy '(a b c)) => (a b c)
  (list-copy '())      => ()
  (list-copy '(a b . c)) => (a b . c)"
      (let loop ((lst lst))
        (if (pair? lst)
            (cons (car lst) (loop (cdr lst)))
            lst)))

    ;; string->vector / vector->string
    (define (string->vector s . args)
      "Syntax: (string->vector string)
       (string->vector string start)
       (string->vector string start end)
Library: (scheme base)
Description: Returns a newly created vector initialized to the elements of
  the string between start and end. start defaults to 0 and end defaults to
  the length of the string.
Example:
  (string->vector \"abc\")     => #(#\\a #\\b #\\c)
  (string->vector \"abc\" 1)   => #(#\\b #\\c)
  (string->vector \"abc\" 1 2) => #(#\\b)"
      (list->vector (apply string->list s args)))

    (define (vector->string v . args)
      "Syntax: (vector->string vector)
       (vector->string vector start)
       (vector->string vector start end)
Library: (scheme base)
Description: Returns a newly allocated string of the objects contained in the
  elements of vector between start and end. It is an error if any element is
  not a character. start defaults to 0 and end defaults to the length of the
  vector.
Example:
  (vector->string #(#\\a #\\b #\\c))     => \"abc\"
  (vector->string #(#\\a #\\b #\\c) 1)   => \"bc\"
  (vector->string #(#\\a #\\b #\\c) 1 2) => \"b\""
      (let* ((start (if (null? args) 0 (car args)))
             (end   (if (or (null? args) (null? (cdr args)))
                        (vector-length v) (cadr args))))
        (let ((s (make-string (- end start))))
          (do ((i start (+ i 1)))
              ((= i end) s)
            (string-set! s (- i start) (vector-ref v i))))))

    ;; vector-append
    (define (vector-append . vecs)
      "Syntax: (vector-append vector ...)
Library: (scheme base)
Description: Returns a newly allocated vector whose elements are the
  concatenation of the elements of the given vectors. With no arguments,
  returns an empty vector.
Example:
  (vector-append '#(a b) '#(c d)) => #(a b c d)
  (vector-append '#(a) '#() '#(b c)) => #(a b c)"
      (list->vector (apply append (map vector->list vecs))))

    ;; vector-map
    (define (vector-map f . vecs)
      "Syntax: (vector-map proc vector1 vector2 ...)
Library: (scheme base)
Description: It is an error if proc does not accept as many arguments as
  there are vectors and return a single value. Applies proc element-wise to
  the elements of the vectors and returns a vector of the results. The
  dynamic order in which proc is applied to the elements is unspecified.
Example:
  (vector-map + '#(1 2 3) '#(4 5 6)) => #(5 7 9)
  (vector-map cadr '#((a b) (d e) (g h))) => #(b e h)"
      (list->vector (apply map f (map vector->list vecs))))

    ;; vector-for-each
    (define (vector-for-each f . vecs)
      "Syntax: (vector-for-each proc vector1 vector2 ...)
Library: (scheme base)
Description: It is an error if proc does not accept as many arguments as
  there are vectors. Applies proc element-wise to the elements of the vectors
  for its side effects, in order from the first element to the last. The
  return value is unspecified.
Example:
  (vector-for-each display '#(a b c)) ; displays abc"
      (apply for-each f (map vector->list vecs)))

    ;; write-string
    (define (write-string s . args)
      "Syntax: (write-string string)
       (write-string string port)
       (write-string string port start)
       (write-string string port start end)
Library: (scheme base)
Description: Writes the characters of string from start to end in left-to-right
  order to the given port. port defaults to the current output port. start
  defaults to 0 and end defaults to the length of string. The return value is
  unspecified.
Example:
  (write-string \"hello\")          ; writes hello
  (write-string \"hello\" (current-output-port) 1 3) ; writes el"
      (let* ((port  (if (null? args) (current-output-port) (car args)))
             (start (if (or (null? args) (null? (cdr args))) 0 (cadr args)))
             (end   (if (or (null? args) (null? (cdr args)) (null? (cddr args)))
                        (string-length s) (car (cddr args)))))
        (do ((i start (+ i 1)))
            ((= i end))
          (write-char (string-ref s i) port))))

    ;; read-string
    (define (read-string k . args)
      "Syntax: (read-string k)
       (read-string k port)
Library: (scheme base)
Description: Reads the next k characters, or as many as are available before
  the end of file, from the textual input port into a newly allocated string
  in left-to-right order and returns the string. If no characters are
  available before the end of file, an end-of-file object is returned. port
  defaults to the current input port.
Example:
  (read-string 3 (open-input-string \"hello\")) => \"hel\""
      (let ((port (if (null? args) (current-input-port) (car args))))
        (let loop ((i 0) (chars '()))
          (if (= i k)
              (list->string (reverse chars))
              (let ((c (read-char port)))
                (if (eof-object? c)
                    (if (null? chars) c (list->string (reverse chars)))
                    (loop (+ i 1) (cons c chars))))))))

    ;; port? close-port
    (define (port? x)
      "Syntax: (port? obj)
Library: (scheme base)
Description: Returns #t if obj is a port (either an input port or an output
  port), #f otherwise.
Example:
  (port? (current-input-port))  => #t
  (port? (current-output-port)) => #t
  (port? 42)                    => #f"
      (or (input-port? x) (output-port? x)))
    (define (close-port p)
      "Syntax: (close-port port)
Library: (scheme base)
Description: Closes the resource associated with port, rendering the port
  incapable of delivering or accepting data. If port is an input port,
  close-input-port is called on it; if port is an output port,
  close-output-port is called on it. The return value is unspecified.
Example:
  (let ((p (open-input-string \"hello\")))
    (close-port p))"
      (if (input-port? p)
          (close-input-port p)
          (close-output-port p)))

    ;; call-with-port
    (define (call-with-port port proc)
      "Syntax: (call-with-port port proc)
Library: (scheme base)
Description: Calls proc with port as an argument. If proc returns, then the
  port is closed automatically and the values yielded by proc are returned.
  If proc does not return, then the port will not be closed automatically,
  unless it is possible to detect that the port will never again be used.
Example:
  (call-with-port (open-input-string \"hello\")
    (lambda (p) (read-char p))) => #\\h"
      (dynamic-wind
        (lambda () #f)
        (lambda () (proc port))
        (lambda () (close-port port))))

    ;; eof-object — create one by reading from empty string port
    (define eof-object
      (let ((e (read-char (open-input-string ""))))
        (lambda () e)))

    ;; make-parameter / parameterize
    (define (make-parameter init . rest)
      "Syntax: (make-parameter init)
       (make-parameter init converter)
Library: (scheme base)
Description: Returns a newly allocated parameter object, which is a procedure
  that accepts zero or one argument. When called with no argument, the
  parameter object returns its current value. When called with one argument,
  the parameter is set to the new value after passing it through the optional
  converter procedure. The converter is applied to init to produce the initial
  value.
Example:
  (define p (make-parameter 10))
  (p)      => 10
  (p 20)
  (p)      => 20
  (define q (make-parameter 10 (lambda (x) (* x 2))))
  (q)      => 20"
      (let* ((convert (if (null? rest) (lambda (x) x) (car rest)))
             (val (convert init)))
        (lambda args
          (if (null? args)
              val
              (set! val (convert (car args)))))))

    (define-syntax parameterize
      "Syntax: (parameterize ((param val) ...) body ...)
Library: (scheme base)
Description: A parameterize expression is used to change the values returned
  by specified parameter objects during the evaluation of the body. Each param
  expression must evaluate to a parameter object. For each parameter binding,
  the parameter object is called with the new value to update it. After the
  body forms are evaluated (even via continuations or exceptions), each
  parameter is restored to its previous value via dynamic-wind.
  The result of the parameterize expression is the value of the last body form.
Example:
  (define p (make-parameter 1))
  (parameterize ((p 2))
    (p)) => 2
  (p) => 1"
      (syntax-rules ()
        ((parameterize () body ...)
         (let () body ...))
        ((parameterize ((p v) rest ...) body ...)
         (let ((param p) (new-val v))
           (let ((old-val (param)))
             (dynamic-wind
               (lambda () (param new-val))
               (lambda () (parameterize (rest ...) body ...))
               (lambda () (param old-val))))))))

    ;; features
    (define features (%primitive "%features-list"))

    ;; guard (R7RS 6.11)
    ;; guard-aux handles the cond-like clauses
    (define-syntax guard-aux
      "Syntax: (guard-aux reraise clause ...)
Library: (scheme base)
Description: Internal helper macro used by guard to process the cond-like
  clauses. reraise is the expression to evaluate if no clause matches.
  Clauses have the same form as in cond, including => and else support.
  Not intended for direct use."
      (syntax-rules (else =>)
        ((guard-aux reraise (else e1 e2 ...))
         (begin e1 e2 ...))
        ((guard-aux reraise (test => handler))
         (let ((t test))
           (if t (handler t) reraise)))
        ((guard-aux reraise (test => handler) clause ...)
         (let ((t test))
           (if t (handler t) (guard-aux reraise clause ...))))
        ((guard-aux reraise (test))
         (or test reraise))
        ((guard-aux reraise (test) clause ...)
         (let ((t test))
           (if t t (guard-aux reraise clause ...))))
        ((guard-aux reraise (test e1 e2 ...))
         (if test (begin e1 e2 ...) reraise))
        ((guard-aux reraise (test e1 e2 ...) clause ...)
         (if test (begin e1 e2 ...) (guard-aux reraise clause ...)))))

    (define-syntax guard
      "Syntax: (guard (var clause ...) body ...)
Library: (scheme base)
Description: Evaluates body in a context where, if an exception is raised,
  var is bound to the condition object and the clauses are evaluated as in a
  cond expression. If a clause matches, its body is evaluated and the result
  is returned. If no clause matches, the exception is re-raised. If an else
  clause is present, it is used when no other clause matches. Clauses may use
  => syntax.
Example:
  (guard (e ((string? (error-object-message e)) (error-object-message e)))
    (error \"oops\")) => \"oops\"
  (guard (e (#t 'caught))
    (error \"anything\")) => caught"
      (syntax-rules ()
        ((guard (var clause ...) e1 e2 ...)
         (call/cc
          (lambda (guard-k)
            (with-exception-handler
             (lambda (condition)
               (let ((var condition))
                 (call/cc
                  (lambda (handler-k)
                    (guard-k
                     (guard-aux
                      (handler-k (raise-continuable condition))
                      clause ...))))))
             (lambda ()
               (call-with-values
                (lambda () e1 e2 ...)
                (lambda args
                  (apply guard-k args))))))))))

    ;; SRFI 11 reference implementation for let-values.
    ;; Uses helper clauses "bind" and "mktmp" to collect temporaries.
    ;; Template-introduced x gets unique Dybvig marks — no gensym needed.
    (define-syntax let-values
      "Syntax: (let-values (((var ...) expr) ...) body ...)
Library: (scheme base)
Description: This form is analogous to let, but each var is bound to the
  corresponding value returned by its init expression, which must return as
  many values as there are variables. The formals for each binding may be
  any <formals> list as in a lambda expression. The init expressions are
  evaluated in the current environment and each var is bound to the
  corresponding value in the body, which is evaluated in the extended
  environment.
Example:
  (let-values (((a b) (values 1 2)))
    (+ a b)) => 3
  (let-values (((a b) (values 1 2))
               ((c)   (values 3)))
    (list a b c)) => (1 2 3)"
      (syntax-rules ()
        ((let-values (?binding ...) ?body0 ?body1 ...)
         (let-values "bind" (?binding ...) () (begin ?body0 ?body1 ...)))
        ((let-values "bind" () ?tmps ?body)
         (let ?tmps ?body))
        ((let-values "bind" ((?b0 ?e0) ?binding ...) ?tmps ?body)
         (let-values "mktmp" ?b0 ?e0 () (?binding ...) ?tmps ?body))
        ((let-values "mktmp" () ?e0 ?args ?bindings ?tmps ?body)
         (call-with-values
           (lambda () ?e0)
           (lambda ?args
             (let-values "bind" ?bindings ?tmps ?body))))
        ((let-values "mktmp" (?a . ?b) ?e0 (?arg ...) ?bindings (?tmp ...) ?body)
         (let-values "mktmp" ?b ?e0 (?arg ... x) ?bindings (?tmp ... (?a x)) ?body))
        ((let-values "mktmp" ?a ?e0 (?arg ...) ?bindings (?tmp ...) ?body)
         (call-with-values
           (lambda () ?e0)
           (lambda (?arg ... . x)
             (let-values "bind" ?bindings (?tmp ... (?a x)) ?body))))))

    (define-syntax let*-values
      "Syntax: (let*-values (((var ...) expr) ...) body ...)
Library: (scheme base)
Description: Semantics like let-values, but the bindings are performed
  sequentially from left to right, and the init expressions are evaluated
  in the environment in which the preceding bindings are visible. Thus
  each binding has access to all preceding bindings.
Example:
  (let*-values (((a b) (values 1 2))
                ((c)   (values (+ a b))))
    c) => 3"
      (syntax-rules ()
        ((let*-values () ?body0 ?body1 ...)
         (let () ?body0 ?body1 ...))
        ((let*-values (?binding0 ?binding1 ...) ?body0 ?body1 ...)
         (let-values (?binding0)
           (let*-values (?binding1 ...) ?body0 ?body1 ...)))))

    (define-syntax define-values
      "Syntax: (define-values formals expression)
Library: (scheme base)
Description: Defines variables whose names and number are determined by
  formals in the same way as a lambda expression, and initializes them to
  the return values of expression. It is an error if expression does not
  return the correct number of values for the given formals. This form may
  appear wherever other definition forms are allowed.
Example:
  (define-values (a b c) (values 1 2 3))
  a => 1
  b => 2
  c => 3"
      (syntax-rules ()
        ((define-values () expr)
         (call-with-values (lambda () expr) (lambda () (if #f #f))))
        ((define-values (var) expr)
         (define var (call-with-values (lambda () expr) (lambda (v) v))))
        ((define-values (var rest ...) expr)
         (begin
           (define var #f)
           (define-values (rest ...) (call-with-values (lambda () expr)
             (lambda (v . vs) (set! var v) (apply values vs))))))
        ((define-values (var . rest) expr)
         (begin
           (define var #f)
           (define-values rest (call-with-values (lambda () expr)
             (lambda (v . vs) (set! var v) (apply values vs))))))
        ((define-values var expr)
         (define var (call-with-values (lambda () expr) list)))))

    ;; symbol=? (R7RS base)
    (define (symbol=? s . rest)
      "Syntax: (symbol=? symbol1 symbol2 ...)
Library: (scheme base)
Description: Returns #t if all the arguments are symbols with the same names,
  in the sense of string=?. It is an error to apply symbol=? to anything other
  than symbols.
Example:
  (symbol=? 'foo 'foo)      => #t
  (symbol=? 'foo 'bar)      => #f
  (symbol=? 'foo 'foo 'foo) => #t"
      (or (null? rest)
          (and (eq? s (car rest))
               (apply symbol=? s (cdr rest)))))

    ;; make-list (R7RS base)
    (define (make-list n . args)
      "Syntax: (make-list k)
       (make-list k fill)
Library: (scheme base)
Description: Returns a newly allocated list of k elements. If a second
  argument is given, then each element is initialized to fill. Otherwise
  the initial contents of each element is unspecified (defaults to #f).
Example:
  (make-list 3)      => (#f #f #f)
  (make-list 3 'x)   => (x x x)
  (make-list 0)      => ()"
      (let ((fill (if (null? args) #f (car args))))
        (let loop ((i n) (acc '()))
          (if (= i 0) acc (loop (- i 1) (cons fill acc))))))

    ;; string-map (R7RS base + SRFI-13 start/end)
    (define (string-map f s . more)
      "Syntax: (string-map proc string1 string2 ...)
       (string-map proc string [start [end]])
Library: (scheme base) (srfi 13)
Description: When given multiple strings, applies proc element-wise to the
  characters of the strings and returns a string of the results. If multiple
  strings are given, they must all have the same length (R7RS).
  When given optional integer start/end indices, maps proc over the characters
  of string[start..end) and returns a new string (SRFI-13).
Example:
  (string-map char-upcase \"hello\")       => \"HELLO\"
  (string-map char-upcase \"hello\" 1 3)   => \"EL\"
  (string-map (lambda (c) c) \"xyz\")      => \"xyz\""
      (if (null? more)
          (let* ((n (string-length s)) (r (make-string n)))
            (do ((i 0 (+ i 1))) ((= i n) r)
              (string-set! r i (f (string-ref s i)))))
          (if (integer? (car more))
              (let* ((start (car more))
                     (end (if (null? (cdr more)) (string-length s) (cadr more)))
                     (n (- end start))
                     (r (make-string n)))
                (do ((i 0 (+ i 1))) ((= i n) r)
                  (string-set! r i (f (string-ref s (+ start i))))))
              (list->string (apply map f (map string->list (cons s more)))))))

    ;; string-for-each (R7RS base + SRFI-13 start/end)
    (define (string-for-each f s . more)
      "Syntax: (string-for-each proc string1 string2 ...)
       (string-for-each proc string [start [end]])
Library: (scheme base) (srfi 13)
Description: When given multiple strings, applies proc element-wise to the
  characters of the strings in order for side effects (R7RS).
  When given optional integer start/end indices, applies proc to each
  character of string[start..end) in order (SRFI-13).
Example:
  (string-for-each display \"abc\") ; displays abc"
      (if (null? more)
          (let ((n (string-length s)))
            (do ((i 0 (+ i 1))) ((= i n))
              (f (string-ref s i))))
          (if (integer? (car more))
              (let* ((start (car more))
                     (end (if (null? (cdr more)) (string-length s) (cadr more))))
                (do ((i start (+ i 1))) ((= i end))
                  (f (string-ref s i))))
              (apply for-each f (map string->list (cons s more))))))


    ;; include-ci — case-insensitive file loading
    (define include-ci (%primitive "include-ci"))


    ;; ---- R7RS/SRFI-9 define-record-type ----
    (define record? (%primitive "record?"))
    (define make-record (%primitive "make-record"))
    (define record-ref (%primitive "record-ref"))
    (define record-set! (%primitive "record-set!"))

    (define-syntax define-record-type
      "Syntax: (define-record-type <type> (<constructor> <field-name> ...) <predicate> (<field-name> <accessor> <modifier>) ...)
Library: (scheme base), (srfi 9)
Description: Defines a new record type. <type> is bound to the record type descriptor.
<constructor> is bound to a procedure that creates instances with the specified fields
initialized from the corresponding arguments. <predicate> is bound to a procedure that
returns #t for instances of this type. Each field clause binds <accessor> to a procedure
that retrieves the field value; an optional <modifier> is bound to a procedure that sets it.
Example:
  (define-record-type <point>
    (make-point x y)
    point?
    (x point-x)
    (y point-y point-set-y!))
  (define p (make-point 1 2))
  (point? p) => #t
  (point-x p) => 1
  (point-set-y! p 42)
  (point-y p) => 42"
      (syntax-rules ()
        ((define-record-type type
           (constructor constructor-tag ...)
           predicate
           (field-tag accessor . more) ...)
         (begin
           (define type
             (make-record-type 'type '(field-tag ...)))
           (define constructor
             (record-constructor type '(constructor-tag ...)))
           (define predicate
             (record-predicate type))
           (define-record-field type field-tag accessor . more)
           ...))))

    ;; An auxilliary macro for define field accessors and modifiers.
    ;; This is needed only because modifiers are optional.

    (define-syntax define-record-field
      (syntax-rules ()
        ((define-record-field type field-tag accessor)
         (define accessor (record-accessor type 'field-tag)))
        ((define-record-field type field-tag accessor modifier)
         (begin
           (define accessor (record-accessor type 'field-tag))
           (define modifier (record-modifier type 'field-tag))))))

    ;; We define the following procedures:
    ;; 
    ;; (make-record-type <type-name> <field-names>)    -> <record-type>
    ;; (record-constructor <record-type> <field-names>) -> <constructor>
    ;; (record-predicate <record-type>)               -> <predicate>
    ;; (record-accessor <record-type <field-name>)    -> <accessor>
    ;; (record-modifier <record-type <field-name>)    -> <modifier>
    ;;   where
    ;; (<constructor> <initial-value> ...)         -> <record>
    ;; (<predicate> <value>)                       -> <boolean>
    ;; (<accessor> <record>)                       -> <value>
    ;; (<modifier> <record> <value>)         -> <unspecific>

    ;; Record types are implemented using vector-like records.  The first
    ;; slot of each record contains the record's type, which is itself a
    ;; record.

    (define (record-type record)
      (record-ref record 0))

    ;;----------------
    ;; Record types are themselves records, so we first define the type for
    ;; them.  Except for problems with circularities, this could be defined as:
    ;;  (define-record-type :record-type
    ;;    (make-record-type name field-tags)
    ;;    record-type?
    ;;    (name record-type-name)
    ;;    (field-tags record-type-field-tags))
    ;; As it is, we need to define everything by hand.

    (define :record-type (make-record 3))
    (record-set! :record-type 0 :record-type)	; Its type is itself.
    (record-set! :record-type 1 ':record-type)
    (record-set! :record-type 2 '(name field-tags))

    ;; Now that :record-type exists we can define a procedure for making more
    ;; record types.

    (define (make-record-type name field-tags)
      (let ((new (make-record 3)))
        (record-set! new 0 :record-type)
        (record-set! new 1 name)
        (record-set! new 2 field-tags)
        new))

    ;; Accessors for record types.

    (define (record-type-name record-type)
      (record-ref record-type 1))

    (define (record-type-field-tags record-type)
      (record-ref record-type 2))

    ;;----------------
    ;; A utility for getting the offset of a field within a record.

    (define (field-index type tag)
      (let loop ((i 1) (tags (record-type-field-tags type)))
        (cond ((null? tags)
               (error "record type has no such field" type tag))
              ((eq? tag (car tags))
               i)
              (else
               (loop (+ i 1) (cdr tags))))))

    ;;----------------
    ;; Now we are ready to define RECORD-CONSTRUCTOR and the rest of the
    ;; procedures used by the macro expansion of DEFINE-RECORD-TYPE.

    (define (record-constructor type tags)
      (let ((size (length (record-type-field-tags type)))
            (arg-count (length tags))
            (indexes (map (lambda (tag)
                            (field-index type tag))
                          tags)))
        (lambda args
          (if (= (length args)
                 arg-count)
              (let ((new (make-record (+ size 1))))
                (record-set! new 0 type)
                (let loop ((as args) (is indexes))
                  (if (not (null? as))
                      (begin
                        (record-set! new (car is) (car as))
                        (loop (cdr as) (cdr is)))))
                new)
              (error "wrong number of arguments to constructor" type args)))))

    (define (record-predicate type)
      (lambda (thing)
        (and (record? thing)
             (eq? (record-type thing)
                  type))))

    (define (record-accessor type tag)
      (let ((index (field-index type tag)))
        (lambda (thing)
          (if (and (record? thing)
                   (eq? (record-type thing)
                        type))
              (record-ref thing index)
              (error "accessor applied to bad value" type tag thing)))))

    (define (record-modifier type tag)
      (let ((index (field-index type tag)))
        (lambda (thing value)
          (if (and (record? thing)
                   (eq? (record-type thing)
                        type))
              (record-set! thing index value)
              (error "modifier applied to bad value" type tag thing)))))
    ;; ---- end define-record-type ----

    ))

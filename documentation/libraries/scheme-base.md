# `(scheme base)`

R7RS base library — core forms and procedures

## Exports

### `*`

```
Syntax: (* z1 ...)
Library: (scheme base)
Description: Returns the product of its arguments. With no arguments, returns 1.
Example:
  (* 4 5) => 20
  (* 3) => 3
  (*) => 1
```

### `+`

```
Syntax: (+ z1 ...)
Library: (scheme base)
Description: Returns the sum of its arguments. With no arguments, returns 0.
Example:
  (+ 3 4) => 7
  (+ 3) => 3
  (+) => 0
```

### `-`

```
Syntax: (- z ...)
Library: (scheme base)
Description: With a single argument, returns the negation of z. With two or more arguments, returns the result of subtracting each successive argument from the first.
Example:
  (- 10 3 2) => 5
  (- 5) => -5
```

### `/`

```
Syntax: (/ z1 z2 ...)
Library: (scheme base)
Description: Returns the quotient of dividing z1 by the remaining arguments. With one argument, returns the multiplicative inverse 1/z1.
Example:
  (/ 10 2) => 5
  (/ 10 2 5) => 1
  (/ 4) => 1/4
```

### `<`

```
Syntax: (< z1 z2 z3 ...)
Library: (scheme base)
Description: Returns #t if the arguments are monotonically increasing.
Example:
  (< 1 2 3) => #t
  (< 1 1) => #f
```

### `<=`

```
Syntax: (<= z1 z2 z3 ...)
Library: (scheme base)
Description: Returns #t if the arguments are monotonically non-decreasing.
Example:
  (<= 1 2 3) => #t
  (<= 1 1) => #t
```

### `=`

```
Syntax: (= z1 z2 z3 ...)
Library: (scheme base)
Description: Returns #t if all arguments are numerically equal.
Example:
  (= 1 1 1) => #t
  (= 1 2) => #f
```

### `>`

```
Syntax: (> z1 z2 z3 ...)
Library: (scheme base)
Description: Returns #t if the arguments are monotonically decreasing.
Example:
  (> 3 2 1) => #t
  (> 3 3) => #f
```

### `>=`

```
Syntax: (>= z1 z2 z3 ...)
Library: (scheme base)
Description: Returns #t if the arguments are monotonically non-increasing.
Example:
  (>= 3 2 1) => #t
  (>= 3 3) => #t
```

### `abs`

```
Syntax: (abs x)
Library: (scheme base)
Description: Returns the absolute value of its argument.
Example:
  (abs -7) => 7
  (abs 7)  => 7
  (abs 0)  => 0
```

### `and`

```
Syntax: (and expr ...)
Library: (scheme base)
Description: Evaluates expressions left to right. Returns #f if any expression evaluates to #f, otherwise returns the value of the last expression. With no arguments, returns #t.
Example:
  (and 1 2 3) => 3
  (and 1 #f 3) => #f
  (and) => #t
```

### `append`

```
Syntax: (append list1 ... obj)
Library: (scheme base)
Description: Returns a list consisting of the elements of the first list followed by the elements of the other lists. The last argument may be any object.
Example:
  (append '(x) '(y)) => (x y)
  (append '(a) '(b c d)) => (a b c d)
  (append '(a b) '() '(c)) => (a b c)
```

### `apply`

```
Syntax: (apply proc arg1 ... args)
Library: (scheme base)
Description: Calls proc with the given arguments. The last argument must
  be a list, whose elements are appended to the preceding arguments.
Example:
  (apply + 1 2 '(3 4)) => 10
```

### `assoc`

```
Syntax: (assoc key alist)
Library: (scheme base)
Description: Searches association list alist for a pair whose car is equal? to key. Returns the first matching pair, or #f if none is found. An optional third argument may supply an alternative comparison procedure.
Example:
  (assoc "b" '(("a" 1) ("b" 2))) => (b 2)
  (assoc 2.0 '((1 a) (2 b)) =) => (2 b)
```

### `assq`

```
Syntax: (assq key alist)
Library: (scheme base)
Description: Searches association list alist for a pair whose car is eq? to key. Returns the first matching pair, or #f if none is found.
Example:
  (assq 'b '((a 1) (b 2) (c 3))) => (b 2)
  (assq 'd '((a 1) (b 2))) => #f
```

### `assv`

```
Syntax: (assv key alist)
Library: (scheme base)
Description: Searches association list alist for a pair whose car is eqv? to key. Returns the first matching pair, or #f if none is found. Similar to assq but uses eqv? for comparison.
Example:
  (assv 2 '((1 a) (2 b) (3 c))) => (2 b)
  (assv 5 '((1 a) (2 b))) => #f
```

### `begin`

```
Syntax: (begin expression ...)
Library: (scheme base)
Description: Evaluates expressions sequentially from left to right. The
  value of the last expression is returned. begin can also appear as a
  splicing form at the top level or at the beginning of a body, in which
  case the forms inside the begin are spliced into the surrounding body.
Example:
  (begin (define x 1) (+ x 2)) => 3
```

### `binary-port?`

```
Syntax: (binary-port? obj)
Library: (scheme base)
Description: Returns #t if obj is a binary port, otherwise returns #f.
Example:
  (binary-port? (open-input-bytevector #u8(1 2 3))) => #t
  (binary-port? (open-input-string "abc")) => #f
```

### `boolean=?`

```
Syntax: (boolean=? boolean1 boolean2 ...)
Library: (scheme base)
Description: Returns #t if all the arguments are booleans with the same truth
  value, #f otherwise.
Example:
  (boolean=? #t #t)    => #t
  (boolean=? #f #f)    => #t
  (boolean=? #t #f)    => #f
  (boolean=? #t #t #t) => #t
```

### `boolean?`

```
Syntax: (boolean? obj)
Library: (scheme base)
Description: Returns #t if obj is either #t or #f, otherwise returns #f.
Example:
  (boolean? #f) => #t
  (boolean? 0) => #f
```

### `bytevector`

```
Syntax: (bytevector byte ...)
Library: (scheme base)
Description: Returns a newly allocated bytevector containing the given byte values (each must be 0-255).
Example:
  (bytevector 1 2 3) => #u8(1 2 3)
  (bytevector) => #u8()
```

### `bytevector-append`

```
Syntax: (bytevector-append bv ...)
Library: (scheme base)
Description: Returns a newly allocated bytevector whose elements are the concatenation of the elements of the given bytevectors.
Example:
  (bytevector-append #u8(0 1 2) #u8(3 4 5)) => #u8(0 1 2 3 4 5)
```

### `bytevector-copy`

```
Syntax: (bytevector-copy bv) (bytevector-copy bv start) (bytevector-copy bv start end)
Library: (scheme base)
Description: Returns a newly allocated copy of the elements of bv from start (inclusive) to end (exclusive).
Example:
  (bytevector-copy #u8(1 2 3)) => #u8(1 2 3)
  (bytevector-copy #u8(1 2 3) 1 2) => #u8(2)
```

### `bytevector-copy!`

```
Syntax: (bytevector-copy! to at from) (bytevector-copy! to at from start) (bytevector-copy! to at from start end)
Library: (scheme base)
Description: Copies bytes from bytevector from (from start to end) into bytevector to starting at at. It is an error if this would overwrite to's bounds.
Example:
  (let ((bv (bytevector 1 2 3 4 5)))
    (bytevector-copy! bv 1 #u8(10 11) 0 2)
    bv) => #u8(1 10 11 4 5)
```

### `bytevector-length`

```
Syntax: (bytevector-length bv)
Library: (scheme base)
Description: Returns the number of bytes in the given bytevector.
Example:
  (bytevector-length #u8(1 2 3)) => 3
```

### `bytevector-u8-ref`

```
Syntax: (bytevector-u8-ref bv k)
Library: (scheme base)
Description: Returns the byte at index k of bytevector bv as an exact integer in [0, 255].
Example:
  (bytevector-u8-ref #u8(1 2 3) 0) => 1
  (bytevector-u8-ref #u8(10 20 30) 2) => 30
```

### `bytevector-u8-set!`

```
Syntax: (bytevector-u8-set! bv k byte)
Library: (scheme base)
Description: Stores byte (an exact integer in [0, 255]) into element k of bytevector bv.
Example:
  (let ((bv (bytevector 1 2 3)))
    (bytevector-u8-set! bv 1 42)
    bv) => #u8(1 42 3)
```

### `bytevector?`

```
Syntax: (bytevector? obj)
Library: (scheme base)
Description: Returns #t if obj is a bytevector, otherwise returns #f.
Example:
  (bytevector? #u8(1 2 3)) => #t
  (bytevector? "abc") => #f
```

### `caar`

```
Syntax: (caar pair)
Library: (scheme base)
Description: Returns the car of the car of pair. Equivalent to (car (car pair)).
Example:
  (caar '((a b) c)) => a
```

### `cadr`

```
Syntax: (cadr pair)
Library: (scheme base)
Description: Returns the car of the cdr of pair. Equivalent to (car (cdr pair)).
Example:
  (cadr '(a b c)) => b
```

### `call-with-current-continuation`

*(no documentation)*

### `call-with-port`

```
Syntax: (call-with-port port proc)
Library: (scheme base)
Description: Calls proc with port as an argument. If proc returns, then the
  port is closed automatically and the values yielded by proc are returned.
  If proc does not return, then the port will not be closed automatically,
  unless it is possible to detect that the port will never again be used.
Example:
  (call-with-port (open-input-string "hello")
    (lambda (p) (read-char p))) => #\h
```

### `call-with-values`

```
Syntax: (call-with-values producer consumer)
Library: (scheme base)
Description: Calls producer with no arguments. The producer must return
  zero or more values. The consumer is then called with those values as
  arguments. Returns the result of consumer.
Example:
  (call-with-values (lambda () (values 1 2)) +) => 3
```

### `call/cc`

*(no documentation)*

### `car`

```
Syntax: (car pair)
Library: (scheme base)
Description: Returns the car of pair. It is an error if pair is not a pair.
Example:
  (car '(a b c)) => a
  (car '((a) b)) => (a)
```

### `case`

```
Syntax: (case key ((datum ...) expr ...) ... (else expr ...))
Library: (scheme base)
Description: Evaluates key, then finds the first clause whose datum list
  contains a value eqv? to the key. Evaluates that clause's expressions and
  returns the last. Supports (datum ... => proc) syntax which calls proc with
  the key value. The else clause matches any key not matched by earlier clauses.
Example:
  (case (* 2 3)
    ((2 3 5 7) 'prime)
    ((1 4 6 8 9) 'composite)) => composite
```

### `cdar`

```
Syntax: (cdar pair)
Library: (scheme base)
Description: Returns the cdr of the car of pair. Equivalent to (cdr (car pair)).
Example:
  (cdar '((1 2) 3)) => (2)
```

### `cddr`

```
Syntax: (cddr pair)
Library: (scheme base)
Description: Returns the cdr of the cdr of pair. Equivalent to (cdr (cdr pair)).
Example:
  (cddr '(1 2 3)) => (3)
```

### `cdr`

```
Syntax: (cdr pair)
Library: (scheme base)
Description: Returns the cdr of pair. It is an error if pair is not a pair.
Example:
  (cdr '((a) b c)) => (b c)
  (cdr '(1 . 2)) => 2
```

### `ceiling`

```
Syntax: (ceiling z)
Library: (scheme base)
Description: Returns the smallest integer not smaller than z (rounds toward positive infinity).
Example:
  (ceiling 1.2) => 2.0
  (ceiling -1.2) => -1.0
  (ceiling 3) => 3
```

### `char->integer`

```
Syntax: (char->integer char)
Library: (scheme base)
Description: Returns the Unicode scalar value (codepoint) of the given character as an exact integer.
Example:
  (char->integer #\a) => 97
  (char->integer #\A) => 65
```

### `char-ready?`

```
Syntax: (char-ready?)
       (char-ready? port)
Library: (scheme base)
Description: Returns #t if a character is ready on the input port and returns
  #f if the function would have to wait. If char-ready returns #t then the
  next read-char operation on the given port is guaranteed not to hang. If the
  port is at end of file then char-ready? returns #t. This implementation
  always returns #t.
Example:
  (char-ready?)         => #t
  (char-ready? (current-input-port)) => #t
```

### `char<=?`

```
Syntax: (char<=? char1 char2 char3 ...)
Library: (scheme base)
Description: Returns #t if the character arguments are monotonically non-decreasing.
Example:
  (char<=? #\a #\b) => #t
  (char<=? #\a #\a) => #t
```

### `char<?`

```
Syntax: (char<? char1 char2 char3 ...)
Library: (scheme base)
Description: Returns #t if the character arguments are monotonically increasing.
Example:
  (char<? #\a #\b) => #t
  (char<? #\a #\a) => #f
```

### `char=?`

```
Syntax: (char=? char1 char2 char3 ...)
Library: (scheme base)
Description: Returns #t if all the given characters are the same (case-sensitive comparison).
Example:
  (char=? #\a #\a) => #t
  (char=? #\a #\A) => #f
```

### `char>=?`

```
Syntax: (char>=? char1 char2 char3 ...)
Library: (scheme base)
Description: Returns #t if the character arguments are monotonically non-increasing.
Example:
  (char>=? #\b #\a) => #t
  (char>=? #\a #\a) => #t
```

### `char>?`

```
Syntax: (char>? char1 char2 char3 ...)
Library: (scheme base)
Description: Returns #t if the character arguments are monotonically decreasing.
Example:
  (char>? #\b #\a) => #t
  (char>? #\a #\a) => #f
```

### `char?`

```
Syntax: (char? obj)
Library: (scheme base)
Description: Returns #t if obj is a character, otherwise returns #f.
Example:
  (char? #\a) => #t
  (char? "a") => #f
```

### `close-input-port`

```
Syntax: (close-input-port port)
Library: (scheme base)
Description: Closes the input port, releasing any resources. It is an error to read from a closed port.
Example:
  (let ((p (open-input-file "data.txt")))
    (close-input-port p))
```

### `close-output-port`

```
Syntax: (close-output-port port)
Library: (scheme base)
Description: Closes the output port, flushing any buffered output and releasing resources.
Example:
  (let ((p (open-output-file "out.txt")))
    (close-output-port p))
```

### `close-port`

```
Syntax: (close-port port)
Library: (scheme base)
Description: Closes the resource associated with port, rendering the port
  incapable of delivering or accepting data. If port is an input port,
  close-input-port is called on it; if port is an output port,
  close-output-port is called on it. The return value is unspecified.
Example:
  (let ((p (open-input-string "hello")))
    (close-port p))
```

### `complex?`

```
Syntax: (complex? obj)
Library: (scheme base)
Description: Returns #t if obj is a complex number, #f otherwise.
  In the R7RS numeric tower, all numbers are complex.
Example:
  (complex? 3+4i) => #t
  (complex? 3)    => #t
```

### `cond`

```
Syntax: (cond (test expr ...) ... (else expr ...))
Library: (scheme base)
Description: Evaluates each test in order. When a test is true, evaluates its associated expressions and returns the last. The else clause matches unconditionally. Supports (test => proc) syntax, which calls proc with the test result.
Example:
  (cond ((= 1 2) 'no) ((= 1 1) 'yes) (else 'other)) => yes
  (cond ((assv 2 '((1 a) (2 b))) => cdr) (else #f)) => (b)
```

### `cond-expand`

```
Syntax: (cond-expand (feature-requirement body ...) ...)
Library: (scheme base)
Description: Evaluates the body of the first clause whose feature
  requirement is satisfied. Feature requirements can be feature identifiers,
  (library <name>) tests, or boolean combinations using and, or, and not.
  An optional (else body ...) clause provides a default.
Example:
  (cond-expand
    (r7rs "R7RS")
    (else "unknown")) => "R7RS"
```

### `cons`

```
Syntax: (cons obj1 obj2)
Library: (scheme base)
Description: Returns a newly allocated pair whose car is obj1 and whose cdr is obj2.
Example:
  (cons 'a '()) => (a)
  (cons 'a '(b c)) => (a b c)
  (cons 1 2) => (1 . 2)
```

### `current-error-port`

```
Syntax: (current-error-port)
Library: (scheme base)
Description: Returns the current default error output port. Error messages are written to this port. Initially bound to the standard error.
Example:
  (current-error-port) => #<output-port>
```

### `current-input-port`

```
Syntax: (current-input-port)
Library: (scheme base)
Description: Returns the current default input port. Read operations that do not specify a port use this port. Initially bound to the standard input.
Example:
  (current-input-port) => #<input-port>
```

### `current-output-port`

```
Syntax: (current-output-port)
Library: (scheme base)
Description: Returns the current default output port. Write and display operations that do not specify a port use this port. Initially bound to the standard output.
Example:
  (current-output-port) => #<output-port>
```

### `define`

```
Syntax: (define variable expression) | (define (name formals) body)
Library: (scheme base)
Description: Defines a variable binding. The first form evaluates expression
  and binds the result to variable. The second form is equivalent to
  (define name (lambda (formals) body)) and creates a procedure binding.
Example:
  (define x 42)
  (define (square n) (* n n))
```

### `define-record-type`

```
Syntax: (define-record-type <type> (<constructor> <field-name> ...) <predicate> (<field-name> <accessor> <modifier>) ...)
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
  (point-y p) => 42
```

### `define-syntax`

```
Syntax: (define-syntax keyword transformer)
Library: (scheme base)
Description: Defines a syntax binding, associating keyword with the given
  macro transformer. transformer is typically a syntax-rules or
  syntax-case expression.
Example:
  (define-syntax my-and
    (syntax-rules ()
      ((_) #t)
      ((_ e) e)
      ((_ e1 e2 ...) (if e1 (my-and e2 ...) #f))))
```

### `define-values`

```
Syntax: (define-values formals expression)
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
  c => 3
```

### `denominator`

```
Syntax: (denominator q)
Library: (scheme base)
Description: Returns the denominator of q, where q is a rational number. If q
  is an integer, the denominator is 1. For inexact reals, returns the
  denominator as an inexact number.
Example:
  (denominator (/ 6 4)) => 2
  (denominator 7)       => 1
  (denominator 1.5)     => 2.0
```

### `do`

```
Syntax: (do ((var init step) ...) (test result ...) body ...)
Library: (scheme base)
Description: Iterates by initializing each var to init, then on each iteration evaluating test: if true, evaluates result expressions and returns the last; otherwise evaluates body expressions and steps each var to the value of its step expression.
Example:
  (do ((i 0 (+ i 1)) (s 0 (+ s i)))
      ((= i 5) s)) => 10
```

### `dynamic-wind`

*(no documentation)*

### `eof-object`

*(no documentation)*

### `eof-object?`

```
Syntax: (eof-object? obj)
Library: (scheme base)
Description: Returns #t if obj is an end-of-file object, otherwise returns #f.
Example:
  (eof-object? (read (open-input-string ""))) => #t
```

### `eq?`

```
Syntax: (eq? obj1 obj2)
Library: (scheme base)
Description: Returns #t if obj1 and obj2 are the same object. Equivalent to pointer equality for most types.
Example:
  (eq? 'a 'a) => #t
  (eq? '() '()) => #t
  (eq? (list 1) (list 1)) => #f
```

### `equal?`

```
Syntax: (equal? obj1 obj2)
Library: (scheme base)
Description: Returns #t if obj1 and obj2 have the same structure and contents (deep equality). Recursively compares pairs, vectors, and strings.
Example:
  (equal? '(a b c) '(a b c)) => #t
  (equal? "abc" "abc") => #t
  (equal? '(a b) '(a c)) => #f
```

### `eqv?`

```
Syntax: (eqv? obj1 obj2)
Library: (scheme base)
Description: Returns #t if obj1 and obj2 are operationally equivalent. Numbers are eqv? if they have the same exactness and are numerically equal.
Example:
  (eqv? 'a 'a) => #t
  (eqv? 1 1) => #t
  (eqv? 1 1.0) => #f
```

### `error`

```
Syntax: (error message obj ...)
Library: (scheme base)
Description: Raises an exception as if by calling raise on a newly allocated
  error object which encapsulates the information provided. The message is a
  string describing the error. The objects are arbitrary values which are
  stored in the error object and can be retrieved using error-object-irritants.
  Also accepts SRFI-23 style (error who message irritant ...) where who is a
  symbol.
Example:
  (error "not a number" 42)
  (error 'my-proc "invalid argument" 'foo)
```

### `error-object-irritants`

```
Syntax: (error-object-irritants error-object)
Library: (scheme base)
Description: Returns the list of irritants (extra objects) of the given error object.
Example:
  (guard (e (#t (error-object-irritants e)))
    (error "bad value" 42)) => (42)
```

### `error-object-message`

```
Syntax: (error-object-message error-object)
Library: (scheme base)
Description: Returns the message string of the given error object.
Example:
  (guard (e (#t (error-object-message e)))
    (error "bad value" 42)) => "bad value"
```

### `error-object?`

```
Syntax: (error-object? obj)
Library: (scheme base)
Description: Returns #t if obj is an error object (as raised by error), otherwise returns #f.
Example:
  (guard (e (#t (error-object? e)))
    (error "oops")) => #t
```

### `even?`

```
Syntax: (even? n)
Library: (scheme base)
Description: Returns #t if n is an even integer, #f otherwise.
Example:
  (even? 4) => #t
  (even? 3) => #f
```

### `exact`

```
Syntax: (exact z)
Library: (scheme base)
Description: Returns the exact number that is numerically equal to z.
  For inexact integers, returns the integer. For non-integral inexact
  numbers, returns the simplest exact rational whose inexact value
  equals z (using continued fraction approximation).
Example:
  (exact 1.5) => 3/2
  (exact 0.3) => 3/10
  (exact 3.0) => 3
  (exact 3) => 3
```

### `exact-integer-sqrt`

```
Syntax: (exact-integer-sqrt k)
Library: (scheme base)
Description: Returns two non-negative exact integer values s and r such that
  k = s^2 + r and k < (s+1)^2. In other words, s is the largest integer such
  that s^2 is not greater than k, and r is the remainder.
Example:
  (exact-integer-sqrt 4) => 2 0
  (exact-integer-sqrt 5) => 2 1
  (exact-integer-sqrt 14) => 3 5
```

### `exact-integer?`

```
Syntax: (exact-integer? z)
Library: (scheme base)
Description: Returns #t if z is both exact and an integer, #f otherwise.
Example:
  (exact-integer? 1)   => #t
  (exact-integer? 1.0) => #f
  (exact-integer? 1/2) => #f
```

### `exact?`

```
Syntax: (exact? z)
Library: (scheme base)
Description: Returns #t if z is an exact number (integer or rational), otherwise returns #f.
Example:
  (exact? 1) => #t
  (exact? 1.0) => #f
  (exact? 1/3) => #t
```

### `expt`

```
Syntax: (expt z1 z2)
Library: (scheme base)
Description: Returns z1 raised to the power z2. If z2 is exact 0, returns exact 1.
Example:
  (expt 2 10) => 1024
  (expt 4 0) => 1
  (expt 2.0 3) => 8.0
```

### `features`

```
Syntax: (%features-list)
Library: (scheme base)
Description: Internal primitive that returns the list of feature symbols for this implementation (used by (features)). Includes r7rs, scm, platform, and architecture identifiers.
Example:
  (%features-list) => (r7rs scm exact-closed ieee-float gnu-linux x86-64 little-endian)
```

### `file-error?`

```
Syntax: (file-error? obj)
Library: (scheme file)
Description: Returns #t if obj is a file error object (as raised by file operations), otherwise returns #f.
Example:
  (guard (e (#t (file-error? e)))
    (open-input-file "nonexistent")) => #t
```

### `floor`

```
Syntax: (floor z)
Library: (scheme base)
Description: Returns the largest integer not larger than z (rounds toward negative infinity).
Example:
  (floor 1.8) => 1.0
  (floor -1.2) => -2.0
  (floor 3) => 3
```

### `floor-quotient`

```
Syntax: (floor-quotient n1 n2)
Library: (scheme base)
Description: Returns the floor quotient of n1 divided by n2. The floor
  quotient is the largest integer not larger than the real-valued quotient
  n1/n2. It satisfies n1 = q*n2 + r where q is the floor quotient.
Example:
  (floor-quotient 5 2)   => 2
  (floor-quotient -5 2)  => -3
  (floor-quotient 5 -2)  => -3
```

### `floor-remainder`

```
Syntax: (floor-remainder n1 n2)
Library: (scheme base)
Description: Returns the floor remainder of n1 divided by n2. The floor
  remainder r satisfies n1 = (floor-quotient n1 n2)*n2 + r. The result has
  the same sign as n2.
Example:
  (floor-remainder 5 2)   => 1
  (floor-remainder -5 2)  => 1
  (floor-remainder 5 -2)  => -1
```

### `floor/`

```
Syntax: (floor/ n1 n2)
Library: (scheme base)
Description: Returns two values: the floor quotient and the floor remainder
  of n1 divided by n2. Equivalent to calling floor-quotient and
  floor-remainder separately, but potentially more efficient.
Example:
  (floor/ 5 2)  => 2 1
  (floor/ -5 2) => -3 1
```

### `flush-output-port`

```
Syntax: (flush-output-port) (flush-output-port port)
Library: (scheme base)
Description: Flushes any buffered output in the given output port (or current output port if omitted).
Example:
  (flush-output-port)
```

### `for-each`

```
Syntax: (for-each proc list1 list2 ...)
Library: (scheme base)
Description: The arguments to for-each are like the arguments to map, but
  for-each calls proc for its side effects rather than for its values. Unlike
  map, for-each is guaranteed to call proc on the elements of the lists in
  order from the first element(s) to the last. The return values of for-each
  are unspecified.
Example:
  (for-each display '(a b c))    ; displays abc
  (for-each + '(1 2 3) '(4 5 6)) ; calls +, side effects only
```

### `gcd`

```
Syntax: (gcd n1 ...)
Library: (scheme base)
Description: Returns the greatest common divisor of its arguments. The result
  is always non-negative. With no arguments, returns 0.
Example:
  (gcd 32 -36) => 4
  (gcd)        => 0
  (gcd 32 -36 12) => 4
```

### `get-output-bytevector`

```
Syntax: (get-output-bytevector port)
Library: (scheme base)
Description: Returns a bytevector consisting of the bytes that have been output to the given bytevector output port (created with open-output-bytevector).
Example:
  (let ((p (open-output-bytevector)))
    (write-u8 65 p)
    (get-output-bytevector p)) => #u8(65)
```

### `get-output-string`

```
Syntax: (get-output-string port)
Library: (scheme base)
Description: Returns a string consisting of the characters that have been output to the given string output port (created with open-output-string).
Example:
  (let ((p (open-output-string)))
    (write-char #\A p)
    (get-output-string p)) => "A"
```

### `guard`

```
Syntax: (guard (var clause ...) body ...)
Library: (scheme base)
Description: Evaluates body in a context where, if an exception is raised,
  var is bound to the condition object and the clauses are evaluated as in a
  cond expression. If a clause matches, its body is evaluated and the result
  is returned. If no clause matches, the exception is re-raised. If an else
  clause is present, it is used when no other clause matches. Clauses may use
  => syntax.
Example:
  (guard (e ((string? (error-object-message e)) (error-object-message e)))
    (error "oops")) => "oops"
  (guard (e (#t 'caught))
    (error "anything")) => caught
```

### `guard-aux`

```
Syntax: (guard-aux reraise clause ...)
Library: (scheme base)
Description: Internal helper macro used by guard to process the cond-like
  clauses. reraise is the expression to evaluate if no clause matches.
  Clauses have the same form as in cond, including => and else support.
  Not intended for direct use.
```

### `if`

```
Syntax: (if test consequent) | (if test consequent alternate)
Library: (scheme base)
Description: Evaluates test. If the result is a true value, consequent is
  evaluated and its value is returned. Otherwise, alternate is evaluated and
  its value is returned. If test yields #f and no alternate is specified,
  the result is unspecified.
Example:
  (if (> 3 2) 'yes 'no) => yes
  (if (> 2 3) 'yes 'no) => no
```

### `include`

```
Syntax: (include filename ...)
Library: (scheme base)
Description: Loads and evaluates one or more Scheme source files in the current module's environment.
Example:
  (include "helpers.scm" "utils.scm")
```

### `include-ci`

```
Syntax: (include-ci filename ...)
Library: (scheme base)
Description: Like include, but reads the files in case-insensitive mode (all identifiers are folded to lowercase).
Example:
  (include-ci "legacy.scm")
```

### `inexact`

```
Syntax: (inexact z)
Library: (scheme base)
Description: Returns the inexact (floating-point) number that is numerically closest to z.
Example:
  (inexact 1) => 1.0
  (inexact 1/3) => 0.3333333333333333
```

### `inexact?`

```
Syntax: (inexact? z)
Library: (scheme base)
Description: Returns #t if z is inexact (i.e., not exact), #f otherwise.
Example:
  (inexact? 1.0) => #t
  (inexact? 1)   => #f
```

### `input-port-open?`

```
Syntax: (input-port-open? port)
Library: (scheme base)
Description: Returns #t if the input port is still open, otherwise returns #f.
Example:
  (let ((p (open-input-string "abc")))
    (close-input-port p)
    (input-port-open? p)) => #f
```

### `input-port?`

```
Syntax: (input-port? obj)
Library: (scheme base)
Description: Returns #t if obj is an input port, otherwise returns #f.
Example:
  (input-port? (open-input-string "abc")) => #t
  (input-port? (open-output-string)) => #f
```

### `integer->char`

```
Syntax: (integer->char n)
Library: (scheme base)
Description: Returns the character corresponding to the given Unicode scalar value (codepoint).
Example:
  (integer->char 97) => #\a
  (integer->char 65) => #\A
```

### `integer?`

```
Syntax: (integer? obj)
Library: (scheme base)
Description: Returns #t if obj is an integer (exact or inexact with an integer value), otherwise returns #f.
Example:
  (integer? 1) => #t
  (integer? 1.0) => #t
  (integer? 1.5) => #f
```

### `lambda`

```
Syntax: (lambda formals body)
Library: (scheme base)
Description: Creates a procedure. formals is a list of parameters, a single
  symbol for a rest parameter, or a dotted pair for required plus rest
  parameters. When the procedure is called, the arguments are bound to the
  parameters and the body is evaluated. The value of the last expression in
  the body is returned.
Example:
  ((lambda (x y) (+ x y)) 3 4) => 7
  ((lambda xs xs) 1 2 3) => (1 2 3)
```

### `lcm`

```
Syntax: (lcm n1 ...)
Library: (scheme base)
Description: Returns the least common multiple of its arguments. The result
  is always non-negative. With no arguments, returns 1.
Example:
  (lcm 32 -36) => 288
  (lcm)        => 1
  (lcm 32 -36 12) => 288
```

### `length`

```
Syntax: (length list)
Library: (scheme base)
Description: Returns the number of elements in the proper list. It is an error if the list is not a proper list.
Example:
  (length '(a b c)) => 3
  (length '()) => 0
```

### `let`

```
Syntax: (let ((variable init) ...) body) | (let name ((variable init) ...) body)
Library: (scheme base)
Description: Binds each variable to the value of the corresponding init
  expression and evaluates body in the extended environment. The init
  expressions are evaluated in the current environment (not the extended
  one). Named let binds the variables and also binds name to a procedure
  that, when called, rebinds the variables and re-evaluates the body.
Example:
  (let ((x 1) (y 2)) (+ x y)) => 3
  (let loop ((n 5) (acc 1)) (if (= n 0) acc (loop (- n 1) (* acc n)))) => 120
```

### `let*`

```
Syntax: (let* ((variable init) ...) body)
Library: (scheme base)
Description: Like let, but the bindings are performed sequentially from
  left to right, and each init expression is evaluated in an environment in
  which the previous bindings are visible.
Example:
  (let* ((x 1) (y (+ x 1))) (+ x y)) => 3
```

### `let*-values`

```
Syntax: (let*-values (((var ...) expr) ...) body ...)
Library: (scheme base)
Description: Semantics like let-values, but the bindings are performed
  sequentially from left to right, and the init expressions are evaluated
  in the environment in which the preceding bindings are visible. Thus
  each binding has access to all preceding bindings.
Example:
  (let*-values (((a b) (values 1 2))
                ((c)   (values (+ a b))))
    c) => 3
```

### `let-syntax`

```
Syntax: (let-syntax ((keyword transformer) ...) body)
Library: (scheme base)
Description: Binds each keyword to the corresponding macro transformer
  and evaluates body in the extended syntactic environment. The bindings
  are not visible in the transformer expressions.
Example:
  (let-syntax ((swap! (syntax-rules ()
                        ((_ a b) (let ((t a)) (set! a b) (set! b t))))))
    (let ((x 1) (y 2)) (swap! x y) (list x y))) => (2 1)
```

### `let-values`

```
Syntax: (let-values (((var ...) expr) ...) body ...)
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
    (list a b c)) => (1 2 3)
```

### `letrec`

```
Syntax: (letrec ((variable init) ...) body)
Library: (scheme base)
Description: Binds each variable and evaluates the init expressions in an
  environment where all variables are bound. The order of evaluation of the
  init expressions is unspecified. Useful for defining mutually recursive
  procedures.
Example:
  (letrec ((even? (lambda (n) (if (= n 0) #t (odd? (- n 1)))))
           (odd? (lambda (n) (if (= n 0) #f (even? (- n 1))))))
    (even? 10)) => #t
```

### `letrec*`

```
Syntax: (letrec* ((variable init) ...) body)
Library: (scheme base)
Description: Like letrec, but the init expressions are evaluated
  sequentially from left to right. Each init is evaluated in an environment
  where all variables are bound, but only the preceding init values are
  guaranteed to be available.
Example:
  (letrec* ((x 1) (y (+ x 1))) (+ x y)) => 3
```

### `letrec-syntax`

```
Syntax: (letrec-syntax ((keyword transformer) ...) body)
Library: (scheme base)
Description: Like let-syntax, but the bindings are visible in the
  transformer expressions, allowing mutually recursive macro definitions.
Example:
  (letrec-syntax ((my-or (syntax-rules ()
                           ((_) #f)
                           ((_ e) e)
                           ((_ e1 e2 ...) (let ((t e1)) (if t t (my-or e2 ...)))))))
    (my-or #f #f 42)) => 42
```

### `list`

*(no documentation)*

### `list->string`

```
Syntax: (list->string list)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated string formed from the characters in
  list. It is an error if any element of list is not a character.
Example:
  (list->string '(#\a #\b #\c)) => "abc"
  (list->string '())              => ""
```

### `list->vector`

```
Syntax: (list->vector list)
Library: (scheme base)
Description: Returns a newly created vector initialized to the elements of
  the argument list.
Example:
  (list->vector '(a b c)) => #(a b c)
  (list->vector '())      => #()
```

### `list-copy`

```
Syntax: (list-copy obj)
Library: (scheme base)
Description: Returns a newly allocated copy of the given list. Only the pairs
  themselves are copied; the cars of the result are the same (in the sense of
  eqv?) as the cars of list. If the last cdr of the list is not the empty
  list, the result is an improper list with the same final cdr as the
  argument.
Example:
  (list-copy '(a b c)) => (a b c)
  (list-copy '())      => ()
  (list-copy '(a b . c)) => (a b . c)
```

### `list-ref`

```
Syntax: (list-ref list k)
Library: (scheme base)
Description: Returns the k-th element (zero-indexed) of list. It is an error if k is out of range.
Example:
  (list-ref '(a b c) 0) => a
  (list-ref '(a b c) 2) => c
```

### `list-set!`

```
Syntax: (list-set! list k obj)
Library: (scheme base)
Description: Stores obj in element k of list. It is an error if k is not a
  valid index of list. The result is unspecified.
Example:
  (let ((ls (list 'a 'b 'c)))
    (list-set! ls 1 'x)
    ls) => (a x c)
```

### `list-tail`

```
Syntax: (list-tail list k)
Library: (scheme base)
Description: Returns the sublist of list obtained by omitting the first k elements. It is an error if list has fewer than k elements.
Example:
  (list-tail '(a b c d) 2) => (c d)
  (list-tail '(a b c) 0) => (a b c)
```

### `list?`

```
Syntax: (list? obj)
Library: (scheme base)
Description: Returns #t if obj is a proper list (a sequence of pairs terminated by the empty list), otherwise returns #f. Also detects circular lists.
Example:
  (list? '(a b c)) => #t
  (list? '(a . b)) => #f
  (list? '()) => #t
```

### `make-bytevector`

```
Syntax: (make-bytevector k) (make-bytevector k fill)
Library: (scheme base)
Description: Returns a newly allocated bytevector of k bytes. If fill is given, each byte is initialized to fill (0-255); otherwise each byte is 0.
Example:
  (make-bytevector 3) => #u8(0 0 0)
  (make-bytevector 3 5) => #u8(5 5 5)
```

### `make-list`

```
Syntax: (make-list k)
       (make-list k fill)
Library: (scheme base)
Description: Returns a newly allocated list of k elements. If a second
  argument is given, then each element is initialized to fill. Otherwise
  the initial contents of each element is unspecified (defaults to #f).
Example:
  (make-list 3)      => (#f #f #f)
  (make-list 3 'x)   => (x x x)
  (make-list 0)      => ()
```

### `make-parameter`

```
Syntax: (make-parameter init)
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
  (q)      => 20
```

### `make-string`

```
Syntax: (make-string k) (make-string k char)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated mutable string of k characters. If char is given, all characters are initialized to char; otherwise they are spaces.
Example:
  (make-string 3 #\x) => "xxx"
  (make-string 3) => "   "
```

### `make-vector`

```
Syntax: (make-vector k) (make-vector k fill)
Library: (scheme base)
Description: Returns a newly allocated vector of k elements. If fill is given, every element is initialized to fill; otherwise each element is 0.
Example:
  (make-vector 3 0) => #(0 0 0)
  (make-vector 3 'a) => #(a a a)
```

### `map`

```
Syntax: (map proc list1 list2 ...)
Library: (scheme base)
Description: The lists must be lists, and proc must be a procedure taking as
  many arguments as there are lists and returning a single value. If more than
  one list is given and not all lists have the same length, map terminates when
  the shortest list runs out. Map applies proc element-wise to the elements of
  the lists and returns a list of the results, in order.
Example:
  (map cadr '((a b) (d e) (g h))) => (b e h)
  (map + '(1 2 3) '(4 5 6))      => (5 7 9)
```

### `max`

```
Syntax: (max x ...)
Library: (scheme base)
Description: Returns the largest of the given real numbers. Requires at least one argument.
Example:
  (max 3 1 4 1 5) => 5
  (max -1 -2 -3) => -1
```

### `member`

```
Syntax: (member obj list)
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
  (member 2.0 '(1 2 3) =) => (2 3)
```

### `memq`

```
Syntax: (memq obj list)
Library: (scheme base)
Description: Returns the first sublist of list whose car is eq? to obj, or #f if no such sublist exists.
Example:
  (memq 'b '(a b c)) => (b c)
  (memq 'z '(a b c)) => #f
```

### `memv`

```
Syntax: (memv obj list)
Library: (scheme base)
Description: Returns the first sublist of list whose car is eqv? to obj, or #f if no such sublist exists.
Example:
  (memv 2 '(1 2 3)) => (2 3)
  (memv 5 '(1 2 3)) => #f
```

### `min`

```
Syntax: (min x ...)
Library: (scheme base)
Description: Returns the smallest of the given real numbers. Requires at least one argument.
Example:
  (min 3 1 4 1 5) => 1
  (min 0.5 1/2) => 0.5
```

### `modulo`

```
Syntax: (modulo n1 n2)
Library: (scheme base)
Description: Returns the integer modulus of n1 divided by n2. The result has the same sign as n2.
Example:
  (modulo 13 4) => 1
  (modulo -13 4) => 3
  (modulo 13 -4) => -3
```

### `negative?`

```
Syntax: (negative? x)
Library: (scheme base)
Description: Returns #t if x is negative, #f otherwise.
Example:
  (negative? -1) => #t
  (negative? 1)  => #f
  (negative? 0)  => #f
```

### `newline`

```
Syntax: (newline) (newline port)
Library: (scheme write)
Description: Writes a newline character to the current output port or to the given port.
Example:
  (newline)
  (newline (open-output-string))
```

### `not`

```
Syntax: (not obj)
Library: (scheme base)
Description: Returns #t if obj is #f, otherwise returns #f.
Example:
  (not #f) => #t
  (not #t) => #f
  (not 42) => #f
```

### `null?`

```
Syntax: (null? obj)
Library: (scheme base)
Description: Returns #t if obj is the empty list '(), otherwise returns #f.
Example:
  (null? '()) => #t
  (null? '(1 2)) => #f
```

### `number->string`

```
Syntax: (number->string z) (number->string z radix)
Library: (scheme base)
Description: Returns a string representation of z in the given radix (default 10). Exact integers support any radix.
Example:
  (number->string 42) => "42"
  (number->string 255 16) => "ff"
  (number->string 3.14) => "3.14"
```

### `number?`

```
Syntax: (number? obj)
Library: (scheme base)
Description: Returns #t if obj is a number (exact integer, rational, or inexact real), otherwise returns #f.
Example:
  (number? 3) => #t
  (number? 3.5) => #t
  (number? "3") => #f
```

### `numerator`

```
Syntax: (numerator q)
Library: (scheme base)
Description: Returns the numerator of q, where q is a rational number. If q
  is an integer, the numerator is q itself. For inexact reals, returns the
  numerator as an inexact number.
Example:
  (numerator (/ 6 4)) => 3
  (numerator 7)       => 7
  (numerator 1.5)     => 3.0
```

### `odd?`

```
Syntax: (odd? n)
Library: (scheme base)
Description: Returns #t if n is an odd integer, #f otherwise.
Example:
  (odd? 3) => #t
  (odd? 4) => #f
```

### `open-input-bytevector`

```
Syntax: (open-input-bytevector bv)
Library: (scheme base)
Description: Returns a binary input port that reads bytes from the bytevector bv.
Example:
  (let ((p (open-input-bytevector #u8(1 2 3))))
    (read-u8 p)) => 1
```

### `open-input-string`

```
Syntax: (open-input-string string)
Library: (scheme base)
Description: Takes a string and returns a textual input port that delivers characters from the string.
Example:
  (define p (open-input-string "hello"))
  (read-char p) => #\h
```

### `open-output-bytevector`

```
Syntax: (open-output-bytevector)
Library: (scheme base)
Description: Returns a binary output port that accumulates bytes in memory. Use get-output-bytevector to retrieve the accumulated bytes.
Example:
  (let ((p (open-output-bytevector)))
    (write-u8 65 p)
    (get-output-bytevector p)) => #u8(65)
```

### `open-output-string`

```
Syntax: (open-output-string)
Library: (scheme base)
Description: Returns a textual output port that accumulates characters written to it. Use get-output-string to retrieve the accumulated string.
Example:
  (let ((p (open-output-string)))
    (write-char #\h p)
    (get-output-string p)) => "h"
```

### `or`

```
Syntax: (or expr ...)
Library: (scheme base)
Description: Evaluates expressions left to right. Returns the value of the first expression that is not #f, or #f if all expressions are #f. With no arguments, returns #f.
Example:
  (or #f #f 3) => 3
  (or #f #f #f) => #f
  (or) => #f
```

### `output-port-open?`

```
Syntax: (output-port-open? port)
Library: (scheme base)
Description: Returns #t if port is still open, otherwise returns #f.
Example:
  (define p (open-output-string))
  (output-port-open? p) => #t
  (close-output-port p)
  (output-port-open? p) => #f
```

### `output-port?`

```
Syntax: (output-port? obj)
Library: (scheme base)
Description: Returns #t if obj is an output port, otherwise returns #f.
Example:
  (output-port? (open-output-string)) => #t
  (output-port? (current-output-port)) => #t
  (output-port? 42) => #f
```

### `pair?`

```
Syntax: (pair? obj)
Library: (scheme base)
Description: Returns #t if obj is a pair, otherwise returns #f.
Example:
  (pair? '(a b c)) => #t
  (pair? '()) => #f
  (pair? '(a . b)) => #t
  (pair? 7) => #f
```

### `parameterize`

```
Syntax: (parameterize ((param val) ...) body ...)
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
  (p) => 1
```

### `peek-char`

```
Syntax: (peek-char)
Library: (scheme base)
Description: Returns the next character available from the input port without updating the port to point past the character. If no more characters are available, an end-of-file object is returned. If port is omitted, the current input port is used.
Example:
  (define p (open-input-string "ab"))
  (peek-char p) => #\a
  (read-char p) => #\a
```

### `peek-u8`

```
Syntax: (peek-u8 port)
Library: (scheme base)
Description: Returns the next byte available from the binary input port without consuming it. Returns an end-of-file object if no bytes are available.
Example:
  (let ((p (open-input-bytevector #u8(10 20))))
    (peek-u8 p)) => 10
```

### `port?`

```
Syntax: (port? obj)
Library: (scheme base)
Description: Returns #t if obj is a port (either an input port or an output
  port), #f otherwise.
Example:
  (port? (current-input-port))  => #t
  (port? (current-output-port)) => #t
  (port? 42)                    => #f
```

### `positive?`

```
Syntax: (positive? x)
Library: (scheme base)
Description: Returns #t if x is positive, #f otherwise.
Example:
  (positive? 1)  => #t
  (positive? -1) => #f
  (positive? 0)  => #f
```

### `procedure?`

```
Syntax: (procedure? obj)
Library: (scheme base)
Description: Returns #t if obj is a procedure, #f otherwise. A procedure is
  either a lambda (user-defined closure) or a primitive (built-in procedure).
Example:
  (procedure? car)       => #t
  (procedure? (lambda (x) x)) => #t
  (procedure? 42)        => #f
```

### `quasiquote`

```
Syntax: (quasiquote template) | `template
Library: (scheme base)
Description: Returns template with unquoted expressions evaluated. Use
  ,expr to insert a value and ,@expr to splice a list. The reader
  abbreviation `template is equivalent to (quasiquote template).
Example:
  (let ((x 1)) `(a ,x c)) => (a 1 c)
  (let ((xs '(1 2))) `(a ,@xs c)) => (a 1 2 c)
```

### `quote`

```
Syntax: (quote datum) | 'datum
Library: (scheme base)
Description: Returns datum without evaluating it. The reader abbreviation
  'datum is equivalent to (quote datum).
Example:
  (quote (1 2 3)) => (1 2 3)
  'hello => hello
```

### `quotient`

```
Syntax: (quotient n1 n2)
Library: (scheme base)
Description: Returns the integer quotient of n1 divided by n2, truncated toward zero.
Example:
  (quotient 13 4) => 3
```

### `raise`

```
Syntax: (raise obj)
Library: (scheme base)
Description: Raises an exception by invoking the current exception handler on obj.
Example:
  (guard (e (#t (error-object-message e)))
    (raise (make-error-object "oops" '()))) => "oops"
```

### `raise-continuable`

```
Syntax: (raise-continuable obj)
Library: (scheme base)
Description: Like raise, but if the handler returns, its value becomes the return value.
Example:
  (with-exception-handler (lambda (e) 42) (lambda () (+ 1 (raise-continuable 'oops)))) => 43
```

### `rational?`

```
Syntax: (rational? obj)
Library: (scheme base)
Description: Returns #t if obj is a rational number. All finite real numbers
  (including inexact reals like 1.0 and 1.5) are rational. +inf.0, -inf.0,
  and +nan.0 are not rational.
Example:
  (rational? 1)      => #t
  (rational? 1/2)    => #t
  (rational? 1.0)    => #t
  (rational? +inf.0) => #f
  (rational? +nan.0) => #f
```

### `rationalize`

```
Syntax: (rationalize x y)
Library: (scheme base)
Description: Returns the simplest rational number within y of x. The simplest
  rational is the one with the smallest denominator. If x is exact, returns an
  exact result; if inexact, returns an inexact result.
Example:
  (rationalize (exact .3) 1/10) => 1/3
  (rationalize .3 1/10) => 0.3333333333333333
```

### `read-bytevector`

```
Syntax: (read-bytevector k port)
Library: (scheme base)
Description: Reads up to k bytes from the binary input port and returns them as a freshly allocated bytevector. Returns an end-of-file object if no bytes are available.
Example:
  (let ((p (open-input-bytevector #u8(1 2 3))))
    (read-bytevector 2 p)) => #u8(1 2)
```

### `read-bytevector!`

```
Syntax: (read-bytevector! bv port)
Library: (scheme base)
Description: Reads bytes from the binary input port into the bytevector bv, starting at start (default 0) and ending before end (default length of bv). Returns the number of bytes read, or an end-of-file object if no bytes were available.
Example:
  (let ((bv (make-bytevector 3 0))
        (p (open-input-bytevector #u8(1 2 3))))
    (read-bytevector! bv p)
    bv) => #u8(1 2 3)
```

### `read-char`

```
Syntax: (read-char)
Library: (scheme base)
Description: Returns the next character available from the input port, updating the port to point past the character. If no more characters are available, an end-of-file object is returned. If port is omitted, the current input port is used.
Example:
  (define p (open-input-string "ab"))
  (read-char p) => #\a
  (read-char p) => #\b
```

### `read-error?`

```
Syntax: (read-error? obj)
Library: (scheme read)
Description: Returns #t if obj is an object representing an error that occurred while reading, otherwise returns #f.
Example:
  (read-error? (guard (e (#t e)) (read (open-input-string "(")))) => #t
```

### `read-line`

```
Syntax: (read-line)
Library: (scheme base)
Description: Returns the next line of text available from the input port as a string, discarding the newline. If end of file is reached before any characters are read, an end-of-file object is returned. If port is omitted, the current input port is used.
Example:
  (define p (open-input-string "hello\nworld"))
  (read-line p) => "hello"
  (read-line p) => "world"
```

### `read-string`

```
Syntax: (read-string k)
       (read-string k port)
Library: (scheme base)
Description: Reads the next k characters, or as many as are available before
  the end of file, from the textual input port into a newly allocated string
  in left-to-right order and returns the string. If no characters are
  available before the end of file, an end-of-file object is returned. port
  defaults to the current input port.
Example:
  (read-string 3 (open-input-string "hello")) => "hel"
```

### `read-u8`

```
Syntax: (read-u8 port)
Library: (scheme base)
Description: Returns the next byte available from the binary input port as an exact integer in the range 0 to 255. Returns an end-of-file object if no bytes are available.
Example:
  (let ((p (open-input-bytevector #u8(65 66))))
    (read-u8 p)) => 65
```

### `real?`

```
Syntax: (real? obj)
Library: (scheme base)
Description: Returns #t if obj is a real number, otherwise returns #f. Integers and rationals are also real numbers.
Example:
  (real? 3) => #t
  (real? 3.5) => #t
  (real? 1/3) => #t
  (real? "hello") => #f
```

### `remainder`

```
Syntax: (remainder n1 n2)
Library: (scheme base)
Description: Returns the remainder of dividing n1 by n2. The result has the same sign as n1. It is an error if n2 is zero.
Example:
  (remainder 13 4) => 1
  (remainder -13 4) => -1
  (remainder 13 -4) => 1
```

### `reverse`

```
Syntax: (reverse list)
Library: (scheme base)
Description: Returns a newly allocated list containing the elements of list in reverse order.
Example:
  (reverse '(1 2 3)) => (3 2 1)
  (reverse '()) => ()
```

### `round`

```
Syntax: (round z)
Library: (scheme base)
Description: Returns the integer closest to z. If z is halfway between two integers, rounds to the even one (banker's rounding).
Example:
  (round 3.5) => 4.0
  (round 2.5) => 2.0
  (round 7/2) => 4
```

### `set!`

```
Syntax: (set! variable expression)
Library: (scheme base)
Description: Evaluates expression and stores the result in the location to
  which variable is bound. variable must be bound either in some enclosing
  scope or at the top level. The result of the set! expression is
  unspecified.
Example:
  (let ((x 1)) (set! x 2) x) => 2
```

### `set-car!`

```
Syntax: (set-car! pair obj)
Library: (scheme base)
Description: Stores obj in the car field of pair. It is an error if pair is not a pair.
Example:
  (define p (list 1 2 3))
  (set-car! p 'a)
  p => (a 2 3)
```

### `set-cdr!`

```
Syntax: (set-cdr! pair obj)
Library: (scheme base)
Description: Stores obj in the cdr field of pair. It is an error if pair is not a pair.
Example:
  (define p (list 1 2 3))
  (set-cdr! p '(b c))
  p => (1 b c)
```

### `square`

```
Syntax: (square z)
Library: (scheme base)
Description: Returns the square of z. This is equivalent to (* z z).
Example:
  (square 5)   => 25
  (square -3)  => 9
  (square 2.0) => 4.0
```

### `string`

```
Syntax: (string char ...)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated string composed of the given characters.
Example:
  (string #\a #\b #\c) => "abc"
  (string) => ""
```

### `string->list`

```
Syntax: (string->list string)
       (string->list string start)
       (string->list string start end)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated list of the characters of string
  between start and end. start defaults to 0 and end defaults to the length
  of string.
Example:
  (string->list "abc")     => (#\a #\b #\c)
  (string->list "abc" 1)   => (#\b #\c)
  (string->list "abc" 1 2) => (#\b)
```

### `string->number`

```
Syntax: (string->number s radix?)
Library: (scheme base)
Description: Converts the string s to a number using the given radix (default 10). Returns #f if s cannot be parsed as a number.
Example:
  (string->number "42") => 42
  (string->number "ff" 16) => 255
  (string->number "abc") => #f
```

### `string->symbol`

```
Syntax: (string->symbol s)
Library: (scheme base)
Description: Returns the interned symbol whose name is the string s. Two calls with equal strings return the same symbol.
Example:
  (string->symbol "hello") => hello
  (eq? (string->symbol "foo") (string->symbol "foo")) => #t
```

### `string->utf8`

```
Syntax: (string->utf8 s start? end?)
Library: (scheme base)
Description: Returns a bytevector containing the UTF-8 encoding of the string s. Optional start and end indices can be used to encode a substring.
Example:
  (string->utf8 "abc") => #u8(97 98 99)
  (string->utf8 "hello" 1 3) => #u8(101 108)
```

### `string->vector`

```
Syntax: (string->vector string)
       (string->vector string start)
       (string->vector string start end)
Library: (scheme base)
Description: Returns a newly created vector initialized to the elements of
  the string between start and end. start defaults to 0 and end defaults to
  the length of the string.
Example:
  (string->vector "abc")     => #(#\a #\b #\c)
  (string->vector "abc" 1)   => #(#\b #\c)
  (string->vector "abc" 1 2) => #(#\b)
```

### `string-append`

```
Syntax: (string-append string ...)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated string whose characters are the concatenation of the characters in the given strings.
Example:
  (string-append "foo" "bar") => "foobar"
  (string-append "a" "b" "c") => "abc"
```

### `string-copy`

```
Syntax: (string-copy string)
       (string-copy string start)
       (string-copy string start end)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated copy of the part of the given string
  between start and end. start defaults to 0 and end defaults to the length
  of the string.
Example:
  (string-copy "abc")     => "abc"
  (string-copy "abc" 1)   => "bc"
  (string-copy "abc" 1 2) => "b"
```

### `string-copy!`

```
Syntax: (string-copy! to at from)
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
  (let ((s (string-copy "hello")))
    (string-copy! s 1 "xyz" 0 2)
    s) => "hxylo"
```

### `string-fill!`

```
Syntax: (string-fill! string char)
       (string-fill! string char start)
       (string-fill! string char start end)
Library: (scheme base) (srfi 13)
Description: Stores char in every element of the given string between start
  and end. start defaults to 0 and end defaults to the length of the string.
Example:
  (let ((s (make-string 3 #\a)))
    (string-fill! s #\x)
    s) => "xxx"
  (let ((s (string-copy "hello")))
    (string-fill! s #\x 1 3)
    s) => "hxxlo"
```

### `string-for-each`

```
Syntax: (string-for-each proc string1 string2 ...)
       (string-for-each proc string [start [end]])
Library: (scheme base) (srfi 13)
Description: When given multiple strings, applies proc element-wise to the
  characters of the strings in order for side effects (R7RS).
  When given optional integer start/end indices, applies proc to each
  character of string[start..end) in order (SRFI-13).
Example:
  (string-for-each display "abc") ; displays abc
```

### `string-length`

```
Syntax: (string-length s)
Library: (scheme base) (srfi 13)
Description: Returns the number of characters in the string s.
Example:
  (string-length "hello") => 5
  (string-length "") => 0
```

### `string-map`

```
Syntax: (string-map proc string1 string2 ...)
       (string-map proc string [start [end]])
Library: (scheme base) (srfi 13)
Description: When given multiple strings, applies proc element-wise to the
  characters of the strings and returns a string of the results. If multiple
  strings are given, they must all have the same length (R7RS).
  When given optional integer start/end indices, maps proc over the characters
  of string[start..end) and returns a new string (SRFI-13).
Example:
  (string-map char-upcase "hello")       => "HELLO"
  (string-map char-upcase "hello" 1 3)   => "EL"
  (string-map (lambda (c) c) "xyz")      => "xyz"
```

### `string-ref`

```
Syntax: (string-ref s k)
Library: (scheme base) (srfi 13)
Description: Returns the character at index k in the string s. It is an error if k is out of range.
Example:
  (string-ref "hello" 0) => #\h
  (string-ref "hello" 4) => #\o
```

### `string-set!`

```
Syntax: (string-set! s k char)
Library: (scheme base) (srfi 13)
Description: Stores char in position k of the string s, mutating the string in place. It is an error if k is out of range.
Example:
  (let ((s (string-copy "hello")))
    (string-set! s 0 #\H)
    s) => "Hello"
```

### `string<=?`

```
Syntax: (string<=? s1 s2 ...)
Library: (scheme base)
Description: Returns #t if the strings are monotonically non-increasing in lexicographic order, otherwise returns #f.
Example:
  (string<=? "a" "b") => #t
  (string<=? "abc" "abc") => #t
  (string<=? "b" "a") => #f
```

### `string<?`

```
Syntax: (string<? s1 s2 ...)
Library: (scheme base)
Description: Returns #t if the strings are monotonically increasing in lexicographic order, otherwise returns #f.
Example:
  (string<? "a" "b") => #t
  (string<? "abc" "abd") => #t
  (string<? "b" "a") => #f
```

### `string=?`

```
Syntax: (string=? s1 s2 ...)
Library: (scheme base)
Description: Returns #t if all the given strings are equal to each other, otherwise returns #f.
Example:
  (string=? "abc" "abc") => #t
  (string=? "abc" "def") => #f
  (string=? "x" "x" "x") => #t
```

### `string>=?`

```
Syntax: (string>=? s1 s2 ...)
Library: (scheme base)
Description: Returns #t if the strings are monotonically non-decreasing in lexicographic order, otherwise returns #f.
Example:
  (string>=? "b" "a") => #t
  (string>=? "abc" "abc") => #t
  (string>=? "a" "b") => #f
```

### `string>?`

```
Syntax: (string>? s1 s2 ...)
Library: (scheme base)
Description: Returns #t if the strings are monotonically decreasing in lexicographic order, otherwise returns #f.
Example:
  (string>? "b" "a") => #t
  (string>? "abc" "abc") => #f
  (string>? "c" "b" "a") => #t
```

### `string?`

```
Syntax: (string? obj)
Library: (scheme base) (srfi 13)
Description: Returns #t if obj is a string, otherwise returns #f.
Example:
  (string? "hello") => #t
  (string? 42) => #f
```

### `substring`

```
Syntax: (substring s start end)
Library: (scheme base)
Description: Returns a newly allocated string containing the characters of s from index start (inclusive) to end (exclusive).
Example:
  (substring "hello" 1 3) => "el"
  (substring "hello" 0 5) => "hello"
```

### `symbol->string`

```
Syntax: (symbol->string sym)
Library: (scheme base)
Description: Returns the name of sym as a string.
Example:
  (symbol->string 'hello) => "hello"
  (symbol->string 'foo-bar) => "foo-bar"
```

### `symbol=?`

```
Syntax: (symbol=? symbol1 symbol2 ...)
Library: (scheme base)
Description: Returns #t if all the arguments are symbols with the same names,
  in the sense of string=?. It is an error to apply symbol=? to anything other
  than symbols.
Example:
  (symbol=? 'foo 'foo)      => #t
  (symbol=? 'foo 'bar)      => #f
  (symbol=? 'foo 'foo 'foo) => #t
```

### `symbol?`

```
Syntax: (symbol? obj)
Library: (scheme base)
Description: Returns #t if obj is a symbol, #f otherwise.
Example:
  (symbol? 'foo) => #t
  (symbol? "foo") => #f
```

### `syntax-error`

```
Syntax: (error message obj ...) (error who message obj ...)
Library: (scheme base)
Description: Raises an error. In R7RS form, message is a string and obj ... are irritants. In SRFI-23 form, who is a symbol identifying the caller.
Example:
  (error "out of range" 42)
  (error 'my-proc "value out of range" 42)
```

### `textual-port?`

```
Syntax: (textual-port? obj)
Library: (scheme base)
Description: Returns #t if obj is a textual port (i.e., a port that reads or writes characters), #f otherwise.
Example:
  (textual-port? (current-input-port)) => #t
  (textual-port? (open-output-bytevector)) => #f
```

### `truncate`

```
Syntax: (truncate x)
Library: (scheme base)
Description: Returns the integer closest to x whose absolute value is not larger than the absolute value of x (rounds toward zero).
Example:
  (truncate 3.7) => 3.0
  (truncate -3.7) => -3.0
```

### `truncate-quotient`

```
Syntax: (quotient n1 n2)
Library: (scheme base)
Description: Returns the integer quotient of n1 divided by n2, truncated toward zero.
Example:
  (quotient 13 4) => 3
```

### `truncate-remainder`

```
Syntax: (remainder n1 n2)
Library: (scheme base)
Description: Returns the remainder of dividing n1 by n2. The result has the same sign as n1. It is an error if n2 is zero.
Example:
  (remainder 13 4) => 1
  (remainder -13 4) => -1
  (remainder 13 -4) => 1
```

### `truncate/`

```
Syntax: (truncate/ n1 n2)
Library: (scheme base)
Description: Returns two values: the truncate quotient and the truncate
  remainder of n1 divided by n2. The truncate quotient is the integer of
  largest absolute value that is not larger than the real-valued quotient n1/n2.
  Equivalent to calling quotient and remainder separately.
Example:
  (truncate/ 5 2)  => 2 1
  (truncate/ -5 2) => -2 -1
```

### `u8-ready?`

```
Syntax: (u8-ready?)
       (u8-ready? port)
Library: (scheme base)
Description: Returns #t if a byte is ready on the binary input port and returns
  #f otherwise. If the port is at end of file then u8-ready? returns #t. This
  implementation always returns #t.
Example:
  (u8-ready? (open-input-bytevector #u8(1 2 3))) => #t
```

### `unless`

```
Syntax: (unless test body ...)
Library: (scheme base)
Description: Evaluates test. If the result is #f, evaluates each body expression in sequence and returns the last. If the test is true, does nothing and returns an unspecified value.
Example:
  (unless #f (display "yes")) => yes
  (unless #t (display "no"))  => (nothing printed)
```

### `utf8->string`

```
Syntax: (utf8->string bv start? end?)
Library: (scheme base)
Description: Decodes the UTF-8 encoded bytes in bytevector bv (optionally from start to end) and returns the result as a string.
Example:
  (utf8->string #u8(104 101 108 108 111)) => "hello"
  (utf8->string #u8(104 101 108 108 111) 1 3) => "el"
```

### `values`

```
Syntax: (values obj ...)
Library: (scheme base)
Description: Returns all of its arguments as multiple values. Used with call-with-values to pass multiple results between procedures.
Example:
  (values 1 2 3) => 1 2 3
  (call-with-values (lambda () (values 4 5)) +) => 9
```

### `vector`

```
Syntax: (vector obj ...)
Library: (scheme base)
Description: Returns a newly allocated vector whose elements contain the given arguments.
Example:
  (vector 1 2 3) => #(1 2 3)
  (vector 'a 'b 'c) => #(a b c)
```

### `vector->list`

```
Syntax: (vector->list vector)
Library: (scheme base)
Description: Returns a newly allocated list containing the elements of vector in order. Optional start and end indices (zero-based, exclusive end) may be supplied to convert a subrange.
Example:
  (vector->list #(a b c)) => (a b c)
  (vector->list #(a b c d) 1 3) => (b c)
```

### `vector->string`

```
Syntax: (vector->string vector)
       (vector->string vector start)
       (vector->string vector start end)
Library: (scheme base)
Description: Returns a newly allocated string of the objects contained in the
  elements of vector between start and end. It is an error if any element is
  not a character. start defaults to 0 and end defaults to the length of the
  vector.
Example:
  (vector->string #(#\a #\b #\c))     => "abc"
  (vector->string #(#\a #\b #\c) 1)   => "bc"
  (vector->string #(#\a #\b #\c) 1 2) => "b"
```

### `vector-append`

```
Syntax: (vector-append vector ...)
Library: (scheme base)
Description: Returns a newly allocated vector whose elements are the
  concatenation of the elements of the given vectors. With no arguments,
  returns an empty vector.
Example:
  (vector-append '#(a b) '#(c d)) => #(a b c d)
  (vector-append '#(a) '#() '#(b c)) => #(a b c)
```

### `vector-copy`

```
Syntax: (vector-copy vector)
       (vector-copy vector start)
       (vector-copy vector start end)
Library: (scheme base)
Description: Returns a newly allocated copy of the elements of the given
  vector between start and end. start defaults to 0 and end defaults to the
  length of the vector.
Example:
  (vector-copy '#(a b c d e) 2 4) => #(c d)
  (vector-copy '#(a b c))         => #(a b c)
```

### `vector-copy!`

```
Syntax: (vector-copy! to at from)
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
    v) => #(1 11 12 4 5)
```

### `vector-fill!`

```
Syntax: (vector-fill! vector fill)
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
    v) => #(1 0 0 4 5)
```

### `vector-for-each`

```
Syntax: (vector-for-each proc vector1 vector2 ...)
Library: (scheme base)
Description: It is an error if proc does not accept as many arguments as
  there are vectors. Applies proc element-wise to the elements of the vectors
  for its side effects, in order from the first element to the last. The
  return value is unspecified.
Example:
  (vector-for-each display '#(a b c)) ; displays abc
```

### `vector-length`

```
Syntax: (vector-length v)
Library: (scheme base)
Description: Returns the number of elements in vector v.
Example:
  (vector-length #(1 2 3)) => 3
  (vector-length (vector)) => 0
```

### `vector-map`

```
Syntax: (vector-map proc vector1 vector2 ...)
Library: (scheme base)
Description: It is an error if proc does not accept as many arguments as
  there are vectors and return a single value. Applies proc element-wise to
  the elements of the vectors and returns a vector of the results. The
  dynamic order in which proc is applied to the elements is unspecified.
Example:
  (vector-map + '#(1 2 3) '#(4 5 6)) => #(5 7 9)
  (vector-map cadr '#((a b) (d e) (g h))) => #(b e h)
```

### `vector-ref`

```
Syntax: (vector-ref v k)
Library: (scheme base)
Description: Returns the element at index k in vector v. If k is out of range and a default is provided, returns the default instead of signalling an error.
Example:
  (vector-ref #(a b c) 1) => b
  (vector-ref #(a b c) 5 'none) => none
```

### `vector-set!`

```
Syntax: (vector-set! v k obj)
Library: (scheme base)
Description: Stores obj in element k of vector v. It is an error if k is not a valid index of v.
Example:
  (let ((v (vector 1 2 3))) (vector-set! v 1 99) v) => #(1 99 3)
```

### `vector?`

```
Syntax: (vector? obj)
Library: (scheme base)
Description: Returns #t if obj is a vector, #f otherwise.
Example:
  (vector? #(1 2 3)) => #t
  (vector? '(1 2 3)) => #f
```

### `when`

```
Syntax: (when test body ...)
Library: (scheme base)
Description: Evaluates test. If the result is true, evaluates each body expression in sequence and returns the last. If the test is #f, does nothing and returns an unspecified value.
Example:
  (when #t (display "yes")) => yes
  (when #f (display "no"))  => (nothing printed)
```

### `with-exception-handler`

```
Syntax: (with-exception-handler handler thunk)
Library: (scheme base)
Description: Calls thunk with handler installed as the current exception handler.
Example:
  (with-exception-handler (lambda (e) 42) (lambda () (raise 'oops))) => 42
```

### `write-bytevector`

```
Syntax: (write-bytevector bv port? start? end?)
Library: (scheme base)
Description: Writes the bytes of bytevector bv to binary output port, optionally restricted to the range [start, end).
Example:
  (write-bytevector #u8(1 2 3) port)
  (write-bytevector #u8(1 2 3 4 5) port 1 3)
```

### `write-char`

```
Syntax: (write-char char port?)
Library: (scheme base)
Description: Writes the character char to the given textual output port, or to the current output port if no port is specified.
Example:
  (write-char #\A) => (outputs A)
  (write-char #\newline port)
```

### `write-string`

```
Syntax: (write-string string)
       (write-string string port)
       (write-string string port start)
       (write-string string port start end)
Library: (scheme base)
Description: Writes the characters of string from start to end in left-to-right
  order to the given port. port defaults to the current output port. start
  defaults to 0 and end defaults to the length of string. The return value is
  unspecified.
Example:
  (write-string "hello")          ; writes hello
  (write-string "hello" (current-output-port) 1 3) ; writes el
```

### `write-u8`

```
Syntax: (write-u8 byte port?)
Library: (scheme base)
Description: Writes a single byte (an exact integer in the range 0-255) to the given binary output port.
Example:
  (write-u8 65 port)
  (write-u8 0 port)
```

### `zero?`

```
Syntax: (zero? z)
Library: (scheme base)
Description: Returns #t if z is zero, #f otherwise.
Example:
  (zero? 0)   => #t
  (zero? 1)   => #f
  (zero? 0.0) => #t
```


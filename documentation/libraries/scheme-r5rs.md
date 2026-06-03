# `(scheme r5rs)`

Full R5RS compatibility library

## Overview

`(scheme r5rs)` is the R5RS compatibility library: a single import that provides
the procedures and syntax of the older R5RS standard, for running legacy code with
minimal changes. It bundles the familiar arithmetic, list, character, string, and
control operations under one name.

## Common uses

```scheme
(import (scheme r5rs))

(map (lambda (x) (* x x)) '(1 2 3))     ;; => (1 4 9)
(assoc 'b '((a . 1) (b . 2)))           ;; => (b . 2)
(call-with-current-continuation
  (lambda (k) (+ 1 (k 41))))            ;; => 41
```

New code should prefer `(scheme base)` and the other R7RS libraries; reach for
`(scheme r5rs)` when porting existing R5RS programs.


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

### `acos`

```
Syntax: (acos z)
Library: (scheme inexact)
Description: Returns the arc cosine of z. The result is in radians.
Example:
  (acos 1.0) => 0.0
  (acos 0.0) => 1.5707963267948966
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

### `angle`

```
Syntax: (angle z)
Library: (scheme complex)
Description: Returns the angle (argument) of the complex number z in radians.
  For positive reals, returns 0.0. For negative reals, returns pi.
Example:
  (angle 1.0)  => 0.0
  (angle -1.0) => 3.141592653589793
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

### `asin`

```
Syntax: (asin z)
Library: (scheme inexact)
Description: Returns the arc sine of z. The result is in radians.
Example:
  (asin 0.0) => 0.0
  (asin 1.0) => 1.5707963267948966
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

### `atan`

```
Syntax: (atan z) (atan y x)
Library: (scheme inexact)
Description: Returns the arc tangent of z, or of y/x when two arguments are given. The result is in radians.
Example:
  (atan 0.0) => 0.0
  (atan 1.0 1.0) => 0.7853981633974483
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

### `caaaar`

```
Syntax: (caaaar pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (car (car pair)))). Accesses the car of
four nested car operations on a pair structure.
Example:
  (caaaar '((((1 2) 3) 4) 5)) => 1
```

### `caaadr`

```
Syntax: (caaadr pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (car (cdr pair)))). Accesses the car of
the car of the car of the cdr of a nested pair structure.
Example:
  (caaadr '(1 ((2 3) 4) 5)) => 2
```

### `caaar`

```
Syntax: (caaar pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (car pair))). Accesses the car of the
car of the car of a nested pair structure.
Example:
  (caaar '(((1 2) 3) 4)) => 1
```

### `caadar`

```
Syntax: (caadar pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (cdr (car pair)))). Accesses the car of
the car of the cdr of the car of a nested pair structure.
Example:
  (caadar '((1 (2 3)) 4)) => 2
```

### `caaddr`

```
Syntax: (caaddr pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (cdr (cdr pair)))). Accesses the car of
the car of the third tail of a nested pair structure.
Example:
  (caaddr '(1 2 (3 4) 5)) => 3
```

### `caadr`

```
Syntax: (caadr pair)
Library: (scheme cxr)
Description: Equivalent to (car (car (cdr pair))). Accesses the car of the
car of the cdr of a nested pair structure.
Example:
  (caadr '(1 (2 3) 4)) => 2
```

### `caar`

```
Syntax: (caar pair)
Library: (scheme base)
Description: Returns the car of the car of pair. Equivalent to (car (car pair)).
Example:
  (caar '((a b) c)) => a
```

### `cadaar`

```
Syntax: (cadaar pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (car (car pair)))). Accesses the car of
the cdr of the car of the car of a nested pair structure.
Example:
  (cadaar '(((1 2) 3) 4)) => 2
```

### `cadadr`

```
Syntax: (cadadr pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (car (cdr pair)))). Accesses the car of
the cdr of the car of the cdr of a nested pair structure.
Example:
  (cadadr '(1 (2 3) 4)) => 3
```

### `cadar`

```
Syntax: (cadar pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (car pair))). Accesses the car of the
cdr of the car of a nested pair structure.
Example:
  (cadar '((1 2) 3)) => 2
```

### `caddar`

```
Syntax: (caddar pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (cdr (car pair)))). Accesses the car of
the cdr of the cdr of the car of a nested pair structure.
Example:
  (caddar '((1 2 3) 4)) => 3
```

### `cadddr`

```
Syntax: (cadddr pair)
Library: (scheme cxr)
Description: Equivalent to (car (cdr (cdr (cdr pair)))). Returns the fourth
element of a list.
Example:
  (cadddr '(1 2 3 4 5)) => 4
```

### `caddr`

```
Syntax: (caddr pair)
Library: (scheme base)
Description: Returns the car of the cdr of the cdr of pair. Equivalent to (car (cdr (cdr pair))). This is the third element of a list.
Example:
  (caddr '(1 2 3)) => 3
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

### `call-with-input-file`

```
Syntax: (call-with-input-file filename proc)
Library: (scheme file)
Description: Opens the file named by filename for input and calls proc with the resulting input port
  as its sole argument. When proc returns, the port is closed automatically via dynamic-wind, even
  if a non-local exit occurs. Returns the value(s) returned by proc. filename may also be a list
  whose car is the filename and whose remaining elements are options passed to open-input-file.
Example:
  (call-with-input-file "data.txt"
    (lambda (port) (read port))) => <first datum from file>
```

### `call-with-output-file`

```
Syntax: (call-with-output-file filename proc)
Library: (scheme file)
Description: Opens the file named by filename for output and calls proc with the resulting output
  port as its sole argument. When proc returns, the port is closed automatically via dynamic-wind,
  even if a non-local exit occurs. Returns the value(s) returned by proc. filename may also be a
  list whose car is the filename and whose remaining elements are options passed to open-output-file.
Example:
  (call-with-output-file "out.txt"
    (lambda (port) (write 42 port))) => <unspecified>
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

### `cdaaar`

```
Syntax: (cdaaar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (car (car pair)))). Accesses the cdr of
the car of the car of the car of a nested pair structure.
Example:
  (cdaaar '((((1 2) 3) 4) 5)) => (2)
```

### `cdaadr`

```
Syntax: (cdaadr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (car (cdr pair)))). Accesses the cdr of
the car of the car of the cdr of a nested pair structure.
Example:
  (cdaadr '(1 ((2 3) 4) 5)) => (3)
```

### `cdaar`

```
Syntax: (cdaar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (car pair))). Accesses the cdr of the
car of the car of a nested pair structure.
Example:
  (cdaar '(((1 2) 3) 4)) => (2)
```

### `cdadar`

```
Syntax: (cdadar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (cdr (car pair)))). Accesses the cdr of
the car of the cdr of the car of a nested pair structure.
Example:
  (cdadar '((1 (2 3)) 4)) => (3)
```

### `cdaddr`

```
Syntax: (cdaddr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (cdr (cdr pair)))). Accesses the cdr of
the car of the third tail of a nested pair structure.
Example:
  (cdaddr '(1 2 (3 4) 5)) => (4)
```

### `cdadr`

```
Syntax: (cdadr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (car (cdr pair))). Accesses the cdr of the
car of the cdr of a nested pair structure.
Example:
  (cdadr '(1 (2 3) 4)) => (3)
```

### `cdar`

```
Syntax: (cdar pair)
Library: (scheme base)
Description: Returns the cdr of the car of pair. Equivalent to (cdr (car pair)).
Example:
  (cdar '((1 2) 3)) => (2)
```

### `cddaar`

```
Syntax: (cddaar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (car (car pair)))). Accesses the cdr of
the cdr of the car of the car of a nested pair structure.
Example:
  (cddaar '(((1 2 3) 4) 5)) => (3)
```

### `cddadr`

```
Syntax: (cddadr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (car (cdr pair)))). Accesses the cdr of
the cdr of the car of the cdr of a nested pair structure.
Example:
  (cddadr '(1 (2 3 4) 5)) => (4)
```

### `cddar`

```
Syntax: (cddar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (car pair))). Accesses the cdr of the
cdr of the car of a nested pair structure.
Example:
  (cddar '((1 2 3) 4)) => (3)
```

### `cdddar`

```
Syntax: (cdddar pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (cdr (car pair)))). Accesses the cdr of
the cdr of the cdr of the car of a nested pair structure.
Example:
  (cdddar '((1 2 3 4) 5)) => (4)
```

### `cddddr`

```
Syntax: (cddddr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (cdr (cdr pair)))). Returns the tail of
a list starting after the fourth element.
Example:
  (cddddr '(1 2 3 4 5 6)) => (5 6)
```

### `cdddr`

```
Syntax: (cdddr pair)
Library: (scheme cxr)
Description: Equivalent to (cdr (cdr (cdr pair))). Returns the tail of a
list starting after the third element.
Example:
  (cdddr '(1 2 3 4 5)) => (4 5)
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

### `char-alphabetic?`

```
Syntax: (char-alphabetic? char)
Library: (scheme char)
Description: Returns #t if char is an alphabetic character.
Example:
  (char-alphabetic? #\a) => #t
  (char-alphabetic? #\1) => #f
```

### `char-ci<=?`

```
Syntax: (char-ci<=? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if the given characters are monotonically non-decreasing (less than or equal)
  in a case-insensitive comparison, that is, after applying char-downcase to each.
Example:
  (char-ci<=? #\a #\A) => #t
  (char-ci<=? #\A #\b #\B) => #t
```

### `char-ci<?`

```
Syntax: (char-ci<? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if the given characters are monotonically increasing (strictly less than)
  in a case-insensitive comparison, that is, after applying char-downcase to each.
Example:
  (char-ci<? #\a #\B) => #t
  (char-ci<? #\A #\b #\C) => #t
```

### `char-ci=?`

```
Syntax: (char-ci=? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if all given characters are equal when compared in a case-insensitive manner,
  that is, after applying char-downcase to each. Accepts one or more character arguments.
Example:
  (char-ci=? #\A #\a) => #t
  (char-ci=? #\B #\b #\B) => #t
```

### `char-ci>=?`

```
Syntax: (char-ci>=? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if the given characters are monotonically non-increasing (greater than or equal)
  in a case-insensitive comparison, that is, after applying char-downcase to each.
Example:
  (char-ci>=? #\A #\a) => #t
  (char-ci>=? #\C #\B #\a) => #t
```

### `char-ci>?`

```
Syntax: (char-ci>? char1 char2 ...)
Library: (scheme char)
Description: Returns #t if the given characters are monotonically decreasing (strictly greater than)
  in a case-insensitive comparison, that is, after applying char-downcase to each.
Example:
  (char-ci>? #\B #\a) => #t
  (char-ci>? #\C #\b #\A) => #t
```

### `char-downcase`

```
Syntax: (char-downcase char)
Library: (scheme char)
Description: Returns the lowercase equivalent of char if it exists, otherwise returns char.
Example:
  (char-downcase #\A) => #\a
  (char-downcase #\a) => #\a
```

### `char-lower-case?`

```
Syntax: (char-lower-case? char)
Library: (scheme char)
Description: Returns #t if char is a lowercase character.
Example:
  (char-lower-case? #\a) => #t
  (char-lower-case? #\A) => #f
```

### `char-numeric?`

```
Syntax: (char-numeric? char)
Library: (scheme char)
Description: Returns #t if char is a numeric character (digit).
Example:
  (char-numeric? #\5) => #t
  (char-numeric? #\a) => #f
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

### `char-upcase`

```
Syntax: (char-upcase char)
Library: (scheme char)
Description: Returns the uppercase equivalent of char if it exists, otherwise returns char.
Example:
  (char-upcase #\a) => #\A
  (char-upcase #\A) => #\A
```

### `char-upper-case?`

```
Syntax: (char-upper-case? char)
Library: (scheme char)
Description: Returns #t if char is an uppercase character.
Example:
  (char-upper-case? #\A) => #t
  (char-upper-case? #\a) => #f
```

### `char-whitespace?`

```
Syntax: (char-whitespace? char)
Library: (scheme char)
Description: Returns #t if char is a whitespace character (space, tab, newline, etc.).
Example:
  (char-whitespace? #\space) => #t
  (char-whitespace? #\a) => #f
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

### `cos`

```
Syntax: (cos z)
Library: (scheme inexact)
Description: Returns the cosine of z. The argument is in radians.
Example:
  (cos 0.0) => 1.0
  (cos 3.141592653589793) => -1.0
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

### `delay`

```
Syntax: (delay expr)
Library: (scheme lazy)
Description: Returns a promise that, when forced via force, will evaluate
expr and cache the result. The expression is not evaluated until the first
call to force. Subsequent calls return the cached result.
Example:
  (define p (delay (begin (display "once") 42)))
  (force p) => 42  ; prints "once"
  (force p) => 42  ; cached, no output
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

### `display`

```
Syntax: (display obj) (display obj port)
Library: (scheme write)
Description: Writes a human-readable representation of obj to the current output port or the given port. Strings are written without quotes; characters are written without the #\ prefix.
Example:
  (display "hello") => hello
  (display #\a) => a
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

### `eval`

```
Syntax: (eval expr) (eval expr environment)
Library: (scheme eval)
Description: Evaluates expr in the given environment specifier. If no environment is given, evaluates in the scm core environment.
Example:
  (eval '(+ 1 2) (environment '(scheme base))) => 3
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

### `exact->inexact`

```
Syntax: (inexact z)
Library: (scheme base)
Description: Returns the inexact (floating-point) number that is numerically closest to z.
Example:
  (inexact 1) => 1.0
  (inexact 1/3) => 0.3333333333333333
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

### `exp`

```
Syntax: (exp num)
Library: (scheme inexact)
Description: Returns e raised to the power of num, where e is the base of the
natural logarithm. The result is an inexact real number.
Example:
  (exp 0)   => 1.0
  (exp 1)   => 2.718281828459045
  (exp 2)   => 7.38905609893065
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

### `force`

```
Syntax: (force promise)
Library: (scheme lazy)
Description: Forces the value of a promise created by delay, delay-force, or
make-promise. If the promise has not been forced previously, its value is
computed by calling the thunk that was used to create it and is cached for
future calls to force. If promise is not a promise, it is returned as-is.
Example:
  (force (delay (+ 1 2)))   => 3
  (define p (delay (begin (display "computed") 42)))
  (force p)  => 42  ; prints "computed" once
  (force p)  => 42  ; cached, no output
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

### `imag-part`

```
Syntax: (imag-part z)
Library: (scheme complex)
Description: Returns the imaginary part of the complex number z. For real
  numbers, returns 0 (exact or inexact matching z's exactness).
Example:
  (imag-part 3.0)  => 0.0
  (imag-part 1+2i) => 2
```

### `inexact->exact`

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

### `inexact?`

```
Syntax: (inexact? z)
Library: (scheme base)
Description: Returns #t if z is inexact (i.e., not exact), #f otherwise.
Example:
  (inexact? 1.0) => #t
  (inexact? 1)   => #f
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

### `interaction-environment`

*(no documentation)*

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

### `list-ref`

```
Syntax: (list-ref list k)
Library: (scheme base)
Description: Returns the k-th element (zero-indexed) of list. It is an error if k is out of range.
Example:
  (list-ref '(a b c) 0) => a
  (list-ref '(a b c) 2) => c
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

### `load`

```
Syntax: (load filename) (load filename environment)
Library: (scheme load)
Description: Reads and evaluates all expressions from the named Scheme source file. If an environment is given, evaluates in that module's environment.
Example:
  (load "mylib.scm")
```

### `log`

```
Syntax: (log z) (log z base)
Library: (scheme inexact)
Description: Returns the natural logarithm of z, or the logarithm of z to base if given.
Example:
  (log 1.0) => 0.0
  (log 8.0 2.0) => 3.0
```

### `magnitude`

```
Syntax: (magnitude z)
Library: (scheme complex)
Description: Returns the magnitude of the complex number z.
  For real numbers, equivalent to abs.
Example:
  (magnitude -3.0) => 3.0
  (magnitude 3+4i) => 5.0
```

### `make-polar`

```
Syntax: (make-polar r theta)
Library: (scheme complex)
Description: Returns the complex number r * e^(i*theta).
Example:
  (make-polar 1 0) => 1.0
  (make-polar 1 1) => 0.5403023058681398+0.8414709848078965i
```

### `make-rectangular`

```
Syntax: (make-rectangular x y)
Library: (scheme complex)
Description: Returns the complex number x + yi.
Example:
  (make-rectangular 1 2) => 1+2i
  (make-rectangular 3 0) => 3
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

### `null-environment`

*(no documentation)*

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

### `open-input-file`

```
Syntax: (open-input-file filename)
Library: (scheme file)
Description: Takes a filename and returns a textual input port that reads characters from the named file. It is an error if the file cannot be opened.
Example:
  (define p (open-input-file "data.txt"))
  (read-char p) => first character of file
```

### `open-output-file`

```
Syntax: (open-output-file filename)
Library: (scheme file)
Description: Takes a filename and returns a textual output port that writes characters to the named file. The file is created or truncated. It is an error if the file cannot be opened.
Example:
  (define p (open-output-file "out.txt"))
  (write-char #\A p)
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

### `quotient`

```
Syntax: (quotient n1 n2)
Library: (scheme base)
Description: Returns the integer quotient of n1 divided by n2, truncated toward zero.
Example:
  (quotient 13 4) => 3
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

### `read`

```
Syntax: (read)
Library: (scheme read)
Description: Reads an external representation of a Scheme object from the given port and returns the object. If no more objects are available, an end-of-file object is returned. If port is omitted, the current input port is used.
Example:
  (define p (open-input-string "(a b c)"))
  (read p) => (a b c)
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

### `real-part`

```
Syntax: (real-part z)
Library: (scheme complex)
Description: Returns the real part of the complex number z. For real numbers,
  returns z unchanged.
Example:
  (real-part 3.0)  => 3.0
  (real-part 1+2i) => 1
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

### `scheme-report-environment`

*(no documentation)*

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

### `sin`

```
Syntax: (sin z)
Library: (scheme inexact)
Description: Returns the sine of z, where z is in radians. Returns an inexact result.
Example:
  (sin 0) => 0.0
  (sin (/ (acos -1) 2)) => 1.0
```

### `sqrt`

```
Syntax: (sqrt z)
Library: (scheme inexact)
Description: Returns the principal square root of z. Returns an exact integer when the result is an exact integer, otherwise returns an inexact number.
Example:
  (sqrt 4) => 2
  (sqrt 2) => 1.4142135623730951
  (sqrt 9) => 3
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

### `string-append`

```
Syntax: (string-append string ...)
Library: (scheme base) (srfi 13)
Description: Returns a newly allocated string whose characters are the concatenation of the characters in the given strings.
Example:
  (string-append "foo" "bar") => "foobar"
  (string-append "a" "b" "c") => "abc"
```

### `string-ci<=?`

```
Syntax: (string-ci<=? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if the given strings are in non-decreasing lexicographic order when
  compared in a case-insensitive manner, that is, after applying string-downcase to each.
Example:
  (string-ci<=? "abc" "ABC") => #t
  (string-ci<=? "Apple" "apple" "Banana") => #t
```

### `string-ci<?`

```
Syntax: (string-ci<? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if the given strings are in strictly ascending lexicographic order when
  compared in a case-insensitive manner, that is, after applying string-downcase to each.
Example:
  (string-ci<? "apple" "Banana") => #t
  (string-ci<? "a" "B" "c") => #t
```

### `string-ci=?`

```
Syntax: (string-ci=? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if all given strings are equal when compared in a case-insensitive manner,
  that is, after applying string-downcase to each.
Example:
  (string-ci=? "Hello" "hello") => #t
  (string-ci=? "ABC" "abc" "Abc") => #t
```

### `string-ci>=?`

```
Syntax: (string-ci>=? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if the given strings are in non-increasing lexicographic order when
  compared in a case-insensitive manner, that is, after applying string-downcase to each.
Example:
  (string-ci>=? "ABC" "abc") => #t
  (string-ci>=? "Banana" "apple" "Apple") => #t
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

### `string-length`

```
Syntax: (string-length s)
Library: (scheme base) (srfi 13)
Description: Returns the number of characters in the string s.
Example:
  (string-length "hello") => 5
  (string-length "") => 0
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

### `symbol?`

```
Syntax: (symbol? obj)
Library: (scheme base)
Description: Returns #t if obj is a symbol, #f otherwise.
Example:
  (symbol? 'foo) => #t
  (symbol? "foo") => #f
```

### `tan`

```
Syntax: (tan z)
Library: (scheme inexact)
Description: Returns the trigonometric tangent of z, where z is in radians.
Example:
  (tan 0) => 0.0
  (tan (/ (* 3.14159265 1) 4)) => 1.0
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

### `vector-length`

```
Syntax: (vector-length v)
Library: (scheme base)
Description: Returns the number of elements in vector v.
Example:
  (vector-length #(1 2 3)) => 3
  (vector-length (vector)) => 0
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

### `with-input-from-file`

```
Syntax: (with-input-from-file filename thunk)
Library: (scheme file)
Description: Opens the file named by filename for input, makes it the current input port, and calls
  thunk with no arguments. When thunk returns, the original current input port is restored and the
  opened port is closed, both managed via dynamic-wind so they occur even on non-local exits.
  Returns the value(s) returned by thunk. filename may also be a list whose car is the filename
  and whose remaining elements are options passed to open-input-file.
Example:
  (with-input-from-file "data.txt"
    (lambda () (read))) => <first datum from file>
```

### `with-output-to-file`

```
Syntax: (with-output-to-file filename thunk)
Library: (scheme file)
Description: Opens the file named by filename for output, makes it the current output port, and
  calls thunk with no arguments. When thunk returns, the original current output port is restored
  and the opened port is closed, both managed via dynamic-wind so they occur even on non-local
  exits. Returns the value(s) returned by thunk. filename may also be a list whose car is the
  filename and whose remaining elements are options passed to open-output-file.
Example:
  (with-output-to-file "out.txt"
    (lambda () (display "hello"))) => <unspecified>
```

### `write`

```
Syntax: (write obj port?)
Library: (scheme write)
Description: Writes a machine-readable representation of obj to the given port, or the current output port. Strings are written with quotes and special characters escaped.
Example:
  (write '(1 "two" #\3)) => (1 "two" #\3)
  (write 'hello) => hello
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


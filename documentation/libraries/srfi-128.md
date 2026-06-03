# `(srfi 128)`

SRFI-128 — Comparators: bundled type-test, equality, ordering, and hash procedures

## Overview

SRFI-128 provides comparators: bundles of a type test, an equality predicate, an
ordering predicate, and a hash function. They give a single value that fully
describes how to compare and hash a kind of data — used by hash tables (SRFI-125)
and ordered collections.

## Common uses

```scheme
(import (srfi 128))

(define c (make-comparator number? = < #f))   ;; type=, equal=, order=, hash=
(comparator? c)                                ;; => #t
(=? c 3 3)                                      ;; => #t
(<? c 1 2)                                      ;; => #t
```

`make-default-comparator` returns a general-purpose comparator, and there are
predefined comparators and combinators for building comparators over compound data.


## Exports

### `<=?`

```
Syntax: (<=? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if each argument is less than or equal to the next.
Example:
  (<=? (make-default-comparator) 1 1 2) => #t
```

### `<?`

```
Syntax: (<? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if each argument is less than the next according to the comparator.
Example:
  (<? (make-default-comparator) 1 2 3) => #t
  (<? (make-default-comparator) 1 1) => #f
```

### `=?`

```
Syntax: (=? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if all arguments are equal according to the comparator.
Example:
  (=? (make-default-comparator) 1 1 1) => #t
  (=? (make-default-comparator) 1 2) => #f
```

### `>=?`

```
Syntax: (>=? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if each argument is greater than or equal to the next.
Example:
  (>=? (make-default-comparator) 3 3 1) => #t
```

### `>?`

```
Syntax: (>? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if each argument is greater than the next according to the comparator.
Example:
  (>? (make-default-comparator) 3 2 1) => #t
```

### `boolean-hash`

```
Syntax: (boolean-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a boolean.
Example:
  (integer? (boolean-hash #t)) => #t
  (= (boolean-hash #t) (boolean-hash #t)) => #t
```

### `char-ci-hash`

```
Syntax: (char-ci-hash obj)
Library: (srfi 128)
Description: Returns a case-insensitive hash value for a character.
Example:
  (= (char-ci-hash #\A) (char-ci-hash #\a)) => #t
```

### `char-hash`

```
Syntax: (char-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a character.
Example:
  (integer? (char-hash #\a)) => #t
  (= (char-hash #\a) (char-hash #\a)) => #t
```

### `comparator-check-type`

```
Syntax: (comparator-check-type comparator obj)
Library: (srfi 128)
Description: Like comparator-test-type but raises an error if obj fails.
Example:
  (comparator-check-type (make-default-comparator) 42) => #t
```

### `comparator-equality-predicate`

*(no documentation)*

### `comparator-hash-function`

*(no documentation)*

### `comparator-hashable?`

*(no documentation)*

### `comparator-if<=>`

*(no documentation)*

### `comparator-ordered?`

*(no documentation)*

### `comparator-ordering-predicate`

*(no documentation)*

### `comparator-register-default!`

```
Syntax: (comparator-register-default! comparator)
Library: (srfi 128)
Description: Registers a comparator to be used by the default comparator for types
that satisfy the registered comparator's type test.
Example:
  (comparator-register-default!
    (make-comparator string? string=? string<? string-hash))
```

### `comparator-test-type`

```
Syntax: (comparator-test-type comparator obj)
Library: (srfi 128)
Description: Returns #t if obj satisfies the type test of the comparator.
Example:
  (comparator-test-type (make-default-comparator) 42) => #t
```

### `comparator-type-test-predicate`

*(no documentation)*

### `comparator?`

*(no documentation)*

### `default-comparator`

*(no documentation)*

### `default-hash`

```
Syntax: (default-hash obj)
Library: (srfi 128)
Description: Returns a hash value for any object using the default hashing strategy.
Example:
  (integer? (default-hash 42)) => #t
  (integer? (default-hash "hello")) => #t
```

### `hash-bound`

```
Syntax: (hash-bound)
Library: (srfi 128)
Description: Returns the upper exclusive bound for hash values. Implementation-defined.
Example:
  (> (hash-bound) 0) => #t
```

### `hash-salt`

```
Syntax: (hash-salt)
Library: (srfi 128)
Description: Returns a salt value for hash functions. Returns 0 in this implementation.
Example:
  (integer? (hash-salt)) => #t
```

### `make-comparator`

```
Syntax: (make-comparator type-test equality ordering hash)
Library: (srfi 128)
Description: Creates a comparator from four procedures. type-test is a predicate
that returns #t for valid arguments. equality is an equivalence predicate. ordering
is an ordering predicate (or #f if not provided). hash is a hash function (or #f
if not provided). If equality is #t, equal? is used.
Example:
  (define c (make-comparator string? string=? string<? string-hash))
  (comparator? c) => #t
  (comparator-ordered? c) => #t
```

### `make-default-comparator`

```
Syntax: (make-default-comparator)
Library: (srfi 128)
Description: Returns a comparator that handles booleans, characters, strings, symbols,
numbers, null, pairs, and vectors, with ordering and hashing support.
Example:
  (define c (make-default-comparator))
  (=? c 1 1) => #t
  (<? c 1 2) => #t
  (<? c "a" "b") => #t
```

### `make-eq-comparator`

```
Syntax: (make-eq-comparator)
Library: (srfi 128)
Description: Returns a comparator that uses eq? for equality.
Example:
  (define c (make-eq-comparator))
  (comparator? c) => #t
```

### `make-equal-comparator`

```
Syntax: (make-equal-comparator)
Library: (srfi 128)
Description: Returns a comparator that uses equal? for equality and default-hash for hashing.
Example:
  (define c (make-equal-comparator))
  (comparator? c) => #t
  (comparator-hashable? c) => #t
```

### `make-eqv-comparator`

```
Syntax: (make-eqv-comparator)
Library: (srfi 128)
Description: Returns a comparator that uses eqv? for equality.
Example:
  (define c (make-eqv-comparator))
  (comparator? c) => #t
```

### `make-list-comparator`

```
Syntax: (make-list-comparator element-comparator type-test empty? head tail)
Library: (srfi 128)
Description: Returns a comparator for list-like sequences using the given element
comparator and sequence access procedures.
Example:
  (define c (make-list-comparator (make-default-comparator) list? null? car cdr))
  (=? c '(1 2 3) '(1 2 3)) => #t
```

### `make-pair-comparator`

```
Syntax: (make-pair-comparator car-comparator cdr-comparator)
Library: (srfi 128)
Description: Returns a comparator for pairs that compares car and cdr using
the given comparators.
Example:
  (define c (make-pair-comparator (make-default-comparator) (make-default-comparator)))
  (=? c '(1 . 2) '(1 . 2)) => #t
```

### `make-vector-comparator`

```
Syntax: (make-vector-comparator element-comparator type-test length ref)
Library: (srfi 128)
Description: Returns a comparator for vector-like sequences using the given element
comparator and vector access procedures.
Example:
  (define c (make-vector-comparator (make-default-comparator) vector? vector-length vector-ref))
  (=? c #(1 2 3) #(1 2 3)) => #t
```

### `number-hash`

```
Syntax: (number-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a number.
Example:
  (integer? (number-hash 42)) => #t
  (= (number-hash 3.14) (number-hash 3.14)) => #t
```

### `string-ci-hash`

```
Syntax: (string-ci-hash obj)
Library: (srfi 128)
Description: Returns a case-insensitive hash value for a string.
Example:
  (= (string-ci-hash "Hello") (string-ci-hash "hello")) => #t
```

### `string-hash`

```
Syntax: (string-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a string.
Example:
  (integer? (string-hash "hello")) => #t
  (= (string-hash "abc") (string-hash "abc")) => #t
```

### `symbol-hash`

```
Syntax: (symbol-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a symbol.
Example:
  (integer? (symbol-hash 'foo)) => #t
  (= (symbol-hash 'bar) (symbol-hash 'bar)) => #t
```


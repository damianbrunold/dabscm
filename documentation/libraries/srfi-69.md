# `(srfi 69)`

SRFI-69 — Basic hash tables with eq?/eqv?/equal? support

## Exports

### `hash`

```
Syntax: (hash obj [bound])
Library: (srfi 69)
Description: Returns a non-negative integer hash suitable for any Scheme object, using
equal?-based comparison semantics. Handles strings, symbols, numbers, chars, booleans,
null, and pairs. If bound is given, the result is in [0, bound); otherwise [0, 2^32).
Example:
  (integer? (hash '(1 2 3))) => #t
  (= (hash "abc") (hash "abc")) => #t
  (< (hash 'foo 100) 100) => #t
```

### `hash-by-identity`

```
Syntax: (hash-by-identity obj [bound])
Library: (srfi 69)
Description: Returns a hash of obj using identity (eq?) comparison semantics. In this
implementation it delegates to hash. If bound is given, the result is in [0, bound).
Example:
  (integer? (hash-by-identity 'foo)) => #t
  (< (hash-by-identity 42 100) 100) => #t
```

### `hash-table->alist`

```
Syntax: (hash-table->alist ht)
Library: (srfi 69)
Description: Returns an association list of all key-value pairs in the hash table ht. The order is unspecified.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table->alist ht) => ((a . 1))
```

### `hash-table-copy`

```
Syntax: (hash-table-copy ht)
Library: (srfi 69)
Description: Returns a copy of the hash table ht with the same equality mode and all the same key-value associations.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (define ht2 (hash-table-copy ht))
  (hash-table-ref ht2 'a) => 1
```

### `hash-table-delete!`

```
Syntax: (hash-table-delete! ht key)
Library: (srfi 69)
Description: Removes the association for key from the hash table ht. Has no effect if key is not present.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table-delete! ht 'x)
  (hash-table-exists? ht 'x) => #f
```

### `hash-table-exists?`

```
Syntax: (hash-table-exists? ht key)
Library: (srfi 69)
Description: Returns #t if key is associated with a value in ht, #f otherwise.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table-exists? ht 'x) => #t
  (hash-table-exists? ht 'y) => #f
```

### `hash-table-fold`

```
Syntax: (hash-table-fold ht f init)
Library: (srfi 69)
Description: Folds f over all key-value associations in ht, starting from init.
f receives (key value accumulator) and returns the new accumulator.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-fold ht (lambda (k v acc) (+ v acc)) 0) => 1
```

### `hash-table-keys`

```
Syntax: (hash-table-keys ht)
Library: (srfi 69)
Description: Returns a list of all keys in the hash table ht. The order is unspecified.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-set! ht 'b 2)
  (list-sort symbol<? (hash-table-keys ht)) => (a b)
```

### `hash-table-merge!`

```
Syntax: (hash-table-merge! ht1 ht2)
Library: (srfi 69)
Description: Adds all key-value associations from ht2 into ht1. Returns ht1.
Example:
  (define ht1 (make-hash-table equal?))
  (define ht2 (make-hash-table equal?))
  (hash-table-set! ht2 'a 1)
  (hash-table-merge! ht1 ht2)
  (hash-table-ref ht1 'a) => 1
```

### `hash-table-ref`

```
Syntax: (hash-table-ref ht key [default-thunk])
Library: (srfi 69)
Description: Returns the value associated with key in ht. If the key is not found and default-thunk is provided, calls it and returns the result; otherwise raises an error.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table-ref ht 'x) => 42
```

### `hash-table-ref/default`

```
Syntax: (hash-table-ref/default ht key default)
Library: (srfi 69)
Description: Returns the value associated with key in ht, or default if key is not found.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table-ref/default ht 'x 0) => 42
  (hash-table-ref/default ht 'y 0) => 0
```

### `hash-table-set!`

```
Syntax: (hash-table-set! ht key value)
Library: (srfi 69)
Description: Associates key with value in the hash table ht. If the key already exists, its value is updated.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table-ref ht 'x) => 42
```

### `hash-table-size`

```
Syntax: (hash-table-size ht)
Library: (srfi 69)
Description: Returns the number of associations in the hash table ht.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 1)
  (hash-table-set! ht 'y 2)
  (hash-table-size ht) => 2
```

### `hash-table-update!`

```
Syntax: (hash-table-update! ht key proc [default-thunk])
Library: (srfi 69)
Description: Applies proc to the current value of key in ht and stores the result.
If key is absent and default-thunk is provided, uses (default-thunk) as the initial value.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 5)
  (hash-table-update! ht 'x (lambda (v) (+ v 1)))
  (hash-table-ref ht 'x) => 6
```

### `hash-table-update!/default`

```
Syntax: (hash-table-update!/default ht key proc default)
Library: (srfi 69)
Description: Applies proc to the current value of key in ht (or default if absent)
and stores the result.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-update!/default ht 'x (lambda (v) (+ v 1)) 0)
  (hash-table-ref ht 'x) => 1
```

### `hash-table-values`

```
Syntax: (hash-table-values ht)
Library: (srfi 69)
Description: Returns a list of all values in the hash table ht. The order is unspecified.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-set! ht 'b 2)
  (list-sort < (hash-table-values ht)) => (1 2)
```

### `hash-table-walk`

```
Syntax: (hash-table-walk ht proc)
Library: (srfi 69)
Description: Calls proc with each key and value in the hash table ht for side effects.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-walk ht (lambda (k v) (display k) (display v)))
```

### `hash-table/get`

```
Syntax: (hash-table/get ht key default)
Library: (srfi 69)
Description: Returns the value associated with key in ht, or default if key is not found.
Alias for hash-table-ref/default.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table/get ht 'x 0) => 42
  (hash-table/get ht 'y 0) => 0
```

### `hash-table/put!`

```
Syntax: (hash-table/put! ht key value)
Library: (srfi 69)
Description: Associates key with value in the hash table ht. If the key already exists, its value is updated.
Alias for hash-table-set!.
Example:
  (define ht (make-hash-table equal?))
  (hash-table/put! ht 'x 42)
  (hash-table-ref ht 'x) => 42
```

### `hash-table/remove!`

```
Syntax: (hash-table/remove! ht key)
Library: (srfi 69)
Description: Removes the association for key from the hash table ht. Has no effect if key is not present.
Alias for hash-table-delete!.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table/remove! ht 'x)
  (hash-table-exists? ht 'x) => #f
```

### `hash-table?`

```
Syntax: (hash-table? obj)
Library: (srfi 69)
Description: Returns #t if obj is a hash table, #f otherwise.
Example:
  (hash-table? (make-hash-table)) => #t
  (hash-table? '()) => #f
```

### `make-hash-table`

```
Syntax: (make-hash-table [equality-proc [hash-proc]])
Library: (srfi 69)
Description: Creates a new empty hash table. The optional equality-proc determines key comparison: eq?, eqv?, or equal? (default). The optional hash-proc is accepted but ignored.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-ref ht 'a) => 1
```

### `string-ci-hash`

```
Syntax: (string-ci-hash s [bound])
Library: (srfi 69)
Description: Returns a non-negative integer hash of string s, case-insensitively. Equivalent
to hashing the downcased version of s. If bound is given, the result is in [0, bound).
Example:
  (= (string-ci-hash "Hello") (string-ci-hash "hello")) => #t
  (< (string-ci-hash "World" 100) 100) => #t
```

### `string-hash`

```
Syntax: (string-hash s [bound])
Library: (srfi 69)
Description: Returns a non-negative integer hash of string s. If bound is given, the result
is in the range [0, bound); otherwise it is in [0, 2^32). The hash is case-sensitive.
Example:
  (integer? (string-hash "hello")) => #t
  (< (string-hash "world" 100) 100) => #t
  (= (string-hash "abc") (string-hash "abc")) => #t
```


# `(srfi 125)`

SRFI-125 — Intermediate hash tables: comparator-based hash tables with mapping, folding, and set operations

## Overview

SRFI-125 provides intermediate hash tables built on SRFI-128 comparators, with a
broad operation set: mapping, folding, and set-like combinations. Use it when you
want comparator-driven tables or the richer API; for simple `eq?`/`equal?` tables
SRFI-69 is lighter.

## Common uses

```scheme
(import (srfi 128) (srfi 125))

(define h (make-hash-table (make-default-comparator)))
(hash-table-set! h 1 "one")
(hash-table-ref/default h 1 #f)        ;; => "one"

(hash-table-update!/default h 2 (lambda (v) (+ v 1)) 0)
(hash-table-ref/default h 2 #f)        ;; => 1
```

It also offers `hash-table-map`, `hash-table-fold`, `hash-table-count`, and
`hash-table-union!`/`hash-table-intersection!` style operations.


## Exports

### `alist->hash-table`

```
Syntax: (alist->hash-table alist comparator)
Library: (srfi 125)
Description: Creates a hash table from an association list. Earlier entries take
precedence over later ones with the same key (first association wins).
Example:
  (define ht (alist->hash-table '((a . 1) (b . 2)) (make-default-comparator)))
  (hash-table-ref ht 'a) => 1
```

### `hash-table`

```
Syntax: (hash-table comparator key1 val1 key2 val2 ...)
Library: (srfi 125)
Description: Creates a new hash table populated with the given key-value pairs.
It is an error to supply duplicate keys.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-ref ht 'a) => 1
  (hash-table-ref ht 'b) => 2
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

### `hash-table-clear!`

```
Syntax: (hash-table-clear! ht)
Library: (srfi 125)
Description: Removes all associations from the hash table ht.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-clear! ht)
  (hash-table-size ht) => 0
```

### `hash-table-comparator`

```
Syntax: (hash-table-comparator ht)
Library: (srfi 125)
Description: Returns the comparator associated with the hash table.
Example:
  (define c (make-default-comparator))
  (define ht (make-hash-table c))
  (comparator? (hash-table-comparator ht)) => #t
```

### `hash-table-contains?`

```
Syntax: (hash-table-contains? ht key)
Library: (srfi 125)
Description: Returns #t if the hash table contains an association for key.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-contains? ht 'a) => #t
  (hash-table-contains? ht 'b) => #f
```

### `hash-table-copy`

```
Syntax: (hash-table-copy ht [mutable?])
Library: (srfi 125)
Description: Returns a copy of ht. The optional mutable? argument is accepted
but ignored (all copies are mutable in this implementation).
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table-copy ht))
  (hash-table-ref ht2 'a) => 1
```

### `hash-table-count`

```
Syntax: (hash-table-count pred ht)
Library: (srfi 125)
Description: Returns the number of associations in ht for which (pred key value)
returns true.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (hash-table-count (lambda (k v) (> v 1)) ht) => 2
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

### `hash-table-difference!`

```
Syntax: (hash-table-difference! ht1 ht2)
Library: (srfi 125)
Description: Removes from ht1 all keys that are in ht2. Returns ht1.
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (define ht2 (hash-table (make-default-comparator) 'b 20))
  (hash-table-difference! ht1 ht2)
  (hash-table-size ht1) => 2
```

### `hash-table-empty-copy`

```
Syntax: (hash-table-empty-copy ht)
Library: (srfi 125)
Description: Returns a new empty hash table with the same comparator as ht.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table-empty-copy ht))
  (hash-table-empty? ht2) => #t
```

### `hash-table-empty?`

```
Syntax: (hash-table-empty? ht)
Library: (srfi 125)
Description: Returns #t if the hash table has no associations.
Example:
  (hash-table-empty? (make-hash-table (make-default-comparator))) => #t
```

### `hash-table-entries`

```
Syntax: (hash-table-entries ht)
Library: (srfi 125)
Description: Returns two values: a list of keys and a list of values from ht.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-entries ht) => (a) (1)
```

### `hash-table-equivalence-function`

```
Syntax: (hash-table-equivalence-function ht)
Library: (srfi 125)
Description: Returns the equivalence function of the hash table's comparator.
Example:
  (define ht (make-hash-table (make-default-comparator)))
  (procedure? (hash-table-equivalence-function ht)) => #t
```

### `hash-table-find`

```
Syntax: (hash-table-find proc ht failure)
Library: (srfi 125)
Description: Calls proc with each key and value. If proc returns a true value, that
value is returned. If no entry satisfies proc, calls failure and returns its result.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-find (lambda (k v) (and (> v 1) v)) ht (lambda () #f)) => 2
```

### `hash-table-fold`

```
Syntax: (hash-table-fold proc init ht)
Library: (srfi 125)
Description: Folds proc over all key-value associations in ht, starting from init.
Note: SRFI-125 argument order is (proc init ht), unlike SRFI-69's (ht proc init).
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-fold (lambda (k v acc) (+ v acc)) 0 ht) => 3
```

### `hash-table-for-each`

```
Syntax: (hash-table-for-each proc ht)
Library: (srfi 125)
Description: Calls proc with each key and value in ht for side effects.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-for-each (lambda (k v) (display k)) ht)
```

### `hash-table-hash-function`

```
Syntax: (hash-table-hash-function ht)
Library: (srfi 125)
Description: Returns the hash function of the hash table's comparator.
Example:
  (define ht (make-hash-table (make-default-comparator)))
  (procedure? (hash-table-hash-function ht)) => #t
```

### `hash-table-intern!`

```
Syntax: (hash-table-intern! ht key failure)
Library: (srfi 125)
Description: If key exists in ht, returns its value. Otherwise calls failure,
stores the result, and returns it.
Example:
  (define ht (make-hash-table (make-default-comparator)))
  (hash-table-intern! ht 'a (lambda () 42)) => 42
  (hash-table-ref ht 'a) => 42
  (hash-table-intern! ht 'a (lambda () 99)) => 42
```

### `hash-table-intersection!`

```
Syntax: (hash-table-intersection! ht1 ht2)
Library: (srfi 125)
Description: Removes from ht1 all keys that are not in ht2. Returns ht1.
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (define ht2 (hash-table (make-default-comparator) 'a 10 'c 30))
  (hash-table-intersection! ht1 ht2)
  (hash-table-size ht1) => 2
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

### `hash-table-map`

```
Syntax: (hash-table-map proc comparator ht)
Library: (srfi 125)
Description: Returns a new hash table (with the given comparator) whose keys are
the same as ht and whose values are the result of applying proc to the values.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (define ht2 (hash-table-map (lambda (v) (* v 10)) (make-default-comparator) ht))
  (hash-table-ref ht2 'a) => 10
```

### `hash-table-map!`

```
Syntax: (hash-table-map! proc ht)
Library: (srfi 125)
Description: Replaces each value in ht with the result of applying proc to the
key and current value.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-map! (lambda (k v) (* v 10)) ht)
  (hash-table-ref ht 'a) => 10
```

### `hash-table-map->list`

```
Syntax: (hash-table-map->list proc ht)
Library: (srfi 125)
Description: Returns a list of the results of applying proc to each key and value.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (sort (hash-table-map->list (lambda (k v) v) ht) <) => (1 2)
```

### `hash-table-mutable?`

```
Syntax: (hash-table-mutable? ht)
Library: (srfi 125)
Description: Returns #t. All hash tables in this implementation are mutable.
Example:
  (hash-table-mutable? (make-hash-table (make-default-comparator))) => #t
```

### `hash-table-pop!`

```
Syntax: (hash-table-pop! ht)
Library: (srfi 125)
Description: Removes an arbitrary association from ht and returns its key and value
as two values. It is an error if ht is empty.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-pop! ht) => 'a 1
  (hash-table-empty? ht) => #t
```

### `hash-table-prune!`

```
Syntax: (hash-table-prune! proc ht)
Library: (srfi 125)
Description: Removes all associations for which (proc key value) returns true.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (hash-table-prune! (lambda (k v) (> v 1)) ht)
  (hash-table-size ht) => 1
```

### `hash-table-ref`

```
Syntax: (hash-table-ref ht key [failure [success]])
Library: (srfi 125)
Description: Returns the value associated with key in ht. If key is not found,
calls failure thunk if given, otherwise raises an error. If success is given,
applies it to the value.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-ref ht 'a) => 1
  (hash-table-ref ht 'b (lambda () 42)) => 42
  (hash-table-ref ht 'a #f (lambda (v) (* v 10))) => 10
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

### `hash-table-unfold`

```
Syntax: (hash-table-unfold stop? mapper successor seed comparator)
Library: (srfi 125)
Description: Creates a hash table by repeatedly applying mapper to the seed
to get key-value pairs, and successor to advance the seed, until stop? returns #t.
Example:
  (define ht (hash-table-unfold (lambda (s) (> s 3))
                                (lambda (s) (values s (* s 10)))
                                (lambda (s) (+ s 1))
                                1
                                (make-default-comparator)))
  (hash-table-ref ht 1) => 10
```

### `hash-table-union!`

```
Syntax: (hash-table-union! ht1 ht2)
Library: (srfi 125)
Description: Adds all associations from ht2 to ht1, without overwriting existing keys.
Returns ht1.
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table (make-default-comparator) 'a 99 'b 2))
  (hash-table-union! ht1 ht2)
  (hash-table-ref ht1 'a) => 1
  (hash-table-ref ht1 'b) => 2
```

### `hash-table-update!`

```
Syntax: (hash-table-update! ht key updater [failure [success]])
Library: (srfi 125)
Description: Applies updater to the value associated with key (after applying success
if given). If key is not found, applies updater to the result of calling failure.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-update! ht 'a (lambda (v) (+ v 1)))
  (hash-table-ref ht 'a) => 2
```

### `hash-table-update!/default`

```
Syntax: (hash-table-update!/default ht key updater default)
Library: (srfi 125)
Description: Applies updater to the value associated with key (or default if absent)
and stores the result.
Example:
  (define ht (make-hash-table (make-default-comparator)))
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

### `hash-table-xor!`

```
Syntax: (hash-table-xor! ht1 ht2)
Library: (srfi 125)
Description: Keeps in ht1 only keys that are in exactly one of ht1 or ht2.
Returns ht1.
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2))
  (define ht2 (hash-table (make-default-comparator) 'b 20 'c 3))
  (hash-table-xor! ht1 ht2)
  (hash-table-size ht1) => 2
  (hash-table-contains? ht1 'a) => #t
  (hash-table-contains? ht1 'c) => #t
```

### `hash-table=?`

```
Syntax: (hash-table=? value-comparator ht1 ht2)
Library: (srfi 125)
Description: Returns #t if the two hash tables have the same keys (by their own
comparators) and the same values (by value-comparator).
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table (make-default-comparator) 'a 1))
  (hash-table=? (make-default-comparator) ht1 ht2) => #t
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
Syntax: (make-hash-table comparator)
Library: (srfi 125)
Description: Creates a new empty hash table using the given comparator for key
comparison. The comparator provides the equality predicate and hash function.
Example:
  (define ht (make-hash-table (make-default-comparator)))
  (hash-table-set! ht 'a 1)
  (hash-table-ref ht 'a) => 1
```


# `(scm dict)`

Dictionary / associative map operations

## Exports

### `dict-clear`

```
Syntax: (dict-clear d)
Library: (scm core)
Description: Removes all key-value associations from the dictionary d, leaving it empty.
Example:
  (let ((d (make-dict)))
    (dict-put d "key" 1)
    (dict-clear d)
    (dict-size d)) => 0
```

### `dict-contains`

```
Syntax: (dict-contains d key)
Library: (scm core)
Description: Returns #t if the dictionary d contains an entry for key (a string or symbol), otherwise returns #f.
Example:
  (let ((d (make-dict)))
    (dict-put d "x" 42)
    (dict-contains d "x")) => #t
```

### `dict-entries`

```
Syntax: (dict-entries d)
Library: (scm core)
Description: Returns a list of (key . value) pairs for all entries in the dictionary d.
Example:
  (let ((d (make-dict)))
    (dict-put d "a" 1)
    (dict-entries d)) => (("a" . 1))
```

### `dict-get`

```
Syntax: (dict-get d key) (dict-get d key default)
Library: (scm core)
Description: Returns the value associated with key in the dictionary d. If the key is not found and a default is given, returns it; otherwise raises an error.
Example:
  (let ((d (make-dict)))
    (dict-put d "x" 42)
    (dict-get d "x")) => 42
```

### `dict-keys`

```
Syntax: (dict-keys d)
Library: (scm core)
Description: Returns a list of all keys (as strings) in the dictionary d.
Example:
  (let ((d (make-dict)))
    (dict-put d "a" 1)
    (dict-put d "b" 2)
    (dict-keys d)) => ("a" "b")
```

### `dict-put`

```
Syntax: (dict-put d key value)
Library: (scm core)
Description: Associates key (a string or symbol) with value in the dictionary d. If the key already exists, the old value is replaced.
Example:
  (let ((d (make-dict)))
    (dict-put d "x" 42)
    (dict-get d "x")) => 42
```

### `dict-size`

```
Syntax: (dict-size d)
Library: (scm core)
Description: Returns the number of key-value entries in the dictionary d.
Example:
  (let ((d (make-dict)))
    (dict-put d "a" 1)
    (dict-size d)) => 1
```

### `dict-values`

```
Syntax: (dict-values d)
Library: (scm core)
Description: Returns a list of all values in the dictionary d.
Example:
  (let ((d (make-dict)))
    (dict-put d "a" 1)
    (dict-values d)) => (1)
```

### `make-dict`

```
Syntax: (make-dict)
Library: (scm core)
Description: Returns a new empty mutable dictionary (hash map) with string or symbol keys.
Example:
  (let ((d (make-dict)))
    (dict-put d "key" 42)
    (dict-get d "key")) => 42
```


# `(scheme cxr)`

Compositions of car and cdr up to 4 levels deep

## Exports

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
Library: (scheme cxr)
Description: Equivalent to (car (cdr (cdr pair))). Returns the third element
of a list.
Example:
  (caddr '(1 2 3 4)) => 3
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


# `(srfi 151)`

SRFI-151 — Bitwise operations: logic, shifts, fields, and folds on exact integers

## Exports

### `any-bit-set?`

*(no documentation)*

### `arithmetic-shift`

```
Syntax: (arithmetic-shift i count)
Library: (srfi 151)
Description: Returns i shifted left by count bits if count is positive, or
right by -count bits if count is negative. Right shifts are arithmetic
(sign-preserving).
Example:
  (arithmetic-shift 8 2) => 32
  (arithmetic-shift 32 -2) => 8
  (arithmetic-shift -1 -1) => -1
```

### `bit-count`

```
Syntax: (bit-count i)
Library: (srfi 151)
Description: Returns the population count of i: the number of 1-bits for
non-negative i, or the number of 0-bits for negative i.
Example:
  (bit-count 10) => 2
  (bit-count -11) => 2
  (bit-count 0) => 0
```

### `bit-field`

*(no documentation)*

### `bit-field-any?`

*(no documentation)*

### `bit-field-clear`

*(no documentation)*

### `bit-field-every?`

*(no documentation)*

### `bit-field-replace`

*(no documentation)*

### `bit-field-replace-same`

*(no documentation)*

### `bit-field-reverse`

*(no documentation)*

### `bit-field-rotate`

*(no documentation)*

### `bit-field-set`

*(no documentation)*

### `bit-set?`

*(no documentation)*

### `bit-swap`

*(no documentation)*

### `bits`

*(no documentation)*

### `bits->list`

*(no documentation)*

### `bits->vector`

*(no documentation)*

### `bitwise-and`

```
Syntax: (bitwise-and i ...)
Library: (srfi 151)
Description: Returns the bitwise AND of its arguments. With no arguments,
returns -1 (all bits set).
Example:
  (bitwise-and 14 10) => 10
  (bitwise-and 14 10 12) => 8
  (bitwise-and) => -1
```

### `bitwise-andc1`

*(no documentation)*

### `bitwise-andc2`

*(no documentation)*

### `bitwise-eqv`

*(no documentation)*

### `bitwise-fold`

*(no documentation)*

### `bitwise-for-each`

*(no documentation)*

### `bitwise-if`

*(no documentation)*

### `bitwise-ior`

```
Syntax: (bitwise-ior i ...)
Library: (srfi 151)
Description: Returns the bitwise inclusive OR of its arguments. With no
arguments, returns 0.
Example:
  (bitwise-ior 10 12) => 14
  (bitwise-ior) => 0
```

### `bitwise-nand`

*(no documentation)*

### `bitwise-nor`

*(no documentation)*

### `bitwise-not`

```
Syntax: (bitwise-not i)
Library: (srfi 151)
Description: Returns the bitwise complement of i.
Example:
  (bitwise-not 10) => -11
  (bitwise-not -1) => 0
  (bitwise-not 0) => -1
```

### `bitwise-orc1`

*(no documentation)*

### `bitwise-orc2`

*(no documentation)*

### `bitwise-unfold`

*(no documentation)*

### `bitwise-xor`

```
Syntax: (bitwise-xor i ...)
Library: (srfi 151)
Description: Returns the bitwise exclusive OR of its arguments. With no
arguments, returns 0.
Example:
  (bitwise-xor 10 12) => 6
  (bitwise-xor) => 0
```

### `copy-bit`

*(no documentation)*

### `every-bit-set?`

*(no documentation)*

### `first-set-bit`

*(no documentation)*

### `integer-length`

```
Syntax: (integer-length i)
Library: (srfi 151)
Description: Returns the number of bits needed to represent i, not counting
the sign bit. For non-negative i, this is the index of the highest set bit
plus one. For negative i, it is the number of bits in (bitwise-not i).
Example:
  (integer-length 0) => 0
  (integer-length 1) => 1
  (integer-length 7) => 3
  (integer-length -1) => 0
  (integer-length -8) => 3
```

### `list->bits`

*(no documentation)*

### `make-bitwise-generator`

*(no documentation)*

### `vector->bits`

*(no documentation)*


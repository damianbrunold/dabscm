# `(srfi 14)`

SRFI-14 — Character sets: predicate-wrapped char-set type

## Overview

SRFI-14 provides character sets: a `char-set` type with constructors, the standard
predefined sets, set algebra, and membership testing. Character sets pair naturally
with the predicate-driven operations in SRFI-13.

## Common uses

```scheme
(import (srfi 13) (srfi 14))

(char-set-contains? (char-set #\a #\e #\i #\o #\u) #\e)   ;; => #t
(string-count "banana" (char-set #\a))                    ;; => 3
```

Predefined sets include `char-set:alphabetic`, `char-set:numeric`,
`char-set:whitespace`, etc., and you can combine them with `char-set-union`,
`char-set-intersection`, and `char-set-complement`.


## Exports

### `->char-set`

```
Syntax: (->char-set x)
Library: (srfi 14)
Description: Coerces x to a char-set. If x is already a char-set, returns it. If x is a
string, returns a char-set of its characters. If x is a char, returns a char-set containing
just that character.
Example:
  (char-set-contains? (->char-set "abc") #\b) => #t
  (char-set-contains? (->char-set #\a) #\a) => #t
  (char-set? (->char-set char-set:digit)) => #t

```

### `char-set`

```
Syntax: (char-set char ...)
Library: (srfi 14)
Description: Constructs a char-set containing exactly the given chars.
Example:
  (char-set-contains? (char-set #\a #\b) #\a) => #t
  (char-set-contains? (char-set #\a #\b) #\c) => #f

```

### `char-set->list`

```
Syntax: (char-set->list cs)
Library: (srfi 14)
Description: Returns a list of all characters in cs in ascending code-point order.
Example:
  (char-set->list (char-set #\a #\b #\c)) => (#\a #\b #\c)
  (char-set->list char-set:empty) => ()

```

### `char-set->string`

```
Syntax: (char-set->string cs)
Library: (srfi 14)
Description: Returns a string containing all characters in cs in ascending code-point order.
Example:
  (char-set->string (char-set #\a #\b #\c)) => "abc"
  (string-length (char-set->string char-set:digit)) => 10

```

### `char-set-adjoin`

```
Syntax: (char-set-adjoin cs char ...)
Library: (srfi 14)
Description: Returns a new char-set that contains all characters in cs plus the given chars.
Example:
  (char-set-contains? (char-set-adjoin char-set:digit #\a) #\a) => #t
  (char-set-contains? (char-set-adjoin char-set:digit #\a) #\5) => #t

```

### `char-set-adjoin!`

```
Syntax: (char-set-adjoin cs char ...)
Library: (srfi 14)
Description: Returns a new char-set that contains all characters in cs plus the given chars.
Example:
  (char-set-contains? (char-set-adjoin char-set:digit #\a) #\a) => #t
  (char-set-contains? (char-set-adjoin char-set:digit #\a) #\5) => #t

```

### `char-set-any`

```
Syntax: (char-set-any pred cs)
Library: (srfi 14)
Description: Applies pred to each character in cs. Returns the first true value pred returns,
or #f if pred returns #f for every character.
Example:
  (char-set-any char-upper-case? char-set:letter) => #t
  (char-set-any char-upper-case? char-set:digit) => #f

```

### `char-set-complement`

```
Syntax: (char-set-complement cs)
Library: (srfi 14)
Description: Returns a char-set containing all characters NOT in cs.
Example:
  (char-set-contains? (char-set-complement char-set:digit) #\a) => #t
  (char-set-contains? (char-set-complement char-set:digit) #\5) => #f

```

### `char-set-complement!`

```
Syntax: (char-set-complement cs)
Library: (srfi 14)
Description: Returns a char-set containing all characters NOT in cs.
Example:
  (char-set-contains? (char-set-complement char-set:digit) #\a) => #t
  (char-set-contains? (char-set-complement char-set:digit) #\5) => #f

```

### `char-set-contains?`

```
Syntax: (char-set-contains? cs ch)
Library: (srfi 14)
Description: Returns #t if the character ch is a member of char-set cs, #f otherwise.
Example:
  (char-set-contains? char-set:digit #\5) => #t
  (char-set-contains? char-set:digit #\a) => #f

```

### `char-set-copy`

```
Syntax: (char-set-copy cs)
Library: (srfi 14)
Description: Returns a copy of the char-set cs. In this implementation char-sets are
immutable, so this returns a new char-set with the same membership predicate.
Example:
  (char-set= (char-set-copy (char-set #\a #\b)) (char-set #\a #\b)) => #t

```

### `char-set-count`

```
Syntax: (char-set-count pred cs)
Library: (srfi 14)
Description: Returns the number of characters in cs that satisfy pred.
Example:
  (char-set-count char-upper-case? char-set:letter) => 26
  (char-set-count char-numeric? (char-set #\1 #\a #\2)) => 2

```

### `char-set-cursor`

```
Syntax: (char-set-cursor cs)
Library: (srfi 14)
Description: Returns a cursor for iterating over the characters of cs. In this implementation
a cursor is the list of characters in cs.
Example:
  (let ((cur (char-set-cursor (char-set #\a #\b))))
    (char-set-ref (char-set #\a #\b) cur)) => #\a

```

### `char-set-cursor-next`

```
Syntax: (char-set-cursor-next cs cursor)
Library: (srfi 14)
Description: Advances the cursor to the next character position in cs. Returns the updated
cursor, or an exhausted cursor if there are no more characters.
Example:
  (let* ((cs (char-set #\a #\b))
         (cur (char-set-cursor cs))
         (cur2 (char-set-cursor-next cs cur)))
    (end-of-char-set? cur2)) => #f

```

### `char-set-delete`

```
Syntax: (char-set-delete cs char ...)
Library: (srfi 14)
Description: Returns a new char-set containing all characters in cs except for the given chars.
Example:
  (char-set-contains? (char-set-delete (char-set #\a #\b #\c) #\b) #\a) => #t
  (char-set-contains? (char-set-delete (char-set #\a #\b #\c) #\b) #\b) => #f

```

### `char-set-delete!`

```
Syntax: (char-set-delete cs char ...)
Library: (srfi 14)
Description: Returns a new char-set containing all characters in cs except for the given chars.
Example:
  (char-set-contains? (char-set-delete (char-set #\a #\b #\c) #\b) #\a) => #t
  (char-set-contains? (char-set-delete (char-set #\a #\b #\c) #\b) #\b) => #f

```

### `char-set-diff+intersection`

```
Syntax: (char-set-diff+intersection cs1 cs2 ...)
Library: (srfi 14)
Description: Returns two values: the difference of cs1 and the remaining sets, and the
intersection of cs1 and the remaining sets. Equivalent to calling char-set-difference and
char-set-intersection separately but potentially more efficient.
Example:
  (define-values (d i) (char-set-diff+intersection (char-set #\a #\b #\c) (char-set #\b #\c #\d)))
  (char-set->list d) => (#\a)
  (char-set->list i) => (#\b #\c)

```

### `char-set-diff+intersection!`

```
Syntax: (char-set-diff+intersection cs1 cs2 ...)
Library: (srfi 14)
Description: Returns two values: the difference of cs1 and the remaining sets, and the
intersection of cs1 and the remaining sets. Equivalent to calling char-set-difference and
char-set-intersection separately but potentially more efficient.
Example:
  (define-values (d i) (char-set-diff+intersection (char-set #\a #\b #\c) (char-set #\b #\c #\d)))
  (char-set->list d) => (#\a)
  (char-set->list i) => (#\b #\c)

```

### `char-set-difference`

```
Syntax: (char-set-difference cs cs1 ...)
Library: (srfi 14)
Description: Returns a char-set containing the characters in cs that are not in any of the
remaining sets.
Example:
  (char-set-contains? (char-set-difference (char-set #\a #\b #\c) (char-set #\b)) #\a) => #t
  (char-set-contains? (char-set-difference (char-set #\a #\b #\c) (char-set #\b)) #\b) => #f

```

### `char-set-difference!`

```
Syntax: (char-set-difference cs cs1 ...)
Library: (srfi 14)
Description: Returns a char-set containing the characters in cs that are not in any of the
remaining sets.
Example:
  (char-set-contains? (char-set-difference (char-set #\a #\b #\c) (char-set #\b)) #\a) => #t
  (char-set-contains? (char-set-difference (char-set #\a #\b #\c) (char-set #\b)) #\b) => #f

```

### `char-set-every`

```
Syntax: (char-set-every pred cs)
Library: (srfi 14)
Description: Returns #t if pred returns a true value for every character in cs. Returns #f
as soon as pred returns #f for any character.
Example:
  (char-set-every char-alphabetic? char-set:letter) => #t
  (char-set-every char-upper-case? char-set:letter) => #f

```

### `char-set-filter`

```
Syntax: (char-set-filter pred cs [base-cs])
Library: (srfi 14)
Description: Returns a char-set containing those characters in cs that satisfy pred. If
base-cs is provided, its characters are included unconditionally in the result.
Example:
  (char-set->list (char-set-filter char-upper-case? char-set:letter)) => (#\A ... #\Z)
  (char-set-contains? (char-set-filter odd? (char-set #\a #\b)) #\a) => depends on char code

```

### `char-set-filter!`

```
Syntax: (char-set-filter pred cs [base-cs])
Library: (srfi 14)
Description: Returns a char-set containing those characters in cs that satisfy pred. If
base-cs is provided, its characters are included unconditionally in the result.
Example:
  (char-set->list (char-set-filter char-upper-case? char-set:letter)) => (#\A ... #\Z)
  (char-set-contains? (char-set-filter odd? (char-set #\a #\b)) #\a) => depends on char code

```

### `char-set-fold`

```
Syntax: (char-set-fold kons knil cs)
Library: (srfi 14)
Description: Folds kons over each character in cs, starting with knil. kons is called as
(kons char accumulator) for each character, returning the new accumulator.
Example:
  (char-set-fold (lambda (c acc) (cons c acc)) '() (char-set #\a #\b)) => (#\a #\b) or (#\b #\a)
  (char-set-fold (lambda (c acc) (+ acc 1)) 0 (char-set #\a #\b)) => 2

```

### `char-set-for-each`

```
Syntax: (char-set-for-each proc cs)
Library: (srfi 14)
Description: Applies proc to each character in cs for side effects. The order of iteration
is not specified. Returns an unspecified value.
Example:
  (char-set-for-each display (char-set #\a #\b #\c))

```

### `char-set-hash`

```
Syntax: (char-set-hash cs [bound])
Library: (srfi 14)
Description: Returns a non-negative integer hash of the char-set cs. If bound is given,
the result is in the range [0, bound); otherwise it is in [0, 2^32).
Example:
  (integer? (char-set-hash char-set:digit)) => #t
  (< (char-set-hash char-set:letter 100) 100) => #t

```

### `char-set-intersection`

```
Syntax: (char-set-intersection cs ...)
Library: (srfi 14)
Description: Returns a char-set containing only characters that appear in all of the given sets.
Example:
  (char-set-contains? (char-set-intersection (char-set #\a #\b) (char-set #\b #\c)) #\b) => #t
  (char-set-contains? (char-set-intersection (char-set #\a #\b) (char-set #\b #\c)) #\a) => #f

```

### `char-set-intersection!`

```
Syntax: (char-set-intersection cs ...)
Library: (srfi 14)
Description: Returns a char-set containing only characters that appear in all of the given sets.
Example:
  (char-set-contains? (char-set-intersection (char-set #\a #\b) (char-set #\b #\c)) #\b) => #t
  (char-set-contains? (char-set-intersection (char-set #\a #\b) (char-set #\b #\c)) #\a) => #f

```

### `char-set-map`

```
Syntax: (char-set-map proc cs)
Library: (srfi 14)
Description: Applies proc to each character in cs and returns a new char-set containing the
resulting characters.
Example:
  (char-set-contains? (char-set-map char-upcase char-set:lower-case) #\A) => #t
  (char-set-contains? (char-set-map char-upcase char-set:lower-case) #\a) => #f

```

### `char-set-member?`

```
Syntax: (char-set-contains? cs ch)
Library: (srfi 14)
Description: Returns #t if the character ch is a member of char-set cs, #f otherwise.
Example:
  (char-set-contains? char-set:digit #\5) => #t
  (char-set-contains? char-set:digit #\a) => #f

```

### `char-set-ref`

```
Syntax: (char-set-ref cs cursor)
Library: (srfi 14)
Description: Returns the character at the current position of cursor within cs.
Example:
  (char-set-ref (char-set #\a) (char-set-cursor (char-set #\a))) => #\a

```

### `char-set-size`

```
Syntax: (char-set-size cs)
Library: (srfi 14)
Description: Returns the total number of characters in cs.
Example:
  (char-set-size (char-set #\a #\b #\c)) => 3
  (char-set-size char-set:empty) => 0

```

### `char-set-unfold`

```
Syntax: (char-set-unfold p f g seed [base-cs])
Library: (srfi 14)
Description: Builds a char-set by unfolding from seed. p is the termination predicate
applied to the seed; if true, the result is returned. f maps the seed to a character to
add. g maps the seed to the next seed. If base-cs is provided, its characters are included.
Example:
  (char-set->list (char-set-unfold (lambda (i) (= i 3)) integer->char (lambda (i) (+ i 1)) 0))
    => (#\nul #\x1 #\x2)

```

### `char-set-unfold!`

```
Syntax: (char-set-unfold p f g seed [base-cs])
Library: (srfi 14)
Description: Builds a char-set by unfolding from seed. p is the termination predicate
applied to the seed; if true, the result is returned. f maps the seed to a character to
add. g maps the seed to the next seed. If base-cs is provided, its characters are included.
Example:
  (char-set->list (char-set-unfold (lambda (i) (= i 3)) integer->char (lambda (i) (+ i 1)) 0))
    => (#\nul #\x1 #\x2)

```

### `char-set-union`

```
Syntax: (char-set-union cs ...)
Library: (srfi 14)
Description: Returns a char-set containing all characters that appear in any of the given sets.
Example:
  (char-set-contains? (char-set-union (char-set #\a) (char-set #\b)) #\a) => #t
  (char-set-contains? (char-set-union (char-set #\a) (char-set #\b)) #\b) => #t
  (char-set-contains? (char-set-union (char-set #\a) (char-set #\b)) #\c) => #f

```

### `char-set-union!`

```
Syntax: (char-set-union cs ...)
Library: (srfi 14)
Description: Returns a char-set containing all characters that appear in any of the given sets.
Example:
  (char-set-contains? (char-set-union (char-set #\a) (char-set #\b)) #\a) => #t
  (char-set-contains? (char-set-union (char-set #\a) (char-set #\b)) #\b) => #t
  (char-set-contains? (char-set-union (char-set #\a) (char-set #\b)) #\c) => #f

```

### `char-set-xor`

```
Syntax: (char-set-xor cs ...)
Library: (srfi 14)
Description: Returns the symmetric difference of the given char-sets: characters that appear
in an odd number of the sets (i.e., in one but not both, pairwise applied left to right).
Example:
  (char-set-contains? (char-set-xor (char-set #\a #\b) (char-set #\b #\c)) #\a) => #t
  (char-set-contains? (char-set-xor (char-set #\a #\b) (char-set #\b #\c)) #\b) => #f
  (char-set-contains? (char-set-xor (char-set #\a #\b) (char-set #\b #\c)) #\c) => #t

```

### `char-set-xor!`

```
Syntax: (char-set-xor cs ...)
Library: (srfi 14)
Description: Returns the symmetric difference of the given char-sets: characters that appear
in an odd number of the sets (i.e., in one but not both, pairwise applied left to right).
Example:
  (char-set-contains? (char-set-xor (char-set #\a #\b) (char-set #\b #\c)) #\a) => #t
  (char-set-contains? (char-set-xor (char-set #\a #\b) (char-set #\b #\c)) #\b) => #f
  (char-set-contains? (char-set-xor (char-set #\a #\b) (char-set #\b #\c)) #\c) => #t

```

### `char-set:ascii`

*(no documentation)*

### `char-set:blank`

*(no documentation)*

### `char-set:digit`

*(no documentation)*

### `char-set:empty`

*(no documentation)*

### `char-set:full`

*(no documentation)*

### `char-set:graphic`

*(no documentation)*

### `char-set:hex-digit`

*(no documentation)*

### `char-set:iso-control`

*(no documentation)*

### `char-set:letter`

*(no documentation)*

### `char-set:letter+digit`

*(no documentation)*

### `char-set:lower-case`

*(no documentation)*

### `char-set:printing`

*(no documentation)*

### `char-set:punctuation`

*(no documentation)*

### `char-set:symbol`

*(no documentation)*

### `char-set:title-case`

*(no documentation)*

### `char-set:upper-case`

*(no documentation)*

### `char-set:whitespace`

*(no documentation)*

### `char-set<=`

```
Syntax: (char-set<= cs ...)
Library: (srfi 14)
Description: Returns #t if every char-set is a subset of the next; i.e., every character
in cs1 is also in cs2, every character in cs2 is also in cs3, and so on.
Example:
  (char-set<= (char-set #\a) (char-set #\a #\b)) => #t
  (char-set<= (char-set #\a #\b) (char-set #\a)) => #f

```

### `char-set<=?`

```
Syntax: (char-set<= cs ...)
Library: (srfi 14)
Description: Returns #t if every char-set is a subset of the next; i.e., every character
in cs1 is also in cs2, every character in cs2 is also in cs3, and so on.
Example:
  (char-set<= (char-set #\a) (char-set #\a #\b)) => #t
  (char-set<= (char-set #\a #\b) (char-set #\a)) => #f

```

### `char-set=`

```
Syntax: (char-set= cs ...)
Library: (srfi 14)
Description: Returns #t if all of the given char-sets contain exactly the same characters.
Example:
  (char-set= (char-set #\a #\b) (char-set #\b #\a)) => #t
  (char-set= (char-set #\a) (char-set #\b)) => #f

```

### `char-set=?`

```
Syntax: (char-set= cs ...)
Library: (srfi 14)
Description: Returns #t if all of the given char-sets contain exactly the same characters.
Example:
  (char-set= (char-set #\a #\b) (char-set #\b #\a)) => #t
  (char-set= (char-set #\a) (char-set #\b)) => #f

```

### `char-set?`

*(no documentation)*

### `end-of-char-set?`

```
Syntax: (end-of-char-set? cursor)
Library: (srfi 14)
Description: Returns #t if the cursor is exhausted (there are no more characters to iterate
over), #f otherwise.
Example:
  (end-of-char-set? (char-set-cursor char-set:empty)) => #t
  (end-of-char-set? (char-set-cursor (char-set #\a))) => #f

```

### `list->char-set`

```
Syntax: (list->char-set char-list [base-cs])
Library: (srfi 14)
Description: Creates a char-set from a list of characters. If base-cs is provided, the
characters of base-cs are included in the result as well.
Example:
  (char-set-contains? (list->char-set '(#\a #\b #\c)) #\b) => #t
  (char-set-contains? (list->char-set '(#\a) (char-set #\b)) #\b) => #t

```

### `list->char-set!`

```
Syntax: (list->char-set char-list [base-cs])
Library: (srfi 14)
Description: Creates a char-set from a list of characters. If base-cs is provided, the
characters of base-cs are included in the result as well.
Example:
  (char-set-contains? (list->char-set '(#\a #\b #\c)) #\b) => #t
  (char-set-contains? (list->char-set '(#\a) (char-set #\b)) #\b) => #t

```

### `string->char-set`

```
Syntax: (string->char-set s [base-cs])
Library: (srfi 14)
Description: Creates a char-set containing all characters in string s. If base-cs is
provided, its characters are included in the result as well.
Example:
  (char-set-contains? (string->char-set "hello") #\e) => #t
  (char-set-contains? (string->char-set "abc" (char-set #\d)) #\d) => #t

```

### `string->char-set!`

```
Syntax: (string->char-set s [base-cs])
Library: (srfi 14)
Description: Creates a char-set containing all characters in string s. If base-cs is
provided, its characters are included in the result as well.
Example:
  (char-set-contains? (string->char-set "hello") #\e) => #t
  (char-set-contains? (string->char-set "abc" (char-set #\d)) #\d) => #t

```

### `ucs-range->char-set`

```
Syntax: (ucs-range->char-set lower upper [error? base-cs])
Library: (srfi 14)
Description: Creates a char-set containing characters with Unicode code points in the range
[lower, upper). Code points outside the ASCII range 0-127 are silently clamped. The optional
error? argument is accepted for compatibility but ignored. If base-cs is provided, its
characters are included in the result.
Example:
  (char-set-contains? (ucs-range->char-set 65 91) #\A) => #t
  (char-set-contains? (ucs-range->char-set 65 91) #\a) => #f
  (char-set-size (ucs-range->char-set 48 58)) => 10

```

### `ucs-range->char-set!`

```
Syntax: (ucs-range->char-set lower upper [error? base-cs])
Library: (srfi 14)
Description: Creates a char-set containing characters with Unicode code points in the range
[lower, upper). Code points outside the ASCII range 0-127 are silently clamped. The optional
error? argument is accepted for compatibility but ignored. If base-cs is provided, its
characters are included in the result.
Example:
  (char-set-contains? (ucs-range->char-set 65 91) #\A) => #t
  (char-set-contains? (ucs-range->char-set 65 91) #\a) => #f
  (char-set-size (ucs-range->char-set 48 58)) => 10

```


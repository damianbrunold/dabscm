# `(scheme char)`

Character classification and case operations

## Exports

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

### `char-foldcase`

```
Syntax: (char-foldcase char)
Library: (scheme char)
Description: Returns the case-folded equivalent of char (for case-insensitive comparisons). Applies Unicode full case folding.
Example:
  (char-foldcase #\A) => #\a
  (char-foldcase #\a) => #\a
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

### `digit-value`

```
Syntax: (digit-value char)
Library: (scheme char)
Description: Returns the numeric value (0-9) of a Unicode decimal digit character, or #f if the character is not a decimal digit.
Example:
  (digit-value #\3) => 3
  (digit-value #\a) => #f
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

### `string-ci>?`

```
Syntax: (string-ci>? string1 string2 ...)
Library: (scheme char)
Description: Returns #t if the given strings are in strictly descending lexicographic order when
  compared in a case-insensitive manner, that is, after applying string-downcase to each.
Example:
  (string-ci>? "Banana" "apple") => #t
  (string-ci>? "c" "B" "a") => #t
```

### `string-downcase`

```
Syntax: (string-downcase string [start [end]])
Library: (scheme char) (srfi 13)
Description: Returns a newly allocated string that is the lowercase equivalent of string (or substring
  s[start..end)), using full Unicode case mapping.
Example:
  (string-downcase "Hello World") => "hello world"
  (string-downcase "HELLO" 1 3)   => "el"
```

### `string-foldcase`

```
Syntax: (string-foldcase s)
Library: (scheme char)
Description: Returns a string that is the result of applying Unicode case folding to s, which lowercases the string in a locale-independent manner.
Example:
  (string-foldcase "Hello") => "hello"
  (string-foldcase "SCHEME") => "scheme"
```

### `string-upcase`

```
Syntax: (string-upcase string [start [end]])
Library: (scheme char) (srfi 13)
Description: Returns a newly allocated string that is the uppercase equivalent of string (or substring
  s[start..end)), using full Unicode case mapping (e.g. ß → SS).
Example:
  (string-upcase "hello world") => "HELLO WORLD"
  (string-upcase "ßa") => "SSA"
```


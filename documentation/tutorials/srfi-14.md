---
title: SRFI 14: character sets
part: libraries
order: 14
libraries: (srfi 14)
summary: Building character sets, the predefined sets, set algebra, membership, iterating, and a password-strength checker.
---
# SRFI 14: character sets

A character set is a set of characters with fast membership tests. String
procedures in SRFI 13 accept them wherever they look for characters.

```scheme
(import (scheme base) (scheme char) (srfi 1) (srfi 13) (srfi 14) (srfi 132))
```

## Building sets

```scheme
(define vowels (char-set #\a #\e #\i #\o #\u))
(define hex (string->char-set "0123456789abcdef"))
(define latin (ucs-range->char-set #x41 #x5B))   ; A-Z, end exclusive
(define evens (char-set-filter (lambda (c) (even? (char->integer c))) latin))

(char-set-size vowels)                 ;; => 5
(char-set-contains? hex #\c)           ;; => #t
(char-set-contains? latin #\a)         ;; => #f
(char-set->string evens)               ;; => "BDFHJLNPRTVXZ"
(char-set= (list->char-set '(#\x #\y)) (string->char-set "yx")) ;; => #t
```

Compare character sets with `char-set=`, not `equal?`: they are records
without a readable printed form.

## Predefined sets

| set | contains |
|---|---|
| `char-set:letter` | letters (all scripts) |
| `char-set:digit` | decimal digits |
| `char-set:letter+digit` | both |
| `char-set:whitespace` | space, tab, newline, … |
| `char-set:punctuation` | `. , ; ! ?` and friends |
| `char-set:upper-case`, `char-set:lower-case` | cased letters |
| `char-set:hex-digit` | `0-9 a-f A-F` |
| `char-set:ascii` | code points 0–127 |

```scheme
(char-set-contains? char-set:letter #\λ) ;; => #t
(char-set-contains? char-set:punctuation #\!) ;; => #t
(string-count "a1b2c3" char-set:digit) ;; => 3
```

## Set algebra

```scheme
(define consonants (char-set-difference (ucs-range->char-set 97 123) vowels))
(char-set-size consonants)             ;; => 21
(char-set-size (char-set-union vowels (char-set #\y))) ;; => 6
(char-set->string (char-set-intersection hex vowels)) ;; => "ae"
(char-set-contains? (char-set-complement vowels) #\a) ;; => #f
(char-set<= vowels char-set:letter)    ;; => #t
```

## Iterating

```scheme
(char-set-count char-upper-case? char-set:ascii) ;; => 26
(char-set-fold (lambda (c n) (+ n 1)) 0 vowels) ;; => 5
(list-sort char<? (char-set->list vowels)) ;; => (#\a #\e #\i #\o #\u)
```

The order of `char-set->list` is not specified, so the example sorts it
(`list-sort` is from SRFI 132).

## Using sets with strings

```scheme
(string-tokenize "red, green;blue" char-set:letter) ;; => ("red" "green" "blue")
(string-delete char-set:punctuation "Hello, world!") ;; => "Hello world"
(string-index "abc123" char-set:digit) ;; => 3
(string-trim-both "***note***" (char-set #\*)) ;; => "note"
```

## Example: password strength

Score a password by the kinds of characters it uses:

```scheme
(define classes
  (list char-set:lower-case char-set:upper-case char-set:digit
        (char-set-complement char-set:letter+digit)))

(define (strength pw)
  (let ((kinds (count (lambda (cs) (string-index pw cs)) classes)))
    (cond ((< (string-length pw) 8) 'weak)
          ((>= kinds 3) 'strong)
          (else 'medium))))

(strength "secret")                    ;; => weak
(strength "longpassword")              ;; => medium
(strength "Tr0ub4dor&3")               ;; => strong
```

`string-index` with a set returns the position of the first character of
that class, or `#f`; `count` counts the classes that occur.

## Where next

- [SRFI 13](srfi-13.md), [characters and Unicode](techniques-02-characters.md).
- Reference: `(srfi 14)`.

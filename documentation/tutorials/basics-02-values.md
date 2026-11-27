---
title: Expressions and values
part: basics
order: 2
libraries: (scheme base) (scheme write) (scheme inexact)
summary: Prefix notation, numbers (exact, inexact, rationals, big integers), booleans, symbols, strings, display versus write.
---
# Expressions and values

Scheme has one syntax for everything: a parenthesized list whose first
element says what to do. `(+ 1 2)` calls `+` with 1 and 2. There are no
operator precedence rules to remember, because nesting is always explicit:

```scheme
(import (scheme base) (scheme write) (scheme inexact))

(+ 1 2)                 ;; => 3
(* 2 (+ 3 4))           ;; => 14
(- 10 1 2 3)            ;; => 4
(max 3 9 4)             ;; => 9
```

Most operators take any number of arguments, so `(+ 1 2 3 4)` is fine. This
is ordinary prefix notation: `(f x y)` is what other languages write as
`f(x, y)`.

## Numbers

Scheme distinguishes *exact* numbers (integers and fractions, computed
without rounding) from *inexact* ones (floating point).

```scheme
(/ 1 3)                 ;; => 1/3
(+ 1/3 1/6)             ;; => 1/2
(/ 1.0 3)               ;; => 0.3333333333333333
(inexact 1/4)           ;; => 0.25
(exact 2.5)             ;; => 5/2
(exact? 1/3)            ;; => #t
(inexact? 0.5)          ;; => #t
```

Integers never overflow. They grow as large as you need:

```scheme
(define (factorial n)
  (if (= n 0) 1 (* n (factorial (- n 1)))))

(factorial 25)          ;; => 15511210043330985984000000
(expt 2 100)            ;; => 1267650600228229401496703205376
```

Integer division comes in a few flavours. `quotient` and `remainder`
truncate towards zero; `floor/` returns both results at once, rounding down:

```scheme
(quotient 17 5)         ;; => 3
(remainder 17 5)        ;; => 2
(modulo -7 3)           ;; => 2
(remainder -7 3)        ;; => -1
(call-with-values (lambda () (floor/ 17 5)) list) ;; => (3 2)
(call-with-values (lambda () (exact-integer-sqrt 17)) list) ;; => (4 1)
```

`floor/` and `exact-integer-sqrt` return *two* values (here the square root
4 and the rest 1); `call-with-values` hands them to a procedure, `list` in
this case. The [records](basics-08-records.md) chapter shows `let-values`,
the more readable way to receive several values.

Rounding and conversions:

```scheme
(round 2.5)             ;; => 2.0
(round 3.5)             ;; => 4.0
(round 7/2)             ;; => 4
(floor -2.5)            ;; => -3.0
(exact (round 2.7))     ;; => 3
(number->string 255 16) ;; => "ff"
(string->number "1e3")  ;; => 1000.0
(string->number "abc")  ;; => #f
(sqrt 16)               ;; => 4
(sqrt 2)                ;; => 1.4142135623730951
```

`round` rounds to even on a tie (2.5 becomes 2), as most numerical code
expects. `string->number` returns `#f` for text that is not a number, which
makes it a convenient parser.

## Booleans

There are two booleans, `#t` and `#f`. In a condition, **only `#f` counts as
false**: `0`, the empty list and the empty string are all true.

```scheme
(if 0 'yes 'no)         ;; => yes
(if '() 'yes 'no)       ;; => yes
(if #f 'yes 'no)        ;; => no
(not 3)                 ;; => #f
(and 1 2 3)             ;; => 3
(or #f 'found)          ;; => found
```

`and` returns its last value if all are true, and `or` its first true value.
That is often used for defaults: `(or (lookup key) 'none)`.

## Symbols

A symbol is a name used as data. It is written with a quote, so that it is
not evaluated as a variable:

```scheme
'apple                  ;; => apple
(symbol? 'apple)        ;; => #t
(eq? 'apple 'apple)     ;; => #t
(symbol->string 'apple) ;; => "apple"
(string->symbol "pear") ;; => pear
```

Two symbols with the same name are always the same object, so `eq?`
compares them in one step. Symbols are ideal for things like states,
colours or keys: `'pending`, `'red`, `'name`.

## Characters and strings

Characters are written `#\a`, `#\space`, `#\newline`; strings are in double
quotes. Both get their own tutorials
([strings](techniques-01-strings.md), [characters](techniques-02-characters.md));
here are the basics:

```scheme
(string-length "Scheme")          ;; => 6
(string-ref "Scheme" 0)           ;; => #\S
(string-append "Sch" "eme")       ;; => "Scheme"
(substring "Scheme" 1 3)          ;; => "ch"
(string->list "abc")              ;; => (#\a #\b #\c)
(string=? "abc" "abc")            ;; => #t
(number->string 42)               ;; => "42"
```

## display versus write

`display` prints a value for people, `write` prints it as Scheme would read
it back. The difference shows with strings and characters:

```scheme
(display "a \"quoted\" word")     ;; prints: a "quoted" word
(write "a \"quoted\" word")       ;; prints: "a \"quoted\" word"
(display #\x)                     ;; prints: x
(write #\x)                       ;; prints: #\x
(write '(1 "two" #\3 four))       ;; prints: (1 "two" #\3 four)
```

Use `display` for messages and reports, `write` for debugging output and for
data you want to read back later.

## Equality

Scheme has several equality predicates; pick the one that fits the data:

| predicate | compares | use for |
|---|---|---|
| `=` | numbers by value | numbers |
| `eq?` | identity | symbols, booleans, the empty list |
| `eqv?` | identity, plus numbers and characters by value | numbers and characters of the same exactness |
| `equal?` | structure, recursively | lists, strings, vectors |
| `string=?`, `char=?` | strings / characters | text |

```scheme
(= 2 2.0)                         ;; => #t
(eqv? 2 2.0)                      ;; => #f
(equal? '(1 (2 3)) '(1 (2 3)))    ;; => #t
(eq? "abc" "abc")                 ;; => #f
(equal? "abc" "abc")              ;; => #t
```

When in doubt, use `equal?`.

## Where next

- [Definitions and procedures](basics-03-procedures.md): naming values, writing functions.
- Reference: `(scheme base)` for numbers, `(scheme inexact)` for `sqrt`, `exp`,
  `sin` and friends.

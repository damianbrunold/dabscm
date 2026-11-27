---
title: Characters and Unicode
part: techniques
order: 2
libraries: (scheme base) (scheme char) (srfi 13) (srfi 14)
summary: Characters and code points, character classes, case conversion and folding, character sets, UTF-8 bytes, a slug generator and a simple Caesar cipher.
---
# Characters and Unicode

## Characters and code points

A character is written `#\a`, or by name (`#\space`, `#\newline`, `#\tab`)
or by its Unicode code point in hex (`#\x41`):

```scheme
(import (scheme base) (scheme char) (srfi 13) (srfi 14))

(char->integer #\A)               ;; => 65
(integer->char 97)                ;; => #\a
(char->integer #\€)               ;; => 8364
#\x41                             ;; => #\A
(char->integer #\space)           ;; => 32
(string-length "naïve")           ;; => 5
```

dabscm strings are sequences of Unicode characters: `"naïve"` has five
characters whatever its UTF-8 encoding takes.

## Character classes

```scheme
(char-alphabetic? #\ß)            ;; => #t
(char-numeric? #\7)               ;; => #t
(char-whitespace? #\tab)          ;; => #t
(char-upper-case? #\Ä)            ;; => #t
(digit-value #\7)                 ;; => 7
(digit-value #\x)                 ;; => #f
```

`digit-value` converts a digit character to its number, or returns `#f`,
which makes it a small parser for single digits.

## Case

```scheme
(char-upcase #\é)                 ;; => #\É
(char-downcase #\Ω)               ;; => #\ω
(string-upcase "Straße")          ;; => "STRASSE"
(string-downcase "ÉCOLE")         ;; => "école"
(string-foldcase "Hello")         ;; => "hello"
(string-ci=? "Zürich" "ZÜRICH")   ;; => #t
(char-ci=? #\a #\A)               ;; => #t
```

Use `string-foldcase` (or the `-ci` comparisons) to compare text without
regard to case. `string-upcase` of "ß" gives "SS", so the length of a string
can change with its case.

## Character sets

SRFI 14 character sets describe groups of characters for searching,
trimming and splitting:

```scheme
(define vowels (char-set #\a #\e #\i #\o #\u))
(char-set-contains? vowels #\e)              ;; => #t
(string-count "banana" vowels)               ;; => 3
(string-index "hello world" char-set:whitespace) ;; => 5
(string-tokenize "red, green;blue" char-set:letter) ;; => ("red" "green" "blue")
(string-delete vowels "programming")         ;; => "prgrmmng"
(string-filter char-set:digit "tel: +41 44 123 45 67") ;; => "41441234567"
(string-trim "...hello!!!" (char-set #\.))   ;; => "hello!!!"
```

Sets combine with `char-set-union`, `char-set-intersection`,
`char-set-difference` and `char-set-complement`:

```scheme
(define consonants (char-set-difference char-set:letter vowels
                                        (string->char-set "AEIOU")))
(string-count "Scheme is fun" consonants)    ;; => 7
```

## Text as bytes

Files and networks carry bytes. `string->utf8` and `utf8->string` convert,
and a character outside ASCII takes more than one byte:

```scheme
(string->utf8 "a€")                         ;; => #u8(97 226 130 172)
(bytevector-length (string->utf8 "a€"))     ;; => 4
(utf8->string #u8(240 159 152 128))         ;; => "😀"
```

Characters outside the Basic Multilingual Plane, like most emoji, are where
the implementations differ: native counts `"😀"` as one character, the JVM
and .NET as two (they store strings as UTF-16). Text in European and most
Asian scripts is the same everywhere.

File ports read and write UTF-8 unless you give another encoding, see
[files](techniques-03-files.md).

## Example: URL slugs

Turn a title into a lowercase, hyphen-separated identifier for a URL. Accented
letters lose their accents through a small mapping:

```scheme
(define accents
  '((#\ä . "ae") (#\ö . "oe") (#\ü . "ue") (#\é . "e") (#\è . "e")
    (#\à . "a") (#\ç . "c") (#\ß . "ss")))

(define (deaccent s)
  (apply string-append
         (map (lambda (c)
                (cond ((assv c accents) => cdr)
                      (else (string c))))
              (string->list s))))

(define slug-chars (string->char-set "abcdefghijklmnopqrstuvwxyz0123456789"))

(define (slug title)
  (string-join (string-tokenize (deaccent (string-downcase title)) slug-chars)
               "-"))

(slug "Grüße aus Zürich!")                  ;; => "gruesse-aus-zuerich"
(slug "  The 10 Best Crème Brûlée Recipes ") ;; => "the-10-best-creme-br-lee-recipes"
```

The last one shows the limit of a hand-written mapping: "û" is not in the
table and not in `slug-chars`, so it splits the word. Add the characters your
data contains. (`char-set:lower-case` would not help here: it contains every
Unicode lowercase letter, "û" included.)

## Example: a Caesar cipher

Shift every letter by n places, keeping case and leaving other characters
alone:

```scheme
(define (shift-char c n)
  (define (rotate base)
    (integer->char (+ base (modulo (+ (- (char->integer c) base) n) 26))))
  (cond ((char<=? #\a c #\z) (rotate (char->integer #\a)))
        ((char<=? #\A c #\Z) (rotate (char->integer #\A)))
        (else c)))

(define (caesar text n) (string-map (lambda (c) (shift-char c n)) text))

(caesar "Hello, World!" 3)                  ;; => "Khoor, Zruog!"
(caesar (caesar "Hello, World!" 3) -3)      ;; => "Hello, World!"
(caesar "Attack at dawn" 13)                ;; => "Nggnpx ng qnja"
```

`char<=?` with three arguments checks a range in one call.

## Where next

- [Files and directories](techniques-03-files.md).
- [SRFI 14](srfi-14.md) for all character-set operations, `(scheme char)`.

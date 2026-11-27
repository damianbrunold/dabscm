---
title: SRFI 13: strings
part: libraries
order: 13
libraries: (srfi 13)
summary: The string library: predicates, comparison, searching, trimming and padding, folding, tokenizing, case, and a line wrapper.
---
# SRFI 13: strings

SRFI 13 is the classic string library. Most of its procedures take
optional `start` and `end` arguments that restrict them to part of the
string, and many accept a character, a character set or a predicate where a
"thing to look for" is expected. The [strings](techniques-01-strings.md)
chapter shows the everyday uses; this one goes through the library.

```scheme
(import (scheme base) (scheme char) (srfi 13) (srfi 14))
```

## Predicates and comparison

```scheme
(string-null? "")                       ;; => #t
(string-every char-numeric? "2025")     ;; => #t
(string-any char-whitespace? "no-space") ;; => #f
(if (string= "abc" "abc") 'same 'different)       ;; => same
(if (string< "apple" "banana") 'before 'after)     ;; => before
(if (string-ci= "Zürich" "ZÜRICH") 'same 'different) ;; => same
(string-prefix-length "interstellar" "internet") ;; => 5
(string-compare "abc" "abd" (lambda (i) 'less) (lambda (i) 'equal) (lambda (i) 'greater))
;; => less
```

The comparisons return a true value, not necessarily `#t` (dabscm returns
the index where the comparison was decided), so use them in conditions.
`string-compare` calls one of three procedures with the index where the
strings first differ, which gives a three-way comparison in one pass.

## Searching

The "thing to look for" can be a character, a character set or a
predicate:

```scheme
(define s "Order 4711, shipped 2025-11-27")
(string-index s #\,)                    ;; => 10
(string-index s char-numeric?)          ;; => 6
(string-index s char-set:digit 11)      ;; => 20
(string-index-right s #\-)              ;; => 27
(string-skip s char-alphabetic?)        ;; => 5
(string-contains s "shipped")           ;; => 12
(string-contains-ci s "ORDER")          ;; => 0
(string-count s char-numeric?)          ;; => 12
```

The optional start index (11 above) searches from that position on.

## Taking apart

```scheme
(string-take "dabscm" 3)                ;; => "dab"
(string-drop "dabscm" 3)                ;; => "scm"
(string-take-right "report.pdf" 3)      ;; => "pdf"
(string-drop-right "report.pdf" 4)      ;; => "report"
(string-tokenize "one  two\tthree")     ;; => ("one" "two" "three")
(string-tokenize "a1b22c333" char-set:digit) ;; => ("1" "22" "333")
```

## Trimming and padding

```scheme
(string-trim "  hi  ")                  ;; => "hi  "
(string-trim-right "  hi  ")            ;; => "  hi"
(string-trim-both "  hi  ")             ;; => "hi"
(string-trim-both "--hi--" #\-)         ;; => "hi"
(string-pad "7" 3 #\0)                  ;; => "007"
(string-pad-right "ab" 5 #\.)           ;; => "ab..."
```

## Building and changing

```scheme
(string-join '("2025" "11" "27") "-")   ;; => "2025-11-27"
(string-join '("a" "b") ", " 'suffix)   ;; => "a, b, "
(string-concatenate '("ab" "cd" "ef"))  ;; => "abcdef"
(string-tabulate (lambda (i) (integer->char (+ 65 i))) 5) ;; => "ABCDE"
(string-reverse "stressed")             ;; => "desserts"
(string-replace "Hello, world" "Scheme" 7 12) ;; => "Hello, Scheme"
(string-delete char-whitespace? "a b c") ;; => "abc"
(string-filter char-upper-case? "Hello World") ;; => "HW"
(string-titlecase "hello world")        ;; => "Hello World"
(xsubstring "abc" 0 7)                  ;; => "abcabca"
```

`string-replace` replaces the part between two indexes; `xsubstring`
treats the string as repeating forever, handy for patterns and rulers.

## Folding

`string-fold` walks the characters like `fold` walks a list:

```scheme
(string-fold (lambda (c n) (if (char=? c #\a) (+ n 1) n)) 0 "banana") ;; => 3
(string-fold-right cons '() "abc")      ;; => (#\a #\b #\c)
(string-unfold null? car cdr '(#\h #\i)) ;; => "hi"
```

## Hashing

```scheme
(= (string-hash "key") (string-hash "key"))     ;; => #t
(= (string-hash-ci "Key") (string-hash-ci "KEY")) ;; => #t
(< (string-hash "key" 100) 100)                 ;; => #t
```

## Example: word wrapping

Wrap a paragraph at a given width, breaking only between words:

```scheme
(define (wrap text width)
  (let loop ((words (string-tokenize text)) (line "") (lines '()))
    (cond ((null? words)
           (reverse (if (string-null? line) lines (cons line lines))))
          ((string-null? line) (loop (cdr words) (car words) lines))
          ((<= (+ (string-length line) 1 (string-length (car words))) width)
           (loop (cdr words) (string-append line " " (car words)) lines))
          (else (loop words "" (cons line lines))))))

(wrap "The quick brown fox jumps over the lazy dog" 15)
;; => ("The quick brown" "fox jumps over" "the lazy dog")
```

## Where next

- [SRFI 14](srfi-14.md): character sets, which many SRFI 13 procedures accept.
- [Strings and text](techniques-01-strings.md), reference `(srfi 13)`.

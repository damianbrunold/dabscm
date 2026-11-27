---
title: Strings and text
part: techniques
order: 1
libraries: (scheme base) (scheme char) (srfi 13) (scm string) (scm io) (srfi 48) (scm templating)
summary: Building, searching, splitting, trimming and padding strings; regular expressions; formatting numbers and tables; string ports; templates; a word-frequency counter.
---
# Strings and text

Text processing draws on several libraries:

| library | for |
|---|---|
| `(scheme base)` | creating, comparing, slicing strings |
| `(scheme char)` | case conversion, character classes |
| `(srfi 13)` | searching, trimming, padding, joining, tokenizing |
| `(scm string)` | regular expressions, splitting, replacing |
| `(srfi 48)` / `(scm io)` | `format` and string ports |
| `(scm templating)` | `{{placeholder}}` templates |

```scheme
(import (scheme base) (scheme char) (scheme write)
        (srfi 13) (scm string) (srfi 48) (scm templating)
        (only (scm io) call-with-output-string))
```

## Building strings

```scheme
(string-append "data" "/" "2025" ".csv")   ;; => "data/2025.csv"
(string-join '("a" "b" "c") ", ")          ;; => "a, b, c"
(make-string 5 #\*)                        ;; => "*****"
(string-upcase "zürich")                   ;; => "ZÜRICH"
(string-titlecase "the quick brown fox")   ;; => "The Quick Brown Fox"
(number->string 3.75)                      ;; => "3.75"
(symbol->string 'pending)                  ;; => "pending"
```

Strings are sequences of Unicode characters; `string-length` counts
characters, not bytes.

## Searching

```scheme
(define path "/var/log/app/2025-11-27.log")

(string-prefix? "/var" path)               ;; => #t
(string-suffix? ".log" path)               ;; => #t
(string-contains path "app")               ;; => 9
(string-contains path "db")                ;; => #f
(string-index path #\-)                    ;; => 17
(string-index-right path #\/)              ;; => 12
(substring path 13 (string-length path))   ;; => "2025-11-27.log"
```

`string-contains` and `string-index` return the position of the match, or
`#f`. Together with `substring` that is the classic way to cut out a part,
here the file name after the last slash.

## Splitting and joining

```scheme
(string-split "2025-11-27" "-")            ;; => ("2025" "11" "27")
(string-split "  many   spaces here ")     ;; => ("" "many" "spaces" "here" "")
(string-tokenize "  many   spaces here ")  ;; => ("many" "spaces" "here")
(string-split-char "a,b,,c" #\,)           ;; => ("a" "b" "" "c")
(string-split-lines "one\ntwo\nthree")     ;; => ("one" "two" "three")
(map string->number (string-split "1.5,2,3" ",")) ;; => (1.5 2 3)
```

- `string-split` with a separator splits at that *regular expression*
  (so a dot must be written `"\\."`); without one
  it splits on runs of whitespace (leading and trailing space give empty
  first and last fields);
- `string-tokenize` (SRFI 13) returns only the non-empty words, which is
  usually what you want for free text;
- `string-split-char` keeps empty fields, as CSV-like data needs.

## Trimming and padding

```scheme
(string-trim-both "   padded   ")          ;; => "padded"
(string-trim "   left")                    ;; => "left"
(string-trim-right "right   ")             ;; => "right"
(string-pad "42" 6)                        ;; => "    42"
(string-pad "42" 6 #\0)                    ;; => "000042"
(string-pad-right "Name" 8)                ;; => "Name    "
(string-pad "123456" 4)                    ;; => "3456"
```

`string-pad` pads on the left (right-aligns) and cuts from the left if the
string is too long; `string-pad-right` left-aligns.

## Replacing

```scheme
(string-replace-all "a.b.c" "." "/")                    ;; => "a/b/c"
(string-replace-all-regex "call 555-1234 or 555-9876" "[0-9]{3}-[0-9]{4}" "XXX-XXXX")
;; => "call XXX-XXXX or XXX-XXXX"
```

`string-replace-all` replaces literal text (a `.` is a dot);
`string-replace-all-regex` takes a regular expression.

## Regular expressions

`string-matches` returns the whole match and the groups, or `#f`:

```scheme
(string-matches "2025-11-27" "([0-9]{4})-([0-9]{2})-([0-9]{2})")
;; => ("2025-11-27" "2025" "11" "27")

(define (parse-date s)
  (let ((m (string-matches s "([0-9]{4})-([0-9]{2})-([0-9]{2})")))
    (and m (map string->number (cdr m)))))

(parse-date "2025-11-27")                  ;; => (2025 11 27)
(parse-date "27.11.2025")                  ;; => #f
```

`string-matches` finds the first match anywhere in the string; anchor the
pattern with `^` and `$` when the whole string must match. To get the
*positions* of a match, use `regex-search`. It returns a vector of `(start . end)`
positions, for the whole match and each group, or `#f`:

```scheme
(define order "Order #4711 shipped")
(define m (regex-search order "#([0-9]+)"))
m                                          ;; => #((6 . 11) (7 . 11))
(let ((group (vector-ref m 1)))
  (substring order (car group) (cdr group))) ;; => "4711"
(regex-search order "[A-Z]{3}")            ;; => #f
```

dabscm accepts the regular-expression syntax that Java and .NET have in
common, so a pattern means the same everywhere.

## Formatting values

`format` (SRFI 48) fills a template; `#f` as the first argument returns a
string:

```scheme
(format #f "~a items, total ~a" 3 21.7)     ;; => "3 items, total 21.7"
(format #f "~s" "quoted")                   ;; => "\"quoted\""
(format #f "hex ~x, binary ~b" 255 5)       ;; => "hex ff, binary 101"
```

For money and other fixed decimals, round with exact arithmetic and pad:

```scheme
(define (fixed x places)
  (let* ((factor (expt 10 places))
         (n (exact (round (* (abs x) factor))))
         (whole (quotient n factor))
         (frac (remainder n factor)))
    (string-append (if (< x 0) "-" "")
                   (number->string whole)
                   "."
                   (string-pad (number->string frac) places #\0))))

(fixed 3.14159 2)                           ;; => "3.14"
(fixed 2.5 2)                               ;; => "2.50"
(fixed -0.125 2)                            ;; => "-0.12"
(fixed 1081/10 2)                           ;; => "108.10"
```

### A text table

Padding gives aligned columns for reports in a terminal or a log:

```scheme
(define rows '(("apples" 3 1.5) ("bread" 1 3.2) ("cheese" 2 13.8)))

(define (row->line row)
  (string-append (string-pad-right (car row) 10)
                 (string-pad (number->string (cadr row)) 4)
                 (string-pad (fixed (caddr row) 2) 9)))

(for-each (lambda (r) (display (row->line r)) (newline)) rows)
;; prints: apples       3     1.50
;; prints: bread        1     3.20
;; prints: cheese       2    13.80
```

## String ports

A string port collects output; `call-with-output-string` gives you one and
returns what was written. That is the efficient way to build a long string
piece by piece:

```scheme
(call-with-output-string
  (lambda (out)
    (for-each (lambda (n) (write n out) (display " " out)) '(1 2 3))))
;; => "1 2 3 "

(define in (open-input-string "first line\nsecond line\n"))
(read-line in)                              ;; => "first line"
(read-line in)                              ;; => "second line"
(eof-object? (read-line in))                ;; => #t
```

`open-input-string` turns a string into an input port, so code written for
files also works on strings, which is handy in tests.

## Templates

`(scm templating)` replaces `{{name}}` placeholders from an alist:

```scheme
(template-render "Dear {{name}}, your order {{id}} has shipped."
                 '(("name" . "Ada") ("id" . "4711")))
;; => "Dear Ada, your order 4711 has shipped."
```

## Example: word frequencies

Count the words of a text, case-insensitively, and list the most common
ones. A hash table does the counting (see
[hash tables](techniques-04-hash-tables.md)):

```scheme
(import (srfi 14) (only (srfi 69) make-hash-table hash-table-update!/default hash-table->alist) (srfi 132))

(define text
  "The cat sat on the mat. The dog sat on the log. A cat and a dog.")

(define (words s)
  (string-tokenize (string-downcase s) char-set:letter))

(define (frequencies ws)
  (let ((t (make-hash-table string=? string-hash)))
    (for-each (lambda (w) (hash-table-update!/default t w (lambda (n) (+ n 1)) 0))
              ws)
    (hash-table->alist t)))

(define (top n counts)
  (let ((sorted (list-sort (lambda (a b)
                             (or (> (cdr a) (cdr b))
                                 (and (= (cdr a) (cdr b)) (string<? (car a) (car b)))))
                           counts)))
    (if (> (length sorted) n) (list-head sorted n) sorted)))

(define (list-head l n) (if (= n 0) '() (cons (car l) (list-head (cdr l) (- n 1)))))

(length (words text))                       ;; => 17
(top 4 (frequencies (words text)))
;; => (("the" . 4) ("a" . 2) ("cat" . 2) ("dog" . 2))
```

`string-tokenize` with `char-set:letter` (SRFI 14) treats everything that
is not a letter as a separator, so punctuation disappears. Ties are sorted
alphabetically, so the result does not depend on the hash table's order.

## Where next

- [Characters and Unicode](techniques-02-characters.md).
- [SRFI 13](srfi-13.md), [`(scm string)`](scm-string.md), [`(scm text)`](scm-text.md)
  for awk/grep/sed-style processing of whole files.

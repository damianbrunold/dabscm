---
title: (scm string): regular expressions and splitting
part: libraries
order: 1001
libraries: (scm string)
summary: Regular-expression matching, searching and replacing with groups, splitting on patterns, lines, literal replace-all, fast substring search; a log-line parser and a date reformatter.
---
# (scm string): regular expressions and splitting

`(scm string)` adds what SRFI 13 lacks: regular expressions, splitting and
literal replacement. Patterns use the regular-expression syntax that Java
and .NET have in common, so a pattern means the same on every
implementation.

```scheme
(import (scheme base) (scheme cxr) (scm string))
```

## Matching

`string-matches` finds the first match of the pattern and returns it with
its groups, as strings, or `#f`:

```scheme
(string-matches "abc123" "([a-z]+)([0-9]+)")  ;; => ("abc123" "abc" "123")
(string-matches "xx abc123 yy" "([a-z]+)([0-9]+)") ;; => ("abc123" "abc" "123")
(string-matches "2025-11-27" "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") ;; => ("2025-11-27")
(string-matches "2025-11-27!" "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") ;; => #f
(string-matches "ab" "(a)(x)?b")              ;; => ("ab" "a" #f)
```

The match may be anywhere in the string; anchor the pattern with `^` and
`$` to require the whole string to match, as a validation needs. A group
that does not take part in the match gives `#f`.

## Searching inside a string

`regex-search` finds the first match anywhere and returns the positions of
the match and of each group as `(start . end)` pairs:

```scheme
(define line "2025-11-27 14:03:12 ERROR db: connection refused")
(define m (regex-search line "([A-Z]+) ([a-z]+):"))
m                                             ;; => #((20 . 29) (20 . 25) (26 . 28))
```

The whole match is characters 20 to 29 (`ERROR db:`), the groups `ERROR`
and `db`. A small helper takes them apart:

```scheme
(define (group s m i)
  (let ((g (vector-ref m i))) (and g (substring s (car g) (cdr g)))))
(group line m 1)                              ;; => "ERROR"
(group line m 2)                              ;; => "db"
(regex-search line "WARN")                    ;; => #f
(vector-ref (regex-search "a1b2c3" "[0-9]" 2) 0) ;; => (3 . 4)
```

The optional third argument starts the search at a position, which is how
you find all matches in turn:

```scheme
(define (all-matches s pattern)
  (let loop ((start 0) (acc '()))
    (let ((m (and (<= start (string-length s)) (regex-search s pattern start))))
      (if (not m)
          (reverse acc)
          (let ((g (vector-ref m 0)))
            (loop (max (cdr g) (+ (car g) 1))
                  (cons (substring s (car g) (cdr g)) acc)))))))

(all-matches "call 555-1234 or 555-9876 now" "[0-9]{3}-[0-9]{4}")
;; => ("555-1234" "555-9876")
```

## Replacing

```scheme
(string-replace-all "a.b.c" "." "/")                   ;; => "a/b/c"
(string-replace-all-regex "a.b.c" "\\." "/")           ;; => "a/b/c"
(string-replace-all-regex "2024-01-31" "([0-9]+)-([0-9]+)-([0-9]+)" "~3.~2.~1")
;; => "31.01.2024"
(string-replace-all-regex "  too   many  spaces " " +" " ") ;; => " too many spaces "
```

`string-replace-all` replaces literal text; `string-replace-all-regex`
takes a pattern, and `~1`, `~2` … in the replacement insert the groups
(`~0` the whole match, `~~` a tilde).

In a Scheme string a backslash must be doubled, so the regular expression
`\.` (a literal dot) is written `"\\."`.

## Splitting

`string-split` splits at a regular expression (whitespace by default):

```scheme
(string-split "a b  c")                       ;; => ("a" "b" "c")
(string-split "a,b;c" "[,;]")                 ;; => ("a" "b" "c")
(string-split "1.5.2" "\\.")                  ;; => ("1" "5" "2")
(string-split-vector "x y")                   ;; => #("x" "y")
(string-split-char "a,,b" #\,)                ;; => ("a" "" "b")
(string-split-lines "one\r\ntwo\n")           ;; => ("one" "two" "")
```

Because the separator is a pattern, a dot must be escaped (`"\\."`);
`string-split-char` splits at a single character literally and keeps empty
fields. `string-split-lines` also removes the carriage return of Windows
line endings.

## Fast literal search

```scheme
(string-contains-from "abcabc" "bc" 2)        ;; => 4
(symbol-starts-with? 'http-get "http")        ;; => #t
```

`string-contains-from` searches from a position without allocating, which
is what hand-written parsers need.

## Example: parsing log lines

Turn log lines into records with one pattern:

```scheme
(define log-lines
  '("2025-11-27 14:03:12 ERROR db: connection refused"
    "2025-11-27 14:03:15 INFO web: request /home 200"
    "garbage line"
    "2025-11-27 14:04:01 WARN db: slow query 2.3s"))

(define (parse-log-line l)
  (let ((m (string-matches l "([0-9-]+) ([0-9:]+) ([A-Z]+) ([a-z]+): (.*)")))
    (and m (cdr m))))

(define (filter-map* f xs)
  (let loop ((xs xs) (acc '()))
    (cond ((null? xs) (reverse acc))
          ((f (car xs)) => (lambda (v) (loop (cdr xs) (cons v acc))))
          (else (loop (cdr xs) acc)))))

(define entries (filter-map* parse-log-line log-lines))
(length entries)                              ;; => 3
(map caddr entries)                           ;; => ("ERROR" "INFO" "WARN")
(map (lambda (e) (list-ref e 3)) entries)     ;; => ("db" "web" "db")
```

Lines that do not match give `#f` and are dropped.

## Where next

- [Strings and text](techniques-01-strings.md), [SRFI 13](srfi-13.md).
- [`(scm text)`](scm-text.md) for grep and sed on whole files.
- Reference: `(scm string)`.

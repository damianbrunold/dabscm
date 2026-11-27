---
title: SRFI 28 and 48: format
part: libraries
order: 28
libraries: (srfi 28) (srfi 48)
summary: format strings, destinations, display versus write directives, numbers in other bases, widths, and a receipt printer.
---
# SRFI 28 and 48: format

`format` fills a template with values. SRFI 28 is the basic version, SRFI 48
adds a destination argument and more directives; dabscm uses the same
`format` for both, and `(scm io)` exports it too.

```scheme
(import (scheme base) (scheme write) (srfi 48))
```

## Destinations

The first argument says where the result goes:

| destination | result |
|---|---|
| `#f` | returned as a string |
| `#t` | written to the current output port |
| a port | written to that port |

```scheme
(format #f "~a + ~a = ~a" 1 2 3)          ;; => "1 + 2 = 3"
(format #t "Hello, ~a!" "world")          ;; prints: Hello, world!
(let ((p (open-output-string)))
  (format p "~a items" 3)
  (get-output-string p))                  ;; => "3 items"
```

SRFI 28's `format` has no destination: `(format "~a" x)` always returns a
string.

## Directives

```scheme
(format #f "~a" "text")                   ;; => "text"
(format #f "~s" "text")                   ;; => "\"text\""
(format #f "~a and ~s" #\x #\x)           ;; => "x and #\\x"
(format #f "line one~%line two")          ;; => "line one\nline two"
(format #f "100~~")                       ;; => "100~"
(format #f "~a" '(1 "two" three))         ;; => "(1 two three)"
(format #f "~s" '(1 "two" three))         ;; => "(1 \"two\" three)"
```

- `~a` displays the value (as `display` would), `~s` writes it (as
  `write` would, with quotes);
- `~%` is a newline and `~~` a tilde.

## Numbers

```scheme
(format #f "~d" 42)                       ;; => "42"
(format #f "~x" 255)                      ;; => "ff"
(format #f "~o" 8)                        ;; => "10"
(format #f "~b" 10)                       ;; => "1010"
(format #f "~8,3f" 3.14159)               ;; => "   3.142"
(format #f "~,2f" 2.5)                    ;; => "2.50"
```

`~w,df` formats a number with `d` decimals in a field `w` wide, which is
what reports need.

## Example: a receipt

```scheme
(define items '(("Coffee" 2 4.5) ("Croissant" 1 3.2) ("Orange juice" 1 5.8)))

(define (receipt items)
  (for-each (lambda (i)
              (format #t "~a~a ~8,2f~%"
                      (car i)
                      (make-string (- 16 (string-length (car i))) #\.)
                      (* (cadr i) (caddr i))))
            items)
  (format #t "~a ~8,2f" (make-string 16 #\=)
          (apply + (map (lambda (i) (* (cadr i) (caddr i))) items))))

(receipt items)
;; prints: Coffee..........     9.00
;; prints: Croissant.......     3.20
;; prints: Orange juice....     5.80
;; prints: ================    18.00
```

## Where next

- [Strings and text](techniques-01-strings.md) for padding and templates.
- Reference: `(srfi 28)`, `(srfi 48)`, `(scm io)`.

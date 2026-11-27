---
title: Vectors, bytevectors and other data
part: basics
order: 6
libraries: (scheme base) (scheme char) (srfi 133)
summary: Vectors for indexed access, bytevectors for binary data, characters and strings in brief, choosing the right structure.
---
# Vectors, bytevectors and other data

## Vectors

A vector is a fixed-size array: access by index takes constant time,
whatever the size. Vectors are written `#(...)`:

```scheme
(import (scheme base) (scheme char)
        (only (srfi 133) vector-fold vector-index vector-count))

(define v (vector 'a 'b 'c))
(vector-ref v 1)                  ;; => b
(vector-length v)                 ;; => 3
(vector-set! v 1 'beta)
v                                 ;; => #(a beta c)
(make-vector 3 0)                 ;; => #(0 0 0)
(vector->list #(1 2 3))           ;; => (1 2 3)
(list->vector '(1 2 3))           ;; => #(1 2 3)
(vector-map (lambda (x) (* x x)) #(1 2 3)) ;; => #(1 4 9)
(define w (make-vector 2 0))
(vector-fill! w 'x)
w                                 ;; => #(x x)
```

A vector literal like `#(1 2 3)` is a constant; use `vector` or
`make-vector` for one you want to change.

### Example: a histogram

Count dice rolls by face. A vector indexed by the face value is the natural
counter:

```scheme
(define rolls '(3 6 1 6 2 6 5 3 1 4 6 2))

(define (histogram values size)
  (let ((counts (make-vector size 0)))
    (for-each (lambda (x)
                (vector-set! counts x (+ 1 (vector-ref counts x))))
              values)
    counts))

(histogram rolls 7)               ;; => #(0 2 2 2 1 1 4)
```

Face 6 came up four times. `(srfi 133)` adds many vector operations; here
`vector-index` finds the most frequent face:

```scheme
(define counts (histogram rolls 7))
(define top (vector-fold (lambda (m x) (max m x)) 0 counts))
(vector-index (lambda (x) (= x top)) counts) ;; => 6
(vector-count even? counts)       ;; => 5
```

## Bytevectors

A bytevector holds bytes (0 to 255): file contents, network messages,
images. It is written `#u8(...)`:

```scheme
(define header (bytevector 137 80 78 71))
(bytevector-u8-ref header 1)      ;; => 80
(bytevector-length header)        ;; => 4
(utf8->string (bytevector 72 105)) ;; => "Hi"
(string->utf8 "é")                ;; => #u8(195 169)
(bytevector-append #u8(1 2) #u8(3)) ;; => #u8(1 2 3)
```

`string->utf8` and `utf8->string` convert between text and its UTF-8
bytes; "é" takes two bytes. The first bytes of every PNG file are
`137 80 78 71` ("\x89PNG"), so that is how a program recognizes one.
[Files](techniques-03-files.md) shows reading and writing binary files.

## Characters and strings in brief

```scheme
(char->integer #\A)               ;; => 65
(integer->char 955)               ;; => #\λ
(string #\a #\b)                  ;; => "ab"
(make-string 3 #\-)               ;; => "---"
(string-copy "hello" 1 3)         ;; => "el"
(string-map char-upcase "shout")  ;; => "SHOUT"
```

The [strings](techniques-01-strings.md) and
[characters](techniques-02-characters.md) tutorials go into depth.

## Choosing a structure

| need | use |
|---|---|
| a sequence you build and walk from the start | list |
| access by position, fixed size | vector |
| bytes | bytevector |
| lookup by key, few entries | association list |
| lookup by key, many entries | [hash table](techniques-04-hash-tables.md) |
| a named group of fields | [record](basics-08-records.md) |
| a single mutable cell | box (`(srfi 111)`) |

## Where next

- [Higher-order programming](basics-07-higher-order.md).
- Reference: `(scheme base)`, `(srfi 133)` (vectors), `(scm bytevector)`
  (multi-byte integers and floats in bytevectors).

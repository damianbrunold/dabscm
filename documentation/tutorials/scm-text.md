---
title: (scm text): Unix text tools in Scheme
part: libraries
order: 1005
libraries: (scm text)
summary: grep, sed, awk, cut, sort-lines, uniq, head, tail, wc, tr, diff, cat, tee and hexdump on lists of lines, files and ports; a log report as a pipeline.
---
# (scm text): Unix text tools in Scheme

`(scm text)` brings the classic Unix text tools to Scheme. Each takes a
*source*: a file name, a list of lines or an input port, and returns lines
(or a number or string), so the tools compose like a shell pipeline.

When the native tool is on the `PATH` and the source is a file, some of
them run it for speed; the option `'pure` forces the Scheme
implementation, which behaves the same on every platform. The examples use
lists of lines and `'pure` where it matters.

```scheme
(import (scheme base) (scheme char) (scheme write) (scm text))

(define log
  '("09:12 INFO  web  GET /home 200 12ms"
    "09:13 ERROR db   connection refused"
    "09:15 INFO  web  GET /shop 200 40ms"
    "09:15 WARN  web  GET /shop 404 3ms"
    "09:20 ERROR db   connection refused"
    "09:21 INFO  web  POST /cart 201 55ms"))
```

## Selecting lines

```scheme
(grep "ERROR" log 'pure)                    ;; => ("09:13 ERROR db   connection refused" "09:20 ERROR db   connection refused")
(grep "error" log 'ignore-case 'count 'pure) ;; => 2
(length (grep "INFO" log 'invert-match 'pure)) ;; => 3
(map car (grep "WARN" log 'line-number 'pure)) ;; => (4)
(head log '(lines . 2))                     ;; => ("09:12 INFO  web  GET /home 200 12ms" "09:13 ERROR db   connection refused")
(tail log '(lines . 1))                     ;; => ("09:21 INFO  web  POST /cart 201 55ms")
```

## Fields: awk and cut

`awk` splits each line into fields and calls a procedure with the fields,
the line number and the line; results that are `#f` are dropped:

```scheme
(awk (lambda (fields n line) (and (string=? (list-ref fields 2) "web") (list-ref fields 5)))
     log)                                   ;; => ("200" "200" "404" "201")

(awk (lambda (fields n line) (list-ref fields 0))
     log
     `(filter . ,(lambda (fields n line) (string=? (list-ref fields 1) "ERROR"))))
;; => ("09:13" "09:20")

(cut '("a:b:c" "d:e:f") '(fields . (1 3)) '(delimiter . ":")) ;; => ("a:c" "d:f")
```

## Sorting, counting, transforming

```scheme
(sort-lines '("pear" "apple" "fig"))        ;; => ("apple" "fig" "pear")
(sort-lines '("10" "9" "100") 'numeric)     ;; => ("9" "10" "100")
(sort-lines '("b" "a" "b") 'unique)         ;; => ("a" "b")
(uniq '("a" "a" "b" "a"))                   ;; => ("a" "b" "a")
(wc log)                                    ;; => ((lines . 6) (words . 50) (chars . 216))
(wc log 'lines-only)                        ;; => 6
((tr "abc" "xyz") "banana")                 ;; => "yxnxnx"
((tr "aeiou" "" 'delete) "banana")          ;; => "bnn"
(sed "refused" "reset" (grep "ERROR" log 'pure) 'pure)
;; => ("09:13 ERROR db   connection reset" "09:20 ERROR db   connection reset")
```

`tr` returns a procedure, which can be mapped over lines.

## Comparing: diff

```scheme
(diff '("a" "b" "c") '("a" "b" "c") 'brief 'pure)  ;; => #t
(diff '("a" "b" "c") '("a" "x" "c") 'brief 'pure)  ;; => #f
(display (diff '("a" "b" "c") '("a" "x" "c") 'pure '(label-a . "old") '(label-b . "new")))
;; prints: --- old
;; prints: +++ new
;; prints: @@ -1,3 +1,3 @@
;; prints:  a
;; prints: -b
;; prints: +x
;; prints:  c
```

The result is a unified diff as `diff -u` prints it.

## Bytes: hexdump

```scheme
(display (hexdump (string->utf8 "Hello, dabscm!")))
;; prints: 00000000  48 65 6c 6c 6f 2c 20 64 61 62 73 63 6d 21       |Hello, dabscm!|
```

## Example: a status report

Count requests per status code with a small pipeline:

```scheme
(define (status-counts lines)
  (let* ((codes (awk (lambda (f n l) (and (>= (length f) 6) (string=? (list-ref f 2) "web")
                                          (list-ref f 5)))
                     lines))
         (sorted (sort-lines codes)))
    (let loop ((xs sorted) (acc '()))
      (if (null? xs)
          (reverse acc)
          (let ((same (let count ((ys xs) (n 0))
                        (if (and (pair? ys) (string=? (car ys) (car xs))) (count (cdr ys) (+ n 1)) n))))
            (loop (list-tail xs same) (cons (cons (car xs) same) acc)))))))

(status-counts log)                         ;; => (("200" . 2) ("201" . 1) ("404" . 1))
```

## Where next

- [`(scm string)`](scm-string.md) for regular expressions, [files](techniques-03-files.md).
- Reference: `(scm text)`.

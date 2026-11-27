---
title: Records
part: basics
order: 8
libraries: (scheme base) (srfi 1) (srfi 132)
summary: define-record-type, constructors, predicates and accessors, immutable updates, multiple return values, records as objects.
---
# Records

Lists are flexible, but `(caddr item)` says nothing about what it is. A
*record type* gives data named fields:

```scheme
(import (scheme base) (srfi 1) (srfi 132))

(define-record-type book
  (make-book title author year pages)
  book?
  (title book-title)
  (author book-author)
  (year book-year)
  (pages book-pages set-book-pages!))

(define dune (make-book "Dune" "Frank Herbert" 1965 412))

(book-title dune)                 ;; => "Dune"
(book? dune)                      ;; => #t
(book? "Dune")                    ;; => #f
(set-book-pages! dune 896)
(book-pages dune)                 ;; => 896
```

`define-record-type` defines, in order:

1. the type name (`book`);
2. the constructor and the fields it takes (`make-book`);
3. a predicate (`book?`);
4. one entry per field: its accessor and, optionally, a modifier
   (`set-book-pages!`).

Fields without a modifier cannot be changed, which is usually what you want.

## Working with collections of records

```scheme
(define library
  (list (make-book "Dune" "Frank Herbert" 1965 412)
        (make-book "Neuromancer" "William Gibson" 1984 271)
        (make-book "Solaris" "Stanisław Lem" 1961 204)
        (make-book "Hyperion" "Dan Simmons" 1989 482)))

(map book-title (filter (lambda (b) (< (book-year b) 1970)) library))
;; => ("Dune" "Solaris")

(map book-title (list-sort (lambda (a b) (< (book-pages a) (book-pages b)))
                           library))
;; => ("Solaris" "Neuromancer" "Dune" "Hyperion")

(fold + 0 (map book-pages library)) ;; => 1369
```

`list-sort` (SRFI 132) takes a "less than" procedure; here it compares page
counts. [Sorting and searching](techniques-05-sorting.md) shows more.

## Updating without mutation

Instead of modifiers, functional code makes a changed copy:

```scheme
(define (book-with-year b year)
  (make-book (book-title b) (book-author b) year (book-pages b)))

(define dune-2021 (book-with-year dune 2021))
(book-year dune-2021)             ;; => 2021
(book-year dune)                  ;; => 1965
```

The old value stays valid, which makes such data safe to share, for example
between threads.

## Returning several values

A procedure can return several values with `values`; `let-values`
receives them:

```scheme
(define (oldest-and-newest books)
  (let ((sorted (list-sort (lambda (a b) (< (book-year a) (book-year b))) books)))
    (values (first sorted) (last sorted))))

(let-values (((old new) (oldest-and-newest library)))
  (list (book-title old) (book-title new)))
;; => ("Solaris" "Hyperion")
```

That is lighter than building a list or a record just to return two things.

## Records as objects

A record with a procedure in a field, or a closure over a record, gives you
objects with behaviour. Here is a bank account whose balance cannot be
changed from outside:

```scheme
(define-record-type account
  (%make-account owner balance)
  account?
  (owner account-owner)
  (balance account-balance %set-balance!))

(define (make-account owner) (%make-account owner 0))

(define (deposit! acc amount)
  (unless (> amount 0) (error "deposit: amount must be positive" amount))
  (%set-balance! acc (+ (account-balance acc) amount)))

(define (withdraw! acc amount)
  (when (> amount (account-balance acc))
    (error "withdraw: insufficient funds" (account-balance acc)))
  (%set-balance! acc (- (account-balance acc) amount)))

(define acc (make-account "Grace"))
(deposit! acc 100)
(withdraw! acc 30)
(account-balance acc)             ;; => 70
(withdraw! acc 500)               ;; => error
```

The `%` prefix is a common convention for "internal, do not use". In a
library you would simply not export `%make-account` and `%set-balance!`
(see [libraries and programs](basics-10-libraries.md)).

## Printing records

`write` shows a record only as `#<record>`. When you need to see the fields
while debugging, give the type a small procedure that turns it into a list:

```scheme
(define (book->list b)
  (list 'book (book-title b) (book-author b) (book-year b)))

(book->list dune)                 ;; => (book "Dune" "Frank Herbert" 1965)
```

## Where next

- [Errors and exceptions](basics-09-errors.md): what `error` really does.
- Reference: `(scheme base)` for `define-record-type`, `(srfi 132)` for sorting.

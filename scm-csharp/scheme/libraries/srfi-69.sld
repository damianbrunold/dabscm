(define-library (srfi 69)
  (import (scheme base) (scheme char))
  (export make-hash-table
          hash-table?
          hash-table-set!
          hash-table-ref
          hash-table-ref/default
          hash-table-delete!
          hash-table-exists?
          hash-table-size
          hash-table-keys
          hash-table-values
          hash-table->alist
          hash-table-copy
          hash-table-walk
          hash-table-fold
          hash-table-merge!
          hash-table-update!
          hash-table-update!/default
          hash-table/get
          hash-table/put!
          hash-table/remove!
          hash
          string-hash
          string-ci-hash
          hash-by-identity)
  (begin
    (define make-hash-table (%primitive "make-hash-table"))
    (define hash-table? (%primitive "hash-table?"))
    (define hash-table-set! (%primitive "hash-table-set!"))
    (define hash-table-ref (%primitive "hash-table-ref"))
    (define hash-table-ref/default (%primitive "hash-table-ref/default"))
    (define hash-table-delete! (%primitive "hash-table-delete!"))
    (define hash-table-exists? (%primitive "hash-table-exists?"))
    (define hash-table-size (%primitive "hash-table-size"))
    (define hash-table-keys (%primitive "hash-table-keys"))
    (define hash-table-values (%primitive "hash-table-values"))
    (define hash-table->alist (%primitive "hash-table->alist"))
    (define hash-table-copy (%primitive "hash-table-copy"))

    (define (hash-table-walk ht proc)
      "Syntax: (hash-table-walk ht proc)
Library: (srfi 69)
Description: Calls proc with each key and value in the hash table ht for side effects.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-walk ht (lambda (k v) (display k) (display v)))"
      (for-each (lambda (pair) (proc (car pair) (cdr pair)))
                (hash-table->alist ht)))

    (define (hash-table-fold ht f init)
      "Syntax: (hash-table-fold ht f init)
Library: (srfi 69)
Description: Folds f over all key-value associations in ht, starting from init.
f receives (key value accumulator) and returns the new accumulator.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'a 1)
  (hash-table-fold ht (lambda (k v acc) (+ v acc)) 0) => 1"
      (let loop ((alist (hash-table->alist ht)) (acc init))
        (if (null? alist)
            acc
            (loop (cdr alist)
                  (f (caar alist) (cdar alist) acc)))))

    (define (hash-table-merge! ht1 ht2)
      "Syntax: (hash-table-merge! ht1 ht2)
Library: (srfi 69)
Description: Adds all key-value associations from ht2 into ht1. Returns ht1.
Example:
  (define ht1 (make-hash-table equal?))
  (define ht2 (make-hash-table equal?))
  (hash-table-set! ht2 'a 1)
  (hash-table-merge! ht1 ht2)
  (hash-table-ref ht1 'a) => 1"
      (hash-table-walk ht2 (lambda (k v) (hash-table-set! ht1 k v)))
      ht1)

    (define (hash-table-update! ht key proc . rest)
      "Syntax: (hash-table-update! ht key proc [default-thunk])
Library: (srfi 69)
Description: Applies proc to the current value of key in ht and stores the result.
If key is absent and default-thunk is provided, uses (default-thunk) as the initial value.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 5)
  (hash-table-update! ht 'x (lambda (v) (+ v 1)))
  (hash-table-ref ht 'x) => 6"
      (let ((old (cond ((hash-table-exists? ht key) (hash-table-ref ht key))
                       ((null? rest) (hash-table-ref ht key))
                       (else ((car rest))))))
        (hash-table-set! ht key (proc old))))

    (define (hash-table-update!/default ht key proc default)
      "Syntax: (hash-table-update!/default ht key proc default)
Library: (srfi 69)
Description: Applies proc to the current value of key in ht (or default if absent)
and stores the result.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-update!/default ht 'x (lambda (v) (+ v 1)) 0)
  (hash-table-ref ht 'x) => 1"
      (hash-table-set! ht key (proc (hash-table-ref/default ht key default))))

    (define (hash-table/get ht key default)
      "Syntax: (hash-table/get ht key default)
Library: (srfi 69)
Description: Returns the value associated with key in ht, or default if key is not found.
Alias for hash-table-ref/default.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table/get ht 'x 0) => 42
  (hash-table/get ht 'y 0) => 0"
      (hash-table-ref/default ht key default))

    (define (hash-table/put! ht key value)
      "Syntax: (hash-table/put! ht key value)
Library: (srfi 69)
Description: Associates key with value in the hash table ht. If the key already exists, its value is updated.
Alias for hash-table-set!.
Example:
  (define ht (make-hash-table equal?))
  (hash-table/put! ht 'x 42)
  (hash-table-ref ht 'x) => 42"
      (hash-table-set! ht key value))

    (define (hash-table/remove! ht key)
      "Syntax: (hash-table/remove! ht key)
Library: (srfi 69)
Description: Removes the association for key from the hash table ht. Has no effect if key is not present.
Alias for hash-table-delete!.
Example:
  (define ht (make-hash-table equal?))
  (hash-table-set! ht 'x 42)
  (hash-table/remove! ht 'x)
  (hash-table-exists? ht 'x) => #f"
      (hash-table-delete! ht key))

    (define (string-hash s . rest)
      "Syntax: (string-hash s [bound])
Library: (srfi 69)
Description: Returns a non-negative integer hash of string s. If bound is given, the result
is in the range [0, bound); otherwise it is in [0, 2^32). The hash is case-sensitive.
Example:
  (integer? (string-hash \"hello\")) => #t
  (< (string-hash \"world\" 100) 100) => #t
  (= (string-hash \"abc\") (string-hash \"abc\")) => #t"
      (let ((bound (if (null? rest) (expt 2 32) (car rest))))
        (modulo (let loop ((i 0) (h 0))
                  (if (= i (string-length s))
                      h
                      (loop (+ i 1)
                            (+ (* h 31) (char->integer (string-ref s i))))))
                bound)))

    (define (string-ci-hash s . rest)
      "Syntax: (string-ci-hash s [bound])
Library: (srfi 69)
Description: Returns a non-negative integer hash of string s, case-insensitively. Equivalent
to hashing the downcased version of s. If bound is given, the result is in [0, bound).
Example:
  (= (string-ci-hash \"Hello\") (string-ci-hash \"hello\")) => #t
  (< (string-ci-hash \"World\" 100) 100) => #t"
      (apply string-hash (string-downcase s) rest))

    (define (hash obj . rest)
      "Syntax: (hash obj [bound])
Library: (srfi 69)
Description: Returns a non-negative integer hash suitable for any Scheme object, using
equal?-based comparison semantics. Handles strings, symbols, numbers, chars, booleans,
null, and pairs. If bound is given, the result is in [0, bound); otherwise [0, 2^32).
Example:
  (integer? (hash '(1 2 3))) => #t
  (= (hash \"abc\") (hash \"abc\")) => #t
  (< (hash 'foo 100) 100) => #t"
      (let ((bound (if (null? rest) (expt 2 32) (car rest))))
        (modulo
         (cond
           ((string? obj) (let loop ((i 0) (h 0))
                            (if (= i (string-length obj)) h
                                (loop (+ i 1)
                                      (+ (* h 31) (char->integer (string-ref obj i)))))))
           ((symbol? obj) (let ((s (symbol->string obj)))
                            (let loop ((i 0) (h 0))
                              (if (= i (string-length s)) h
                                  (loop (+ i 1)
                                        (+ (* h 31) (char->integer (string-ref s i))))))))
           ((number? obj) (exact (floor obj)))
           ((char? obj) (char->integer obj))
           ((boolean? obj) (if obj 1 0))
           ((null? obj) 0)
           ((pair? obj) (+ (* 31 (hash (car obj) bound)) (hash (cdr obj) bound)))
           (else 0))
         bound)))

    (define (hash-by-identity obj . rest)
      "Syntax: (hash-by-identity obj [bound])
Library: (srfi 69)
Description: Returns a hash of obj using identity (eq?) comparison semantics. In this
implementation it delegates to hash. If bound is given, the result is in [0, bound).
Example:
  (integer? (hash-by-identity 'foo)) => #t
  (< (hash-by-identity 42 100) 100) => #t"
      (apply hash obj rest))))

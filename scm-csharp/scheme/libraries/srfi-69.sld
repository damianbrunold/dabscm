(define-library (srfi 69)
  (import (scheme base)
          (scheme char)
          (only (scheme complex) real-part))
  (export alist->hash-table
          hash
          hash-by-identity
          hash-table->alist
          hash-table-copy
          hash-table-delete!
          hash-table-equivalence-function
          hash-table-exists?
          hash-table-fold
          hash-table-hash-function
          hash-table-keys
          hash-table-merge!
          hash-table-ref
          hash-table-ref/default
          hash-table-set!
          hash-table-size
          hash-table-update!
          hash-table-update!/default
          hash-table-values
          hash-table-walk
          hash-table/get
          hash-table/put!
          hash-table/remove!
          hash-table?
          make-hash-table
          string-ci-hash
          string-hash)
  (begin
    (define %make-hash-table (%primitive "make-hash-table"))
    (define %hash-table-ref (%primitive "hash-table-ref"))
    (define %table-spec (%primitive "%hash-table-comparator"))
    (define %set-table-spec! (%primitive "%hash-table-set-comparator!"))
    (define hash-table? (%primitive "hash-table?"))
    (define hash-table-set! (%primitive "hash-table-set!"))
    (define hash-table-ref/default (%primitive "hash-table-ref/default"))
    (define hash-table-delete! (%primitive "hash-table-delete!"))
    (define hash-table-exists? (%primitive "hash-table-exists?"))
    (define hash-table-size (%primitive "hash-table-size"))
    (define hash-table-keys (%primitive "hash-table-keys"))
    (define hash-table-values (%primitive "hash-table-values"))
    (define hash-table->alist (%primitive "hash-table->alist"))
    (define hash-table-copy (%primitive "hash-table-copy"))

    ;; The equivalences the hash tables support natively, as the mode the
    ;; make-hash-table primitive takes. Any other predicate is an error: a
    ;; table cannot call it, and treating it as equal? would give wrong
    ;; answers silently.
    (define %primitive-name (%primitive "%primitive-name"))

    ;; equiv is the procedure p: eq? to it, or the primitive of its name (a
    ;; primitive need not be eq? to itself across libraries)
    (define (%is? equiv p name) (or (eq? equiv p) (eq? (%primitive-name equiv) name)))

    (define (%equivalence-mode equiv)
      (cond ((%is? equiv equal? 'equal?) 'equal)
            ((%is? equiv eqv? 'eqv?) 'eqv)
            ((%is? equiv eq? 'eq?) 'eq)
            ((%is? equiv string=? 'string=?) 'equal)
            ((%is? equiv string-ci=? 'string-ci=?) 'string-ci)
            ((%is? equiv char=? 'char=?) 'eqv)
            ((%is? equiv char-ci=? 'char-ci=?) 'char-ci)
            ((%is? equiv = '=) 'numeric)
            (else
             (error "make-hash-table: unsupported equivalence (use equal?, eqv?, eq?, string=?, string-ci=?, char=?, char-ci=? or =)"
                    equiv))))

    ;; the hash function SRFI 69 associates with an equivalence
    (define (%default-hash equiv)
      (cond ((%is? equiv eq? 'eq?) hash-by-identity)
            ((%is? equiv string=? 'string=?) string-hash)
            ((%is? equiv string-ci=? 'string-ci=?) string-ci-hash)
            (else hash)))

    (define (make-hash-table . args)
      "Syntax: (make-hash-table [equivalence [hash arg ...]])
Library: (srfi 69)
Description: Creates a new empty hash table. equivalence (default equal?)
is one of equal?, eqv?, eq?, string=?, string-ci=?, char=?, char-ci=? or
=; another predicate is an error. The table hashes as its equivalence
needs: the optional hash function is kept for hash-table-hash-function,
further arguments are ignored.
Example:
  (define ht (make-hash-table string-ci=? string-ci-hash))
  (hash-table-set! ht \"Zurich\" 1)
  (hash-table-ref/default ht \"ZURICH\" #f) => 1"
      (if (null? args)
          (%make-hash-table)
          (let* ((equiv (car args))
                 (ht (%make-hash-table (%equivalence-mode equiv))))
            (%set-table-spec! ht
                              (vector 'srfi-69
                                      equiv
                                      (if (and (pair? (cdr args))
                                               (procedure? (cadr args)))
                                          (cadr args)
                                          (%default-hash equiv))))
            ht)))

    (define (%spec ht)
      (let ((s (%table-spec ht)))
        (and (vector? s) (= (vector-length s) 3) (eq? (vector-ref s 0) 'srfi-69) s)))

    (define (hash-table-equivalence-function ht)
      "Syntax: (hash-table-equivalence-function ht)
Library: (srfi 69)
Description: The equivalence predicate ht was made with (equal? by default).
Example:
  (hash-table-equivalence-function (make-hash-table eq?)) => eq?"
      (let ((s (%spec ht))) (if s (vector-ref s 1) equal?)))

    (define (hash-table-hash-function ht)
      "Syntax: (hash-table-hash-function ht)
Library: (srfi 69)
Description: The hash function ht was made with, or the one that goes with
its equivalence (hash by default).
Example:
  (hash-table-hash-function (make-hash-table string=?)) => string-hash"
      (let ((s (%spec ht))) (if s (vector-ref s 2) hash)))

    (define %missing (list 'missing))

    (define (hash-table-ref ht key . thunk)
      "Syntax: (hash-table-ref ht key [thunk])
Library: (srfi 69)
Description: The value of key in ht. When key is missing, the result of
calling thunk, or an error without thunk.
Example:
  (define ht (make-hash-table))
  (hash-table-set! ht 'a 1)
  (hash-table-ref ht 'a) => 1
  (hash-table-ref ht 'b (lambda () 0)) => 0"
      (if (null? thunk)
          (%hash-table-ref ht key)
          (let ((v (hash-table-ref/default ht key %missing)))
            (if (eq? v %missing) ((car thunk)) v))))

    (define (alist->hash-table alist . args)
      "Syntax: (alist->hash-table alist [equivalence [hash arg ...]])
Library: (srfi 69)
Description: A new hash table (made as with make-hash-table and the further
arguments) holding the associations of alist; for a key that occurs more
than once, the first association wins.
Example:
  (define ht (alist->hash-table '((a . 1) (b . 2) (a . 3))))
  (hash-table-ref ht 'a) => 1"
      (let ((ht (apply make-hash-table args)))
        (for-each (lambda (p)
                    (unless (hash-table-exists? ht (car p))
                      (hash-table-set! ht (car p) (cdr p))))
                  alist)
        ht))

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
      (let loop ((alist (hash-table->alist ht))
                 (acc init))
        (if (null? alist)
            acc
            (loop (cdr alist) (f (caar alist) (cdar alist) acc)))))

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
        (modulo (cond ((string? obj)
                       (let loop ((i 0) (h 0))
                         (if (= i (string-length obj))
                             h
                             (loop (+ i 1)
                                   (+ (* h 31)
                                      (char->integer (string-ref obj i)))))))
                      ((symbol? obj)
                       (let ((s (symbol->string obj)))
                         (let loop ((i 0) (h 0))
                           (if (= i (string-length s))
                               h
                               (loop (+ i 1)
                                     (+ (* h 31)
                                        (char->integer (string-ref s i))))))))
                      ((number? obj)
                       ;; = numbers hash alike; NaN, infinities -> 0
                       (let ((x (real-part obj)))
                         (if (and (= x x) (< (abs x) 1e18))
                             (exact (floor x))
                             0)))
                      ((char? obj) (char->integer obj))
                      ((boolean? obj) (if obj 1 0))
                      ((null? obj) 0)
                      ((pair? obj)
                       (+ (* 31 (hash (car obj) bound))
                          (hash (cdr obj) bound)))
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

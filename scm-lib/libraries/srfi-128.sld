(define-library (srfi 128)
  (import (scheme base) (scheme char) (scheme inexact) (scheme complex))
  (export comparator? comparator-ordered? comparator-hashable?
          make-comparator
          make-pair-comparator make-list-comparator make-vector-comparator
          make-eq-comparator make-eqv-comparator make-equal-comparator
          boolean-hash char-hash char-ci-hash default-hash number-hash
          string-hash string-ci-hash symbol-hash
          hash-bound hash-salt
          make-default-comparator default-comparator
          comparator-type-test-predicate comparator-equality-predicate
          comparator-ordering-predicate comparator-hash-function
          comparator-test-type comparator-check-type
          =? <? >? <=? >=?
          comparator-if<=>
          comparator-register-default!)
  (begin

    ;; --- Record type ---

    (define-record-type <comparator>
      (%make-comparator type-test equality ordering hash ordered? hashable?)
      comparator?
      (type-test comparator-type-test-predicate)
      (equality comparator-equality-predicate)
      (ordering comparator-ordering-predicate)
      (hash comparator-hash-function)
      (ordered? comparator-ordered?)
      (hashable? comparator-hashable?))

    ;; --- Constructor ---

    (define (make-comparator type-test equality ordering hash)
      "Syntax: (make-comparator type-test equality ordering hash)
Library: (srfi 128)
Description: Creates a comparator from four procedures. type-test is a predicate
that returns #t for valid arguments. equality is an equivalence predicate. ordering
is an ordering predicate (or #f if not provided). hash is a hash function (or #f
if not provided). If equality is #t, equal? is used.
Example:
  (define c (make-comparator string? string=? string<? string-hash))
  (comparator? c) => #t
  (comparator-ordered? c) => #t"
      (let ((type-test (if (eq? type-test #t) (lambda (x) #t) type-test))
            (equality (if (eq? equality #t) equal? equality)))
        (%make-comparator type-test equality
                          (if ordering ordering (lambda (a b) (error "comparator has no ordering predicate")))
                          (if hash hash (lambda (x) (error "comparator has no hash function")))
                          (and ordering #t)
                          (and hash #t))))

    ;; --- Type test and check ---

    (define (comparator-test-type comparator obj)
      "Syntax: (comparator-test-type comparator obj)
Library: (srfi 128)
Description: Returns #t if obj satisfies the type test of the comparator.
Example:
  (comparator-test-type (make-default-comparator) 42) => #t"
      ((comparator-type-test-predicate comparator) obj))

    (define (comparator-check-type comparator obj)
      "Syntax: (comparator-check-type comparator obj)
Library: (srfi 128)
Description: Like comparator-test-type but raises an error if obj fails.
Example:
  (comparator-check-type (make-default-comparator) 42) => #t"
      (if (comparator-test-type comparator obj)
          #t
          (error "comparator type check failed" obj)))

    ;; --- Hash bound and salt ---

    (define (hash-bound)
      "Syntax: (hash-bound)
Library: (srfi 128)
Description: Returns the upper exclusive bound for hash values. Implementation-defined.
Example:
  (> (hash-bound) 0) => #t"
      (expt 2 32))

    (define (hash-salt)
      "Syntax: (hash-salt)
Library: (srfi 128)
Description: Returns a salt value for hash functions. Returns 0 in this implementation.
Example:
  (integer? (hash-salt)) => #t"
      0)

    ;; --- Hash functions ---

    (define (boolean-hash obj)
      "Syntax: (boolean-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a boolean.
Example:
  (integer? (boolean-hash #t)) => #t
  (= (boolean-hash #t) (boolean-hash #t)) => #t"
      (if obj 1 0))

    (define (char-hash obj)
      "Syntax: (char-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a character.
Example:
  (integer? (char-hash #\\a)) => #t
  (= (char-hash #\\a) (char-hash #\\a)) => #t"
      (char->integer obj))

    (define (char-ci-hash obj)
      "Syntax: (char-ci-hash obj)
Library: (srfi 128)
Description: Returns a case-insensitive hash value for a character.
Example:
  (= (char-ci-hash #\\A) (char-ci-hash #\\a)) => #t"
      (char->integer (char-downcase obj)))

    (define (number-hash obj)
      "Syntax: (number-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a number.
Example:
  (integer? (number-hash 42)) => #t
  (= (number-hash 3.14) (number-hash 3.14)) => #t"
      (exact (floor (abs (real-part obj)))))

    (define (string-hash obj)
      "Syntax: (string-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a string.
Example:
  (integer? (string-hash \"hello\")) => #t
  (= (string-hash \"abc\") (string-hash \"abc\")) => #t"
      (let loop ((i 0) (h 0))
        (if (= i (string-length obj))
            (modulo h (hash-bound))
            (loop (+ i 1)
                  (+ (* h 31) (char->integer (string-ref obj i)))))))

    (define (string-ci-hash obj)
      "Syntax: (string-ci-hash obj)
Library: (srfi 128)
Description: Returns a case-insensitive hash value for a string.
Example:
  (= (string-ci-hash \"Hello\") (string-ci-hash \"hello\")) => #t"
      (string-hash (string-downcase obj)))

    (define (symbol-hash obj)
      "Syntax: (symbol-hash obj)
Library: (srfi 128)
Description: Returns a hash value for a symbol.
Example:
  (integer? (symbol-hash 'foo)) => #t
  (= (symbol-hash 'bar) (symbol-hash 'bar)) => #t"
      (string-hash (symbol->string obj)))

    (define (default-hash obj)
      "Syntax: (default-hash obj)
Library: (srfi 128)
Description: Returns a hash value for any object using the default hashing strategy.
Example:
  (integer? (default-hash 42)) => #t
  (integer? (default-hash \"hello\")) => #t"
      (cond
        ((boolean? obj) (boolean-hash obj))
        ((char? obj) (char-hash obj))
        ((string? obj) (string-hash obj))
        ((symbol? obj) (symbol-hash obj))
        ((number? obj) (number-hash obj))
        ((null? obj) 0)
        ((pair? obj)
         (modulo (+ (* 31 (default-hash (car obj)))
                    (default-hash (cdr obj)))
                 (hash-bound)))
        ((vector? obj)
         (let ((len (min (vector-length obj) 8)))
           (let loop ((i 0) (h 0))
             (if (= i len)
                 (modulo h (hash-bound))
                 (loop (+ i 1)
                       (+ (* h 31) (default-hash (vector-ref obj i))))))))
        (else 0)))

    ;; --- Standard comparators ---

    (define (make-eq-comparator)
      "Syntax: (make-eq-comparator)
Library: (srfi 128)
Description: Returns a comparator that uses eq? for equality.
Example:
  (define c (make-eq-comparator))
  (comparator? c) => #t"
      (%make-comparator (lambda (x) #t) eq? #f #f #f #f))

    (define (make-eqv-comparator)
      "Syntax: (make-eqv-comparator)
Library: (srfi 128)
Description: Returns a comparator that uses eqv? for equality.
Example:
  (define c (make-eqv-comparator))
  (comparator? c) => #t"
      (%make-comparator (lambda (x) #t) eqv? #f #f #f #f))

    (define (make-equal-comparator)
      "Syntax: (make-equal-comparator)
Library: (srfi 128)
Description: Returns a comparator that uses equal? for equality and default-hash for hashing.
Example:
  (define c (make-equal-comparator))
  (comparator? c) => #t
  (comparator-hashable? c) => #t"
      (%make-comparator (lambda (x) #t) equal? #f default-hash #f #t))

    ;; --- Default comparator ---

    (define *default-comparator-registry* '())

    (define (comparator-register-default! comparator)
      "Syntax: (comparator-register-default! comparator)
Library: (srfi 128)
Description: Registers a comparator to be used by the default comparator for types
that satisfy the registered comparator's type test.
Example:
  (comparator-register-default!
    (make-comparator string? string=? string<? string-hash))"
      (set! *default-comparator-registry*
            (cons comparator *default-comparator-registry*)))

    (define (default-comparator-type-test obj)
      (or (boolean? obj) (char? obj) (string? obj) (symbol? obj)
          (number? obj) (null? obj) (pair? obj) (vector? obj)
          (let loop ((regs *default-comparator-registry*))
            (if (null? regs) #f
                (if (comparator-test-type (car regs) obj) #t
                    (loop (cdr regs)))))))

    (define (type-index obj)
      (cond
        ((null? obj)    0)
        ((boolean? obj) 1)
        ((char? obj)    2)
        ((number? obj)  3)
        ((string? obj)  4)
        ((symbol? obj)  5)
        ((pair? obj)    6)
        ((vector? obj)  7)
        (else           8)))

    (define (default-comparator-equality a b)
      (cond
        ((and (boolean? a) (boolean? b)) (eq? a b))
        ((and (char? a) (char? b)) (char=? a b))
        ((and (number? a) (number? b)) (= a b))
        ((and (string? a) (string? b)) (string=? a b))
        ((and (symbol? a) (symbol? b)) (eq? a b))
        ((and (null? a) (null? b)) #t)
        ((and (pair? a) (pair? b))
         (and (default-comparator-equality (car a) (car b))
              (default-comparator-equality (cdr a) (cdr b))))
        ((and (vector? a) (vector? b))
         (and (= (vector-length a) (vector-length b))
              (let loop ((i 0))
                (or (= i (vector-length a))
                    (and (default-comparator-equality (vector-ref a i) (vector-ref b i))
                         (loop (+ i 1)))))))
        (else
         (let loop ((regs *default-comparator-registry*))
           (if (null? regs) (equal? a b)
               (if (and (comparator-test-type (car regs) a)
                        (comparator-test-type (car regs) b))
                   ((comparator-equality-predicate (car regs)) a b)
                   (loop (cdr regs))))))))

    (define (default-comparator-ordering a b)
      (let ((ia (type-index a)) (ib (type-index b)))
        (cond
          ((< ia ib) #t)
          ((> ia ib) #f)
          (else
           (cond
             ((null? a) #f)
             ((boolean? a) (and (not a) b))
             ((char? a) (char<? a b))
             ((number? a) (< a b))
             ((string? a) (string<? a b))
             ((symbol? a) (string<? (symbol->string a) (symbol->string b)))
             ((pair? a)
              (cond
                ((default-comparator-ordering (car a) (car b)) #t)
                ((default-comparator-ordering (car b) (car a)) #f)
                (else (default-comparator-ordering (cdr a) (cdr b)))))
             ((vector? a)
              (let ((la (vector-length a)) (lb (vector-length b)))
                (let loop ((i 0))
                  (cond
                    ((and (= i la) (= i lb)) #f)
                    ((= i la) #t)
                    ((= i lb) #f)
                    ((default-comparator-ordering (vector-ref a i) (vector-ref b i)) #t)
                    ((default-comparator-ordering (vector-ref b i) (vector-ref a i)) #f)
                    (else (loop (+ i 1)))))))
             (else
              (let loop ((regs *default-comparator-registry*))
                (if (null? regs) (error "cannot order objects" a b)
                    (if (and (comparator-test-type (car regs) a)
                             (comparator-test-type (car regs) b)
                             (comparator-ordered? (car regs)))
                        ((comparator-ordering-predicate (car regs)) a b)
                        (loop (cdr regs)))))))))))

    (define (make-default-comparator)
      "Syntax: (make-default-comparator)
Library: (srfi 128)
Description: Returns a comparator that handles booleans, characters, strings, symbols,
numbers, null, pairs, and vectors, with ordering and hashing support.
Example:
  (define c (make-default-comparator))
  (=? c 1 1) => #t
  (<? c 1 2) => #t
  (<? c \"a\" \"b\") => #t"
      (%make-comparator default-comparator-type-test
                        default-comparator-equality
                        default-comparator-ordering
                        default-hash
                        #t #t))

    (define default-comparator (make-default-comparator))

    ;; --- Compound comparators ---

    (define (make-pair-comparator car-comparator cdr-comparator)
      "Syntax: (make-pair-comparator car-comparator cdr-comparator)
Library: (srfi 128)
Description: Returns a comparator for pairs that compares car and cdr using
the given comparators.
Example:
  (define c (make-pair-comparator (make-default-comparator) (make-default-comparator)))
  (=? c '(1 . 2) '(1 . 2)) => #t"
      (make-comparator
       pair?
       (lambda (a b)
         (and ((comparator-equality-predicate car-comparator) (car a) (car b))
              ((comparator-equality-predicate cdr-comparator) (cdr a) (cdr b))))
       (if (and (comparator-ordered? car-comparator) (comparator-ordered? cdr-comparator))
           (lambda (a b)
             (cond
               (((comparator-ordering-predicate car-comparator) (car a) (car b)) #t)
               (((comparator-ordering-predicate car-comparator) (car b) (car a)) #f)
               (else ((comparator-ordering-predicate cdr-comparator) (cdr a) (cdr b)))))
           #f)
       (if (and (comparator-hashable? car-comparator) (comparator-hashable? cdr-comparator))
           (lambda (x)
             (modulo (+ (* 31 ((comparator-hash-function car-comparator) (car x)))
                        ((comparator-hash-function cdr-comparator) (cdr x)))
                     (hash-bound)))
           #f)))

    (define (make-list-comparator element-comparator type-test empty? head tail)
      "Syntax: (make-list-comparator element-comparator type-test empty? head tail)
Library: (srfi 128)
Description: Returns a comparator for list-like sequences using the given element
comparator and sequence access procedures.
Example:
  (define c (make-list-comparator (make-default-comparator) list? null? car cdr))
  (=? c '(1 2 3) '(1 2 3)) => #t"
      (make-comparator
       type-test
       (lambda (a b)
         (let loop ((a a) (b b))
           (cond
             ((and (empty? a) (empty? b)) #t)
             ((or (empty? a) (empty? b)) #f)
             (else (and ((comparator-equality-predicate element-comparator) (head a) (head b))
                        (loop (tail a) (tail b)))))))
       (if (comparator-ordered? element-comparator)
           (lambda (a b)
             (let loop ((a a) (b b))
               (cond
                 ((and (empty? a) (empty? b)) #f)
                 ((empty? a) #t)
                 ((empty? b) #f)
                 (((comparator-ordering-predicate element-comparator) (head a) (head b)) #t)
                 (((comparator-ordering-predicate element-comparator) (head b) (head a)) #f)
                 (else (loop (tail a) (tail b))))))
           #f)
       (if (comparator-hashable? element-comparator)
           (lambda (x)
             (let loop ((x x) (h 0))
               (if (empty? x) (modulo h (hash-bound))
                   (loop (tail x)
                         (+ (* h 31) ((comparator-hash-function element-comparator) (head x)))))))
           #f)))

    (define (make-vector-comparator element-comparator type-test length ref)
      "Syntax: (make-vector-comparator element-comparator type-test length ref)
Library: (srfi 128)
Description: Returns a comparator for vector-like sequences using the given element
comparator and vector access procedures.
Example:
  (define c (make-vector-comparator (make-default-comparator) vector? vector-length vector-ref))
  (=? c #(1 2 3) #(1 2 3)) => #t"
      (make-comparator
       type-test
       (lambda (a b)
         (and (= (length a) (length b))
              (let loop ((i 0))
                (or (= i (length a))
                    (and ((comparator-equality-predicate element-comparator) (ref a i) (ref b i))
                         (loop (+ i 1)))))))
       (if (comparator-ordered? element-comparator)
           (lambda (a b)
             (let ((la (length a)) (lb (length b)))
               (let loop ((i 0))
                 (cond
                   ((and (= i la) (= i lb)) #f)
                   ((= i la) #t)
                   ((= i lb) #f)
                   (((comparator-ordering-predicate element-comparator) (ref a i) (ref b i)) #t)
                   (((comparator-ordering-predicate element-comparator) (ref b i) (ref a i)) #f)
                   (else (loop (+ i 1)))))))
           #f)
       (if (comparator-hashable? element-comparator)
           (lambda (x)
             (let ((len (min (length x) 8)))
               (let loop ((i 0) (h 0))
                 (if (= i len) (modulo h (hash-bound))
                     (loop (+ i 1)
                           (+ (* h 31) ((comparator-hash-function element-comparator) (ref x i))))))))
           #f)))

    ;; --- Comparison predicates ---

    (define (=? comparator a b . rest)
      "Syntax: (=? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if all arguments are equal according to the comparator.
Example:
  (=? (make-default-comparator) 1 1 1) => #t
  (=? (make-default-comparator) 1 2) => #f"
      (and ((comparator-equality-predicate comparator) a b)
           (or (null? rest)
               (let loop ((prev b) (rest rest))
                 (or (null? rest)
                     (and ((comparator-equality-predicate comparator) prev (car rest))
                          (loop (car rest) (cdr rest))))))))

    (define (<? comparator a b . rest)
      "Syntax: (<? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if each argument is less than the next according to the comparator.
Example:
  (<? (make-default-comparator) 1 2 3) => #t
  (<? (make-default-comparator) 1 1) => #f"
      (and ((comparator-ordering-predicate comparator) a b)
           (or (null? rest)
               (let loop ((prev b) (rest rest))
                 (or (null? rest)
                     (and ((comparator-ordering-predicate comparator) prev (car rest))
                          (loop (car rest) (cdr rest))))))))

    (define (>? comparator a b . rest)
      "Syntax: (>? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if each argument is greater than the next according to the comparator.
Example:
  (>? (make-default-comparator) 3 2 1) => #t"
      (and ((comparator-ordering-predicate comparator) b a)
           (or (null? rest)
               (let loop ((prev b) (rest rest))
                 (or (null? rest)
                     (and ((comparator-ordering-predicate comparator) (car rest) prev)
                          (loop (car rest) (cdr rest))))))))

    (define (<=? comparator a b . rest)
      "Syntax: (<=? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if each argument is less than or equal to the next.
Example:
  (<=? (make-default-comparator) 1 1 2) => #t"
      (and (not ((comparator-ordering-predicate comparator) b a))
           (or (null? rest)
               (let loop ((prev b) (rest rest))
                 (or (null? rest)
                     (and (not ((comparator-ordering-predicate comparator) (car rest) prev))
                          (loop (car rest) (cdr rest))))))))

    (define (>=? comparator a b . rest)
      "Syntax: (>=? comparator a b c ...)
Library: (srfi 128)
Description: Returns #t if each argument is greater than or equal to the next.
Example:
  (>=? (make-default-comparator) 3 3 1) => #t"
      (and (not ((comparator-ordering-predicate comparator) a b))
           (or (null? rest)
               (let loop ((prev b) (rest rest))
                 (or (null? rest)
                     (and (not ((comparator-ordering-predicate comparator) prev (car rest)))
                          (loop (car rest) (cdr rest))))))))

    ;; --- Three-way comparison ---

    (define-syntax comparator-if<=>
      (syntax-rules ()
        ((_ comparator a b less equal greater)
         (let ((cmp comparator) (x a) (y b))
           (cond
             (((comparator-equality-predicate cmp) x y) equal)
             (((comparator-ordering-predicate cmp) x y) less)
             (else greater))))
        ((_ a b less equal greater)
         (comparator-if<=> default-comparator a b less equal greater))))

    ))

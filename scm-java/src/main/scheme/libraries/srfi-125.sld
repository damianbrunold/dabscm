(define-library (srfi 125)
  (import (scheme base) (srfi 128))
  (export
    ;; Constructors
    make-hash-table hash-table hash-table-unfold alist->hash-table
    ;; Predicates
    hash-table? hash-table-contains? hash-table-empty? hash-table=?
    hash-table-mutable?
    ;; Accessors
    hash-table-ref hash-table-ref/default
    ;; Mutators
    hash-table-set! hash-table-delete! hash-table-intern!
    hash-table-update! hash-table-update!/default
    hash-table-pop! hash-table-clear!
    ;; The whole hash table
    hash-table-size hash-table-keys hash-table-values hash-table-entries
    hash-table-find hash-table-count
    ;; Mapping and folding
    hash-table-map hash-table-for-each hash-table-map!
    hash-table-map->list hash-table-fold hash-table-prune!
    ;; Copying and conversion
    hash-table-copy hash-table-empty-copy hash-table->alist
    ;; Hash tables as sets
    hash-table-union! hash-table-intersection!
    hash-table-difference! hash-table-xor!
    ;; Comparator access
    hash-table-equivalence-function hash-table-hash-function
    hash-table-comparator)
  (begin

    ;; --- Primitives ---

    (define %make-hash-table-prim (%primitive "make-hash-table"))
    (define hash-table? (%primitive "hash-table?"))
    (define hash-table-set! (%primitive "hash-table-set!"))
    (define %hash-table-ref (%primitive "hash-table-ref"))
    (define hash-table-ref/default (%primitive "hash-table-ref/default"))
    (define hash-table-delete! (%primitive "hash-table-delete!"))
    (define %hash-table-exists? (%primitive "hash-table-exists?"))
    (define hash-table-size (%primitive "hash-table-size"))
    (define hash-table-keys (%primitive "hash-table-keys"))
    (define hash-table-values (%primitive "hash-table-values"))
    (define hash-table->alist (%primitive "hash-table->alist"))
    (define %hash-table-copy (%primitive "hash-table-copy"))
    (define hash-table-clear! (%primitive "hash-table-clear!"))
    (define %set-comparator! (%primitive "%hash-table-set-comparator!"))
    (define %get-comparator (%primitive "%hash-table-comparator"))

    ;; --- Constructors ---

    (define (make-hash-table comparator . args)
      "Syntax: (make-hash-table comparator)
Library: (srfi 125)
Description: Creates a new empty hash table using the given comparator for key
comparison. The comparator provides the equality predicate and hash function.
Example:
  (define ht (make-hash-table (make-default-comparator)))
  (hash-table-set! ht 'a 1)
  (hash-table-ref ht 'a) => 1"
      (let ((eq-pred (comparator-equality-predicate comparator)))
        (let ((ht (%make-hash-table-prim eq-pred)))
          (%set-comparator! ht comparator)
          ht)))

    (define (hash-table comparator . args)
      "Syntax: (hash-table comparator key1 val1 key2 val2 ...)
Library: (srfi 125)
Description: Creates a new hash table populated with the given key-value pairs.
It is an error to supply duplicate keys.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-ref ht 'a) => 1
  (hash-table-ref ht 'b) => 2"
      (let ((ht (make-hash-table comparator)))
        (let loop ((args args))
          (if (null? args) ht
              (begin
                (if (null? (cdr args))
                    (error "hash-table: odd number of arguments"))
                (hash-table-set! ht (car args) (cadr args))
                (loop (cddr args)))))))

    (define (hash-table-unfold stop? mapper successor seed comparator)
      "Syntax: (hash-table-unfold stop? mapper successor seed comparator)
Library: (srfi 125)
Description: Creates a hash table by repeatedly applying mapper to the seed
to get key-value pairs, and successor to advance the seed, until stop? returns #t.
Example:
  (define ht (hash-table-unfold (lambda (s) (> s 3))
                                (lambda (s) (values s (* s 10)))
                                (lambda (s) (+ s 1))
                                1
                                (make-default-comparator)))
  (hash-table-ref ht 1) => 10"
      (let ((ht (make-hash-table comparator)))
        (let loop ((seed seed))
          (if (stop? seed)
              ht
              (call-with-values
                (lambda () (mapper seed))
                (lambda (key value)
                  (hash-table-set! ht key value)
                  (loop (successor seed))))))))

    (define (alist->hash-table alist comparator . args)
      "Syntax: (alist->hash-table alist comparator)
Library: (srfi 125)
Description: Creates a hash table from an association list. Earlier entries take
precedence over later ones with the same key (first association wins).
Example:
  (define ht (alist->hash-table '((a . 1) (b . 2)) (make-default-comparator)))
  (hash-table-ref ht 'a) => 1"
      (let ((ht (apply make-hash-table comparator args)))
        (for-each (lambda (pair)
                    (if (not (%hash-table-exists? ht (car pair)))
                        (hash-table-set! ht (car pair) (cdr pair))))
                  alist)
        ht))

    ;; --- Predicates ---

    (define (hash-table-contains? ht key)
      "Syntax: (hash-table-contains? ht key)
Library: (srfi 125)
Description: Returns #t if the hash table contains an association for key.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-contains? ht 'a) => #t
  (hash-table-contains? ht 'b) => #f"
      (%hash-table-exists? ht key))

    (define (hash-table-empty? ht)
      "Syntax: (hash-table-empty? ht)
Library: (srfi 125)
Description: Returns #t if the hash table has no associations.
Example:
  (hash-table-empty? (make-hash-table (make-default-comparator))) => #t"
      (= 0 (hash-table-size ht)))

    (define (hash-table=? value-comparator ht1 ht2)
      "Syntax: (hash-table=? value-comparator ht1 ht2)
Library: (srfi 125)
Description: Returns #t if the two hash tables have the same keys (by their own
comparators) and the same values (by value-comparator).
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table (make-default-comparator) 'a 1))
  (hash-table=? (make-default-comparator) ht1 ht2) => #t"
      (let ((val=? (comparator-equality-predicate value-comparator)))
        (and (= (hash-table-size ht1) (hash-table-size ht2))
             (let ((alist1 (hash-table->alist ht1)))
               (let loop ((pairs alist1))
                 (or (null? pairs)
                     (let* ((key (caar pairs))
                            (val1 (cdar pairs)))
                       (and (%hash-table-exists? ht2 key)
                            (val=? val1 (hash-table-ref/default ht2 key #f))
                            (loop (cdr pairs))))))))))

    (define (hash-table-mutable? ht)
      "Syntax: (hash-table-mutable? ht)
Library: (srfi 125)
Description: Returns #t. All hash tables in this implementation are mutable.
Example:
  (hash-table-mutable? (make-hash-table (make-default-comparator))) => #t"
      #t)

    ;; --- Accessors ---

    (define (hash-table-ref ht key . args)
      "Syntax: (hash-table-ref ht key [failure [success]])
Library: (srfi 125)
Description: Returns the value associated with key in ht. If key is not found,
calls failure thunk if given, otherwise raises an error. If success is given,
applies it to the value.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-ref ht 'a) => 1
  (hash-table-ref ht 'b (lambda () 42)) => 42
  (hash-table-ref ht 'a #f (lambda (v) (* v 10))) => 10"
      (cond
        ((null? args)
         (%hash-table-ref ht key))
        ((null? (cdr args))
         ;; failure thunk provided
         (if (%hash-table-exists? ht key)
             (hash-table-ref/default ht key #f)
             ((car args))))
        (else
         ;; failure and success provided
         (if (%hash-table-exists? ht key)
             ((cadr args) (hash-table-ref/default ht key #f))
             ((car args))))))

    ;; --- Mutators ---

    (define (hash-table-intern! ht key failure)
      "Syntax: (hash-table-intern! ht key failure)
Library: (srfi 125)
Description: If key exists in ht, returns its value. Otherwise calls failure,
stores the result, and returns it.
Example:
  (define ht (make-hash-table (make-default-comparator)))
  (hash-table-intern! ht 'a (lambda () 42)) => 42
  (hash-table-ref ht 'a) => 42
  (hash-table-intern! ht 'a (lambda () 99)) => 42"
      (if (%hash-table-exists? ht key)
          (hash-table-ref/default ht key #f)
          (let ((val (failure)))
            (hash-table-set! ht key val)
            val)))

    (define (hash-table-update! ht key updater . rest)
      "Syntax: (hash-table-update! ht key updater [failure [success]])
Library: (srfi 125)
Description: Applies updater to the value associated with key (after applying success
if given). If key is not found, applies updater to the result of calling failure.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-update! ht 'a (lambda (v) (+ v 1)))
  (hash-table-ref ht 'a) => 2"
      (cond
        ((null? rest)
         (hash-table-set! ht key (updater (%hash-table-ref ht key))))
        ((null? (cdr rest))
         ;; failure thunk
         (let ((val (if (%hash-table-exists? ht key)
                        (hash-table-ref/default ht key #f)
                        ((car rest)))))
           (hash-table-set! ht key (updater val))))
        (else
         ;; failure and success
         (let ((val (if (%hash-table-exists? ht key)
                        ((cadr rest) (hash-table-ref/default ht key #f))
                        ((car rest)))))
           (hash-table-set! ht key (updater val))))))

    (define (hash-table-update!/default ht key updater default)
      "Syntax: (hash-table-update!/default ht key updater default)
Library: (srfi 125)
Description: Applies updater to the value associated with key (or default if absent)
and stores the result.
Example:
  (define ht (make-hash-table (make-default-comparator)))
  (hash-table-update!/default ht 'x (lambda (v) (+ v 1)) 0)
  (hash-table-ref ht 'x) => 1"
      (hash-table-set! ht key (updater (hash-table-ref/default ht key default))))

    (define (hash-table-pop! ht)
      "Syntax: (hash-table-pop! ht)
Library: (srfi 125)
Description: Removes an arbitrary association from ht and returns its key and value
as two values. It is an error if ht is empty.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-pop! ht) => 'a 1
  (hash-table-empty? ht) => #t"
      (if (hash-table-empty? ht)
          (error "hash-table-pop!: hash table is empty")
          (let* ((alist (hash-table->alist ht))
                 (pair (car alist)))
            (hash-table-delete! ht (car pair))
            (values (car pair) (cdr pair)))))

    ;; --- The whole hash table ---

    (define (hash-table-entries ht)
      "Syntax: (hash-table-entries ht)
Library: (srfi 125)
Description: Returns two values: a list of keys and a list of values from ht.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-entries ht) => (a) (1)"
      (values (hash-table-keys ht) (hash-table-values ht)))

    (define (hash-table-find proc ht failure)
      "Syntax: (hash-table-find proc ht failure)
Library: (srfi 125)
Description: Calls proc with each key and value. If proc returns a true value, that
value is returned. If no entry satisfies proc, calls failure and returns its result.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-find (lambda (k v) (and (> v 1) v)) ht (lambda () #f)) => 2"
      (let loop ((alist (hash-table->alist ht)))
        (if (null? alist)
            (failure)
            (let ((result (proc (caar alist) (cdar alist))))
              (if result result
                  (loop (cdr alist)))))))

    (define (hash-table-count pred ht)
      "Syntax: (hash-table-count pred ht)
Library: (srfi 125)
Description: Returns the number of associations in ht for which (pred key value)
returns true.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (hash-table-count (lambda (k v) (> v 1)) ht) => 2"
      (let loop ((alist (hash-table->alist ht)) (n 0))
        (if (null? alist) n
            (loop (cdr alist)
                  (if (pred (caar alist) (cdar alist)) (+ n 1) n)))))

    ;; --- Mapping and folding ---

    (define (hash-table-map proc comparator ht)
      "Syntax: (hash-table-map proc comparator ht)
Library: (srfi 125)
Description: Returns a new hash table (with the given comparator) whose keys are
the same as ht and whose values are the result of applying proc to the values.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (define ht2 (hash-table-map (lambda (v) (* v 10)) (make-default-comparator) ht))
  (hash-table-ref ht2 'a) => 10"
      (let ((result (make-hash-table comparator)))
        (for-each (lambda (pair)
                    (hash-table-set! result (car pair) (proc (cdr pair))))
                  (hash-table->alist ht))
        result))

    (define (hash-table-for-each proc ht)
      "Syntax: (hash-table-for-each proc ht)
Library: (srfi 125)
Description: Calls proc with each key and value in ht for side effects.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (hash-table-for-each (lambda (k v) (display k)) ht)"
      (for-each (lambda (pair) (proc (car pair) (cdr pair)))
                (hash-table->alist ht)))

    (define (hash-table-map! proc ht)
      "Syntax: (hash-table-map! proc ht)
Library: (srfi 125)
Description: Replaces each value in ht with the result of applying proc to the
key and current value.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-map! (lambda (k v) (* v 10)) ht)
  (hash-table-ref ht 'a) => 10"
      (for-each (lambda (pair)
                  (hash-table-set! ht (car pair) (proc (car pair) (cdr pair))))
                (hash-table->alist ht)))

    (define (hash-table-map->list proc ht)
      "Syntax: (hash-table-map->list proc ht)
Library: (srfi 125)
Description: Returns a list of the results of applying proc to each key and value.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (sort (hash-table-map->list (lambda (k v) v) ht) <) => (1 2)"
      (map (lambda (pair) (proc (car pair) (cdr pair)))
           (hash-table->alist ht)))

    (define (hash-table-fold proc init ht)
      "Syntax: (hash-table-fold proc init ht)
Library: (srfi 125)
Description: Folds proc over all key-value associations in ht, starting from init.
Note: SRFI-125 argument order is (proc init ht), unlike SRFI-69's (ht proc init).
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2))
  (hash-table-fold (lambda (k v acc) (+ v acc)) 0 ht) => 3"
      (let loop ((alist (hash-table->alist ht)) (acc init))
        (if (null? alist) acc
            (loop (cdr alist)
                  (proc (caar alist) (cdar alist) acc)))))

    (define (hash-table-prune! proc ht)
      "Syntax: (hash-table-prune! proc ht)
Library: (srfi 125)
Description: Removes all associations for which (proc key value) returns true.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (hash-table-prune! (lambda (k v) (> v 1)) ht)
  (hash-table-size ht) => 1"
      (for-each (lambda (pair)
                  (if (proc (car pair) (cdr pair))
                      (hash-table-delete! ht (car pair))))
                (hash-table->alist ht)))

    ;; --- Copying and conversion ---

    (define (hash-table-copy ht . args)
      "Syntax: (hash-table-copy ht [mutable?])
Library: (srfi 125)
Description: Returns a copy of ht. The optional mutable? argument is accepted
but ignored (all copies are mutable in this implementation).
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table-copy ht))
  (hash-table-ref ht2 'a) => 1"
      (%hash-table-copy ht))

    (define (hash-table-empty-copy ht)
      "Syntax: (hash-table-empty-copy ht)
Library: (srfi 125)
Description: Returns a new empty hash table with the same comparator as ht.
Example:
  (define ht (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table-empty-copy ht))
  (hash-table-empty? ht2) => #t"
      (let ((comp (%get-comparator ht)))
        (if comp
            (make-hash-table comp)
            (%make-hash-table-prim equal?))))

    ;; --- Hash tables as sets ---

    (define (hash-table-union! ht1 ht2)
      "Syntax: (hash-table-union! ht1 ht2)
Library: (srfi 125)
Description: Adds all associations from ht2 to ht1, without overwriting existing keys.
Returns ht1.
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1))
  (define ht2 (hash-table (make-default-comparator) 'a 99 'b 2))
  (hash-table-union! ht1 ht2)
  (hash-table-ref ht1 'a) => 1
  (hash-table-ref ht1 'b) => 2"
      (for-each (lambda (pair)
                  (if (not (%hash-table-exists? ht1 (car pair)))
                      (hash-table-set! ht1 (car pair) (cdr pair))))
                (hash-table->alist ht2))
      ht1)

    (define (hash-table-intersection! ht1 ht2)
      "Syntax: (hash-table-intersection! ht1 ht2)
Library: (srfi 125)
Description: Removes from ht1 all keys that are not in ht2. Returns ht1.
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (define ht2 (hash-table (make-default-comparator) 'a 10 'c 30))
  (hash-table-intersection! ht1 ht2)
  (hash-table-size ht1) => 2"
      (for-each (lambda (pair)
                  (if (not (%hash-table-exists? ht2 (car pair)))
                      (hash-table-delete! ht1 (car pair))))
                (hash-table->alist ht1))
      ht1)

    (define (hash-table-difference! ht1 ht2)
      "Syntax: (hash-table-difference! ht1 ht2)
Library: (srfi 125)
Description: Removes from ht1 all keys that are in ht2. Returns ht1.
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2 'c 3))
  (define ht2 (hash-table (make-default-comparator) 'b 20))
  (hash-table-difference! ht1 ht2)
  (hash-table-size ht1) => 2"
      (for-each (lambda (pair)
                  (if (%hash-table-exists? ht1 (car pair))
                      (hash-table-delete! ht1 (car pair))))
                (hash-table->alist ht2))
      ht1)

    (define (hash-table-xor! ht1 ht2)
      "Syntax: (hash-table-xor! ht1 ht2)
Library: (srfi 125)
Description: Keeps in ht1 only keys that are in exactly one of ht1 or ht2.
Returns ht1.
Example:
  (define ht1 (hash-table (make-default-comparator) 'a 1 'b 2))
  (define ht2 (hash-table (make-default-comparator) 'b 20 'c 3))
  (hash-table-xor! ht1 ht2)
  (hash-table-size ht1) => 2
  (hash-table-contains? ht1 'a) => #t
  (hash-table-contains? ht1 'c) => #t"
      (let ((to-delete '())
            (to-add '()))
        (for-each (lambda (pair)
                    (if (%hash-table-exists? ht1 (car pair))
                        (set! to-delete (cons (car pair) to-delete))
                        (set! to-add (cons pair to-add))))
                  (hash-table->alist ht2))
        (for-each (lambda (key) (hash-table-delete! ht1 key)) to-delete)
        (for-each (lambda (pair) (hash-table-set! ht1 (car pair) (cdr pair))) to-add)
        ht1))

    ;; --- Comparator access ---

    (define (hash-table-comparator ht)
      "Syntax: (hash-table-comparator ht)
Library: (srfi 125)
Description: Returns the comparator associated with the hash table.
Example:
  (define c (make-default-comparator))
  (define ht (make-hash-table c))
  (comparator? (hash-table-comparator ht)) => #t"
      (%get-comparator ht))

    (define (hash-table-equivalence-function ht)
      "Syntax: (hash-table-equivalence-function ht)
Library: (srfi 125)
Description: Returns the equivalence function of the hash table's comparator.
Example:
  (define ht (make-hash-table (make-default-comparator)))
  (procedure? (hash-table-equivalence-function ht)) => #t"
      (let ((comp (%get-comparator ht)))
        (if comp
            (comparator-equality-predicate comp)
            equal?)))

    (define (hash-table-hash-function ht)
      "Syntax: (hash-table-hash-function ht)
Library: (srfi 125)
Description: Returns the hash function of the hash table's comparator.
Example:
  (define ht (make-hash-table (make-default-comparator)))
  (procedure? (hash-table-hash-function ht)) => #t"
      (let ((comp (%get-comparator ht)))
        (if comp
            (comparator-hash-function comp)
            default-hash)))

    ))

(define-library (srfi 14)
  (import (scheme base) (scheme char))
  (export char-set?
          char-set
          ;; Canonical names
          char-set-contains?
          char-set=
          char-set<=
          ;; Compat aliases
          char-set-member?
          char-set=?
          char-set<=?
          ;; Set operations
          char-set-complement
          char-set-union
          char-set-intersection
          char-set-difference
          char-set-xor
          char-set-diff+intersection
          ;; Adjoin/delete
          char-set-adjoin
          char-set-delete
          ;; Fold/iteration
          char-set-fold
          char-set-for-each
          char-set-map
          ;; Filter
          char-set-filter
          char-set-filter!
          ;; Count/predicates
          char-set-count
          char-set-size
          char-set-every
          char-set-any
          ;; Copy
          char-set-copy
          ;; Hash
          char-set-hash
          ;; Cursors
          char-set-cursor
          char-set-ref
          char-set-cursor-next
          end-of-char-set?
          ;; Conversion
          list->char-set
          list->char-set!
          string->char-set
          string->char-set!
          char-set->list
          char-set->string
          ;; Coercion
          ->char-set
          ;; Unfold
          char-set-unfold
          char-set-unfold!
          ;; UCS range
          ucs-range->char-set
          ucs-range->char-set!
          ;; Mutable aliases (immutable implementation — alias to pure ops)
          char-set-adjoin!
          char-set-delete!
          char-set-complement!
          char-set-union!
          char-set-intersection!
          char-set-difference!
          char-set-xor!
          char-set-diff+intersection!
          ;; Predefined sets
          char-set:letter
          char-set:digit
          char-set:whitespace
          char-set:upper-case
          char-set:lower-case
          char-set:letter+digit
          char-set:punctuation
          char-set:symbol
          char-set:graphic
          char-set:printing
          char-set:blank
          char-set:ascii
          char-set:empty
          char-set:full
          char-set:hex-digit
          char-set:iso-control
          char-set:title-case)
  (begin
    (define-record-type <char-set>
      (%make-char-set pred)
      char-set?
      (pred %char-set-pred))

    (define (char-set . chars)
      #<<END
Syntax: (char-set char ...)
Library: (srfi 14)
Description: Constructs a char-set containing exactly the given chars.
Example:
  (char-set-contains? (char-set #\a #\b) #\a) => #t
  (char-set-contains? (char-set #\a #\b) #\c) => #f
END
      (%make-char-set (lambda (c) (member c chars))))

    ;; --- Internal helpers ---
    (define (%any pred lst)
      (cond ((null? lst) #f)
            ((pred (car lst)) => (lambda (v) v))
            (else (%any pred (cdr lst)))))

    (define (%all pred lst)
      (cond ((null? lst) #t)
            ((not (pred (car lst))) #f)
            (else (%all pred (cdr lst)))))

    (define (%ascii-chars)
      (let loop ((i 0) (result '()))
        (if (= i 128)
            (reverse result)
            (loop (+ i 1) (cons (integer->char i) result)))))

    ;; --- Membership ---

    (define (char-set-contains? cs ch)
      #<<END
Syntax: (char-set-contains? cs ch)
Library: (srfi 14)
Description: Returns #t if the character ch is a member of char-set cs, #f otherwise.
Example:
  (char-set-contains? char-set:digit #\5) => #t
  (char-set-contains? char-set:digit #\a) => #f
END
      (if ((%char-set-pred cs) ch) #t #f))

    ;; Canonical name alias
    (define char-set-member? char-set-contains?)

    ;; --- Equality / Subset ---

    (define (char-set= . sets)
      #<<END
Syntax: (char-set= cs ...)
Library: (srfi 14)
Description: Returns #t if all of the given char-sets contain exactly the same characters.
Example:
  (char-set= (char-set #\a #\b) (char-set #\b #\a)) => #t
  (char-set= (char-set #\a) (char-set #\b)) => #f
END
      (if (or (null? sets) (null? (cdr sets)))
          #t
          (let ((s1 (car sets)) (s2 (cadr sets)))
            (and (%all (lambda (c)
                         (eq? (if ((%char-set-pred s1) c) #t #f)
                              (if ((%char-set-pred s2) c) #t #f)))
                       (%ascii-chars))
                 (apply char-set= (cdr sets))))))

    (define char-set=? char-set=)

    (define (char-set<= . sets)
      #<<END
Syntax: (char-set<= cs ...)
Library: (srfi 14)
Description: Returns #t if every char-set is a subset of the next; i.e., every character
in cs1 is also in cs2, every character in cs2 is also in cs3, and so on.
Example:
  (char-set<= (char-set #\a) (char-set #\a #\b)) => #t
  (char-set<= (char-set #\a #\b) (char-set #\a)) => #f
END
      (if (or (null? sets) (null? (cdr sets)))
          #t
          (let ((s1 (car sets)) (s2 (cadr sets)))
            (and (%all (lambda (c)
                         (or (not ((%char-set-pred s1) c))
                             ((%char-set-pred s2) c)))
                       (%ascii-chars))
                 (apply char-set<= (cdr sets))))))

    (define char-set<=? char-set<=)

    ;; --- Set operations ---

    (define (char-set-complement cs)
      #<<END
Syntax: (char-set-complement cs)
Library: (srfi 14)
Description: Returns a char-set containing all characters NOT in cs.
Example:
  (char-set-contains? (char-set-complement char-set:digit) #\a) => #t
  (char-set-contains? (char-set-complement char-set:digit) #\5) => #f
END
      (%make-char-set (lambda (c) (not ((%char-set-pred cs) c)))))

    (define (char-set-union . sets)
      #<<END
Syntax: (char-set-union cs ...)
Library: (srfi 14)
Description: Returns a char-set containing all characters that appear in any of the given sets.
Example:
  (char-set-contains? (char-set-union (char-set #\a) (char-set #\b)) #\a) => #t
  (char-set-contains? (char-set-union (char-set #\a) (char-set #\b)) #\b) => #t
  (char-set-contains? (char-set-union (char-set #\a) (char-set #\b)) #\c) => #f
END
      (%make-char-set (lambda (c) (%any (lambda (s) ((%char-set-pred s) c)) sets))))

    (define (char-set-intersection . sets)
      #<<END
Syntax: (char-set-intersection cs ...)
Library: (srfi 14)
Description: Returns a char-set containing only characters that appear in all of the given sets.
Example:
  (char-set-contains? (char-set-intersection (char-set #\a #\b) (char-set #\b #\c)) #\b) => #t
  (char-set-contains? (char-set-intersection (char-set #\a #\b) (char-set #\b #\c)) #\a) => #f
END
      (%make-char-set (lambda (c) (%all (lambda (s) ((%char-set-pred s) c)) sets))))

    (define (char-set-difference cs . rest)
      #<<END
Syntax: (char-set-difference cs cs1 ...)
Library: (srfi 14)
Description: Returns a char-set containing the characters in cs that are not in any of the
remaining sets.
Example:
  (char-set-contains? (char-set-difference (char-set #\a #\b #\c) (char-set #\b)) #\a) => #t
  (char-set-contains? (char-set-difference (char-set #\a #\b #\c) (char-set #\b)) #\b) => #f
END
      (%make-char-set
       (lambda (c)
         (and ((%char-set-pred cs) c)
              (%all (lambda (s) (not ((%char-set-pred s) c))) rest)))))

    (define (char-set-xor . sets)
      #<<END
Syntax: (char-set-xor cs ...)
Library: (srfi 14)
Description: Returns the symmetric difference of the given char-sets: characters that appear
in an odd number of the sets (i.e., in one but not both, pairwise applied left to right).
Example:
  (char-set-contains? (char-set-xor (char-set #\a #\b) (char-set #\b #\c)) #\a) => #t
  (char-set-contains? (char-set-xor (char-set #\a #\b) (char-set #\b #\c)) #\b) => #f
  (char-set-contains? (char-set-xor (char-set #\a #\b) (char-set #\b #\c)) #\c) => #t
END
      (if (null? sets)
          char-set:empty
          (let loop ((acc (car sets)) (rest (cdr sets)))
            (if (null? rest)
                acc
                (loop (char-set-difference
                       (char-set-union acc (car rest))
                       (char-set-intersection acc (car rest)))
                      (cdr rest))))))

    (define (char-set-diff+intersection cs1 . rest)
      #<<END
Syntax: (char-set-diff+intersection cs1 cs2 ...)
Library: (srfi 14)
Description: Returns two values: the difference of cs1 and the remaining sets, and the
intersection of cs1 and the remaining sets. Equivalent to calling char-set-difference and
char-set-intersection separately but potentially more efficient.
Example:
  (define-values (d i) (char-set-diff+intersection (char-set #\a #\b #\c) (char-set #\b #\c #\d)))
  (char-set->list d) => (#\a)
  (char-set->list i) => (#\b #\c)
END
      (values (apply char-set-difference cs1 rest)
              (apply char-set-intersection cs1 rest)))

    ;; --- Adjoin / Delete ---

    (define (char-set-adjoin cs . chars)
      #<<END
Syntax: (char-set-adjoin cs char ...)
Library: (srfi 14)
Description: Returns a new char-set that contains all characters in cs plus the given chars.
Example:
  (char-set-contains? (char-set-adjoin char-set:digit #\a) #\a) => #t
  (char-set-contains? (char-set-adjoin char-set:digit #\a) #\5) => #t
END
      (%make-char-set (lambda (c) (or ((%char-set-pred cs) c) (member c chars)))))

    (define (char-set-delete cs . chars)
      #<<END
Syntax: (char-set-delete cs char ...)
Library: (srfi 14)
Description: Returns a new char-set containing all characters in cs except for the given chars.
Example:
  (char-set-contains? (char-set-delete (char-set #\a #\b #\c) #\b) #\a) => #t
  (char-set-contains? (char-set-delete (char-set #\a #\b #\c) #\b) #\b) => #f
END
      (%make-char-set (lambda (c) (and ((%char-set-pred cs) c) (not (member c chars))))))

    ;; --- Fold / Iteration ---

    (define (char-set-fold kons knil cs)
      #<<END
Syntax: (char-set-fold kons knil cs)
Library: (srfi 14)
Description: Folds kons over each character in cs, starting with knil. kons is called as
(kons char accumulator) for each character, returning the new accumulator.
Example:
  (char-set-fold (lambda (c acc) (cons c acc)) '() (char-set #\a #\b)) => (#\a #\b) or (#\b #\a)
  (char-set-fold (lambda (c acc) (+ acc 1)) 0 (char-set #\a #\b)) => 2
END
      (let loop ((chars (%ascii-chars)) (acc knil))
        (cond ((null? chars) acc)
              (((%char-set-pred cs) (car chars))
               (loop (cdr chars) (kons (car chars) acc)))
              (else (loop (cdr chars) acc)))))

    (define (char-set-for-each proc cs)
      #<<END
Syntax: (char-set-for-each proc cs)
Library: (srfi 14)
Description: Applies proc to each character in cs for side effects. The order of iteration
is not specified. Returns an unspecified value.
Example:
  (char-set-for-each display (char-set #\a #\b #\c))
END
      (char-set-fold (lambda (c _) (proc c)) #f cs)
      (if #f #f))

    (define (char-set-map proc cs)
      #<<END
Syntax: (char-set-map proc cs)
Library: (srfi 14)
Description: Applies proc to each character in cs and returns a new char-set containing the
resulting characters.
Example:
  (char-set-contains? (char-set-map char-upcase char-set:lower-case) #\A) => #t
  (char-set-contains? (char-set-map char-upcase char-set:lower-case) #\a) => #f
END
      (%make-char-set
       (lambda (c)
         (char-set-fold (lambda (mapped acc) (or acc (char=? c (proc mapped)))) #f cs))))

    ;; --- Filter ---

    (define (char-set-filter pred cs . rest)
      #<<END
Syntax: (char-set-filter pred cs [base-cs])
Library: (srfi 14)
Description: Returns a char-set containing those characters in cs that satisfy pred. If
base-cs is provided, its characters are included unconditionally in the result.
Example:
  (char-set->list (char-set-filter char-upper-case? char-set:letter)) => (#\A ... #\Z)
  (char-set-contains? (char-set-filter odd? (char-set #\a #\b)) #\a) => depends on char code
END
      (let ((base-cs (if (null? rest) char-set:empty (car rest))))
        (%make-char-set
         (lambda (c) (or ((%char-set-pred base-cs) c)
                         (and ((%char-set-pred cs) c) (pred c)))))))

    (define char-set-filter! char-set-filter)

    ;; --- Count / Size / Predicates ---

    (define (char-set-count pred cs)
      #<<END
Syntax: (char-set-count pred cs)
Library: (srfi 14)
Description: Returns the number of characters in cs that satisfy pred.
Example:
  (char-set-count char-upper-case? char-set:letter) => 26
  (char-set-count char-numeric? (char-set #\1 #\a #\2)) => 2
END
      (char-set-fold (lambda (c acc) (if (pred c) (+ acc 1) acc)) 0 cs))

    (define (char-set-size cs)
      #<<END
Syntax: (char-set-size cs)
Library: (srfi 14)
Description: Returns the total number of characters in cs.
Example:
  (char-set-size (char-set #\a #\b #\c)) => 3
  (char-set-size char-set:empty) => 0
END
      (char-set-fold (lambda (c acc) (+ acc 1)) 0 cs))

    (define (char-set-every pred cs)
      #<<END
Syntax: (char-set-every pred cs)
Library: (srfi 14)
Description: Returns #t if pred returns a true value for every character in cs. Returns #f
as soon as pred returns #f for any character.
Example:
  (char-set-every char-alphabetic? char-set:letter) => #t
  (char-set-every char-upper-case? char-set:letter) => #f
END
      (call-with-current-continuation
        (lambda (return)
          (char-set-fold (lambda (c acc)
                           (or (pred c) (return #f)))
                         #t cs))))

    (define (char-set-any pred cs)
      #<<END
Syntax: (char-set-any pred cs)
Library: (srfi 14)
Description: Applies pred to each character in cs. Returns the first true value pred returns,
or #f if pred returns #f for every character.
Example:
  (char-set-any char-upper-case? char-set:letter) => #t
  (char-set-any char-upper-case? char-set:digit) => #f
END
      (call-with-current-continuation
        (lambda (return)
          (char-set-for-each
           (lambda (c)
             (let ((v (pred c)))
               (when v (return v))))
           cs)
          #f)))

    ;; --- Copy ---

    (define (char-set-copy cs)
      #<<END
Syntax: (char-set-copy cs)
Library: (srfi 14)
Description: Returns a copy of the char-set cs. In this implementation char-sets are
immutable, so this returns a new char-set with the same membership predicate.
Example:
  (char-set= (char-set-copy (char-set #\a #\b)) (char-set #\a #\b)) => #t
END
      (%make-char-set (%char-set-pred cs)))

    ;; --- Hash ---

    (define (char-set-hash cs . rest)
      #<<END
Syntax: (char-set-hash cs [bound])
Library: (srfi 14)
Description: Returns a non-negative integer hash of the char-set cs. If bound is given,
the result is in the range [0, bound); otherwise it is in [0, 2^32).
Example:
  (integer? (char-set-hash char-set:digit)) => #t
  (< (char-set-hash char-set:letter 100) 100) => #t
END
      (let ((bound (if (null? rest) (expt 2 32) (car rest))))
        (modulo (char-set-fold (lambda (c acc) (+ (* acc 31) (char->integer c))) 0 cs)
                bound)))

    ;; --- Cursors ---

    (define (char-set-cursor cs)
      #<<END
Syntax: (char-set-cursor cs)
Library: (srfi 14)
Description: Returns a cursor for iterating over the characters of cs. In this implementation
a cursor is the list of characters in cs.
Example:
  (let ((cur (char-set-cursor (char-set #\a #\b))))
    (char-set-ref (char-set #\a #\b) cur)) => #\a
END
      (char-set->list cs))

    (define (char-set-ref cs cursor)
      #<<END
Syntax: (char-set-ref cs cursor)
Library: (srfi 14)
Description: Returns the character at the current position of cursor within cs.
Example:
  (char-set-ref (char-set #\a) (char-set-cursor (char-set #\a))) => #\a
END
      (car cursor))

    (define (char-set-cursor-next cs cursor)
      #<<END
Syntax: (char-set-cursor-next cs cursor)
Library: (srfi 14)
Description: Advances the cursor to the next character position in cs. Returns the updated
cursor, or an exhausted cursor if there are no more characters.
Example:
  (let* ((cs (char-set #\a #\b))
         (cur (char-set-cursor cs))
         (cur2 (char-set-cursor-next cs cur)))
    (end-of-char-set? cur2)) => #f
END
      (cdr cursor))

    (define (end-of-char-set? cursor)
      #<<END
Syntax: (end-of-char-set? cursor)
Library: (srfi 14)
Description: Returns #t if the cursor is exhausted (there are no more characters to iterate
over), #f otherwise.
Example:
  (end-of-char-set? (char-set-cursor char-set:empty)) => #t
  (end-of-char-set? (char-set-cursor (char-set #\a))) => #f
END
      (null? cursor))

    ;; --- Conversion ---

    (define (char-set->list cs)
      #<<END
Syntax: (char-set->list cs)
Library: (srfi 14)
Description: Returns a list of all characters in cs in ascending code-point order.
Example:
  (char-set->list (char-set #\a #\b #\c)) => (#\a #\b #\c)
  (char-set->list char-set:empty) => ()
END
      (let loop ((chars (%ascii-chars)) (result '()))
        (cond ((null? chars) (reverse result))
              (((%char-set-pred cs) (car chars))
               (loop (cdr chars) (cons (car chars) result)))
              (else (loop (cdr chars) result)))))

    (define (char-set->string cs)
      #<<END
Syntax: (char-set->string cs)
Library: (srfi 14)
Description: Returns a string containing all characters in cs in ascending code-point order.
Example:
  (char-set->string (char-set #\a #\b #\c)) => "abc"
  (string-length (char-set->string char-set:digit)) => 10
END
      (list->string (char-set->list cs)))

    (define (list->char-set chars . rest)
      #<<END
Syntax: (list->char-set char-list [base-cs])
Library: (srfi 14)
Description: Creates a char-set from a list of characters. If base-cs is provided, the
characters of base-cs are included in the result as well.
Example:
  (char-set-contains? (list->char-set '(#\a #\b #\c)) #\b) => #t
  (char-set-contains? (list->char-set '(#\a) (char-set #\b)) #\b) => #t
END
      (let ((base-cs (if (null? rest) #f (car rest))))
        (if base-cs
            (apply char-set-adjoin base-cs chars)
            (apply char-set chars))))

    (define list->char-set! list->char-set)

    (define (string->char-set s . rest)
      #<<END
Syntax: (string->char-set s [base-cs])
Library: (srfi 14)
Description: Creates a char-set containing all characters in string s. If base-cs is
provided, its characters are included in the result as well.
Example:
  (char-set-contains? (string->char-set "hello") #\e) => #t
  (char-set-contains? (string->char-set "abc" (char-set #\d)) #\d) => #t
END
      (apply list->char-set (string->list s) rest))

    (define string->char-set! string->char-set)

    ;; --- Coercion ---

    (define (->char-set x)
      #<<END
Syntax: (->char-set x)
Library: (srfi 14)
Description: Coerces x to a char-set. If x is already a char-set, returns it. If x is a
string, returns a char-set of its characters. If x is a char, returns a char-set containing
just that character.
Example:
  (char-set-contains? (->char-set "abc") #\b) => #t
  (char-set-contains? (->char-set #\a) #\a) => #t
  (char-set? (->char-set char-set:digit)) => #t
END
      (cond ((char-set? x) x)
            ((string? x) (string->char-set x))
            ((char? x) (char-set x))
            (else (error "->char-set: cannot coerce" x))))

    ;; --- Unfold ---

    (define (char-set-unfold p f g seed . rest)
      #<<END
Syntax: (char-set-unfold p f g seed [base-cs])
Library: (srfi 14)
Description: Builds a char-set by unfolding from seed. p is the termination predicate
applied to the seed; if true, the result is returned. f maps the seed to a character to
add. g maps the seed to the next seed. If base-cs is provided, its characters are included.
Example:
  (char-set->list (char-set-unfold (lambda (i) (= i 3)) integer->char (lambda (i) (+ i 1)) 0))
    => (#\nul #\x1 #\x2)
END
      ;; p=termination pred, f=seed->char, g=seed->next-seed
      (let ((base-cs (if (null? rest) char-set:empty (car rest))))
        (let loop ((seed seed) (cs base-cs))
          (if (p seed)
              cs
              (loop (g seed) (char-set-adjoin cs (f seed)))))))

    (define char-set-unfold! char-set-unfold)

    ;; Mutable aliases (strings are immutable in this implementation)

    (define char-set-adjoin!      char-set-adjoin)
    (define char-set-delete!      char-set-delete)
    (define char-set-complement!  char-set-complement)
    (define char-set-union!       char-set-union)
    (define char-set-intersection! char-set-intersection)
    (define char-set-difference!  char-set-difference)
    (define char-set-xor!         char-set-xor)
    (define char-set-diff+intersection! char-set-diff+intersection)

    ;; --- UCS range ---

    (define (ucs-range->char-set lower upper . rest)
      #<<END
Syntax: (ucs-range->char-set lower upper [error? base-cs])
Library: (srfi 14)
Description: Creates a char-set containing characters with Unicode code points in the range
[lower, upper). Code points outside the ASCII range 0-127 are silently clamped. The optional
error? argument is accepted for compatibility but ignored. If base-cs is provided, its
characters are included in the result.
Example:
  (char-set-contains? (ucs-range->char-set 65 91) #\A) => #t
  (char-set-contains? (ucs-range->char-set 65 91) #\a) => #f
  (char-set-size (ucs-range->char-set 48 58)) => 10
END
      ;; error? and base-cs args are optional; clamp to ASCII 0-127
      (let ((base-cs (if (or (null? rest) (null? (cdr rest)))
                         char-set:empty
                         (cadr rest))))
        (let loop ((i (max 0 lower)) (cs base-cs))
          (if (>= i (min upper 128))
              cs
              (loop (+ i 1) (char-set-adjoin cs (integer->char i)))))))

    (define ucs-range->char-set! ucs-range->char-set)

    ;; --- Predefined character sets ---

    (define char-set:letter
      (%make-char-set char-alphabetic?))

    (define char-set:digit
      (%make-char-set char-numeric?))

    (define char-set:whitespace
      (%make-char-set char-whitespace?))

    (define char-set:upper-case
      (%make-char-set char-upper-case?))

    (define char-set:lower-case
      (%make-char-set char-lower-case?))

    (define char-set:letter+digit
      (%make-char-set (lambda (c) (or (char-alphabetic? c) (char-numeric? c)))))

    ;; ASCII punctuation: ! " # % & ' ( ) * , - . / : ; ? @ [ \ ] _ ` { }
    (define char-set:punctuation
      (%make-char-set
       (lambda (c)
         (let ((n (char->integer c)))
           (or (= n 33)                          ; !
               (= n 34)                          ; "
               (= n 35)                          ; #
               (= n 37)                          ; %
               (= n 38)                          ; &
               (= n 39)                          ; '
               (= n 40)                          ; (
               (= n 41)                          ; )
               (= n 42)                          ; *
               (= n 44)                          ; ,
               (= n 45)                          ; -
               (= n 46)                          ; .
               (= n 47)                          ; /
               (= n 58)                          ; :
               (= n 59)                          ; ;
               (= n 63)                          ; ?
               (= n 64)                          ; @
               (= n 91)                          ; [
               (= n 92)                          ; \
               (= n 93)                          ; ]
               (= n 95)                          ; _
               (= n 96)                          ; `
               (= n 123)                         ; {
               (= n 125))))))                    ; }

    ;; ASCII symbols: $ + < = > ^ | ~
    (define char-set:symbol
      (%make-char-set
       (lambda (c)
         (let ((n (char->integer c)))
           (or (= n 36)                          ; $
               (= n 43)                          ; +
               (= n 60)                          ; <
               (= n 61)                          ; =
               (= n 62)                          ; >
               (= n 94)                          ; ^
               (= n 124)                         ; |
               (= n 126))))))                    ; ~

    (define char-set:graphic
      (%make-char-set
       (lambda (c)
         (let ((n (char->integer c)))
           (and (>= n 33) (<= n 126))))))

    (define char-set:printing
      (%make-char-set
       (lambda (c)
         (let ((n (char->integer c)))
           (and (>= n 32) (<= n 126))))))

    (define char-set:blank
      (%make-char-set
       (lambda (c) (or (char=? c #\space) (char=? c #\tab)))))

    (define char-set:ascii
      (%make-char-set
       (lambda (c) (< (char->integer c) 128))))

    (define char-set:empty
      (%make-char-set (lambda (c) #f)))

    (define char-set:full
      (%make-char-set (lambda (c) #t)))

    (define char-set:hex-digit
      (%make-char-set
       (lambda (c)
         (let ((n (char->integer c)))
           (or (and (>= n 48) (<= n 57))         ; 0-9
               (and (>= n 65) (<= n 70))         ; A-F
               (and (>= n 97) (<= n 102)))))))   ; a-f

    (define char-set:iso-control
      (%make-char-set
       (lambda (c)
         (let ((n (char->integer c)))
           (or (and (>= n 0) (<= n 31))
               (= n 127))))))

    ;; No title-case chars in ASCII
    (define char-set:title-case
      (%make-char-set (lambda (c) #f)))

    ))

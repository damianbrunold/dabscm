(define-library (srfi 1)
  (import (scheme base) (scheme cxr) (srfi 8))
  (export ;; Re-exports from (scheme base)
          cons list pair? null?
          car cdr caar cadr cdar cddr
          list-ref length
          append reverse
          map for-each
          make-list list-copy
          set-car! set-cdr!
          member memq memv
          assoc assq assv
          ;; Re-exports from (scheme cxr)
          caaaar caaadr caaar caadar caaddr caadr
          cadaar cadadr cadar caddar cadddr caddr
          cdaaar cdaadr cdaar cdadar cdaddr cdadr
          cddaar cddadr cddar cdddar cddddr cdddr
          ;; Selectors
          first second third fourth fifth sixth seventh eighth ninth tenth
          ;; filter/find/partition
          filter find partition
          ;; fold-right
          fold-right
          ;; Constructors
          xcons list-tabulate
          ;; List predicates
          proper-list? circular-list? dotted-list? length+
          ;; Core SRFI-1
          fold reduce reduce-right
          any every
          take drop take-right drop-right take! drop-right!
          last last-pair
          split-at split-at!
          concatenate concatenate!
          append! reverse!
          append-map append-map!
          filter-map count list-index
          delete delete! delete-duplicates delete-duplicates!
          remove filter! partition! remove!
          find-tail take-while drop-while take-while!
          span break span! break!
          alist-cons alist-copy alist-delete alist-delete!
          not-pair? null-list?
          cons* make-list iota
          unfold unfold-right
          pair-fold pair-fold-right
          car+cdr list-copy list=
          zip append-reverse append-reverse!
          circular-list
          ;; Unzip
          unzip1 unzip2 unzip3 unzip4 unzip5
          ;; Map variants
          map! map-in-order pair-for-each
          ;; Lset operations
          lset-adjoin lset<= lset= lset-union lset-intersection lset-difference lset-xor
          lset-union! lset-intersection! lset-difference! lset-xor!
          lset-diff+intersection lset-diff+intersection!)
  (begin

    ;; Based on the SRFI-1 reference implementation by Olin Shivers.
    ;; See ACKNOWLEDGMENTS.md for details.

    ;; --- Internal helpers ---

    (define (check-arg pred val caller)
      (if (pred val) val (error "Bad argument" val caller)))

    ;; --- Selectors ---

    (define first (%primitive "first"))
    (define second (%primitive "second"))
    (define (third x)
      "Syntax: (third lst)
Library: (srfi 1)
Description: Returns the third element of lst.
Example:
  (third '(a b c d)) => c"
      (caddr x))
    (define (fourth x)
      "Syntax: (fourth lst)
Library: (srfi 1)
Description: Returns the fourth element of lst.
Example:
  (fourth '(a b c d)) => d"
      (cadddr x))
    (define (fifth x)
      "Syntax: (fifth lst)
Library: (srfi 1)
Description: Returns the fifth element of lst.
Example:
  (fifth '(a b c d e)) => e"
      (car (cddddr x)))
    (define (sixth x)
      "Syntax: (sixth lst)
Library: (srfi 1)
Description: Returns the sixth element of lst.
Example:
  (sixth '(a b c d e f)) => f"
      (cadr (cddddr x)))
    (define (seventh x)
      "Syntax: (seventh lst)
Library: (srfi 1)
Description: Returns the seventh element of lst.
Example:
  (seventh '(a b c d e f g)) => g"
      (caddr (cddddr x)))
    (define (eighth x)
      "Syntax: (eighth lst)
Library: (srfi 1)
Description: Returns the eighth element of lst.
Example:
  (eighth '(a b c d e f g h)) => h"
      (cadddr (cddddr x)))
    (define (ninth x)
      "Syntax: (ninth lst)
Library: (srfi 1)
Description: Returns the ninth element of lst.
Example:
  (ninth '(a b c d e f g h i)) => i"
      (car (cddddr (cddddr x))))
    (define (tenth x)
      "Syntax: (tenth lst)
Library: (srfi 1)
Description: Returns the tenth element of lst.
Example:
  (tenth '(a b c d e f g h i j)) => j"
      (cadr (cddddr (cddddr x))))

    (define (car+cdr pair)
      "Syntax: (car+cdr p)
Library: (srfi 1)
Description: Returns two values: the car and cdr of pair p. Equivalent to (values (car p) (cdr p)).
Example:
  (car+cdr '(1 2 3)) => 1 and (2 3)"
      (values (car pair) (cdr pair)))

    ;; --- Constructors ---

    (define (xcons d a)
      "Syntax: (xcons d a)
Library: (srfi 1)
Description: Constructs a pair with reversed argument order: (xcons d a) = (cons a d).
Useful for fold-based list construction where the accumulator comes first.
Example:
  (xcons '(2 3) 1) => (1 2 3)
  (fold xcons '() '(1 2 3)) => (3 2 1)"
      (cons a d))

    (define (list-tabulate len proc)
      "Syntax: (list-tabulate n f)
Library: (srfi 1)
Description: Creates a list of n elements by applying f to each index 0, 1, ..., n-1 in order.
Example:
  (list-tabulate 5 (lambda (i) i)) => (0 1 2 3 4)
  (list-tabulate 4 (lambda (i) (* i i))) => (0 1 4 9)"
      (check-arg (lambda (n) (and (integer? n) (>= n 0))) len list-tabulate)
      (check-arg procedure? proc list-tabulate)
      (do ((i (- len 1) (- i 1))
           (ans '() (cons (proc i) ans)))
          ((< i 0) ans)))

    (define (cons* first . rest)
      "Syntax: (cons* elt1 ... obj)
Library: (srfi 1)
Description: Like list* -- constructs a list from the given arguments, using the last argument as
the tail. With one argument, returns that argument.
Example:
  (cons* 1 2 3 '(4 5)) => (1 2 3 4 5)
  (cons* 1) => 1"
      (let recur ((x first) (rest rest))
        (if (pair? rest)
            (cons x (recur (car rest) (cdr rest)))
            x)))

    (define (iota count . maybe-start+step)
      "Syntax: (iota count [start [step]])
Library: (srfi 1)
Description: Returns a list of count numbers starting at start (default 0) with increment step (default 1).
Example:
  (iota 5) => (0 1 2 3 4)
  (iota 5 1) => (1 2 3 4 5)
  (iota 5 0 2) => (0 2 4 6 8)"
      (check-arg integer? count iota)
      (if (< count 0) (error "Negative step count" iota count))
      (let ((start (if (pair? maybe-start+step) (car maybe-start+step) 0))
            (step (if (and (pair? maybe-start+step) (pair? (cdr maybe-start+step)))
                      (cadr maybe-start+step) 1)))
        (check-arg number? start iota)
        (check-arg number? step iota)
        (let loop ((n 0) (r '()))
          (if (= n count)
              (reverse r)
              (loop (+ 1 n)
                    (cons (+ start (* n step)) r))))))

    (define (circular-list val1 . vals)
      "Syntax: (circular-list elt1 ...)
Library: (srfi 1)
Description: Creates a circular list from the given arguments by setting the cdr of the last
pair to point back to the beginning.
Example:
  (take (circular-list 1 2 3) 7) => (1 2 3 1 2 3 1)"
      (let ((ans (cons val1 vals)))
        (set-cdr! (last-pair ans) ans)
        ans))

    ;; --- List predicates ---

    (define (proper-list? x)
      "Syntax: (proper-list? x)
Library: (srfi 1)
Description: Returns #t if x is a proper list (a finite list ending with the empty list).
Uses a fast/slow pointer technique to detect cycles.
Example:
  (proper-list? '(1 2 3)) => #t
  (proper-list? '(1 2 . 3)) => #f
  (proper-list? '()) => #t"
      (let lp ((x x) (lag x))
        (if (pair? x)
            (let ((x (cdr x)))
              (if (pair? x)
                  (let ((x   (cdr x))
                        (lag (cdr lag)))
                    (and (not (eq? x lag)) (lp x lag)))
                  (null? x)))
            (null? x))))

    (define (dotted-list? x)
      "Syntax: (dotted-list? x)
Library: (srfi 1)
Description: Returns #t if x is a dotted list (a finite list ending with a non-null, non-pair value).
A dotted list is one that is neither proper nor circular.
Example:
  (dotted-list? '(1 2 . 3)) => #t
  (dotted-list? '(1 2 3)) => #f
  (dotted-list? 5) => #t"
      (let lp ((x x) (lag x))
        (if (pair? x)
            (let ((x (cdr x)))
              (if (pair? x)
                  (let ((x   (cdr x))
                        (lag (cdr lag)))
                    (and (not (eq? x lag)) (lp x lag)))
                  (not (null? x))))
            (not (null? x)))))

    (define (circular-list? x)
      "Syntax: (circular-list? x)
Library: (srfi 1)
Description: Returns #t if x is a circular list (one that contains a cycle).
Uses a fast/slow pointer technique to detect cycles.
Example:
  (circular-list? (circular-list 1 2 3)) => #t
  (circular-list? '(1 2 3)) => #f"
      (let lp ((x x) (lag x))
        (and (pair? x)
             (let ((x (cdr x)))
               (and (pair? x)
                    (let ((x   (cdr x))
                          (lag (cdr lag)))
                      (or (eq? x lag) (lp x lag))))))))

    (define (not-pair? x)
      "Syntax: (not-pair? x)
Library: (srfi 1)
Description: Returns #t if x is not a pair, #f if it is. Complement of pair?.
Example:
  (not-pair? '()) => #t
  (not-pair? '(1 2)) => #f
  (not-pair? 5) => #t"
      (not (pair? x)))

    (define (null-list? l)
      "Syntax: (null-list? lst)
Library: (srfi 1)
Description: Returns #t if lst is the empty list, #f if it is a pair.
Signals an error if lst is neither null nor a pair.
Example:
  (null-list? '()) => #t
  (null-list? '(1 2)) => #f"
      (cond ((pair? l) #f)
            ((null? l) #t)
            (else (error "null-list?: argument out of domain" l))))

    (define (list= = . lists)
      "Syntax: (list= = lst1 ...)
Library: (srfi 1)
Description: Returns #t if all lists are equal element-by-element using the = predicate.
Lists must have the same length. Returns #t if zero or one list is given.
Example:
  (list= eq? '(a b c) '(a b c)) => #t
  (list= = '(1 2 3) '(1 2 4)) => #f"
      (or (null? lists)
          (let lp1 ((list-a (car lists)) (others (cdr lists)))
            (or (null? others)
                (let ((list-b (car others))
                      (others (cdr others)))
                  (if (eq? list-a list-b)
                      (lp1 list-b others)
                      (let lp2 ((pair-a list-a) (pair-b list-b))
                        (if (null-list? pair-a)
                            (and (null-list? pair-b)
                                 (lp1 list-b others))
                            (and (not (null-list? pair-b))
                                 (= (car pair-a) (car pair-b))
                                 (lp2 (cdr pair-a) (cdr pair-b)))))))))))

    (define (length+ x)
      "Syntax: (length+ lst)
Library: (srfi 1)
Description: Returns the length of lst if it is a proper or dotted list, or #f if lst is circular.
Example:
  (length+ '(1 2 3)) => 3
  (length+ '(1 2 . 3)) => 2
  (length+ (circular-list 1 2)) => #f"
      (let lp ((x x) (lag x) (len 0))
        (if (pair? x)
            (let ((x (cdr x))
                  (len (+ len 1)))
              (if (pair? x)
                  (let ((x   (cdr x))
                        (lag (cdr lag))
                        (len (+ len 1)))
                    (and (not (eq? x lag)) (lp x lag len)))
                  len))
            len)))

    (define (zip list1 . more-lists)
      "Syntax: (zip lst1 ...)
Library: (srfi 1)
Description: Interleaves multiple lists into a list of lists. Each element of the result is a list
of the corresponding elements from each input list. Stops at the shortest list.
Example:
  (zip '(1 2 3) '(a b c)) => ((1 a) (2 b) (3 c))
  (zip '(1 2) '(a b) '(x y)) => ((1 a x) (2 b y))"
      (apply map list list1 more-lists))

    ;; --- take & drop ---

    (define (take lis k)
      "Syntax: (take lst n)
Library: (srfi 1)
Description: Returns a fresh list of the first n elements of lst.
Example:
  (take '(1 2 3 4 5) 3) => (1 2 3)
  (take '(1 2 3) 0) => ()"
      (check-arg integer? k take)
      (let recur ((lis lis) (k k))
        (if (zero? k) '()
            (cons (car lis)
                  (recur (cdr lis) (- k 1))))))

    (define (drop lis k)
      "Syntax: (drop lst n)
Library: (srfi 1)
Description: Returns all but the first n elements of lst.
Example:
  (drop '(1 2 3 4 5) 2) => (3 4 5)
  (drop '(1 2 3) 3) => ()"
      (check-arg integer? k drop)
      (let iter ((lis lis) (k k))
        (if (zero? k) lis (iter (cdr lis) (- k 1)))))

    (define (take! lis k)
      "Syntax: (take! lst n)
Library: (srfi 1)
Description: Destructive version of take. May modify lst to return the first n elements.
Example:
  (take! (list 1 2 3 4 5) 3) => (1 2 3)"
      (check-arg integer? k take!)
      (if (zero? k) '()
          (begin (set-cdr! (drop lis (- k 1)) '())
                 lis)))

    (define (take-right lis k)
      "Syntax: (take-right lst n)
Library: (srfi 1)
Description: Returns the last n elements of lst.
Example:
  (take-right '(1 2 3 4 5) 2) => (4 5)
  (take-right '(1 2 3) 0) => ()"
      (check-arg integer? k take-right)
      (let lp ((lag lis) (lead (drop lis k)))
        (if (pair? lead)
            (lp (cdr lag) (cdr lead))
            lag)))

    (define (drop-right lis k)
      "Syntax: (drop-right lst n)
Library: (srfi 1)
Description: Returns all but the last n elements of lst.
Example:
  (drop-right '(1 2 3 4 5) 2) => (1 2 3)
  (drop-right '(1 2 3) 3) => ()"
      (check-arg integer? k drop-right)
      (let recur ((lag lis) (lead (drop lis k)))
        (if (pair? lead)
            (cons (car lag) (recur (cdr lag) (cdr lead)))
            '())))

    (define (drop-right! lis k)
      "Syntax: (drop-right! lst n)
Library: (srfi 1)
Description: Destructive version of drop-right. May modify lst to return all but the last n elements.
Example:
  (drop-right! (list 1 2 3 4 5) 2) => (1 2 3)"
      (check-arg integer? k drop-right!)
      (let ((lead (drop lis k)))
        (if (pair? lead)
            (let lp ((lag lis) (lead (cdr lead)))
              (if (pair? lead)
                  (lp (cdr lag) (cdr lead))
                  (begin (set-cdr! lag '())
                         lis)))
            '())))

    (define (split-at x k)
      "Syntax: (split-at lst n)
Library: (srfi 1)
Description: Splits lst at index n. Returns two values: the first n elements and the remaining elements.
Example:
  (split-at '(1 2 3 4 5) 2) => (1 2) and (3 4 5)"
      (check-arg integer? k split-at)
      (let recur ((lis x) (k k))
        (if (zero? k) (values '() lis)
            (receive (prefix suffix) (recur (cdr lis) (- k 1))
              (values (cons (car lis) prefix) suffix)))))

    (define (split-at! x k)
      "Syntax: (split-at! lst n)
Library: (srfi 1)
Description: Destructive version of split-at. May modify lst.
Example:
  (split-at! (list 1 2 3 4 5) 2) => (1 2) and (3 4 5)"
      (check-arg integer? k split-at!)
      (if (zero? k) (values '() x)
          (let* ((prev (drop x (- k 1)))
                 (suffix (cdr prev)))
            (set-cdr! prev '())
            (values x suffix))))

    (define (last lis)
      "Syntax: (last lst)
Library: (srfi 1)
Description: Returns the last element of lst. lst must be a non-empty proper list.
Example:
  (last '(1 2 3)) => 3"
      (car (last-pair lis)))

    (define (last-pair lis)
      "Syntax: (last-pair lst)
Library: (srfi 1)
Description: Returns the last pair (the final cons cell) of lst. lst must be a non-empty list.
Example:
  (last-pair '(1 2 3)) => (3)
  (last-pair '(1 2 . 3)) => (2 . 3)"
      (check-arg pair? lis last-pair)
      (let lp ((lis lis))
        (let ((tail (cdr lis)))
          (if (pair? tail) (lp tail) lis))))

    ;; --- Unzippers ---

    (define (unzip1 lis)
      "Syntax: (unzip1 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns a list of the first elements of each sublist.
Example:
  (unzip1 '((1 a) (2 b) (3 c))) => (1 2 3)"
      (map car lis))

    (define (unzip2 lis)
      "Syntax: (unzip2 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns two values: the list of first elements and the list
of second elements from each sublist.
Example:
  (unzip2 '((1 a) (2 b) (3 c))) => (1 2 3) and (a b c)"
      (let recur ((lis lis))
        (if (null-list? lis) (values lis lis)
            (let ((elt (car lis)))
              (receive (a b) (recur (cdr lis))
                (values (cons (car  elt) a)
                        (cons (cadr elt) b)))))))

    (define (unzip3 lis)
      "Syntax: (unzip3 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns three values: the lists of first, second, and third
elements from each sublist.
Example:
  (unzip3 '((1 a x) (2 b y))) => (1 2) and (a b) and (x y)"
      (let recur ((lis lis))
        (if (null-list? lis) (values lis lis lis)
            (let ((elt (car lis)))
              (receive (a b c) (recur (cdr lis))
                (values (cons (car   elt) a)
                        (cons (cadr  elt) b)
                        (cons (caddr elt) c)))))))

    (define (unzip4 lis)
      "Syntax: (unzip4 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns four values: the lists of first through fourth
elements from each sublist.
Example:
  (unzip4 '((1 a x p) (2 b y q))) => (1 2) and (a b) and (x y) and (p q)"
      (let recur ((lis lis))
        (if (null-list? lis) (values lis lis lis lis)
            (let ((elt (car lis)))
              (receive (a b c d) (recur (cdr lis))
                (values (cons (car    elt) a)
                        (cons (cadr   elt) b)
                        (cons (caddr  elt) c)
                        (cons (cadddr elt) d)))))))

    (define (unzip5 lis)
      "Syntax: (unzip5 lsts)
Library: (srfi 1)
Description: Takes a list of lists and returns five values: the lists of first through fifth
elements from each sublist.
Example:
  (unzip5 '((1 a x p i) (2 b y q j))) => (1 2) and (a b) and (x y) and (p q) and (i j)"
      (let recur ((lis lis))
        (if (null-list? lis) (values lis lis lis lis lis)
            (let ((elt (car lis)))
              (receive (a b c d e) (recur (cdr lis))
                (values (cons (car     elt) a)
                        (cons (cadr    elt) b)
                        (cons (caddr   elt) c)
                        (cons (cadddr  elt) d)
                        (cons (car (cddddr elt)) e)))))))

    ;; --- append! append-reverse append-reverse! concatenate concatenate! ---

    (define (append! . lists)
      "Syntax: (append! lst ...)
Library: (srfi 1)
Description: Destructively appends the given lists together by modifying the cdr of each list's last pair.
Returns the concatenated list.
Example:
  (append! (list 1 2) (list 3 4)) => (1 2 3 4)"
      (let lp ((lists lists) (prev '()))
        (if (not (pair? lists)) prev
            (let ((first (car lists))
                  (rest (cdr lists)))
              (if (not (pair? first)) (lp rest first)
                  (let lp2 ((tail-cons (last-pair first))
                            (rest rest))
                    (if (pair? rest)
                        (let ((next (car rest))
                              (rest (cdr rest)))
                          (set-cdr! tail-cons next)
                          (lp2 (if (pair? next) (last-pair next) tail-cons)
                               rest))
                        first)))))))

    (define (append-reverse rev-head tail)
      "Syntax: (append-reverse rev-head tail)
Library: (srfi 1)
Description: Appends (reverse rev-head) to tail. More efficient than (append (reverse rev-head) tail).
Example:
  (append-reverse '(3 2 1) '(4 5)) => (1 2 3 4 5)"
      (let lp ((rev-head rev-head) (tail tail))
        (if (null-list? rev-head) tail
            (lp (cdr rev-head) (cons (car rev-head) tail)))))

    (define (append-reverse! rev-head tail)
      "Syntax: (append-reverse! rev-head tail)
Library: (srfi 1)
Description: Destructive version of append-reverse. May modify rev-head.
Example:
  (append-reverse! (list 3 2 1) '(4 5)) => (1 2 3 4 5)"
      (let lp ((rev-head rev-head) (tail tail))
        (if (null-list? rev-head) tail
            (let ((next-rev (cdr rev-head)))
              (set-cdr! rev-head tail)
              (lp next-rev rev-head)))))

    (define (concatenate lists)
      "Syntax: (concatenate lsts)
Library: (srfi 1)
Description: Appends all lists in lsts together into a single list. Equivalent to (apply append lsts).
Example:
  (concatenate '((1 2) (3 4) (5))) => (1 2 3 4 5)
  (concatenate '()) => ()"
      (reduce-right append '() lists))

    (define (concatenate! lists)
      "Syntax: (concatenate! lsts)
Library: (srfi 1)
Description: Destructive version of concatenate.
Example:
  (concatenate! (list (list 1 2) (list 3 4))) => (1 2 3 4)"
      (reduce-right append! '() lists))

    ;; --- Fold/map internal utilities ---

    ;; Return (map cdr lists).
    ;; However, if any element of LISTS is empty, just abort and return '().
    (define (%cdrs lists)
      (call-with-current-continuation
        (lambda (abort)
          (let recur ((lists lists))
            (if (pair? lists)
                (let ((lis (car lists)))
                  (if (null-list? lis) (abort '())
                      (cons (cdr lis) (recur (cdr lists)))))
                '())))))

    (define (%cars+ lists last-elt)
      (let recur ((lists lists))
        (if (pair? lists) (cons (caar lists) (recur (cdr lists))) (list last-elt))))

    ;; LISTS is a (not very long) non-empty list of lists.
    ;; Return two lists: the cars & the cdrs of the lists.
    ;; However, if any of the lists is empty, just abort and return [() ()].
    (define (%cars+cdrs lists)
      (call-with-current-continuation
        (lambda (abort)
          (let recur ((lists lists))
            (if (pair? lists)
                (receive (list other-lists) (car+cdr lists)
                  (if (null-list? list) (abort '() '())
                      (receive (a d) (car+cdr list)
                        (receive (cars cdrs) (recur other-lists)
                          (values (cons a cars) (cons d cdrs))))))
                (values '() '()))))))

    ;; Like %CARS+CDRS, but we pass in a final elt tacked onto the end of the
    ;; cars list.
    (define (%cars+cdrs+ lists cars-final)
      (call-with-current-continuation
        (lambda (abort)
          (let recur ((lists lists))
            (if (pair? lists)
                (receive (list other-lists) (car+cdr lists)
                  (if (null-list? list) (abort '() '())
                      (receive (a d) (car+cdr list)
                        (receive (cars cdrs) (recur other-lists)
                          (values (cons a cars) (cons d cdrs))))))
                (values (list cars-final) '()))))))

    ;; Like %CARS+CDRS, but blow up if any list is empty.
    (define (%cars+cdrs/no-test lists)
      (let recur ((lists lists))
        (if (pair? lists)
            (receive (list other-lists) (car+cdr lists)
              (receive (a d) (car+cdr list)
                (receive (cars cdrs) (recur other-lists)
                  (values (cons a cars) (cons d cdrs)))))
            (values '() '()))))

    ;; --- count ---

    (define (count pred list1 . lists)
      "Syntax: (count pred lst1 ...)
Library: (srfi 1)
Description: Counts the number of elements in lst1 (and parallel elements in other lists) for which
pred returns true. With multiple lists, pred is applied to parallel elements.
Example:
  (count odd? '(1 2 3 4 5)) => 3
  (count < '(1 2 3) '(2 1 4)) => 2"
      (check-arg procedure? pred count)
      (if (pair? lists)
          (let lp ((list1 list1) (lists lists) (i 0))
            (if (null-list? list1) i
                (receive (as ds) (%cars+cdrs lists)
                  (if (null? as) i
                      (lp (cdr list1) ds
                          (if (apply pred (car list1) as) (+ i 1) i))))))
          (let lp ((lis list1) (i 0))
            (if (null-list? lis) i
                (lp (cdr lis) (if (pred (car lis)) (+ i 1) i))))))

    ;; --- fold/unfold ---

    (define (unfold-right p f g seed . maybe-tail)
      "Syntax: (unfold-right p f g seed [tail])
Library: (srfi 1)
Description: Constructs a list right-to-left by unfolding seed. p is the termination predicate;
f maps seed to an element, g maps seed to the next seed. Optional tail is the initial list
that elements are prepended to (defaults to empty list).
Example:
  (unfold-right zero? (lambda (n) n) (lambda (n) (- n 1)) 5) => (1 2 3 4 5)"
      (check-arg procedure? p unfold-right)
      (check-arg procedure? f unfold-right)
      (check-arg procedure? g unfold-right)
      (let lp ((seed seed) (ans (if (pair? maybe-tail) (car maybe-tail) '())))
        (if (p seed) ans
            (lp (g seed)
                (cons (f seed) ans)))))

    (define (unfold p f g seed . maybe-tail-gen)
      "Syntax: (unfold p f g seed [tail-gen])
Library: (srfi 1)
Description: Constructs a list by unfolding seed. p is the termination predicate; when (p seed) is true,
unfolding stops. f maps seed to the next list element, g maps seed to the next seed.
Optional tail-gen is called on the final seed to produce the tail (defaults to empty list).
Example:
  (unfold (lambda (n) (> n 5)) (lambda (n) n) (lambda (n) (+ n 1)) 1) => (1 2 3 4 5)"
      (check-arg procedure? p unfold)
      (check-arg procedure? f unfold)
      (check-arg procedure? g unfold)
      (if (pair? maybe-tail-gen)
          (let ((tail-gen (car maybe-tail-gen)))
            (let recur ((seed seed))
              (if (p seed) (tail-gen seed)
                  (cons (f seed) (recur (g seed))))))
          (let recur ((seed seed))
            (if (p seed) '()
                (cons (f seed) (recur (g seed)))))))

    (define (fold kons knil lis1 . lists)
      "Syntax: (fold kons knil lst1 ...)
Library: (srfi 1)
Description: Left-associative fold. Applies kons to each element and the accumulated value,
processing from left to right. kons receives (e1 ... acc) where acc starts as knil.
Example:
  (fold + 0 '(1 2 3)) => 6
  (fold cons '() '(1 2 3)) => (3 2 1)"
      (check-arg procedure? kons fold)
      (if (pair? lists)
          (let lp ((lists (cons lis1 lists)) (ans knil))
            (receive (cars+ans cdrs) (%cars+cdrs+ lists ans)
              (if (null? cars+ans) ans
                  (lp cdrs (apply kons cars+ans)))))
          (let lp ((lis lis1) (ans knil))
            (if (null-list? lis) ans
                (lp (cdr lis) (kons (car lis) ans))))))

    (define (fold-right kons knil lis1 . lists)
      "Syntax: (fold-right kons knil lst1 ...)
Library: (srfi 1)
Description: Right-associative fold. Applies kons to each element and the accumulated result,
processing lists from right to left. kons receives (e1 ... acc).
Example:
  (fold-right cons '() '(1 2 3)) => (1 2 3)
  (fold-right + 0 '(1 2 3)) => 6"
      (check-arg procedure? kons fold-right)
      (if (pair? lists)
          (let recur ((lists (cons lis1 lists)))
            (let ((cdrs (%cdrs lists)))
              (if (null? cdrs) knil
                  (apply kons (%cars+ lists (recur cdrs))))))
          (let recur ((lis lis1))
            (if (null-list? lis) knil
                (let ((head (car lis)))
                  (kons head (recur (cdr lis))))))))

    (define (pair-fold-right f zero lis1 . lists)
      "Syntax: (pair-fold-right f knil lst1 ...)
Library: (srfi 1)
Description: Right-associative fold over successive tails (pairs) of lst.
f receives the current tail and the accumulated result; processes right to left.
Example:
  (pair-fold-right cons '() '(1 2 3)) => ((1 2 3) (2 3) (3))"
      (check-arg procedure? f pair-fold-right)
      (if (pair? lists)
          (let recur ((lists (cons lis1 lists)))
            (let ((cdrs (%cdrs lists)))
              (if (null? cdrs) zero
                  (apply f (append! lists (list (recur cdrs)))))))
          (let recur ((lis lis1))
            (if (null-list? lis) zero (f lis (recur (cdr lis)))))))

    (define (pair-fold f zero lis1 . lists)
      "Syntax: (pair-fold f knil lst1 ...)
Library: (srfi 1)
Description: Folds f over the successive tails (pairs) of lst rather than its elements.
f receives the current tail and the accumulator; processes left to right.
Example:
  (pair-fold (lambda (pair acc) (cons (car pair) acc)) '() '(1 2 3)) => (3 2 1)"
      (check-arg procedure? f pair-fold)
      (if (pair? lists)
          (let lp ((lists (cons lis1 lists)) (ans zero))
            (let ((tails (%cdrs lists)))
              (if (null? tails) ans
                  (lp tails (apply f (append! lists (list ans)))))))
          (let lp ((lis lis1) (ans zero))
            (if (null-list? lis) ans
                (let ((tail (cdr lis)))
                  (lp tail (f lis ans)))))))

    ;; REDUCE and REDUCE-RIGHT only use RIDENTITY in the empty-list case.

    (define (reduce f ridentity lis)
      "Syntax: (reduce f ridentity lst)
Library: (srfi 1)
Description: Like fold, but uses the first element of lst as the initial accumulator when lst is non-empty.
If lst is empty, returns ridentity.
Example:
  (reduce + 0 '(1 2 3)) => 6
  (reduce max 0 '(3 1 4 1 5)) => 5
  (reduce + 0 '()) => 0"
      (check-arg procedure? f reduce)
      (if (null-list? lis) ridentity
          (fold f (car lis) (cdr lis))))

    (define (reduce-right f ridentity lis)
      "Syntax: (reduce-right f ridentity lst)
Library: (srfi 1)
Description: Like fold-right, but uses the last element of lst as the initial accumulator when lst is non-empty.
If lst is empty, returns ridentity.
Example:
  (reduce-right + 0 '(1 2 3)) => 6
  (reduce-right cons '() '(1 2 3)) => (1 2 3)
  (reduce-right + 0 '()) => 0"
      (check-arg procedure? f reduce-right)
      (if (null-list? lis) ridentity
          (let recur ((head (car lis)) (lis (cdr lis)))
            (if (pair? lis)
                (f head (recur (car lis) (cdr lis)))
                head))))

    ;; --- Mappers ---

    (define (append-map f lis1 . lists)
      "Syntax: (append-map f lst1 ...)
Library: (srfi 1)
Description: Maps f over lst(s) and appends all resulting lists. f must return a list for each element.
Example:
  (append-map (lambda (x) (list x (* x x))) '(1 2 3)) => (1 1 2 4 3 9)"
      (really-append-map append-map append f lis1 lists))

    (define (append-map! f lis1 . lists)
      "Syntax: (append-map! f lst1 ...)
Library: (srfi 1)
Description: Destructive version of append-map.
Example:
  (append-map! (lambda (x) (list x (* x x))) '(1 2 3)) => (1 1 2 4 3 9)"
      (really-append-map append-map! append! f lis1 lists))

    (define (really-append-map who appender f lis1 lists)
      (check-arg procedure? f who)
      (if (pair? lists)
          (receive (cars cdrs) (%cars+cdrs (cons lis1 lists))
            (if (null? cars) '()
                (let recur ((cars cars) (cdrs cdrs))
                  (let ((vals (apply f cars)))
                    (receive (cars2 cdrs2) (%cars+cdrs cdrs)
                      (if (null? cars2) vals
                          (appender vals (recur cars2 cdrs2))))))))
          (if (null-list? lis1) '()
              (let recur ((elt (car lis1)) (rest (cdr lis1)))
                (let ((vals (f elt)))
                  (if (null-list? rest) vals
                      (appender vals (recur (car rest) (cdr rest)))))))))

    (define (pair-for-each proc lis1 . lists)
      "Syntax: (pair-for-each proc lst1 ...)
Library: (srfi 1)
Description: Like for-each, but proc is called on successive tails (pairs) of the list(s) rather
than on individual elements.
Example:
  (pair-for-each (lambda (p) (display (car p))) '(1 2 3)) ; displays 1 2 3"
      (check-arg procedure? proc pair-for-each)
      (if (pair? lists)
          (let lp ((lists (cons lis1 lists)))
            (let ((tails (%cdrs lists)))
              (if (pair? tails)
                  (begin (apply proc lists)
                         (lp tails)))))
          (let lp ((lis lis1))
            (if (not (null-list? lis))
                (let ((tail (cdr lis)))
                  (proc lis)
                  (lp tail))))))

    ;; We stop when LIS1 runs out, not when any list runs out.
    (define (map! f lis1 . lists)
      "Syntax: (map! f lst1 ...)
Library: (srfi 1)
Description: Destructive map. Applies f to each element of lst (and parallel elements of other lists)
and stores the result back in lst's pairs in place.
Example:
  (let ((l (list 1 2 3))) (map! (lambda (x) (* x x)) l) l) => (1 4 9)"
      (check-arg procedure? f map!)
      (if (pair? lists)
          (let lp ((lis1 lis1) (lists lists))
            (if (not (null-list? lis1))
                (receive (heads tails) (%cars+cdrs/no-test lists)
                  (set-car! lis1 (apply f (car lis1) heads))
                  (lp (cdr lis1) tails))))
          (pair-for-each (lambda (pair) (set-car! pair (f (car pair)))) lis1))
      lis1)

    ;; Map F across L, and save up all the non-false results.
    (define (filter-map f lis1 . lists)
      "Syntax: (filter-map f lst1 ...)
Library: (srfi 1)
Description: Maps f over the list(s) and returns a list of all non-#f results.
Example:
  (filter-map (lambda (x) (and (odd? x) (* x x))) '(1 2 3 4 5)) => (1 9 25)"
      (check-arg procedure? f filter-map)
      (if (pair? lists)
          (let recur ((lists (cons lis1 lists)))
            (receive (cars cdrs) (%cars+cdrs lists)
              (if (pair? cars)
                  (cond ((apply f cars) => (lambda (x) (cons x (recur cdrs))))
                        (else (recur cdrs)))
                  '())))
          (let recur ((lis lis1))
            (if (null-list? lis) lis
                (let ((tail (recur (cdr lis))))
                  (cond ((f (car lis)) => (lambda (x) (cons x tail)))
                        (else tail)))))))

    ;; Map F across lists, guaranteeing to go left-to-right.
    (define (map-in-order f lis1 . lists)
      "Syntax: (map-in-order f lst1 ...)
Library: (srfi 1)
Description: Like map, but guarantees left-to-right evaluation order.
Example:
  (map-in-order (lambda (x) (* x x)) '(1 2 3)) => (1 4 9)"
      (check-arg procedure? f map-in-order)
      (if (pair? lists)
          (let recur ((lists (cons lis1 lists)))
            (receive (cars cdrs) (%cars+cdrs lists)
              (if (pair? cars)
                  (let ((x (apply f cars)))
                    (cons x (recur cdrs)))
                  '())))
          (let recur ((lis lis1))
            (if (null-list? lis) lis
                (let ((tail (cdr lis))
                      (x (f (car lis))))
                  (cons x (recur tail)))))))

    ;; --- filter, remove, partition ---

    ;; This FILTER shares the longest tail of L that has no deleted elements.
    (define (filter pred lis)
      "Syntax: (filter pred lst)
Library: (srfi 1)
Description: Returns a list of all elements in lst that satisfy pred, in order.
Example:
  (filter odd? '(1 2 3 4 5)) => (1 3 5)"
      (check-arg procedure? pred filter)
      (let recur ((lis lis))
        (if (null-list? lis) lis
            (let ((head (car lis))
                  (tail (cdr lis)))
              (if (pred head)
                  (let ((new-tail (recur tail)))
                    (if (eq? tail new-tail) lis
                        (cons head new-tail)))
                  (recur tail))))))

    ;; This implementation of FILTER!
    ;; - doesn't cons, and uses no stack;
    ;; - is careful not to do redundant SET-CDR! writes.
    (define (filter! pred lis)
      "Syntax: (filter! pred lst)
Library: (srfi 1)
Description: Destructive version of filter. Modifies lst in place to retain only elements satisfying pred.
Example:
  (filter! odd? (list 1 2 3 4 5)) => (1 3 5)"
      (check-arg procedure? pred filter!)
      (let lp ((ans lis))
        (cond ((null-list? ans)       ans)
              ((not (pred (car ans))) (lp (cdr ans)))
              (else (letrec ((scan-in (lambda (prev lis)
                                        (if (pair? lis)
                                            (if (pred (car lis))
                                                (scan-in lis (cdr lis))
                                                (scan-out prev (cdr lis))))))
                             (scan-out (lambda (prev lis)
                                         (let lp ((lis lis))
                                           (if (pair? lis)
                                               (if (pred (car lis))
                                                   (begin (set-cdr! prev lis)
                                                          (scan-in lis (cdr lis)))
                                                   (lp (cdr lis)))
                                               (set-cdr! prev lis))))))
                      (scan-in ans (cdr ans))
                      ans)))))

    ;; Answers share common tail with LIS where possible.
    (define (partition pred lis)
      "Syntax: (partition pred lst)
Library: (srfi 1)
Description: Partitions lst into two lists: elements that satisfy pred and elements that do not.
Returns two values: the list of matching elements and the list of non-matching elements, both in order.
Example:
  (partition odd? '(1 2 3 4 5)) => (1 3 5) and (2 4)"
      (check-arg procedure? pred partition)
      (let recur ((lis lis))
        (if (null-list? lis) (values lis lis)
            (let ((elt (car lis))
                  (tail (cdr lis)))
              (receive (in out) (recur tail)
                (if (pred elt)
                    (values (if (pair? out) (cons elt in) lis) out)
                    (values in (if (pair? in) (cons elt out) lis))))))))

    ;; This implementation of PARTITION!
    ;; - doesn't cons, and uses no stack;
    ;; - is careful not to do redundant SET-CDR! writes.
    (define (partition! pred lis)
      "Syntax: (partition! pred lst)
Library: (srfi 1)
Description: Destructive version of partition. Splits lst in place into two lists: elements satisfying
pred and elements not satisfying pred. Returns two values.
Example:
  (partition! odd? (list 1 2 3 4 5)) => (1 3 5) and (2 4)"
      (check-arg procedure? pred partition!)
      (if (null-list? lis) (values lis lis)
          (letrec ((scan-in (lambda (in-prev out-prev lis)
                              (let lp ((in-prev in-prev) (lis lis))
                                (if (pair? lis)
                                    (if (pred (car lis))
                                        (lp lis (cdr lis))
                                        (begin (set-cdr! out-prev lis)
                                               (scan-out in-prev lis (cdr lis))))
                                    (set-cdr! out-prev lis)))))
                   (scan-out (lambda (in-prev out-prev lis)
                               (let lp ((out-prev out-prev) (lis lis))
                                 (if (pair? lis)
                                     (if (pred (car lis))
                                         (begin (set-cdr! in-prev lis)
                                                (scan-in lis out-prev (cdr lis)))
                                         (lp lis (cdr lis)))
                                     (set-cdr! in-prev lis))))))
            (if (pred (car lis))
                (let lp ((prev-l lis) (l (cdr lis)))
                  (cond ((not (pair? l)) (values lis l))
                        ((pred (car l)) (lp l (cdr l)))
                        (else (scan-out prev-l l (cdr l))
                              (values lis l))))
                (let lp ((prev-l lis) (l (cdr lis)))
                  (cond ((not (pair? l)) (values l lis))
                        ((pred (car l))
                         (scan-in l prev-l (cdr l))
                         (values l lis))
                        (else (lp l (cdr l)))))))))

    (define (remove pred l)
      "Syntax: (remove pred lst)
Library: (srfi 1)
Description: Returns a list of all elements in lst that do not satisfy pred (complement of filter).
Example:
  (remove odd? '(1 2 3 4 5)) => (2 4)"
      (filter (lambda (x) (not (pred x))) l))

    (define (remove! pred l)
      "Syntax: (remove! pred lst)
Library: (srfi 1)
Description: Destructive version of remove. Modifies lst in place to remove all elements satisfying pred.
Example:
  (remove! odd? (list 1 2 3 4 5)) => (2 4)"
      (filter! (lambda (x) (not (pred x))) l))

    ;; --- delete ---

    (define (delete x lis . maybe-=)
      "Syntax: (delete x lst [=])
Library: (srfi 1)
Description: Returns lst with all elements equal to x removed. Uses equal? by default;
an optional = argument specifies the equality predicate.
Example:
  (delete 3 '(1 2 3 4 3)) => (1 2 4)
  (delete \"b\" '(\"a\" \"b\" \"c\") string=?) => (\"a\" \"c\")"
      (let ((= (if (pair? maybe-=) (car maybe-=) equal?)))
        (filter (lambda (y) (not (= x y))) lis)))

    (define (delete! x lis . maybe-=)
      "Syntax: (delete! x lst [=])
Library: (srfi 1)
Description: Destructive version of delete. May modify lst.
Example:
  (delete! 3 (list 1 2 3 4 3)) => (1 2 4)"
      (let ((= (if (pair? maybe-=) (car maybe-=) equal?)))
        (filter! (lambda (y) (not (= x y))) lis)))

    ;; --- delete-duplicates ---

    (define (delete-duplicates lis . maybe-=)
      "Syntax: (delete-duplicates lst [=])
Library: (srfi 1)
Description: Returns lst with duplicate elements removed, preserving the first occurrence of each.
Uses equal? by default; an optional = argument specifies the equality predicate.
Example:
  (delete-duplicates '(1 2 1 3 2 4)) => (1 2 3 4)"
      (let ((elt= (if (pair? maybe-=) (car maybe-=) equal?)))
        (check-arg procedure? elt= delete-duplicates)
        (let recur ((lis lis))
          (if (null-list? lis) lis
              (let* ((x (car lis))
                     (tail (cdr lis))
                     (new-tail (recur (delete x tail elt=))))
                (if (eq? tail new-tail) lis (cons x new-tail)))))))

    (define (delete-duplicates! lis . maybe-=)
      "Syntax: (delete-duplicates! lst [=])
Library: (srfi 1)
Description: Destructive version of delete-duplicates. May modify lst.
Example:
  (delete-duplicates! (list 1 2 1 3 2 4)) => (1 2 3 4)"
      (let ((elt= (if (pair? maybe-=) (car maybe-=) equal?)))
        (check-arg procedure? elt= delete-duplicates!)
        (let recur ((lis lis))
          (if (null-list? lis) lis
              (let* ((x (car lis))
                     (tail (cdr lis))
                     (new-tail (recur (delete! x tail elt=))))
                (if (eq? tail new-tail) lis (cons x new-tail)))))))

    ;; --- alist stuff ---

    (define (alist-cons key datum alist)
      "Syntax: (alist-cons key val alist)
Library: (srfi 1)
Description: Prepends a new (key . val) pair to alist and returns the extended association list.
Example:
  (alist-cons 'a 1 '((b . 2))) => ((a . 1) (b . 2))"
      (cons (cons key datum) alist))

    (define (alist-copy alist)
      "Syntax: (alist-copy alist)
Library: (srfi 1)
Description: Returns a shallow copy of alist with each pair freshly allocated. The keys and values
themselves are not copied.
Example:
  (alist-copy '((a . 1) (b . 2))) => ((a . 1) (b . 2))"
      (map (lambda (elt) (cons (car elt) (cdr elt)))
           alist))

    (define (alist-delete key alist . maybe-=)
      "Syntax: (alist-delete key alist [=])
Library: (srfi 1)
Description: Returns a copy of alist with all entries whose car equals key removed.
Uses equal? by default; an optional = argument specifies the equality predicate.
Example:
  (alist-delete 'b '((a . 1) (b . 2) (b . 3))) => ((a . 1))"
      (let ((= (if (pair? maybe-=) (car maybe-=) equal?)))
        (filter (lambda (elt) (not (= key (car elt)))) alist)))

    (define (alist-delete! key alist . maybe-=)
      "Syntax: (alist-delete! key alist [=])
Library: (srfi 1)
Description: Destructive version of alist-delete. May modify alist.
Example:
  (alist-delete! 'b (list (cons 'a 1) (cons 'b 2))) => ((a . 1))"
      (let ((= (if (pair? maybe-=) (car maybe-=) equal?)))
        (filter! (lambda (elt) (not (= key (car elt)))) alist)))

    ;; --- find, find-tail, take-while, drop-while, span, break, any, every, list-index ---

    (define (find pred list)
      "Syntax: (find pred lst)
Library: (srfi 1)
Description: Returns the first element of lst that satisfies pred, or #f if no such element exists.
Example:
  (find even? '(1 3 4 5)) => 4
  (find even? '(1 3 5)) => #f"
      (cond ((find-tail pred list) => car)
            (else #f)))

    (define (find-tail pred list)
      "Syntax: (find-tail pred lst)
Library: (srfi 1)
Description: Returns the first pair in lst whose car satisfies pred, or #f if no such pair exists.
Example:
  (find-tail even? '(1 3 4 5)) => (4 5)
  (find-tail even? '(1 3 5)) => #f"
      (check-arg procedure? pred find-tail)
      (let lp ((list list))
        (and (not (null-list? list))
             (if (pred (car list)) list
                 (lp (cdr list))))))

    (define (take-while pred lis)
      "Syntax: (take-while pred lst)
Library: (srfi 1)
Description: Returns the longest initial prefix of lst whose elements all satisfy pred.
Example:
  (take-while even? '(2 4 5 6)) => (2 4)
  (take-while even? '(1 2 3)) => ()"
      (check-arg procedure? pred take-while)
      (let recur ((lis lis))
        (if (null-list? lis) '()
            (let ((x (car lis)))
              (if (pred x)
                  (cons x (recur (cdr lis)))
                  '())))))

    (define (drop-while pred lis)
      "Syntax: (drop-while pred lst)
Library: (srfi 1)
Description: Drops leading elements of lst that satisfy pred, returning the remainder.
Example:
  (drop-while even? '(2 4 5 6)) => (5 6)
  (drop-while even? '(2 4 6)) => ()"
      (check-arg procedure? pred drop-while)
      (let lp ((lis lis))
        (if (null-list? lis) '()
            (if (pred (car lis))
                (lp (cdr lis))
                lis))))

    (define (take-while! pred lis)
      "Syntax: (take-while! pred lst)
Library: (srfi 1)
Description: Destructive version of take-while. May modify lst.
Example:
  (take-while! even? (list 2 4 5 6)) => (2 4)"
      (check-arg procedure? pred take-while!)
      (if (or (null-list? lis) (not (pred (car lis)))) '()
          (begin (let lp ((prev lis) (rest (cdr lis)))
                   (if (pair? rest)
                       (let ((x (car rest)))
                         (if (pred x) (lp rest (cdr rest))
                             (set-cdr! prev '())))))
                 lis)))

    (define (span pred lis)
      "Syntax: (span pred lst)
Library: (srfi 1)
Description: Splits lst at the first element not satisfying pred. Returns two values:
the longest initial prefix of elements satisfying pred, and the remainder.
Example:
  (span even? '(2 4 5 6)) => (2 4) and (5 6)"
      (check-arg procedure? pred span)
      (let recur ((lis lis))
        (if (null-list? lis) (values '() '())
            (let ((x (car lis)))
              (if (pred x)
                  (receive (prefix suffix) (recur (cdr lis))
                    (values (cons x prefix) suffix))
                  (values '() lis))))))

    (define (span! pred lis)
      "Syntax: (span! pred lst)
Library: (srfi 1)
Description: Destructive version of span. May modify lst.
Example:
  (span! even? (list 2 4 5 6)) => (2 4) and (5 6)"
      (check-arg procedure? pred span!)
      (if (or (null-list? lis) (not (pred (car lis)))) (values '() lis)
          (let ((suffix (let lp ((prev lis) (rest (cdr lis)))
                          (if (null-list? rest) rest
                              (let ((x (car rest)))
                                (if (pred x) (lp rest (cdr rest))
                                    (begin (set-cdr! prev '())
                                           rest)))))))
            (values lis suffix))))

    (define (break pred lis)
      "Syntax: (break pred lst)
Library: (srfi 1)
Description: Splits lst at the first element satisfying pred. Returns two values:
the longest initial prefix of elements not satisfying pred, and the remainder.
Example:
  (break odd? '(2 4 5 6)) => (2 4) and (5 6)"
      (span (lambda (x) (not (pred x))) lis))

    (define (break! pred lis)
      "Syntax: (break! pred lst)
Library: (srfi 1)
Description: Destructive version of break. May modify lst.
Example:
  (break! odd? (list 2 4 5 6)) => (2 4) and (5 6)"
      (span! (lambda (x) (not (pred x))) lis))

    (define (any pred lis1 . lists)
      "Syntax: (any pred lst1 ...)
Library: (srfi 1)
Description: Applies pred to successive elements of the lists. Returns the first true value
returned by pred, or #f if pred returns #f for all elements. Stops on the first true value.
Example:
  (any odd? '(2 4 5 6)) => #t
  (any odd? '(2 4 6)) => #f
  (any < '(1 2 3) '(2 3 4)) => #t"
      (check-arg procedure? pred any)
      (if (pair? lists)
          (receive (heads tails) (%cars+cdrs (cons lis1 lists))
            (and (pair? heads)
                 (let lp ((heads heads) (tails tails))
                   (receive (next-heads next-tails) (%cars+cdrs tails)
                     (if (pair? next-heads)
                         (or (apply pred heads) (lp next-heads next-tails))
                         (apply pred heads))))))
          (and (not (null-list? lis1))
               (let lp ((head (car lis1)) (tail (cdr lis1)))
                 (if (null-list? tail)
                     (pred head)
                     (or (pred head) (lp (car tail) (cdr tail))))))))

    (define (every pred lis1 . lists)
      "Syntax: (every pred lst1 ...)
Library: (srfi 1)
Description: Applies pred to successive elements of the lists. Returns #t (or the last pred result)
if pred returns true for all elements, or #f as soon as pred returns #f.
Example:
  (every odd? '(1 3 5)) => #t
  (every odd? '(1 2 5)) => #f
  (every < '(1 2 3) '(2 3 4)) => #t"
      (check-arg procedure? pred every)
      (if (pair? lists)
          (receive (heads tails) (%cars+cdrs (cons lis1 lists))
            (or (not (pair? heads))
                (let lp ((heads heads) (tails tails))
                  (receive (next-heads next-tails) (%cars+cdrs tails)
                    (if (pair? next-heads)
                        (and (apply pred heads) (lp next-heads next-tails))
                        (apply pred heads))))))
          (or (null-list? lis1)
              (let lp ((head (car lis1)) (tail (cdr lis1)))
                (if (null-list? tail)
                    (pred head)
                    (and (pred head) (lp (car tail) (cdr tail))))))))

    (define (list-index pred lis1 . lists)
      "Syntax: (list-index pred lst1 ...)
Library: (srfi 1)
Description: Returns the 0-based index of the first element in lst1 (and parallel elements in other lists)
for which pred returns true, or #f if no such element exists.
Example:
  (list-index even? '(1 3 4 5)) => 2
  (list-index < '(1 2 3) '(2 1 4)) => 0"
      (check-arg procedure? pred list-index)
      (if (pair? lists)
          (let lp ((lists (cons lis1 lists)) (n 0))
            (receive (heads tails) (%cars+cdrs lists)
              (and (pair? heads)
                   (if (apply pred heads) n
                       (lp tails (+ n 1))))))
          (let lp ((lis lis1) (n 0))
            (and (not (null-list? lis))
                 (if (pred (car lis)) n (lp (cdr lis) (+ n 1)))))))

    ;; --- Reverse ---

    (define (reverse! lis)
      "Syntax: (reverse! lst)
Library: (srfi 1)
Description: Destructively reverses lst in place by modifying the cdr pointers. Returns the reversed list.
Example:
  (reverse! (list 1 2 3)) => (3 2 1)"
      (let lp ((lis lis) (ans '()))
        (if (null-list? lis) ans
            (let ((tail (cdr lis)))
              (set-cdr! lis ans)
              (lp tail lis)))))

    ;; --- Lists-as-sets ---

    (define (%lset2<= = lis1 lis2) (every (lambda (x) (member x lis2 =)) lis1))

    (define (lset<= = . lists)
      "Syntax: (lset<= = lst ...)
Library: (srfi 1)
Description: Subset test. Returns #t if every element of each list is contained in the next list
(tested with =). In other words, s1 is a subset of s2 is a subset of ...
Example:
  (lset<= eq? '(a b) '(a b c)) => #t
  (lset<= eq? '(a b c) '(a b)) => #f"
      (check-arg procedure? = lset<=)
      (or (not (pair? lists))
          (let lp ((s1 (car lists)) (rest (cdr lists)))
            (or (not (pair? rest))
                (let ((s2 (car rest)) (rest (cdr rest)))
                  (and (or (eq? s2 s1)
                           (%lset2<= = s1 s2))
                       (lp s2 rest)))))))

    (define (lset= = . lists)
      "Syntax: (lset= = lst ...)
Library: (srfi 1)
Description: Returns #t if all given sets contain the same elements (tested with =).
Each pair of adjacent sets must be mutual subsets.
Example:
  (lset= eq? '(a b c) '(c b a)) => #t
  (lset= eq? '(a b c) '(a b)) => #f"
      (define (flip proc) (lambda (x y) (proc y x)))
      (check-arg procedure? = lset=)
      (or (not (pair? lists))
          (let lp ((s1 (car lists)) (rest (cdr lists)))
            (or (not (pair? rest))
                (let ((s2   (car rest))
                      (rest (cdr rest)))
                  (and (or (eq? s1 s2)
                           (and (%lset2<= = s1 s2)
                                (%lset2<= (flip =) s2 s1)))
                       (lp s2 rest)))))))

    (define (lset-adjoin = lis . elts)
      "Syntax: (lset-adjoin = lst elt ...)
Library: (srfi 1)
Description: Adds each elt to lst if it is not already present (tested with =).
Returns the augmented list.
Example:
  (lset-adjoin eq? '(a b c) 'd 'a) => (d a b c)"
      (check-arg procedure? = lset-adjoin)
      (fold (lambda (elt ans) (if (member elt ans =) ans (cons elt ans)))
            lis elts))

    (define (lset-union = . lists)
      "Syntax: (lset-union = lst ...)
Library: (srfi 1)
Description: Returns the union of the given sets (lists), using = to test element equality.
The result contains all elements that appear in at least one of the lists, without duplicates.
Example:
  (lset-union eq? '(a b c) '(b c d)) => (d a b c)"
      (check-arg procedure? = lset-union)
      (reduce (lambda (lis ans)
                (cond ((null? lis) ans)
                      ((null? ans) lis)
                      ((eq? lis ans) ans)
                      (else
                       (fold (lambda (elt ans) (if (any (lambda (x) (= x elt)) ans)
                                                   ans
                                                   (cons elt ans)))
                             ans lis))))
              '() lists))

    (define (lset-union! = . lists)
      "Syntax: (lset-union! = lst ...)
Library: (srfi 1)
Description: Destructive version of lset-union. May modify the input lists.
Example:
  (lset-union! eq? (list 'a 'b) (list 'b 'c)) => (c a b)"
      (check-arg procedure? = lset-union!)
      (reduce (lambda (lis ans)
                (cond ((null? lis) ans)
                      ((null? ans) lis)
                      ((eq? lis ans) ans)
                      (else
                       (pair-fold (lambda (pair ans)
                                    (let ((elt (car pair)))
                                      (if (any (lambda (x) (= x elt)) ans)
                                          ans
                                          (begin (set-cdr! pair ans) pair))))
                                  ans lis))))
              '() lists))

    (define (lset-intersection = lis1 . lists)
      "Syntax: (lset-intersection = lst1 lst2 ...)
Library: (srfi 1)
Description: Returns the intersection of the given sets: elements of lst1 that appear in all
other lists (tested with =).
Example:
  (lset-intersection eq? '(a b c d) '(b c d e) '(c d e f)) => (c d)"
      (check-arg procedure? = lset-intersection)
      (let ((lists (delete lis1 lists eq?)))
        (cond ((any null-list? lists) '())
              ((null? lists)          lis1)
              (else (filter (lambda (x)
                              (every (lambda (lis) (member x lis =)) lists))
                            lis1)))))

    (define (lset-intersection! = lis1 . lists)
      "Syntax: (lset-intersection! = lst1 lst2 ...)
Library: (srfi 1)
Description: Destructive version of lset-intersection. May modify lis1.
Example:
  (lset-intersection! eq? (list 'a 'b 'c) '(b c d)) => (b c)"
      (check-arg procedure? = lset-intersection!)
      (let ((lists (delete lis1 lists eq?)))
        (cond ((any null-list? lists) '())
              ((null? lists)          lis1)
              (else (filter! (lambda (x)
                               (every (lambda (lis) (member x lis =)) lists))
                             lis1)))))

    (define (lset-difference = lis1 . lists)
      "Syntax: (lset-difference = lst1 lst2 ...)
Library: (srfi 1)
Description: Returns the difference of the sets: elements of lst1 that do not appear in any
of the other lists (tested with =).
Example:
  (lset-difference eq? '(a b c d) '(b c)) => (a d)"
      (check-arg procedure? = lset-difference)
      (let ((lists (filter pair? lists)))
        (cond ((null? lists)     lis1)
              ((memq lis1 lists) '())
              (else (filter (lambda (x)
                              (every (lambda (lis) (not (member x lis =)))
                                     lists))
                            lis1)))))

    (define (lset-difference! = lis1 . lists)
      "Syntax: (lset-difference! = lst1 lst2 ...)
Library: (srfi 1)
Description: Destructive version of lset-difference. May modify lis1.
Example:
  (lset-difference! eq? (list 'a 'b 'c 'd) '(b c)) => (a d)"
      (check-arg procedure? = lset-difference!)
      (let ((lists (filter pair? lists)))
        (cond ((null? lists)     lis1)
              ((memq lis1 lists) '())
              (else (filter! (lambda (x)
                               (every (lambda (lis) (not (member x lis =)))
                                      lists))
                             lis1)))))

    (define (lset-xor = . lists)
      "Syntax: (lset-xor = lst ...)
Library: (srfi 1)
Description: Returns the symmetric difference of the given sets: elements that appear in an odd
number of the lists (tested with =).
Example:
  (lset-xor eq? '(a b c d) '(b c d e)) => (e a)"
      (check-arg procedure? = lset-xor)
      (reduce (lambda (b a)
                (receive (a-b a-int-b) (lset-diff+intersection = a b)
                  (cond ((null? a-b)     (lset-difference = b a))
                        ((null? a-int-b) (append b a))
                        (else (fold (lambda (xb ans)
                                      (if (member xb a-int-b =) ans (cons xb ans)))
                                    a-b
                                    b)))))
              '() lists))

    (define (lset-xor! = . lists)
      "Syntax: (lset-xor! = lst ...)
Library: (srfi 1)
Description: Destructive version of lset-xor. May modify the input lists.
Example:
  (lset-xor! eq? (list 'a 'b 'c) (list 'b 'c 'd)) => (d a)"
      (check-arg procedure? = lset-xor!)
      (reduce (lambda (b a)
                (receive (a-b a-int-b) (lset-diff+intersection! = a b)
                  (cond ((null? a-b)     (lset-difference! = b a))
                        ((null? a-int-b) (append! b a))
                        (else (pair-fold (lambda (b-pair ans)
                                           (if (member (car b-pair) a-int-b =) ans
                                               (begin (set-cdr! b-pair ans) b-pair)))
                                         a-b
                                         b)))))
              '() lists))

    (define (lset-diff+intersection = lis1 . lists)
      "Syntax: (lset-diff+intersection = lst1 lst2 ...)
Library: (srfi 1)
Description: Returns two values: the set difference of lst1 minus the other sets, and the
intersection of lst1 with the union of the other sets (tested with =).
Example:
  (lset-diff+intersection eq? '(a b c d) '(b c)) => (a d) and (b c)"
      (check-arg procedure? = lset-diff+intersection)
      (cond ((every null-list? lists) (values lis1 '()))
            ((memq lis1 lists)        (values '() lis1))
            (else (partition (lambda (elt)
                               (not (any (lambda (lis) (member elt lis =))
                                         lists)))
                             lis1))))

    (define (lset-diff+intersection! = lis1 . lists)
      "Syntax: (lset-diff+intersection! = lst1 lst2 ...)
Library: (srfi 1)
Description: Destructive version of lset-diff+intersection. May modify lis1.
Example:
  (lset-diff+intersection! eq? (list 'a 'b 'c 'd) '(b c)) => (a d) and (b c)"
      (check-arg procedure? = lset-diff+intersection!)
      (cond ((every null-list? lists) (values lis1 '()))
            ((memq lis1 lists)        (values '() lis1))
            (else (partition! (lambda (elt)
                                (not (any (lambda (lis) (member elt lis =))
                                          lists)))
                              lis1))))

    ))

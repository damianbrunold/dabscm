;; Bootstrap: bind primitives needed by library.scm
(define car (%primitive "car"))
(define cdr (%primitive "cdr"))
(define caar (%primitive "caar"))
(define cadr (%primitive "cadr"))
(define cons (%primitive "cons"))
(define pair? (%primitive "pair?"))
(define null? (%primitive "null?"))
(define append (%primitive "append"))
(define memq (%primitive "memq"))
(define list-ref (%primitive "list-ref"))
(define eq? (%primitive "eq?"))
(define eqv? (%primitive "eqv?"))
(define equal? (%primitive "equal?"))
(define not (%primitive "not"))
(define error (%primitive "error"))
(define = (%primitive "="))
(define < (%primitive "<"))
(define > (%primitive ">"))
(define + (%primitive "+"))
(define - (%primitive "-"))
(define * (%primitive "*"))
(define quotient (%primitive "quotient"))
(define symbol? (%primitive "symbol?"))
(define number? (%primitive "number?"))
(define boolean? (%primitive "boolean?"))
(define char? (%primitive "char?"))
(define string? (%primitive "string?"))
(define vector? (%primitive "vector?"))
(define vector (%primitive "vector"))
(define vector-ref (%primitive "vector-ref"))
(define vector-set! (%primitive "vector-set!"))
(define vector-length (%primitive "vector-length"))
(define string->symbol (%primitive "string->symbol"))
(define symbol->string (%primitive "symbol->string"))
(define apply (%primitive "apply"))
(define gensym (%primitive "gensym"))
(define call-with-current-continuation (%primitive "call-with-current-continuation"))
(define call-with-values (%primitive "call-with-values"))
(define values (%primitive "values"))
(define read (%primitive "read"))
(define list? (%primitive "list?"))
(define *input-port* (%primitive "*input-port*"))
(define *output-port* (%primitive "*output-port*"))
(define *error-port* (%primitive "*error-port*"))
(define first (%primitive "first"))
(define second (%primitive "second"))
(define length (%primitive "length"))
(define member (%primitive "member"))
(define list (lambda x x))

;; Source location
(define current-source-location (%primitive "current-source-location"))

;; Macro system support primitives
(define syntax->datum (%primitive "syntax->datum"))
(define datum->syntax (%primitive "datum->syntax"))
(define identifier? (%primitive "identifier?"))
(define free-identifier=? (%primitive "free-identifier=?"))
(define bound-identifier=? (%primitive "bound-identifier=?"))
(define generate-temporaries (%primitive "generate-temporaries"))

(define call/cc call-with-current-continuation)

(define (cdar pair)
  "Syntax: (cdar pair)
Library: (scheme base)
Description: Returns the cdr of the car of pair. Equivalent to (cdr (car pair)).
Example:
  (cdar '((1 2) 3)) => (2)"
  (cdr (car pair)))

(define (cddr pair)
  "Syntax: (cddr pair)
Library: (scheme base)
Description: Returns the cdr of the cdr of pair. Equivalent to (cdr (cdr pair)).
Example:
  (cddr '(1 2 3)) => (3)"
  (cdr (cdr pair)))

(define (caddr pair)
  "Syntax: (caddr pair)
Library: (scheme base)
Description: Returns the car of the cdr of the cdr of pair. Equivalent to (car (cdr (cdr pair))). This is the third element of a list.
Example:
  (caddr '(1 2 3)) => 3"
  (car (cdr (cdr pair))))

(define (third pair)
  "Syntax: (third pair)
Library: (scm core)
Description: Returns the third element of a list. Equivalent to (caddr pair).
Example:
  (third '(a b c)) => c"
  (car (cdr (cdr pair))))

;; R7RS auxiliary syntax — must be bound before macros that use them as literals.
;; Their values are irrelevant; only the binding identity matters for


(define-syntax and
  "Syntax: (and expr ...)
Library: (scheme base)
Description: Evaluates expressions left to right. Returns #f if any expression evaluates to #f, otherwise returns the value of the last expression. With no arguments, returns #t.
Example:
  (and 1 2 3) => 3
  (and 1 #f 3) => #f
  (and) => #t"
  (syntax-rules ()
    ((and) #t)
    ((and e) e)
    ((and e1 e2 ...)
     (if e1 (and e2 ...) #f))))

(define-syntax or
  "Syntax: (or expr ...)
Library: (scheme base)
Description: Evaluates expressions left to right. Returns the value of the first expression that is not #f, or #f if all expressions are #f. With no arguments, returns #f.
Example:
  (or #f #f 3) => 3
  (or #f #f #f) => #f
  (or) => #f"
  (syntax-rules ()
    ((or) #f)
    ((or e) e)
    ((or e1 e2 ...)
     (let ((t e1))
       (if t t (or e2 ...))))))

(define (constant? obj)
  "Syntax: (constant? obj)
Library: (scm core)
Description: Returns #t if obj is a self-quoting constant: a number, boolean, character, string, or a quoted datum. Used internally by the quasiquote expander.
Example:
  (constant? 42) => #t
  (constant? 'x) => #f
  (constant? '(quote foo)) => #t"
  (or (number? obj)
      (boolean?  obj)
      (char? obj)
      (string? obj)
      (and (pair? obj)
	   (eq? (car obj) 'quote))))

(define-syntax cond
  "Syntax: (cond (test expr ...) ... (else expr ...))
Library: (scheme base)
Description: Evaluates each test in order. When a test is true, evaluates its associated expressions and returns the last. The else clause matches unconditionally. Supports (test => proc) syntax, which calls proc with the test result.
Example:
  (cond ((= 1 2) 'no) ((= 1 1) 'yes) (else 'other)) => yes
  (cond ((assv 2 '((1 a) (2 b))) => cdr) (else #f)) => (b)"
  (syntax-rules (else =>)
    ((cond (else e1 e2 ...))
     (begin e1 e2 ...))
    ((cond (test => proc) rest ...)
     (let ((tmp test))
       (if tmp (proc tmp) (cond rest ...))))
    ((cond (test) rest ...)
     (or test (cond rest ...)))
    ((cond (test e1 e2 ...) rest ...)
     (if test (begin e1 e2 ...) (cond rest ...)))
    ((cond)
     (if #f #f))))

(define (assq x ls)
  "Syntax: (assq key alist)
Library: (scheme base)
Description: Searches association list alist for a pair whose car is eq? to key. Returns the first matching pair, or #f if none is found.
Example:
  (assq 'b '((a 1) (b 2) (c 3))) => (b 2)
  (assq 'd '((a 1) (b 2))) => #f"
  (cond ((null? ls) #f)
	((eq? x (first (first ls))) (first ls))
	(else (assq x (cdr ls)))))

(define (assv x ls)
  "Syntax: (assv key alist)
Library: (scheme base)
Description: Searches association list alist for a pair whose car is eqv? to key. Returns the first matching pair, or #f if none is found. Similar to assq but uses eqv? for comparison.
Example:
  (assv 2 '((1 a) (2 b) (3 c))) => (2 b)
  (assv 5 '((1 a) (2 b))) => #f"
  (cond ((null? ls) #f)
	((eqv? x (first (first ls))) (first ls))
	(else (assv x (cdr ls)))))

(define (assoc x ls . rest)
  "Syntax: (assoc key alist)
Library: (scheme base)
Description: Searches association list alist for a pair whose car is equal? to key. Returns the first matching pair, or #f if none is found. An optional third argument may supply an alternative comparison procedure.
Example:
  (assoc \"b\" '((\"a\" 1) (\"b\" 2))) => (b 2)
  (assoc 2.0 '((1 a) (2 b)) =) => (2 b)"
  (let ((compare (if (null? rest) equal? (car rest))))
    (let loop ((ls ls))
      (cond ((null? ls) #f)
            ((compare x (first (first ls))) (first ls))
            (else (loop (cdr ls)))))))

(define (vector->list v . args)
  "Syntax: (vector->list vector)
Library: (scheme base)
Description: Returns a newly allocated list containing the elements of vector in order. Optional start and end indices (zero-based, exclusive end) may be supplied to convert a subrange.
Example:
  (vector->list #(a b c)) => (a b c)
  (vector->list #(a b c d) 1 3) => (b c)"
  (let ((start (if (null? args) 0 (car args)))
        (end   (if (or (null? args) (null? (cdr args)))
                   (vector-length v) (cadr args))))
    (let loop ((n (- end 1)) (r '()))
      (if (< n start)
          r
          (loop (- n 1) (cons (vector-ref v n) r))))))


(define (reverse ls)
  "Syntax: (reverse list)
Library: (scheme base)
Description: Returns a newly allocated list containing the elements of list in reverse order.
Example:
  (reverse '(1 2 3)) => (3 2 1)
  (reverse '()) => ()"
  (let loop ((ls ls) (acc '()))
    (if (null? ls)
	acc
	(loop (cdr ls) (cons (car ls) acc)))))

(define-syntax case
  "Syntax: (case key ((datum ...) expr ...) ... (else expr ...))
Library: (scheme base)
Description: Evaluates key, then finds the first clause whose datum list
  contains a value eqv? to the key. Evaluates that clause's expressions and
  returns the last. Supports (datum ... => proc) syntax which calls proc with
  the key value. The else clause matches any key not matched by earlier clauses.
Example:
  (case (* 2 3)
    ((2 3 5 7) 'prime)
    ((1 4 6 8 9) 'composite)) => composite"
  (syntax-rules (else =>)
    ((case expr (else => proc))
     (let ((t expr)) (proc t)))
    ((case expr (else body ...))
     (begin expr body ...))
    ((case expr ((datum ...) => proc) rest ...)
     (let ((t expr))
       (if (memv t '(datum ...)) (proc t) (case t rest ...))))
    ((case expr ((datum ...) body ...) rest ...)
     (let ((t expr))
       (if (memv t '(datum ...)) (begin body ...) (case t rest ...))))
    ((case expr)
     (if #f #f))))

(define-syntax do
  "Syntax: (do ((var init step) ...) (test result ...) body ...)
Library: (scheme base)
Description: Iterates by initializing each var to init, then on each iteration evaluating test: if true, evaluates result expressions and returns the last; otherwise evaluates body expressions and steps each var to the value of its step expression.
Example:
  (do ((i 0 (+ i 1)) (s 0 (+ s i)))
      ((= i 5) s)) => 10"
  (syntax-rules ()
    ((do ((var init step ...) ...) (test result ...) body ...)
     (let loop ((var init) ...)
       (if test
           (begin (if #f #f) result ...)
           (begin body ... (loop (do-step var step ...) ...)))))))

(define-syntax do-step
  (syntax-rules ()
    ((do-step var) var)
    ((do-step var step) step)))

(define-syntax with-values
  "Syntax: (with-values producer consumer)
Library: (scm core)
Description: Calls producer as a thunk and passes its multiple return values to consumer. A convenience wrapper around call-with-values.
Example:
  (with-values (lambda () (values 1 2)) +) => 3"
  (syntax-rules ()
    ((with-values producer consumer)
     (call-with-values (lambda () producer) consumer))))

(define (map f lst . more)
  "Syntax: (map proc list1 list2 ...)
Library: (scheme base)
Description: The lists must be lists, and proc must be a procedure taking as
  many arguments as there are lists and returning a single value. If more than
  one list is given and not all lists have the same length, map terminates when
  the shortest list runs out. Map applies proc element-wise to the elements of
  the lists and returns a list of the results, in order.
Example:
  (map cadr '((a b) (d e) (g h))) => (b e h)
  (map + '(1 2 3) '(4 5 6))      => (5 7 9)"
  (define (any-null? ls)
    (cond ((null? ls) #f)
          ((null? (car ls)) #t)
          (else (any-null? (cdr ls)))))
  (if (null? more)
      (let loop ((lst lst))
        (if (null? lst) '()
            (cons (f (car lst)) (loop (cdr lst)))))
      (let loop ((lists (cons lst more)))
        (if (any-null? lists) '()
            (cons (apply f (map car lists))
                  (loop (map cdr lists)))))))

(define-syntax unless
  "Syntax: (unless test body ...)
Library: (scheme base)
Description: Evaluates test. If the result is #f, evaluates each body expression in sequence and returns the last. If the test is true, does nothing and returns an unspecified value.
Example:
  (unless #f (display \"yes\")) => yes
  (unless #t (display \"no\"))  => (nothing printed)"
  (syntax-rules ()
    ((unless test body ...)
     (if (not test) (begin body ...)))))

(define-syntax when
  "Syntax: (when test body ...)
Library: (scheme base)
Description: Evaluates test. If the result is true, evaluates each body expression in sequence and returns the last. If the test is #f, does nothing and returns an unspecified value.
Example:
  (when #t (display \"yes\")) => yes
  (when #f (display \"no\"))  => (nothing printed)"
  (syntax-rules ()
    ((when test body ...)
     (if test (begin body ...)))))

(define (min . ls)
  "Syntax: (min x ...)
Library: (scheme base)
Description: Returns the smallest of the given real numbers. Requires at least one argument.
Example:
  (min 3 1 4 1 5) => 1
  (min 0.5 1/2) => 0.5"
  (let loop ((ls ls) (m (car ls)))
    (cond ((null? ls) m)
	  ((< (car ls) m)
	   (loop (cdr ls) (car ls)))
	  (else
	   (loop (cdr ls) m)))))

(define (max . ls)
  "Syntax: (max x ...)
Library: (scheme base)
Description: Returns the largest of the given real numbers. Requires at least one argument.
Example:
  (max 3 1 4 1 5) => 5
  (max -1 -2 -3) => -1"
  (let loop ((ls ls) (m (car ls)))
    (cond ((null? ls) m)
	  ((> (car ls) m)
	   (loop (cdr ls) (car ls)))
	  (else
	   (loop (cdr ls) m)))))

(define (even? n)
  "Syntax: (even? n)
Library: (scheme base)
Description: Returns #t if n is an even integer, #f otherwise.
Example:
  (even? 4) => #t
  (even? 3) => #f"
  (= n (* 2 (quotient n 2))))

(define (odd? n)
  "Syntax: (odd? n)
Library: (scheme base)
Description: Returns #t if n is an odd integer, #f otherwise.
Example:
  (odd? 3) => #t
  (odd? 4) => #f"
  (not (even? n)))

(define (list-tail ls n)
  "Syntax: (list-tail list k)
Library: (scheme base)
Description: Returns the sublist of list obtained by omitting the first k elements. It is an error if list has fewer than k elements.
Example:
  (list-tail '(a b c d) 2) => (c d)
  (list-tail '(a b c) 0) => (a b c)"
  (if (= n 0)
      ls
      (list-tail (cdr ls) (- n 1))))


(define (filter proc lst)
  "Syntax: (filter pred list)
Library: (scheme base)
Description: Returns a newly allocated list containing only the elements of list for which pred returns a true value, preserving the original order.
Example:
  (filter odd? '(1 2 3 4 5)) => (1 3 5)
  (filter string? '(1 \"a\" #t \"b\")) => (a b)"
  (cond ((null? lst) '())
	((proc (car lst)) (cons (car lst) (filter proc (cdr lst))))
	(else (filter proc (cdr lst)))))

(define syntax-error error)

(define *module-search-path* '("."))
(define (module-search-path)
  "Syntax: (module-search-path)
Library: (scm core)
Description: Returns the current list of directory paths searched when loading modules. The default is ('.'). Used by the module loader to locate .sld library files.
Example:
  (module-search-path) => (\".\")"
  *module-search-path*)

(define (module-search-path! path)
  "Syntax: (module-search-path! path)
Library: (scm core)
Description: Sets the module search path to path, which must be a list of directory strings. Subsequent module loads will search these directories.
Example:
  (module-search-path! '(\".\" \"/usr/share/scheme\"))"
  (set! *module-search-path* path))

(define *modules* '())
(define (modules) *modules*)

(define (current-input-port)
  "Syntax: (current-input-port)
Library: (scheme base)
Description: Returns the current default input port. Read operations that do not specify a port use this port. Initially bound to the standard input.
Example:
  (current-input-port) => #<input-port>"
  *input-port*)

(define (current-output-port)
  "Syntax: (current-output-port)
Library: (scheme base)
Description: Returns the current default output port. Write and display operations that do not specify a port use this port. Initially bound to the standard output.
Example:
  (current-output-port) => #<output-port>"
  *output-port*)

(define (current-error-port)
  "Syntax: (current-error-port)
Library: (scheme base)
Description: Returns the current default error output port. Error messages are written to this port. Initially bound to the standard error.
Example:
  (current-error-port) => #<output-port>"
  *error-port*)

(define (set-current-input-port port)
  "Syntax: (set-current-input-port port)
Library: (scm core)
Description: Sets the current default input port to port. Subsequent read operations without an explicit port argument will read from port.
Example:
  (set-current-input-port (open-input-file \"input.txt\"))"
  (set! *input-port* port))

(define (set-current-output-port port)
  "Syntax: (set-current-output-port port)
Library: (scm core)
Description: Sets the current default output port to port. Subsequent write and display operations without an explicit port argument will write to port.
Example:
  (set-current-output-port (open-output-file \"output.txt\"))"
  (set! *output-port* port))

(define (set-current-error-port port)
  "Syntax: (set-current-error-port port)
Library: (scm core)
Description: Sets the current default error port to port. Subsequent error output without an explicit port argument will write to port.
Example:
  (set-current-error-port (open-output-file \"errors.txt\"))"
  (set! *error-port* port))

;; Export public API from (scm core)
;; Primitives declared above are NOT exported — they are internal to scm core.
;; Libraries should use (%primitive "name") or import from their primary library.
(%module-export-bindings '(scm core)
  ;; Core syntax forms
  'quote 'quasiquote 'if 'set! 'begin
  'lambda 'define 'define-syntax
  'let 'let* 'letrec 'letrec*
  'let-syntax 'letrec-syntax 'cond-expand
  ;; Macros / special forms
  'and 'or 'cond 'case
  'do 'when 'unless 'with-values
  'import
  ;; Macro support primitives
  'syntax->datum 'datum->syntax 'identifier?
  'free-identifier=? 'bound-identifier=? 'generate-temporaries
  ;; Functions
  'list
  'cdar 'cddr 'caddr 'third 'constant? 'syntax-error 'call/cc
  'length 'map 'reverse 'filter
  'assq 'assv 'assoc 'vector->list
  'min 'max 'even? 'odd? 'list-tail
  ;; Source location
  'current-source-location
  ;; Module/system
  'module-search-path 'module-search-path! 'modules
  'current-input-port 'current-output-port 'current-error-port
  'set-current-input-port 'set-current-output-port 'set-current-error-port
  ;; Internal primitives
  '%load-module '%primitive)

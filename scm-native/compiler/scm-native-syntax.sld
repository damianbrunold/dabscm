(define-library (scm native syntax)
  (export make-ident
          ident?
          ident-sym
          ident-scopes
          fresh-scope
          wrap
          strip
          add-scope
          flip-scope
          bind!
          resolve
          bound-identifier=?
          free-identifier=?
          ident-name
          make-transformer
          transformer?
          transformer-name
          apply-transformer
          binding-table-entries
          scope-counter-value
          set-scope-counter!
          reset-syntax-state!
          transformer-parts
          rebuild-transformer)
  (import (scheme base)
          (scheme cxr)
          (srfi 1)
          (srfi 69))
  (begin
    ;; Syntax objects in the sets-of-scopes model (Flatt 2016), as in the
    ;; JVM implementation: only identifiers are wrapped; pairs and vectors
    ;; are plain and contain identifiers. A scope set is a sorted list of
    ;; integers.

    (define-record-type ident
      (make-ident sym scopes)
      ident?
      (sym ident-sym)
      (scopes ident-scopes))

    (define (ident-name x) (if (ident? x) (ident-sym x) x))

    (define scope-counter 0)
    (define (fresh-scope)
      (set! scope-counter (+ scope-counter 1))
      scope-counter)

    (define (scope-counter-value) scope-counter)
    (define (set-scope-counter! n) (set! scope-counter n))

    (define (scopes-add s scopes)
      (cond ((null? scopes) (list s))
            ((= s (car scopes)) scopes)
            ((< s (car scopes)) (cons s scopes))
            (else (cons (car scopes) (scopes-add s (cdr scopes))))))

    (define (scopes-flip s scopes)
      (if (memv s scopes) (remv s scopes) (scopes-add s scopes)))

    (define (remv x l) (remove (lambda (y) (eqv? x y)) l))

    (define (subset? a b)
      ;; both sorted
      (cond ((null? a) #t)
            ((null? b) #f)
            ((= (car a) (car b)) (subset? (cdr a) (cdr b)))
            ((> (car a) (car b)) (subset? a (cdr b)))
            (else #f)))

    ;; Wrap a datum: every symbol becomes an identifier with scopes.
    (define (wrap d scopes)
      (cond ((symbol? d) (make-ident d scopes))
            ((pair? d) (cons (wrap (car d) scopes) (wrap (cdr d) scopes)))
            ((vector? d) (vector-map (lambda (x) (wrap x scopes)) d))
            (else d)))

    (define (strip x)
      (cond ((ident? x) (ident-sym x))
            ((pair? x) (cons (strip (car x)) (strip (cdr x))))
            ((vector? x) (vector-map strip x))
            (else x)))

    (define (map-scopes f x)
      (cond ((ident? x) (make-ident (ident-sym x) (f (ident-scopes x))))
            ((pair? x) (cons (map-scopes f (car x)) (map-scopes f (cdr x))))
            ((vector? x) (vector-map (lambda (y) (map-scopes f y)) x))
            (else x)))

    (define (add-scope x s) (map-scopes (lambda (ss) (scopes-add s ss)) x))
    (define (flip-scope x s) (map-scopes (lambda (ss) (scopes-flip s ss)) x))

    ;; --- binding table -------------------------------------------------------
    ;; symbol -> list of (scopes . binding)

    (define table (make-hash-table eq?))

    (define (bind! sym scopes binding)
      (hash-table-set! table sym
                       (cons (cons scopes binding)
                             (remove (lambda (e) (equal? (car e) scopes))
                                     (hash-table-ref/default table sym '())))))

    ;; The binding of identifier id: the one whose scope set is the largest
    ;; subset of id's scopes. #f if unbound.
    (define (resolve id)
      (let ((scopes (ident-scopes id)))
        (let loop ((es (hash-table-ref/default table (ident-sym id) '()))
                   (best #f) (best-size -1))
          (if (null? es)
              (and best (cdr best))
              (let ((e (car es)))
                (if (subset? (car e) scopes)
                    (let ((n (length (car e))))
                      (if (> n best-size)
                          (loop (cdr es) e n)
                          (loop (cdr es) best best-size)))
                    (loop (cdr es) best best-size)))))))

    ;; The table as a list of (symbol (scopes . binding) ...), for the
    ;; expander state that eval needs at run time
    ;; A new program (scmc compiles several in one process, e.g. the native
    ;; test runners and (scm deb webapp)): no bindings and scopes of an
    ;; earlier one. Else they end up in the expander state of a program that
    ;; links eval (all earlier programs' libraries in its executable) and
    ;; its output depends on what was compiled before it.
    (define (reset-syntax-state!)
      (set! table (make-hash-table eq?))
      (set! scope-counter 0))

    (define (binding-table-entries)
      (hash-table-fold table (lambda (sym entries acc) (cons (cons sym entries) acc)) '()))

    (define (bound-identifier=? a b)
      (and (ident? a) (ident? b)
           (eq? (ident-sym a) (ident-sym b))
           (equal? (ident-scopes a) (ident-scopes b))))

    (define (free-identifier=? a b)
      (let ((ba (if (ident? a) (resolve a) #f))
            (bb (if (ident? b) (resolve b) #f)))
        (if (or ba bb)
            (eq? ba bb)
            (eq? (ident-name a) (ident-name b)))))

    ;; --- syntax-rules ----------------------------------------------------------

    (define-record-type transformer
      (%make-transformer name ellipsis literals rules)
      transformer?
      (name transformer-name)
      (ellipsis transformer-ellipsis)
      (literals transformer-literals)
      (rules transformer-rules))

    ;; (name ellipsis literals rules) and back, for the expander state
    (define (transformer-parts t)
      (list (transformer-name t) (transformer-ellipsis t) (transformer-literals t) (transformer-rules t)))
    (define (rebuild-transformer parts) (apply %make-transformer parts))

    ;; spec: the cdr of (syntax-rules ...) as syntax
    (define (make-transformer name spec)
      (let* ((custom (and (pair? spec) (ident? (car spec))))
             (ellipsis (if custom (car spec) #f))
             (spec (if custom (cdr spec) spec))
             (literals (car spec))
             ;; an ellipsis listed among the literals is not an ellipsis
             (ellipsis (if (and (not custom)
                                (any (lambda (l) (eq? (ident-name l) '...)) literals))
                           'none
                           ellipsis)))
        (%make-transformer name ellipsis literals
                           (map (lambda (r) (cons (car r) (cadr r))) (cdr spec)))))

    ;; an ellipsis listed among the literals is a literal (R7RS 4.3.2)
    (define (ellipsis? t x)
      (let ((e (transformer-ellipsis t)))
        (cond ((eq? e 'none) #f)
              ((literal? t x) #f)
              (e (and (ident? x) (bound-identifier=? x e)))
              (else (and (ident? x) (eq? (ident-sym x) '...))))))

    (define (literal? t x)
      (and (ident? x)
           (any (lambda (l) (bound-identifier=? l x)) (transformer-literals t))))

    (define (underscore? t x)
      (and (ident? x) (eq? (ident-sym x) '_) (not (literal? t x))))

    ;; Apply transformer t to form (the whole macro use, as syntax).
    (define (apply-transformer t form)
      (let loop ((rules (transformer-rules t)))
        (if (null? rules)
            (error "no syntax-rules pattern matches" (transformer-name t) (strip form))
            (let ((b (match t (cdar (car rules)) (cdr form) '())))
              (if b
                  (instantiate t (cdr (car rules)) b)
                  (loop (cdr rules)))))))

    ;; Bindings: list of (pattern-variable depth . value); at depth d > 0 the
    ;; value is a list of depth d - 1 values. Returns #f if no match.
    (define (match t p x b)
      (cond ((not b) #f)
            ((ident? p)
             (cond ((literal? t p) (and (ident? x) (free-identifier=? p x) b))
                   ((underscore? t p) b)
                   (else (cons (cons p (cons 0 x)) b))))
            ((pair? p)
             (if (and (pair? (cdr p)) (ellipsis? t (cadr p)))
                 (match-ellipsis t (car p) (cddr p) x b)
                 (and (pair? x)
                      (match t (cdr p) (cdr x) (match t (car p) (car x) b)))))
            ((null? p) (and (null? x) b))
            ((vector? p)
             (and (vector? x) (match t (vector->list p) (vector->list x) b)))
            (else (and (equal? p (strip x)) b))))

    ;; p ... followed by the patterns in rest (a list, possibly dotted)
    (define (match-ellipsis t p rest x b)
      (let* ((min-tail (let count ((r rest) (n 0)) (if (pair? r) (count (cdr r) (+ n 1)) n)))
             (items (let collect ((x x) (acc '()))
                      (if (pair? x) (collect (cdr x) (cons (car x) acc)) (reverse acc))))
             (n (- (length items) min-tail)))
        (and (>= n 0)
             (let* ((matched (map (lambda (item) (match t p item '())) (take items n))))
               (and (every (lambda (m) m) matched)
                    (let ((b2 (fold (lambda (v b)
                                      (cons (cons v (cons (+ 1 (pattern-depth t p v))
                                                          (map (lambda (m) (cddr (assq-var v m))) matched)))
                                            b))
                                    b
                                    (pattern-vars t p))))
                      (match t rest (drop-pairs x n) b2)))))))

    (define (drop-pairs x n) (if (= n 0) x (drop-pairs (cdr x) (- n 1))))

    (define (assq-var v b)
      (find (lambda (e) (bound-identifier=? (car e) v)) b))

    ;; pattern variables of pattern p
    (define (pattern-vars t p)
      (cond ((ident? p) (if (or (literal? t p) (underscore? t p) (ellipsis? t p)) '() (list p)))
            ((pair? p) (append (pattern-vars t (car p)) (pattern-vars t (cdr p))))
            ((vector? p) (pattern-vars t (vector->list p)))
            (else '())))

    ;; depth of v within p
    (define (pattern-depth t p v)
      (let walk ((p p) (d 0))
        (cond ((ident? p) (if (bound-identifier=? p v) d #f))
              ((pair? p)
               (if (and (pair? (cdr p)) (ellipsis? t (cadr p)))
                   (or (walk (car p) (+ d 1)) (walk (cddr p) d))
                   (or (walk (car p) d) (walk (cdr p) d))))
              ((vector? p) (walk (vector->list p) d))
              (else #f))))

    (define (instantiate t tmpl b)
      (cond ((ident? tmpl)
             (let ((e (assq-var tmpl b)))
               (cond ((not e) tmpl)
                     ((= (cadr e) 0) (cddr e))
                     (else (error "pattern variable used without ellipsis" (ident-sym tmpl))))))
            ((pair? tmpl)
             (cond ((and (ellipsis? t (car tmpl)) (pair? (cdr tmpl)))
                    ;; (... template): ellipses in template are literal
                    (instantiate-escaped (cadr tmpl) b))
                   ((and (pair? (cdr tmpl)) (ellipsis? t (cadr tmpl)))
                    ;; element followed by one or more ellipses
                    (let loop ((rest (cddr tmpl)) (depth 1))
                      (if (and (pair? rest) (ellipsis? t (car rest)))
                          (loop (cdr rest) (+ depth 1))
                          (append (instantiate-ellipsis t (car tmpl) b depth)
                                  (instantiate t rest b)))))
                   (else (cons (instantiate t (car tmpl) b) (instantiate t (cdr tmpl) b)))))
            ((vector? tmpl) (list->vector (instantiate t (vector->list tmpl) b)))
            (else tmpl)))

    (define (instantiate-escaped tmpl b)
      (instantiate (%make-transformer 'escape 'none '() '()) tmpl b))

    ;; The expansions of tmpl followed by depth ellipses, as a list
    (define (instantiate-ellipsis t tmpl b depth)
      ;; the innermost binding of each variable (b also holds the shadowed
      ;; bindings of the enclosing ellipsis levels)
      (let* ((vars (filter (lambda (e) (and (> (cadr e) 0) (occurs? (car e) tmpl)))
                           (innermost b))))
        (when (null? vars)
          (error "no pattern variable with ellipsis depth in template" (strip tmpl)))
        (let* ((len (apply min (map (lambda (e) (length (cddr e))) vars)))
               (items
                (map (lambda (i)
                       (append (map (lambda (e) (cons (car e) (cons (- (cadr e) 1) (list-ref (cddr e) i))))
                                    vars)
                               b))
                     (iota len))))
          (if (= depth 1)
              (map (lambda (b2) (instantiate t tmpl b2)) items)
              (append-map (lambda (b2) (instantiate-ellipsis t tmpl b2 (- depth 1))) items)))))

    (define (innermost b)
      (let loop ((b b) (acc '()))
        (cond ((null? b) (reverse acc))
              ((find (lambda (e) (bound-identifier=? (car e) (car (car b)))) acc) (loop (cdr b) acc))
              (else (loop (cdr b) (cons (car b) acc))))))

    (define (occurs? v tmpl)
      (cond ((ident? tmpl) (bound-identifier=? v tmpl))
            ((pair? tmpl) (or (occurs? v (car tmpl)) (occurs? v (cdr tmpl))))
            ((vector? tmpl) (occurs? v (vector->list tmpl)))
            (else #f)))))

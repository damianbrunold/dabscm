(define-library (scm native anf)
  (export anf
          simple?
          leaf-call?
          set-leaf-primitives!)
  (import (scheme base)
          (scheme cxr)
          (srfi 1)
          (scm native ast))
  (begin
    ;; A-normal form. Afterwards:
    ;;   * the operator and operands of call and prim are simple
    ;;   * the test of if is simple
    ;;   * the right-hand side of lset/gset/gdef is simple
    ;;   * all but the last expression of seq are simple
    ;;   * a let binds one variable when its right-hand side is complex
    ;; A complex expression (one that contains a call outside a lambda) is
    ;; then only found in tail position or as the right-hand side of a let,
    ;; which is where the emitter splits code at a non-tail call.
    ;; Expressions without effect in a non-last seq position are dropped.

    ;; Primitives that never collect and never call Scheme: the emitter calls
    ;; them directly, so a call of one with simple arguments is simple
    (define leaf-primitives '())
    (define (set-leaf-primitives! names) (set! leaf-primitives names))
    (define (leaf-call? e)
      (and (eq? (node-kind e) 'call)
           (eq? (node-kind (cadr e)) 'primref)
           (memq (cadr (cadr e)) leaf-primitives)
           #t))

    (define (simple? e)
      (case (node-kind e)
        ((const lref gref primref lambda) #t)
        ((call) (and (leaf-call? e) (every simple? (cddr e))))
        ((prim) (every simple? (cddr e)))
        ((if seq) (every simple? (cdr e)))
        ((lset gset gdef) (simple? (caddr e)))
        ((let) (and (every (lambda (b) (simple? (cadr b))) (cadr e))
                    (simple? (caddr e))))
        ((letrec) (simple? (caddr e)))
        (else (error "simple?: unknown node" e))))

    (define (anf e)
      (case (node-kind e)
        ((const lref gref primref) e)
        ((lambda)
         (let ((l (cadr e)))
           (lam-body-set! l (anf (lam-body l)))
           e))
        ((lset gset gdef)
         (name (anf (caddr e)) (lambda (a) (list (car e) (cadr e) a))))
        ((if)
         (name (anf (cadr e))
               (lambda (test) `(if ,test ,(anf (caddr e)) ,(anf (cadddr e))))))
        ((seq)
         (let loop ((es (cdr e)))
           (let ((first (anf (car es))))
             (cond ((null? (cdr es)) first)
                   ((effect-free? first) (loop (cdr es)))
                   ((simple? first)
                    (let ((rest (loop (cdr es))))
                      (if (eq? (node-kind rest) 'seq)
                          `(seq ,first ,@(cdr rest))
                          `(seq ,first ,rest))))
                   (else `(let ((,(new-var) ,first)) ,(loop (cdr es))))))))
        ((call)
         (name* (map anf (cdr e)) (lambda (as) (cons 'call as))))
        ((prim)
         (name* (map anf (cddr e)) (lambda (as) `(prim ,(cadr e) ,@as))))
        ((let)
         (let* ((bindings (map (lambda (b) (list (car b) (anf (cadr b)))) (cadr e)))
                (body (anf (caddr e))))
           (if (every (lambda (b) (simple? (cadr b))) bindings)
               `(let ,bindings ,body)
               (fold-right (lambda (b inner) `(let (,b) ,inner)) body bindings))))
        ((letrec)
         (for-each (lambda (b) (anf (cadr b))) (cadr e))
         `(letrec ,(cadr e) ,(anf (caddr e))))
        (else (error "anf: unknown node" e))))

    (define (effect-free? e)
      (memq (node-kind e) '(const lref primref lambda)))

    ;; Give e a name when it is complex: k receives a simple expression.
    (define (name e k)
      (if (simple? e)
          (k e)
          (let ((v (new-var)))
            `(let ((,v ,e)) ,(k `(lref ,v))))))

    (define (name* es k)
      (if (null? es)
          (k '())
          (name (car es)
                (lambda (a) (name* (cdr es) (lambda (as) (k (cons a as))))))))))

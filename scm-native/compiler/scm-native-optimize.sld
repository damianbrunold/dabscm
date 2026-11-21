(define-library (scm native optimize)
  (export optimize
          open-coded-arity)
  (import (scheme base)
          (scheme cxr)
          (srfi 1)
          (srfi 69)
          (scm native ast)
          (scm native expand))
  (begin
    ;; Simple whole-program rewrites before ANF (Phase 2; the real optimizer
    ;; is Phase 3):
    ;;   * a global defined exactly once, to a primitive, and never assigned
    ;;     (such as car in (scheme base)) is replaced by the primitive
    ;;   * calls of primitives with the right arity become open-coded prim
    ;;     nodes; arithmetic with more arguments is folded

    (define open-coded
      '((car . 1) (cdr . 1) (cons . 2) (set-car! . 2) (set-cdr! . 2)
        (pair? . 1) (null? . 1) (not . 1) (eq? . 2) (eqv? . 2)
        (+ . 2) (- . 2) (* . 2) (< . 2) (> . 2) (<= . 2) (>= . 2) (= . 2)
        (zero? . 1) (vector-ref . 2) (vector-set! . 3) (vector-length . 1)
        (char->integer . 1)))

    (define (open-coded-arity op)
      (let ((p (assq op open-coded)))
        (and p (cdr p))))

    ;; modules: list of (name . body); the aliases are found over all of them
    (define (optimize modules)
      (let ((aliases (primitive-aliases `(seq ,@(map cdr modules)))))
        (map (lambda (m) (cons (car m) (rewrite (cdr m) aliases))) modules)))

    ;; glob -> primitive name, for globals that are constant primitives
    (define (primitive-aliases ast)
      (let ((defs (make-hash-table eq?)))
        (let walk ((e ast))
          (case (node-kind e)
            ((gdef)
             (hash-table-set! defs (cadr e)
                              (cons (caddr e) (hash-table-ref/default defs (cadr e) '())))
             (walk (caddr e)))
            ((const lref gref primref) #t)
            ((lset gset) (walk (caddr e)))
            ((lambda) (walk (lam-body (cadr e))))
            ((if seq call) (for-each walk (cdr e)))
            ((prim) (for-each walk (cddr e)))
            ((let letrec) (for-each (lambda (b) (walk (cadr b))) (cadr e)) (walk (caddr e)))
            (else (error "primitive-aliases: unknown node" e))))
        (let ((aliases (make-hash-table eq?)))
          (hash-table-walk defs
                           (lambda (g rhss)
                             (when (and (= (length rhss) 1)
                                        (eq? (node-kind (car rhss)) 'primref)
                                        (not (glob-assigned? g)))
                               (hash-table-set! aliases g (cadr (car rhss))))))
          aliases)))

    (define (rewrite e aliases)
      (define (r e) (rewrite e aliases))
      (case (node-kind e)
        ((const lref primref) e)
        ((gref)
         (let ((p (hash-table-ref/default aliases (cadr e) #f)))
           (if p `(primref ,p) e)))
        ((gdef gset lset) (list (car e) (cadr e) (r (caddr e))))
        ((lambda)
         (lam-body-set! (cadr e) (r (lam-body (cadr e))))
         e)
        ((if seq) (cons (car e) (map r (cdr e))))
        ((prim) `(prim ,(cadr e) ,@(map r (cddr e))))
        ((call)
         (let ((f (r (cadr e)))
               (args (map r (cddr e))))
           (or (and (eq? (node-kind f) 'primref) (open-code (cadr f) args))
               `(call ,f ,@args))))
        ((let letrec)
         `(,(car e) ,(map (lambda (b) (list (car b) (r (cadr b)))) (cadr e)) ,(r (caddr e))))
        (else (error "rewrite: unknown node" e))))

    (define (open-code op args)
      (let ((arity (open-coded-arity op))
            (n (length args)))
        (cond ((not arity) #f)
              ((= n arity) `(prim ,op ,@args))
              ((and (memq op '(+ * -)) (> n 2))
               (fold (lambda (a acc) `(prim ,op ,acc ,a)) `(prim ,op ,(car args) ,(cadr args)) (cddr args)))
              ((and (eq? op '-) (= n 1)) `(prim - (const 0) ,(car args)))
              ((and (eq? op '+) (= n 0)) '(const 0))
              ((and (eq? op '*) (= n 0)) '(const 1))
              ((and (memq op '(+ *)) (= n 1) ) #f)
              (else #f))))))

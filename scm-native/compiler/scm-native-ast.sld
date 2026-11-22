(define-library (scm native ast)
  (export make-var
          var?
          var-name
          var-id
          var-assigned?
          var-assigned!
          make-lam
          lam?
          lam-params
          lam-rest
          lam-body
          lam-body-set!
          lam-free
          lam-free-set!
          lam-name
          lam-id
          fresh-id
          new-var
          node-kind
          var-union
          var-diff
          refs
          compute-free!
          the-unspecified
          unspecified?
          lam-doc
          lam-doc-set!
          make-astral-char
          astral-char?
          astral-char-code)
  (import (scheme base)
          (srfi 1)
          (srfi 69))
  (begin
    ;; Core IR. Variables are records (unique by identity); nodes are lists:
    ;;   (const datum)            (lref var)        (lset var e)
    ;;   (gref name)              (gset name e)     (gdef name e)
    ;;   (if e e e)               (seq e ...)
    ;;   (lambda lam)             (call f e ...)    (prim op e ...)
    ;;   (primref name)           a primitive procedure
    ;;   (let ((var e) ...) e)    (letrec ((var lambda-node) ...) e)
    ;; prim nodes are open-coded operations; calls of other primitives are
    ;; (call (gref name) ...).

    (define-record-type var
      (%make-var name id assigned)
      var?
      (name var-name)
      (id var-id)
      (assigned var-assigned? set-var-assigned!))

    (define (var-assigned! v) (set-var-assigned! v #t))

    ;; The datum of (const the-unspecified), the value of (if #f #f)
    (define-record-type unspecified-type
      (make-unspecified)
      unspecified?)
    (define the-unspecified (make-unspecified))

    ;; The docstrings of lambdas (for procedure-doc): the first form of the
    ;; body, if it is a string (as the JVM implementation)
    (define lam-docs (make-hash-table eq?))
    (define (lam-doc l) (hash-table-ref/default lam-docs l #f))
    (define (lam-doc-set! l doc) (hash-table-set! lam-docs l doc))

    ;; A character beyond U+FFFF in the source: the JVM implementation's
    ;; characters are UTF-16 code units, so the compiler (running there)
    ;; reads it as this record (see read-file in (scm native expand))
    (define-record-type astral-char
      (make-astral-char code)
      astral-char?
      (code astral-char-code))

    (define-record-type lam
      (%make-lam params rest body free name id)
      lam?
      (params lam-params)
      (rest lam-rest)
      (body lam-body lam-body-set!)
      (free lam-free lam-free-set!)
      (name lam-name)
      (id lam-id))

    (define counter 0)
    (define (fresh-id)
      (set! counter (+ counter 1))
      counter)

    (define (make-var name) (%make-var name (fresh-id) #f))
    (define (new-var) (make-var 'tmp))

    (define (make-lam params rest body name)
      (%make-lam params rest body '() name (fresh-id)))

    (define (node-kind e) (car e))

    ;; Sets of variables as lists (Phase 1; small sets)
    (define (var-union a b)
      (fold (lambda (v acc) (if (memq v acc) acc (cons v acc))) a b))
    (define (var-diff a b)
      (remove (lambda (v) (memq v b)) a))

    ;; Local variables referenced by e (free in e). Needs compute-free! first
    ;; for nested lambdas.
    (define (refs e)
      (case (node-kind e)
        ((const gref primref) '())
        ((lref) (list (cadr e)))
        ((lset) (var-union (list (cadr e)) (refs (caddr e))))
        ((gset gdef) (refs (caddr e)))
        ((lambda) (lam-free (cadr e)))
        ((if seq call)
         (fold (lambda (x acc) (var-union (refs x) acc)) '() (cdr e)))
        ((prim)
         (fold (lambda (x acc) (var-union (refs x) acc)) '() (cddr e)))
        ((let letrec)
         (let ((bound (map car (cadr e))))
           (var-union
            (if (eq? (node-kind e) 'letrec)
                (var-diff (fold (lambda (b acc) (var-union (refs (cadr b)) acc)) '() (cadr e))
                          bound)
                (fold (lambda (b acc) (var-union (refs (cadr b)) acc)) '() (cadr e)))
            (var-diff (refs (caddr e)) bound))))
        (else (error "refs: unknown node" e))))

    ;; Compute the free variables of every lambda, innermost first.
    (define (compute-free! e)
      (case (node-kind e)
        ((const gref lref primref) #t)
        ((lset gset gdef) (compute-free! (caddr e)))
        ((lambda)
         (let ((l (cadr e)))
           (compute-free! (lam-body l))
           (lam-free-set! l (var-diff (refs (lam-body l))
                                      (if (lam-rest l)
                                          (cons (lam-rest l) (lam-params l))
                                          (lam-params l))))))
        ((if seq call) (for-each compute-free! (cdr e)))
        ((prim) (for-each compute-free! (cddr e)))
        ((let letrec)
         (for-each (lambda (b) (compute-free! (cadr b))) (cadr e))
         (compute-free! (caddr e)))
        (else (error "compute-free!: unknown node" e))))))

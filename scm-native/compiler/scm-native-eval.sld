(define-library (scm native eval)
  (export eval
          environment
          load)
  (import (scheme base)
          (scheme cxr)
          (scheme file)
          (scheme read)
          (srfi 69)
          (scm native ast)
          (scm native expand))
  (begin
    ;; eval and environment for native programs. The program carries the
    ;; expander's state after its compilation (see expander-state in
    ;; (scm native expand)): eval expands code against the linked libraries
    ;; as the compiler did, and runs the Core IR with the interpreter below,
    ;; whose procedures are ordinary procedures of the program. Globals of
    ;; the linked libraries are the program's own cells; libraries that are
    ;; not linked are loaded from their sources (over the compiler's search
    ;; path) and run by the interpreter.

    (define installed #f)

    (define (ensure-installed!)
      (unless installed
        (let ((text ((%primitive "%eval-state"))))
          (unless text (error "eval: the program has no expander state"))
          (install-expander-state! (read (open-input-string text)))
          (set! installed #t))))

    ;; --- environments ------------------------------------------------------

    (define-record-type eval-environment
      (make-eval-environment module)
      eval-environment?
      (module environment-module))

    ;; one environment per list of import sets (as the JVM implementation:
    ;; a definition evaluated in (environment '(scheme base)) is visible in
    ;; the next (environment '(scheme base)))
    (define environments '())

    (define (environment . specs)
      (named-module-environment specs #f))

    ;; name: the module's name in messages, or #f for the first spec's
    (define (named-module-environment specs name)
      (ensure-installed!)
      (cond ((assoc specs environments) => cdr)
            (else
             (let ((m (if name (make-eval-module specs name) (make-eval-module specs))))
               (run-new-modules!)
               (let ((e (make-eval-environment m)))
                 (set! environments (cons (cons specs e) environments))
                 e)))))

    ;; (load file [environment]): evaluates the forms of file in order;
    ;; without an environment in the running module, as the JVM's load:
    ;; the environment of the code being evaluated (a script that scm
    ;; interprets), else the program's own module, so that a loaded
    ;; (define x ...) sets the program's x (a configuration file)
    (define (load file . env)
      (let ((forms (call-with-input-file file
                     (lambda (p)
                       (let loop ((acc '()))
                         (let ((x (read p)))
                           (if (eof-object? x) (reverse acc) (loop (cons x acc))))))))
            (env (cond ((pair? env) env)
                       ((current-eval-environment) => list)
                       (else (list (program-environment))))))
        (for-each (lambda (f) (apply eval f env)) forms)))

    (define the-program-environment #f)

    (define (program-environment)
      (ensure-installed!)
      (or the-program-environment
          (let ((m (program-eval-module)))
            (set! the-program-environment
                  (if m (make-eval-environment m) (named-environment '(user main))))
            the-program-environment)))

    ;; Environment specifiers as the JVM implementation's (null-environment,
    ;; scheme-report-environment, interaction-environment): library names,
    ;; one environment each
    (define named-environments '())

    (define repl-libraries
      '((scheme base) (scheme case-lambda) (scheme char) (scheme complex) (scheme cxr)
        (scheme eval) (scheme file) (scheme inexact) (scheme lazy) (scheme process-context)
        (scheme read) (scheme time) (scheme write)))

    (define (named-environment name)
      (cond ((assoc name named-environments) => cdr)
            (else
             (let ((e (if (member name '((user main) (user program)))
                          (named-module-environment repl-libraries name)
                          (environment name))))
               (set! named-environments (cons (cons name e) named-environments))
               e))))

    (define (eval x . env)
      (let ((e (cond ((null? env) (named-environment '(user main)))
                     ((eval-environment? (car env)) (car env))
                     ((pair? (car env)) (named-environment (car env)))
                     (else (error "eval: not an environment" (car env))))))
        (let ((forms (expand-eval (environment-module e) x)))
          (run-new-modules!)
          (parameterize ((current-eval-environment e))
            (let loop ((forms forms) (result (if #f #f)))
              (if (null? forms)
                  result
                  (loop (cdr forms) ((compile (car forms) '()) '()))))))))

    ;; the environment of the code eval runs, for load
    (define current-eval-environment (make-parameter #f))

    ;; run the bodies of the libraries loaded from source, in order
    (define (run-new-modules!)
      (for-each (lambda (m) ((compile (cdr m) '()) '()))
                (take-new-modules!)))

    ;; --- primitives that need the expander ---------------------------------
    ;; The runtime's macroexpand and bound? call this (the special
    ;; eval_hook) with their name and arguments.
    (define (%eval-hook op . args)
      (ensure-installed!)
      (case op
        ((macroexpand) (macroexpand-datum (car args)))
        ;; bound in the program (its definitions and imports)
        ((bound?)
         (let ((b (program-binding (car args))))
           (cond ((not b) #f)
                 ((eq? (car b) 'global) (global-bound? (cdr b)))
                 (else #t))))
        (else (error "primitive not implemented in dabscm native:" op))))

    (define (global-bound? g)
      (let ((c (glob-cell g)))
        (if (car c)
            (guard (e (#t #f)) ((%primitive "%native-global-ref") (car c)) #t)
            (not (eq? (vector-ref (cdr c) 0) unbound)))))

    ;; --- globals -----------------------------------------------------------

    ;; glob -> (index . #f) for a cell of the program, (#f . box) else
    (define cells (make-hash-table eq?))
    (define unbound (list 'unbound))

    (define (glob-cell g)
      (or (hash-table-ref/default cells g #f)
          (let* ((i (and (installed-glob? g) ((%primitive "%native-global") (glob-name g))))
                 (c (if i (cons i #f) (cons #f (vector unbound)))))
            (hash-table-set! cells g c)
            c)))

    (define (global-getter g)
      (let ((c (glob-cell g)))
        (if (car c)
            (let ((i (car c)) (ref (%primitive "%native-global-ref")))
              (lambda (r) (ref i)))
            (let ((box (cdr c)) (name (glob-name g)))
              (lambda (r)
                (let ((v (vector-ref box 0)))
                  (if (eq? v unbound)
                      (error (string-append name " is not bound"))
                      v)))))))

    (define (global-setter g)
      (let ((c (glob-cell g)))
        (if (car c)
            (let ((i (car c)) (set (%primitive "%native-global-set!")))
              (lambda (v) (set i v)))
            (let ((box (cdr c)))
              (lambda (v) (vector-set! box 0 v))))))

    ;; --- the interpreter ---------------------------------------------------
    ;; Core IR to closures (lambda (r) ...): r is the run-time environment, a
    ;; list of frames (vectors); cenv the compile-time one, a list of lists of
    ;; variables.

    (define (locate v cenv)
      (let loop ((cenv cenv) (depth 0))
        (if (null? cenv)
            (error "eval: unbound local variable" (var-name v))
            (let find ((vs (car cenv)) (i 0))
              (cond ((null? vs) (loop (cdr cenv) (+ depth 1)))
                    ((eq? (car vs) v) (values depth i))
                    (else (find (cdr vs) (+ i 1))))))))

    (define (frame-at r depth)
      (if (= depth 0) (car r) (frame-at (cdr r) (- depth 1))))

    (define (compile e cenv)
      (case (node-kind e)
        ((const)
         (let ((v (if (unspecified? (cadr e)) (if #f #f) (cadr e))))
           (lambda (r) v)))
        ((lref)
         (let-values (((d i) (locate (cadr e) cenv)))
           (case d
             ((0) (lambda (r) (vector-ref (car r) i)))
             ((1) (lambda (r) (vector-ref (cadr r) i)))
             ((2) (lambda (r) (vector-ref (caddr r) i)))
             (else (lambda (r) (vector-ref (frame-at r d) i))))))
        ((lset)
         (let-values (((d i) (locate (cadr e) cenv)))
           (let ((x (compile (caddr e) cenv)))
             (lambda (r) (vector-set! (frame-at r d) i (x r))))))
        ((gref) (global-getter (cadr e)))
        ((gset)
         (let ((set (global-setter (cadr e)))
               (x (compile (caddr e) cenv)))
           (lambda (r) (set (x r)))))
        ;; a definition's value is its name (as the JVM implementation's)
        ((gdef)
         (let ((set (global-setter (cadr e)))
               (x (compile (caddr e) cenv))
               (name (glob-sym (cadr e))))
           (lambda (r) (set (x r)) name)))
        ((primref)
         ;; as in compiled code, a primitive the runtime does not implement is
         ;; an error when it is called
         (let* ((name (cadr e))
                (p (or ((%primitive "%primitive-ref") name)
                       (lambda args (error "primitive not implemented in dabscm native:" name)))))
           (lambda (r) p)))
        ((if)
         (let ((c (compile (cadr e) cenv))
               (t (compile (caddr e) cenv))
               (f (compile (cadddr e) cenv)))
           (lambda (r) (if (c r) (t r) (f r)))))
        ((seq) (compile-seq (map (lambda (x) (compile x cenv)) (cdr e))))
        ((call)
         (let ((f (compile (cadr e) cenv))
               (args (map (lambda (x) (compile x cenv)) (cddr e))))
           (case (length args)
             ((0) (lambda (r) ((f r))))
             ((1) (let ((a (car args))) (lambda (r) ((f r) (a r)))))
             ((2) (let ((a (car args)) (b (cadr args))) (lambda (r) ((f r) (a r) (b r)))))
             ((3) (let ((a (car args)) (b (cadr args)) (c (caddr args)))
                    (lambda (r) ((f r) (a r) (b r) (c r)))))
             (else (lambda (r) (apply (f r) (map (lambda (a) (a r)) args)))))))
        ((lambda) (compile-lambda (cadr e) cenv))
        ((let)
         (let* ((vars (map car (cadr e)))
                (inits (map (lambda (b) (compile (cadr b) cenv)) (cadr e)))
                (body (compile (caddr e) (cons vars cenv))))
           (lambda (r)
             (body (cons (list->vector (map (lambda (i) (i r)) inits)) r)))))
        ((letrec)
         (let* ((vars (map car (cadr e)))
                (cenv2 (cons vars cenv))
                (inits (map (lambda (b) (compile (cadr b) cenv2)) (cadr e)))
                (body (compile (caddr e) cenv2))
                (n (length vars)))
           (lambda (r)
             (let* ((frame (make-vector n (if #f #f)))
                    (r2 (cons frame r)))
               (let loop ((inits inits) (i 0))
                 (unless (null? inits)
                   (vector-set! frame i ((car inits) r2))
                   (loop (cdr inits) (+ i 1))))
               (body r2)))))
        (else (error "eval: unknown Core IR node" (node-kind e)))))

    (define (compile-seq xs)
      (cond ((null? xs) (lambda (r) (if #f #f)))
            ((null? (cdr xs)) (car xs))
            ((null? (cddr xs)) (let ((a (car xs)) (b (cadr xs))) (lambda (r) (a r) (b r))))
            (else (let ((a (car xs)) (rest (compile-seq (cdr xs))))
                    (lambda (r) (a r) (rest r))))))

    (define (compile-lambda l cenv)
      (let* ((params (lam-params l))
             (rest (lam-rest l))
             (n (length params))
             (vars (if rest (append params (list rest)) params))
             (body (compile (lam-body l) (cons vars cenv))))
        (if rest
            (case n
              ((0) (lambda (r) (lambda args (body (cons (vector args) r)))))
              ((1) (lambda (r) (lambda (a . args) (body (cons (vector a args) r)))))
              ((2) (lambda (r) (lambda (a b . args) (body (cons (vector a b args) r)))))
              (else
               (lambda (r)
                 (lambda args
                   (if (< (length args) n)
                       (error (string-append "Wrong number of arguments: at least "
                                             (number->string n) " expected, "
                                             (number->string (length args)) " supplied"))
                       (let ((frame (make-vector (+ n 1))))
                         (let loop ((as args) (i 0))
                           (if (= i n)
                               (vector-set! frame n as)
                               (begin (vector-set! frame i (car as)) (loop (cdr as) (+ i 1)))))
                         (body (cons frame r))))))))
            (case n
              ((0) (lambda (r) (lambda () (body (cons (vector) r)))))
              ((1) (lambda (r) (lambda (a) (body (cons (vector a) r)))))
              ((2) (lambda (r) (lambda (a b) (body (cons (vector a b) r)))))
              ((3) (lambda (r) (lambda (a b c) (body (cons (vector a b c) r)))))
              (else
               (lambda (r)
                 (lambda args
                   (unless (= (length args) n)
                     (error (string-append "Wrong number of arguments: " (number->string n)
                                           " expected, " (number->string (length args)) " supplied")))
                   (body (cons (list->vector args) r)))))))))))

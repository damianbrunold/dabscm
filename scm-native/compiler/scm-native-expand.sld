(define-library (scm native expand)
  (export expand-program
          make-glob
          glob?
          glob-lib
          glob-sym
          glob-name
          glob-assigned?
          missing-primitives)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme file)
          (scheme read)
          (scheme write)
          (srfi 1)
          (srfi 69)
          (scm fs)
          (scm native ast)
          (scm native syntax))
  (begin
    ;; The expander: syntax (as read) -> Core IR. It follows the JVM
    ;; implementation's Expander.java (sets of scopes, two-scope flip,
    ;; syntax-rules only) and its library system, but runs ahead of time over
    ;; the whole program: every library the program imports, transitively,
    ;; is expanded once, and the result is one Core IR expression that
    ;; initializes the libraries in dependency order and then runs the
    ;; program.
    ;;
    ;; (expand-program file search-path features primitive-names)
    ;;   => (values ast globs)

    ;; --- globals -----------------------------------------------------------

    ;; A global variable: a top-level definition of a library or the program.
    (define-record-type glob
      (%make-glob lib sym assigned)
      glob?
      (lib glob-lib)
      (sym glob-sym)
      (assigned glob-assigned? set-glob-assigned!))

    (define (make-glob lib sym) (%make-glob lib sym #f))

    ;; "<module>: <name>", as the JVM implementation names a global in errors
    (define (glob-name g)
      (let ((out (open-output-string)))
        (if (eq? (glob-lib g) 'program)
            (write-string "user program" out)
            (let loop ((parts (glob-lib g)) (first #t))
              (unless (null? parts)
                (unless first (write-char #\space out))
                (display (car parts) out)
                (loop (cdr parts) #f))))
        (write-string ": " out)
        (display (glob-sym g) out)
        (get-output-string out)))

    ;; --- modules -----------------------------------------------------------

    (define-record-type module
      (%make-module name scope globals exports body)
      module?
      (name module-name)
      (scope module-scope)
      (body module-body set-module-body!)            ; Core IR forms, reversed
      (globals module-globals set-module-globals!)   ; alist sym -> glob
      (exports module-exports set-module-exports!))  ; alist sym -> binding

    (define modules '())            ; name -> module, in load order
    (define scope->module '())      ; module scope -> module
    (define completed '())          ; modules in initialization order, reversed

    (define (add-body! m forms)
      (set-module-body! m (append (reverse forms) (module-body m))))
    (define all-globs '())
    (define loading '())
    (define search-path '())
    (define features '())
    (define primitives '())
    (define missing '())
    (define current #f)             ; the module being expanded

    (define (missing-primitives) missing)

    (define (new-module name)
      (let ((m (%make-module name (fresh-scope) '() '() '())))
        (set! scope->module (cons (cons (module-scope m) m) scope->module))
        (for-each (lambda (b) (bind! (car b) (list (module-scope m)) (cdr b))) core-bindings)
        m))

    (define (module-glob m sym)
      (cond ((assq sym (module-globals m)) => cdr)
            (else
             (let ((g (make-glob (module-name m) sym)))
               (set-module-globals! m (cons (cons sym g) (module-globals m)))
               (set! all-globs (cons g all-globs))
               g))))

    ;; --- bindings ----------------------------------------------------------
    ;; (core . name) | (macro . transformer) | (local . var) | (global . glob)
    ;; Bindings are compared with eq?.

    (define core-names
      '(quote quasiquote if set! begin lambda define define-syntax let let*
        letrec letrec* let-syntax letrec-syntax cond-expand import %primitive
        define-library))

    (define core-bindings (map (lambda (n) (cons n (cons 'core n))) core-names))

    (define (binding-kind b) (car b))

    (define (global-binding g) (cons 'global g))

    ;; Resolve an identifier. As in the JVM implementation, an unbound one
    ;; is looked up by name in the module being expanded (where a macro is
    ;; used, not where it is defined; library.scm's case refers to memv,
    ;; which (scheme base) defines), and else is a global of that module.
    ;; The JVM compiler's intrinsics are open-coded even where the module
    ;; does not bind them ((scheme char) uses null? without importing it).
    (define intrinsics
      '(car cdr cons null? pair? not + - * / = < > <= >= eq? eqv? vector-ref
        vector-set! list caar cadr cdar cddr caaar caadr cadar caddr cdaar cdadr
        cddar cdddr caaaar caaadr caadar caaddr cadaar cadadr caddar cadddr
        cdaaar cdaadr cdadar cdaddr cddaar cddadr cdddar cddddr))

    (define (lookup id)
      (or (resolve id)
          (resolve (make-ident (ident-sym id) (list (module-scope current))))
          (and (memq (ident-sym id) intrinsics)
               (not (assq (ident-sym id) (module-globals current)))
               (cons 'primitive (ident-sym id)))
          (global-binding (module-glob current (ident-sym id)))))

    (define (core? stx name)
      (and (ident? stx)
           (let ((b (resolve stx)))
             (and b (eq? (car b) 'core) (eq? (cdr b) name)))))

    (define (head-binding form)
      (and (pair? form) (ident? (car form)) (resolve (car form))))

    ;; --- macro use -----------------------------------------------------------

    (define (expand-macro t form use-site?)
      (let* ((use (fresh-scope))
             (intro (fresh-scope))
             (input (add-scope (if use-site? (add-scope form use) form) intro)))
        (flip-scope (apply-transformer t input) intro)))

    (define (eval-transformer name expr)
      (unless (and (pair? expr) (ident? (car expr)) (eq? (ident-sym (car expr)) 'syntax-rules))
        (error "define-syntax: expected (syntax-rules ...)" name (strip expr)))
      (make-transformer name (cdr expr)))

    ;; (define-syntax name [docstring] transformer)
    (define (syntax-definition form)
      (let ((name (cadr form))
            (expr (if (= (length form) 4) (cadddr form) (caddr form))))
        (values name (eval-transformer (ident-name name) expr))))

    ;; --- expressions -------------------------------------------------------

    (define unspecified `(const ,the-unspecified))

    (define (expand stx)
      (cond ((ident? stx)
             (let ((b (lookup stx)))
               (case (binding-kind b)
                 ((local) `(lref ,(cdr b)))
                 ((global) `(gref ,(cdr b)))
                 ((primitive) `(primref ,(cdr b)))
                 (else (error "syntax keyword used as an expression" (ident-sym stx))))))
            ((pair? stx)
             (let ((b (head-binding stx)))
               (cond ((and b (eq? (car b) 'core)) (expand-core (cdr b) stx))
                     ((and b (eq? (car b) 'macro)) (expand (expand-macro (cdr b) stx #t)))
                     (else `(call ,(expand (car stx)) ,@(map expand (proper (cdr stx) stx)))))))
            ((null? stx) '(const ()))
            ((symbol? stx) `(const ,stx))
            (else `(const ,(strip stx)))))

    (define (proper l form)
      (cond ((null? l) '())
            ((pair? l) (cons (car l) (proper (cdr l) form)))
            (else (error "improper form" (strip form)))))

    (define (expand-seq forms)
      (cond ((null? forms) unspecified)
            ((null? (cdr forms)) (expand (car forms)))
            (else `(seq ,@(map expand forms)))))

    (define (expand-core name form)
      (case name
        ((quote) `(const ,(strip (cadr form))))
        ((quasiquote) (expand-qq (cadr form) 1))
        ((if)
         `(if ,(expand (cadr form))
              ,(expand (caddr form))
              ,(if (pair? (cdddr form)) (expand (cadddr form)) unspecified)))
        ((set!)
         (let ((b (lookup (cadr form)))
               (e (expand (caddr form))))
           (case (binding-kind b)
             ((local) (var-assigned! (cdr b)) `(lset ,(cdr b) ,e))
             ((global) (set-glob-assigned! (cdr b) #t) `(gset ,(cdr b) ,e))
             (else (error "set! of a syntax keyword" (strip (cadr form)))))))
        ((begin) (expand-seq (cdr form)))
        ((lambda) (expand-lambda (cadr form) (cddr form) #f))
        ((let)
         (if (ident? (cadr form))
             (expand-named-let form)
             (expand-let (cadr form) (cddr form))))
        ((let*)
         (if (or (null? (cadr form)) (null? (cdadr form)))
             (expand-let (cadr form) (cddr form))
             (expand-let (list (caadr form))
                         (list (cons (car form) (cons (cdadr form) (cddr form)))))))
        ((letrec letrec*) (expand-letrec (cadr form) (cddr form)))
        ((let-syntax letrec-syntax)
         (expand-seq (let-syntax-body form)))
        ((cond-expand) (expand-seq (cond-expand-body form)))
        ((%primitive) (primitive-ref (cadr form)))
        ;; as the JVM implementation: an import anywhere imports into the
        ;; module being expanded
        ((import)
         (for-each import-set! (strip (cdr form)))
         unspecified)
        ((define define-syntax define-library)
         (error "definition or declaration in expression context" (strip form)))
        (else (error "unknown core form" name))))

    (define (primitive-ref arg)
      (let* ((a (strip arg))
             (a (if (and (pair? a) (eq? (car a) 'quote)) (cadr a) a))
             (name (if (string? a) (string->symbol a) a)))
        (unless (memq name primitives)
          (unless (memq name missing) (set! missing (cons name missing))))
        `(primref ,name)))

    ;; Bind identifiers to new local variables in a fresh scope
    (define (bind-locals ids scope)
      (map (lambda (id)
             (let ((v (make-var (ident-sym id))))
               (bind! (ident-sym id) (ident-scopes id) (cons 'local v))
               v))
           ids))

    (define (expand-lambda formals body name)
      (let* ((s (fresh-scope))
             (formals (add-scope formals s))
             (body (add-scope body s)))
        (let loop ((f formals) (ids '()))
          (cond ((pair? f) (loop (cdr f) (cons (car f) ids)))
                (else
                 (let* ((params (bind-locals (reverse ids) s))
                        (rest (and (ident? f) (car (bind-locals (list f) s)))))
                   `(lambda ,(make-lam params rest (expand-body body) name))))))))

    (define (expand-let bindings body)
      (if (null? bindings)
          (expand-body body)
          (let* ((s (fresh-scope))
                 (inits (map (lambda (b) (expand-named (if (pair? (cdr b)) (cadr b) no-init)
                                                       (ident-name (car b))))
                             bindings))
                 (vars (bind-locals (map (lambda (b) (add-scope (car b) s)) bindings) s)))
            `(let ,(map list vars inits) ,(expand-body (add-scope body s))))))

    (define (expand-named-let form)
      (let* ((name (cadr form))
             (bindings (caddr form))
             (body (cdddr form))
             (inits (map (lambda (b) (expand (cadr b))) bindings))
             (s (fresh-scope))
             (v (car (bind-locals (list (add-scope name s)) s)))
             (lam (expand-lambda (add-scope (map car bindings) s) (add-scope body s) (ident-name name))))
        (make-letrec (list v) (list lam) `(call (lref ,v) ,@inits))))

    ;; A binding or definition without an initializer
    (define no-init (list 'no-init))

    ;; init no-init: unspecified
    (define (expand-named init name)
      (cond ((eq? init no-init) unspecified)
            ((and (pair? init) (core? (car init) 'lambda))
             (expand-lambda (cadr init) (cddr init) name))
            (else (expand init))))

    ;; letrec* over variables already bound
    (define (make-letrec vars inits body)
      (if (and (pair? vars)
               (every (lambda (i) (eq? (node-kind i) 'lambda)) inits)
               (not (any var-assigned? vars)))
          `(letrec ,(map list vars inits) ,body)
          (begin
            (for-each var-assigned! vars)
            `(let ,(map (lambda (v) (list v unspecified)) vars)
               (seq ,@(map (lambda (v i) `(lset ,v ,i)) vars inits) ,body)))))

    (define (expand-letrec bindings body)
      (let* ((s (fresh-scope))
             (bindings (add-scope bindings s))
             (vars (bind-locals (map car bindings) s))
             (inits (map (lambda (b) (expand-named (if (pair? (cdr b)) (cadr b) no-init) (ident-name (car b))))
                         bindings)))
        (make-letrec vars inits (expand-body (add-scope body s)))))

    ;; let-syntax / letrec-syntax: bind the macros, return the body forms
    (define (let-syntax-body form)
      (let* ((s (fresh-scope))
             (bindings (if (core? (car form) 'letrec-syntax) (add-scope (cadr form) s) (cadr form))))
        (for-each (lambda (b)
                    (let ((name (add-scope (car b) s)))
                      (bind! (ident-sym name) (ident-scopes name)
                             (cons 'macro (eval-transformer (ident-sym name) (cadr b))))))
                  bindings)
        (add-scope (cddr form) s)))

    ;; --- bodies ------------------------------------------------------------

    ;; Expand a body: leading definitions (after macro expansion, with begin
    ;; spliced) become letrec*. A leading string followed by more forms is a
    ;; docstring.
    (define (expand-body forms0)
      ;; the body's scope goes on the forms before they are partially
      ;; expanded, so that a define-syntax binds its name inside the body
      ;; only; and again after, for definitions introduced by macros
      (let* ((s (fresh-scope))
             (forms (append-map partial-expand (add-scope forms0 s)))
             (forms (if (and (pair? forms) (string? (car forms)) (pair? (cdr forms)))
                        (cdr forms)
                        forms)))
        (let loop ((fs forms) (defs '()))
          (if (and (pair? fs) (define-form? (car fs)))
              (loop (cdr fs) (cons (normalize-define (car fs)) defs))
              (begin
                (when (any define-form? fs)
                  (error "definitions must precede the expressions of a body" (strip (car fs))))
                (if (null? defs)
                    (expand-seq fs)
                    (let* ((defs (reverse defs))
                           (names (map (lambda (d) (add-scope (car d) s)) defs))
                           (vars (bind-locals names s))
                           (inits (map (lambda (d n) (expand-named (add-scope (cadr d) s) (ident-sym n)))
                                       defs names))
                           (body (expand-seq (add-scope fs s))))
                      (make-letrec vars inits body))))))))

    (define (define-form? f) (and (pair? f) (core? (car f) 'define)))

    ;; Partially expand a body form: expand macros at the head, splice begin,
    ;; evaluate define-syntax. Returns a list of forms.
    (define (partial-expand form)
      (let ((b (head-binding form)))
        (cond ((not b) (list form))
              ((eq? (car b) 'macro) (partial-expand (expand-macro (cdr b) form #f)))
              ((eq? (car b) 'core)
               (case (cdr b)
                 ((begin) (append-map partial-expand (cdr form)))
                 ((define-syntax)
                  (let-values (((name t) (syntax-definition form)))
                    (bind! (ident-sym name) (ident-scopes name) (cons 'macro t))
                    '()))
                 ((let-syntax letrec-syntax) (append-map partial-expand (let-syntax-body form)))
                 (else (list form))))
              (else (list form)))))

    ;; (define (f . args) body ...) => (f (lambda args body ...)); (define x) => (x no-init)
    (define (normalize-define form)
      (let ((target (cadr form)))
        (if (pair? target)
            (normalize-define
             (list (car form) (car target) (cons (lambda-id) (cons (cdr target) (cddr form)))))
            (list target (if (pair? (cddr form)) (caddr form) no-init)))))

    ;; an identifier for the core lambda (bound in every module scope)
    (define (lambda-id) (make-ident 'lambda (list (module-scope current))))

    ;; --- quasiquote ----------------------------------------------------------

    (define (expand-qq x depth)
      (cond ((ident? x) `(const ,(ident-sym x)))
            ((vector? x)
             `(call (primref list->vector) ,(expand-qq (vector->list x) depth)))
            ((not (pair? x)) `(const ,(strip x)))
            ((core-or-name? (car x) 'unquote)
             (if (= depth 1)
                 (expand (cadr x))
                 `(call (primref list) (const unquote) ,(expand-qq (cadr x) (- depth 1)))))
            ((core-or-name? (car x) 'quasiquote)
             `(call (primref list) (const quasiquote) ,(expand-qq (cadr x) (+ depth 1))))
            ((and (pair? (car x)) (core-or-name? (caar x) 'unquote-splicing) (= depth 1))
             (let ((rest (expand-qq (cdr x) depth)))
               (if (equal? rest '(const ()))
                   (expand (cadar x))
                   `(call (primref append) ,(expand (cadar x)) ,rest))))
            (else
             (let ((a (expand-qq (car x) depth))
                   (d (expand-qq (cdr x) depth)))
               (if (and (eq? (car a) 'const) (eq? (car d) 'const))
                   `(const ,(cons (cadr a) (cadr d)))
                   `(call (primref cons) ,a ,d))))))

    (define (core-or-name? x name) (and (ident? x) (eq? (ident-sym x) name)))

    ;; --- cond-expand ---------------------------------------------------------

    (define (cond-expand-body form)
      (let loop ((clauses (cdr form)))
        (cond ((null? clauses) '())
              ((feature? (strip (car (car clauses)))) (cdr (car clauses)))
              (else (loop (cdr clauses))))))

    (define (feature? req)
      (cond ((symbol? req) (or (eq? req 'else) (memq req features)))
            ((pair? req)
             (case (car req)
               ((and) (every feature? (cdr req)))
               ((or) (any feature? (cdr req)))
               ((not) (not (feature? (cadr req))))
               ((library) (or (assoc (cadr req) modules) (find-library-file (cadr req))))
               (else #f)))
            (else #f)))

    ;; --- top level -----------------------------------------------------------

    ;; Expand a top-level form of the current module; returns Core IR forms.
    (define (toplevel form)
      (let ((b (head-binding form)))
        (cond ((and b (eq? (car b) 'macro)) (toplevel (expand-macro (cdr b) form #t)))
              ((and b (eq? (car b) 'core))
               (case (cdr b)
                 ((begin) (append-map toplevel (cdr form)))
                 ((define)
                  (let* ((d (normalize-define form))
                         (name (ident-name (car d)))
                         (e (expand-named (cadr d) name))
                         ;; a top-level definition is visible by its name in
                         ;; the module, whatever scopes a macro gave it
                         (g (module-glob current name)))
                    (bind! name (list (module-scope current)) (global-binding g))
                    (list `(gdef ,g ,e))))
                 ((define-syntax)
                  (let-values (((name t) (syntax-definition form)))
                    (bind! (ident-name name) (list (module-scope current)) (cons 'macro t))
                    '()))
                 ((let-syntax letrec-syntax) (append-map toplevel (let-syntax-body form)))
                 ((cond-expand) (append-map toplevel (cond-expand-body form)))
                 ((import)
                  (for-each import-set! (strip (cdr form)))
                  '())
                 ((define-library)
                  (define-library! form)
                  '())
                 (else (list (expand form)))))
              ((and (pair? form) (ident? (car form)) (eq? (ident-sym (car form)) '%module-export-bindings))
               ;; library.scm: (%module-export-bindings '(scm core) 'name ...)
               (set-module-exports! current
                                    (filter-map (lambda (q)
                                                  (let* ((s (cadr (strip q)))
                                                         (b (resolve (make-ident s (list (module-scope current))))))
                                                    (and b (cons s b))))
                                                (cddr form)))
               '())
              (else (list (expand form))))))

    ;; --- libraries -----------------------------------------------------------

    (define (library-file-name name)
      (string-append
       (fold (lambda (part acc)
               (let ((s (if (symbol? part) (symbol->string part) (number->string part))))
                 (if (string=? acc "") s (string-append acc "-" s))))
             "" name)))

    (define (find-library-file name)
      (let ((base (library-file-name name)))
        (any (lambda (dir)
               (any (lambda (ext)
                      (let ((f (join-path dir (string-append base ext))))
                        (and (file-exists? f) f)))
                    '(".sld" ".scm")))
             search-path)))

    (define (read-file file)
      (call-with-input-file file
        (lambda (port)
          (let loop ((acc '()))
            (let ((x (read port)))
              (if (eof-object? x) (reverse acc) (loop (cons x acc))))))))

    ;; SRFI 97 names: (srfi :1 ...) and (srfi srfi-1) are (srfi 1)
    (define (canonical-library-name name)
      (if (and (pair? name) (eq? (car name) 'srfi) (pair? (cdr name)) (symbol? (cadr name)))
          (let ((s (symbol->string (cadr name))))
            (cond ((and (> (string-length s) 1) (char=? (string-ref s 0) #\:)
                        (string->number (substring s 1 (string-length s))))
                   => (lambda (n) (list 'srfi n)))
                  ((and (> (string-length s) 5) (string=? (substring s 0 5) "srfi-")
                        (string->number (substring s 5 (string-length s))))
                   => (lambda (n) (list 'srfi n)))
                  (else name)))
          name))

    ;; The module named name, loading it first if needed
    (define (get-module name0)
      (define name (canonical-library-name name0))
      (cond ((assoc name modules) => cdr)
            ((member name loading) (error "circular library dependency" name))
            ((equal? name '(scm core)) (load-core-library))
            (else
             (let ((file (find-library-file name)))
               (unless file (error "library not found" name))
               (set! loading (cons name loading))
               (let ((saved current))
                 (for-each (lambda (form)
                             (set! current saved)
                             (unless (and (pair? form) (eq? (car form) 'define-library))
                               (error "expected define-library in library file" file))
                             (define-library-file! form file))
                           (read-file file))
                 (set! current saved))
               (set! loading (cdr loading))
               (or (cond ((assoc name modules) => cdr) (else #f))
                   (error "library file does not define the library" name file))))))

    (define core-library-file #f)

    (define (load-core-library)
      (let ((saved current)
            (m (new-module '(scm core))))
        (set! current m)
        (set! loading (cons '(scm core) loading))
        (let ((forms (append-map (lambda (f) (toplevel (wrap f (list (module-scope m)))))
                                 (read-file core-library-file))))
          (add-body! m forms))
        (set! loading (cdr loading))
        (set! modules (cons (cons '(scm core) m) modules))
        (set! completed (cons m completed))
        (set! current saved)
        m))

    ;; (define-library name decl ...) as read from file
    (define (define-library-file! form file)
      (let* ((name (cadr form))
             (m (new-module name)))
        (set! current m)
        (let ((exports '()))
          (define (decl! d)
            (case (car d)
              ((export) (set! exports (append exports (cdr d))))
              ((import) (for-each import-set! (cdr d)))
              ((begin)
               (let ((forms (append-map (lambda (f) (toplevel (wrap f (list (module-scope m)))))
                                        (cdr d))))
                 (add-body! m forms)))
              ((include include-ci)
               (for-each (lambda (f)
                           (decl! (cons 'begin (read-file (include-path f file)))))
                         (cdr d)))
              ((include-library-declarations)
               (for-each (lambda (f) (for-each decl! (read-file (include-path f file)))) (cdr d)))
              ((cond-expand)
               (let loop ((clauses (cdr d)))
                 (cond ((null? clauses) #t)
                       ((feature? (car (car clauses))) (for-each decl! (cdr (car clauses))))
                       (else (loop (cdr clauses))))))
              (else (error "unknown library declaration" (car d)))))
          (for-each decl! (cddr form))
          (set-module-exports!
           m
           (filter-map (lambda (e)
                  (let ((src (if (pair? e) (cadr e) e))
                        (dst (if (pair? e) (caddr e) e)))
                    (let ((b (resolve (make-ident src (list (module-scope m))))))
                      ;; names the library does not bind (auxiliary syntax
                      ;; such as else) are not exported
                      (and b (cons dst b)))))
                exports))
          (set! modules (cons (cons name m) modules))
          (set! completed (cons m completed)))))

    (define (define-library! form)
      (define-library-file! (strip form) #f))

    (define (include-path f file)
      (if (and file (not (absolute-path? f)))
          (join-path (directory-name file) f)
          f))

    (define (absolute-path? f) (and (> (string-length f) 0) (char=? (string-ref f 0) #\/)))

    ;; The bindings an import set provides: alist sym -> binding
    (define (import-bindings spec)
      (let ((head (and (pair? spec) (car spec))))
        (case head
          ((only)
           (let ((b (import-bindings (cadr spec))))
             (map (lambda (s) (or (assq s b) (error "import only: not exported" s (cadr spec))))
                  (cddr spec))))
          ((except)
           (remove (lambda (e) (memq (car e) (cddr spec))) (import-bindings (cadr spec))))
          ((prefix)
           (map (lambda (e) (cons (symbol-append (caddr spec) (car e)) (cdr e)))
                (import-bindings (cadr spec))))
          ((rename)
           (map (lambda (e) (cond ((assq (car e) (cddr spec)) => (lambda (r) (cons (cadr r) (cdr e))))
                                  (else e)))
                (import-bindings (cadr spec))))
          (else (module-exports (get-module spec))))))

    (define (symbol-append a b)
      (string->symbol (string-append (symbol->string a) (symbol->string b))))

    (define (import-set! spec)
      (let ((saved current))
        (let ((bindings (import-bindings spec)))
          (set! current saved)
          (for-each (lambda (e) (bind! (car e) (list (module-scope current)) (cdr e)))
                    bindings))))

    ;; --- program -------------------------------------------------------------

    ;; As the JVM implementation binds them for a program: script-name (the
    ;; executable here) and script-arguments, unless the program defines
    ;; them; after the leading imports
    (define (with-script-globals forms)
      (define (defines? name)
        (any (lambda (f)
               (and (pair? f) (eq? (car f) 'define) (pair? (cdr f))
                    (or (eq? (cadr f) name)
                        (and (pair? (cadr f)) (eq? (car (cadr f)) name)))))
             forms))
      (let* ((imports (let loop ((fs forms) (acc '()))
                        (if (and (pair? fs) (pair? (car fs)) (eq? (car (car fs)) 'import))
                            (loop (cdr fs) (cons (car fs) acc))
                            (reverse acc))))
             (rest (list-tail forms (length imports)))
             (globals
              (append
               (if (defines? 'script-name)
                   '()
                   '((define script-name ((%primitive "car") ((%primitive "command-line"))))))
               (if (defines? 'script-arguments)
                   '()
                   '((define script-arguments ((%primitive "cdr") ((%primitive "command-line")))))))))
        (append imports globals rest)))

    (define (expand-program file paths feature-list prims core-file)
      ;; a fresh library registry per program: the modules of an earlier
      ;; program (in the same process) must not end up in this one
      (set! modules '())
      (set! scope->module '())
      (set! completed '())
      (set! all-globs '())
      (set! loading '())
      (set! missing '())
      (set! search-path paths)
      (set! features feature-list)
      (set! primitives prims)
      (set! core-library-file core-file)
      (let* ((m (new-module 'program))
             (_ (set! current m))
             (forms (append-map (lambda (f)
                                  (set! current m)
                                  (toplevel (wrap f (list (module-scope m)))))
                                (with-script-globals (read-file file)))))
        ;; the modules in initialization order: (name . body), the program last
        (values (append (map (lambda (m) (cons (module-name m) `(seq ,@(reverse (module-body m)) ,unspecified)))
                             (reverse completed))
                        (list (cons 'program `(seq ,@forms ,unspecified))))
                (reverse all-globs))))))

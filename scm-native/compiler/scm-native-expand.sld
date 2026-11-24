(define-library (scm native expand)
  (export expand-program
          make-glob
          glob?
          glob-lib
          glob-sym
          glob-name
          glob-assigned?
          missing-primitives
          program-eager-modules
          expander-state
          install-expander-state!
          make-eval-module
          expand-eval
          take-new-modules!
          installed-glob?
          used-primitives
          program-binding
          program-eval-module
          set-runtime-search-path!
          with-expanding-file
          macroexpand-datum
          user-library-exports)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme file)
          (only (scheme process-context) get-environment-variable)
          (scheme read)
          (scheme write)
          (srfi 1)
          (srfi 69)
          (srfi 132)
          (scm fs)
          (scm native ast)
          (scm native syntax))
  ;; the host's characters: full Unicode natively, UTF-16 units on the JVM
  (cond-expand
    (dabscm-native (begin (define native-host #t)))
    (else (begin (define native-host #f))))
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

    ;; the number of libraries initialized before the program starts (the
    ;; others at their import, see expand-program)
    (define eager-modules 0)
    (define (program-eager-modules) eager-modules)

    ;; the primitives the program refers to
    (define used '())
    (define (used-primitives) used)

    ;; the program's module (its scope is in the state, for bound? and
    ;; macroexpand at run time)
    (define program-module #f)
    (define program-scope #f)

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
        define-library include include-ci))

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
        ((include include-ci) (expand-seq (map-included form (lambda (f) (list f)))))
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
        (unless (memq name used) (set! used (cons name used)))
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
                        (rest (and (ident? f) (car (bind-locals (list f) s))))
                        (lam (make-lam params rest (expand-body body) name)))
                   ;; as the JVM implementation, also a string that is the whole body
                   (when (and (pair? body) (string? (car body)))
                     (lam-doc-set! lam (car body)))
                   `(lambda ,lam)))))))

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
                 ((include include-ci) (map-included form partial-expand))
                 (else (list form))))
              (else (list form)))))

    ;; --- include -------------------------------------------------------------

    ;; the file whose forms are being expanded: include resolves against its
    ;; directory (#f at run time in eval: the current directory)
    (define expanding-file #f)

    (define (with-expanding-file file thunk)
      (let ((saved expanding-file))
        (set! expanding-file file)
        (let ((r (thunk)))
          (set! expanding-file saved)
          r)))

    ;; (include "file" ...) and (include-ci ...): the files' forms, read when
    ;; the form is expanded and expanded where it stands (R7RS), with the
    ;; scopes of the include keyword; (f form) of each is a list of forms,
    ;; made while expanding-file is the included file (for nested includes)
    (define (map-included form f)
      (let ((scopes (ident-scopes (car form)))
            (ci? (core? (car form) 'include-ci)))
        (append-map
         (lambda (name)
           (let ((name (strip name)))
             (unless (string? name) (error "include: expected a file name" name))
             (let ((path (include-path name expanding-file)))
               (unless (file-exists? path) (error "include: file not found" path))
               (with-expanding-file path
                 (lambda ()
                   (append-map (lambda (d) (f (wrap (if ci? (fold-symbols d) d) scopes)))
                               (read-file path)))))))
         (proper (cdr form) form))))

    (define (fold-symbols d)
      (cond ((symbol? d) (string->symbol (string-foldcase (symbol->string d))))
            ((pair? d) (cons (fold-symbols (car d)) (fold-symbols (cdr d))))
            ((vector? d) (vector-map fold-symbols d))
            (else d)))

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
            ((qq-form? x 'unquote)
             (if (= depth 1)
                 (expand (cadr x))
                 `(call (primref list) (const unquote) ,(expand-qq (cadr x) (- depth 1)))))
            ((qq-form? x 'quasiquote)
             `(call (primref list) (const quasiquote) ,(expand-qq (cadr x) (+ depth 1))))
            ((and (qq-form? (car x) 'unquote-splicing) (= depth 1))
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

    ;; (name datum): not the tail of a list such as (const unquote)
    (define (qq-form? x name)
      (and (pair? x) (core-or-name? (car x) name) (pair? (cdr x)) (null? (cddr x))))

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
                         ;; a top-level definition is visible by its name in
                         ;; the module, whatever scopes a macro gave it
                         (g (module-glob current name))
                         (bind (lambda () (bind! name (list (module-scope current)) (global-binding g))))
                         (hb (head-binding (cadr d)))
                         (proc? (and hb (eq? (car hb) 'core) (eq? (cdr hb) 'lambda))))
                    ;; A procedure's body sees its own definition, also where the
                    ;; name was imported (the JVM looks globals up when the body
                    ;; runs): (define (f x) ... (f ...)) in a program that
                    ;; imports another f. Any other expression runs at once, as
                    ;; on the JVM before the definition exists: (define x (wrap x)).
                    (when proc? (bind))
                    (let ((e (expand-named (cadr d) name)))
                      (unless proc? (bind))
                      (list `(gdef ,g ,e)))))
                 ((define-syntax)
                  (let-values (((name t) (syntax-definition form)))
                    (bind! (ident-name name) (list (module-scope current)) (cons 'macro t))
                    '()))
                 ((let-syntax letrec-syntax) (append-map toplevel (let-syntax-body form)))
                 ((cond-expand) (append-map toplevel (cond-expand-body form)))
                 ((include include-ci) (map-included form toplevel))
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

    ;; at run time (eval): the program's (module-search-path), searched
    ;; before the compiler's path, as the JVM's loader searches it
    (define runtime-search-path '())
    (define (set-runtime-search-path! dirs) (set! runtime-search-path dirs))

    (define (find-library-file name)
      (let ((base (library-file-name name)))
        (any (lambda (dir)
               (any (lambda (ext)
                      (let ((f (join-path dir (string-append base ext))))
                        (and (file-exists? f) f)))
                    '(".sld" ".scm")))
             (append runtime-search-path search-path))))

    (define (read-file file)
      (let* ((text (call-with-input-file file
                     (lambda (port)
                       (let ((s (read-string 100000000 port)))
                         (if (eof-object? s) "" s)))))
             (marked (if native-host text (mark-astral-chars text)))
             ;; the file itself when nothing was marked: a read error then
             ;; names the file with its line and column
             (port (if (eq? marked text) (open-input-file file) (open-input-string marked))))
        (let loop ((acc '()))
          (let ((x (read port)))
            (if (eof-object? x)
                (let ((forms (reverse acc)))
                  (close-port port)
                  (if (eq? marked text) forms (map restore-astral-chars forms)))
                (loop (cons x acc)))))))

    ;; Characters beyond U+FFFF: the JVM implementation (where the compiler
    ;; runs) has UTF-16 characters and reads such a character literal as its
    ;; high surrogate. Before reading, each literal #\xHHHHH (and #\ with
    ;; the character itself) beyond U+FFFF becomes a marker symbol, and
    ;; after reading the markers become astral-char records. Strings are
    ;; left alone (a string holds such a character as a surrogate pair,
    ;; which the emitter writes as one character).
    (define astral-prefix "%native-astral-char-")

    (define (mark-astral-chars text)
      (let ((n (string-length text)))
        (define (at i) (and (< i n) (string-ref text i)))
        (define (delimiter? i)
          (let ((c (at i)))
            (or (not c) (char-whitespace? c) (memv c '(#\( #\) #\" #\;)))))
        (define (hex-end i)
          (let loop ((j i))
            (if (and (at j) (or (char<=? #\0 (at j) #\9) (char<=? #\a (char-downcase (at j)) #\f)))
                (loop (+ j 1))
                j)))
        (define (surrogate? c lo hi) (and c (<= lo (char->integer c) hi)))
        (if (not (has-char-literal? text))
            text
            (let ((out (open-output-string)) (changed #f))
              (define (marker code)
                (set! changed #t)
                (write-string (string-append "|" astral-prefix (number->string code 16) "|") out))
              (let loop ((i 0))
                (when (< i n)
                  (let ((c (string-ref text i)))
                    (cond
                     ((char=? c #\")             ; string
                      (write-char c out)
                      (let s ((j (+ i 1)))
                        (cond ((>= j n) (loop j))
                              ((char=? (string-ref text j) #\\)
                               (write-char #\\ out)
                               (when (at (+ j 1)) (write-char (string-ref text (+ j 1)) out))
                               (s (+ j 2)))
                              ((char=? (string-ref text j) #\")
                               (write-char #\" out)
                               (loop (+ j 1)))
                              (else (write-char (string-ref text j) out) (s (+ j 1))))))
                     ((char=? c #\|)             ; |symbol|
                      (write-char c out)
                      (let s ((j (+ i 1)))
                        (cond ((>= j n) (loop j))
                              ((char=? (string-ref text j) #\\)
                               (write-char #\\ out)
                               (when (at (+ j 1)) (write-char (string-ref text (+ j 1)) out))
                               (s (+ j 2)))
                              ((char=? (string-ref text j) #\|)
                               (write-char #\| out)
                               (loop (+ j 1)))
                              (else (write-char (string-ref text j) out) (s (+ j 1))))))
                     ((char=? c #\;)             ; line comment
                      (let s ((j i))
                        (cond ((>= j n) (loop j))
                              ((char=? (string-ref text j) #\newline) (loop j))
                              (else (write-char (string-ref text j) out) (s (+ j 1))))))
                     ((and (char=? c #\#) (eqv? (at (+ i 1)) #\|)) ; block comment
                      (write-string "#|" out)
                      (let s ((j (+ i 2)) (depth 1))
                        (cond ((>= j n) (loop j))
                              ((and (char=? (string-ref text j) #\|) (eqv? (at (+ j 1)) #\#))
                               (write-string "|#" out)
                               (if (= depth 1) (loop (+ j 2)) (s (+ j 2) (- depth 1))))
                              ((and (char=? (string-ref text j) #\#) (eqv? (at (+ j 1)) #\|))
                               (write-string "#|" out)
                               (s (+ j 2) (+ depth 1)))
                              (else (write-char (string-ref text j) out) (s (+ j 1) depth)))))
                     ((and (char=? c #\#) (eqv? (at (+ i 1)) #\\)) ; character
                      (let ((d (at (+ i 2))))
                        (cond
                         ((and d (char-ci=? d #\x) (> (hex-end (+ i 3)) (+ i 3)) (delimiter? (hex-end (+ i 3)))
                               (> (string->number (substring text (+ i 3) (hex-end (+ i 3))) 16) #xFFFF))
                          (marker (string->number (substring text (+ i 3) (hex-end (+ i 3))) 16))
                          (loop (hex-end (+ i 3))))
                         ((and (surrogate? d #xD800 #xDBFF) (surrogate? (at (+ i 3)) #xDC00 #xDFFF)
                               (delimiter? (+ i 4)))
                          (marker (+ #x10000 (* (- (char->integer d) #xD800) #x400)
                                     (- (char->integer (at (+ i 3))) #xDC00)))
                          (loop (+ i 4)))
                         (else
                          (write-string "#\\" out)
                          (when d (write-char d out))
                          (loop (+ i 3))))))
                     (else (write-char c out) (loop (+ i 1)))))))
              (if changed (get-output-string out) text)))))

    (define (has-char-literal? s)
      (let ((n (- (string-length s) 1)))
        (let loop ((i 0))
          (cond ((>= i n) #f)
                ((and (char=? (string-ref s i) #\#) (char=? (string-ref s (+ i 1)) #\\)) #t)
                (else (loop (+ i 1)))))))

    (define (restore-astral-chars x)
      (cond ((pair? x) (cons (restore-astral-chars (car x)) (restore-astral-chars (cdr x))))
            ((vector? x) (vector-map restore-astral-chars x))
            ((and (symbol? x)
                  (let ((s (symbol->string x)))
                    (and (> (string-length s) (string-length astral-prefix))
                         (string=? (substring s 0 (string-length astral-prefix)) astral-prefix)
                         (string->number (substring s (string-length astral-prefix) (string-length s)) 16))))
             => make-astral-char)
            (else x)))

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

    ;; library name -> its file (#f: defined in a program or library body)
    (define library-files '())

    ;; The libraries that are not files in lib-dir (defined in the program
    ;; or found elsewhere), for %module-exports at run time: a list of
    ;; (name (sym . kind) ...), kind syntax or unknown
    (define (user-library-exports lib-dir)
      (filter-map
       (lambda (entry)
         (let ((name (car entry)) (file (and (cdr entry) (absolute-path (cdr entry)))))
           (and (not (and file (>= (string-length file) (string-length lib-dir))
                          (string=? (substring file 0 (string-length lib-dir)) lib-dir)))
                (cond ((assoc name modules)
                       => (lambda (e)
                            (cons name
                                  (map (lambda (x) (cons (car x) (if (eq? (car (cdr x)) 'macro) 'syntax 'unknown)))
                                       (module-exports (cdr e))))))
                      (else #f)))))
       (reverse library-files)))

    ;; (define-library name decl ...) as read from file
    (define (define-library-file! form file)
      (set! library-files (cons (cons (cadr form) file) library-files))
      (let* ((name (cadr form))
             (m (new-module name)))
        (set! current m)
        (let ((exports '()))
          (define (decl! d)
            (case (car d)
              ((export) (set! exports (append exports (cdr d))))
              ((import) (for-each import-set! (cdr d)))
              ((begin)
               (predeclare-procedures! m (cdr d))
               (let ((forms (with-expanding-file file
                              (lambda ()
                                (append-map (lambda (f) (toplevel (wrap f (list (module-scope m)))))
                                            (cdr d))))))
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

    ;; A library's procedure definitions are visible in its whole body,
    ;; also where the name is imported: the JVM looks globals up by name
    ;; when the code runs, so a procedure defined earlier in the body that
    ;; calls the library's own list->string (shadowing (scheme base)'s) gets
    ;; that one. Only procedures ((define (f ...) ...), (define f (lambda
    ;; ...))): a value definition's expression runs at once, where the JVM
    ;; still sees the import ((define x (wrap x))). forms as read.
    (define (predeclare-procedures! m forms)
      (for-each
       (lambda (f)
         (when (and (pair? f) (eq? (car f) 'define) (pair? (cdr f)))
           (let ((target (cadr f)))
             (cond ((and (pair? target) (symbol? (car target)))
                    (predeclare! m (car target)))
                   ((and (symbol? target) (pair? (cddr f)) (pair? (caddr f))
                         (eq? (car (caddr f)) 'lambda))
                    (predeclare! m target)))))
         (when (and (pair? f) (eq? (car f) 'begin))
           (predeclare-procedures! m (cdr f))))
       forms))

    (define (predeclare! m sym)
      (bind! sym (list (module-scope m)) (global-binding (module-glob m sym))))

    (define (define-library! form)
      (define-library-file! (strip form) #f))

    (define (include-path f file)
      (if (and file (not (absolute-path? f)))
          (join-path (directory-name file) f)
          f))

    ;; / or \ at the start, or a drive (C:)
    (define (absolute-path? f)
      (let ((n (string-length f)))
        (or (and (> n 0) (memv (string-ref f 0) '(#\/ #\\)))
            (and (> n 1) (char=? (string-ref f 1) #\:)))))

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

    ;; --- the state for eval at run time -------------------------------------
    ;; A program that links (scm native eval) carries the expander's state
    ;; after its expansion: the binding table (without local bindings), the
    ;; libraries with their exports and globals, and the scope counter. Run
    ;; time eval installs it, so that it expands code against the linked
    ;; libraries as the compiler did, without their sources.
    ;;
    ;; (state counter features search-path globs bindings entries modules)
    ;;   globs: #((lib sym assigned) ...)
    ;;   bindings: #(binding ...): (c name) (p name) (g glob-index)
    ;;     (m name ellipsis literals rules), syntax encoded: an identifier is
    ;;     #(%i sym scopes), a vector #(%v item ...), an astral-char #(%a code)
    ;;   entries: (#(sym (scopes binding-index) ...) ...), sorted
    ;;   modules: ((name scope ((sym binding-index) ...) ((sym glob-index) ...)) ...)
    ;;   (lists and vectors rather than pairs and lists: the JVM
    ;;   implementation's write fails on (quote . 3) and writes (quote a b)
    ;;   as 'a)

    (define (expander-state)
      (let ((glob-ids (make-hash-table eq?)) (globs '()) (nglobs 0)
            (binding-ids (make-hash-table eq?)) (bindings '()) (nbindings 0))
        (define (glob-id g)
          (or (hash-table-ref/default glob-ids g #f)
              (let ((i nglobs))
                (hash-table-set! glob-ids g i)
                (set! nglobs (+ i 1))
                (set! globs (cons (list (glob-lib g) (glob-sym g) (glob-assigned? g)) globs))
                i)))
        (define (enc x)
          (cond ((ident? x) (vector '%i (ident-sym x) (ident-scopes x)))
                ((pair? x) (cons (enc (car x)) (enc (cdr x))))
                ((vector? x) (list->vector (cons '%v (map enc (vector->list x)))))
                ((astral-char? x) (vector '%a (astral-char-code x)))
                (else x)))
        (define (binding-id b)
          (and (not (eq? (car b) 'local))
               (or (hash-table-ref/default binding-ids b #f)
                   (let ((e (case (car b)
                              ((core) (list 'c (cdr b)))
                              ((primitive) (list 'p (cdr b)))
                              ((global) (list 'g (glob-id (cdr b))))
                              ((macro) (cons 'm (map enc (transformer-parts (cdr b)))))
                              (else (error "expander-state: binding" (car b))))))
                     (let ((i nbindings))
                       (hash-table-set! binding-ids b i)
                       (set! nbindings (+ i 1))
                       (set! bindings (cons e bindings))
                       i)))))
        (let* ((entries
                (filter-map
                 (lambda (entry)
                   (let ((es (filter-map (lambda (e)
                                           (let ((id (binding-id (cdr e))))
                                             (and id (list (car e) id))))
                                         (cdr entry))))
                     (and (pair? es) (list->vector (cons (car entry) es)))))
                 (sort-by-name (binding-table-entries))))
               (mods
                (map (lambda (entry)
                       (let ((m (cdr entry)))
                         (list (module-name m) (module-scope m)
                               (filter-map (lambda (e) (let ((id (binding-id (cdr e)))) (and id (list (car e) id))))
                                           (module-exports m))
                               (map (lambda (e) (list (car e) (glob-id (cdr e)))) (module-globals m)))))
                     (reverse modules)))
               ;; the program's globals, for load without an environment
               ;; (numbered before globs is turned into the vector below)
               (program-globals
                (if program-module
                    (map (lambda (e) (list (car e) (glob-id (cdr e)))) (module-globals program-module))
                    '())))
          (list 'state (scope-counter-value) features search-path
                (list->vector (reverse globs)) (list->vector (reverse bindings)) entries mods
                (and program-module (module-scope program-module))
                program-globals))))

    (define (sort-by-name entries)
      (list-sort (lambda (a b) (string<? (symbol->string (car a)) (symbol->string (car b)))) entries))

    (define (install-expander-state! st)
      (let* ((globs (vector-map (lambda (g)
                                  (let ((x (make-glob (car g) (cadr g))))
                                    (when (caddr g) (set-glob-assigned! x #t))
                                    (hash-table-set! installed-globs x #t)
                                    x))
                                (list-ref st 4)))
             (dec (lambda (x)
                    (let dec ((x x))
                      (cond ((pair? x) (cons (dec (car x)) (dec (cdr x))))
                            ((and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) '%i))
                             (make-ident (vector-ref x 1) (vector-ref x 2)))
                            ((and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) '%v))
                             (list->vector (map dec (cdr (vector->list x)))))
                            ((and (vector? x) (> (vector-length x) 0) (eq? (vector-ref x 0) '%a))
                             (integer->char (vector-ref x 1)))
                            (else x)))))
             (bindings (vector-map (lambda (e)
                                     (case (car e)
                                       ((c) (cdr (assq (cadr e) core-bindings)))
                                       ((p) (cons 'primitive (cadr e)))
                                       ((g) (global-binding (vector-ref globs (cadr e))))
                                       ((m) (cons 'macro (rebuild-transformer (map dec (cdr e)))))))
                                   (list-ref st 5))))
        (set-scope-counter! (list-ref st 1))
        (set! features (list-ref st 2))
        ;; the compiler's search path, then (for an installed program whose
        ;; build directories are elsewhere) the libraries of the dabscm
        ;; native installation SCM_NATIVE_DIR names
        (set! search-path
              (append (list-ref st 3)
                      (let ((dir (get-environment-variable "SCM_NATIVE_DIR")))
                        (if (and dir (not (string=? dir "")))
                            (list (join-path (directory-name dir) "scm-lib" "libraries")
                                  (join-path dir "compiler")
                                  (join-path dir "lib"))
                            '()))))
        (for-each (lambda (entry)
                    (for-each (lambda (e) (bind! (car entry) (car e) (vector-ref bindings (cadr e))))
                              (reverse (cdr entry))))
                  (map vector->list (list-ref st 6)))
        (set! modules '())
        (set! scope->module '())
        (set! completed '())
        (for-each (lambda (md)
                    (let ((m (%make-module (car md) (cadr md)
                                           (map (lambda (e) (cons (car e) (vector-ref globs (cadr e)))) (cadddr md))
                                           (map (lambda (e) (cons (car e) (vector-ref bindings (cadr e)))) (caddr md))
                                           '())))
                      (set! modules (cons (cons (car md) m) modules))
                      (set! scope->module (cons (cons (cadr md) m) scope->module))))
                  (list-ref st 7))
        (set! program-scope (list-ref st 8))
        (set! program-module
              (and program-scope
                   (let ((m (%make-module 'program program-scope
                                          (map (lambda (e) (cons (car e) (vector-ref globs (cadr e))))
                                               (if (> (length st) 9) (list-ref st 9) '()))
                                          '() '())))
                     (set! scope->module (cons (cons program-scope m) scope->module))
                     m)))))

    ;; The compiled program's module (after install-expander-state!), or #f:
    ;; load without an environment evaluates in it, as the JVM's load in the
    ;; running module, so its definitions set the program's globals
    (define (program-eval-module) program-module)

    ;; The binding of the name sym in the program, or #f
    (define (program-binding sym)
      (and program-scope (resolve (make-ident sym (list program-scope)))))

    ;; macroexpand: the datum x with its macros expanded, in the program's
    ;; scope, as plain data (core forms stay; binding names are not
    ;; expanded)
    (define (macroexpand-datum x)
      (define (mx stx)
        (if (and (pair? stx) (ident? (car stx)))
            (let ((b (resolve (car stx))))
              (cond ((and b (eq? (car b) 'macro)) (mx (expand-macro (cdr b) stx #t)))
                    ((and b (eq? (car b) 'core)) (mx-core (cdr b) stx))
                    (else (map-proper mx stx))))
            (if (pair? stx) (map-proper mx stx) stx)))
      (define (mx-body forms) (map-proper mx forms))
      (define (mx-bindings bs)
        (map-proper (lambda (b) (if (and (pair? b) (pair? (cdr b))) (cons (car b) (mx-body (cdr b))) b)) bs))
      (define (mx-core name stx)
        (case name
          ((quote quasiquote) stx)
          ((lambda) (if (pair? (cdr stx)) (cons* (car stx) (cadr stx) (mx-body (cddr stx))) stx))
          ((define)
           (if (and (pair? (cdr stx)) (pair? (cadr stx)))
               (cons* (car stx) (cadr stx) (mx-body (cddr stx)))
               (cons* (car stx) (if (pair? (cdr stx)) (cadr stx) '()) (if (pair? (cdr stx)) (mx-body (cddr stx)) '()))))
          ((set!) (if (and (pair? (cdr stx)) (pair? (cddr stx))) (list (car stx) (cadr stx) (mx (caddr stx))) stx))
          ((let let* letrec letrec*)
           (cond ((and (pair? (cdr stx)) (ident? (cadr stx)) (pair? (cddr stx))) ; named let
                  (cons* (car stx) (cadr stx) (mx-bindings (caddr stx)) (mx-body (cdddr stx))))
                 ((pair? (cdr stx)) (cons* (car stx) (mx-bindings (cadr stx)) (mx-body (cddr stx))))
                 (else stx)))
          ;; as the JVM implementation's expander: (if c a) gets the
          ;; unspecified value as its else, (begin x) is x
          ((if)
           (let ((parts (mx-body (cdr stx))))
             (if (and (list? parts) (= (length parts) 2))
                 (cons (car stx) (append parts (list (if #f #f))))
                 (cons (car stx) parts))))
          ((begin)
           (if (and (pair? (cdr stx)) (null? (cddr stx)))
               (mx (cadr stx))
               (cons (car stx) (mx-body (cdr stx)))))
          (else (cons (car stx) (mx-body (cdr stx))))))
      (strip (mx (wrap x (list program-scope)))))

    (define (map-proper f l)
      (cond ((pair? l) (cons (f (car l)) (map-proper f (cdr l))))
            (else l)))

    ;; the globals of the compiled program (which have its cells)
    (define installed-globs (make-hash-table eq?))
    (define (installed-glob? g) (hash-table-ref/default installed-globs g #f))

    ;; A module for eval: the environment of the import sets specs, named
    ;; (in messages) after the first, as in the JVM implementation
    (define (make-eval-module specs . name)
      (let ((m (new-module (cond ((pair? name) (car name))
                                 ((and (pair? specs) (pair? (car specs))) (car specs))
                                 (else 'program)))))
        (set! current m)
        (for-each import-set! specs)
        m))

    ;; The Core IR forms of the top-level form (a datum) in module m
    (define (expand-eval m form)
      (set! current m)
      (toplevel (wrap form (list (module-scope m)))))

    ;; The libraries loaded (from source) since the last call, in
    ;; initialization order: ((name . body) ...)
    (define (take-new-modules!)
      (let ((new (reverse completed)))
        (set! completed '())
        (map (lambda (m) (cons (module-name m) `(seq ,@(reverse (module-body m)) ,unspecified))) new)))

    ;; extra-forms: forms the program gets before its own (the driver's
    ;; implicit import of (scm native eval))
    (define (expand-program file paths feature-list prims core-file . extra-forms)
      ;; a fresh library registry per program: the modules of an earlier
      ;; program (in the same process) must not end up in this one
      (set! modules '())
      (set! scope->module '())
      (set! completed '())
      (set! all-globs '())
      (set! loading '())
      (set! missing '())
      (set! used '())
      (set! library-files '())
      (set! search-path paths)
      (set! features feature-list)
      (set! primitives prims)
      (set! core-library-file core-file)
      (set! expanding-file file)
      (let* ((m (new-module 'program))
             (_ (set! current m))
             (_ (set! program-module m))
             (seen-code? #f)
             ;; Libraries are initialized when the program reaches the import
             ;; that brings them in, as on the JVM, where code before a later
             ;; import (a configuration loaded, a parameter set) is seen by
             ;; the libraries it imports. Those of the imports before the
             ;; program's first definition or expression start with the
             ;; program (eager); a later import's are initialized by calls
             ;; of their entries (%module-entry, by their index in the
             ;; initialization order) at its place.
             (forms (append-map
                     (lambda (f)
                       (set! current m)
                       (let* ((before (length completed))
                              (fs (toplevel (wrap f (list (module-scope m)))))
                              (after (length completed)))
                         (cond (seen-code?
                                (append (map (lambda (i)
                                               `(call (call (primref %module-entry) (const ,i))))
                                             (iota (- after before) before))
                                        fs))
                               (else
                                (when (pair? fs)
                                  (set! seen-code? #t)
                                  (set! eager-modules after))
                                fs))))
                     (append (if (pair? extra-forms) (car extra-forms) '())
                             (with-script-globals (read-file file))))))
        (unless seen-code? (set! eager-modules (length completed)))
        ;; the modules in initialization order: (name . body), the program last
        (values (append (map (lambda (m) (cons (module-name m) `(seq ,@(reverse (module-body m)) ,unspecified)))
                             (reverse completed))
                        ;; the program's value is its last form's (an integer
                        ;; is the exit code, as for a script on the JVM)
                        (list (cons 'program
                                    (if (and (pair? forms)
                                             (not (eq? (car (last forms)) 'gdef)))
                                        `(seq ,@forms)
                                        `(seq ,@forms ,unspecified)))))
                (reverse all-globs))))))

(define-library (scm native emit)
  (export emit-modules
          mangle
          set-program-version!
          set-eval-state!
          set-eager-modules!
          set-user-libraries!)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme inexact)
          (scheme write)
          (srfi 1)
          (srfi 69)
          (srfi 132)
          (scm native ast)
          (scm native anf)
          (scm native expand)
          (scm native optimize))
  (begin
    ;; Zig code generation from ANF Core IR (see scm-native/README.md for
    ;; the runtime model).
    ;;
    ;; Every lambda becomes an entry block; every non-tail call ends a block
    ;; and continues in a new return block. A block is a Zig function
    ;; `fn (*Thread) callconv(.c) void` that ends in a tail call. Within a
    ;; block, values live in Zig constants; across a call, the live ones are
    ;; saved in the frame. A block reserves the heap words it allocates at its
    ;; entry, while all its values are still in roots.
    ;;
    ;; Zig rejects unused and shadowed locals, so the emitter loads exactly
    ;; the variables a block refers to, and names every value uniquely.
    ;;
    ;; Every module (library or the program) becomes a Zig file of its own,
    ;; compiled to an object separately (and cached by Zig). Its globals are
    ;; the array scml_<module>_g; other modules refer to it as extern.
    ;; Names within a module are numbered per module, so that a library's
    ;; Zig code does not depend on the program it is compiled for.

    (define (cat . xs)
      (apply string-append
             (map (lambda (x)
                    (cond ((string? x) x)
                          ((number? x) (number->string x))
                          ((symbol? x) (symbol->string x))
                          (else (error "cat: bad piece" x))))
                  xs)))

    ;; --- output state ------------------------------------------------------

    (define blocks '())        ; finished block functions (strings)
    (define statics '())       ; file-level declarations (strings)
    (define init-lines '())    ; statements of init()
    (define primitive-names '()) ; (name module kind): kind code or value
    (define primitive-procs '()) ; (name . zig-var) static procedures
    (define module-sym #f)       ; the module being emitted, mangled
    (define own-globals 0)       ; number of globals of the module so far
    (define global-table (make-hash-table eq?)) ; glob -> (module-sym . index)
    (define module-sizes '())    ; module-sym -> number of globals (finished)
    (define externs '())         ; extern declarations of the module
    (define local-ids (make-hash-table eq?))    ; var or lam -> number in the module
    (define constant-symbols (make-hash-table eq?)) ; symbol -> zig-name
    (define constant-numbers '())                   ; (number . zig-name)
    (define counter 0)

    (define (next!)
      (set! counter (+ counter 1))
      counter)

    (define (add-static! s) (set! statics (cons s statics)))
    (define (add-init! s) (set! init-lines (cons s init-lines)))

    (define (add-extern! s) (unless (member s externs) (set! externs (cons s externs))))

    ;; A per-module number for a variable or lambda (deterministic names)
    (define (local-id x)
      (or (hash-table-ref/default local-ids x #f)
          (let ((n (next!)))
            (hash-table-set! local-ids x n)
            n)))

    ;; The Zig place of global g: scml_<module>_g[index]
    (define (global-place g)
      (let ((entry (hash-table-ref/default global-table g #f)))
        (cond (entry
               (unless (string=? (car entry) module-sym)
                 (add-extern! (cat "extern var " (globals-array (car entry)) ": ["
                                   (max 1 (cdr (assoc (car entry) module-sizes))) "]Word;")))
               (cat (globals-array (car entry)) "[" (cdr entry) "]"))
              ((string=? (module-symbol (glob-lib g)) module-sym)
               (let ((i own-globals))
                 (set! own-globals (+ i 1))
                 (hash-table-set! global-table g (cons module-sym i))
                 (cat (globals-array module-sym) "[" i "]")))
              (else (error "emit: global of a module not emitted yet" (glob-name g))))))

    (define (globals-array sym) (cat "scml_" sym "_g"))

    (define (implemented? name) (assq name primitive-names))
    (define (allocating-leaf? name)
      (let ((p (assq name primitive-names)))
        (and p (or (string=? (cadr p) "prims_num")
                   (memq name '(sin cos tan asin acos atan log gensym string->symbol))))))
    (define (value-primitive? name) (eq? (caddr (assq name primitive-names)) 'value))

    ;; The runtime's symbol of an implemented primitive (declared extern)
    (define (prim-symbol name)
      (let ((sym (mangle (if (value-primitive? name) "scmv_" "scmp_") (symbol->string name))))
        (add-extern! (if (value-primitive? name)
                         (cat "extern fn " sym "() callconv(.c) Word;")
                         (cat "extern fn " sym "(t: *Thread) callconv(.c) void;")))
        sym))

    ;; The static procedure object of a primitive (a file-level variable)
    (define (primitive-proc name)
      (cond ((assq name primitive-procs) => cdr)
            (else
             (let ((v (cat "p" (next!))))
               (set! primitive-procs (cons (cons name v) primitive-procs))
               (add-static! (cat "var " v ": Word = undefined;"))
               (add-init! (cond ((not (implemented? name))
                                 (cat "    " v " = rt.missingPrimitive(\"" (zig-escape (symbol->string name)) "\");"))
                                ((value-primitive? name)
                                 (cat "    " v " = " (prim-symbol name) "();"))
                                (else
                                 (cat "    " v " = rt.primitive(&" (prim-symbol name) ", \""
                                      (zig-escape (symbol->string name)) "\");"))))
               v))))

    ;; --- blocks ------------------------------------------------------------

    (define-record-type block
      (%make-block name prologue lines alloc dyn-alloc unreserved)
      block?
      (name block-name)
      (prologue block-prologue set-block-prologue!)
      (lines block-lines set-block-lines!)
      (alloc block-alloc set-block-alloc!)
      (dyn-alloc block-dyn-alloc set-block-dyn-alloc!)
      ;; may allocate outside the nursery (arithmetic, leaf primitives): such
      ;; allocation requests a collection, which the block's entry checks
      (unreserved block-unreserved? set-block-unreserved!))

    (define (make-block name) (%make-block name '() '() 0 #f #f))
    (define (unreserved! b) (set-block-unreserved! b #t))

    (define (emit! b . pieces)
      (set-block-lines! b (cons (apply cat "    " pieces) (block-lines b))))

    (define (prologue! b . pieces)
      (set-block-prologue! b (cons (apply cat "    " pieces) (block-prologue b))))

    (define (alloc! b n) (set-block-alloc! b (+ (block-alloc b) n)))

    (define (finish-block! b)
      (let* ((n (block-alloc b))
             (dyn (block-dyn-alloc b))
             ;; every procedure entry is a safepoint: a requested
             ;; collection (or another thread's) happens there, and a
             ;; terminated thread ends there; every unbounded computation
             ;; passes through one (or a loop head)
             (attention (if (char=? (string-ref (block-name b) 0) #\L)
                            (list "    if (t.attention()) |c| return @call(.always_tail, c, .{t});")
                            '()))
             (reserve (append
                       attention
                       (cond ((and dyn (> n 0)) (list (cat "    t.reserve(" dyn " + " n ");")))
                             (dyn (list (cat "    t.reserve(" dyn ");")))
                             ((> n 0) (list (cat "    t.reserve(" n ");")))
                             (else '())))))
        (set! blocks
              (cons (apply cat
                           (cat "fn " (block-name b) "(t: *Thread) callconv(.c) void {\n"
                                ;; inline helpers with constant arguments are
                                ;; evaluated at comptime: large blocks need more
                                (if (> (length (block-lines b)) 200) "    @setEvalBranchQuota(100000000);\n" ""))
                           (append (map (lambda (l) (cat l "\n"))
                                        (append (reverse (block-prologue b))
                                                reserve
                                                (reverse (block-lines b))))
                                   (list "}\n")))
                    blocks))))

    (define tail-call-ret "return @call(.always_tail, rt.retCode(t), .{t});")

    ;; A return that reports an error (an expression, usable after orelse)
    (define (fail-stmt msg atoms)
      (cat "return @call(.always_tail, rt.fail(t, \"" (zig-escape msg) "\", &.{"
           (join atoms ", ") "}), .{t})"))

    ;; --- environments ------------------------------------------------------
    ;; env: alist var -> (zig-expression . local?). local? is #t for Zig
    ;; constants of the current block (they must be saved across a call), #f
    ;; for literals and statics (valid everywhere).

    (define (lookup env v)
      (cond ((assq v env) => cadr)
            (else (error "emit: variable not in scope" (var-name v) (var-id v)))))

    (define (local-name v) (cat "v" (local-id v)))

    (define (bind env v expr local?) (cons (list v expr local?) env))

    ;; a variable bound to a known lambda (letrec): calls jump to its code
    (define (bind-known env v expr local? l) (cons (list v expr local? l) env))

    (define (known-lam env v)
      (let ((e (assq v env)))
        (and e (pair? (cdddr e)) (cadddr e))))

    (define (arity-ok? l n)
      (if (lam-rest l) (>= n (length (lam-params l))) (= n (length (lam-params l)))))

    (define (temp! b expr)
      (let ((name (cat "t" (next!))))
        (emit! b "const " name " = " expr ";")
        name))

    ;; --- constants ---------------------------------------------------------

    (define (fixnum? d) (and (exact-integer? d) (<= (- (expt 2 62)) d (- (expt 2 62) 1))))

    (define (constant d)
      (cond ((unspecified? d) "rt.UNSPEC")
            ((eq? d #t) "rt.TRUE")
            ((eq? d #f) "rt.FALSE")
            ((null? d) "rt.NIL")
            ((fixnum? d) (word-literal (* 2 d)))
            ((char? d) (word-literal (+ (* 8 (char->integer d)) 5)))
            ((astral-char? d) (word-literal (+ (* 8 (astral-char-code d)) 5)))
            ;; literals are distinct objects (as in the JVM implementation),
            ;; except those that cannot be mutated
            ((and (symbol? d) (hash-table-ref/default constant-symbols d #f)) => (lambda (n) n))
            ((and (number? d) (assoc d constant-numbers)) => cdr)
            (else
             (let ((name (cat "c" (next!)))
                   (init (constant-init d)))
               (cond ((symbol? d) (hash-table-set! constant-symbols d name))
                     ((number? d) (set! constant-numbers (cons (cons d name) constant-numbers))))
               (add-static! (cat "var " name ": Word = undefined;"))
               (add-init! (cat "    " name " = " init ";"))
               name))))

    ;; A tagged word as a Zig literal (computed here: comptime evaluation of
    ;; rt.fix in large functions exceeds Zig's branch quota)
    (define (word-literal n)
      (let ((u (if (< n 0) (+ n (expt 2 64)) n)))
        (cat "@as(Word, 0x" (number->string u 16) ")")))

    (define (constant-init d)
      (cond ((string? d) (cat "rt.data.constString(\"" (zig-escape d) "\")"))
            ((symbol? d) (cat "rt.data.intern(\"" (zig-escape (symbol->string d)) "\")"))
            ((and (real? d) (inexact? d)) (cat "rt.data.constFlonum(" (zig-float d) ")"))
            ((pair? d) (cat "rt.data.constPair(" (constant (car d)) ", " (constant (cdr d)) ")"))
            ((vector? d) (cat "rt.data.constVector(&.{" (join (map constant (vector->list d)) ", ") "})"))
            ((bytevector? d)
             (cat "rt.data.constBytevector(&.{"
                  (join (map number->string (bytevector->list d)) ", ") "})"))
            ((number? d) (cat "rt.data.constNumber(t, \"" (number->string d) "\")"))
            (else (error "unsupported constant" d))))

    (define (zig-float x)
      (cond ((nan? x) "std.math.nan(f64)")
            ((infinite? x) (if (> x 0) "std.math.inf(f64)" "-std.math.inf(f64)"))
            (else (number->string x))))

    ;; --- simple expressions: emit statements, return a Zig expression ------

    (define (cg-simple e b env)
      (case (node-kind e)
        ((const) (constant (cadr e)))
        ((lref)
         (let ((v (cadr e)))
           (if (var-assigned? v)
               (temp! b (cat "rt.ptr(" (lookup env v) ")[1]"))
               (lookup env v))))
        ((gref) (cg-gref (cadr e) b))
        ((primref) (primitive-proc (cadr e)))
        ((lset)
         (let ((a (cg-simple (caddr e) b env)))
           (emit! b "rt.ptr(" (lookup env (cadr e)) ")[1] = " a ";")
           (emit! b "rt.barrier(t, " (lookup env (cadr e)) ", " a ");")
           ;; set! returns the value (as the JVM implementation)
           a))
        ((gset)
         (let ((a (cg-simple (caddr e) b env)))
           (emit! b (global-place (cadr e)) " = " a ";")
           a))
        ((gdef)
         (let ((a (cg-simple (caddr e) b env)))
           (emit! b (global-place (cadr e)) " = " a ";")
           "rt.UNSPEC"))
        ((lambda) (cg-closure (cadr e) b env))
        ((prim) (cg-prim (cadr e) (map (lambda (a) (cg-simple a b env)) (cddr e)) b (cddr e)))
        ((call) (cg-leaf-call (cadr (cadr e)) (map (lambda (a) (cg-simple a b env)) (cddr e)) b))
        ((if)
         (let ((test (cg-simple (cadr e) b env))
               (r (cat "t" (next!))))
           (emit! b "var " r ": Word = undefined;")
           (emit! b "if (rt.isTrue(" test ")) {")
           (emit! b "    " r " = " (cg-simple (caddr e) b env) ";")
           (emit! b "} else {")
           (emit! b "    " r " = " (cg-simple (cadddr e) b env) ";")
           (emit! b "}")
           r))
        ((seq)
         (let loop ((es (cdr e)))
           (if (null? (cdr es))
               (cg-simple (car es) b env)
               (begin (cg-effect (car es) b env) (loop (cdr es))))))
        ((let) (cg-simple (caddr e) b (cg-let-bindings (cadr e) (caddr e) b env)))
        ((letrec) (cg-simple (caddr e) b (cg-letrec (cadr e) (caddr e) b env)))
        (else (error "cg-simple: not simple" e))))

    (define (cg-effect e b env)
      (case (node-kind e)
        ((const) #t)
        ((lref)
         ;; the variable is loaded in this block: it must be used
         (let ((a (lookup env (cadr e))))
           (when (local-expr? a) (emit! b "rt.ignore(" a ");"))))
        ((seq) (for-each (lambda (x) (cg-effect x b env)) (cdr e)))
        ((if)
         (let ((test (cg-simple (cadr e) b env)))
           (emit! b "if (rt.isTrue(" test ")) {")
           (cg-effect (caddr e) b env)
           (emit! b "} else {")
           (cg-effect (cadddr e) b env)
           (emit! b "}")))
        ((let) (cg-effect (caddr e) b (cg-let-bindings (cadr e) (caddr e) b env)))
        ((letrec) (cg-effect (caddr e) b (cg-letrec (cadr e) (caddr e) b env)))
        (else
         (let ((a (cg-simple e b env)))
           (when (local-expr? a) (emit! b "rt.ignore(" a ");"))))))

    (define (cg-gref g b)
      (let* ((v (temp! b (global-place g))))
        (emit! b "if (" v " == rt.UNBOUND) return @call(.always_tail, rt.unboundError(t, \""
               (zig-escape (glob-name g)) "\"), .{t});")
        v))

    ;; Bindings of a let whose right-hand sides are simple
    (define (cg-let-bindings bindings body b env)
      (let ((used (refs body)))
        (fold (lambda (binding env2)
                (let* ((v (car binding))
                       (rhs (cadr binding)))
                  (if (memq v used)
                      (bind-value v (cg-simple rhs b env) b env2)
                      (begin (cg-effect rhs b env) env2))))
              env
              bindings)))

    ;; Bind v to the value of Zig expression a (boxing it if v is assigned)
    (define (bind-value v a b env)
      (cond ((var-assigned? v)
             (alloc! b 2)
             (emit! b "const " (local-name v) " = t.box(" a ");")
             (bind env v (local-name v) #t))
            ((local-expr? a) (bind env v a #t))
            (else (bind env v a #f))))

    ;; Zig constants of the block are named t<n> or v<n>
    (define (local-expr? a)
      (and (> (string-length a) 1)
           (memv (string-ref a 0) '(#\t #\v))
           (char-numeric? (string-ref a 1))))

    ;; letrec of lambdas: allocate all closures, then fill in their free
    ;; variables (which may be the closures themselves).
    (define (cg-letrec bindings body b env)
      (let* ((used (fold (lambda (bd acc) (var-union (lam-free (cadr (cadr bd))) acc))
                         (refs body) bindings))
             (live (filter (lambda (bd) (memq (car bd) used)) bindings))
             (env2 (fold (lambda (bd env2)
                           (let* ((v (car bd))
                                  (l (cadr (cadr bd))))
                             (if (null? (lam-free l))
                                 (bind-known env2 v (static-closure l) #f l)
                                 (let ((c (cat "cl" (local-id v))))
                                   (alloc! b (+ 2 (length (lam-free l))))
                                   (emit! b "const " c " = t.closure(&" (gen-lambda l) ", "
                                          (length (lam-free l)) ");")
                                   (emit! b "const " (local-name v) " = rt.tagPtr(" c ");")
                                   (bind-known env2 v (local-name v) #t l)))))
                         env live)))
        (for-each (lambda (bd)
                    (let ((l (cadr (cadr bd))))
                      (unless (null? (lam-free l))
                        (fill-closure! (cat "cl" (local-id (car bd))) l b env2))))
                  live)
        env2))

    (define (fill-closure! c l b env)
      (let loop ((fs (lam-free l)) (i 2))
        (unless (null? fs)
          (emit! b c "[" i "] = " (lookup env (car fs)) ";")
          (loop (cdr fs) (+ i 1)))))

    (define (static-closure l)
      (let ((name (cat "s" (local-id l))))
        (unless (hash-table-ref/default statics-made name #f)
          (hash-table-set! statics-made name #t)
          (add-static! (cat "var " name ": Word = undefined;"))
          (add-init! (cat "    " name " = rt.staticProc(&" (gen-lambda l) ");"))
          (when (escape-only? l) (add-init! (cat "    rt.markEscapeOnly(" name ");"))))
        name))

    ;; An escape-only receiver (as the JVM implementation's Jit.escapeOnly):
    ;; one parameter, which the body only calls directly; nested lambdas do
    ;; not refer to it. call/cc gives such a receiver an escape continuation.
    (define (escape-only? l)
      (and (= (length (lam-params l)) 1)
           (not (lam-rest l))
           (let ((k (car (lam-params l))))
             (and (not (var-assigned? k)) (only-called? (lam-body l) k)))))

    (define (only-called? e k)
      (case (node-kind e)
        ((const gref primref) #t)
        ((lref) (not (eq? (cadr e) k)))
        ((lambda) (not (memq k (lam-free (cadr e)))))
        ((call) (and (or (and (eq? (node-kind (cadr e)) 'lref) (eq? (cadr (cadr e)) k))
                         (only-called? (cadr e) k))
                     (every (lambda (a) (only-called? a k)) (cddr e))))
        ((prim) (every (lambda (a) (only-called? a k)) (cddr e)))
        ((if seq) (every (lambda (a) (only-called? a k)) (cdr e)))
        ((lset gset gdef) (only-called? (caddr e) k))
        ((let letrec) (and (every (lambda (b) (only-called? (cadr b) k)) (cadr e))
                           (only-called? (caddr e) k)))
        (else #f)))
    (define statics-made (make-hash-table string=?))

    (define (cg-closure l b env)
      (if (null? (lam-free l))
          (static-closure l)
          (let ((c (cat "cl" (next!))))
            (alloc! b (+ 2 (length (lam-free l))))
            (emit! b "const " c " = t.closure(&" (gen-lambda l) ", " (length (lam-free l)) ");")
            (fill-closure! c l b env)
            (let ((v (temp! b (cat "rt.tagPtr(" c ")"))))
              (when (escape-only? l) (emit! b "rt.markEscapeOnly(" v ");"))
              v))))

    ;; --- open-coded primitives ---------------------------------------------

    (define (cg-prim op as b args-nodes)
      (define (a i) (list-ref as i))
      (define (pred expr) (temp! b (cat "rt.boolean(" expr ")")))
      (define (check! test msg . atoms)
        (emit! b "if (!(" test ")) " (fail-stmt msg atoms) ";"))
      (define (type-fail name . atoms)
        (cat "return @call(.always_tail, rt.typeError(t, \"" (zig-escape name) "\", &.{"
             (join atoms ", ") "}), .{t})"))
      (define (arith-fail name)
        (cat "return @call(.always_tail, rt.arithError(t, \"" name "\", " (a 0) ", " (a 1) "), .{t})"))
      ;; a flonum result needs no reservation (rt.safeFlo)
      (define (arith fn name)
        (unreserved! b)
        (temp! b (cat "rt.num." fn "(t, " (a 0) ", " (a 1) ") orelse " (arith-fail name))))
      (define (cmp c name)
        (pred (cat "rt.num.cmp(" (a 0) ", " (a 1) ", ." c ") orelse " (arith-fail name))))
      (define (vector-fail name)
        (cat "return @call(.always_tail, rt.vectorError(t, \"" name "\", " (a 0) ", " (a 1) "), .{t})"))
      (case op
        ((car cdr)
         (emit! b "if (!rt.isPair(" (a 0) ")) " (type-fail (symbol->string op)) ";")
         (temp! b (cat "rt." op "(" (a 0) ")")))
        ((cons) (alloc! b 3) (temp! b (cat "t.cons(" (a 0) ", " (a 1) ")")))
        ((set-car! set-cdr!)
         (emit! b "if (!rt.isPair(" (a 0) ")) " (type-fail (symbol->string op)) ";")
         (emit! b "rt.ptr(" (a 0) ")[" (if (eq? op 'set-car!) 1 2) "] = " (a 1) ";")
         (emit! b "rt.barrier(t, " (a 0) ", " (a 1) ");")
         "rt.UNSPEC")
        ((pair?) (pred (cat "rt.isPair(" (a 0) ")")))
        ((null?) (pred (cat (a 0) " == rt.NIL")))
        ((not) (pred (cat (a 0) " == rt.FALSE")))
        ((eq?) (pred (cat (a 0) " == " (a 1))))
        ((eqv?) (pred (cat "rt.data.eqv(" (a 0) ", " (a 1) ")")))
        ((+) (arith "add" "+"))
        ((-) (arith "sub" "-"))
        ((*) (arith "mul" "*"))
        ((<) (cmp "lt" "<"))
        ((>) (cmp "gt" ">"))
        ((<=) (cmp "le" "<="))
        ((>=) (cmp "ge" ">="))
        ((=) (cmp "eq" "="))
        ((zero?) (pred (cat "rt.num.cmp(" (a 0) ", rt.fix(0), .eq) orelse " (type-fail "zero?" (a 0)))))
        ((vector-ref)
         (temp! b (cat "rt.data.vref(" (a 0) ", " (a 1) ") orelse " (vector-fail "vector-ref"))))
        ((vector-set!)
         (emit! b "if (!rt.data.vset(" (a 0) ", " (a 1) ", " (a 2) ")) " (vector-fail "vector-set!") ";")
         (emit! b "rt.barrier(t, " (a 0) ", " (a 2) ");")
         "rt.UNSPEC")
        ((vector-length)
         (emit! b "if (!rt.data.isVector(" (a 0) ")) " (type-fail "vector-length") ";")
         (temp! b (cat "rt.fix(@intCast(rt.data.vectorLen(" (a 0) ")))")))
        ((char->integer)
         (emit! b "if (!rt.isChar(" (a 0) ")) " (type-fail "char->integer") ";")
         (temp! b (cat "rt.fix(rt.charCode(" (a 0) "))")))
        ;; records (from define-record-type, see (scm native optimize))
        ((%record-get)
         ;; x type index tag
         (emit! b "if (!(rt.isObj(" (a 0) ", rt.T_RECORD) and rt.ptr(" (a 0) ")[1] == " (a 1) ")) "
                "return @call(.always_tail, rt.fail(t, \"accessor applied to bad value\", &.{"
                (a 1) ", " (a 3) ", " (a 0) "}), .{t});")
         (temp! b (cat "rt.ptr(" (a 0) ")[1 + " (record-index (list-ref args-nodes 2)) "]")))
        ((%record-set)
         ;; x value type index tag
         (emit! b "if (!(rt.isObj(" (a 0) ", rt.T_RECORD) and rt.ptr(" (a 0) ")[1] == " (a 2) ")) "
                "return @call(.always_tail, rt.fail(t, \"modifier applied to bad value\", &.{"
                (a 2) ", " (a 4) ", " (a 0) "}), .{t});")
         (emit! b "rt.ptr(" (a 0) ")[1 + " (record-index (list-ref args-nodes 3)) "] = " (a 1) ";")
         (emit! b "rt.barrier(t, " (a 0) ", " (a 1) ");")
         "rt.UNSPEC")
        ((%record-is)
         (pred (cat "rt.isObj(" (a 0) ", rt.T_RECORD) and rt.ptr(" (a 0) ")[1] == " (a 1))))
        ((%record-make)
         ;; type size (index ...) arg ...
         (let* ((size (cadr (list-ref args-nodes 1)))
                (indexes (cadr (list-ref args-nodes 2)))
                (q (cat "rec" (next!))))
           (alloc! b (+ 1 size))
           (emit! b "const " q " = t.allocRaw(" (+ 1 size) ");")
           (emit! b q "[0] = rt.hdr(rt.T_RECORD, " size ");")
           (emit! b q "[1] = " (a 0) ";")
           (let loop ((i 2))
             (when (<= i size)
               (emit! b q "[" i "] = rt.FALSE;")
               (loop (+ i 1))))
           (let loop ((is indexes) (k 3))
             (unless (null? is)
               (emit! b q "[" (+ 1 (car is)) "] = " (a k) ";")
               (loop (cdr is) (+ k 1))))
           (temp! b (cat "rt.tagPtr(" q ")"))))
        (else (error "cg-prim: unknown primitive" op))))

    (define (record-index node) (cadr node))

    ;; A direct call of a leaf primitive: arguments in t.args, the value
    ;; returned (UNBOUND for an error, which is pending in the thread)
    (define (cg-leaf-call name as b)
      ;; numeric leaf primitives may make flonums and bignums
      (when (allocating-leaf? name) (unreserved! b))
      (let ((n (length as))
            (sym (mangle "scmd_" (symbol->string name))))
        (add-extern! (cat "extern fn " sym "(t: *Thread) callconv(.c) Word;"))
        (when (> n 256) (emit! b "t.ensureArgs(" n ");"))
        (let loop ((as as) (i 0))
          (unless (null? as)
            (emit! b "t.args[" i "] = " (car as) ";")
            (loop (cdr as) (+ i 1))))
        (emit! b "t.argc = " n ";")
        (let ((r (temp! b (cat sym "(t)"))))
          (emit! b "if (" r " == rt.UNBOUND) return @call(.always_tail, rt.errorCode, .{t});")
          r)))

    ;; --- tail position -----------------------------------------------------

    (define (cg-tail e b env)
      (case (node-kind e)
        ((if)
         (let ((test (cg-simple (cadr e) b env)))
           (emit! b "if (rt.isTrue(" test ")) {")
           (cg-tail (caddr e) b env)
           (emit! b "} else {")
           (cg-tail (cadddr e) b env)
           (emit! b "}")))
        ((seq)
         (let loop ((es (cdr e)))
           (if (null? (cdr es))
               (cg-tail (car es) b env)
               (begin (cg-effect (car es) b env) (loop (cdr es))))))
        ((let)
         (let ((bindings (cadr e))
               (body (caddr e)))
           (if (and (= (length bindings) 1) (not (simple? (cadr (car bindings)))))
               (cg-nontail-call (car (car bindings)) (cadr (car bindings)) body b env)
               (cg-tail body b (cg-let-bindings bindings body b env)))))
        ((letrec)
         (let ((loop (loop-candidate e)))
           (if loop
               (cg-loop loop b env)
               (cg-tail (caddr e) b (cg-letrec (cadr e) (caddr e) b env)))))
        ((call)
         (cond ((and (eq? (node-kind (cadr e)) 'lref) (assq (cadr (cadr e)) loops))
                => (lambda (loop) (cg-loop-again loop (cddr e) b env)))
               ((simple? e)
                (let ((a (cg-simple e b env)))
                  (emit! b "t.val = " a ";")
                  (emit! b tail-call-ret)))
               (else (cg-call (cadr e) (cddr e) b env))))
        (else
         (let ((a (cg-simple e b env)))
           (emit! b "t.val = " a ";")
           (emit! b tail-call-ret)))))

    (define (cg-call f args b env)
      (let* ((direct (and (eq? (node-kind f) 'primref) (implemented? (cadr f))))
             (n (length args))
             ;; a known lambda: a letrec-bound one, or a global of this module
             (known (cond ((and (eq? (node-kind f) 'lref) (known-lam env (cadr f)))
                           => (lambda (l) (and (arity-ok? l n) l)))
                          ((and (eq? (node-kind f) 'gref) (known-global-lambda (cadr f)))
                           => (lambda (l)
                                (and (arity-ok? l n)
                                     (string=? (module-symbol (glob-lib (cadr f))) module-sym)
                                     l)))
                          (else #f)))
             (global (and (not known) (eq? (node-kind f) 'gref)))
             (fa (cond (direct #f)
                       (global #f)
                       ((and known (eq? (node-kind f) 'gref)) (static-closure known))
                       (else (cg-simple f b env))))
             (as (map (lambda (a) (cg-simple a b env)) args)))
        (when (> n 256) (emit! b "t.ensureArgs(" n ");"))
        (let loop ((as as) (i 0))
          (unless (null? as)
            (emit! b "t.args[" i "] = " (car as) ";")
            (loop (cdr as) (+ i 1))))
        (emit! b "t.argc = " n ";")
        (cond ((and direct (value-primitive? (cadr f)))
               (emit! b "return @call(.always_tail, rt.notProcedureCode, .{t});"))
              (direct
               (emit! b "return @call(.always_tail, " (prim-symbol (cadr f)) ", .{t});"))
              (known
               (emit! b "t.self = " fa ";")
               (emit! b "return @call(.always_tail, " (gen-lambda known) ", .{t});"))
              (global
               (emit! b "return @call(.always_tail, rt.enterCell(t, &" (global-place (cadr f)) ", \""
                      (zig-escape (glob-name (cadr f))) "\"), .{t});"))
              (else
               (emit! b "return @call(.always_tail, rt.enter(t, " fa "), .{t});")))))

    ;; (let ((v rhs)) body) with a complex rhs: save the live values in a
    ;; frame, evaluate rhs in tail position, continue in a return block.
    (define (cg-nontail-call v rhs body b env)
      (let* ((used (refs body))
             ;; the first entry of each variable (delete-duplicates is
             ;; quadratic, and env holds a long body's literals and statics)
             (live (let ((seen (make-hash-table eq?)))
                     (filter (lambda (entry)
                               (and (not (hash-table-ref/default seen (car entry) #f))
                                    (begin (hash-table-set! seen (car entry) #t) #t)
                                    (memq (car entry) used)
                                    (caddr entry)))
                             env)))
             (n (length live))
             (k (make-block (cat "K" (next!))))
             (info (cat "k" (substring (block-name k) 1 (string-length (block-name k))))))
        (add-static! (cat "const " info ": rt.RetInfo = .{ .code = &" (block-name k)
                          ", .size = " n " };"))
        (emit! b "t.ensureStack(" (+ n 1) ");")
        (for-each (lambda (entry) (emit! b "t.push(" (cadr entry) ");")) live)
        (emit! b "t.pushRet(&" info ");")
        (cg-tail rhs b env)
        ;; the return block: literals and statics stay valid; the live
        ;; values come from the frame, the call's result from t.val
        (let loop ((live live) (i 0)
                   (env2 (filter (lambda (entry) (not (caddr entry))) env)))
          (if (pair? live)
              (let* ((var (car (car live)))
                     (name (cat (local-name var) "_" (next!))))
                (emit! k "const " name " = t.slot(" n ", " i ");")
                (loop (cdr live) (+ i 1) (bind env2 var name #t)))
              (begin
                (emit! k "t.sp -= " (+ n 1) ";")
                (let ((env3 (cond ((not (memq v used)) env2)
                                  ((var-assigned? v) (bind-value v "t.val" k env2))
                                  (else
                                   (emit! k "const " (local-name v) " = t.val;")
                                   (bind env2 v (local-name v) #t)))))
                  (cg-tail body k env3)
                  (finish-block! k)))))))

    ;; --- loops ---------------------------------------------------------------
    ;; A named let (letrec ((v (lambda params body))) (v init ...)) whose v is
    ;; only called, in tail position, and whose body makes no non-tail call,
    ;; becomes a Zig loop: the parameters are vars, a call of v assigns them
    ;; and continues. If the body allocates, each iteration checks the heap;
    ;; to collect, the loop's values (parameters and the outer values it
    ;; uses, copied to vars) are spilled to t.args, which are roots.

    (define loops '())  ; (v label param-vars) for the loops being emitted

    (define (mentions? e v) (and (memq v (refs e)) #t))

    (define (loop-candidate e)
      (and (= (length (cadr e)) 1)
           (let* ((bd (car (cadr e)))
                  (v (car bd))
                  (l (cadr (cadr bd)))
                  (call (caddr e))
                  (n (length (lam-params l))))
             (and (not (var-assigned? v))
                  (not (lam-rest l))
                  (not (any var-assigned? (lam-params l)))
                  (eq? (node-kind call) 'call)
                  (eq? (node-kind (cadr call)) 'lref)
                  (eq? (cadr (cadr call)) v)
                  (= (length (cddr call)) n)
                  (not (any (lambda (a) (mentions? a v)) (cddr call)))
                  ;; a body that never calls v is no loop (and Zig rejects an
                  ;; unused label)
                  (mentions? (lam-body l) v)
                  (loop-body-ok? (lam-body l) v n)
                  (list v l (cddr call))))))

    (define (loop-body-ok? e v n)
      (case (node-kind e)
        ((if) (and (not (mentions? (cadr e) v))
                   (loop-body-ok? (caddr e) v n)
                   (loop-body-ok? (cadddr e) v n)))
        ((seq) (let loop ((es (cdr e)))
                 (if (null? (cdr es))
                     (loop-body-ok? (car es) v n)
                     (and (not (mentions? (car es) v)) (loop (cdr es))))))
        ((let) (and (every (lambda (b) (simple? (cadr b))) (cadr e))
                    (not (any (lambda (b) (mentions? (cadr b) v)) (cadr e)))
                    (loop-body-ok? (caddr e) v n)))
        ((letrec) (and (not (any (lambda (b) (mentions? (cadr b) v)) (cadr e)))
                       (loop-body-ok? (caddr e) v n)))
        ((call) (if (and (eq? (node-kind (cadr e)) 'lref) (eq? (cadr (cadr e)) v))
                    (and (= (length (cddr e)) n)
                         (not (any (lambda (a) (mentions? a v)) (cddr e))))
                    (not (mentions? e v))))
        (else (not (mentions? e v)))))

    (define (cg-loop loop b env)
      (let* ((v (car loop))
             (l (cadr loop))
             (inits (map (lambda (a) (cg-simple a b env)) (caddr loop)))
             (body (lam-body l))
             (used (refs body))
             (label (cat "loop" (next!)))
             (params (lam-params l))
             ;; parameter vars (#f for unused parameters)
             (pvars (map (lambda (p) (and (memq p used) (cat "lp" (next!)))) params))
             ;; outer values the body uses, as vars
             (outer (filter (lambda (entry) (and (caddr entry) (memq (car entry) used)
                                                 (not (memq (car entry) params))))
                            (delete-duplicates env (lambda (x y) (eq? (car x) (car y))))))
             (ovars (map (lambda (entry) (cat "lo" (next!))) outer)))
        (for-each (lambda (pv a)
                    (when pv
                      (emit! b "var " pv ": Word = " a ";")
                      (emit! b "_ = &" pv ";")))
                  pvars inits)
        (for-each (lambda (entry ov)
                    (emit! b "var " ov ": Word = " (cadr entry) ";")
                    (emit! b "_ = &" ov ";"))
                  outer ovars)
        (let* ((env2 (fold (lambda (entry ov env) (bind env (car entry) ov #t)) env outer ovars))
               (env2 (fold (lambda (p pv env) (if pv (bind env p pv #t) env)) env2 params pvars))
               (marker (string-copy "// heap check"))
               (saved-alloc (block-alloc b)))
          (emit! b label ": while (true) {")
          (set-block-lines! b (cons marker (block-lines b)))
          (set-block-alloc! b 0)
          (set! loops (cons (list v label pvars) loops))
          (cg-tail body b env2)
          (set! loops (cdr loops))
          (emit! b "}")
          (let* ((n (block-alloc b))
                 (spilled (append (filter (lambda (x) x) pvars) ovars))
                 (k (length spilled)))
            (set-block-alloc! b saved-alloc)
            (set-block-lines!
             b
             (map (lambda (line)
                    (cond ((not (eq? line marker)) line)
                          ;; with n = 0 the check still notices a requested
                          ;; collection (flonums and large objects lower hlimit)
                          (else
                           (apply cat
                                  "    if (@intFromPtr(t.hp) + 8 * " n " > t.limit()) {\n"
                                  "        t.ensureArgs(" (max k 1) ");\n"
                                  (append
                                   (map (lambda (x i) (cat "        t.args[" i "] = " x ";\n")) spilled (iota k))
                                   (list "        t.reserve(" n ");\n"
                                         ;; a terminated thread ends here too
                                         "        if (t.ending()) |c| return @call(.always_tail, c, .{t});\n")
                                   (map (lambda (x i) (cat "        " x " = t.args[" i "];\n")) spilled (iota k))
                                   (list "    }"))))))
                  (block-lines b)))))))

    ;; a call of the loop in its body: assign the parameters, continue
    (define (cg-loop-again loop args b env)
      (let* ((as (map (lambda (a) (cg-simple a b env)) args))
             ;; copy first: an argument may be another parameter's var
             (copies (map (lambda (a pv) (and pv (temp! b a))) as (caddr loop))))
        (for-each (lambda (pv c) (when pv (emit! b pv " = " c ";"))) (caddr loop) copies)
        (emit! b "continue :" (cadr loop) ";")))

    ;; --- lambdas -----------------------------------------------------------

    (define (gen-lambda l)
      (let ((name (cat "L" (local-id l))))
        (unless (hash-table-ref/default lambdas-made name #f)
          (hash-table-set! lambdas-made name #t)
          (when (lam-doc l)
            (add-init! (cat "    rt.setDoc(&" name ", \"" (zig-escape (lam-doc l)) "\");")))
          (let* ((b (make-block name))
                 (params (lam-params l))
                 (rest (lam-rest l))
                 (n (length params))
                 (used (refs (lam-body l))))
            (if rest
                (prologue! b "if (t.argc < " n ") return @call(.always_tail, rt.arityErrorN(t, " n ", true), .{t});")
                (prologue! b "if (t.argc != " n ") return @call(.always_tail, rt.arityErrorN(t, " n ", false), .{t});"))
            (let* ((env (let loop ((ps params) (i 0) (env '()))
                          (if (null? ps)
                              env
                              (loop (cdr ps) (+ i 1)
                                    (if (memq (car ps) used)
                                        (bind-param (car ps) (cat "t.args[" i "]") b env)
                                        env)))))
                   (env (if (and rest (memq rest used))
                            (begin
                              (set-block-dyn-alloc! b (cat "3 * (t.argc - " n ")"))
                              (bind-param rest (cat "rt.restList(t, " n ")") b env))
                            env))
                   (env (let loop ((fs (lam-free l)) (i 0) (env env))
                          (if (null? fs)
                              env
                              ;; free variables hold the box of an assigned variable
                              (let ((name (local-name (car fs))))
                                (emit! b "const " name " = t.free(" i ");")
                                (loop (cdr fs) (+ i 1) (bind env (car fs) name #t)))))))
              (cg-tail (lam-body l) b env)
              (finish-block! b))))
        name))
    (define lambdas-made (make-hash-table string=?))

    (define (bind-param v expr b env)
      (if (var-assigned? v)
          (begin
            (alloc! b 2)
            (emit! b "const " (local-name v) " = t.box(" expr ");"))
          (emit! b "const " (local-name v) " = " expr ";"))
      (bind env v (local-name v) #t))

    ;; --- modules -----------------------------------------------------------

    ;; The symbol part for a module: (scheme base) -> scheme_base
    (define (module-symbol name)
      (if (eq? name 'program)
          "program"
          (let loop ((parts name) (acc ""))
            (if (null? parts)
                acc
                (loop (cdr parts)
                      (cat acc (if (string=? acc "") "" "_")
                           (mangle "" (let ((p (car parts)))
                                        (if (symbol? p) (symbol->string p) (number->string p))))))))))

    ;; prefix and s with every character that is not an ASCII letter or digit
    ;; as _xx (as exports.zig mangles primitive names)
    (define (mangle prefix s)
      (let ((out (open-output-string)))
        (write-string prefix out)
        (string-for-each
         (lambda (c)
           (if (or (char<=? #\a c #\z) (char<=? #\A c #\Z) (char<=? #\0 c #\9))
               (write-char c out)
               (let ((b (char->integer c)))
                 (if (< b 128)
                     (begin (write-char #\_ out)
                            (write-char (string-ref hex (quotient b 16)) out)
                            (write-char (string-ref hex (remainder b 16)) out))
                     ;; beyond ASCII: each UTF-8 byte
                     (let ((bv (string->utf8 (string c))))
                       (let loop ((i 0))
                         (when (< i (bytevector-length bv))
                           (let ((x (bytevector-u8-ref bv i)))
                             (write-char #\_ out)
                             (write-char (string-ref hex (quotient x 16)) out)
                             (write-char (string-ref hex (remainder x 16)) out))
                           (loop (+ i 1)))))))))
         s)
        (get-output-string out)))

    (define (reset-module! sym)
      (set! module-sym sym)
      (set! blocks '())
      (set! statics '())
      (set! init-lines '())
      ;; hash tables: a large module (a test program) has tens of thousands
      ;; of lambdas, and lists made the emitter quadratic
      (set! constant-symbols (make-hash-table eq?))
      (set! constant-numbers '())
      (set! statics-made (make-hash-table string=?))
      (set! lambdas-made (make-hash-table string=?))
      (set! primitive-procs '())
      (set! externs '())
      (set! own-globals 0)
      (set! counter 0)
      (set! local-ids (make-hash-table eq?)))

    ;; modules: list of (name . body) in initialization order, the program
    ;; last; bodies in ANF with free variables computed.
    ;; Returns a list of (module-symbol . zig-source).
    (define (emit-modules modules prims)
      (set! primitive-names prims)
      (set! global-table (make-hash-table eq?))
      (set! module-sizes '())
      (map (lambda (m)
             (let ((sym (module-symbol (car m))))
               (reset-module! sym)
               (start-refs-memo!)
               (let* ((entry (gen-lambda (make-lam '() #f (cdr m) 'toplevel)))
                      (extra (if (eq? (car m) 'program) (program-tables modules entry) "")))
                 (set! module-sizes (cons (cons sym own-globals) module-sizes))
                 (stop-refs-memo!)
                 (cons sym (module-source sym entry extra)))))
           modules))

    (define (module-source sym entry extra)
      (apply cat
             "//! Generated by scmc (dabscm native). Do not edit.\n"
             "const std = @import(\"std\");\n"
             "const rt = @import(\"rt\");\n"
             "const Thread = rt.Thread;\n"
             "const Word = rt.Word;\n\n"
             (append
              (map (lambda (s) (cat s "\n")) (reverse externs))
              (list "\nexport var " (globals-array sym) ": [" (max 1 own-globals) "]Word = @splat(rt.UNBOUND);\n\n")
              (map (lambda (s) (cat s "\n")) (reverse statics))
              (list "\nexport fn scml_" sym "_init(t: *Thread) callconv(.c) void {\n"
                    "    @setEvalBranchQuota(100000000);\n    const t_ = t; // init may not use t\n    _ = t_;\n"
                    (apply cat (map (lambda (l) (cat l "\n")) (reverse init-lines)))
                    "}\n\n"
                    "comptime {\n    @export(&" entry ", .{ .name = \"scml_" sym "_entry\" });\n}\n\n"
                    extra)
              (map (lambda (s) (cat s "\n")) (reverse blocks)))))

    ;; The program's tables: its modules, and where the specials are
    (define (program-tables modules entry)
      (let* ((syms (map (lambda (m) (module-symbol (car m))) modules))
             (descs
              (map (lambda (sym)
                     (unless (string=? sym "program")
                       (add-extern! (cat "extern fn scml_" sym "_init(t: *Thread) callconv(.c) void;"))
                       (add-extern! (cat "extern fn scml_" sym "_entry(t: *Thread) callconv(.c) void;"))
                       (add-extern! (cat "extern var " (globals-array sym) ": ["
                                         (max 1 (cdr (assoc sym module-sizes))) "]Word;")))
                     (cat "    .{ .init = &scml_" sym "_init, .entry = "
                          (if (string=? sym "program") (cat "&" entry) (cat "&scml_" sym "_entry"))
                          ", .globals = &" (globals-array sym) ", .nglobals = "
                          (if (string=? sym "program") (cat (globals-array "program") ".len")
                              (max 1 (cdr (assoc sym module-sizes))))
                          " },\n"))
                   syms))
             (eval-setup
              (if eval-state
                  (cons (cat "    rt.setEvalState(eval_state);\n")
                        (map (lambda (g) (cat "    rt.registerGlobal(\"" (zig-escape (glob-name g)) "\", &" (global-place g) ");\n"))
                             (list-sort (lambda (a b) (string<? (glob-name a) (glob-name b)))
                                        (hash-table-keys global-table))))
                  '()))
             (specials
              (filter-map
               (lambda (s)
                 (let ((g (find (lambda (g) (and (equal? (glob-lib g) (car (car s)))
                                                 (eq? (glob-sym g) (cadr (car s)))))
                                (hash-table-keys global-table))))
                   (and g (cat "    t.specials[@intFromEnum(rt.Special." (cadr s) ")] = &" (global-place g) ";\n"))))
               special-globals)))
        (apply cat
               "const modules = [_]rt.Module{\n"
               (append descs
                       (list "};\n\n"
                             "export fn scm_program_modules() callconv(.c) rt.ModuleList {\n"
                             "    return .{ .modules = &modules, .count = modules.len };\n}\n\n"
                             "export fn scm_program_eager() callconv(.c) usize {\n"
                             "    return " (if eager-modules (number->string eager-modules) "modules.len - 1")
                             ";\n}\n\n"
                             "export fn scm_program_version() callconv(.c) [*:0]const u8 {\n"
                             "    return \"" program-version "\";\n}\n\n"
                             "export fn scm_program_specials(t: *Thread) callconv(.c) void {\n"
                             "    const t_ = t;\n    _ = t_;\n")
                       specials
                       (map (lambda (l)
                              (cat "    rt.registerLibrary(\"" (zig-escape (datum->string (car l))) "\", \""
                                   (zig-escape (apply cat (map (lambda (e) (cat (if (eq? (cdr e) 'syntax) "s" "u")
                                                                                (symbol->string (car e)) " "))
                                                               (cdr l))))
                                   "\");\n"))
                            user-libraries)
                       eval-setup
                       (list "}\n\n")
                       (if eval-state
                           (list "const eval_state = \"" (zig-escape eval-state) "\";\n\n")
                           '())))))

    ;; libraries not in runtime/library_exports.zig: (name (sym . kind) ...)
    (define user-libraries '())
    (define (set-user-libraries! l) (set! user-libraries l))

    (define (datum->string d)
      (let ((out (open-output-string))) (write d out) (get-output-string out)))

    ;; the expander state's text for a program that links eval, else #f
    (define eval-state #f)
    (define (set-eval-state! s) (set! eval-state s))

    ;; libraries initialized before the program (the others at their import)
    (define eager-modules #f)
    (define (set-eager-modules! n) (set! eager-modules n))

    ;; the dabscm version, for sys-scm-version
    (define program-version "unknown")
    (define (set-program-version! v) (set! program-version v))

    (define special-globals
      '((((scheme base) raise) raise)
        (((scm core) *input-port*) input_port)
        (((scm core) *output-port*) output_port)
        (((scm core) *error-port*) error_port)
        (((scm native eval) %eval-hook) eval_hook)))


    ;; --- strings -----------------------------------------------------------

    (define (join strs sep)
      ;; a port: appending to the result is quadratic (a large bytevector
      ;; constant has a million elements)
      (if (null? strs)
          ""
          (let ((out (open-output-string)))
            (write-string (car strs) out)
            (for-each (lambda (s) (write-string sep out) (write-string s out)) (cdr strs))
            (get-output-string out))))

    (define (bytevector->list bv)
      (let loop ((i (- (bytevector-length bv) 1)) (acc '()))
        (if (< i 0) acc (loop (- i 1) (cons (bytevector-u8-ref bv i) acc)))))

    (define hex "0123456789abcdef")

    ;; A Zig string literal body for the UTF-8 encoding of s
    (define (zig-escape s)
      (let ((bv (string->utf8 s))
            (out (open-output-string)))
        (let loop ((i 0))
          (when (< i (bytevector-length bv))
            (let ((byte (bytevector-u8-ref bv i)))
              (if (and (>= byte 32) (< byte 127) (not (= byte 34)) (not (= byte 92)))
                  (write-char (integer->char byte) out)
                  (begin
                    (write-string "\\x" out)
                    (write-char (string-ref hex (quotient byte 16)) out)
                    (write-char (string-ref hex (remainder byte 16)) out))))
            (loop (+ i 1))))
        (get-output-string out)))))

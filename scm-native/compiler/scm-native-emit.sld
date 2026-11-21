(define-library (scm native emit)
  (export emit-program)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme inexact)
          (scheme write)
          (srfi 1)
          (scm native ast)
          (scm native anf)
          (scm native expand))
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
    (define globals '())       ; (glob . index)
    (define primitive-names '())
    (define primitive-procs '()) ; (name . zig-var) static procedures
    (define constants '())     ; (datum . zig-name)
    (define counter 0)

    (define (next!)
      (set! counter (+ counter 1))
      counter)

    (define (add-static! s) (set! statics (cons s statics)))
    (define (add-init! s) (set! init-lines (cons s init-lines)))

    (define (global-index g)
      (cond ((assq g globals) => cdr)
            (else
             (let ((i (length globals)))
               (set! globals (cons (cons g i) globals))
               i))))

    (define (implemented? name) (assq name primitive-names))

    ;; The static procedure object of a primitive (a file-level variable)
    (define (primitive-proc name)
      (cond ((assq name primitive-procs) => cdr)
            (else
             (let ((v (cat "p" (next!))))
               (set! primitive-procs (cons (cons name v) primitive-procs))
               (add-static! (cat "var " v ": Word = undefined;"))
               (add-init! (if (implemented? name)
                              (cat "    " v " = rt.primitive(" (prim-code name) ", \""
                                   (zig-escape (symbol->string name)) "\");")
                              (cat "    " v " = rt.missingPrimitive(\"" (zig-escape (symbol->string name)) "\");")))
               v))))

    ;; primitive-names: alist name -> runtime module
    (define (prim-code name)
      (cat "rt." (cdr (assq name primitive-names)) ".@\"%" (zig-escape (symbol->string name)) "\""))

    ;; --- blocks ------------------------------------------------------------

    (define-record-type block
      (%make-block name prologue lines alloc dyn-alloc)
      block?
      (name block-name)
      (prologue block-prologue set-block-prologue!)
      (lines block-lines set-block-lines!)
      (alloc block-alloc set-block-alloc!)
      (dyn-alloc block-dyn-alloc set-block-dyn-alloc!))

    (define (make-block name) (%make-block name '() '() 0 #f))

    (define (emit! b . pieces)
      (set-block-lines! b (cons (apply cat "    " pieces) (block-lines b))))

    (define (prologue! b . pieces)
      (set-block-prologue! b (cons (apply cat "    " pieces) (block-prologue b))))

    (define (alloc! b n) (set-block-alloc! b (+ (block-alloc b) n)))

    (define (finish-block! b)
      (let* ((n (block-alloc b))
             (dyn (block-dyn-alloc b))
             (reserve (cond ((and dyn (> n 0)) (list (cat "    t.reserve(" dyn " + " n ");")))
                            (dyn (list (cat "    t.reserve(" dyn ");")))
                            ((> n 0) (list (cat "    t.reserve(" n ");")))
                            (else '()))))
        (set! blocks
              (cons (apply cat
                           (cat "fn " (block-name b) "(t: *Thread) callconv(.c) void {\n")
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

    (define (local-name v) (cat "v" (var-id v)))

    (define (bind env v expr local?) (cons (list v expr local?) env))

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
            ;; literals are distinct objects (as in the JVM implementation),
            ;; except those that cannot be mutated
            ((and (or (symbol? d) (number? d)) (assoc d constants)) => cdr)
            (else
             (let ((name (cat "c" (next!)))
                   (init (constant-init d)))
               (set! constants (cons (cons d name) constants))
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
           ;; set! returns the value (as the JVM implementation)
           a))
        ((gset)
         (let ((a (cg-simple (caddr e) b env)))
           (emit! b "t.globals[" (global-index (cadr e)) "] = " a ";")
           a))
        ((gdef)
         (let ((a (cg-simple (caddr e) b env)))
           (emit! b "t.globals[" (global-index (cadr e)) "] = " a ";")
           "rt.UNSPEC"))
        ((lambda) (cg-closure (cadr e) b env))
        ((prim) (cg-prim (cadr e) (map (lambda (a) (cg-simple a b env)) (cddr e)) b))
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
      (let* ((i (global-index g))
             (v (temp! b (cat "t.globals[" i "]"))))
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
                                 (bind env2 v (static-closure l) #f)
                                 (let ((c (cat "cl" (var-id v))))
                                   (alloc! b (+ 2 (length (lam-free l))))
                                   (emit! b "const " c " = t.closure(&" (gen-lambda l) ", "
                                          (length (lam-free l)) ");")
                                   (emit! b "const " (local-name v) " = rt.tagPtr(" c ");")
                                   (bind env2 v (local-name v) #t)))))
                         env live)))
        (for-each (lambda (bd)
                    (let ((l (cadr (cadr bd))))
                      (unless (null? (lam-free l))
                        (fill-closure! (cat "cl" (var-id (car bd))) l b env2))))
                  live)
        env2))

    (define (fill-closure! c l b env)
      (let loop ((fs (lam-free l)) (i 2))
        (unless (null? fs)
          (emit! b c "[" i "] = " (lookup env (car fs)) ";")
          (loop (cdr fs) (+ i 1)))))

    (define (static-closure l)
      (let ((name (cat "s" (lam-id l))))
        (unless (member name statics-made)
          (set! statics-made (cons name statics-made))
          (add-static! (cat "var " name ": Word = undefined;"))
          (add-init! (cat "    " name " = rt.staticProc(&" (gen-lambda l) ");")))
        name))
    (define statics-made '())

    (define (cg-closure l b env)
      (if (null? (lam-free l))
          (static-closure l)
          (let ((c (cat "cl" (next!))))
            (alloc! b (+ 2 (length (lam-free l))))
            (emit! b "const " c " = t.closure(&" (gen-lambda l) ", " (length (lam-free l)) ");")
            (fill-closure! c l b env)
            (temp! b (cat "rt.tagPtr(" c ")")))))

    ;; --- open-coded primitives ---------------------------------------------

    (define (cg-prim op as b)
      (define (a i) (list-ref as i))
      (define (pred expr) (temp! b (cat "rt.boolean(" expr ")")))
      (define (check! test msg . atoms)
        (emit! b "if (!(" test ")) " (fail-stmt msg atoms) ";"))
      (define (type-fail name . atoms)
        (cat "return @call(.always_tail, rt.typeError(t, \"" (zig-escape name) "\", &.{"
             (join atoms ", ") "}), .{t})"))
      (define (arith-fail name)
        (cat "return @call(.always_tail, rt.arithError(t, \"" name "\", " (a 0) ", " (a 1) "), .{t})"))
      (define (arith fn name)
        (alloc! b 2)
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
         "rt.UNSPEC")
        ((vector-length)
         (emit! b "if (!rt.data.isVector(" (a 0) ")) " (type-fail "vector-length") ";")
         (temp! b (cat "rt.fix(@intCast(rt.data.vectorLen(" (a 0) ")))")))
        ((char->integer)
         (emit! b "if (!rt.isChar(" (a 0) ")) " (type-fail "char->integer") ";")
         (temp! b (cat "rt.fix(rt.charCode(" (a 0) "))")))
        (else (error "cg-prim: unknown primitive" op))))

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
        ((letrec) (cg-tail (caddr e) b (cg-letrec (cadr e) (caddr e) b env)))
        ((call) (cg-call (cadr e) (cddr e) b env))
        (else
         (let ((a (cg-simple e b env)))
           (emit! b "t.val = " a ";")
           (emit! b tail-call-ret)))))

    (define (cg-call f args b env)
      (let* ((direct (and (eq? (node-kind f) 'primref) (implemented? (cadr f))))
             (global (eq? (node-kind f) 'gref))
             (fa (and (not direct) (not global) (cg-simple f b env)))
             (as (map (lambda (a) (cg-simple a b env)) args))
             (n (length as)))
        (when (> n 256) (emit! b "t.ensureArgs(" n ");"))
        (let loop ((as as) (i 0))
          (unless (null? as)
            (emit! b "t.args[" i "] = " (car as) ";")
            (loop (cdr as) (+ i 1))))
        (emit! b "t.argc = " n ";")
        (cond (direct
               (emit! b "return @call(.always_tail, rt.primCode(" (prim-code (cadr f)) "), .{t});"))
              (global
               (emit! b "return @call(.always_tail, rt.enterGlobal(t, " (global-index (cadr f)) "), .{t});"))
              (else
               (emit! b "return @call(.always_tail, rt.enter(t, " fa "), .{t});")))))

    ;; (let ((v rhs)) body) with a complex rhs: save the live values in a
    ;; frame, evaluate rhs in tail position, continue in a return block.
    (define (cg-nontail-call v rhs body b env)
      (let* ((used (refs body))
             (live (filter (lambda (entry) (and (memq (car entry) used) (caddr entry)))
                           (delete-duplicates env (lambda (x y) (eq? (car x) (car y))))))
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

    ;; --- lambdas -----------------------------------------------------------

    (define (gen-lambda l)
      (let ((name (cat "L" (lam-id l))))
        (unless (member name lambdas-made)
          (set! lambdas-made (cons name lambdas-made))
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
    (define lambdas-made '())

    (define (bind-param v expr b env)
      (if (var-assigned? v)
          (begin
            (alloc! b 2)
            (emit! b "const " (local-name v) " = t.box(" expr ");"))
          (emit! b "const " (local-name v) " = " expr ";"))
      (bind env v (local-name v) #t))

    ;; --- program -----------------------------------------------------------

    ;; ast: the program as Core IR in ANF with free variables computed.
    ;; Returns the Zig source of the program module.
    (define (emit-program ast prims)
      (set! blocks '())
      (set! statics '())
      (set! init-lines '())
      (set! globals '())
      (set! constants '())
      (set! statics-made '())
      (set! lambdas-made '())
      (set! primitive-names prims)
      (set! primitive-procs '())
      (let* ((main (make-lam '() #f ast 'toplevel))
             (entry (gen-lambda main))
             (names (map (lambda (g) (glob-name (car g))) (sort-by-index globals))))
        ;; tell the runtime where the globals are that it uses itself
        (for-each (lambda (g)
                    (let ((s (assoc (list (glob-lib (car g)) (glob-sym (car g))) special-globals)))
                      (when s
                        (add-init! (cat "    t.specials[@intFromEnum(rt.Special." (cadr s) ")] = " (cdr g) ";")))))
                  globals)
        (apply cat
               "//! Generated by scmc (dabscm native). Do not edit.\n"
               "const std = @import(\"std\");\n"
               "const rt = @import(\"rt\");\n"
               "const Thread = rt.Thread;\n"
               "const Word = rt.Word;\n\n"
               "pub const program: rt.Program = .{ .names = &names, .init = &init, .entry = &" entry " };\n"
               "const names = [_][]const u8{ "
               (join (map (lambda (n) (cat "\"" (zig-escape n) "\"")) names) ", ")
               " };\n\n"
               (append
                (map (lambda (s) (cat s "\n")) (reverse statics))
                (list "\nfn init(t: *Thread) void {\n"
                      "    @setEvalBranchQuota(100000000);\n    const t_ = t; // init may not use t\n    _ = t_;\n"
                      (apply cat (map (lambda (l) (cat l "\n")) (reverse init-lines)))
                      "}\n\n")
                (map (lambda (s) (cat s "\n")) (reverse blocks))))))

    (define special-globals
      '((((scheme base) raise) raise)
        (((scm core) *input-port*) input_port)
        (((scm core) *output-port*) output_port)
        (((scm core) *error-port*) error_port)))

    (define (sort-by-index gs)
      (let loop ((i 0) (acc '()))
        (if (= i (length gs))
            (reverse acc)
            (loop (+ i 1) (cons (find (lambda (g) (= (cdr g) i)) gs) acc)))))

    ;; --- strings -----------------------------------------------------------

    (define (join strs sep)
      (if (null? strs)
          ""
          (fold (lambda (s acc) (string-append acc sep s)) (car strs) (cdr strs))))

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

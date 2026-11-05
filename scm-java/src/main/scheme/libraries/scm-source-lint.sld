(define-library (scm source lint)
  (import (scheme base)
          (scheme char)
          (scheme write)
          (srfi 69)
          (scm fs)
          (scm io)
          (scm source)
          (scm source format))
  (export lint-command
          lint-file
          lint-finding-col
          lint-finding-file
          lint-finding-line
          lint-finding-message
          lint-finding-rule
          lint-finding-severity
          lint-finding?
          lint-findings->json
          lint-findings->text
          lint-options
          lint-rules
          lint-string)
  (begin

    ;; ================================================================
    ;; (scm source lint) — the static checker behind `scm lint`.
    ;;
    ;; It reads a file with (scm source) and walks the code with a scope
    ;; analysis that knows the core and derived forms of R7RS. The global
    ;; environment is what the file imports (the exports of built-in
    ;; libraries are loaded, project libraries are read statically from
    ;; their .sld files) plus its own definitions. Uses of macros it does
    ;; not know are not looked into: every identifier in them counts as
    ;; used and none is reported as unbound, so they cause no false
    ;; positives. When an imported library cannot be resolved, or the
    ;; file includes other files, unbound identifiers are not reported.
    ;;
    ;; Findings carry a rule id, a severity (error, warning, info), the
    ;; position and a message. Rules can be switched off and on by the
    ;; command line, the [lint] table of scm-tools.toml, a
    ;; `;; lint: disable rule ...` comment (whole file) or a
    ;; `; lint: ignore rule ...` comment (its line, or the next line
    ;; when the comment is on a line of its own; without rule names it
    ;; silences every rule there).
    ;; ================================================================

    ;; ---- rules -----------------------------------------------------

    ;; (id severity enabled-by-default? description)
    (define rule-table
      '((read-error error #t
         "the file cannot be read (unbalanced parentheses, bad syntax)")
        (unbound-identifier error #t
         "an identifier that is neither local, defined, imported nor a core form")
        (unused-import warning #t
         "an import none of whose names is used or re-exported")
        (unused-only-name warning #t
         "a name in (only ...) that is never used")
        (import-conflict warning #t
         "two imports bind the same name to different things (the last one wins)")
        (duplicate-import warning #t "the same import set appears twice")
        (unused-local warning #t
         "a local variable or internal definition that is never used")
        (unused-parameter warning #f
         "a procedure parameter that is never used")
        (unused-definition warning #t
         "a top-level definition of a library that is neither exported nor used")
        (duplicate-definition error #t
         "a name defined twice in the same body or library")
        (export-undefined error #t
         "an exported name that is neither defined nor imported")
        (duplicate-export warning #t "a name exported twice")
        (shadowed-import info #f "a local binding hides an imported name")
        (set-imported error #t "set! of an imported binding")
        (arity-mismatch error #t
         "a call with the wrong number of arguments to a procedure defined in the file")
        (malformed-form error #t
         "a special form with the wrong shape (if arity, else not last, bad bindings, empty body)")
        (definition-context warning #t
         "a definition where only expressions are allowed")
        (duplicate-case-datum warning #t
         "a datum that appears in two case clauses")
        (unreachable-clause warning #t
         "a cond clause after one whose test is always true")
        (eq-literal warning #t
         "eq?/memq/assq on a number, character or string literal (use eqv?, equal?, string=?)")
        (if-boolean info #t "(if c #t #f) is c, (if c #f #t) is (not c)")
        (if-without-else info #t "a one-armed if (use when or unless)")
        (nested-if info #t
         "an if nested three levels deep in else branches (use cond)")
        (cxr info #t
         "a car/cdr composition with a standard name (cadr, cddr, ...)")
        (null-compare info #t "a comparison with '() (use null?)")
        (length-zero info #t
         "a length compared with 0 (use null? or pair?, which do not walk the list)")
        (append-list info #t "(append (list x) y) is (cons x y)")
        (redundant-call info #t
         "string-append or append with a single argument")
        (begin-single info #t "(begin e) in expression position is e")
        (empty-let info #t "(let () e) without definitions is e")
        (eta-lambda info #t "(lambda (x) (f x)) is f")
        (define-lambda info #f
         "(define f (lambda (x) ...)) can be written (define (f x) ...)")
        (predicate-naming info #f
         "a procedure that only returns booleans whose name does not end in ?")
        (missing-docstring warning #t
         "an exported procedure without a Syntax:/Library: docstring (configured libraries)")
        (docstring-syntax-mismatch warning #t
         "the docstring's Syntax: line names a different procedure")
        (docstring-library-mismatch warning #t
         "the docstring's Library: line names a different library")
        (library-file-name warning #t
         "the .sld file name does not match the library name")
        (unsorted-imports info #t "the imports are not in scm fmt order")
        (unsorted-exports info #t "the exports are not in scm fmt order")
        (line-too-long info #t
         "a code line longer than the width (long strings and comments are exempt)")
        (trailing-whitespace info #t "whitespace at the end of a line")
        (tab-character info #t "a tab character outside strings")
        (missing-final-newline info #t "the file does not end with a newline")
        (not-formatted info #t
         "scm fmt would change the file (only with --fmt-check)")))

    (define (lint-rules)
      "Syntax: (lint-rules)
Library: (scm source lint)
Description: Returns the linter's rules as a list of (id severity
  enabled-by-default? description), id and severity being symbols.
Example:
  (car (lint-rules))
    => (read-error error #t \"the file cannot be read ...\")"
      rule-table)

    (define (rule-severity id)
      (let ((r (assq id rule-table))) (if r (cadr r) 'info)))

    ;; ---- findings --------------------------------------------------

    (define-record-type lint-finding
      (make-lint-finding rule severity file line col message)
      lint-finding?
      (rule lint-finding-rule)
      (severity lint-finding-severity)
      (file lint-finding-file)
      (line lint-finding-line)
      (col lint-finding-col)
      (message lint-finding-message))

    (define (severity-rank s)
      (case s
        ((error) 3)
        ((warning) 2)
        (else 1)))

    (define (lint-findings->text findings)
      "Syntax: (lint-findings->text findings)
Library: (scm source lint)
Description: Formats a list of findings one per line as
  file:line:column: severity: [rule] message (line and column from 1),
  the format compilers use, so editors can jump to the places.
Example:
  (lint-findings->text (lint-string \"(define (f x) 1)\" \"a.scm\"))
    => \"\""
      (let ((out (open-output-string)))
        (for-each (lambda (f)
                    (write-string (string-append
                                   (lint-finding-file f)
                                   ":"
                                   (number->string (lint-finding-line f))
                                   ":"
                                   (number->string (+ 1 (lint-finding-col f)))
                                   ": "
                                   (symbol->string (lint-finding-severity f))
                                   ": ["
                                   (symbol->string (lint-finding-rule f))
                                   "] "
                                   (lint-finding-message f)
                                   "\n")
                                  out))
                  findings)
        (get-output-string out)))

    (define (json-string s)
      (let ((out (open-output-string)))
        (write-char #\" out)
        (string-for-each (lambda (c)
                           (case c
                             ((#\") (write-string "\\\"" out))
                             ((#\\) (write-string "\\\\" out))
                             ((#\newline) (write-string "\\n" out))
                             ((#\return) (write-string "\\r" out))
                             ((#\tab) (write-string "\\t" out))
                             (else (if (< (char->integer c) 32)
                                       (write-string
                                        (string-append
                                         "\\u00"
                                         (if (< (char->integer c) 16) "0" "")
                                         (number->string (char->integer c)
                                                         16))
                                        out)
                                       (write-char c out)))))
                         s)
        (write-char #\" out)
        (get-output-string out)))

    (define (lint-findings->json findings)
      "Syntax: (lint-findings->json findings)
Library: (scm source lint)
Description: Formats a list of findings as a JSON array of objects with
  the keys file, line, column (both from 1), severity, rule and message.
Example:
  (lint-findings->json '()) => \"[]\""
      (let ((out (open-output-string)))
        (write-string "[" out)
        (let loop ((fs findings) (first #t))
          (unless (null? fs)
            (let ((f (car fs)))
              (unless first (write-string "," out))
              (write-string (string-append
                             "\n  {\"file\": "
                             (json-string (lint-finding-file f))
                             ", \"line\": "
                             (number->string (lint-finding-line f))
                             ", \"column\": "
                             (number->string (+ 1 (lint-finding-col f)))
                             ", \"severity\": "
                             (json-string
                              (symbol->string (lint-finding-severity f)))
                             ", \"rule\": "
                             (json-string
                              (symbol->string (lint-finding-rule f)))
                             ", \"message\": "
                             (json-string (lint-finding-message f))
                             "}")
                            out))
            (loop (cdr fs) #f)))
        (write-string (if (null? findings) "]" "\n]") out)
        (get-output-string out)))

    ;; ---- options ---------------------------------------------------

    (define (lint-options path . overrides)
      "Syntax: (lint-options path [overrides])
Library: (scm source lint)
Description: Returns the linter options for the file path: the defaults,
  overridden by the [lint] table (and the width and library-path of the
  [format] table) of the nearest scm-tools.toml, overridden by the alist
  overrides. Keys: enable and disable (lists of rule id symbols, added to
  or removed from the rules enabled by default), width (78),
  docstring-libraries (list of first parts of library names whose
  exported procedures need docstrings, default (\"scm\")), library-path
  (directories with the .sld files of project libraries) and fmt-check
  (#f; #t adds the not-formatted rule).
Example:
  (cdr (assq 'width (lint-options \"src/a.sld\"))) => 78"
      (let* ((cfg (tools-config path))
             (dir (tools-config-ref cfg '("dir") "."))
             (sym-list (lambda (v) (if (list? v) (map string->symbol v) '())))
             (abs-dirs (lambda (v)
                         (if (list? v)
                             (map (lambda (d)
                                    (if
                                     (and (> (string-length d) 0)
                                          (char=? (string-ref d 0) #\/))
                                     d
                                     (string-append dir "/" d)))
                                  v)
                             '())))
             (over (if (pair? overrides) (car overrides) '()))
             (get (lambda (k default)
                    (cond ((assq k over) => cdr)
                          (else default)))))
        (list (cons 'enable
                    (append (get 'enable '())
                            (sym-list (tools-config-ref cfg
                                                        '("lint" "enable")
                                                        '()))))
              (cons 'disable
                    (append (get 'disable '())
                            (sym-list (tools-config-ref cfg
                                                        '("lint" "disable")
                                                        '()))))
              (cons 'width
                    (get 'width
                         (tools-config-ref
                          cfg
                          '("lint" "width")
                          (tools-config-ref cfg '("format" "width") 78))))
              (cons 'docstring-libraries
                    (get 'docstring-libraries
                         (tools-config-ref cfg
                                           '("lint" "docstring-libraries")
                                           '("scm"))))
              (cons 'library-path
                    (get 'library-path
                         (append (abs-dirs
                                  (tools-config-ref cfg
                                                    '("lint" "library-path")
                                                    '()))
                                 (abs-dirs
                                  (tools-config-ref cfg
                                                    '("format" "library-path")
                                                    '())))))
              (cons 'format-options (format-options path))
              (cons 'fmt-check (get 'fmt-check #f)))))

    (define (opt opts key default)
      (cond ((assq key opts) => cdr)
            (else default)))

    ;; ---- small helpers ---------------------------------------------

    (define (string-prefix? p s)
      (and (<= (string-length p) (string-length s))
           (string=? p (substring s 0 (string-length p)))))

    (define (string-suffix? p s)
      (and (<= (string-length p) (string-length s))
           (string=? p
                     (substring s (- (string-length s) (string-length p))))))

    (define (string-index-of s ch)
      (let loop ((k 0))
        (cond ((= k (string-length s)) #f)
              ((char=? (string-ref s k) ch) k)
              (else (loop (+ k 1))))))

    (define (trim s)
      (let* ((n (string-length s))
             (a (let loop ((k 0))
                  (if (and (< k n) (char-whitespace? (string-ref s k)))
                      (loop (+ k 1))
                      k)))
             (b (let loop ((k n))
                  (if (and (> k a) (char-whitespace? (string-ref s (- k 1))))
                      (loop (- k 1))
                      k))))
        (substring s a b)))

    (define (split-words s)
      ;; split on whitespace and commas
      (let loop ((cs (string->list s))
                 (cur '())
                 (acc '()))
        (define (flush)
          (if (null? cur) acc (cons (list->string (reverse cur)) acc)))
        (cond ((null? cs) (reverse (flush)))
              ((or (char-whitespace? (car cs)) (char=? (car cs) #\,))
               (loop (cdr cs) '() (flush)))
              (else (loop (cdr cs) (cons (car cs) cur) acc)))))

    (define (any? pred lst)
      (and (pair? lst) (or (pred (car lst)) (any? pred (cdr lst)))))

    (define (every? pred lst)
      (or (null? lst) (and (pred (car lst)) (every? pred (cdr lst)))))

    (define (datum->string d)
      (let ((o (open-output-string)))
        (write d o)
        (get-output-string o)))

    (define (code-items node)
      (let loop ((ks (cst-children node))
                 (acc '()))
        (cond ((null? ks) (reverse acc))
              ((memq (cst-kind (car ks))
                     '(comment block-comment directive datum-comment))
               (loop (cdr ks) acc))
              (else (loop (cdr ks) (cons (car ks) acc))))))

    (define (symbol-node? node)
      (and (eq? (cst-kind node) 'atom)
           (let ((t (cst-text node)))
             (and (> (string-length t) 0)
                  (not (memv (string-ref t 0) '(#\" #\#)))
                  (not (string->number t))
                  (not (member (string-downcase t)
                               '("+inf.0" "-inf.0" "+nan.0" "-nan.0")))))))

    (define (node-symbol node)
      (let ((t (cst-text node)))
        (if (string-index-of t #\|)
            (let ((d (cst->datum node)))
              (if (symbol? d) d (string->symbol t)))
            (string->symbol t))))

    (define (list-node? node) (eq? (cst-kind node) 'list))

    (define (head-symbol node)
      (and (list-node? node)
           (let ((items (code-items node)))
             (and (pair? items)
                  (symbol-node? (car items))
                  (node-symbol (car items))))))

    (define (string-node? node)
      (and (eq? (cst-kind node) 'atom)
           (let ((t (cst-text node)))
             (and (> (string-length t) 0)
                  (or (char=? (string-ref t 0) #\")
                      (string-prefix? "#<<" t))))))

    (define (literal-kind node)
      ;; number, string, char or #f
      (and (eq? (cst-kind node) 'atom)
           (let ((t (cst-text node)))
             (cond ((string-node? node) 'string)
                   ((string-prefix? "#\\" t) 'char)
                   ((string->number t) 'number)
                   (else #f)))))

    (define (empty-list-literal? node)
      (and (eq? (cst-kind node) 'prefix)
           (string=? (cst-text node) "'")
           (let ((kids (code-items node)))
             (and (= (length kids) 1)
                  (list-node? (car kids))
                  (null? (code-items (car kids)))))))

    (define (true-literal? node)
      (and (eq? (cst-kind node) 'atom)
           (member (cst-text node) '("#t" "#true"))))
    (define (false-literal? node)
      (and (eq? (cst-kind node) 'atom)
           (member (cst-text node) '("#f" "#false"))))

    (define (formals->names node)
      ;; -> (values names-with-nodes rest-node-or-#f ok?)
      (case (cst-kind node)
        ((atom)
         (if (symbol-node? node) (values '() node #t) (values '() #f #f)))
        ((list)
         (let loop ((ks (code-items node))
                    (acc '()))
           (cond ((null? ks) (values (reverse acc) #f #t))
                 ((eq? (cst-kind (car ks)) 'dot)
                  (if (and (pair? (cdr ks))
                           (null? (cddr ks))
                           (symbol-node? (cadr ks)))
                      (values (reverse acc) (cadr ks) #t)
                      (values (reverse acc) #f #f)))
                 ((symbol-node? (car ks)) (loop (cdr ks) (cons (car ks) acc)))
                 (else (values (reverse acc) #f #f)))))
        (else (values '() #f #f))))

    ;; ---- bindings and scopes ---------------------------------------

    (define-record-type binding
      (make-binding name kind node used assigned arity calls)
      binding?
      (name b-name)
      (kind b-kind) ; local param define loop macro record-type record
      (node b-node)
      (used b-used set-b-used!)
      (assigned b-assigned set-b-assigned!)
      (arity b-arity set-b-arity!) ; (min . max-or-#f) or #f
      (calls b-calls set-b-calls!))

    (define (new-binding name kind node)
      (make-binding name kind node #f #f #f '()))

    (define (make-frame) (make-hash-table eq?))

    ;; ---- the analysis ----------------------------------------------

    (define special-forms
      '(quote quasiquote lambda named-lambda case-lambda define define-values
        define-record-type define-syntax let-syntax letrec-syntax syntax-rules
        er-macro-transformer let let* letrec letrec* let-values let*-values
        receive do parameterize fluid-let guard cond case if when unless begin
        set! delay delay-force make-promise and or include include-ci
        cond-expand define-library import export))

    ;; Keywords that may appear in forms without being references.
    (define auxiliary-keywords '(else => ... _ unquote unquote-splicing))

    ;; Bound in every library and program without an import.
    (define core-forms
      '(quote quasiquote if set! begin lambda define define-syntax let let*
        letrec letrec* let-syntax letrec-syntax cond-expand import %primitive
        define-library))

    ;; Compiled inline when called (not when used as a value), so a call
    ;; works without an import.
    (define intrinsics
      '(car cdr cons null? pair? not + - * / = < > <= >= eq? eqv? vector-ref
        vector-set! list caar cadr cadar cdar cddr caaar caadr caddr cdaar
        cdadr cddar cdddr caaaar caaadr caadar caaddr cadaar cadadr caddar
        cadddr cdaaar cdaadr cdadar cdaddr cddaar cddadr cdddar cddddr))

    ;; Bound by the scm command for the script it runs.
    (define script-globals '(script-name script-arguments))

    (define (analyze cst file opts emit)
      (let* ((top-defs (make-frame))
             (imports '()) ; list of #(datum node bindings used-names-table)
             (import-table (make-frame)) ; name -> list of (import . binding)
             (complete? #t)
             (lib-name #f)
             (exports '()) ; list of (visible internal node)
             (library? #f)
             (reported (make-hash-table eq?))
             (cache (make-import-cache (append
                                        (opt opts 'library-path '())
                                        (if
                                         (file-exists? file)
                                         (list
                                          (directory-name
                                           (absolute-path file)))
                                         '())))))

        (define (report! rule node message)
          (emit rule
                (if node (cst-line node) 1)
                (if node (cst-col node) 0)
                message))

        ;; -- resolution --
        (define (lookup-local name env)
          (let loop ((fs env))
            (cond ((null? fs) #f)
                  ((hash-table-ref/default (car fs) name #f))
                  (else (loop (cdr fs))))))

        (define (resolve name env)
          ;; -> binding, (import-entries ...) list, or #f
          (or (lookup-local name env)
              (hash-table-ref/default top-defs name #f)
              (let ((imps (hash-table-ref/default import-table name #f)))
                (and imps (cons 'import imps)))))

        ;; A name several imports provide is credited to one of them:
        ;; (scheme ...) before (srfi ...) before (scm ...) before others,
        ;; then the earlier import, so redundant imports show as unused.
        (define (mark-import-used! entries name)
          (let loop ((es entries) (best #f))
            (cond ((null? es)
                   (when best
                     (hash-table-set! (vector-ref (car best) 3) name #t)
                     ;; the others could have provided it: remember who did
                     (for-each (lambda (e)
                                 (unless (eq? (car e) (car best))
                                   (hash-table-set! (vector-ref (car e) 5)
                                                    (vector-ref (car best) 0)
                                                    #t)))
                               entries)))
                  ((or (not best) (import-before? (caar es) (car best)))
                   (loop (cdr es) (car es)))
                  (else (loop (cdr es) best)))))

        (define (import-before? a b)
          (let ((ga (import-group (vector-ref a 0)))
                (gb (import-group (vector-ref b 0))))
            (or (< ga gb)
                (and (= ga gb) (< (vector-ref a 4) (vector-ref b 4))))))

        (define (ref! name node env . call?)
          (let ((r (resolve name env)))
            (cond ((binding? r) (set-b-used! r #t) r)
                  ((pair? r) (mark-import-used! (cdr r) name) r)
                  (else (when
                            (and complete?
                                 (not (memq name auxiliary-keywords))
                                 (not (memq name core-forms))
                                 (not (and (pair? call?)
                                           (car call?)
                                           (memq name intrinsics)))
                                 (not (and (not library?)
                                           (memq name script-globals))))
                          (report! 'unbound-identifier
                                   node
                                   (string-append (symbol->string name)
                                                  " is not bound")))
                        #f))))

        ;; marks every symbol under node as used, without reporting
        (define (opaque! node env)
          (case (cst-kind node)
            ((atom)
             (when (symbol-node? node)
               (let ((r (resolve (node-symbol node) env)))
                 (cond ((binding? r) (set-b-used! r #t))
                       ((pair? r)
                        (mark-import-used! (cdr r) (node-symbol node)))))))
            ((list vector prefix label)
             (for-each (lambda (k) (opaque! k env)) (cst-children node)))
            (else #t)))

        (define (import-kind entries)
          ;; syntax if the name is imported as a macro/core form
          (if (any? (lambda (e) (eq? (import-binding-kind (cdr e)) 'syntax))
                    entries)
              'syntax
              'value))

        ;; -- frames --
        (define (bind! frame name kind node)
          (let ((b (new-binding name kind node)))
            (hash-table-set! frame name b)
            (when
                (and (eq? kind 'local)
                     (hash-table-ref/default import-table name #f))
              (report! 'shadowed-import
                       node
                       (string-append (symbol->string name)
                                      " hides an imported binding")))
            b))

        (define (close-frame! frame)
          (hash-table-walk frame
                           (lambda (name b)
                             (check-calls! b)
                             (unless
                                 (or (b-used b)
                                     (let ((s (symbol->string name)))
                                       (and (> (string-length s) 0)
                                            (char=? (string-ref s 0) #\_))))
                               (case (b-kind b)
                                 ((local define loop macro)
                                  (report!
                                   'unused-local
                                   (b-node b)
                                   (string-append (symbol->string name)
                                                  " is never used")))
                                 ((param)
                                  (report!
                                   'unused-parameter
                                   (b-node b)
                                   (string-append "parameter "
                                                  (symbol->string name)
                                                  " is never used")))
                                 (else #t))))))

        (define (check-calls! b)
          (let ((ar (b-arity b)))
            (when (and ar (not (b-assigned b)))
              (for-each (lambda (c)
                          (let ((n (cdr c)))
                            (when
                                (or (< n (car ar))
                                    (and (cdr ar) (> n (cdr ar))))
                              (report! 'arity-mismatch
                                       (car c)
                                       (string-append
                                        (symbol->string (b-name b))
                                        " takes "
                                        (arity-text ar)
                                        ", called with "
                                        (number->string n))))))
                        (b-calls b)))))

        (define (arity-text ar)
          (cond ((not (cdr ar))
                 (string-append "at least "
                                (number->string (car ar))
                                " argument(s)"))
                ((= (car ar) (cdr ar))
                 (string-append (number->string (car ar)) " argument(s)"))
                (else (string-append (number->string (car ar))
                                     " to "
                                     (number->string (cdr ar))
                                     " arguments"))))

        (define (formals-arity formals-node)
          (let-values (((names rest ok?) (formals->names formals-node)))
            (and ok? (cons (length names) (if rest #f (length names))))))

        (define (lambda-arity node)
          ;; arity of a (lambda formals ...) node, else #f
          (and (eq? (head-symbol node) 'lambda)
               (not (lookup-shadowed? 'lambda))
               (let ((items (code-items node)))
                 (and (>= (length items) 2) (formals-arity (cadr items))))))

        (define (lookup-shadowed? name) #f)

        ;; -- definitions in a body --
        ;; Collects the names a body defines into frame; returns #t.
        (define (collect-definitions! forms frame top?)
          (for-each (lambda (f)
                      (let ((h (and (list-node? f) (head-symbol f))))
                        (case h
                          ((define define-values
                             define-record-type
                             define-syntax)
                           (for-each (lambda (nb)
                                       (let
                                           ((name (car nb))
                                            (node (cadr nb))
                                            (kind (caddr nb)))
                                         (when
                                             (hash-table-ref/default frame
                                                                     name #f)
                                           (report!
                                            'duplicate-definition
                                            node
                                            (string-append
                                             (symbol->string name)
                                             " is defined twice")))
                                         (let
                                             ((b
                                               (new-binding name kind node)))
                                           (when (cadddr nb)
                                             (set-b-arity! b (cadddr nb)))
                                           (hash-table-set! frame name b))))
                                     (definition-names f)))
                          ((begin)
                           (collect-definitions! (cdr (code-items f))
                                                 frame
                                                 top?))
                          (else #t))))
                    forms))

        ;; -> list of (name node kind arity)
        (define (definition-names f)
          (let* ((items (code-items f))
                 (h (head-symbol f)))
            (case h
              ((define)
               (if (< (length items) 2)
                   '()
                   (let loop ((target (cadr items))
                              (value (and (>= (length items) 3)
                                          (caddr items))))
                     (cond ((symbol-node? target)
                            (list (list
                                   (node-symbol target)
                                   target
                                   'define
                                   (and value
                                        (list-node? value)
                                        (lambda-arity value)))))
                           ((and (list-node? target)
                                 (pair? (code-items target)))
                            (let ((head (car (code-items target))))
                              (if (symbol-node? head)
                                  (list
                                   (list
                                    (node-symbol head)
                                    head
                                    'define
                                    (formals-arity (formals-tail target))))
                                  (loop head #f))))
                           (else '())))))
              ((define-values)
               (if (< (length items) 2)
                   '()
                   (let-values
                       (((names rest _ok?) (formals->names (cadr items))))
                     (map (lambda (n) (list (node-symbol n) n 'define #f))
                          (if rest (append names (list rest)) names)))))
              ((define-syntax)
               (if (and (>= (length items) 2) (symbol-node? (cadr items)))
                   (list (list (node-symbol (cadr items))
                               (cadr items)
                               'macro
                               #f))
                   '()))
              ((define-record-type)
               (if (< (length items) 4)
                   '()
                   (let* ((tname (cadr items))
                          (ctor (caddr items))
                          (pred (cadddr items))
                          (fields (cddddr items))
                          (nfields (length fields)))
                     (append (if (symbol-node? tname)
                                 (list (list (node-symbol tname)
                                             tname
                                             'record-type
                                             #f))
                                 '())
                             (cond ((symbol-node? ctor)
                                    (list
                                     (list (node-symbol ctor)
                                           ctor
                                           'record
                                           (cons nfields nfields))))
                                   ((and
                                     (list-node? ctor)
                                     (pair? (code-items ctor))
                                     (symbol-node? (car (code-items ctor))))
                                    (let
                                        ((n (- (length (code-items ctor)) 1)))
                                      (list
                                       (list
                                        (node-symbol (car (code-items ctor)))
                                        (car (code-items ctor))
                                        'record
                                        (cons n n)))))
                                   (else '()))
                             (if (symbol-node? pred)
                                 (list (list (node-symbol pred)
                                             pred
                                             'record
                                             (cons 1 1)))
                                 '())
                             (apply append
                                    (map
                                     (lambda (fl)
                                       (if
                                        (list-node? fl)
                                        (let ((fi (code-items fl)))
                                          (append
                                           (if
                                            (and (>= (length fi) 2)
                                                 (symbol-node? (cadr fi)))
                                            (list
                                             (list (node-symbol (cadr fi))
                                                   (cadr fi)
                                                   'record
                                                   (cons 1 1)))
                                            '())
                                           (if
                                            (and (>= (length fi) 3)
                                                 (symbol-node? (caddr fi)))
                                            (list
                                             (list (node-symbol (caddr fi))
                                                   (caddr fi)
                                                   'record
                                                   (cons 2 2)))
                                            '())))
                                        '()))
                                     fields))))))
              (else '()))))

        ;; the formals part of a (name . formals) header, as a node
        (define (formals-tail target)
          (let* ((kids (cst-children target))
                 (rest (let loop ((ks kids) (seen-head #f))
                         (cond ((null? ks) '())
                               ((memq (cst-kind (car ks))
                                      '(comment block-comment datum-comment
                                        directive))
                                (loop (cdr ks) seen-head))
                               ((not seen-head) (loop (cdr ks) #t))
                               (else ks)))))
            (if (and (pair? rest) (eq? (cst-kind (car rest)) 'dot))
                (if (pair? (cdr rest)) (cadr rest) target)
                (make-cst-node 'list
                               "("
                               (cst-line target)
                               (cst-col target)
                               ""
                               rest
                               (cst-close target)))))

        ;; -- walking --
        (define (walk-body forms env owner)
          ;; forms: list of nodes (code only); owner: node for messages
          (when (null? forms) (report! 'malformed-form owner "empty body"))
          (let ((frame (make-frame)))
            (collect-definitions! forms frame #f)
            (let ((env (cons frame env)))
              (walk-body-forms forms env)
              (close-frame! frame))))

        (define (walk-body-forms forms env)
          (for-each (lambda (f) (walk-form f env #t)) forms))

        ;; body? = definitions allowed here
        (define (walk-form node env body?)
          (let ((h (and (list-node? node) (head-symbol node))))
            (cond ((and h
                        (memq h
                              '(define define-values define-record-type
                                define-syntax))
                        (not (resolve-local-or-def h env)))
                   (unless body?
                     (report! 'definition-context
                              node
                              (string-append (symbol->string h)
                                             " in an expression context")))
                   (walk-definition node env))
                  ((and body? h
                        (eq? h 'begin)
                        (not (resolve-local-or-def h env)))
                   ;; a splicing begin in a body
                   (for-each (lambda (f) (walk-form f env #t))
                             (cdr (code-items node))))
                  (else (walk-expr node env)))))

        (define (resolve-local-or-def name env)
          (or (lookup-local name env)
              (hash-table-ref/default top-defs name #f)))

        (define (walk-definition node env)
          (let* ((items (code-items node))
                 (h (head-symbol node)))
            (case h
              ((define)
               (cond ((< (length items) 2)
                      (report! 'malformed-form node "define without a name"))
                     ((list-node? (cadr items))
                      (walk-curried (cadr items) (cddr items) env node))
                     (else (when (> (length items) 3)
                             (report! 'malformed-form
                                      node
                                      "define with more than one value"))
                           (when (= (length items) 3)
                             (check-define-lambda node (caddr items))
                             (walk-expr (caddr items) env)))))
              ((define-values)
               (when (>= (length items) 3) (walk-expr (caddr items) env)))
              ((define-syntax)
               (for-each (lambda (k) (opaque! k env)) (cddr items)))
              ((define-record-type)
               ;; nothing to evaluate
               #t))))

        (define (check-define-lambda node value)
          (when
              (and (eq? (head-symbol value) 'lambda)
                   (not (resolve-local-or-def 'lambda '())))
            (report! 'define-lambda
                     node
                     "(define f (lambda ...)) can be written (define (f ...) ...)")))

        ;; (define (name . formals) body...) or curried ((name a) b)
        (define (walk-curried target body env node)
          (let ((head (car (code-items target))))
            (if (list-node? head)
                (walk-curried head
                              (list (make-cst-node
                                     'list
                                     "("
                                     (cst-line node)
                                     (cst-col node)
                                     ""
                                     (cons
                                      (make-cst-node 'atom
                                                     "lambda"
                                                     (cst-line node)
                                                     (cst-col node)
                                                     ""
                                                     '()
                                                     #f)
                                      (cons (formals-tail target) body))
                                     (cons "" ")")))
                              env
                              node)
                (begin
                  (check-docstring-in-body node body)
                  (walk-lambda (formals-tail target) body env node)))))

        (define (check-docstring-in-body node body) #t)

        (define (walk-lambda formals body env node)
          (let ((frame (make-frame)))
            (let-values (((names rest ok?) (formals->names formals)))
              (unless ok?
                (report! 'malformed-form
                         formals
                         "bad formals: parameters must be identifiers"))
              (for-each (lambda (n)
                          (when
                              (hash-table-ref/default frame
                                                      (node-symbol n)
                                                      #f)
                            (report! 'malformed-form
                                     n
                                     (string-append
                                      "parameter "
                                      (symbol->string (node-symbol n))
                                      " appears twice")))
                          (bind! frame (node-symbol n) 'param n))
                        (if rest (append names (list rest)) names)))
            (walk-body body (cons frame env) node)
            (close-frame! frame)))

        (define (walk-exprs nodes env)
          (for-each (lambda (n) (walk-expr n env)) nodes))

        (define (definition? f)
          (and (list-node? f)
               (memq (head-symbol f)
                     '(define define-values define-record-type
                       define-syntax))))

        ;; A sequence in expression position (cond/case clause, when,
        ;; unless, begin). Definitions there are reported and bound, so
        ;; their uses are not reported as unbound too.
        (define (walk-seq forms env)
          (if (any? definition? forms)
              (let ((frame (make-frame)))
                (for-each (lambda (f)
                            (when (definition? f)
                              (report! 'definition-context
                                       f
                                       (string-append
                                        (symbol->string (head-symbol f))
                                        " in an expression context"))))
                          forms)
                (collect-definitions! forms frame #f)
                (let ((env (cons frame env)))
                  (for-each (lambda (f)
                              (if (definition? f)
                                  (walk-definition f env)
                                  (walk-form f env #f)))
                            forms))
                (close-frame! frame))
              (for-each (lambda (f) (walk-form f env #f)) forms)))

        (define (walk-expr node env)
          (case (cst-kind node)
            ((atom)
             (when (symbol-node? node) (ref! (node-symbol node) node env)))
            ((prefix)
             (let ((t (cst-text node))
                   (kids (code-items node)))
               (cond ((member t '("'" "#'")) #t)
                     ((member t '("`" "#`"))
                      (for-each (lambda (k) (walk-qq k env 1)) kids))
                     (else (walk-exprs kids env)))))
            ((label) (walk-exprs (code-items node) env))
            ((list) (walk-list node env))
            (else #t)))

        (define (walk-qq node env depth)
          (case (cst-kind node)
            ((prefix)
             (let ((t (cst-text node))
                   (kids (code-items node)))
               (cond ((member t '("," ",@"))
                      (if (= depth 1)
                          (walk-exprs kids env)
                          (for-each (lambda (k) (walk-qq k env (- depth 1)))
                                    kids)))
                     ((string=? t "`")
                      (for-each (lambda (k) (walk-qq k env (+ depth 1)))
                                kids))
                     (else (for-each (lambda (k) (walk-qq k env depth))
                                     kids)))))
            ((list vector label)
             (let ((h (head-symbol node)))
               (cond ((and (memq h '(unquote unquote-splicing)) (= depth 1))
                      (walk-exprs (cdr (code-items node)) env))
                     (else (for-each (lambda (k) (walk-qq k env depth))
                                     (code-items node))))))
            (else #t)))

        (define (walk-list node env)
          (let ((items (code-items node)))
            (cond ((null? items) #t)
                  ((symbol-node? (car items))
                   (let* ((name (node-symbol (car items)))
                          (local (resolve-local-or-def name env)))
                     (cond ((and local (eq? (b-kind local) 'macro))
                            (set-b-used! local #t)
                            (for-each (lambda (k) (opaque! k env))
                                      (cdr items)))
                           (local (walk-call node items env))
                           ((memq name special-forms)
                            (let
                                ((imps (hash-table-ref/default import-table
                                                               name #f)))
                              (cond (imps (mark-import-used! imps name))
                                    ((and
                                      complete?
                                      (not (memq name core-forms))
                                      (not
                                       (memq
                                        name
                                        '(define-values define-record-type
                                          include include-ci export
                                          named-lambda
                                          er-macro-transformer))))
                                     (report!
                                      'unbound-identifier
                                      (car items)
                                      (string-append (symbol->string name)
                                                     " is not bound")))))
                            (walk-special name node items env))
                           (else (let
                                     ((imps
                                       (hash-table-ref/default import-table
                                                               name #f)))
                                   (if (and imps
                                            (eq? (import-kind imps) 'syntax))
                                       (begin
                                         (mark-import-used! imps name)
                                         (for-each
                                          (lambda (k) (opaque! k env))
                                          (cdr items)))
                                       (walk-call node items env)))))))
                  (else (walk-exprs items env)))))

        (define (walk-call node items env)
          (let* ((head (car items))
                 (r (ref! (node-symbol head) head env #t))
                 (args (cdr items)))
            (when (binding? r)
              (set-b-calls! r (cons (cons node (length args)) (b-calls r))))
            (unless (binding? r)
              (check-call-idioms node (node-symbol head) args env))
            (walk-exprs args env)))

        ;; -- special forms --
        (define (walk-special name node items env)
          (let ((args (cdr items)))
            (case name
              ((quote) #t)
              ((quasiquote) (for-each (lambda (k) (walk-qq k env 1)) args))
              ((lambda)
               (if (null? args)
                   (report! 'malformed-form node "lambda without formals")
                   (begin
                     (check-eta node args env)
                     (walk-lambda (car args) (cdr args) env node))))
              ((named-lambda)
               (when (pair? args)
                 (walk-lambda (formals-tail (car args)) (cdr args) env node)))
              ((case-lambda)
               (for-each (lambda (cl)
                           (if (list-node? cl)
                               (let ((ci (code-items cl)))
                                 (if (null? ci)
                                     (report! 'malformed-form
                                              cl
                                              "empty case-lambda clause")
                                     (walk-lambda (car ci) (cdr ci) env cl)))
                               (report! 'malformed-form
                                        cl
                                        "case-lambda clause is not a list")))
                         args))
              ((define define-values
                 define-record-type
                 define-syntax)
               (walk-form node env #f))
              ((let-syntax letrec-syntax)
               (if (null? args)
                   (report! 'malformed-form node "missing bindings")
                   (let ((frame (make-frame)))
                     (for-each (lambda (b)
                                 (let
                                     ((bi
                                       (if (list-node? b)
                                           (code-items b)
                                           '())))
                                   (when
                                       (and (pair? bi)
                                            (symbol-node? (car bi)))
                                     (bind! frame
                                            (node-symbol (car bi))
                                            'macro
                                            (car bi)))
                                   (for-each (lambda (k) (opaque! k env))
                                             (if (pair? bi) (cdr bi) '()))))
                               (if (list-node? (car args))
                                   (code-items (car args))
                                   '()))
                     (walk-body (cdr args) (cons frame env) node)
                     (close-frame! frame))))
              ((syntax-rules er-macro-transformer)
               (for-each (lambda (k) (opaque! k env)) args))
              ((let) (walk-let node args env))
              ((let*) (walk-let* node args env))
              ((letrec letrec*) (walk-letrec node args env))
              ((let-values let*-values) (walk-let-values node name args env))
              ((receive)
               (if (< (length args) 2)
                   (report! 'malformed-form
                            node
                            "receive needs formals and an expression")
                   (begin
                     (walk-expr (cadr args) env)
                     (let ((frame (make-frame)))
                       (bind-formals! frame (car args) 'local)
                       (walk-body (cddr args) (cons frame env) node)
                       (close-frame! frame)))))
              ((do) (walk-do node args env))
              ((parameterize fluid-let)
               (if (null? args)
                   (report! 'malformed-form node "missing bindings")
                   (begin
                     (for-each (lambda (b)
                                 (if (list-node? b)
                                     (walk-exprs (code-items b) env)
                                     (report! 'malformed-form
                                              b
                                              "bad binding")))
                               (if (list-node? (car args))
                                   (code-items (car args))
                                   '()))
                     (walk-body (cdr args) env node))))
              ((guard) (walk-guard node args env))
              ((cond) (walk-cond node args env))
              ((case) (walk-case node args env))
              ((if)
               (if (or (< (length args) 2) (> (length args) 3))
                   (report! 'malformed-form
                            node
                            (string-append "if takes 2 or 3 arguments, given "
                                           (number->string (length args))))
                   (check-if-idioms node args))
               (walk-exprs args env))
              ((when unless)
               (if (null? args)
                   (report! 'malformed-form
                            node
                            (string-append (symbol->string name)
                                           " without a test"))
                   (begin
                     (walk-expr (car args) env)
                     (walk-seq (cdr args) env))))
              ((begin)
               (when (= (length args) 1)
                 (report! 'begin-single
                          node
                          "(begin e) with a single expression is e"))
               (walk-seq args env))
              ((set!)
               (if (not (and (= (length args) 2) (symbol-node? (car args))))
                   (report! 'malformed-form
                            node
                            "set! takes an identifier and an expression")
                   (let* ((target (car args))
                          (r (resolve (node-symbol target) env)))
                     (cond ((binding? r) (set-b-assigned! r #t))
                           ((pair? r)
                            (mark-import-used! (cdr r) (node-symbol target))
                            (report! 'set-imported
                                     target
                                     (string-append
                                      "set! of the imported binding "
                                      (symbol->string (node-symbol target)))))
                           (else (ref! (node-symbol target) target env)))
                     (walk-expr (cadr args) env))))
              ((delay
                 delay-force
                 make-promise
                 and
                 or)
               (walk-exprs args env))
              ((include include-ci) (set! complete? #f))
              ((cond-expand) (for-each (lambda (k) (opaque! k env)) args))
              ((define-library import export) #t)
              (else (walk-exprs args env)))))

        (define (bind-formals! frame formals kind)
          (let-values (((names rest ok?) (formals->names formals)))
            (unless ok? (report! 'malformed-form formals "bad formals"))
            (for-each (lambda (n) (bind! frame (node-symbol n) kind n))
                      (if rest (append names (list rest)) names))))

        ;; bindings list -> list of (name-node init-node-or-#f), reporting bad ones
        (define (binding-pairs node blist)
          (cond ((not (list-node? blist))
                 (report! 'malformed-form blist "bindings must be a list")
                 '())
                (else (let loop ((bs (code-items blist))
                                 (acc '()))
                        (if (null? bs)
                            (reverse acc)
                            (let ((b (car bs)))
                              (cond ((and
                                      (list-node? b)
                                      (let ((bi (code-items b)))
                                        (and (= (length bi) 2)
                                             (symbol-node? (car bi)))))
                                     (let ((bi (code-items b)))
                                       (loop
                                        (cdr bs)
                                        (cons
                                         (list
                                          (car bi)
                                          (and (pair? (cdr bi)) (cadr bi)))
                                         acc))))
                                    (else
                                     (report!
                                      'malformed-form
                                      b
                                      "a binding must be (variable expression)")
                                     (loop (cdr bs) acc)))))))))

        (define (check-duplicate-vars pairs)
          (let ((seen (make-frame)))
            (for-each (lambda (p)
                        (let ((s (node-symbol (car p))))
                          (if (hash-table-ref/default seen s #f)
                              (report! 'malformed-form
                                       (car p)
                                       (string-append (symbol->string s)
                                                      " is bound twice"))
                              (hash-table-set! seen s #t))))
                      pairs)))

        (define (walk-let node args env)
          (cond ((null? args)
                 (report! 'malformed-form node "let without bindings"))
                ((symbol-node? (car args))
                 ;; named let
                 (if (null? (cdr args))
                     (report! 'malformed-form
                              node
                              "named let without bindings")
                     (let ((pairs (binding-pairs node (cadr args))))
                       (check-duplicate-vars pairs)
                       (for-each (lambda (p)
                                   (when (cadr p) (walk-expr (cadr p) env)))
                                 pairs)
                       (let ((lframe (make-frame))
                             (vframe (make-frame)))
                         (let
                             ((lb (bind! lframe
                                         (node-symbol (car args))
                                         'loop
                                         (car args))))
                           (set-b-arity!
                            lb
                            (cons (length pairs) (length pairs))))
                         (for-each (lambda (p)
                                     (bind! vframe
                                            (node-symbol (car p))
                                            'local
                                            (car p)))
                                   pairs)
                         (walk-body (cddr args)
                                    (cons vframe (cons lframe env))
                                    node)
                         (close-frame! vframe)
                         (close-frame! lframe)))))
                (else (let ((pairs (binding-pairs node (car args))))
                        (check-duplicate-vars pairs)
                        (when
                            (and (null? pairs)
                                 (list-node? (car args))
                                 (not (any?
                                       (lambda (f)
                                         (memq
                                          (head-symbol f)
                                          '(define define-values
                                            define-record-type
                                            define-syntax)))
                                       (cdr args)))
                                 (= (length (cdr args)) 1))
                          (report! 'empty-let
                                   node
                                   "(let () e) without definitions is e"))
                        (for-each (lambda (p)
                                    (when (cadr p) (walk-expr (cadr p) env)))
                                  pairs)
                        (let ((frame (make-frame)))
                          (for-each (lambda (p)
                                      (let
                                          ((b
                                            (bind! frame
                                                   (node-symbol (car p))
                                                   'local
                                                   (car p))))
                                        (when
                                            (and (cadr p)
                                                 (list-node? (cadr p)))
                                          (set-b-arity!
                                           b
                                           (lambda-arity (cadr p))))))
                                    pairs)
                          (walk-body (cdr args) (cons frame env) node)
                          (close-frame! frame))))))

        (define (walk-let* node args env)
          (if (null? args)
              (report! 'malformed-form node "let* without bindings")
              (let ((pairs (binding-pairs node (car args))))
                (let loop ((ps pairs) (env env) (frames '()))
                  (if (null? ps)
                      (begin
                        (walk-body (cdr args) env node)
                        (for-each close-frame! frames))
                      (let ((p (car ps))
                            (frame (make-frame)))
                        (when (cadr p) (walk-expr (cadr p) env))
                        (let
                            ((b (bind! frame
                                       (node-symbol (car p))
                                       'local
                                       (car p))))
                          (when (and (cadr p) (list-node? (cadr p)))
                            (set-b-arity! b (lambda-arity (cadr p)))))
                        (loop (cdr ps)
                              (cons frame env)
                              (cons frame frames))))))))

        (define (walk-letrec node args env)
          (if (null? args)
              (report! 'malformed-form node "letrec without bindings")
              (let ((pairs (binding-pairs node (car args)))
                    (frame (make-frame)))
                (check-duplicate-vars pairs)
                (for-each (lambda (p)
                            (let
                                ((b (bind! frame
                                           (node-symbol (car p))
                                           'local
                                           (car p))))
                              (when (and (cadr p) (list-node? (cadr p)))
                                (set-b-arity! b (lambda-arity (cadr p))))))
                          pairs)
                (let ((env (cons frame env)))
                  (for-each (lambda (p)
                              (when (cadr p) (walk-expr (cadr p) env)))
                            pairs)
                  (walk-body (cdr args) env node))
                (close-frame! frame))))

        (define (walk-let-values node name args env)
          (if (or (null? args) (not (list-node? (car args))))
              (report! 'malformed-form node "missing bindings")
              (let ((frame (make-frame)))
                (for-each (lambda (b)
                            (let ((bi (if (list-node? b) (code-items b) '())))
                              (if (= (length bi) 2)
                                  (begin
                                    (walk-expr
                                     (cadr bi)
                                     (if (eq? name 'let*-values)
                                         (cons frame env)
                                         env))
                                    (bind-formals! frame (car bi) 'local))
                                  (report!
                                   'malformed-form
                                   b
                                   "a binding must be (formals expression)"))))
                          (code-items (car args)))
                (walk-body (cdr args) (cons frame env) node)
                (close-frame! frame))))

        (define (walk-do node args env)
          (if (< (length args) 2)
              (report! 'malformed-form
                       node
                       "do needs bindings and a test clause")
              (let ((frame (make-frame))
                    (specs (if (list-node? (car args))
                               (code-items (car args))
                               '())))
                (for-each (lambda (s)
                            (let ((si (if (list-node? s) (code-items s) '())))
                              (if (and (<= 2 (length si) 3)
                                       (symbol-node? (car si)))
                                  (walk-expr (cadr si) env)
                                  (report!
                                   'malformed-form
                                   s
                                   "a do binding must be (var init [step])"))))
                          specs)
                (for-each (lambda (s)
                            (let ((si (if (list-node? s) (code-items s) '())))
                              (when (and (pair? si) (symbol-node? (car si)))
                                (bind! frame
                                       (node-symbol (car si))
                                       'local
                                       (car si)))))
                          specs)
                (let ((env (cons frame env)))
                  (for-each (lambda (s)
                              (let
                                  ((si (if (list-node? s)
                                           (code-items s)
                                           '())))
                                (when (= (length si) 3)
                                  (walk-expr (caddr si) env))))
                            specs)
                  (if (list-node? (cadr args))
                      (walk-exprs (code-items (cadr args)) env)
                      (report! 'malformed-form
                               (cadr args)
                               "the do test must be a list"))
                  (walk-exprs (cddr args) env))
                (close-frame! frame))))

        (define (walk-guard node args env)
          (if (or (null? args)
                  (not (list-node? (car args)))
                  (null? (code-items (car args)))
                  (not (symbol-node? (car (code-items (car args))))))
              (report! 'malformed-form
                       node
                       "guard needs (variable clause ...)")
              (let* ((spec (code-items (car args)))
                     (frame (make-frame)))
                (bind! frame (node-symbol (car spec)) 'param (car spec))
                (walk-cond-clauses node (cdr spec) (cons frame env))
                (walk-body (cdr args) env node)
                (close-frame! frame))))

        (define (walk-cond node args env) (walk-cond-clauses node args env))

        (define (walk-cond-clauses node clauses env)
          (let loop ((cs clauses) (after-else #f) (after-true #f))
            (unless (null? cs)
              (let ((c (car cs)))
                (cond ((not (list-node? c))
                       (report! 'malformed-form
                                c
                                "a cond clause must be a list")
                       (loop (cdr cs) after-else after-true))
                      ((null? (code-items c))
                       (report! 'malformed-form c "empty cond clause")
                       (loop (cdr cs) after-else after-true))
                      (else (when after-else
                              (report! 'malformed-form c "clause after else"))
                            (when (and after-true (not after-else))
                              (report! 'unreachable-clause
                                       c
                                       "clause after one whose test is always true"))
                            (let* ((ci (code-items c))
                                   (test (car ci))
                                   (else?
                                    (and
                                     (symbol-node? test)
                                     (eq? (node-symbol test) 'else)
                                     (not (resolve-local-or-def 'else env)))))
                              (unless else? (walk-expr test env))
                              (let ((rest (cdr ci)))
                                (if (and (pair? rest)
                                         (symbol-node? (car rest))
                                         (eq? (node-symbol (car rest)) '=>))
                                    (walk-exprs (cdr rest) env)
                                    (walk-seq rest env)))
                              (loop (cdr cs)
                                    (or after-else else?)
                                    (or after-true
                                        (true-literal? test))))))))))

        (define (walk-case node args env)
          (if (null? args)
              (report! 'malformed-form node "case without a key")
              (let ((seen (make-hash-table equal?)))
                (walk-expr (car args) env)
                (let loop ((cs (cdr args))
                           (after-else #f))
                  (unless (null? cs)
                    (let ((c (car cs)))
                      (if (or (not (list-node? c)) (null? (code-items c)))
                          (begin
                            (report! 'malformed-form c "bad case clause")
                            (loop (cdr cs) after-else))
                          (let* ((ci (code-items c))
                                 (data (car ci))
                                 (else?
                                  (and (symbol-node? data)
                                       (eq? (node-symbol data) 'else))))
                            (when after-else
                              (report! 'malformed-form c "clause after else"))
                            (cond (else? #t)
                                  ((list-node? data)
                                   (for-each
                                    (lambda (d)
                                      (let ((v (cst->datum d)))
                                        (if
                                         (hash-table-ref/default seen v #f)
                                         (report!
                                          'duplicate-case-datum
                                          d
                                          (string-append
                                           (datum->string v)
                                           " already appears in an earlier clause"))
                                         (hash-table-set! seen v #t))))
                                    (code-items data)))
                                  (else
                                   (report!
                                    'malformed-form
                                    data
                                    "case clause data must be a list")))
                            (let ((rest (cdr ci)))
                              (if (and (pair? rest)
                                       (symbol-node? (car rest))
                                       (eq? (node-symbol (car rest)) '=>))
                                  (walk-exprs (cdr rest) env)
                                  (walk-seq rest env)))
                            (loop (cdr cs) (or after-else else?))))))))))

        ;; -- idioms --
        (define (visible? name)
          ;; whether a standard procedure name is available unshadowed
          (and (hash-table-ref/default import-table name #f)
               (not (hash-table-ref/default top-defs name #f))))

        (define (check-if-idioms node args)
          (let ((c (car args)))
            (cond ((= (length args) 2)
                   (report! 'if-without-else
                            node
                            (if (eq? (head-symbol c) 'not)
                                "one-armed if: use unless"
                                "one-armed if: use when")))
                  ((and (true-literal? (cadr args))
                        (false-literal? (caddr args)))
                   (report! 'if-boolean
                            node
                            "(if c #t #f) is c (when c is a boolean)"))
                  ((and (false-literal? (cadr args))
                        (true-literal? (caddr args)))
                   (report! 'if-boolean node "(if c #f #t) is (not c)"))
                  (else (let loop ((e (caddr args))
                                   (depth 1))
                          (if (and (eq? (head-symbol e) 'if)
                                   (= (length (code-items e)) 4))
                              (if (>= (+ depth 1) 3)
                                  (unless
                                      (hash-table-ref/default reported node
                                                              #f)
                                    (hash-table-set! reported e #t)
                                    (report!
                                     'nested-if
                                     node
                                     "if nested in else branches: use cond"))
                                  (loop (cadddr (code-items e)) (+ depth 1)))
                              #t))))))

        (define (cxr-chain node)
          ;; -> (letters . innermost-arg) for nested car/cdr calls
          (let loop ((n node) (letters '()))
            (let ((h (head-symbol n)))
              (if (and (memq h '(car cdr)) (= (length (code-items n)) 2))
                  (loop (cadr (code-items n))
                        (cons (if (eq? h 'car) #\a #\d) letters))
                  (cons (reverse letters) n)))))

        (define (check-call-idioms node name args env)
          (let ((n (length args)))
            (case name
              ((car cdr)
               (unless (hash-table-ref/default reported node #f)
                 (let* ((chain (cxr-chain node))
                        (letters (car chain))
                        (len (min 4 (length letters))))
                   (when (>= len 2)
                     (let
                         ((sugg (string->symbol
                                 (string-append
                                  "c"
                                  (list->string (list-head* letters len))
                                  "r"))))
                       (when (visible? sugg)
                         ;; mark the inner calls so they are not reported again
                         (let mark ((m node) (k 0))
                           (when (< k len)
                             (hash-table-set! reported m #t)
                             (mark (cadr (code-items m)) (+ k 1))))
                         (report! 'cxr
                                  node
                                  (string-append "use "
                                                 (symbol->string sugg)))))))))
              ((eq? eqv? equal?)
               (when (= n 2)
                 (cond ((or (empty-list-literal? (car args))
                            (empty-list-literal? (cadr args)))
                        (report! 'null-compare
                                 node
                                 "comparison with '(): use null?"))
                       ((and (eq? name 'eq?)
                             (or (literal-kind (car args))
                                 (literal-kind (cadr args))))
                        =>
                        (lambda (k)
                          (report! 'eq-literal
                                   node
                                   (if (eq? k 'string)
                                       "eq? on a string literal: use string=? or equal?"
                                       "eq? on a number or character: use eqv?")))))))
              ((memq assq)
               (when (= n 2)
                 (let
                     ((k (or (literal-kind (car args))
                             (quoted-literal-elements-kind (cadr args)))))
                   (when k
                     (report! 'eq-literal
                              node
                              (string-append
                               (symbol->string name)
                               " with "
                               (if (eq? k 'string)
                                   "strings"
                                   "numbers or characters")
                               ": use "
                               (if (eq? name 'memq)
                                   (if (eq? k 'string) "member" "memv")
                                   (if (eq? k 'string) "assoc" "assv"))))))))
              ((= > positive? zero?)
               (let ((len-arg? (lambda (a) (eq? (head-symbol a) 'length)))
                     (zero-lit? (lambda (a)
                                  (and (eq? (cst-kind a) 'atom)
                                       (string=? (cst-text a) "0")))))
                 (when
                     (or (and (memq name '(zero? positive?))
                              (= n 1)
                              (len-arg? (car args)))
                         (and (memq name '(= >))
                              (= n 2)
                              (or (and (len-arg? (car args))
                                       (zero-lit? (cadr args)))
                                  (and (eq? name '=)
                                       (zero-lit? (car args))
                                       (len-arg? (cadr args))))))
                   (report! 'length-zero
                            node
                            (if (memq name '(zero? =))
                                "length compared with 0: use null?"
                                "length compared with 0: use pair?")))))
              ((append)
               (cond ((= n 1)
                      (report! 'redundant-call
                               node
                               "append with one argument is that argument"))
                     ((and (= n 2)
                           (eq? (head-symbol (car args)) 'list)
                           (= (length (code-items (car args))) 2))
                      (report! 'append-list
                               node
                               "(append (list x) y) is (cons x y)"))))
              ((string-append)
               (when (= n 1)
                 (report! 'redundant-call
                          node
                          "string-append with one argument: the argument itself (or string-copy)")))
              (else #t))))

        (define (quoted-literal-elements-kind node)
          (and (eq? (cst-kind node) 'prefix)
               (string=? (cst-text node) "'")
               (let ((kids (code-items node)))
                 (and (= (length kids) 1)
                      (list-node? (car kids))
                      (let ((ks (map literal-kind (code-items (car kids)))))
                        (cond ((memq 'string ks) 'string)
                              ((or (memq 'number ks) (memq 'char ks)) 'number)
                              (else #f)))))))

        (define (check-eta node args env)
          ;; (lambda (x ...) (f x ...))
          (when (= (length args) 2)
            (let ((formals (car args))
                  (body (cadr args)))
              (when (and (list-node? formals) (list-node? body))
                (let-values (((names rest ok?) (formals->names formals)))
                  (let ((bi (code-items body)))
                    (when
                        (and ok?
                             (not rest)
                             (pair? bi)
                             (symbol-node? (car bi))
                             (= (length (cdr bi)) (length names))
                             (every? symbol-node? (cdr bi))
                             (equal? (map node-symbol (cdr bi))
                                     (map node-symbol names))
                             (not (memq (node-symbol (car bi))
                                        (map node-symbol names))))
                      (let* ((f (node-symbol (car bi)))
                             (r (resolve f env)))
                        (when
                            (or (and (binding? r)
                                     (memq (b-kind r) '(define record))
                                     (b-arity r))
                                (and (pair? r)
                                     (not (binding? r))
                                     (every?
                                      (lambda (e)
                                        (eq? (import-binding-kind (cdr e))
                                             'procedure))
                                      (cdr r))))
                          (report! 'eta-lambda
                                   node
                                   (string-append
                                    "(lambda ... ("
                                    (symbol->string f)
                                    " ...)) is just "
                                    (symbol->string f))))))))))))

        ;; -- top level --
        (define (add-import! set-node)
          (let* ((d (cst->datum set-node))
                 (bs (import-set-bindings d cache))
                 (imp (vector d set-node bs
                              (make-hash-table eq?)
                              (length imports)
                              (make-hash-table equal?))))
            (when (any? (lambda (i) (equal? (vector-ref i 0) d)) imports)
              (report! 'duplicate-import
                       set-node
                       (string-append (datum->string d)
                                      " is imported twice")))
            (set! imports (append imports (list imp)))
            (if (not bs)
                (set! complete? #f)
                (for-each (lambda (b)
                            (let ((name (import-binding-name b)))
                              (hash-table-set!
                               import-table
                               name
                               (append (hash-table-ref/default import-table
                                                               name
                                                               '())
                                       (list (cons imp b))))))
                          bs))))

        (define (check-import-conflicts!)
          (let ((pairs-reported (make-hash-table equal?)))
            (hash-table-walk import-table
                             (lambda (name entries)
                               (when (> (length entries) 1)
                                 (let loop ((es entries))
                                   (when (pair? (cdr es))
                                     (let ((a (car es)))
                                       (for-each
                                        (lambda (b)
                                          (unless
                                              (or
                                               (same-import-binding? (cdr a)
                                                                     (cdr b))
                                               (eq?
                                                (import-binding-kind (cdr a))
                                                'unknown)
                                               (eq?
                                                (import-binding-kind (cdr b))
                                                'unknown))
                                            (let
                                                ((key
                                                  (list
                                                   (vector-ref (car a) 0)
                                                   (vector-ref (car b) 0))))
                                              (let
                                                  ((prev
                                                    (hash-table-ref/default
                                                     pairs-reported key #f)))
                                                (hash-table-set!
                                                 pairs-reported
                                                 key
                                                 (cons name
                                                       (or prev '())))))))
                                        (cdr es)))
                                     (loop (cdr es)))))))
            (hash-table-walk pairs-reported
                             (lambda (key names)
                               (let* ((sorted (sort-symbols names))
                                      (shown
                                       (list-head* sorted
                                                   (min 5 (length sorted))))
                                      (b-imp
                                       (let find ((is imports))
                                         (cond
                                          ((null? is) #f)
                                          ((equal? (vector-ref (car is) 0)
                                                   (cadr key))
                                           (car is))
                                          (else (find (cdr is)))))))
                                 (report!
                                  'import-conflict
                                  (and b-imp (vector-ref b-imp 1))
                                  (string-append
                                   (datum->string (car key))
                                   " and "
                                   (datum->string (cadr key))
                                   " both bind "
                                   (join-symbols shown)
                                   (if (> (length sorted) 5) ", ..." "")
                                   " differently; the later import wins")))))))

        (define (check-unused-imports!)
          (for-each (lambda (imp)
                      (let ((bs (vector-ref imp 2))
                            (used (vector-ref imp 3))
                            (d (vector-ref imp 0)))
                        (when bs
                          (when (and (pair? bs) (= (hash-table-size used) 0))
                            (let
                                ((others
                                  (hash-table-keys (vector-ref imp 5))))
                              (report! 'unused-import
                                       (vector-ref imp 1)
                                       (if
                                        (null? others)
                                        (string-append
                                         (datum->string d)
                                         " is imported but not used")
                                        (string-append
                                         (datum->string d)
                                         " is redundant: the names used from it also come from "
                                         (join-strings
                                          (map datum->string others)
                                          ", "))))))
                          (when
                              (and (pair? d)
                                   (eq? (car d) 'only)
                                   (> (hash-table-size used) 0))
                            (for-each (lambda (n)
                                        (when
                                            (and
                                             (symbol? n)
                                             (not
                                              (hash-table-ref/default used n
                                                                      #f)))
                                          (report!
                                           'unused-only-name
                                           (vector-ref imp 1)
                                           (string-append
                                            (symbol->string n)
                                            " is imported but not used"))))
                                      (cddr d))))))
                    imports))

        (define (library-body-forms decls)
          ;; collects the begin bodies; handles includes and cond-expand
          (let loop ((ds decls) (acc '()))
            (if (null? ds)
                acc
                (let* ((d (car ds))
                       (h (head-symbol d)))
                  (case h
                    ((begin)
                     (loop (cdr ds) (append acc (cdr (code-items d)))))
                    ((include include-ci include-library-declarations)
                     (set! complete? #f)
                     (loop (cdr ds) acc))
                    ((cond-expand) (set! complete? #f) (loop (cdr ds) acc))
                    (else (loop (cdr ds) acc)))))))

        (define (check-library-file-name! node)
          (when (and lib-name (string-suffix? ".sld" file))
            (let ((expected (library-file-name lib-name)))
              (unless (string=? expected (base-name file))
                (report! 'library-file-name
                         node
                         (string-append "library "
                                        (datum->string lib-name)
                                        " is expected in a file named "
                                        expected))))))

        (define (analyze-library! lib)
          (let* ((items (code-items lib))
                 (decls (if (>= (length items) 2) (cddr items) '())))
            (set! library? #t)
            (set! lib-name
                  (and (>= (length items) 2) (cst->datum (cadr items))))
            (check-library-file-name! (if (>= (length items) 2)
                                          (cadr items)
                                          lib))
            ;; imports first, wherever they appear
            (for-each (lambda (d)
                        (when (eq? (head-symbol d) 'import)
                          (for-each add-import! (cdr (code-items d)))))
                      decls)
            ;; exports
            (let ((seen (make-hash-table eq?)))
              (for-each (lambda (d)
                          (when (eq? (head-symbol d) 'export)
                            (for-each (lambda (e)
                                        (let*
                                            ((dt (cst->datum e))
                                             (vis
                                              (if
                                               (and (pair? dt)
                                                    (eq? (car dt) 'rename)
                                                    (= (length dt) 3))
                                               (caddr dt)
                                               dt))
                                             (int
                                              (if
                                               (and (pair? dt)
                                                    (eq? (car dt) 'rename)
                                                    (= (length dt) 3))
                                               (cadr dt)
                                               dt)))
                                          (when (symbol? vis)
                                            (when
                                                (hash-table-ref/default seen
                                                                        vis
                                                                        #f)
                                              (report!
                                               'duplicate-export
                                               e
                                               (string-append
                                                (symbol->string vis)
                                                " is exported twice")))
                                            (hash-table-set! seen vis #t)
                                            (set!
                                             exports
                                             (cons (list vis int e)
                                                   exports)))))
                                      (cdr (code-items d)))))
                        decls))
            (let ((body (library-body-forms decls)))
              (collect-definitions! body top-defs #t)
              (walk-body-forms body '())
              ;; exports count as uses
              (for-each (lambda (ex)
                          (let ((int (cadr ex)))
                            (if (symbol? int)
                                (let ((r (resolve int '())))
                                  (cond
                                   ((binding? r) (set-b-used! r 'exported))
                                   ((pair? r) (mark-import-used! (cdr r) int))
                                   (complete?
                                    (report!
                                     'export-undefined
                                     (caddr ex)
                                     (string-append
                                      (symbol->string int)
                                      " is exported but not defined")))))
                                #t)))
                        exports)
              (check-docstrings! body))))

        (define (analyze-program! forms)
          (for-each (lambda (f)
                      (when (eq? (head-symbol f) 'import)
                        (for-each add-import! (cdr (code-items f))))
                      ;; a loaded file can define anything
                      (when
                          (memq (head-symbol f)
                                '(load require include include-ci))
                        (set! complete? #f)))
                    forms)
          (let ((body (let loop ((fs forms) (acc '()))
                        (cond ((null? fs) (reverse acc))
                              ((eq? (head-symbol (car fs)) 'import)
                               (loop (cdr fs) acc))
                              (else (loop (cdr fs) (cons (car fs) acc)))))))
            (collect-definitions! body top-defs #t)
            (walk-body-forms body '())))

        ;; -- docstrings --
        (define (check-docstrings! body)
          (when
              (and lib-name
                   (pair? lib-name)
                   (symbol? (car lib-name))
                   (member (symbol->string (car lib-name))
                           (opt opts 'docstring-libraries '("scm"))))
            (let ((exported (map car exports))
                  (lib-text (datum->string lib-name)))
              (for-each (lambda (f)
                          (when
                              (and (eq? (head-symbol f) 'define)
                                   (>= (length (code-items f)) 3)
                                   (list-node? (cadr (code-items f))))
                            (let* ((target (cadr (code-items f)))
                                   (head (car (code-items target))))
                              (when
                                  (and (symbol-node? head)
                                       (memq (node-symbol head) exported))
                                (let* ((name
                                        (symbol->string (node-symbol head)))
                                       (body (cddr (code-items f)))
                                       (doc
                                        (and (pair? (cdr body))
                                             (string-node? (car body))
                                             (cst->datum (car body)))))
                                  (cond
                                   ((not (string? doc))
                                    (report!
                                     'missing-docstring
                                     head
                                     (string-append name
                                                    " is exported but has no docstring")))
                                   ((not (string-prefix? "Syntax:" doc))
                                    (report!
                                     'missing-docstring
                                     (car body)
                                     (string-append "the docstring of " name
                                                    " does not start with Syntax:")))
                                   (else
                                    (let
                                        ((syn
                                          (trim
                                           (substring
                                            doc
                                            7
                                            (or
                                             (string-index-of doc #\newline)
                                             (string-length doc))))))
                                      (unless
                                          (or
                                           (string-prefix?
                                            (string-append "(" name " ")
                                            syn)
                                           (string-prefix?
                                            (string-append "(" name ")")
                                            syn)
                                           (string=? syn name))
                                        (report!
                                         'docstring-syntax-mismatch
                                         (car body)
                                         (string-append
                                          "the Syntax: line does not describe "
                                          name))))
                                    (let
                                        ((lib-line
                                          (find-line doc "Library:")))
                                      (cond
                                       ((not lib-line)
                                        (report!
                                         'missing-docstring
                                         (car body)
                                         (string-append "the docstring of "
                                                        name
                                                        " has no Library: line")))
                                       ((not
                                         (string=? (trim lib-line) lib-text))
                                        (report!
                                         'docstring-library-mismatch
                                         (car body)
                                         (string-append "Library: "
                                                        (trim lib-line)
                                                        " should be "
                                                        lib-text))))))))))))
                        (flatten-begins body)))))

        (define (flatten-begins forms)
          (apply append
                 (map (lambda (f)
                        (if (eq? (head-symbol f) 'begin)
                            (flatten-begins (cdr (code-items f)))
                            (list f)))
                      forms)))

        (define (find-line doc prefix)
          (let loop ((start 0))
            (and (< start (string-length doc))
                 (let* ((end (let e ((k start))
                               (if (or (= k (string-length doc))
                                       (char=? (string-ref doc k) #\newline))
                                   k
                                   (e (+ k 1)))))
                        (ln (substring doc start end)))
                   (if (string-prefix? prefix ln)
                       (substring ln
                                  (string-length prefix)
                                  (string-length ln))
                       (loop (+ end 1)))))))

        ;; -- predicates naming (simple: every result is a boolean) --
        (define (check-predicate-naming! forms)
          (for-each (lambda (f)
                      (when
                          (and (eq? (head-symbol f) 'define)
                               (>= (length (code-items f)) 3)
                               (list-node? (cadr (code-items f))))
                        (let* ((head (car (code-items (cadr (code-items f)))))
                               (body (cddr (code-items f))))
                          (when
                              (and (symbol-node? head)
                                   (not
                                    (string-suffix?
                                     "?"
                                     (symbol->string (node-symbol head))))
                                   (boolean-result?
                                    (list-ref body (- (length body) 1))))
                            (report! 'predicate-naming
                                     head
                                     (string-append
                                      (symbol->string (node-symbol head))
                                      " returns only booleans: name it "
                                      (symbol->string (node-symbol head))
                                      "?"))))))
                    (flatten-begins forms)))

        (define (boolean-result? e)
          (cond ((or (true-literal? e) (false-literal? e)) #t)
                ((list-node? e)
                 (let ((h (head-symbol e))
                       (items (code-items e)))
                   (cond ((not h) #f)
                         ((memq h
                                '(not null? pair? = < > <= >= eq? eqv? equal?
                                  zero? string=? char=? boolean?))
                          #t)
                         ((memq h '(and or))
                          (and (pair? (cdr items))
                               (every? boolean-result? (cdr items))))
                         ((eq? h 'if)
                          (and (= (length items) 4)
                               (boolean-result? (caddr items))
                               (boolean-result? (cadddr items))))
                         ((string-suffix? "?" (symbol->string h)) #t)
                         (else #f))))
                (else #f)))

        ;; -- run --
        (let* ((forms (code-items cst))
               (lib (and (= (length (filter-nodes
                                     (lambda (f)
                                       (eq? (head-symbol f) 'define-library))
                                     forms))
                            1)
                         (car (filter-nodes
                               (lambda (f)
                                 (eq? (head-symbol f) 'define-library))
                               forms)))))
          (cond (lib (analyze-library! lib))
                ((any? (lambda (f) (eq? (head-symbol f) 'import)) forms)
                 (analyze-program! forms))
                (else
                 ;; no imports: a fragment or data file, the environment is unknown
                 (set! complete? #f)
                 #t))
          (when
              (or lib (any? (lambda (f) (eq? (head-symbol f) 'import)) forms))
            (check-unused-imports!)
            (check-import-conflicts!)
            (hash-table-walk top-defs
                             (lambda (name b)
                               (check-calls! b)
                               (when
                                   (and library? complete?
                                        (not (b-used b))
                                        (memq (b-kind b) '(define macro)))
                                 (report!
                                  'unused-definition
                                  (b-node b)
                                  (string-append
                                   (symbol->string name)
                                   " is defined but neither exported nor used")))))
            (check-predicate-naming! (if
                                      lib
                                      (library-body-forms
                                       (let ((items (code-items lib)))
                                         (if (>= (length items) 2)
                                             (cddr items)
                                             '())))
                                      forms))))))

    (define (import-group set)
      (let
          ((name (let unwrap ((d set))
                   (if (and (pair? d)
                            (memq (car d) '(only except prefix rename))
                            (pair? (cdr d)))
                       (unwrap (cadr d))
                       d))))
        (if (and (pair? name) (symbol? (car name)))
            (case (car name)
              ((scheme) 0)
              ((srfi) 1)
              ((scm) 2)
              (else 3))
            3)))

    (define (filter-nodes pred lst)
      (let loop ((l lst) (acc '()))
        (cond ((null? l) (reverse acc))
              ((pred (car l)) (loop (cdr l) (cons (car l) acc)))
              (else (loop (cdr l) acc)))))

    (define (list-head* lst k)
      (if (or (= k 0) (null? lst))
          '()
          (cons (car lst) (list-head* (cdr lst) (- k 1)))))

    (define (sort-symbols syms)
      (let loop ((l syms) (acc '()))
        (if (null? l)
            acc
            (loop (cdr l)
                  (let ins ((acc acc))
                    (cond ((null? acc) (list (car l)))
                          ((string<? (symbol->string (car l))
                                     (symbol->string (car acc)))
                           (cons (car l) acc))
                          (else (cons (car acc) (ins (cdr acc))))))))))

    (define (join-strings strs sep)
      (let loop ((s strs) (acc ""))
        (cond ((null? s) acc)
              ((string=? acc "") (loop (cdr s) (car s)))
              (else (loop (cdr s) (string-append acc sep (car s)))))))

    (define (join-symbols syms)
      (let loop ((s syms) (acc ""))
        (cond ((null? s) acc)
              ((string=? acc "") (loop (cdr s) (symbol->string (car s))))
              (else (loop (cdr s)
                          (string-append acc ", "
                                         (symbol->string (car s))))))))

    ;; ---- text checks -----------------------------------------------

    ;; Lines inside multi-line strings and block comments, and the column
    ;; spans of string atoms and comments per line.
    (define (token-spans cst)
      (let ((inner (make-hash-table eqv?))
            (spans (make-hash-table eqv?)))
        (define (add-span! line a b)
          (hash-table-set! spans line
                           (cons (cons a b)
                                 (hash-table-ref/default spans line '()))))
        (define (walk node)
          (case (cst-kind node)
            ((atom block-comment comment)
             (when
                 (or (memq (cst-kind node) '(block-comment comment))
                     (string-node? node))
               (let* ((t (cst-text node))
                      (first-nl (let loop ((k 0))
                                  (cond
                                   ((= k (string-length t)) #f)
                                   ((char=? (string-ref t k) #\newline) k)
                                   (else (loop (+ k 1)))))))
                 (add-span! (cst-line node)
                            (cst-col node)
                            (+ (cst-col node)
                               (or first-nl (string-length t))))
                 (when first-nl
                   (let loop ((k 0)
                              (line (cst-line node)))
                     (when (< k (string-length t))
                       (if (char=? (string-ref t k) #\newline)
                           (begin
                             (hash-table-set! inner (+ line 1) #t)
                             (loop (+ k 1) (+ line 1)))
                           (loop (+ k 1) line))))))))
            (else (for-each walk (cst-children node)))))
        (walk cst)
        (cons inner spans)))

    (define (text-checks text cst width emit)
      (let* ((ts (token-spans cst))
             (inner (car ts))
             (spans (cdr ts))
             (n (string-length text)))
        (let loop ((start 0) (line 1))
          (when (< start n)
            (let* ((end (let e ((k start))
                          (if (or (= k n)
                                  (char=? (string-ref text k) #\newline))
                              k
                              (e (+ k 1)))))
                   (ln (substring text start end))
                   (len (string-length (if
                                        (and
                                         (> (string-length ln) 0)
                                         (char=?
                                          (string-ref
                                           ln
                                           (- (string-length ln) 1))
                                          #\return))
                                        (substring ln 0
                                                   (- (string-length ln) 1))
                                        ln)))
                   (inside? (hash-table-ref/default inner line #f))
                   (line-spans (hash-table-ref/default spans line '()))
                   (in-span? (lambda (col)
                               (any? (lambda (s)
                                       (and (<= (car s) col) (< col (cdr s))))
                                     line-spans))))
              (unless inside?
                (when (and (> len width) (not (in-span? width)))
                  (emit 'line-too-long
                        line
                        width
                        (string-append "line is "
                                       (number->string len)
                                       " characters long (width "
                                       (number->string width)
                                       ")")))
                (when
                    (and (> len 0)
                         (memv (string-ref ln (- len 1)) '(#\space #\tab)))
                  (emit 'trailing-whitespace
                        line
                        (- len 1)
                        "trailing whitespace"))
                (let tab ((k 0))
                  (when (< k len)
                    (if (and (char=? (string-ref ln k) #\tab)
                             (not (in-span? k)))
                        (emit 'tab-character line k "tab character")
                        (tab (+ k 1))))))
              (loop (+ end 1) (+ line 1)))))
        (when (and (> n 0) (not (char=? (string-ref text (- n 1)) #\newline)))
          (emit 'missing-final-newline
                1
                0
                "the file does not end with a newline"))))

    ;; ---- sorting checks --------------------------------------------

    (define (sort-checks cst file opts emit)
      (let ((fopts (opt opts 'format-options '())))
        (let-values
            (((sorted _notes) (sort-source-declarations cst fopts file)))
          (for-each (lambda (orig new) (compare-clauses orig new emit))
                    (cst-children cst)
                    (cst-children sorted)))))

    (define (compare-clauses orig new emit)
      (let ((h (head-symbol orig)))
        (cond ((eq? h 'define-library)
               (for-each (lambda (o n) (compare-clauses o n emit))
                         (cst-children orig)
                         (cst-children new)))
              ((memq h '(import export))
               (unless
                   (equal? (map cst->string (code-items orig))
                           (map cst->string (code-items new)))
                 (emit (if (eq? h 'import)
                           'unsorted-imports
                           'unsorted-exports)
                       (cst-line orig)
                       (cst-col orig)
                       (if (eq? h 'import)
                           "imports are not sorted ((scheme ...), (srfi ...), (scm ...), others; alphabetically)"
                           "exports are not sorted alphabetically"))))
              (else #t))))

    ;; ---- suppression -----------------------------------------------

    (define (suppressions cst)
      ;; -> (file-disabled-rules . line-table) ; line-table: line -> list of rules or 'all
      (let ((disabled '())
            (lines (make-hash-table eqv?)))
        (define (walk node)
          (if (eq? (cst-kind node) 'comment)
              (let* ((t (cst-text node))
                     (body (trim (let loop ((k 0))
                                   (if (and (< k (string-length t))
                                            (char=? (string-ref t k) #\;))
                                       (loop (+ k 1))
                                       (substring t k (string-length t)))))))
                (cond ((string-prefix? "lint: disable" body)
                       (set! disabled
                             (append (map
                                      string->symbol
                                      (split-words
                                       (substring body 13
                                                  (string-length body))))
                                     disabled)))
                      ((string-prefix? "lint: ignore" body)
                       (let* ((rules (map
                                      string->symbol
                                      (split-words
                                       (substring body 12
                                                  (string-length body)))))
                              (target (if (cst-trailing-comment? node)
                                          (cst-line node)
                                          (+ 1 (cst-line node)))))
                         (hash-table-set! lines target
                                          (if (null? rules) 'all rules))))))
              (for-each walk (cst-children node))))
        (walk cst)
        (cons disabled lines)))

    ;; ---- entry points ----------------------------------------------

    (define (enabled-rules opts)
      (let ((enable (opt opts 'enable '()))
            (disable (opt opts 'disable '())))
        (let loop ((rs rule-table) (acc '()))
          (if (null? rs)
              acc
              (let* ((r (car rs))
                     (id (car r)))
                (loop (cdr rs)
                      (if (and (or (caddr r)
                                   (memq id enable)
                                   (and (eq? id 'not-formatted)
                                        (opt opts 'fmt-check #f)))
                               (not (memq id disable))
                               (or (not (eq? id 'not-formatted))
                                   (opt opts 'fmt-check #f)))
                          (cons id acc)
                          acc)))))))

    (define (lint-string text file . maybe-opts)
      "Syntax: (lint-string text file [options])
Library: (scm source lint)
Description: Checks the Scheme source text (named file in the findings
  and used to find sibling libraries) and returns the findings, a list of
  lint-finding records sorted by position. options is an alist as
  returned by lint-options (missing keys take the defaults). Accessors:
  lint-finding-rule, lint-finding-severity, lint-finding-file,
  lint-finding-line (from 1), lint-finding-col (from 0),
  lint-finding-message.
Example:
  (map lint-finding-rule
       (lint-string \"(import (scheme base))\\n(define (f x) (car (cdr x)))\\n\"
                    \"a.scm\"))
    => (cxr)"
      (let* ((opts (if (pair? maybe-opts) (car maybe-opts) '()))
             (enabled (enabled-rules opts))
             (found '()))
        (define (finish cst)
          (let* ((sup (if cst
                          (suppressions cst)
                          (cons '() (make-hash-table eqv?))))
                 (disabled (car sup))
                 (lines (cdr sup)))
            (sort-findings (filter-nodes
                            (lambda (f)
                              (let
                                  ((ign
                                    (hash-table-ref/default
                                     lines
                                     (lint-finding-line f)
                                     #f)))
                                (not (or
                                      (memq (lint-finding-rule f) disabled)
                                      (eq? ign 'all)
                                      (and
                                       (pair? ign)
                                       (memq (lint-finding-rule f) ign))))))
                            found))))
        (define (emit rule line col message)
          (when (memq rule enabled)
            (set! found
                  (cons (make-lint-finding rule
                                           (rule-severity rule)
                                           file
                                           line
                                           col
                                           message)
                        found))))
        (let ((cst (guard (e ((source-read-error-position e)
                              =>
                              (lambda (pos)
                                (emit 'read-error
                                      (cadr pos)
                                      (caddr pos)
                                      (substring
                                       (error-object-message e)
                                       13
                                       (string-length
                                        (error-object-message e))))
                                #f)))
                     (source-read-string text file))))
          (when cst
            (analyze cst file opts emit)
            (text-checks text cst (opt opts 'width 78) emit)
            (when
                (or (memq 'unsorted-imports enabled)
                    (memq 'unsorted-exports enabled))
              (guard (e (#t #f)) (sort-checks cst file opts emit)))
            (when (memq 'not-formatted enabled)
              (guard (e (#t #f))
                (unless
                    (string=? text
                              (format-source-string
                               text
                               (opt opts 'format-options '())))
                  (emit 'not-formatted
                        1
                        0
                        "scm fmt would change this file")))))
          (finish cst))))

    (define (sort-findings fs)
      (let ((v (list->vector fs)))
        ;; insertion sort on (line col) is fine for per-file counts, but use
        ;; a merge to stay fast on files with many findings
        (merge-sort (vector->list v)
                    (lambda (a b)
                      (or (< (lint-finding-line a) (lint-finding-line b))
                          (and (= (lint-finding-line a) (lint-finding-line b))
                               (< (lint-finding-col a)
                                  (lint-finding-col b))))))))

    (define (merge-sort lst less?)
      (define (merge a b)
        (cond ((null? a) b)
              ((null? b) a)
              ((less? (car b) (car a)) (cons (car b) (merge a (cdr b))))
              (else (cons (car a) (merge (cdr a) b)))))
      (let loop ((lst lst))
        (if (or (null? lst) (null? (cdr lst)))
            lst
            (let split ((l lst) (a '()) (b '()))
              (if (null? l)
                  (merge (loop (reverse a)) (loop (reverse b)))
                  (split (cdr l) (cons (car l) b) a))))))

    (define (lint-file path . maybe-opts)
      "Syntax: (lint-file path [options])
Library: (scm source lint)
Description: Checks the Scheme source file at path, like lint-string;
  options default to (lint-options path).
Example:
  (lint-findings->text (lint-file \"src/app.sld\"))"
      (lint-string (read-file-string path)
                   path
                   (if (pair? maybe-opts)
                       (car maybe-opts)
                       (lint-options path))))

    ;; ---- command line ----------------------------------------------

    (define lint-usage
      "usage: scm lint [options] PATH...
Checks Scheme source files and reports problems as
file:line:column: severity: [rule] message. A PATH is a file or a
directory (searched for *.scm and *.sld).

  --enable RULE,...   also check these rules (see --list-rules)
  --disable RULE,...  do not check these rules
  --fail-on LEVEL     exit with 1 if there is a finding of this severity
                      or worse: error (default), warning or info
  --format FORMAT     text (default) or json
  --width N           line width for line-too-long (default 78)
  --fmt-check         also report files scm fmt would change
  --exclude GLOB      skip matching files and directories (repeatable)
  --quiet             no summary line
  --list-rules        list the rules and exit
  --help              this text

Settings come from the nearest scm-tools.toml ([lint] table); options
given here are added. A `;; lint: disable RULE ...` comment switches rules
off for its file, `; lint: ignore [RULE ...]` for its line (or the next
line, when the comment stands alone). Exit codes: 0 ok, 1 findings at the
--fail-on level, 2 usage error.
")

    (define (lint-command args)
      "Syntax: (lint-command args)
Library: (scm source lint)
Description: Runs `scm lint` with the list of argument strings args (the
  command line after \"lint\") and returns the exit code. See `scm lint
  --help`.
Example:
  (lint-command '(\"src\")) => 0"
      (let loop
          ((as args)
           (over '())
           (paths '())
           (fmt 'text)
           (fail-on 'error)
           (excludes '())
           (quiet? #f))
        (define (usage-error msg)
          (write-string (string-append "scm lint: " msg "\n")
                        (current-error-port))
          (write-string lint-usage (current-error-port))
          2)
        (define (rule-list s) (map string->symbol (split-words s)))
        (define (unknown-rules ids)
          (filter-nodes (lambda (id) (not (assq id rule-table))) ids))
        (cond ((null? as)
               (if (null? paths)
                   (usage-error "no PATH given")
                   (run-lint (reverse paths)
                             over
                             fmt
                             fail-on
                             excludes
                             quiet?)))
              (else (let ((a (car as))
                          (val (and (pair? (cdr as)) (cadr as))))
                      (cond ((member a '("--help" "-h"))
                             (write-string lint-usage)
                             0)
                            ((string=? a "--list-rules")
                             (for-each (lambda (r)
                                         (write-string
                                          (string-append
                                           (symbol->string (car r))
                                           (make-string
                                            (max
                                             1
                                             (-
                                              28
                                              (string-length
                                               (symbol->string (car r)))))
                                            #\space)
                                           (symbol->string (cadr r))
                                           (make-string
                                            (max
                                             1
                                             (-
                                              8
                                              (string-length
                                               (symbol->string (cadr r)))))
                                            #\space)
                                           (if (caddr r) "on   " "off  ")
                                           (cadddr r)
                                           "\n")))
                                       rule-table)
                             0)
                            ((string=? a "--quiet")
                             (loop (cdr as)
                                   over
                                   paths
                                   fmt
                                   fail-on
                                   excludes
                                   #t))
                            ((string=? a "--fmt-check")
                             (loop (cdr as)
                                   (cons '(fmt-check . #t) over)
                                   paths
                                   fmt
                                   fail-on
                                   excludes
                                   quiet?))
                            ((member a '("--enable" "--disable"))
                             (cond ((not val)
                                    (usage-error
                                     (string-append a " needs rule names")))
                                   ((pair? (unknown-rules (rule-list val)))
                                    (usage-error
                                     (string-append
                                      "unknown rule "
                                      (symbol->string
                                       (car
                                        (unknown-rules (rule-list val)))))))
                                   (else
                                    (let
                                        ((key
                                          (if (string=? a "--enable")
                                              'enable
                                              'disable)))
                                      (loop
                                       (cddr as)
                                       (cons
                                        (cons
                                         key
                                         (append (rule-list val)
                                                 (opt over key '())))
                                        over)
                                       paths
                                       fmt
                                       fail-on
                                       excludes
                                       quiet?)))))
                            ((string=? a "--fail-on")
                             (if (member val '("error" "warning" "info"))
                                 (loop (cddr as)
                                       over
                                       paths
                                       fmt
                                       (string->symbol val)
                                       excludes
                                       quiet?)
                                 (usage-error
                                  "--fail-on takes error, warning or info")))
                            ((string=? a "--format")
                             (if (member val '("text" "json"))
                                 (loop (cddr as)
                                       over
                                       paths
                                       (string->symbol val)
                                       fail-on
                                       excludes
                                       quiet?)
                                 (usage-error "--format takes text or json")))
                            ((string=? a "--width")
                             (let ((n (and val (string->number val))))
                               (if (and n (exact-integer? n) (> n 10))
                                   (loop (cddr as)
                                         (cons (cons 'width n) over)
                                         paths
                                         fmt
                                         fail-on
                                         excludes
                                         quiet?)
                                   (usage-error
                                    "--width needs a number above 10"))))
                            ((string=? a "--exclude")
                             (if val
                                 (loop (cddr as)
                                       over
                                       paths
                                       fmt
                                       fail-on
                                       (cons val excludes)
                                       quiet?)
                                 (usage-error "--exclude needs a pattern")))
                            ((and (> (string-length a) 1)
                                  (char=? (string-ref a 0) #\-))
                             (usage-error
                              (string-append "unknown option " a)))
                            (else (loop (cdr as)
                                        over
                                        (cons a paths)
                                        fmt
                                        fail-on
                                        excludes
                                        quiet?))))))))

    (define (run-lint paths over fmt fail-on excludes quiet?)
      (let ((all '()) (files 0) (missing 0))
        (for-each (lambda (path)
                    (if (or (file-exists? path) (directory-exists? path))
                        (for-each (lambda (file)
                                    (set! files (+ files 1))
                                    (let
                                        ((fs
                                          (if
                                           (tools-excluded? file "lint")
                                           '()
                                           (guard
                                               (e
                                                (#t
                                                 (list
                                                  (make-lint-finding
                                                   'read-error
                                                   'error
                                                   file
                                                   1
                                                   0
                                                   (if
                                                    (error-object? e)
                                                    (string-append
                                                     "cannot check: "
                                                     (error-object-message e))
                                                    "cannot check")))))
                                             (lint-string
                                              (read-file-string file)
                                              file
                                              (lint-options file over))))))
                                      (when (eq? fmt 'text)
                                        (write-string
                                         (lint-findings->text fs)))
                                      (set! all (append all fs))))
                                  (collect-source-files (list path) excludes))
                        (begin
                          (set! missing (+ missing 1))
                          (write-string
                           (string-append path
                                          ": no such file or directory\n")
                           (current-error-port)))))
                  paths)
        (when (eq? fmt 'json)
          (write-string (lint-findings->json all))
          (newline))
        (unless quiet?
          (let
              ((count (lambda (s)
                        (length (filter-nodes
                                 (lambda (f)
                                   (eq? (lint-finding-severity f) s))
                                 all)))))
            (write-string (string-append (number->string files)
                                         " file(s): "
                                         (number->string (count 'error))
                                         " error(s), "
                                         (number->string (count 'warning))
                                         " warning(s), "
                                         (number->string (count 'info))
                                         " info\n")
                          (current-error-port))))
        (cond ((> missing 0) 2)
              ((any? (lambda (f)
                       (>= (severity-rank (lint-finding-severity f))
                           (severity-rank fail-on)))
                     all)
               1)
              (else 0))))))

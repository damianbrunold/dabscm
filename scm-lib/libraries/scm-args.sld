(define-library (scm args)
  (import (scm core)
          (scheme base)
          (scheme write)
          (scheme process-context)
          (srfi 1)
          (srfi 13))
  (export
    ;; parsing + accessors
    parse-args args-ref args->alist args-rest
    ;; data-form construction
    make-arg-parser opt flag pos
    ;; declarative macro
    define-cli
    ;; help rendering
    format-help
    ;; types
    make-arg-type arg-type? coerce-type
    arg:string arg:integer arg:number arg:boolean arg:symbol
    arg:one-of arg:list
    ;; predicates / introspection
    arg-parser? arg-spec? arg-result?)
  (begin

    ;; ----------------------------------------------------------------
    ;; (scm args) — declarative command-line argument parsing.
    ;;
    ;; You describe a grammar once — options, flags, key-value options
    ;; and positionals, each optionally typed — and hand it to
    ;; parse-args. The parser validates the input, converts values to
    ;; the declared types, and produces a result you read with
    ;; args-ref. --help and --version are generated from the spec.
    ;;
    ;; Two equivalent ways to build a spec:
    ;;
    ;;   ;; declarative macro
    ;;   (define cli
    ;;     (define-cli
    ;;       (program "resize") (description "Resize images.") (version "1.0")
    ;;       (option width  (short #\w) (long "width") (type arg:integer)
    ;;               (required #t) (help "Target width in px"))
    ;;       (flag   verbose (short #\v) (long "verbose") (help "Verbose"))
    ;;       (positional input (type arg:string) (required #t))))
    ;;
    ;;   ;; data form (programmatic specs)
    ;;   (define cli
    ;;     (make-arg-parser
    ;;       'program "resize" 'version "1.0"
    ;;       'options (list (opt 'width 'short #\w 'long "width"
    ;;                           'type arg:integer 'required #t)
    ;;                      (flag 'verbose 'short #\v 'long "verbose"))
    ;;       'positionals (list (pos 'input 'type arg:string 'required #t))))
    ;;
    ;;   (define r (parse-args cli))        ; defaults to (cdr (command-line))
    ;;   (args-ref r 'width)                ; => 800
    ;;
    ;; Token grammar understood by parse-args:
    ;;   --long val   --long=val            long option, value as next token or =
    ;;   -o val       -o=val                short option, value as next token or =
    ;;   -abc                               cluster of boolean short flags
    ;;   --verbose / --no-verbose           set / clear a boolean flag
    ;;   --                                 stop option parsing; rest positional
    ;; Tokens like -5 (leading digit) and - are treated as positionals.
    ;; ----------------------------------------------------------------

    ;; sentinel for "no default supplied"
    (define %unset (list '%unset))
    (define (unset? v) (eq? v %unset))

    ;; --- small string/list helpers (kept local to avoid srfi spread) ---

    (define (str-index-char s ch)
      (let ((n (string-length s)))
        (let loop ((i 0))
          (cond ((= i n) #f)
                ((char=? (string-ref s i) ch) i)
                (else (loop (+ i 1)))))))

    (define (string-split-char s ch)
      (let ((n (string-length s)))
        (let loop ((i 0) (start 0) (acc '()))
          (cond ((= i n) (reverse (cons (substring s start n) acc)))
                ((char=? (string-ref s i) ch)
                 (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
                (else (loop (+ i 1) start acc))))))

    (define (join-strings lst sep)
      (cond ((null? lst) "")
            ((null? (cdr lst)) (car lst))
            (else (string-append (car lst) sep (join-strings (cdr lst) sep)))))

    (define (del-assq key lst)
      (filter (lambda (p) (not (eq? (car p) key))) lst))

    (define (digit-char? c)
      (and (char>=? c #\0) (char<=? c #\9)))

    ;; ================================================================
    ;; Types — a type is a name (for --help) plus a string->value
    ;; converter that raises (via error) on invalid input.
    ;; ================================================================

    (define-record-type arg-type
      (make-arg-type* name convert)
      arg-type?
      (name arg-type-name)
      (convert arg-type-convert))

    (define (make-arg-type name convert)
      "Syntax: (make-arg-type name convert)
Library: (scm args)
Description: Builds a custom argument type. name is a short string shown in
  --help as the value placeholder (e.g. \"PORT\"); convert is a procedure
  taking the raw argument string and returning the converted value, raising
  via error on invalid input (the message is surfaced to the user). Any
  bare string->value procedure also works as a type — parse-args coerces it
  with the placeholder \"VALUE\".
Example:
  (define arg:port
    (make-arg-type \"PORT\"
      (lambda (s)
        (let ((n (string->number s)))
          (if (and n (integer? n) (<= 1 n 65535)) n
              (error (string-append \"bad port: \" s)))))))"
      (make-arg-type* name convert))

    (define (coerce-type t)
      "Syntax: (coerce-type t)
Library: (scm args)
Description: Normalizes a type designator to an arg-type: an arg-type is
  returned unchanged; a bare procedure is wrapped as a string->value
  converter with the placeholder \"VALUE\". Used internally and when writing
  custom type combinators.
Example:
  (coerce-type string->number) => #<arg-type VALUE>"
      (cond ((arg-type? t) t)
            ((procedure? t) (make-arg-type "VALUE" t))
            (else (error "args: not a valid type" t))))

    (define arg:string (make-arg-type "STRING" (lambda (s) s)))

    (define arg:integer
      (make-arg-type "INT"
        (lambda (s)
          (let ((n (string->number s)))
            (if (and n (integer? n) (exact? n)) n
                (error (string-append "expected an integer, got '" s "'")))))))

    (define arg:number
      (make-arg-type "NUM"
        (lambda (s)
          (let ((n (string->number s)))
            (if (and n (real? n)) n
                (error (string-append "expected a number, got '" s "'")))))))

    (define arg:boolean
      (make-arg-type "BOOL"
        (lambda (s)
          (let ((d (string-downcase s)))
            (cond ((member d '("true" "yes" "y" "1" "on")) #t)
                  ((member d '("false" "no" "n" "0" "off")) #f)
                  (else (error (string-append "expected a boolean, got '" s "'"))))))))

    (define arg:symbol (make-arg-type "SYM" (lambda (s) (string->symbol s))))

    (define (arg:one-of . syms)
      "Syntax: (arg:one-of sym ...)
Library: (scm args)
Description: A type accepting only one of the given symbols (an enumeration).
  The argument string is read as a symbol and must be a member of syms;
  otherwise a usage error listing the choices is reported. In --help the
  placeholder renders as {sym|sym|...}. Note the symbols are evaluated, so
  quote them: (arg:one-of 'fast 'slow).
Example:
  (option mode (long \"mode\") (type (arg:one-of 'fast 'slow)) (default 'fast))"
      (make-arg-type
        (string-append "{" (join-strings (map symbol->string syms) "|") "}")
        (lambda (s)
          (let ((sym (string->symbol s)))
            (if (memq sym syms) sym
                (error (string-append "expected one of "
                                      (join-strings (map symbol->string syms) ", ")
                                      ", got '" s "'")))))))

    (define (arg:list elem . sep-opt)
      "Syntax: (arg:list elem-type [separator])
Library: (scm args)
Description: A type that splits the argument on separator (a char, default
  #\\,) and converts each piece with elem-type, returning a list. elem-type
  may be any type or bare converter procedure. Empty pieces are kept.
Example:
  (option nums (long \"nums\") (type (arg:list arg:integer)))
  ;; --nums 1,2,3  =>  (1 2 3)"
      (let ((sep (if (null? sep-opt) #\, (car sep-opt)))
            (et (coerce-type elem)))
        (make-arg-type
          (string-append (arg-type-name et) "[" (string sep) "...]")
          (lambda (s)
            (map (arg-type-convert et) (string-split-char s sep))))))

    ;; ================================================================
    ;; Spec + parser records
    ;; ================================================================

    ;; kind is one of: option | flag | positional
    (define-record-type arg-spec
      (make-arg-spec* kind name shorts longs type required default repeat help metavar)
      arg-spec?
      (kind     arg-spec-kind)
      (name     arg-spec-name)
      (shorts   arg-spec-shorts   set-arg-spec-shorts!)
      (longs    arg-spec-longs    set-arg-spec-longs!)
      (type     arg-spec-type     set-arg-spec-type!)
      (required arg-spec-required set-arg-spec-required!)
      (default  arg-spec-default  set-arg-spec-default!)
      (repeat   arg-spec-repeat   set-arg-spec-repeat!)
      (help     arg-spec-help     set-arg-spec-help!)
      (metavar  arg-spec-metavar  set-arg-spec-metavar!))

    (define (fresh-spec kind name)
      (make-arg-spec* kind name '() '() arg:string #f %unset #f #f #f))

    (define (arg-spec-add-short! s c)
      (set-arg-spec-shorts! s (append (arg-spec-shorts s) (list c))))
    (define (arg-spec-add-long! s l)
      (set-arg-spec-longs! s (append (arg-spec-longs s) (list l))))

    (define-record-type arg-parser
      (make-arg-parser* program description version epilog options positionals)
      arg-parser?
      (program      arg-parser-program      set-arg-parser-program!)
      (description  arg-parser-description   set-arg-parser-description!)
      (version      arg-parser-version       set-arg-parser-version!)
      (epilog       arg-parser-epilog        set-arg-parser-epilog!)
      (options      arg-parser-options       set-arg-parser-options!)
      (positionals  arg-parser-positionals   set-arg-parser-positionals!))

    (define (make-empty-arg-parser)
      (make-arg-parser* "program" #f #f #f '() '()))

    (define (arg-parser-add-option! p s)
      (set-arg-parser-options! p (append (arg-parser-options p) (list s))))
    (define (arg-parser-add-positional! p s)
      (set-arg-parser-positionals! p (append (arg-parser-positionals p) (list s))))

    (define-record-type arg-result
      (make-arg-result alist rest)
      arg-result?
      (alist arg-result-alist)
      (rest  arg-result-rest))

    ;; ================================================================
    ;; Data-form construction: opt / flag / pos / make-arg-parser
    ;; ================================================================

    (define (apply-spec-plist! s plist)
      (let loop ((p plist))
        (cond
          ((null? p) s)
          ((null? (cdr p)) (error "args: odd-length property list in spec" (arg-spec-name s)))
          (else
           (let ((k (car p)) (v (cadr p)))
             (case k
               ((short)    (arg-spec-add-short! s v))
               ((long)     (arg-spec-add-long! s v))
               ((type)     (set-arg-spec-type! s v))
               ((default)  (set-arg-spec-default! s v))
               ((required) (set-arg-spec-required! s v))
               ((repeat)   (set-arg-spec-repeat! s v))
               ((help)     (set-arg-spec-help! s v))
               ((metavar)  (set-arg-spec-metavar! s v))
               (else (error "args: unknown spec keyword" k)))
             (loop (cddr p)))))))

    (define (opt name . plist)
      "Syntax: (opt name key value ...)
Library: (scm args)
Description: Builds a key-value option spec (data form). Keys: short (a
  char), long (a string), type (an arg-type, default arg:string), default,
  required (boolean), repeat (boolean — collect repeats into a list), help,
  metavar. Use inside make-arg-parser's 'options list.
Example:
  (opt 'count 'short #\\n 'long \"count\" 'type arg:integer 'default 1)"
      (apply-spec-plist! (fresh-spec 'option name) plist))

    (define (flag name . plist)
      "Syntax: (flag name key value ...)
Library: (scm args)
Description: Builds a boolean flag spec (data form). Presence sets it to #t;
  --no-<long> sets it to #f. Keys: short, long, default, help. Use inside
  make-arg-parser's 'options list.
Example:
  (flag 'verbose 'short #\\v 'long \"verbose\" 'help \"Verbose output\")"
      (apply-spec-plist! (fresh-spec 'flag name) plist))

    (define (pos name . plist)
      "Syntax: (pos name key value ...)
Library: (scm args)
Description: Builds a positional argument spec (data form). Keys: type,
  required, default, repeat (variadic — collects all remaining positionals
  into a list; must be the last positional), help. Use inside
  make-arg-parser's 'positionals list.
Example:
  (pos 'input 'type arg:string 'required #t 'help \"Input file\")"
      (apply-spec-plist! (fresh-spec 'positional name) plist))

    (define (make-arg-parser . plist)
      "Syntax: (make-arg-parser key value ...)
Library: (scm args)
Description: Builds an argument parser (data form). Keys: program (string),
  description, version, epilog, options (list of opt/flag specs),
  positionals (list of pos specs). The declarative define-cli macro is a
  more readable front end producing the same object.
Example:
  (make-arg-parser 'program \"tool\"
    'options (list (flag 'verbose 'short #\\v))
    'positionals (list (pos 'file 'required #t)))"
      (let ((p (make-empty-arg-parser)))
        (let loop ((pl plist))
          (cond
            ((null? pl) p)
            ((null? (cdr pl)) (error "args: odd-length property list" pl))
            (else
             (let ((k (car pl)) (v (cadr pl)))
               (case k
                 ((program)     (set-arg-parser-program! p v))
                 ((description) (set-arg-parser-description! p v))
                 ((version)     (set-arg-parser-version! p v))
                 ((epilog)      (set-arg-parser-epilog! p v))
                 ((options)     (for-each (lambda (s) (arg-parser-add-option! p s)) v))
                 ((positionals) (for-each (lambda (s) (arg-parser-add-positional! p s)) v))
                 (else (error "args: unknown parser keyword" k)))
               (loop (cddr pl))))))))

    ;; ================================================================
    ;; Declarative macro: define-cli
    ;; ================================================================

    ;; Each clause within an option/flag/positional becomes a one-arg
    ;; mutator applied to a fresh spec.
    (define-syntax cli-clause
      (syntax-rules (short long type default required repeat help metavar)
        ((_ (short c))    (lambda (s) (arg-spec-add-short! s c)))
        ((_ (long l))     (lambda (s) (arg-spec-add-long! s l)))
        ((_ (type t))     (lambda (s) (set-arg-spec-type! s t)))
        ((_ (default v))  (lambda (s) (set-arg-spec-default! s v)))
        ((_ (required v)) (lambda (s) (set-arg-spec-required! s v)))
        ((_ (required))   (lambda (s) (set-arg-spec-required! s #t)))
        ((_ (repeat v))   (lambda (s) (set-arg-spec-repeat! s v)))
        ((_ (repeat))     (lambda (s) (set-arg-spec-repeat! s #t)))
        ((_ (help h))     (lambda (s) (set-arg-spec-help! s h)))
        ((_ (metavar m))  (lambda (s) (set-arg-spec-metavar! s m)))))

    (define (build-spec kind name clause-procs)
      (let ((s (fresh-spec kind name)))
        (for-each (lambda (f) (f s)) clause-procs)
        s))

    ;; Each top-level clause mutates the parser p.
    (define-syntax cli-top-clause
      (syntax-rules (program description version epilog option flag positional)
        ((_ p (program x))      (set-arg-parser-program! p x))
        ((_ p (description x))   (set-arg-parser-description! p x))
        ((_ p (version x))       (set-arg-parser-version! p x))
        ((_ p (epilog x))        (set-arg-parser-epilog! p x))
        ((_ p (option name c ...))
         (arg-parser-add-option! p (build-spec 'option 'name (list (cli-clause c) ...))))
        ((_ p (flag name c ...))
         (arg-parser-add-option! p (build-spec 'flag 'name (list (cli-clause c) ...))))
        ((_ p (positional name c ...))
         (arg-parser-add-positional! p (build-spec 'positional 'name (list (cli-clause c) ...))))))

    (define-syntax define-cli
      (syntax-rules ()
        ((_ clause ...)
         (let ((the-parser (make-empty-arg-parser)))
           (cli-top-clause the-parser clause) ...
           the-parser))))

    ;; ================================================================
    ;; Lookup
    ;; ================================================================

    (define (find-by-short parser ch)
      (find (lambda (s) (memv ch (arg-spec-shorts s))) (arg-parser-options parser)))
    (define (find-by-long parser name)
      (find (lambda (s) (member name (arg-spec-longs s))) (arg-parser-options parser)))

    (define (spec-display-name s)
      (cond ((pair? (arg-spec-longs s)) (string-append "--" (car (arg-spec-longs s))))
            ((pair? (arg-spec-shorts s)) (string-append "-" (string (car (arg-spec-shorts s)))))
            (else (symbol->string (arg-spec-name s)))))

    ;; ================================================================
    ;; Parsing
    ;; ================================================================

    (define (parse-args parser . rest)
      "Syntax: (parse-args parser [args] ['on-error mode])
Library: (scm args)
Description: Parses argument list args (default: (cdr (command-line)), i.e.
  the script's arguments with the program path removed) against parser,
  returning a result usable with args-ref / args->alist / args-rest. Values
  are converted to their declared types. mode is 'exit (default) — on a
  usage error print a diagnostic to (current-error-port) and exit 2 — or
  'raise to signal a catchable error instead. --help and --version always
  print to stdout and exit 0.
Example:
  (define r (parse-args cli '(\"-v\" \"--count\" \"3\" \"in.txt\")))
  (args-ref r 'count) => 3"
      (let* ((args (if (and (pair? rest) (list? (car rest)))
                       (car rest)
                       (cdr (command-line))))
             (kw (if (and (pair? rest) (list? (car rest))) (cdr rest) rest))
             (on-error (let ((p (memq 'on-error kw)))
                         (if (and p (pair? (cdr p))) (cadr p) 'exit)))
             (prog (or (arg-parser-program parser) "program")))

        (define (fail msg)
          (if (eq? on-error 'raise)
              (error (string-append prog ": " msg))
              (let ((ep (current-error-port)))
                (display prog ep) (display ": " ep) (display msg ep) (newline ep)
                (display "Try '" ep) (display prog ep)
                (display " --help' for more information." ep) (newline ep)
                (exit 2))))

        (define (show-help)
          (display (format-help parser) (current-output-port))
          (exit 0))

        (define (show-version)
          (display prog) (display " ") (display (arg-parser-version parser)) (newline)
          (exit 0))

        (define (convert-value spec str)
          (let ((ty (coerce-type (arg-spec-type spec))))
            (guard (e (#t (fail (string-append
                                  "invalid value for " (spec-display-name spec) ": "
                                  (if (error-object? e)
                                      (error-object-message e)
                                      "conversion failed")))))
              ((arg-type-convert ty) str))))

        (define (record-flag seen spec val)
          (cons (cons (arg-spec-name spec) val)
                (del-assq (arg-spec-name spec) seen)))

        (define (record-option seen spec val)
          (let ((nm (arg-spec-name spec)))
            (if (arg-spec-repeat spec)
                (let ((cur (cond ((assq nm seen) => cdr) (else '()))))
                  (cons (cons nm (append cur (list val))) (del-assq nm seen)))
                (cons (cons nm val) (del-assq nm seen)))))

        ;; resolve options not seen on the command line
        (define (resolve-options seen)
          (let loop ((specs (arg-parser-options parser)) (acc '()))
            (if (null? specs)
                acc
                (let* ((s (car specs)) (nm (arg-spec-name s)) (p (assq nm seen)))
                  (cond
                    (p (loop (cdr specs) (cons p acc)))
                    ((eq? (arg-spec-kind s) 'flag)
                     (loop (cdr specs)
                           (cons (cons nm (if (unset? (arg-spec-default s)) #f (arg-spec-default s))) acc)))
                    ((arg-spec-repeat s)
                     (loop (cdr specs)
                           (cons (cons nm (if (unset? (arg-spec-default s)) '() (arg-spec-default s))) acc)))
                    ((not (unset? (arg-spec-default s)))
                     (loop (cdr specs) (cons (cons nm (arg-spec-default s)) acc)))
                    ((arg-spec-required s)
                     (fail (string-append "missing required option " (spec-display-name s))))
                    (else (loop (cdr specs) acc)))))))

        ;; assign collected positional tokens to positional specs
        (define (assign-positionals toks)
          (let ((specs (arg-parser-positionals parser)))
            (if (null? specs)
                (values '() toks)  ; no declared positionals -> everything is rest
                (let loop ((specs specs) (toks toks) (acc '()))
                  (if (null? specs)
                      (if (null? toks)
                          (values (reverse acc) '())
                          (fail (string-append "unexpected argument '" (car toks) "'")))
                      (let ((s (car specs)))
                        (if (arg-spec-repeat s)
                            (if (and (null? toks) (arg-spec-required s))
                                (fail (string-append "missing required argument '"
                                                     (symbol->string (arg-spec-name s)) "'"))
                                (values (reverse (cons (cons (arg-spec-name s)
                                                             (map (lambda (tk) (convert-value s tk)) toks))
                                                       acc))
                                        '()))
                            (if (null? toks)
                                (if (arg-spec-required s)
                                    (fail (string-append "missing required argument '"
                                                         (symbol->string (arg-spec-name s)) "'"))
                                    (loop (cdr specs) toks
                                          (if (unset? (arg-spec-default s))
                                              acc
                                              (cons (cons (arg-spec-name s) (arg-spec-default s)) acc))))
                                (loop (cdr specs) (cdr toks)
                                      (cons (cons (arg-spec-name s) (convert-value s (car toks))) acc))))))))))

        (define (finish seen posacc)
          (call-with-values
            (lambda () (assign-positionals (reverse posacc)))
            (lambda (posalist rst)
              (make-arg-result (append (resolve-options seen) posalist) rst))))

        ;; classification predicates
        (define (long-opt? t)
          (and (string-prefix? "--" t) (> (string-length t) 2)))
        (define (short-opt? t)
          (and (> (string-length t) 1)
               (char=? (string-ref t 0) #\-)
               (not (char=? (string-ref t 1) #\-))
               (not (digit-char? (string-ref t 1)))))

        (define (handle-long t more seen posacc done?)
          (let* ((body (substring t 2 (string-length t)))
                 (eqi (str-index-char body #\=))
                 (name (if eqi (substring body 0 eqi) body))
                 (val (if eqi (substring body (+ eqi 1) (string-length body)) #f)))
            (cond
              ((and (string=? name "help")
                    (not (find-by-long parser "help")))
               (show-help))
              ((and (string=? name "version") (arg-parser-version parser)
                    (not (find-by-long parser "version")))
               (show-version))
              (else
               (let ((spec (find-by-long parser name)))
                 (cond
                   (spec
                    (if (eq? (arg-spec-kind spec) 'flag)
                        (if val
                            (fail (string-append "option '--" name "' takes no value"))
                            (loop more (record-flag seen spec #t) posacc done?))
                        (if val
                            (loop more (record-option seen spec (convert-value spec val)) posacc done?)
                            (if (null? more)
                                (fail (string-append "option '--" name "' requires a value"))
                                (loop (cdr more)
                                      (record-option seen spec (convert-value spec (car more)))
                                      posacc done?)))))
                   ;; --no-<flag> negation
                   ((and (string-prefix? "no-" name)
                         (let ((bs (find-by-long parser (substring name 3 (string-length name)))))
                           (and bs (eq? (arg-spec-kind bs) 'flag) bs)))
                    => (lambda (bs) (loop more (record-flag seen bs #f) posacc done?)))
                   (else (fail (string-append "unknown option '--" name "'")))))))))

        (define (handle-short t more seen posacc done?)
          (let* ((bodyfull (substring t 1 (string-length t)))
                 (eqi (str-index-char bodyfull #\=)))
            (if eqi
                ;; -o=value : exactly one short char before '='
                (let ((chars (substring bodyfull 0 eqi))
                      (val (substring bodyfull (+ eqi 1) (string-length bodyfull))))
                  (if (not (= (string-length chars) 1))
                      (fail (string-append "malformed option '-" bodyfull "'"))
                      (let ((spec (find-by-short parser (string-ref chars 0))))
                        (cond
                          ((not spec) (fail (string-append "unknown option '-" chars "'")))
                          ((eq? (arg-spec-kind spec) 'flag)
                           (fail (string-append "option '-" chars "' takes no value")))
                          (else (loop more (record-option seen spec (convert-value spec val))
                                      posacc done?))))))
                ;; cluster of short options; last one may consume the next token
                (let scan ((i 0) (seen2 seen))
                  (if (= i (string-length bodyfull))
                      (loop more seen2 posacc done?)
                      (let* ((ch (string-ref bodyfull i))
                             (spec (find-by-short parser ch)))
                        (cond
                          ((and (char=? ch #\h) (not spec) (not (find-by-long parser "help")))
                           (show-help))
                          ((not spec)
                           (fail (string-append "unknown option '-" (string ch) "'")))
                          ((eq? (arg-spec-kind spec) 'flag)
                           (scan (+ i 1) (record-flag seen2 spec #t)))
                          (else
                           (if (= (+ i 1) (string-length bodyfull))
                               (if (null? more)
                                   (fail (string-append "option '-" (string ch) "' requires a value"))
                                   (loop (cdr more)
                                         (record-option seen2 spec (convert-value spec (car more)))
                                         posacc done?))
                               (fail (string-append "option '-" (string ch)
                                                    "' requires a value (use -" (string ch)
                                                    " <value> or -" (string ch) "=<value>)")))))))))))

        (define (loop toks seen posacc done?)
          (if (null? toks)
              (finish seen posacc)
              (let ((t (car toks)) (more (cdr toks)))
                (cond
                  (done? (loop more seen (cons t posacc) #t))
                  ((string=? t "--") (loop more seen posacc #t))
                  ((long-opt? t) (handle-long t more seen posacc done?))
                  ((short-opt? t) (handle-short t more seen posacc done?))
                  (else (loop more seen (cons t posacc) #f))))))

        (loop args '() '() #f)))

    ;; ================================================================
    ;; Accessors
    ;; ================================================================

    (define (args-ref result name . fallback)
      "Syntax: (args-ref result name [fallback])
Library: (scm args)
Description: Returns the value parsed for name (a symbol) from a parse-args
  result. If name was not supplied and has no default, returns fallback (or
  #f when no fallback is given). Flags return #t/#f; repeatable options
  return a list.
Example:
  (args-ref r 'count) => 3
  (args-ref r 'output \"-\") => \"-\"   ; not supplied, fallback used"
      (let ((p (assq name (arg-result-alist result))))
        (if p (cdr p) (if (null? fallback) #f (car fallback)))))

    (define (args->alist result)
      "Syntax: (args->alist result)
Library: (scm args)
Description: Returns the full association list of (name . value) pairs from a
  parse-args result. Handy for debugging or bulk processing.
Example:
  (args->alist r) => ((verbose . #t) (count . 3) (input . \"in.txt\"))"
      (arg-result-alist result))

    (define (args-rest result)
      "Syntax: (args-rest result)
Library: (scm args)
Description: Returns the list of leftover positional tokens. When the parser
  declares no positional specs, every positional argument lands here; when
  it does declare positionals, this is the empty list (use a repeat
  positional to capture a variable tail by name instead).
Example:
  (args-rest r) => (\"a.txt\" \"b.txt\")"
      (arg-result-rest result))

    ;; ================================================================
    ;; Help rendering
    ;; ================================================================

    (define (option-metavar s)
      (or (arg-spec-metavar s) (arg-type-name (coerce-type (arg-spec-type s)))))

    (define (option-invocation s)
      (let* ((shorts (map (lambda (c) (string-append "-" (string c))) (arg-spec-shorts s)))
             (longs (map (lambda (l) (string-append "--" l)) (arg-spec-longs s)))
             (base (join-strings (append shorts longs) ", ")))
        (if (eq? (arg-spec-kind s) 'flag)
            base
            (string-append base " " (option-metavar s)))))

    (define (value->display v)
      (cond ((string? v) v)
            ((symbol? v) (symbol->string v))
            ((number? v) (number->string v))
            ((eq? v #t) "true")
            ((eq? v #f) "false")
            ((null? v) "")
            (else (let ((o (open-output-string))) (write v o) (get-output-string o)))))

    (define (option-help-suffix s)
      (let* ((h (or (arg-spec-help s) ""))
             (extra (cond
                      ((and (not (eq? (arg-spec-kind s) 'flag)) (arg-spec-required s))
                       " (required)")
                      ((not (unset? (arg-spec-default s)))
                       (string-append " (default: " (value->display (arg-spec-default s)) ")"))
                      (else ""))))
        (string-append h extra)))

    (define (usage-line parser)
      (let* ((prog (or (arg-parser-program parser) "program"))
             (has-opts (pair? (arg-parser-options parser)))
             (pos (map (lambda (s)
                         (let ((nm (symbol->string (arg-spec-name s))))
                           (cond ((arg-spec-repeat s) (string-append "[" nm "...]"))
                                 ((arg-spec-required s) (string-append "<" nm ">"))
                                 (else (string-append "[" nm "]")))))
                       (arg-parser-positionals parser))))
        (string-append "Usage: " prog
                       (if has-opts " [options]" "")
                       (if (pair? pos) (string-append " " (join-strings pos " ")) ""))))

    (define (emit-rows out rows)
      (let ((w (min 28 (fold (lambda (r m) (max m (string-length (car r)))) 0 rows))))
        (for-each
          (lambda (r)
            (let ((left (car r)) (right (cdr r)))
              (display "  " out)
              (display left out)
              (cond
                ((string=? right "") (newline out))
                ((> (string-length left) w)
                 (newline out)
                 (display (make-string (+ 2 w 2) #\space) out)
                 (display right out) (newline out))
                (else
                 (display (make-string (+ (- w (string-length left)) 2) #\space) out)
                 (display right out) (newline out)))))
          rows)))

    (define (format-help parser)
      "Syntax: (format-help parser)
Library: (scm args)
Description: Renders the --help text for parser as a string: a usage line,
  the description, an Arguments section for positionals, and an Options
  section (including the auto-generated --help and --version entries).
  parse-args prints this and exits 0 on --help/-h.
Example:
  (display (format-help cli))"
      (let ((out (open-output-string)))
        (define (line . xs) (for-each (lambda (x) (display x out)) xs) (newline out))
        (line (usage-line parser))
        (when (arg-parser-description parser)
          (newline out) (line (arg-parser-description parser)))
        (when (pair? (arg-parser-positionals parser))
          (newline out) (line "Arguments:")
          (emit-rows out (map (lambda (s)
                                (cons (symbol->string (arg-spec-name s))
                                      (or (arg-spec-help s) "")))
                              (arg-parser-positionals parser))))
        (newline out) (line "Options:")
        (emit-rows out
          (append
            (map (lambda (s) (cons (option-invocation s) (option-help-suffix s)))
                 (arg-parser-options parser))
            (list (cons "-h, --help" "Show this help and exit"))
            (if (arg-parser-version parser)
                (list (cons "--version" "Show version and exit"))
                '())))
        (when (arg-parser-epilog parser)
          (newline out) (line (arg-parser-epilog parser)))
        (get-output-string out)))

))

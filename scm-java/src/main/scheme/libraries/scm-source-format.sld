(define-library (scm source format)
  (import (scheme base)
          (scheme char)
          (scheme file)
          (scheme write)
          (srfi 69)
          (scm fs)
          (scm io)
          (scm source))
  (export fmt-command
          format-file!
          format-options
          format-source-string
          sort-source-declarations
          source-diff)
  (begin

    ;; ================================================================
    ;; (scm source format) — the source formatter behind `scm fmt`.
    ;;
    ;; It reads a file losslessly with (scm source), optionally sorts the
    ;; import and export lists of define-library forms and top-level
    ;; imports, and lays the code out again with Emacs scheme-mode
    ;; indentation within a line width (78 by default):
    ;;
    ;;   - a form that fits on the rest of its line stays on one line,
    ;;     unless it is a body form with several body expressions, a cond
    ;;     or case with several clauses, a let with several bindings or an
    ;;     import/export list with several entries;
    ;;   - body forms (define..., lambda, let..., when, case, ...) keep
    ;;     their distinguished arguments on the first line and indent the
    ;;     body by 2 (distinguished arguments that must break go to +4);
    ;;   - other calls keep the first argument on the operator's line and
    ;;     align the rest under it, or put all arguments at +1;
    ;;   - data (quoted lists, vectors, lists headed by a non-symbol)
    ;;     align under the first element, atoms filled to the width;
    ;;   - comments stay where they are: end-of-line comments at the end
    ;;     of their line, other comments on lines of their own; one blank
    ;;     line is kept wherever the source had one or more;
    ;;   - strings, here-strings, block comments and atoms are copied
    ;;     verbatim, never split; brackets become parentheses.
    ;;
    ;; With keep-breaks the line breaks of the source are kept and only
    ;; the indentation is redone; lines still too long are broken.
    ;;
    ;; Safety net: the result must read back to the same datums as the
    ;; (sorted) input and formatting it again must not change it; if
    ;; either check fails the formatter raises an error instead of
    ;; returning a result.
    ;; ================================================================

    ;; ---- options ---------------------------------------------------

    (define default-options
      '((width . 78)
        (keep-breaks . #f)
        (sort-imports . #t)
        (sort-exports . #t)
        (keep-brackets . #f)
        (indent . ())
        (library-path . ())
        (unchecked . #f)))

    (define (opt opts key)
      (cond ((assq key opts) => cdr)
            ((assq key default-options) => cdr)
            (else #f)))

    (define (format-options path . overrides)
      "Syntax: (format-options path [overrides])
Library: (scm source format)
Description: Returns the formatter options for the file path: the
  defaults, overridden by the [format] table of the nearest
  scm-tools.toml (see tools-config in (scm source)), overridden by the
  alist overrides. Keys: width (integer, 78), keep-breaks (#f),
  sort-imports (#t), sort-exports (#t), keep-brackets (#f), indent (an
  alist of form name string to indent rule, see format-source-string)
  and library-path (directories searched for the .sld files of imported
  project libraries, relative paths taken from the config's directory).
Example:
  (cdr (assq 'width (format-options \"src/a.sld\" '((width . 100)))))
    => 100"
      (let* ((cfg (tools-config path))
             (dir (tools-config-ref cfg '("dir") "."))
             (get (lambda (k) (tools-config-ref cfg (list "format" k) 'none)))
             (from-cfg (let loop
                           ((keys '(("width" . width)
                                    ("keep-breaks" . keep-breaks)
                                    ("sort-imports" . sort-imports)
                                    ("sort-exports" . sort-exports)
                                    ("keep-brackets" . keep-brackets)))
                            (acc '()))
                         (if (null? keys)
                             acc
                             (let ((v (get (caar keys))))
                               (loop (cdr keys)
                                     (if (eq? v 'none)
                                         acc
                                         (cons (cons (cdar keys) v) acc)))))))
             (indent (let ((v (get "indent")))
                       (if (list? v)
                           (map (lambda (p)
                                  (cons
                                   (car p)
                                   (if (string? (cdr p))
                                       (string->symbol (cdr p))
                                       (cdr p))))
                                v)
                           '())))
             (libpath (let ((v (get "library-path")))
                        (if (list? v)
                            (map (lambda (d)
                                   (if (and (> (string-length d) 0)
                                            (char=? (string-ref d 0) #\/))
                                       d
                                       (string-append dir "/" d)))
                                 v)
                            '())))
             (over (if (pair? overrides) (car overrides) '())))
        (append over from-cfg
                (list (cons 'indent indent) (cons 'library-path libpath))
                default-options)))

    ;; ---- small helpers ---------------------------------------------

    (define (string-has-newline? s)
      (let loop ((k 0))
        (and (< k (string-length s))
             (or (char=? (string-ref s k) #\newline) (loop (+ k 1))))))

    (define (last-newline s)
      (let loop ((k (- (string-length s) 1)))
        (cond ((< k 0) #f)
              ((char=? (string-ref s k) #\newline) k)
              (else (loop (- k 1))))))

    (define (string-prefix? p s)
      (and (<= (string-length p) (string-length s))
           (string=? p (substring s 0 (string-length p)))))

    (define (rstrip s)
      (let loop ((k (string-length s)))
        (if (and (> k 0)
                 (memv (string-ref s (- k 1)) '(#\space #\tab #\return)))
            (loop (- k 1))
            (substring s 0 k))))

    (define (join strs)
      (let ((out (open-output-string)))
        (let loop ((ss strs) (first #t))
          (unless (null? ss)
            (unless first (write-char #\space out))
            (write-string (car ss) out)
            (loop (cdr ss) #f)))
        (get-output-string out)))

    (define (every? pred lst)
      (or (null? lst) (and (pred (car lst)) (every? pred (cdr lst)))))

    (define (any? pred lst)
      (and (pair? lst) (or (pred (car lst)) (any? pred (cdr lst)))))

    (define (comment-kind? node)
      (memq (cst-kind node) '(comment block-comment directive)))

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

    (define (symbol-name node)
      (let ((t (cst-text node)))
        (if (char=? (string-ref t 0) #\|)
            (substring t 1 (- (string-length t) 1))
            t)))

    (define (node-head-name node)
      (and (eq? (cst-kind node) 'list)
           (let ((items (code-items node)))
             (and (pair? items)
                  (symbol-node? (car items))
                  (symbol-name (car items))))))

    (define (with-pre node pre)
      (make-cst-node (cst-kind node)
                     (cst-text node)
                     (cst-line node)
                     (cst-col node)
                     pre
                     (cst-children node)
                     (cst-close node)))

    (define (with-children node kids)
      (make-cst-node (cst-kind node)
                     (cst-text node)
                     (cst-line node)
                     (cst-col node)
                     (cst-pre node)
                     kids
                     (cst-close node)))

    ;; Compares datums without deep recursion on long lists.
    (define (datum-equal? a b)
      (let loop ((a a) (b b))
        (cond ((and (pair? a) (pair? b))
               (and (datum-equal? (car a) (car b)) (loop (cdr a) (cdr b))))
              ((and (vector? a) (vector? b))
               (and (= (vector-length a) (vector-length b))
                    (let vl ((k 0))
                      (or (= k (vector-length a))
                          (and (datum-equal? (vector-ref a k)
                                             (vector-ref b k))
                               (vl (+ k 1)))))))
              (else (equal? a b)))))

    ;; ---- indentation rules -----------------------------------------
    ;;
    ;; A rule is a number N (body form with N distinguished arguments)
    ;; or one of the symbols below, which also say how the arguments are
    ;; laid out:
    ;;   define  N=1, a list first argument is a header
    ;;   lambda  N=1, the first argument is a formals list
    ;;   let     N=1 bindings, or N=2 for a named let
    ;;   do      N=2, bindings and the test clause
    ;;   receive N=2, formals
    ;;   cond    a call whose arguments are clauses, one per line
    ;;   case    N=1, then clauses (case, match)
    ;;   clauses N=0, every argument a clause (case-lambda)
    ;;   guard   N=1, the (var clause ...) argument
    ;;   rules   N=1 literals, then syntax rules (syntax-rules)
    ;;   import  a call whose arguments are library names / import
    ;;           sets / exports, one per line
    ;;   call    an ordinary call

    (define builtin-indent
      '(("begin" . 0)
        ("delay" . 0)
        ("delay-force" . 0)
        ("make-promise" . 0)
        ("define" . define)
        ("define-syntax" . define)
        ("define-values" . define)
        ("define-record-type" . define)
        ("define-library" . define)
        ("define-cli" . define)
        ("lambda" . lambda)
        ("named-lambda" . define)
        ("let" . let)
        ("let*" . let)
        ("letrec" . let)
        ("letrec*" . let)
        ("let-values" . let)
        ("let*-values" . let)
        ("parameterize" . let)
        ("fluid-let" . let)
        ("let-syntax" . let)
        ("letrec-syntax" . let)
        ("do" . do)
        ("receive" . receive)
        ("when" . 1)
        ("unless" . 1)
        ("cond" . cond)
        ("case" . case)
        ("match" . case)
        ("case-lambda" . clauses)
        ("guard" . guard)
        ("syntax-rules" . rules)
        ("er-macro-transformer" . 1)
        ("syntax-case" . 2)
        ("dynamic-wind" . 0)
        ("call-with-values" . 1)
        ("call-with-input-file" . 1)
        ("call-with-output-file" . 1)
        ("call-with-port" . 1)
        ("call-with-output-string" . 0)
        ("call-with-current-continuation" . 0)
        ("call/cc" . 0)
        ("with-input-from-file" . 1)
        ("with-output-to-file" . 1)
        ("with-exception-handler" . 1)
        ("test-group" . 1)
        ("test-begin" . 1)
        ("import" . import)
        ("export" . import)
        ("library" . 1)
        ("module" . 1)))

    (define (indent-rule name user)
      (cond ((assoc name user) => (lambda (p) (cons (cdr p) #t)))
            ((assoc name builtin-indent) => (lambda (p) (cons (cdr p) #t)))
            ((string-prefix? "define" name) (cons 'define #f))
            ((string-prefix? "with-" name) (cons 1 #f))
            ((string-prefix? "call-with-" name) (cons 1 #f))
            (else (cons 'call #f))))

    ;; Layout information for a list node in a context. Contexts:
    ;;   code      ordinary code
    ;;   data      quoted data
    ;;   plain     a list laid out as a call without consulting the
    ;;             indent rules (headers, formals, clauses, bindings)
    ;;   bindings  a list of bindings, one per line
    ;;   clauses   (var clause ...) of guard: a plain call, one per line
    ;; Result: #(style n argctx force? fill?) where style is call, body
    ;; or data, n the number of distinguished arguments (body), argctx a
    ;; procedure (index node) -> context for the code items after the
    ;; head (all code items for data), force? whether the list must
    ;; break and fill? whether atom arguments may share lines.

    (define (const-ctx c) (lambda (i node) c))

    (define (make-list-info user)
      (lambda (node ctx)
        (let* ((items (code-items node))
               (n (length items)))
          (cond ((not (eq? (cst-kind node) 'list))
                 (vector 'data 0 (const-ctx 'data) #f #t))
                ((eq? ctx 'data)
                 ;; symbol-headed data that is not just atoms (quasiquoted
                 ;; builder trees, alists of forms) hangs like a call
                 (if (and (pair? items)
                          (symbol-node? (car items))
                          (not (every? (lambda (k)
                                         (memq (cst-kind k) '(atom dot)))
                                       items)))
                     (vector 'call 0 (const-ctx 'data) #f #t)
                     (vector 'data 0 (const-ctx 'data) #f #t)))
                ((eq? ctx 'bindings)
                 ;; one binding per line once a value is a call
                 (vector 'data
                         0
                         (const-ctx 'plain)
                         (and (>= n 2)
                              (any? (lambda (b)
                                      (and
                                       (eq? (cst-kind b) 'list)
                                       (let ((bi (code-items b)))
                                         (and
                                          (pair? bi)
                                          (pair? (cdr bi))
                                          (eq? (cst-kind (cadr bi)) 'list)))))
                                    items))
                         #f))
                ((or (= n 0) (not (symbol-node? (car items))))
                 (vector 'data 0 (const-ctx 'code) #f #f))
                ((eq? ctx 'plain) (vector 'call 0 (const-ctx 'code) #f #t))
                ((eq? ctx 'clauses)
                 (vector 'call 0 (const-ctx 'plain) (>= n 3) #f))
                (else (form-info (symbol-name (car items)) items user))))))

    (define (form-info name items user)
      (let* ((r (indent-rule name user))
             (rule (car r))
             (known? (cdr r))
             (nargs (- (length items) 1))
             (arg1 (and (>= nargs 1) (cadr items))))
        (define (body n argctx)
          (vector 'body n argctx (and known? (> (- nargs n) 1)) #f))
        (cond ((number? rule) (body rule (const-ctx 'code)))
              (else (case rule
                      ((define)
                       (body 1
                             (lambda (i node)
                               (if (and (= i 0) (eq? (cst-kind node) 'list))
                                   'plain
                                   'code))))
                      ((lambda)
                       (body 1 (lambda (i node) (if (= i 0) 'plain 'code))))
                      ((let)
                       (if (and arg1 (symbol-node? arg1))
                           (body 2
                                 (lambda (i node)
                                   (if (= i 1) 'bindings 'code)))
                           (body 1
                                 (lambda (i node)
                                   (if (= i 0) 'bindings 'code)))))
                      ((do)
                       (body 2
                             (lambda (i node)
                               (cond ((= i 0) 'bindings)
                                     ((= i 1) 'plain)
                                     (else 'code)))))
                      ((receive)
                       (body 2 (lambda (i node) (if (= i 0) 'plain 'code))))
                      ((cond)
                       (vector 'call 0 (const-ctx 'plain) (>= nargs 2) #f))
                      ((case)
                       (body 1 (lambda (i node) (if (= i 0) 'code 'plain))))
                      ((clauses) (body 0 (const-ctx 'plain)))
                      ((guard)
                       (body 1 (lambda (i node) (if (= i 0) 'clauses 'code))))
                      ((rules) (body 1 (const-ctx 'data)))
                      ((import)
                       (vector 'call 0 (const-ctx 'data) (>= nargs 2) #f))
                      (else (vector 'call
                                    0
                                    (const-ctx 'code)
                                    #f
                                    (not (string=? name "if")))))))))

    (define (info-style i) (vector-ref i 0))
    (define (info-n i) (vector-ref i 1))
    (define (info-argctx i) (vector-ref i 2))
    (define (info-force? i) (vector-ref i 3))
    (define (info-fill? i) (vector-ref i 4))

    (define (operand-ctx node ctx)
      (if (eq? (cst-kind node) 'prefix)
          (let ((t (cst-text node)))
            (if (member t '("," ",@" "#," "#,@")) 'code 'data))
          ctx))

    ;; ---- layout ----------------------------------------------------

    (define (layout root opts)
      (let* ((width (opt opts 'width))
             (keep? (opt opts 'keep-breaks))
             (keep-brackets? (opt opts 'keep-brackets))
             (list-info (make-list-info (opt opts 'indent)))
             (out (open-output-string))
             (col 0)
             (pending #f)
             (pend-indent #f)
             (comment-line? #f)
             (started? #f)
             (flat-memo (make-hash-table eq?))
             (nl-memo (make-hash-table eq?)))

        ;; -- printer --
        (define (emit! s)
          (when pend-indent
            (write-string (make-string pend-indent #\space) out)
            (set! col pend-indent)
            (set! pend-indent #f))
          (write-string s out)
          (set! started? #t)
          (let ((k (last-newline s)))
            (if k
                (set! col (- (string-length s) k 1))
                (set! col (+ col (string-length s))))))
        (define (cur-col) (or pend-indent col))
        (define (newline! indent)
          (when pending
            (write-string " " out)
            (write-string pending out)
            (set! pending #f))
          (write-string "\n" out)
          (set! col 0)
          (set! pend-indent indent)
          (set! comment-line? #f))
        (define (blocked?) (or pending comment-line?))
        ;; Before an element that goes on the current line.
        (define (sep! indent space?)
          (cond ((blocked?) (newline! indent))
                (pend-indent #t)
                ((and (= col 0) started?) (set! pend-indent indent))
                (space? (emit! " "))
                (else #t)))
        ;; Before an element that goes on a new line.
        (define (break! indent blank?)
          (when blank? (newline! #f))
          (newline! indent))
        (define (trailing! text)
          (when pending (newline! (cur-col)))
          (set! pending (rstrip text)))
        (define (own-comment! text)
          (emit! (rstrip text))
          (set! comment-line? #t))
        (define (fits? c s tail) (<= (+ c (string-length s) tail) width))

        ;; -- measuring --
        (define (open-text node)
          (let ((t (cst-text node)))
            (if (and (string=? t "[") (not keep-brackets?)) "(" t)))
        (define (close-text node)
          (let ((t (cdr (cst-close node))))
            (if (and (string=? t "]") (not keep-brackets?)) ")" t)))

        (define (flat node ctx)
          (case (cst-kind node)
            ((atom)
             (let ((t (cst-text node))) (if (string-has-newline? t) #f t)))
            ((dot) ".")
            ((comment directive) #f)
            ((block-comment)
             (let ((t (cst-text node))) (if (string-has-newline? t) #f t)))
            ((prefix label datum-comment)
             (let ((kids (cst-children node)))
               (and (= (length kids) 1)
                    (let ((f (flat (car kids) (operand-ctx node ctx))))
                      (and f (string-append (cst-text node) f))))))
            (else (let ((m (hash-table-ref/default flat-memo node 'none)))
                    (if (not (eq? m 'none))
                        m
                        (let ((f (flat-container node ctx)))
                          (hash-table-set! flat-memo node f)
                          f))))))

        (define (flat-container node ctx)
          (let ((kids (cst-children node)))
            (and (not (any? (lambda (k)
                              (memq (cst-kind k) '(comment directive)))
                            kids))
                 (let ((info (list-info node ctx)))
                   (and (or keep? (not (info-force? info)))
                        (let loop ((ks kids)
                                   (i (start-index info))
                                   (acc '()))
                          (if (null? ks)
                              (string-append (open-text node)
                                             (join (reverse acc))
                                             (close-text node))
                              (let* ((k (car ks))
                                     (code?
                                      (not (eq? (cst-kind k) 'datum-comment)))
                                     (f (flat k (child-ctx info i k ctx))))
                                (and f
                                     (loop (cdr ks)
                                           (if code? (+ i 1) i)
                                           (cons f acc)))))))))))

        ;; Index of the first code item for argctx: the head is -1 for
        ;; call and body styles.
        (define (start-index info) (if (eq? (info-style info) 'data) 0 -1))
        (define (child-ctx info i node ctx)
          (cond ((< i 0) 'code)
                (else ((info-argctx info) i node))))

        (define (has-newlines? node)
          (and (memq (cst-kind node)
                     '(list vector bytevector prefix label datum-comment))
               (let ((m (hash-table-ref/default nl-memo node 'none)))
                 (if (not (eq? m 'none))
                     m
                     (let
                         ((r (or (any? (lambda (k)
                                         (or
                                          (> (cst-newlines-before k) 0)
                                          (comment-kind? k)
                                          (has-newlines? k)
                                          (and
                                           (eq? (cst-kind k) 'atom)
                                           (string-has-newline?
                                            (cst-text k)))))
                                       (cst-children node))
                                 (and (cst-close node)
                                      (pair? (cst-close node))
                                      (string-has-newline?
                                       (car (cst-close node)))))))
                       (hash-table-set! nl-memo node r)
                       r)))))

        ;; -- rendering --
        (define (render node ctx tail)
          (case (cst-kind node)
            ((atom dot block-comment) (emit! (cst-text node)))
            ((comment) (own-comment! (cst-text node)))
            ((directive) (own-comment! (cst-text node)))
            ((prefix label datum-comment) (render-operand node ctx tail))
            (else (render-container node ctx tail))))

        (define (render-operand node ctx tail)
          (emit! (cst-text node))
          (let ((c (cur-col))
                (kids (cst-children node)))
            (let loop ((ks kids) (first? #t))
              (unless (null? ks)
                (let ((k (car ks)))
                  (cond ((eq? (cst-kind k) 'comment)
                         (if (and (cst-trailing-comment? k) (not pending))
                             (trailing! (cst-text k))
                             (begin
                               (newline! c)
                               (own-comment! (cst-text k)))))
                        (else (unless first? (sep! c #f))
                              (render k
                                      (operand-ctx node ctx)
                                      (if (null? (cdr ks)) tail 0))))
                  (loop (cdr ks) #f))))))

        (define (render-container node ctx tail)
          (let ((c (cur-col))
                (f (flat node ctx)))
            (cond ((and f
                        (fits? c f tail)
                        (not (and keep? (has-newlines? node))))
                   (emit! f))
                  ((and keep? (has-newlines? node))
                   (layout-list node ctx tail c #t))
                  (else (layout-list node ctx tail c #f)))))

        ;; Lays out a list that does not go on one line. orig? = keep the
        ;; original line breaks of this list's elements.
        (define (layout-list node ctx tail c orig?)
          (let* ((info (list-info node ctx))
                 (style (info-style info))
                 (open (open-text node))
                 (kids (cst-children node))
                 (items (code-items node))
                 (last-item (and (pair? items)
                                 (list-ref items (- (length items) 1))))
                 (head (and (pair? items)
                            (not (eq? style 'data))
                            (car items)))
                 (head-flat (and head (flat head 'code)))
                 (n-dist (info-n info))
                 (fill? (and (info-fill? info)
                             (not (any? comment-kind? kids))
                             (every? (lambda (k)
                                       (memq (cst-kind k) '(atom dot)))
                                     (if head (cdr items) items))))
                 ;; hang: first argument on the operator's line
                 (hang-col (and head-flat
                                (+ c
                                   (string-length open)
                                   (string-length head-flat)
                                   1)))
                 (args (if head (cdr items) items))
                 (hang? (and (eq? style 'call)
                             head-flat
                             (pair? args)
                             (let ((first-arg-kid (next-kid-after kids head)))
                               (and first-arg-kid
                                    (not (comment-kind? first-arg-kid))
                                    ;; an atom first argument must fit there
                                    (or
                                     (not
                                      (memq (cst-kind first-arg-kid)
                                            '(atom dot)))
                                     (string-has-newline?
                                      (cst-text first-arg-kid))
                                     (fits?
                                      hang-col
                                      (cst-text first-arg-kid)
                                      (if (null? (cdr args)) (+ tail 1) 0)))
                                    (if
                                     orig?
                                     (= (cst-newlines-before first-arg-kid) 0)
                                     (or
                                      fill?
                                      (<= hang-col (quotient width 2))
                                      (let loop ((as args) (i 0))
                                        (or
                                         (null? as)
                                         (let
                                             ((f
                                               (flat
                                                (car as)
                                                (child-ctx info i
                                                           (car as)
                                                           ctx))))
                                           (and
                                            f
                                            (fits?
                                             hang-col
                                             f
                                             (if (null? (cdr as))
                                                 (+ tail 1)
                                                 0))
                                            (loop (cdr as) (+ i 1))))))))))))
                 (dist-broken? #f)
                 (atom-run? #t))
            (emit! open)
            (let loop ((ks kids)
                       (i (start-index info))
                       (first? #t))
              (unless (null? ks)
                (let* ((k (car ks))
                       (kind (cst-kind k))
                       (code? (not (memq
                                    kind
                                    '(comment block-comment directive
                                      datum-comment))))
                       ;; the index the next code item will have
                       (ci i)
                       (indent (case style
                                 ((data) (+ c (string-length open)))
                                 ((call)
                                  (if (and hang? (>= ci 0)) hang-col (+ c 1)))
                                 (else (cond ((< ci 0) (+ c 1))
                                             ((< ci n-dist) (+ c 4))
                                             (else (+ c 2))))))
                       (blank? (>= (cst-newlines-before k) 2))
                       (k-tail (if (eq? k last-item) (+ tail 1) 0)))
                  (cond ((eq? kind 'comment)
                         ;; an end-of-line comment stays at the end of the line
                         ;; it was on (after the opening delimiter if first)
                         (if (and (cst-trailing-comment? k) (not pending))
                             (trailing! (cst-text k))
                             (begin
                               (break! indent (and blank? (not first?)))
                               (own-comment! (cst-text k)))))
                        ((eq? kind 'directive)
                         (unless first? (break! indent blank?))
                         (own-comment! (cst-text k)))
                        (else (let ((place
                                     (cond
                                      (first? 'first)
                                      (orig?
                                       (if
                                        (> (cst-newlines-before k) 0)
                                        'new
                                        (let
                                            ((f
                                              (flat
                                               k
                                               (child-ctx info ci k ctx))))
                                          (if
                                           (or
                                            (not f)
                                            (fits? (+ (cur-col) 1) f k-tail)
                                            (not (memq kind '(atom dot))))
                                           'same
                                           'new))))
                                      (else
                                       (case style
                                         ((data)
                                          (if
                                           fill?
                                           (fill-place k ci info ctx k-tail)
                                           'new))
                                         ((call)
                                          (cond
                                           ((< ci 0) 'same)
                                           ((and hang? (= ci 0))
                                            (unless (memq kind '(atom dot))
                                              (set! atom-run? #f))
                                            'same)
                                           (fill?
                                            (fill-place k ci info ctx k-tail))
                                           ;; leading atom arguments share the
                                           ;; operator's line while they fit
                                           ((and
                                             hang?
                                             atom-run?
                                             (info-fill? info)
                                             (memq kind '(atom dot))
                                             (eq?
                                              (fill-place k ci info ctx
                                                          k-tail)
                                              'same))
                                            'same)
                                           (else (set! atom-run? #f) 'new)))
                                         (else
                                          (cond
                                           ((< ci 0) 'same)
                                           ((< ci n-dist)
                                            (if
                                             (and
                                              (not dist-broken?)
                                              (let
                                                  ((f
                                                    (flat
                                                     k
                                                     (child-ctx info ci k
                                                                ctx))))
                                                (or
                                                 (and
                                                  f
                                                  (fits? (+ (cur-col) 1)
                                                         f
                                                         k-tail))
                                                 (and
                                                  (not f)
                                                  (memq
                                                   kind
                                                   '(list vector bytevector
                                                     prefix label))
                                                  (<= (+ (cur-col) 1)
                                                      (quotient width 2))))))
                                             'same
                                             (begin
                                               (set! dist-broken? #t)
                                               'new)))
                                           (else 'new))))))))
                                (case place
                                  ((first) (sep! indent #f))
                                  ((same) (sep! indent #t))
                                  (else
                                   (break! indent (and blank? (not first?)))))
                                (if (eq? kind 'datum-comment)
                                    (render k ctx 0)
                                    (render k
                                            (child-ctx info ci k ctx)
                                            k-tail)))))
                  (loop (cdr ks) (if code? (+ i 1) i) #f))))
            ;; closing delimiter
            (let ((close-indent (case style
                                  ((data) (+ c (string-length open)))
                                  ((call) (if hang? hang-col (+ c 1)))
                                  (else (+ c 2)))))
              (when comment-line? (newline! close-indent))
              (emit! (close-text node)))))

        (define (fill-place k ci info ctx k-tail)
          (let ((f (flat k (child-ctx info ci k ctx))))
            (if (and f (fits? (+ (cur-col) 1) f k-tail)) 'same 'new)))

        ;; -- top level --
        (let loop ((ks (cst-children root))
                   (first? #t))
          (unless (null? ks)
            (let ((k (car ks)))
              (cond ((and (eq? (cst-kind k) 'comment)
                          (not first?)
                          (= (cst-newlines-before k) 0)
                          (not pending))
                     (trailing! (cst-text k)))
                    (else (unless first?
                            (if (and keep?
                                     (= (cst-newlines-before k) 0)
                                     (not (blocked?)))
                                (sep! 0 #t)
                                (break! 0 (>= (cst-newlines-before k) 2))))
                          (render k 'code 0)))
              (loop (cdr ks) #f))))
        (when pending
          (write-string " " out)
          (write-string pending out))
        (when started? (unless (= col 0) (write-string "\n" out)))
        (get-output-string out)))

    (define (next-kid-after kids node)
      (let loop ((ks kids))
        (cond ((null? ks) #f)
              ((eq? (car ks) node) (and (pair? (cdr ks)) (cadr ks)))
              (else (loop (cdr ks))))))

    ;; ---- import / export sorting -----------------------------------

    (define (lib-name-of-set d)
      ;; the library name inside an import set datum
      (cond ((and (pair? d)
                  (memq (car d) '(only except prefix rename))
                  (pair? (cdr d)))
             (lib-name-of-set (cadr d)))
            (else d)))

    (define (import-group name)
      (if (and (pair? name) (symbol? (car name)))
          (case (car name)
            ((scheme) 0)
            ((srfi) 1)
            ((scm) 2)
            (else 3))
          3))

    (define (name-part<? a b)
      (cond ((and (number? a) (number? b)) (< a b))
            ((number? a) #t)
            ((number? b) #f)
            (else (string<? (part->string a) (part->string b)))))

    (define (part->string p)
      (cond ((symbol? p) (symbol->string p))
            ((number? p) (number->string p))
            (else (let ((o (open-output-string)))
                    (write p o)
                    (get-output-string o)))))

    (define (lib-name<? a b)
      (let ((ga (import-group a))
            (gb (import-group b)))
        (cond ((< ga gb) #t)
              ((> ga gb) #f)
              (else (let loop ((a (if (list? a) a (list a)))
                               (b (if (list? b) b (list b))))
                      (cond ((null? a) (pair? b))
                            ((null? b) #f)
                            ((name-part<? (car a) (car b)) #t)
                            ((name-part<? (car b) (car a)) #f)
                            (else (loop (cdr a) (cdr b)))))))))

    (define (import-key node) (lib-name-of-set (cst->datum node)))

    (define (export-key node)
      (let ((d (cst->datum node)))
        (cond ((symbol? d) (symbol->string d))
              ((and (pair? d)
                    (eq? (car d) 'rename)
                    (= (length d) 3)
                    (symbol? (caddr d)))
               (symbol->string (caddr d)))
              (else (part->string d)))))

    ;; Stable insertion sort on (key . item) pairs.
    (define (sort-items items key less?)
      (let ((keyed (map (lambda (it) (cons (key (car it)) it)) items)))
        (map cdr
             (let loop ((ks keyed) (acc '()))
               (if (null? ks)
                   acc
                   (loop (cdr ks)
                         (let ins ((acc acc))
                           (cond ((null? acc) (list (car ks)))
                                 ((less? (caar ks) (caar acc))
                                  (cons (car ks) acc))
                                 (else (cons (car acc)
                                             (ins (cdr acc))))))))))))

    ;; Sorts the entries after the head of an import/export clause.
    ;; Own-line comments split the entries into groups sorted separately;
    ;; end-of-line comments move with the entry before them.
    (define (sort-clause node key less?)
      (let* ((kids (cst-children node))
             (head (car kids)))
        (let loop ((ks (cdr kids))
                   (group '())
                   (out '()))
          (define (flush)
            ;; group: reversed list of (entry trailing...) items
            (let* ((items (reverse group))
                   (sorted (sort-items items key less?))
                   (pres (map (lambda (it) (cst-pre (car it))) items)))
              (append out
                      (apply append
                             (map (lambda (it pre)
                                    (cons (with-pre (car it) pre) (cdr it)))
                                  sorted
                                  pres)))))
          (cond ((null? ks)
                 (comments-end-lines (with-children node
                                       (cons head (flush)))))
                ((and (eq? (cst-kind (car ks)) 'comment)
                      (cst-trailing-comment? (car ks))
                      (pair? group))
                 (loop (cdr ks)
                       (cons (append (car group) (list (car ks))) (cdr group))
                       out))
                ((memq (cst-kind (car ks))
                       '(comment block-comment directive datum-comment))
                 (loop (cdr ks) '() (append (flush) (list (car ks)))))
                (else (loop (cdr ks) (cons (list (car ks)) group) out))))))

    ;; After reordering, an end-of-line comment may be followed by an
    ;; entry or the closing delimiter that was on the same line; give them
    ;; a line of their own so the comment does not swallow them.
    (define (comments-end-lines node)
      (let loop ((ks (cst-children node))
                 (prev #f)
                 (acc '()))
        (if (null? ks)
            (let ((close (cst-close node))
                  (kids (reverse acc)))
              (make-cst-node (cst-kind node)
                             (cst-text node)
                             (cst-line node)
                             (cst-col node)
                             (cst-pre node)
                             kids
                             (if (and prev
                                      (eq? (cst-kind prev) 'comment)
                                      (not (string-has-newline? (car close))))
                                 (cons (string-append "\n" (car close))
                                       (cdr close))
                                 close)))
            (let* ((k (car ks))
                   (k (if (and prev
                               (eq? (cst-kind prev) 'comment)
                               (not (string-has-newline? (cst-pre k))))
                          (with-pre k (string-append "\n" (cst-pre k)))
                          k)))
              (loop (cdr ks) k (cons k acc))))))

    ;; -- import conflict check --

    (define (datum->string d)
      (let ((o (open-output-string)))
        (write d o)
        (get-output-string o)))

    ;; Returns #t if reordering the import sets cannot change what a name
    ;; means, else a string saying why it might.
    (define (imports-reorderable? set-datums cache)
      (let ((seen (make-hash-table eq?)))
        (let loop ((ds set-datums))
          (if (null? ds)
              #t
              (let ((bs (import-set-bindings (car ds) cache)))
                (if (not bs)
                    (string-append "the exports of "
                                   (datum->string (car ds))
                                   " are unknown")
                    (let scan ((bs bs))
                      (if (null? bs)
                          (loop (cdr ds))
                          (let* ((b (car bs))
                                 (prev (hash-table-ref/default
                                        seen
                                        (import-binding-name b)
                                        #f)))
                            (cond ((not prev)
                                   (hash-table-set! seen
                                                    (import-binding-name b)
                                                    b)
                                   (scan (cdr bs)))
                                  ((same-import-binding? prev b)
                                   (scan (cdr bs)))
                                  (else
                                   (string-append
                                    (symbol->string (import-binding-name b))
                                    " comes from both "
                                    (datum->string
                                     (import-binding-library prev))
                                    " and "
                                    (datum->string
                                     (import-binding-library b))))))))))))))

    (define (sort-imports-node node opts notes cache)
      (let* ((sets (cdr (code-items node)))
             (datums (map cst->datum sets)))
        (if (< (length sets) 2)
            node
            (let ((ok (imports-reorderable? datums cache)))
              (if (eq? ok #t)
                  (sort-clause node import-key lib-name<?)
                  (begin
                    (set-car! notes
                              (cons (list
                                     (cst-line node)
                                     (cst-col node)
                                     (string-append "imports not sorted: "
                                                    ok))
                                    (car notes)))
                    node))))))

    (define (sort-exports-node node)
      (if (< (length (code-items node)) 3)
          node
          (sort-clause node export-key string<?)))

    (define (sort-declarations root opts notes file)
      (let ((imports? (opt opts 'sort-imports))
            (exports? (opt opts 'sort-exports))
            (cache (make-import-cache (append
                                       (opt opts 'library-path)
                                       ;; sibling libraries of the file
                                       (if
                                        (file-exists? file)
                                        (list
                                         (directory-name
                                          (absolute-path file)))
                                        '())))))
        (define (fix-clause cl)
          (let ((h (node-head-name cl)))
            (cond ((and imports? (equal? h "import"))
                   (sort-imports-node cl opts notes cache))
                  ((and exports? (equal? h "export")) (sort-exports-node cl))
                  (else cl))))
        (with-children root
          (map (lambda (top)
                 (let ((h (node-head-name top)))
                   (cond ((equal? h "define-library")
                          (with-children top
                            (map (lambda (k)
                                   (if (eq? (cst-kind k) 'list)
                                       (fix-clause k)
                                       k))
                                 (cst-children top))))
                         ((and imports? (equal? h "import"))
                          (sort-imports-node top opts notes cache))
                         (else top))))
               (cst-children root)))))

    (define (sort-source-declarations cst opts file)
      "Syntax: (sort-source-declarations cst options file)
Library: (scm source format)
Description: Returns a copy of the CST file node cst with the import and
  export lists of its define-library forms and top-level imports sorted
  the way scm fmt sorts them (see format-source-string for options;
  sort-imports and sort-exports are honoured). Imports whose order could
  matter are left alone. Returns two values: the new node and a list of
  notes (line col message) about import lists left unsorted. file names
  the source, for finding sibling libraries.
Example:
  (sort-source-declarations (source-read-string \"(import (scm io) (scheme base))\")
                            '() \"<string>\")"
      (let* ((notes (list '()))
             (sorted (sort-declarations cst opts notes file)))
        (values sorted (reverse (car notes)))))

    ;; ---- entry points ----------------------------------------------

    (define (format-source-string str . maybe-opts)
      "Syntax: (format-source-string str [options])
Library: (scm source format)
Description: Formats the Scheme source text str and returns the new text.
  options is an alist (see format-options; missing keys take the
  defaults): width, keep-breaks, sort-imports, sort-exports,
  keep-brackets, indent and library-path. indent adds or overrides
  indentation rules: an alist of form name (string) to a number N (a body
  form with N distinguished arguments, like Emacs scheme-indent-function)
  or a symbol naming a built-in rule: define, lambda, let, do, receive,
  cond, case, clauses, guard, rules, import or call.
  Raises an error with the position when str cannot be read, and an
  error starting \"internal formatter error\" when the result would not
  read back to the same datums or would change when formatted again.
Example:
  (format-source-string \"(define (f x)\\n(if x\\n1 2))\")
    => \"(define (f x) (if x 1 2))\\n\""
      (car (format-with-notes str
                              (if (pair? maybe-opts) (car maybe-opts) '())
                              "<string>")))

    ;; -> (text . notes)
    (define (format-with-notes str opts file)
      (let* ((cst (source-read-string str file))
             (notes (list '()))
             (sorted (if (or (opt opts 'sort-imports)
                             (opt opts 'sort-exports))
                         (sort-declarations cst opts notes file)
                         cst))
             (text (layout sorted opts)))
        (unless (opt opts 'unchecked) (verify-format sorted text opts file))
        (cons text (reverse (car notes)))))

    ;; The safety net: same datums, and stable under a second run.
    (define (verify-format sorted text opts file)
      (let ((expected (cst->datum sorted))
            (got (guard (e (#t 'unreadable))
                   (cst->datum (source-read-string text file)))))
        (unless (datum-equal? expected got)
          (error
           "internal formatter error: the formatted text reads differently"
           file)))
      (let ((again (layout (source-read-string text file) opts)))
        (unless (string=? again text)
          (error "internal formatter error: formatting is not stable" file))))

    (define (format-file! path . maybe-opts)
      "Syntax: (format-file! path [options])
Library: (scm source format)
Description: Formats the file at path in place (see format-source-string
  for options; by default format-options of path) and returns #t if its
  text changed, #f if it was already formatted. The file is only written
  when the text changes.
Example:
  (format-file! \"src/app.sld\") => #t"
      (let* ((opts (if (pair? maybe-opts)
                       (car maybe-opts)
                       (format-options path)))
             (old (read-file-string path))
             (new (car (format-with-notes old opts path))))
        (if (string=? old new)
            #f
            (begin
              (write-text-file path new)
              #t))))

    (define (write-text-file path text)
      (call-with-output-file path (lambda (p) (write-string text p))))

    ;; ---- diff ------------------------------------------------------

    (define (split-lines s)
      (let loop ((k 0) (start 0) (acc '()))
        (cond ((= k (string-length s))
               (reverse (if (< start k)
                            (cons (substring s start k) acc)
                            acc)))
              ((char=? (string-ref s k) #\newline)
               (loop (+ k 1) (+ k 1) (cons (substring s start k) acc)))
              (else (loop (+ k 1) start acc)))))

    (define (source-diff old new name)
      "Syntax: (source-diff old new name)
Library: (scm source format)
Description: Returns a unified diff (3 lines of context) from the text
  old to the text new, with name in the --- / +++ header lines, or \"\"
  if the texts are equal.
Example:
  (source-diff \"a\\nb\\n\" \"a\\nc\\n\" \"x.scm\")
    => \"--- x.scm\\n+++ x.scm (formatted)\\n@@ -1,2 +1,2 @@\\n a\\n-b\\n+c\\n\""
      (if (string=? old new)
          ""
          (let* ((a (list->vector (split-lines old)))
                 (b (list->vector (split-lines new)))
                 (ops (diff-ops a b))
                 (out (open-output-string)))
            (write-string (string-append "--- " name "\n+++ " name
                                         " (formatted)\n")
                          out)
            (write-hunks ops a b out)
            (get-output-string out))))

    ;; Edit script as a list of (op ai bi) with op = / - +, ai bi line
    ;; indexes: patience diff (lines unique to both sides anchor the
    ;; alignment), an LCS table for small gaps, a plain replacement for
    ;; large gaps without anchors.
    (define (diff-ops a b)
      (diff-range a b 0 (vector-length a) 0 (vector-length b)))

    (define (ops-equal a0 b0 n)
      (let loop ((k (- n 1))
                 (acc '()))
        (if (< k 0)
            acc
            (loop (- k 1) (cons (list '= (+ a0 k) (+ b0 k)) acc)))))

    (define (ops-replace a0 a1 b0 b1)
      (append (let loop ((k (- a1 1))
                         (acc '()))
                (if (< k a0) acc (loop (- k 1) (cons (list '- k #f) acc))))
              (let loop ((k (- b1 1))
                         (acc '()))
                (if (< k b0) acc (loop (- k 1) (cons (list '+ #f k) acc))))))

    (define (diff-range a b a0 a1 b0 b1)
      ;; common prefix and suffix
      (let* ((pre (let loop ((k 0))
                    (if (and (< (+ a0 k) a1)
                             (< (+ b0 k) b1)
                             (string=? (vector-ref a (+ a0 k))
                                       (vector-ref b (+ b0 k))))
                        (loop (+ k 1))
                        k)))
             (suf (let loop ((k 0))
                    (if (and (< (+ a0 pre k) a1)
                             (< (+ b0 pre k) b1)
                             (string=? (vector-ref a (- a1 k 1))
                                       (vector-ref b (- b1 k 1))))
                        (loop (+ k 1))
                        k)))
             (ma0 (+ a0 pre))
             (ma1 (- a1 suf))
             (mb0 (+ b0 pre))
             (mb1 (- b1 suf)))
        (append (ops-equal a0 b0 pre)
                (diff-middle a b ma0 ma1 mb0 mb1)
                (ops-equal ma1 mb1 suf))))

    (define (diff-middle a b a0 a1 b0 b1)
      (cond ((or (= a0 a1) (= b0 b1)) (ops-replace a0 a1 b0 b1))
            (else (let ((anchors (unique-anchors a b a0 a1 b0 b1)))
                    (if (null? anchors)
                        (if (<= (* (- a1 a0) (- b1 b0)) 4000000)
                            (lcs-ops a b a0 (- a1 a0) b0 (- b1 b0))
                            (ops-replace a0 a1 b0 b1))
                        (let loop ((as anchors) (pa a0) (pb b0) (acc '()))
                          (if (null? as)
                              (apply append
                                     (reverse
                                      (cons (diff-range a b pa a1 pb b1)
                                            acc)))
                              (let ((i (caar as))
                                    (j (cdar as)))
                                (loop (cdr as)
                                      (+ i 1)
                                      (+ j 1)
                                      (cons
                                       (list (list '= i j))
                                       (cons (diff-range a b pa i pb j)
                                             acc)))))))))))

    ;; Lines occurring exactly once in each range, as (i . j) pairs on the
    ;; longest increasing subsequence of j.
    (define (unique-anchors a b a0 a1 b0 b1)
      (let ((ca (make-hash-table string=? string-hash))
            (cb (make-hash-table string=? string-hash)))
        (do ((i a0 (+ i 1))) ((= i a1))
          (let ((l (vector-ref a i)))
            (hash-table-set! ca l
                             (if (hash-table-ref/default ca l #f) 'many i))))
        (do ((j b0 (+ j 1))) ((= j b1))
          (let ((l (vector-ref b j)))
            (hash-table-set! cb l
                             (if (hash-table-ref/default cb l #f) 'many j))))
        (let ((pairs (let loop ((i a0) (acc '()))
                       (if (= i a1)
                           (reverse acc)
                           (let* ((l (vector-ref a i))
                                  (x (hash-table-ref/default ca l #f))
                                  (y (hash-table-ref/default cb l #f)))
                             (loop (+ i 1)
                                   (if (and (number? x) (number? y))
                                       (cons (cons i y) acc)
                                       acc)))))))
          (longest-increasing pairs))))

    ;; Patience sorting on the cdrs; pairs come sorted by car.
    (define (longest-increasing pairs)
      (if (null? pairs)
          '()
          (let* ((n (length pairs))
                 (v (list->vector pairs))
                 (tails (make-vector n 0)) ; index into v of the pile tops
                 (prev (make-vector n -1))
                 (len 0))
            (do ((k 0 (+ k 1))) ((= k n))
              (let ((y (cdr (vector-ref v k))))
                ;; binary search for the first pile whose top is >= y
                (let search ((lo 0) (hi len))
                  (if (< lo hi)
                      (let ((mid (quotient (+ lo hi) 2)))
                        (if (< (cdr (vector-ref v (vector-ref tails mid))) y)
                            (search (+ mid 1) hi)
                            (search lo mid)))
                      (begin
                        (when (> lo 0)
                          (vector-set! prev k (vector-ref tails (- lo 1))))
                        (vector-set! tails lo k)
                        (when (= lo len) (set! len (+ len 1))))))))
            (let loop ((k (vector-ref tails (- len 1)))
                       (acc '()))
              (if (< k 0)
                  acc
                  (loop (vector-ref prev k) (cons (vector-ref v k) acc)))))))

    (define (lcs-ops a b a0 an b0 bm)
      (let ((t (make-vector (* (+ an 1) (+ bm 1)) 0))
            (w (+ bm 1)))
        (do ((i (- an 1) (- i 1))) ((< i 0))
          (do ((j (- bm 1) (- j 1))) ((< j 0))
            (vector-set! t
                         (+ (* i w) j)
                         (if (string=? (vector-ref a (+ a0 i))
                                       (vector-ref b (+ b0 j)))
                             (+ 1 (vector-ref t (+ (* (+ i 1) w) (+ j 1))))
                             (max (vector-ref t (+ (* (+ i 1) w) j))
                                  (vector-ref t (+ (* i w) (+ j 1))))))))
        (let loop ((i 0) (j 0) (acc '()))
          (cond ((and (= i an) (= j bm)) (reverse acc))
                ((= i an) (loop i (+ j 1) (cons (list '+ #f (+ b0 j)) acc)))
                ((= j bm) (loop (+ i 1) j (cons (list '- (+ a0 i) #f) acc)))
                ((string=? (vector-ref a (+ a0 i)) (vector-ref b (+ b0 j)))
                 (loop (+ i 1)
                       (+ j 1)
                       (cons (list '= (+ a0 i) (+ b0 j)) acc)))
                ((>= (vector-ref t (+ (* (+ i 1) w) j))
                     (vector-ref t (+ (* i w) (+ j 1))))
                 (loop (+ i 1) j (cons (list '- (+ a0 i) #f) acc)))
                (else (loop i (+ j 1) (cons (list '+ #f (+ b0 j)) acc)))))))

    (define (write-hunks ops a b out)
      (let* ((v (list->vector ops))
             (n (vector-length v))
             (ctx 3))
        (define (change? k) (not (eq? (car (vector-ref v k)) '=)))
        ;; positions of changes grouped into hunks
        (let loop ((k 0))
          (when (< k n)
            (if (not (change? k))
                (loop (+ k 1))
                (let* ((start (max 0 (- k ctx)))
                       (end (let ext ((e k) (last k))
                              (cond ((>= e n) (min n (+ last ctx 1)))
                                    ((change? e) (ext (+ e 1) e))
                                    ((> (- e last) (* 2 ctx))
                                     (min n (+ last ctx 1)))
                                    (else (ext (+ e 1) last))))))
                  (write-hunk v start end a b out)
                  (loop end)))))))

    (define (write-hunk v start end a b out)
      (let loop ((k start) (a0 #f) (b0 #f) (ac 0) (bc 0) (lines '()))
        (if (< k end)
            (let* ((op (vector-ref v k))
                   (kind (car op)))
              (case kind
                ((=)
                 (loop (+ k 1)
                       (or a0 (cadr op))
                       (or b0 (caddr op))
                       (+ ac 1)
                       (+ bc 1)
                       (cons (string-append " " (vector-ref a (cadr op)))
                             lines)))
                ((-)
                 (loop (+ k 1)
                       (or a0 (cadr op))
                       b0
                       (+ ac 1)
                       bc
                       (cons (string-append "-" (vector-ref a (cadr op)))
                             lines)))
                (else (loop (+ k 1)
                            a0
                            (or b0 (caddr op))
                            ac
                            (+ bc 1)
                            (cons (string-append "+"
                                                 (vector-ref b (caddr op)))
                                  lines)))))
            (let ((a0 (or a0 (hunk-anchor v start 'a)))
                  (b0 (or b0 (hunk-anchor v start 'b))))
              (write-string (string-append "@@ -"
                                           (range-text a0 ac)
                                           " +"
                                           (range-text b0 bc)
                                           " @@\n")
                            out)
              (for-each (lambda (l)
                          (write-string l out)
                          (newline out))
                        (reverse lines))))))

    (define (hunk-anchor v start side)
      ;; the line index before which an empty side of a hunk sits
      (let loop ((k start))
        (cond ((< k 0) 0)
              (else (let
                        ((x (if (eq? side 'a)
                                (cadr (vector-ref v k))
                                (caddr (vector-ref v k)))))
                      (if x (+ x 1) (loop (- k 1))))))))

    (define (range-text start count)
      (cond ((= count 0) (string-append (number->string start) ",0"))
            ((= count 1) (number->string (+ start 1)))
            (else (string-append (number->string (+ start 1))
                                 ","
                                 (number->string count)))))

    ;; ---- command line ----------------------------------------------

    (define fmt-usage
      "usage: scm fmt [options] PATH...
Formats Scheme source files in place. A PATH is a file, a directory
(searched for *.scm and *.sld) or - (read stdin, write stdout).

  --check          change nothing; list the files that would change and
                   exit with 1 if there are any
  --diff           change nothing; print a unified diff of the changes
  --width N        line width (default 78, or [format] width)
  --keep-breaks    keep the source's line breaks, redo the indentation
  --no-sort        do not sort imports and exports
  --no-sort-imports, --no-sort-exports
  --keep-brackets  keep [ ] instead of turning them into ( )
  --exclude GLOB   skip matching files and directories (repeatable)
  --quiet          no per-file output
  --help           this text

Settings come from the nearest scm-tools.toml ([format] table); options
given here win. Exit codes: 0 ok, 1 files would change (--check) or a
file could not be read, 2 usage error, 3 internal formatter error.
")

    (define (fmt-command args)
      "Syntax: (fmt-command args)
Library: (scm source format)
Description: Runs `scm fmt` with the list of argument strings args (the
  command line after \"fmt\") and returns the exit code. See `scm fmt
  --help` for the options.
Example:
  (fmt-command '(\"--check\" \"src\")) => 0"
      (let loop
          ((as args)
           (over '())
           (paths '())
           (mode 'write)
           (excludes '())
           (quiet? #f))
        (define (usage-error msg)
          (write-string (string-append "scm fmt: " msg "\n")
                        (current-error-port))
          (write-string fmt-usage (current-error-port))
          2)
        (cond ((null? as)
               (if (null? paths)
                   (usage-error "no PATH given")
                   (run-fmt (reverse paths) over mode excludes quiet?)))
              (else (let ((a (car as)))
                      (cond ((member a '("--help" "-h"))
                             (write-string fmt-usage)
                             0)
                            ((string=? a "--check")
                             (loop (cdr as)
                                   over
                                   paths
                                   'check
                                   excludes
                                   quiet?))
                            ((string=? a "--diff")
                             (loop (cdr as) over paths 'diff excludes quiet?))
                            ((string=? a "--quiet")
                             (loop (cdr as) over paths mode excludes #t))
                            ((string=? a "--keep-breaks")
                             (loop (cdr as)
                                   (cons '(keep-breaks . #t) over)
                                   paths
                                   mode
                                   excludes
                                   quiet?))
                            ((string=? a "--keep-brackets")
                             (loop (cdr as)
                                   (cons '(keep-brackets . #t) over)
                                   paths
                                   mode
                                   excludes
                                   quiet?))
                            ((string=? a "--no-sort")
                             (loop (cdr as)
                                   (cons* '(sort-imports . #f)
                                          '(sort-exports . #f)
                                          over)
                                   paths
                                   mode
                                   excludes
                                   quiet?))
                            ((string=? a "--no-sort-imports")
                             (loop (cdr as)
                                   (cons '(sort-imports . #f) over)
                                   paths
                                   mode
                                   excludes
                                   quiet?))
                            ((string=? a "--no-sort-exports")
                             (loop (cdr as)
                                   (cons '(sort-exports . #f) over)
                                   paths
                                   mode
                                   excludes
                                   quiet?))
                            ((string=? a "--width")
                             (let
                                 ((n (and (pair? (cdr as))
                                          (string->number (cadr as)))))
                               (if (and n (exact-integer? n) (> n 10))
                                   (loop (cddr as)
                                         (cons (cons 'width n) over)
                                         paths
                                         mode
                                         excludes
                                         quiet?)
                                   (usage-error
                                    "--width needs a number above 10"))))
                            ((string=? a "--exclude")
                             (if (pair? (cdr as))
                                 (loop (cddr as)
                                       over
                                       paths
                                       mode
                                       (cons (cadr as) excludes)
                                       quiet?)
                                 (usage-error "--exclude needs a pattern")))
                            ((and (> (string-length a) 1)
                                  (char=? (string-ref a 0) #\-))
                             (usage-error
                              (string-append "unknown option " a)))
                            (else (loop (cdr as)
                                        over
                                        (cons a paths)
                                        mode
                                        excludes
                                        quiet?))))))))

    (define (cons* a b rest) (cons a (cons b rest)))

    (define (read-all-input port)
      (let ((out (open-output-string)))
        (let loop ()
          (let ((s (read-string 65536 port)))
            (unless (eof-object? s)
              (write-string s out)
              (loop))))
        (get-output-string out)))

    (define (report-error file e)
      (let ((pos (source-read-error-position e))
            (err (current-error-port)))
        (if pos
            (write-string (string-append (car pos)
                                         ":"
                                         (number->string (cadr pos))
                                         ":"
                                         (number->string (caddr pos))
                                         ": "
                                         (error-object-message e)
                                         "\n")
                          err)
            (write-string (string-append
                           file
                           ": "
                           (if (error-object? e)
                               (error-object-message e)
                               "error")
                           "\n")
                          err))))

    (define (internal-error? e)
      (and (error-object? e)
           (string-prefix? "internal formatter error"
                           (error-object-message e))))

    (define (run-fmt paths over mode excludes quiet?)
      (let ((changed 0) (failed 0) (internal 0) (total 0))
        (define (do-text text file opts)
          ;; -> formatted text, or #f after reporting an error
          (guard
              (e (#t
                  (if (internal-error? e)
                      (set! internal (+ internal 1))
                      (set! failed (+ failed 1)))
                  (report-error file e)
                  #f))
            (let ((r (format-with-notes text opts file)))
              (unless quiet?
                (for-each (lambda (n)
                            (write-string
                             (string-append file ":"
                                            (number->string (car n))
                                            ":"
                                            (number->string (cadr n))
                                            ": note: "
                                            (caddr n)
                                            "\n")
                             (current-error-port)))
                          (cdr r)))
              (car r))))
        (for-each (lambda (path)
                    (if (string=? path "-")
                        (let* ((text (read-all-input (current-input-port)))
                               (new (do-text text "<stdin>"
                                             (format-options "." over))))
                          (set! total (+ total 1))
                          (when new (write-string new)))
                        (for-each (lambda (file)
                                    (unless (tools-excluded? file "format")
                                      (set! total (+ total 1))
                                      (let*
                                          ((opts (format-options file over))
                                           (old
                                            (guard
                                                (e
                                                 (#t
                                                  (set! failed (+ failed 1))
                                                  (report-error file e)
                                                  #f))
                                              (read-file-string file)))
                                           (new
                                            (and old
                                                 (do-text old file opts))))
                                        (when
                                            (and new (not (string=? old new)))
                                          (set! changed (+ changed 1))
                                          (case mode
                                            ((check)
                                             (unless quiet?
                                               (write-string
                                                (string-append file "\n"))))
                                            ((diff)
                                             (write-string
                                              (source-diff old new file)))
                                            (else
                                             (write-text-file file new)
                                             (unless quiet?
                                               (write-string
                                                (string-append "formatted "
                                                               file
                                                               "\n")))))))))
                                  (if (or (file-exists? path)
                                          (directory-exists? path))
                                      (collect-source-files (list path)
                                                            excludes)
                                      (begin
                                        (set! failed (+ failed 1))
                                        (write-string
                                         (string-append path
                                                        ": no such file or directory\n")
                                         (current-error-port))
                                        '())))))
                  paths)
        (unless (or quiet? (member "-" paths))
          (write-string (string-append (number->string total)
                                       " file(s), "
                                       (number->string changed)
                                       (case mode
                                         ((check diff) " would change")
                                         (else " reformatted"))
                                       (if
                                        (> (+ failed internal) 0)
                                        (string-append
                                         ", "
                                         (number->string (+ failed internal))
                                         " failed")
                                        "")
                                       "\n")
                        (current-error-port)))
        (cond ((> internal 0) 3)
              ((> failed 0) 1)
              ((and (memq mode '(check diff)) (> changed 0)) 1)
              (else 0))))))

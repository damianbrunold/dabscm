(define-library (scm templating)
  (import (scm core)
          (scheme base)
          (scheme cxr)
          (scheme file)
          (scheme write)
          (srfi 13)
          (scm io)
          (scm fs))
  (export template-render
          template-render-file
          make-template-engine
          template-engine-render
          template-context)
  (begin

    ;; ---------------------------------------------------------------------------
    ;; 1. Context construction
    ;; ---------------------------------------------------------------------------

    (define (template-context . pairs)
      (let loop ((ps pairs) (acc '()))
        (if (or (null? ps) (null? (cdr ps)))
            (reverse acc)
            (loop (cddr ps)
                  (cons (cons (car ps) (cadr ps)) acc)))))

    ;; ---------------------------------------------------------------------------
    ;; 2. Context lookup (dot notation, fault-tolerant)
    ;; ---------------------------------------------------------------------------

    (define (tmpl-lookup-one key obj)
      (cond
        ((string->number key)
         (let ((idx (exact (string->number key))))
           (cond
             ((vector? obj)
              (if (and (>= idx 0) (< idx (vector-length obj)))
                  (vector-ref obj idx) 'missing))
             ((pair? obj)
              (if (pair? (car obj))
                  'missing
                  (if (and (>= idx 0) (< idx (length obj)))
                      (list-ref obj idx) 'missing)))
             (else 'missing))))
        ((pair? obj)
         (let* ((sym-key (if (symbol? key) key (string->symbol key)))
                (entry (or (assoc sym-key obj)
                           (assoc key obj))))
           (if entry (cdr entry) 'missing)))
        (else 'missing)))

    (define (tmpl-lookup path ctx)
      (let loop ((parts (tmpl-split-path path)) (cur ctx))
        (if (null? parts)
            cur
            (let ((val (tmpl-lookup-one (car parts) cur)))
              (if (eq? val 'missing)
                  #f
                  (loop (cdr parts) val))))))

    (define (tmpl-value->string val)
      (cond
        ((not val) "")
        ((string? val) val)
        ((number? val) (number->string val))
        ((boolean? val) (if val "true" "false"))
        ((symbol? val) (symbol->string val))
        (else "")))

    (define (tmpl-truthy? val)
      (and val (not (null? val)) (not (equal? val ""))))

    ;; Split a path string "a.b.c" on literal dots → ("a" "b" "c")
    (define (tmpl-split-path s)
      (let loop ((chars (string->list s)) (cur '()) (acc '()))
        (cond
          ((null? chars)
           (reverse (cons (list->string (reverse cur)) acc)))
          ((char=? (car chars) #\.)
           (loop (cdr chars) '() (cons (list->string (reverse cur)) acc)))
          (else
           (loop (cdr chars) (cons (car chars) cur) acc)))))

    ;; ---------------------------------------------------------------------------
    ;; 3. Lexer
    ;; ---------------------------------------------------------------------------

    (define (tmpl-find haystack needle pos)
      (let ((nlen (string-length needle))
            (hlen (string-length haystack)))
        (let loop ((i pos))
          (cond
            ((> (+ i nlen) hlen) #f)
            ((string=? (substring haystack i (+ i nlen)) needle) i)
            (else (loop (+ i 1)))))))

    (define (tmpl-split-ws s)
      (let loop ((chars (string->list s)) (cur '()) (acc '()))
        (cond
          ((null? chars)
           (let ((part (list->string (reverse cur))))
             (reverse (if (> (string-length part) 0) (cons part acc) acc))))
          ((member (car chars) '(#\space #\tab #\newline #\return))
           (let ((part (list->string (reverse cur))))
             (loop (cdr chars) '()
                   (if (> (string-length part) 0) (cons part acc) acc))))
          (else
           (loop (cdr chars) (cons (car chars) cur) acc)))))

    (define (tmpl-strip-quotes s)
      (let ((len (string-length s)))
        (if (and (>= len 2)
                 (or (and (char=? (string-ref s 0) #\")
                          (char=? (string-ref s (- len 1)) #\"))
                     (and (char=? (string-ref s 0) #\')
                          (char=? (string-ref s (- len 1)) #\'))))
            (substring s 1 (- len 1))
            s)))

    (define (tmpl-parse-block s)
      (let ((parts (tmpl-split-ws s)))
        (cond
          ((null? parts) (error "template: empty block tag"))
          ((string=? (car parts) "for")
           (if (and (>= (length parts) 4) (string=? (caddr parts) "in"))
               (list 'block-for (cadr parts) (cadddr parts))
               (error "template: bad for syntax" s)))
          ((string=? (car parts) "endfor")  '(block-endfor))
          ((string=? (car parts) "if")
           (if (>= (length parts) 2)
               (list 'block-if (cadr parts))
               (error "template: if requires expression")))
          ((string=? (car parts) "else")   '(block-else))
          ((string=? (car parts) "endif")  '(block-endif))
          ((string=? (car parts) "include")
           (if (>= (length parts) 2)
               (list 'block-include (tmpl-strip-quotes (cadr parts)))
               (error "template: include requires filename")))
          (else (error "template: unknown tag" (car parts))))))

    (define (tmpl-lex str)
      (let ((len (string-length str)))
        (let loop ((pos 0) (acc '()))
          (let ((epos (tmpl-find str "{{" pos))
                (bpos (tmpl-find str "{%" pos)))
            (define (add-text end toks)
              (if (< pos end)
                  (cons (list 'text (substring str pos end)) toks)
                  toks))
            (cond
              ((and (not epos) (not bpos))
               (reverse (add-text len acc)))
              ((and epos (or (not bpos) (< epos bpos)))
               (let ((close (tmpl-find str "}}" (+ epos 2))))
                 (if (not close)
                     (error "template: unclosed {{")
                     (let* ((expr (string-trim-both
                                    (substring str (+ epos 2) close)))
                            (new-acc (cons (list 'expr expr)
                                           (add-text epos acc))))
                       (loop (+ close 2) new-acc)))))
              (else
               (let ((close (tmpl-find str "%}" (+ bpos 2))))
                 (if (not close)
                     (error "template: unclosed {%")
                     (let* ((block-str (string-trim-both
                                         (substring str (+ bpos 2) close)))
                            (block-tok (tmpl-parse-block block-str))
                            (new-acc (cons block-tok (add-text bpos acc))))
                       (loop (+ close 2) new-acc))))))))))

    ;; ---------------------------------------------------------------------------
    ;; 4. Parser — flat tokens → AST
    ;; ---------------------------------------------------------------------------

    (define (tmpl-parse-level tokens)
      (let loop ((toks tokens) (acc '()))
        (if (null? toks)
            (cons (reverse acc) '())
            (let ((tok (car toks)))
              (case (car tok)
                ((block-endfor block-else block-endif)
                 (cons (reverse acc) toks))
                ((block-for)
                 (let* ((var-name (cadr tok))
                        (expr     (caddr tok))
                        (body+rest (tmpl-parse-level (cdr toks)))
                        (body      (car body+rest))
                        (rest      (cdr body+rest)))
                   (if (or (null? rest) (not (eq? (caar rest) 'block-endfor)))
                       (error "template: missing endfor")
                       (loop (cdr rest)
                             (cons (list 'for var-name expr body) acc)))))
                ((block-if)
                 (let* ((expr      (cadr tok))
                        (then+rest (tmpl-parse-level (cdr toks)))
                        (then-body (car then+rest))
                        (rest1     (cdr then+rest)))
                   (cond
                     ((null? rest1) (error "template: missing endif"))
                     ((eq? (caar rest1) 'block-endif)
                      (loop (cdr rest1)
                            (cons (list 'if expr then-body '()) acc)))
                     ((eq? (caar rest1) 'block-else)
                      (let* ((else+rest (tmpl-parse-level (cdr rest1)))
                             (else-body (car else+rest))
                             (rest2     (cdr else+rest)))
                        (if (or (null? rest2)
                                (not (eq? (caar rest2) 'block-endif)))
                            (error "template: missing endif after else")
                            (loop (cdr rest2)
                                  (cons (list 'if expr then-body else-body)
                                        acc)))))
                     (else (error "template: unexpected tag in if" (caar rest1))))))
                (else
                 (loop (cdr toks) (cons tok acc))))))))

    (define (tmpl-parse str)
      (car (tmpl-parse-level (tmpl-lex str))))

    ;; ---------------------------------------------------------------------------
    ;; 5. Renderer — AST → string via port
    ;; ---------------------------------------------------------------------------

    (define (tmpl-read-file path)
      (call-with-input-file path
        (lambda (port)
          (let loop ((chars '()))
            (let ((ch (read-char port)))
              (if (eof-object? ch)
                  (list->string (reverse chars))
                  (loop (cons ch chars))))))))

    (define (tmpl-render-nodes nodes ctx base-dir port)
      (for-each
        (lambda (node)
          (case (car node)
            ((text)
             (display (cadr node) port))
            ((expr)
             (let ((val (tmpl-lookup (cadr node) ctx)))
               (display (tmpl-value->string val) port)))
            ((for)
             (let* ((var-name (cadr node))
                    (expr     (caddr node))
                    (body     (cadddr node))
                    (coll     (tmpl-lookup expr ctx)))
               (when coll
                 (let ((items (if (vector? coll)
                                  (vector->list coll)
                                  (if (list? coll) coll '()))))
                   (for-each
                     (lambda (item)
                       (let ((loop-ctx (cons (cons (string->symbol var-name) item)
                                             ctx)))
                         (tmpl-render-nodes body loop-ctx base-dir port)))
                     items)))))
            ((if)
             (let* ((expr      (cadr node))
                    (then-body (caddr node))
                    (else-body (cadddr node))
                    (val       (tmpl-lookup expr ctx)))
               (if (tmpl-truthy? val)
                   (tmpl-render-nodes then-body ctx base-dir port)
                   (tmpl-render-nodes else-body ctx base-dir port))))
            ((block-include)
             (let* ((filename (cadr node))
                    (path     (if (string-prefix? "/" filename)
                                  filename
                                  (join-path base-dir filename)))
                    (content  (tmpl-read-file path))
                    (ast      (tmpl-parse content))
                    (inc-base (directory-name path)))
               (tmpl-render-nodes ast ctx inc-base port)))))
        nodes))

    ;; ---------------------------------------------------------------------------
    ;; 6. Public API
    ;; ---------------------------------------------------------------------------

    (define (template-render str ctx)
      (call-with-output-string
        (lambda (port)
          (tmpl-render-nodes (tmpl-parse str) ctx "." port))))

    (define (template-render-file path ctx)
      (let* ((content  (tmpl-read-file path))
             (base-dir (directory-name path))
             (ast      (tmpl-parse content)))
        (call-with-output-string
          (lambda (port)
            (tmpl-render-nodes ast ctx base-dir port)))))

    (define (make-template-engine base-dir)
      (lambda (path ctx)
        (template-render-file (join-path base-dir path) ctx)))

    (define (template-engine-render engine path ctx)
      (engine path ctx))))

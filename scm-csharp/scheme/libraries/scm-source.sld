(define-library (scm source)
  (import (scheme base)
          (scheme char)
          (scheme read)
          (scheme write)
          (srfi 69)
          (scm fs)
          (scm glob)
          (scm io)
          (scm module)
          (scm toml))
  (export collect-source-files
          cst->datum
          cst->string
          cst-children
          cst-close
          cst-code?
          cst-col
          cst-comment?
          cst-container?
          cst-kind
          cst-line
          cst-newlines-before
          cst-node?
          cst-pre
          cst-text
          cst-trailing-comment?
          import-binding-kind
          import-binding-library
          import-binding-name
          import-set-bindings
          library-file-name
          make-cst-node
          make-import-cache
          same-import-binding?
          source-read-error-position
          source-read-file
          source-read-string
          tools-config
          tools-config-ref
          tools-excluded?)
  (begin

    ;; ================================================================
    ;; (scm source) — a lossless reader for Scheme source text. It
    ;; produces a concrete syntax tree (CST) that keeps everything the
    ;; ordinary reader throws away: comments of every kind, the exact
    ;; spelling of atoms, bracket style and the whitespace in front of
    ;; each node. Writing the tree back with cst->string reproduces the
    ;; input byte for byte. The formatter (scm source format) and the
    ;; linter (scm source lint) are built on it.
    ;;
    ;; Every node is a cst-node record:
    ;;   kind      symbol, see below
    ;;   text      the node's own text (an atom's spelling, a comment, an
    ;;             opening delimiter or a prefix)
    ;;   line col  where the node starts (line from 1, column from 0)
    ;;   pre       the whitespace in front of the node
    ;;   children  the nested nodes of a container, prefix or #; comment
    ;;   close     containers: (whitespace-before-close . close-delimiter);
    ;;             the file node: the whitespace at the end of the file
    ;;
    ;; Kinds:
    ;;   file            the whole text; children are the top-level nodes
    ;;   list            text "(" or "["
    ;;   vector          text "#("
    ;;   bytevector      text "#u8("
    ;;   prefix          text ' ` , ,@ #' #` #, #,@ ; children: any comments
    ;;                   followed by the datum
    ;;   label           text "#N=" ; children as for prefix
    ;;   datum-comment   text "#;" ; children as for prefix
    ;;   atom            symbol, number, character, boolean, string,
    ;;                   here-string (its text ends with the newline after
    ;;                   the end marker) or a label reference "#N#"
    ;;   dot             the "." of a dotted list
    ;;   comment         a ; comment, text without the newline
    ;;   block-comment   a #| |# comment (nesting allowed)
    ;;   directive       #!fold-case, #!no-fold-case or a #!/ shebang line
    ;; ================================================================

    (define-record-type cst-node
      (make-cst-node kind text line col pre children close)
      cst-node?
      (kind cst-kind)
      (text cst-text)
      (line cst-line)
      (col cst-col)
      (pre cst-pre)
      (children cst-children)
      (close cst-close))

    ;; ---- reading ---------------------------------------------------

    (define (delimiter? c)
      (or (char-whitespace? c) (memv c '(#\( #\) #\[ #\] #\" #\;))))

    (define (read-error-at file line col message)
      (error (string-append "source-read: " message) file line col))

    (define (source-read-error-position obj)
      "Syntax: (source-read-error-position obj)
Library: (scm source)
Description: Returns (file line col) when obj is an error raised by
  source-read-string or source-read-file, otherwise #f. line counts from
  1, col from 0.
Example:
  (guard (e (#t (source-read-error-position e)))
    (source-read-string \"(a\" \"x.scm\"))
    => (\"x.scm\" 1 0)"
      (and (error-object? obj)
           (let ((msg (error-object-message obj))
                 (irr (error-object-irritants obj)))
             (and (string? msg)
                  (>= (string-length msg) 12)
                  (string=? (substring msg 0 12) "source-read:")
                  (= (length irr) 3)
                  irr))))

    (define (source-read-string str . maybe-file)
      "Syntax: (source-read-string str [file])
Library: (scm source)
Description: Reads all of the Scheme source text str into a CST and
  returns its file node. Nothing is lost: comments, whitespace and the
  exact spelling of every atom are kept, so (cst->string (source-read-string
  s)) is s again. file (default \"<string>\") is only used in error
  messages. A malformed text (an unclosed list, an unexpected closing
  bracket, an unterminated string or comment) raises an error whose
  position source-read-error-position returns.
Example:
  (map cst-kind (cst-children (source-read-string \"(a b) ; c\")))
    => (list comment)"
      (let* ((file (if (pair? maybe-file) (car maybe-file) "<string>"))
             (n (string-length str))
             (i 0)
             (line 1)
             (col 0))

        (define (peek) (if (< i n) (string-ref str i) #f))
        (define (peek-at k) (if (< (+ i k) n) (string-ref str (+ i k)) #f))
        (define (advance!)
          (let ((c (string-ref str i)))
            (set! i (+ i 1))
            (if (char=? c #\newline)
                (begin
                  (set! line (+ line 1))
                  (set! col 0))
                (set! col (+ col 1)))
            c))
        (define (fail l c message) (read-error-at file l c message))

        (define (skip-whitespace)
          (let ((start i))
            (let loop ()
              (let ((c (peek)))
                (when (and c (char-whitespace? c))
                  (advance!)
                  (loop))))
            (substring str start i)))

        ;; Reads nodes until a closing delimiter (consumed) or, at top
        ;; level, the end of the text. Returns (items close-pre close-char).
        (define (read-items open-line open-col top?)
          (let loop ((acc '()))
            (let* ((ws (skip-whitespace))
                   (c (peek)))
              (cond ((not c)
                     (if top?
                         (list (reverse acc) ws #f)
                         (fail open-line open-col "unclosed list")))
                    ((or (char=? c #\)) (char=? c #\]))
                     (if top?
                         (fail line col
                               (string-append "unexpected " (string c)))
                         (begin
                           (advance!)
                           (list (reverse acc) ws (string c)))))
                    (else (loop (cons (read-node ws) acc)))))))

        ;; Reads the comments up to and including the next datum, for a
        ;; prefix, label or datum comment opened at (pl pc).
        (define (read-operand pl pc what)
          (let loop ((acc '()))
            (let* ((ws (skip-whitespace))
                   (c (peek)))
              (when (or (not c) (char=? c #\)) (char=? c #\]))
                (fail pl pc (string-append what " without a datum")))
              (let ((node (read-node ws)))
                (if (memq (cst-kind node)
                          '(comment block-comment datum-comment directive))
                    (loop (cons node acc))
                    (reverse (cons node acc)))))))

        (define (scan-string! l c)
          ;; at the opening quote
          (advance!)
          (let loop ()
            (let ((ch (peek)))
              (cond ((not ch) (fail l c "unterminated string"))
                    ((char=? ch #\\)
                     (advance!)
                     (when (peek) (advance!))
                     (loop))
                    ((char=? ch #\") (advance!))
                    (else (advance!) (loop))))))

        (define (scan-bar! l c)
          ;; at an opening |
          (advance!)
          (let loop ()
            (let ((ch (peek)))
              (cond ((not ch) (fail l c "unterminated |symbol|"))
                    ((char=? ch #\\)
                     (advance!)
                     (when (peek) (advance!))
                     (loop))
                    ((char=? ch #\|) (advance!))
                    (else (advance!) (loop))))))

        (define (scan-atom! l c)
          (let loop ()
            (let ((ch (peek)))
              (cond ((not ch) #t)
                    ((char=? ch #\|) (scan-bar! l c) (loop))
                    ((delimiter? ch) #t)
                    (else (advance!) (loop))))))

        (define (scan-to-eol!)
          (let loop ()
            (let ((ch (peek)))
              (when (and ch (not (char=? ch #\newline)))
                (advance!)
                (loop)))))

        (define (scan-block-comment! l c)
          ;; at #|
          (advance!)
          (advance!)
          (let loop ((depth 1))
            (let ((ch (peek)))
              (cond ((not ch) (fail l c "unterminated #| comment"))
                    ((and (char=? ch #\|) (eqv? (peek-at 1) #\#))
                     (advance!)
                     (advance!)
                     (unless (= depth 1) (loop (- depth 1))))
                    ((and (char=? ch #\#) (eqv? (peek-at 1) #\|))
                     (advance!)
                     (advance!)
                     (loop (+ depth 1)))
                    (else (advance!) (loop depth))))))

        (define (scan-here-string! l c)
          ;; at #<<MARKER\n ... \nMARKER\n
          (advance!)
          (advance!)
          (advance!)
          (let ((mstart i))
            (scan-to-eol!)
            (let
                ((marker (let ((m (substring str mstart i)))
                           (if (and (> (string-length m) 0)
                                    (char=?
                                     (string-ref m (- (string-length m) 1))
                                     #\return))
                               (substring m 0 (- (string-length m) 1))
                               m))))
              (unless (peek) (fail l c "here-string not closed"))
              (advance!)
              (let loop ()
                (unless (peek) (fail l c "here-string not closed"))
                (let ((lstart i))
                  (scan-to-eol!)
                  (let* ((ln (substring str lstart i))
                         (ln (if (and (> (string-length ln) 0)
                                      (char=?
                                       (string-ref ln
                                                   (- (string-length ln) 1))
                                       #\return))
                                 (substring ln 0 (- (string-length ln) 1))
                                 ln)))
                    (cond ((string=? ln marker)
                           (unless (peek) (fail l c "here-string not closed"))
                           (advance!))
                          (else (unless (peek)
                                  (fail l c "here-string not closed"))
                                (advance!)
                                (loop)))))))))

        (define (container kind text pre l c)
          (let* ((r (read-items l c #f)))
            (make-cst-node kind text l c pre
                           (car r)
                           (cons (cadr r) (caddr r)))))

        (define (operand-node kind text pre l c what)
          (make-cst-node kind text l c pre (read-operand l c what) #f))

        (define (atom-from start pre l c)
          (let ((text (substring str start i)))
            (make-cst-node (if (string=? text ".") 'dot 'atom)
                           text
                           l
                           c
                           pre
                           '()
                           #f)))

        (define (read-node pre)
          (let ((l line)
                (c col)
                (start i)
                (ch (peek)))
            (cond ((or (char=? ch #\() (char=? ch #\[))
                   (advance!)
                   (container 'list (string ch) pre l c))
                  ((char=? ch #\")
                   (scan-string! l c)
                   (atom-from start pre l c))
                  ((char=? ch #\;)
                   (scan-to-eol!)
                   (make-cst-node 'comment
                                  (substring str start i)
                                  l
                                  c
                                  pre
                                  '()
                                  #f))
                  ((char=? ch #\')
                   (advance!)
                   (operand-node 'prefix "'" pre l c "quote"))
                  ((char=? ch #\`)
                   (advance!)
                   (operand-node 'prefix "`" pre l c "quasiquote"))
                  ((char=? ch #\,)
                   (advance!)
                   (if (eqv? (peek) #\@)
                       (begin
                         (advance!)
                         (operand-node 'prefix
                                       ",@"
                                       pre
                                       l
                                       c
                                       "unquote-splicing"))
                       (operand-node 'prefix "," pre l c "unquote")))
                  ((char=? ch #\|) (scan-atom! l c) (atom-from start pre l c))
                  ((char=? ch #\#) (read-hash pre l c start))
                  (else (scan-atom! l c) (atom-from start pre l c)))))

        (define (read-hash pre l c start)
          (let ((nx (peek-at 1)))
            (cond ((eqv? nx #\|)
                   (scan-block-comment! l c)
                   (make-cst-node 'block-comment
                                  (substring str start i)
                                  l
                                  c
                                  pre
                                  '()
                                  #f))
                  ((eqv? nx #\;)
                   (advance!)
                   (advance!)
                   (operand-node 'datum-comment "#;" pre l c "#;"))
                  ((eqv? nx #\()
                   (advance!)
                   (advance!)
                   (container 'vector "#(" pre l c))
                  ((and (eqv? nx #\u)
                        (eqv? (peek-at 2) #\8)
                        (eqv? (peek-at 3) #\())
                   (advance!)
                   (advance!)
                   (advance!)
                   (advance!)
                   (container 'bytevector "#u8(" pre l c))
                  ((eqv? nx #\\)
                   (advance!)
                   (advance!)
                   (unless (peek)
                     (fail l c "character literal at end of text"))
                   (advance!)
                   (scan-atom! l c)
                   (atom-from start pre l c))
                  ((eqv? nx #\<)
                   (unless (eqv? (peek-at 2) #\<)
                     (fail l c "expected #<< for a here-string"))
                   (scan-here-string! l c)
                   (atom-from start pre l c))
                  ((eqv? nx #\')
                   (advance!)
                   (advance!)
                   (operand-node 'prefix "#'" pre l c "syntax"))
                  ((eqv? nx #\`)
                   (advance!)
                   (advance!)
                   (operand-node 'prefix "#`" pre l c "quasisyntax"))
                  ((eqv? nx #\,)
                   (advance!)
                   (advance!)
                   (if (eqv? (peek) #\@)
                       (begin
                         (advance!)
                         (operand-node 'prefix
                                       "#,@"
                                       pre
                                       l
                                       c
                                       "unsyntax-splicing"))
                       (operand-node 'prefix "#," pre l c "unsyntax")))
                  ((eqv? nx #\!)
                   (if (eqv? (peek-at 2) #\/)
                       (scan-to-eol!)
                       (begin
                         (advance!)
                         (advance!)
                         (scan-atom! l c)))
                   (make-cst-node 'directive
                                  (substring str start i)
                                  l
                                  c
                                  pre
                                  '()
                                  #f))
                  ((and nx (char-numeric? nx))
                   (advance!)
                   (let loop ()
                     (when (and (peek) (char-numeric? (peek)))
                       (advance!)
                       (loop)))
                   (cond ((eqv? (peek) #\=)
                          (advance!)
                          (operand-node 'label
                                        (substring str start i)
                                        pre
                                        l
                                        c
                                        "datum label"))
                         ((eqv? (peek) #\#)
                          (advance!)
                          (atom-from start pre l c))
                         (else (scan-atom! l c) (atom-from start pre l c))))
                  (else (advance!)
                        (scan-atom! l c)
                        (atom-from start pre l c)))))

        (let ((r (read-items 1 0 #t)))
          (make-cst-node 'file "" 1 0 "" (car r) (cadr r)))))

    (define (source-read-file path)
      "Syntax: (source-read-file path)
Library: (scm source)
Description: Reads the Scheme source file at path (UTF-8) into a CST and
  returns its file node, like source-read-string. Read errors name path.
Example:
  (cst->string (source-read-file \"lib.sld\")) ; the file's text, unchanged"
      (source-read-string (read-file-string path) path))

    ;; ---- writing ---------------------------------------------------

    (define (write-node node out)
      (case (cst-kind node)
        ((file)
         (for-each (lambda (ch)
                     (write-string (cst-pre ch) out)
                     (write-node ch out))
                   (cst-children node))
         (write-string (cst-close node) out))
        ((list vector bytevector)
         (write-string (cst-text node) out)
         (for-each (lambda (ch)
                     (write-string (cst-pre ch) out)
                     (write-node ch out))
                   (cst-children node))
         (let ((close (cst-close node)))
           (write-string (car close) out)
           (write-string (cdr close) out)))
        ((prefix label datum-comment)
         (write-string (cst-text node) out)
         (for-each (lambda (ch)
                     (write-string (cst-pre ch) out)
                     (write-node ch out))
                   (cst-children node)))
        (else (write-string (cst-text node) out))))

    (define (cst->string node)
      "Syntax: (cst->string node)
Library: (scm source)
Description: Writes node back as source text. For a file node read by
  source-read-string this is exactly the original text. The node's own
  pre whitespace is not included; that of its children is.
Example:
  (cst->string (source-read-string \"(a  [b] ; c\\n)\")) => \"(a  [b] ; c\\n)\""
      (let ((out (open-output-string)))
        (write-node node out)
        (get-output-string out)))

    (define (cst->datum node)
      "Syntax: (cst->datum node)
Library: (scm source)
Description: Returns the datum node denotes, as the ordinary reader would
  read it. For a file node, returns the list of its top-level datums.
  Comment nodes have no datum; for them the result is the eof object.
Example:
  (cst->datum (car (cst-children (source-read-string \"'(a #;b c)\"))))
    => (quote (a c))"
      ;; The newline ends a trailing ; comment for readers that would
      ;; otherwise reject a comment at the very end of the input.
      (let
          ((port (open-input-string (string-append (cst->string node) "\n"))))
        (if (eq? (cst-kind node) 'file)
            (let loop ((acc '()))
              (let ((d (read port)))
                (if (eof-object? d) (reverse acc) (loop (cons d acc)))))
            (read port))))

    ;; ---- predicates and helpers ------------------------------------

    (define (cst-comment? node)
      "Syntax: (cst-comment? node)
Library: (scm source)
Description: Returns #t if node is a comment of any kind (; comment,
  #| |# block comment, #; datum comment) or a #! directive, that is a
  node with no datum of its own.
Example:
  (cst-comment? (car (cst-children (source-read-string \"; x\")))) => #t"
      (and (memq (cst-kind node)
                 '(comment block-comment datum-comment directive))
           #t))

    (define (cst-code? node)
      "Syntax: (cst-code? node)
Library: (scm source)
Description: Returns #t if node denotes a datum (anything but a comment,
  a directive or the dot of a dotted list).
Example:
  (cst-code? (car (cst-children (source-read-string \"42\")))) => #t"
      (not (or (cst-comment? node) (eq? (cst-kind node) 'dot))))

    (define (cst-container? node)
      "Syntax: (cst-container? node)
Library: (scm source)
Description: Returns #t if node is a list, vector or bytevector.
Example:
  (cst-container? (car (cst-children (source-read-string \"#(1 2)\")))) => #t"
      (and (memq (cst-kind node) '(list vector bytevector)) #t))

    (define (cst-newlines-before node)
      "Syntax: (cst-newlines-before node)
Library: (scm source)
Description: Returns the number of line breaks in the whitespace in front
  of node: 0 if it is on the same line as what precedes it, 2 or more if
  a blank line separates them.
Example:
  (map cst-newlines-before
       (cst-children (source-read-string \"a b\\n\\nc\")))
    => (0 0 2)"
      (let ((s (cst-pre node)))
        (let loop ((k 0) (acc 0))
          (if (= k (string-length s))
              acc
              (loop (+ k 1)
                    (if (char=? (string-ref s k) #\newline)
                        (+ acc 1)
                        acc))))))

    (define (cst-trailing-comment? node)
      "Syntax: (cst-trailing-comment? node)
Library: (scm source)
Description: Returns #t if node is a ; comment that follows other code on
  the same line (an end-of-line comment), #f for a comment on a line of
  its own and for every other node.
Example:
  (map cst-trailing-comment?
       (cst-children (source-read-string \"(a) ; x\\n; y\")))
    => (#f #t #f)"
      (and (eq? (cst-kind node) 'comment)
           (= (cst-newlines-before node) 0)
           (not (and (= (cst-line node) 1)
                     (= (cst-col node) (string-length (cst-pre node)))))))

    ;; ---- shared tool support: files and configuration -------------

    (define skipped-directories '("build" "dist" "node_modules" "bin" "obj"))

    (define (source-file? name)
      (let ((n (string-length name)))
        (and (> n 4)
             (let ((ext (substring name (- n 4) n)))
               (or (string=? ext ".scm") (string=? ext ".sld"))))))

    (define (excluded? rel excludes)
      (let loop ((ex excludes))
        (and (pair? ex)
             (or (glob-match? (car ex) rel)
                 (glob-match? (car ex) (base-name rel))
                 (loop (cdr ex))))))

    (define (collect-source-files paths . maybe-excludes)
      "Syntax: (collect-source-files paths [excludes])
Library: (scm source)
Description: Expands the list paths into the Scheme source files a tool
  should process. A file is taken as it is; a directory is searched
  recursively for *.scm and *.sld files, skipping hidden directories and
  build, dist, node_modules, bin and obj. excludes is a list of glob
  patterns matched against the path relative to the directory given and
  against the base name; matching files and directories are left out.
  The result keeps the order of paths, each directory's files sorted.
Example:
  (collect-source-files '(\"src\" \"main.scm\") '(\"*-generated.sld\"))
    => (\"src/a.sld\" \"src/sub/b.scm\" \"main.scm\")"
      (let ((excludes (if (pair? maybe-excludes) (car maybe-excludes) '())))
        (define (walk dir rel acc)
          (let* ((files (list-sort-strings (directory-files dir)))
                 (dirs (list-sort-strings (directory-directories dir)))
                 (acc (let loop ((fs files) (acc acc))
                        (if (null? fs)
                            acc
                            (let
                                ((r (if rel
                                        (string-append rel "/" (car fs))
                                        (car fs))))
                              (loop (cdr fs)
                                    (if
                                     (and (source-file? (car fs))
                                          (not (excluded? r excludes)))
                                     (cons (string-append dir "/" (car fs))
                                           acc)
                                     acc)))))))
            (let loop ((ds dirs) (acc acc))
              (if (null? ds)
                  acc
                  (let ((d (car ds))
                        (r (if rel
                               (string-append rel "/" (car ds))
                               (car ds))))
                    (loop (cdr ds)
                          (if (or (char=? (string-ref d 0) #\.)
                                  (member d skipped-directories)
                                  (excluded? r excludes))
                              acc
                              (walk (string-append dir "/" d) r acc))))))))
        (let loop ((ps paths) (acc '()))
          (cond ((null? ps) (reverse acc))
                ((directory-exists? (car ps))
                 (let ((dir (strip-trailing-slash (car ps))))
                   (loop (cdr ps) (walk dir #f acc))))
                (else (loop (cdr ps) (cons (car ps) acc)))))))

    (define (strip-trailing-slash p)
      (if (and (> (string-length p) 1)
               (char=? (string-ref p (- (string-length p) 1)) #\/))
          (substring p 0 (- (string-length p) 1))
          p))

    (define (list-sort-strings lst)
      ;; insertion into a sorted list; directory listings are short
      (let loop ((lst lst) (acc '()))
        (if (null? lst)
            acc
            (loop (cdr lst)
                  (let ins ((acc acc))
                    (cond ((null? acc) (list (car lst)))
                          ((string<? (car lst) (car acc))
                           (cons (car lst) acc))
                          (else (cons (car acc) (ins (cdr acc))))))))))

    (define config-cache '())

    (define (parent-directory dir)
      (let loop ((k (- (string-length dir) 1)))
        (cond ((< k 0) #f)
              ((char=? (string-ref dir k) #\/)
               (if (= k 0)
                   (if (string=? dir "/") #f "/")
                   (substring dir 0 k)))
              (else (loop (- k 1))))))

    (define (tools-config path)
      "Syntax: (tools-config path)
Library: (scm source)
Description: Returns the configuration for the source tools (scm fmt,
  scm lint) that applies to the file or directory path: the parsed TOML
  of the nearest scm-tools.toml in path's directory or one of its
  parents, as an alist with string keys (see (scm toml)), plus the entry
  (\"dir\" . directory-of-the-config-file). Without a config file the
  result is (). Results are cached per directory.
Example:
  (tools-config-ref (tools-config \"src/a.sld\") '(\"format\" \"width\") 78)
    => 78"
      (let* ((abs (absolute-path path))
             (start (if (directory-exists? abs)
                        abs
                        (or (parent-directory abs) "/"))))
        (let loop ((dir start) (seen '()))
          (let ((cached (assoc dir config-cache)))
            (cond (cached (for-each (lambda (d)
                                      (set!
                                       config-cache
                                       (cons (cons d (cdr cached))
                                             config-cache)))
                                    seen)
                          (cdr cached))
                  (else (let
                            ((file (string-append
                                    (if (string=? dir "/") "" dir)
                                    "/scm-tools.toml")))
                          (if (file-exists? file)
                              (let
                                  ((cfg
                                    (cons
                                     (cons "dir" dir)
                                     (toml-parse (read-file-string file)))))
                                (for-each
                                 (lambda (d)
                                   (set! config-cache
                                         (cons (cons d cfg) config-cache)))
                                 (cons dir seen))
                                cfg)
                              (let ((up (parent-directory dir)))
                                (if up
                                    (loop up (cons dir seen))
                                    (begin
                                      (for-each
                                       (lambda (d)
                                         (set!
                                          config-cache
                                          (cons (cons d '()) config-cache)))
                                       (cons dir seen))
                                      '())))))))))))

    (define (tools-config-ref cfg keys default)
      "Syntax: (tools-config-ref cfg keys default)
Library: (scm source)
Description: Looks up the path of string keys in the alist cfg returned
  by tools-config and returns the value found, or default. TOML arrays
  come back as lists.
Example:
  (tools-config-ref '((\"lint\" (\"disable\" . #(\"x\")))) '(\"lint\" \"disable\") '())
    => (\"x\")"
      (let loop ((v cfg) (keys keys))
        (cond ((null? keys) (if (vector? v) (vector->list v) v))
              ((and (list? v) (assoc (car keys) v))
               =>
               (lambda (p) (loop (cdr p) (cdr keys))))
              (else default))))

    ;; ---- import resolution -----------------------------------------
    ;;
    ;; An import binding is a vector #(visible-name library original-name
    ;; kind) where kind is syntax (a macro or core form), procedure,
    ;; value or unknown. Libraries of the scheme, srfi and scm families
    ;; are loaded to see their exports; other libraries are read
    ;; statically from their .sld file in a list of directories, and the
    ;; names they re-export are followed through their own imports.

    (define (import-binding-name b)
      "Syntax: (import-binding-name binding)
Library: (scm source)
Description: Returns the name an import binding (from
  import-set-bindings) makes visible, a symbol.
Example:
  (import-binding-name (car (import-set-bindings '(only (scheme base) car)
                                                  (make-import-cache '()))))
    => car"
      (vector-ref b 0))

    (define (import-binding-library b)
      "Syntax: (import-binding-library binding)
Library: (scm source)
Description: Returns the name of the library that defines an import
  binding (from import-set-bindings); for a re-exported name this is the
  library it comes from originally, when that is known.
Example:
  (import-binding-library (car (import-set-bindings '(only (scheme base) car)
                                                     (make-import-cache '()))))
    => (scheme base)"
      (vector-ref b 1))

    (define (import-binding-kind b)
      "Syntax: (import-binding-kind binding)
Library: (scm source)
Description: Returns what an import binding (from import-set-bindings)
  is: syntax (a macro or core form), procedure, value or unknown.
Example:
  (import-binding-kind (car (import-set-bindings '(only (scheme base) when)
                                                  (make-import-cache '()))))
    => syntax"
      (vector-ref b 3))

    (define (make-import-cache lib-dirs)
      "Syntax: (make-import-cache lib-dirs)
Library: (scm source)
Description: Returns a cache for import-set-bindings that finds the
  .sld files of non-built-in libraries in the list of directories
  lib-dirs (the module search path is searched as well).
Example:
  (make-import-cache '(\"src\"))"
      (vector (append lib-dirs (guard (e (#t '())) (module-search-path)))
              (make-hash-table equal?)))

    (define (library-file-name name)
      "Syntax: (library-file-name name)
Library: (scm source)
Description: Returns the file name a library name maps to: its parts
  joined with - plus .sld.
Example:
  (library-file-name '(scm net http)) => \"scm-net-http.sld\""
      (let ((out (open-output-string)))
        (let loop ((ps name) (first #t))
          (unless (null? ps)
            (unless first (write-char #\- out))
            (if (symbol? (car ps))
                (write-string (symbol->string (car ps)) out)
                (write (car ps) out))
            (loop (cdr ps) #f)))
        (string-append (get-output-string out) ".sld")))

    (define (builtin-family? name)
      (and (pair? name) (memq (car name) '(scheme srfi scm)) #t))

    (define (value-kind v)
      (let ((s (let ((o (open-output-string)))
                 (write v o)
                 (get-output-string o))))
        (cond ((or (string-prefix? "#<macro" s)
                   (string-prefix? "#<core-form" s))
               'syntax)
              ((procedure? v) 'procedure)
              (else 'value))))

    (define (string-prefix? p s)
      (and (<= (string-length p) (string-length s))
           (string=? p (substring s 0 (string-length p)))))

    ;; The exports of a library: list of binding vectors, or #f.
    (define (library-bindings name cache)
      (let ((table (vector-ref cache 1)))
        (let ((hit (hash-table-ref/default table name 'none)))
          (cond ((eq? hit 'busy) #f)
                ((not (eq? hit 'none)) hit)
                (else (hash-table-set! table name 'busy)
                      (let ((r (compute-library-bindings name cache)))
                        (hash-table-set! table name r)
                        r))))))

    (define (compute-library-bindings name cache)
      (or (and (builtin-family? name)
               (guard (e (#t #f))
                 (%load-module name)
                 (map (lambda (s)
                        (vector s name s
                                (guard (e (#t 'unknown))
                                  (value-kind (%module-ref name s)))))
                      (%module-exports name))))
          (static-library-bindings name cache)))

    (define (find-library-file name dirs)
      (let ((fname (library-file-name name)))
        (let loop ((ds dirs))
          (cond ((null? ds) #f)
                ((not (string? (car ds))) (loop (cdr ds)))
                ((file-exists? (string-append (car ds) "/" fname))
                 (string-append (car ds) "/" fname))
                (else (loop (cdr ds)))))))

    (define (static-library-bindings name cache)
      (let ((file (find-library-file name (vector-ref cache 0))))
        (and file
             (guard (e (#t #f))
               (let ((forms (cst->datum (source-read-file file))))
                 (and (pair? forms)
                      (pair? (car forms))
                      (eq? (caar forms) 'define-library)
                      (static-bindings-of name (cddar forms) cache)))))))

    (define (static-bindings-of name decls cache)
      (let loop
          ((ds decls)
           (exports '())
           (imports '())
           (defs '())
           (macros '())
           (ok? #t))
        (cond ((not ok?) #f)
              ((null? ds)
               (let
                   ((imported (map (lambda (s) (import-set-bindings s cache))
                                   imports)))
                 (map (lambda (e)
                        (let ((visible (car e))
                              (orig (cdr e)))
                          (cond ((memq orig macros)
                                 (vector visible name orig 'syntax))
                                ((memq orig defs)
                                 (vector visible name orig 'value))
                                (else
                                 ;; a re-export: take it from the imports
                                 (let find ((ts imported))
                                   (cond
                                    ((null? ts)
                                     (vector visible name orig 'unknown))
                                    ((and
                                      (car ts)
                                      (let scan ((bs (car ts)))
                                        (cond
                                         ((null? bs) #f)
                                         ((eq? (vector-ref (car bs) 0) orig)
                                          (car bs))
                                         (else (scan (cdr bs))))))
                                     =>
                                     (lambda (b)
                                       (vector visible
                                               (vector-ref b 1)
                                               (vector-ref b 2)
                                               (vector-ref b 3))))
                                    (else (find (cdr ts)))))))))
                      exports)))
              ((not (pair? (car ds)))
               (loop (cdr ds) exports imports defs macros ok?))
              (else (case (caar ds)
                      ((export)
                       (loop (cdr ds)
                             (append exports
                                     (map
                                      (lambda (e)
                                        (if
                                         (and (pair? e) (eq? (car e) 'rename))
                                         (cons (caddr e) (cadr e))
                                         (cons e e)))
                                      (cdar ds)))
                             imports
                             defs
                             macros
                             ok?))
                      ((import)
                       (loop (cdr ds)
                             exports
                             (append imports (cdar ds))
                             defs
                             macros
                             ok?))
                      ((begin)
                       (let-values (((d m) (body-definitions (cdar ds))))
                         (loop (cdr ds)
                               exports
                               imports
                               (append d defs)
                               (append m macros)
                               ok?)))
                      ((include include-ci include-library-declarations
                                cond-expand)
                       (loop (cdr ds) exports imports defs macros #f))
                      (else (loop (cdr ds)
                                  exports
                                  imports
                                  defs
                                  macros
                                  ok?)))))))

    ;; Names defined by a body's top-level forms -> (values defs macros).
    (define (body-definitions forms)
      (let loop ((fs forms) (defs '()) (macros '()))
        (if (null? fs)
            (values defs macros)
            (let ((f (car fs)))
              (if (not (pair? f))
                  (loop (cdr fs) defs macros)
                  (case (car f)
                    ((define define-values define-record-type)
                     (loop (cdr fs) (append (defined-names f) defs) macros))
                    ((define-syntax)
                     (loop (cdr fs)
                           defs
                           (if (pair? (cdr f))
                               (cons (cadr f) macros)
                               macros)))
                    ((begin)
                     (let-values (((d m) (body-definitions (cdr f))))
                       (loop (cdr fs) (append d defs) (append m macros))))
                    (else (loop (cdr fs) defs macros))))))))

    (define (defined-names f)
      (case (car f)
        ((define)
         (let loop ((target (and (pair? (cdr f)) (cadr f))))
           (cond ((symbol? target) (list target))
                 ((pair? target) (loop (car target)))
                 (else '()))))
        ((define-values)
         (let loop ((fs (and (pair? (cdr f)) (cadr f)))
                    (acc '()))
           (cond ((symbol? fs) (cons fs acc))
                 ((pair? fs)
                  (loop (cdr fs)
                        (if (symbol? (car fs)) (cons (car fs) acc) acc)))
                 (else acc))))
        ((define-record-type)
         (if (< (length f) 4)
             '()
             (let ((ctor (caddr f))
                   (pred (cadddr f))
                   (fields (cddddr f)))
               (append (cond ((symbol? ctor) (list ctor))
                             ((and (pair? ctor) (symbol? (car ctor)))
                              (list (car ctor)))
                             (else '()))
                       (if (symbol? pred) (list pred) '())
                       (apply append
                              (map (lambda (fl)
                                     (if (pair? fl)
                                         (filter-symbols (cdr fl))
                                         '()))
                                   fields))))))
        (else '())))

    (define (filter-symbols lst)
      (let loop ((l lst) (acc '()))
        (cond ((not (pair? l)) (reverse acc))
              ((symbol? (car l)) (loop (cdr l) (cons (car l) acc)))
              (else (loop (cdr l) acc)))))

    (define (import-set-bindings set cache)
      "Syntax: (import-set-bindings import-set cache)
Library: (scm source)
Description: Returns the bindings an import set (a datum such as
  (scheme base) or (only (srfi 1) fold)) makes visible, as a list of
  vectors #(name library original-name kind), kind being syntax,
  procedure, value or unknown. Returns #f when the library cannot be
  found or its exports cannot be determined statically. cache comes from
  make-import-cache.
Example:
  (map import-binding-name
       (import-set-bindings '(only (scheme base) car) (make-import-cache '())))
    => (car)"
      (define (rewrap inner f) (and inner (f inner)))
      (cond ((and (pair? set) (eq? (car set) 'only) (pair? (cdr set)))
             (rewrap (import-set-bindings (cadr set) cache)
                     (lambda (bs)
                       (keep (lambda (b) (memq (vector-ref b 0) (cddr set)))
                             bs))))
            ((and (pair? set) (eq? (car set) 'except) (pair? (cdr set)))
             (rewrap (import-set-bindings (cadr set) cache)
                     (lambda (bs)
                       (keep (lambda (b)
                               (not (memq (vector-ref b 0) (cddr set))))
                             bs))))
            ((and (pair? set) (eq? (car set) 'prefix) (= (length set) 3))
             (rewrap (import-set-bindings (cadr set) cache)
                     (lambda (bs)
                       (map (lambda (b)
                              (vector (string->symbol
                                       (string-append
                                        (symbol->string (caddr set))
                                        (symbol->string (vector-ref b 0))))
                                      (vector-ref b 1)
                                      (vector-ref b 2)
                                      (vector-ref b 3)))
                            bs))))
            ((and (pair? set) (eq? (car set) 'rename) (pair? (cdr set)))
             (rewrap (import-set-bindings (cadr set) cache)
                     (lambda (bs)
                       (map (lambda (b)
                              (let ((r (assq (vector-ref b 0) (cddr set))))
                                (if (and r (pair? (cdr r)))
                                    (vector (cadr r)
                                            (vector-ref b 1)
                                            (vector-ref b 2)
                                            (vector-ref b 3))
                                    b)))
                            bs))))
            ((and (list? set) (pair? set)) (library-bindings set cache))
            (else #f)))

    (define (keep pred lst)
      (let loop ((l lst) (acc '()))
        (cond ((null? l) (reverse acc))
              ((pred (car l)) (loop (cdr l) (cons (car l) acc)))
              (else (loop (cdr l) acc)))))

    (define (same-import-binding? a b)
      "Syntax: (same-import-binding? a b)
Library: (scm source)
Description: Returns #t if the import bindings a and b (from
  import-set-bindings) certainly denote the same binding: the same
  library and original name, or for built-in libraries the identical
  value. #f means different or unknown.
Example:
  (let ((c (make-import-cache '())))
    (same-import-binding? (car (import-set-bindings '(only (scheme base) car) c))
                          (car (import-set-bindings '(only (scm core) car) c))))
    => #t"
      (or (and (equal? (vector-ref a 1) (vector-ref b 1))
               (eq? (vector-ref a 2) (vector-ref b 2)))
          (and (builtin-family? (vector-ref a 1))
               (builtin-family? (vector-ref b 1))
               (guard (e (#t #f))
                 (eq? (%module-ref (vector-ref a 1) (vector-ref a 2))
                      (%module-ref (vector-ref b 1) (vector-ref b 2)))))))

    (define (tools-excluded? file section)
      "Syntax: (tools-excluded? file section)
Library: (scm source)
Description: Returns #t if the scm-tools.toml that applies to file
  excludes it: the top-level exclude list or the one in the table named
  section (\"format\" or \"lint\"). Patterns are globs matched against
  the path relative to the config file's directory; \"dir/**\" excludes
  everything under dir.
Example:
  (tools-excluded? \"scm-java/src/x.sld\" \"lint\") => #t ; with exclude = [\"scm-java/**\"]"
      (let* ((cfg (tools-config file))
             (dir (tools-config-ref cfg '("dir") #f))
             (patterns (append (let
                                   ((v (tools-config-ref cfg
                                                         '("exclude")
                                                         '())))
                                 (if (list? v) v '()))
                               (let
                                   ((v (tools-config-ref
                                        cfg
                                        (list section "exclude")
                                        '())))
                                 (if (list? v) v '())))))
        (and dir
             (pair? patterns)
             (let* ((abs (absolute-path file))
                    (rel (if (string-prefix? (string-append dir "/") abs)
                             (substring abs
                                        (+ 1 (string-length dir))
                                        (string-length abs))
                             abs)))
               (let loop ((ps patterns))
                 (and (pair? ps)
                      (or (glob-match? (car ps) rel)
                          (let ((p (car ps)))
                            (if (and (>= (string-length p) 3)
                                     (string=?
                                      "/**"
                                      (substring p
                                                 (- (string-length p) 3)
                                                 (string-length p))))
                                (string-prefix?
                                 (substring p 0 (- (string-length p) 2))
                                 rel)
                                (or (string=? p rel)
                                    (string-prefix? (string-append p "/")
                                                    rel))))
                          (loop (cdr ps)))))))))))

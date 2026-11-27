;; (build tutorials): turns the tutorials in documentation/tutorials/*.md
;; into test programs scm-tests/tests/tests_tutorial_<id>.scm, so every
;; tutorial example runs on the JVM, .NET and native implementations.
;;
;; A tutorial is Markdown with a front-matter block:
;;
;;   ---
;;   title: Strings and text
;;   part: techniques
;;   order: 3
;;   libraries: (scheme base) (srfi 13)
;;   summary: Building, searching and splitting text.
;;   ---
;;
;; Every ```scheme block runs, all blocks of a tutorial in order as one
;; program; ```scheme no-test blocks are shown only. In a block,
;;
;;   expr ;; => datum        expr must be equal? to datum
;;   expr ;; => error        expr must raise
;;   expr ;; prints: text    expr must write text (several consecutive
;;   ;; prints: more         ";; prints:" lines are several output lines)
;;
;; anything else is plain code. (import ...) forms are moved to the top.
(define-library (build tutorials)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme file)
          (scheme read)
          (scheme write)
          (srfi 1)
          (srfi 13)
          (scm fs))
  (export generate-tutorial-tests
          read-tutorial
          tutorial-body
          tutorial-front
          tutorial-id
          tutorial-path)
  (begin

    (define (read-text path)
      (call-with-input-file path
        (lambda (p)
          (let loop ((acc '()))
            (let ((s (read-string 65536 p)))
              (if (eof-object? s)
                  (apply string-append (reverse acc))
                  (loop (cons s acc))))))))

    (define (split-lines s)
      (let loop ((i 0) (start 0) (acc '()))
        (cond ((= i (string-length s))
               (reverse (if (= start i) acc (cons (substring s start i) acc))))
              ((char=? (string-ref s i) #\newline)
               (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
              (else (loop (+ i 1) start acc)))))

    ;; --- the tutorial ------------------------------------------------------

    ;; (id path front blocks body): front an alist of symbols to strings,
    ;; blocks ((info first-line lines) ...) of the fenced code blocks, body
    ;; the Markdown text after the front matter
    (define (tutorial-id t) (car t))
    (define (tutorial-path t) (cadr t))
    (define (tutorial-front t) (caddr t))
    (define (tutorial-blocks t) (cadddr t))
    (define (tutorial-body t) (car (cddddr t)))

    (define (read-tutorial path)
      (let* ((lines (list->vector (split-lines (read-text path))))
             (n (vector-length lines))
             (id (let ((b (base-name path)))
                   (substring b 0 (- (string-length b) 3)))))
        ;; front matter: --- ... --- at the top
        (let-values (((front body-start)
                      (if (and (> n 0) (string=? (string-trim-right (vector-ref lines 0)) "---"))
                          (let loop ((i 1) (acc '()))
                            (cond ((>= i n) (error "tutorial: unterminated front matter" path))
                                  ((string=? (string-trim-right (vector-ref lines i)) "---")
                                   (values (reverse acc) (+ i 1)))
                                  (else
                                   (let* ((l (vector-ref lines i))
                                          (c (string-index l #\:)))
                                     (loop (+ i 1)
                                           (if c
                                               (cons (cons (string->symbol (string-trim-both (substring l 0 c)))
                                                           (string-trim-both (substring l (+ c 1) (string-length l))))
                                                     acc)
                                               acc))))))
                          (values '() 0))))
          ;; fenced blocks ``` info ... ```
          (let loop ((i body-start) (blocks '()))
            (if (>= i n)
                (list id path front (reverse blocks)
                      (let loop ((k (- n 1)) (acc '()))
                        (if (< k body-start)
                            (apply string-append acc)
                            (loop (- k 1) (cons (vector-ref lines k) (cons "\n" acc))))))
                (let ((l (string-trim-both (vector-ref lines i))))
                  (if (string-prefix? "```" l)
                      (let ((info (string-trim-both (substring l 3 (string-length l)))))
                        (let inner ((j (+ i 1)) (acc '()))
                          (cond ((>= j n) (error "tutorial: unterminated code block" path (+ i 1)))
                                ((string-prefix? "```" (string-trim-both (vector-ref lines j)))
                                 (loop (+ j 1)
                                       (cons (list info (+ i 2) (reverse acc)) blocks)))
                                (else (inner (+ j 1) (cons (vector-ref lines j) acc))))))
                      (loop (+ i 1) blocks))))))))

    (define (tested-block? b)
      (let ((words (string-tokenize (car b))))
        (and (pair? words)
             (string=? (car words) "scheme")
             (not (member "no-test" (cdr words))))))

    ;; --- forms with their checks ---------------------------------------------

    ;; A block's text -> ((form line check) ...), check #f, (value datum),
    ;; (error) or (prints "text"); line: the Markdown line of the form
    (define (block-forms b)
      (let* ((first-line (cadr b))
             (text (apply string-append (map (lambda (l) (string-append l "\n")) (caddr b))))
             (lines (list->vector (caddr b)))
             (port (open-input-string text)))
        ;; the line (0-based) of each character position
        (define line-of
          (let ((v (make-vector (+ 1 (string-length text)) 0)))
            (let loop ((i 0) (l 0))
              (when (< i (string-length text))
                (vector-set! v i l)
                (loop (+ i 1) (if (char=? (string-ref text i) #\newline) (+ l 1) l))))
            (vector-set! v (string-length text)
                         (if (> (string-length text) 0)
                             (vector-ref v (- (string-length text) 1))
                             0))
            (lambda (pos) (vector-ref v (min pos (string-length text))))))
        (let loop ((pos 0) (acc '()))
          (let* ((start (skip-space-and-comments text pos)))
            (if (>= start (string-length text))
                (reverse acc)
                (let* ((sub (open-input-string (substring text start (string-length text))))
                       (form (read sub))
                       (end (+ start (consumed-chars text start sub)))
                       (form-line (line-of start))
                       (end-line (line-of (max start (- end 1))))
                       (check (form-check text end lines end-line)))
                  (loop (if (car check)
                            ;; the check's comment lines are consumed
                            (line-start text (+ end-line 1 (cdr check)))
                            end)
                        (cons (list form (+ first-line form-line) (car check)) acc))))))))

    ;; characters read from text at start by port sub (read leaves the port
    ;; right after the datum)
    (define (consumed-chars text start sub)
      (let ((rest (let loop ((acc '()))
                    (let ((c (read-char sub)))
                      (if (eof-object? c) (length acc) (loop (cons c acc)))))))
        (- (- (string-length text) start) rest)))

    (define (line-start text line)
      (let loop ((i 0) (l 0))
        (cond ((= l line) i)
              ((>= i (string-length text)) i)
              ((char=? (string-ref text i) #\newline) (loop (+ i 1) (+ l 1)))
              (else (loop (+ i 1) l)))))

    (define (skip-space-and-comments text pos)
      (let loop ((i pos))
        (cond ((>= i (string-length text)) i)
              ((char-whitespace? (string-ref text i)) (loop (+ i 1)))
              ((char=? (string-ref text i) #\;)
               (let skip ((j i))
                 (if (or (>= j (string-length text)) (char=? (string-ref text j) #\newline))
                     (loop j)
                     (skip (+ j 1)))))
              (else i))))

    ;; the check of a form ending at end on line end-line: a comment
    ;; after it on that line, else ";; =>" / ";; prints:" comment lines
    ;; right below it (then (check . lines-used) counts from the line below)
    (define (form-check text end lines end-line)
      (let ((rest-of-line (let loop ((i end))
                            (if (or (>= i (string-length text))
                                    (char=? (string-ref text i) #\newline))
                                (substring text end i)
                                (loop (+ i 1))))))
        (if (comment-of rest-of-line)
            (line-check rest-of-line lines (+ end-line 1))
            (let ((below (and (< (+ end-line 1) (vector-length lines))
                              (string-trim-both (vector-ref lines (+ end-line 1))))))
              (if (and below
                       (string-prefix? ";;" below)
                       (let ((c (comment-of below)))
                         (and c (or (string-prefix? "=>" c) (string-prefix? "prints:" c)))))
                  (let ((r (line-check below lines (+ end-line 2))))
                    (cons (car r) (+ 1 (cdr r))))
                  (cons #f 0))))))

    ;; the check after a form: on its last line (";; => x", ";; prints: x"),
    ;; then more ";; prints:" lines below. -> (check . extra-lines-used)
    (define (line-check line lines next)
      (let ((c (comment-of line)))
        (cond ((and c (string-prefix? "=>" c))
               (let ((v (string-trim-both (substring c 2 (string-length c)))))
                 (cons (if (string=? v "error")
                           '(error)
                           (list 'value (read (open-input-string v))))
                       0)))
              ((and c (string-prefix? "prints:" c))
               (let loop ((i next) (out (list (prints-text c))))
                 (let ((more (and (< i (vector-length lines))
                                  (let ((t (string-trim-both (vector-ref lines i))))
                                    (and (string-prefix? ";;" t)
                                         (comment-of t))))))
                   (if (and more (string-prefix? "prints:" more))
                       (loop (+ i 1) (cons (prints-text more) out))
                       (cons (list 'prints (string-join (reverse out) "\n"))
                             (- i next))))))
              (else (cons #f 0)))))

    (define (prints-text c)
      (let ((s (substring c 7 (string-length c))))
        (if (and (> (string-length s) 0) (char=? (string-ref s 0) #\space))
            (substring s 1 (string-length s))
            s)))

    ;; the text of a ";; ..." comment on the line (outside strings), or #f
    (define (comment-of line)
      (let loop ((i 0) (in-string #f))
        (cond ((>= i (- (string-length line) 1)) #f)
              (in-string
               (cond ((char=? (string-ref line i) #\\) (loop (+ i 2) #t))
                     ((char=? (string-ref line i) #\") (loop (+ i 1) #f))
                     (else (loop (+ i 1) #t))))
              ((char=? (string-ref line i) #\") (loop (+ i 1) #t))
              ((and (char=? (string-ref line i) #\#) (< (+ i 1) (string-length line))
                    (char=? (string-ref line (+ i 1)) #\\))
               (loop (+ i 3) #f))
              ((and (char=? (string-ref line i) #\;) (char=? (string-ref line (+ i 1)) #\;))
               (string-trim-both (substring line (+ i 2) (string-length line))))
              (else (loop (+ i 1) #f)))))

    ;; --- the test program ---------------------------------------------------------

    (define (import-form? f) (and (pair? f) (eq? (car f) 'import)))

    (define (test-name id line) (string-append id ".md:" (number->string line)))

    (define (emit-form f id out)
      (let ((form (car f)) (line (cadr f)) (check (caddr f)))
        (cond ((not check) (write form out))
              ((eq? (car check) 'value)
               (write `(test-equal ,(test-name id line) ',(cadr check) ,form) out))
              ((eq? (car check) 'error)
               (write `(test-error ,(test-name id line) ,form) out))
              (else
               (write `(test-equal ,(test-name id line) ,(cadr check)
                                   (%tutorial-output (lambda () ,form)))
                      out)))
        (newline out)))

    (define (write-test-program t out)
      (let* ((id (tutorial-id t))
             (forms (append-map block-forms (filter tested-block? (tutorial-blocks t))))
             (imports (append-map (lambda (f) (cdar f))
                                  (filter (lambda (f) (import-form? (car f))) forms)))
             (body (remove (lambda (f) (import-form? (car f))) forms)))
        (display ";; Generated by update-scheme-files.scm from documentation/tutorials/" out)
        (display id out)
        (display ".md: do not edit.\n" out)
        (write `(import ,@(delete-duplicates
                           (append imports '((scheme base) (scm test)))))
               out)
        (newline out)
        (write '(test-runner-factory scm-test-runner) out)
        (newline out)
        ;; output of a thunk, without its trailing newline
        (write '(define (%tutorial-output thunk)
                  (let ((p (open-output-string)))
                    (parameterize ((current-output-port p)) (thunk))
                    (let ((s (get-output-string p)))
                      (if (and (> (string-length s) 0)
                               (char=? (string-ref s (- (string-length s) 1)) #\newline))
                          (substring s 0 (- (string-length s) 1))
                          s))))
               out)
        (newline out)
        (write `(test-begin ,(string-append "tutorial-" id)) out)
        (newline out)
        (for-each (lambda (f) (emit-form f id out)) body)
        (write `(test-end ,(string-append "tutorial-" id)) out)
        (newline out)))

    (define (test-file-name id)
      (string-append "tests_tutorial_"
                     (list->string (map (lambda (c) (if (char=? c #\-) #\_ c))
                                        (string->list id)))
                     ".scm"))

    ;; Writes tests-dir/tests_tutorial_<id>.scm for each tutorial in
    ;; tutorials-dir that has tested code, removes stale ones; -> the
    ;; written file names
    (define (generate-tutorial-tests tutorials-dir tests-dir)
      (let* ((files (filter (lambda (f) (and (string-suffix? ".md" f)
                                             (not (string=? f "README.md"))))
                            (directory-files tutorials-dir)))
             (written
              (filter-map
               (lambda (f)
                 (let ((t (read-tutorial (join-path tutorials-dir f))))
                   (and (any tested-block? (tutorial-blocks t))
                        (let ((name (test-file-name (tutorial-id t))))
                          (call-with-output-file (join-path tests-dir name)
                            (lambda (out) (write-test-program t out)))
                          name))))
               (list-sort-strings files))))
        (for-each (lambda (f)
                    (when (and (string-prefix? "tests_tutorial_" f)
                               (not (member f written)))
                      (delete-file (join-path tests-dir f))))
                  (directory-files tests-dir))
        written))

    (define (list-sort-strings l)
      (let loop ((l l) (acc '()))
        (if (null? l)
            acc
            (loop (cdr l)
                  (let ins ((acc acc))
                    (cond ((null? acc) (list (car l)))
                          ((string<? (car l) (car acc)) (cons (car l) acc))
                          (else (cons (car acc) (ins (cdr acc))))))))))))

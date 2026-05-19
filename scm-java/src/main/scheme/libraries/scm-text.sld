(define-library (scm text)
  (import (scm core)
          (scheme base)
          (scheme file)
          (scheme write)
          (scm fs)
          (scm string)
          (scm system)
          (srfi 1)
          (srfi 13)
          (srfi 132))
  (export awk
          cat
          cut
          diff
          grep
          head
          hexdump
          sed
          sort-lines
          tail
          tee
          tr
          uniq
          wc)
  (begin

    (define (%has-flag? opts sym)
      (let loop ((o opts))
        (cond ((null? o) #f)
              ((eq? (car o) sym) #t)
              (else (loop (cdr o))))))

    (define (%opt-value opts sym default)
      (let loop ((o opts))
        (cond ((null? o) default)
              ((and (pair? (car o)) (eq? (car (car o)) sym)) (cdr (car o)))
              (else (loop (cdr o))))))

    (define (%read-all-lines port)
      (let loop ((acc '()))
        (let ((l (read-line port)))
          (if (eof-object? l)
              (reverse acc)
              (loop (cons l acc))))))

    (define (%lines-from src)
      "Coerce src to a list of lines.
src may be a list of strings, a string filename, or an input port."
      (cond
        ((list? src) src)
        ((input-port? src) (%read-all-lines src))
        ((string? src)
         (call-with-port (open-input-file src) %read-all-lines))
        (else (error "scm text: cannot read lines from" src))))

    (define (%lower-string s)
      (string-downcase s))

    (define (%line-matches? line pat ci? fixed?)
      (let ((l (if ci? (%lower-string line) line))
            (p (if ci? (%lower-string pat) pat)))
        ;; In all cases we use substring search. With shell-out (see grep),
        ;; full regex semantics are delegated to native grep; the pure path
        ;; supports literal patterns only.
        (and (string-contains l p) #t)))

    (define (grep pattern src . opts)
      "Syntax: (grep pattern src [option ...])
Library: (scm text)
Description: Returns the list of lines in src matching pattern. src may
  be a filename string, a list of strings, or an input port. Options:
  'ignore-case (-i), 'invert-match (-v), 'line-number (-n) (returns
  (list line-no line) pairs), 'count (-c) (returns integer match count),
  'fixed-strings (-F) (literal match; this is also the default in pure
  mode), 'pure (force pure-Scheme path).
  When 'pure is not set and the native grep command is on PATH and src
  is a filename, grep shells out to it for full POSIX regex support.
Example:
  (grep \"ERROR\" \"log.txt\" 'ignore-case 'line-number)"
      (let ((pure? (%has-flag? opts 'pure))
            (native (which "grep")))
        (if (and (not pure?) native (string? src))
            (grep/native native pattern src opts)
            (grep/scheme pattern src opts))))

    (define (grep/scheme pattern src opts)
      (let* ((ci?     (%has-flag? opts 'ignore-case))
             (invert? (%has-flag? opts 'invert-match))
             (nums?   (%has-flag? opts 'line-number))
             (count?  (%has-flag? opts 'count))
             (fixed?  (or (%has-flag? opts 'fixed-strings) #t))
             (lines   (%lines-from src))
             (matched
              (let loop ((ls lines) (i 1) (acc '()))
                (cond
                  ((null? ls) (reverse acc))
                  (else
                   (let* ((line (car ls))
                          (m? (%line-matches? line pattern ci? fixed?))
                          (keep? (if invert? (not m?) m?)))
                     (loop (cdr ls) (+ i 1)
                           (if keep?
                               (cons (if nums? (list i line) line) acc)
                               acc))))))))
        (if count? (length matched) matched)))

    (define (grep/native native pattern file opts)
      (let* ((ci?     (%has-flag? opts 'ignore-case))
             (invert? (%has-flag? opts 'invert-match))
             (nums?   (%has-flag? opts 'line-number))
             (count?  (%has-flag? opts 'count))
             (fixed?  (%has-flag? opts 'fixed-strings))
             (args    (list native)))
        (let* ((args (if ci?     (append args '("-i")) args))
               (args (if invert? (append args '("-v")) args))
               (args (if fixed?  (append args '("-F")) args))
               (args (if (or nums? count?) (append args '("-n")) args))
               (args (append args (list "--" pattern file)))
               (r (run-program/capture args)))
          (if (or (not (pair? r))
                  (and (not (zero? (car r))) (not (= 1 (car r)))))
              (if count? 0 '())
              (let* ((out (cadr r))
                     (lns (if (string=? out "")
                              '()
                              (let ((all (string-split out "\n")))
                                ;; drop trailing empty from final newline
                                (if (and (not (null? all))
                                         (string=? (last all) ""))
                                    (drop-right all 1)
                                    all)))))
                (cond
                  (count? (length lns))
                  (nums?
                   (map (lambda (l)
                          (let ((sep (string-index l #\:)))
                            (if sep
                                (list (string->number (substring l 0 sep))
                                      (substring l (+ sep 1) (string-length l)))
                                (list 0 l))))
                        lns))
                  (else lns)))))))

    (define (sed pattern replacement src . opts)
      "Syntax: (sed pattern replacement src [option ...])
Library: (scm text)
Description: Substitutes pattern with replacement in each line of src.
  Options: 'global (g flag, replace all occurrences per line; default is
  first occurrence only), 'ignore-case (i flag), 'pure (force pure path).
  When the native sed command is on PATH and 'pure is not set, sed shells
  out to it. The pure path treats pattern as a literal string.
Example:
  (sed \"foo\" \"bar\" \"in.txt\" 'global)"
      (let ((pure? (%has-flag? opts 'pure))
            (native (which "sed")))
        (if (and (not pure?) native (string? src))
            (sed/native native pattern replacement src opts)
            (sed/scheme pattern replacement src opts))))

    (define (%escape-sed-delim s)
      (string-replace-all s "|" "\\|"))

    (define (string-replace-all s from to)
      (let* ((flen (string-length from))
             (slen (string-length s)))
        (if (zero? flen)
            s
            (let loop ((i 0) (out '()))
              (cond
                ((> (+ i flen) slen)
                 (apply string-append (reverse (cons (substring s i slen) out))))
                ((string=? (substring s i (+ i flen)) from)
                 (loop (+ i flen) (cons to out)))
                (else
                 (loop (+ i 1)
                       (cons (string (string-ref s i)) out))))))))

    (define (sed/native native pattern replacement file opts)
      (let* ((global? (%has-flag? opts 'global))
             (ci?     (%has-flag? opts 'ignore-case))
             (flags   (string-append (if global? "g" "") (if ci? "i" "")))
             (expr    (string-append "s|"
                                     (%escape-sed-delim pattern)
                                     "|"
                                     (%escape-sed-delim replacement)
                                     "|" flags))
             (r (run-program/capture (list native expr file))))
        (if (and (pair? r) (zero? (car r)))
            (let* ((out (cadr r))
                   (lns (string-split out "\n")))
              (if (and (not (null? lns))
                       (string=? (last lns) ""))
                  (drop-right lns 1)
                  lns))
            (error "sed: native sed failed" r))))

    (define (sed/scheme pattern replacement src opts)
      (let ((global? (%has-flag? opts 'global))
            (lines (%lines-from src)))
        (map (lambda (l)
               (if global?
                   (string-replace-all l pattern replacement)
                   (let ((i (string-contains l pattern)))
                     (if i
                         (string-append (substring l 0 i)
                                        replacement
                                        (substring l
                                                   (+ i (string-length pattern))
                                                   (string-length l)))
                         l))))
             lines)))

    (define (head src . opts)
      "Syntax: (head src [option ...])
Library: (scm text)
Description: Returns the first n lines of src (default 10). Options:
  '(lines . n) sets the count.
Example:
  (head \"log.txt\" '(lines . 5))"
      (let ((n (%opt-value opts 'lines 10))
            (lines (%lines-from src)))
        (if (<= (length lines) n) lines (take lines n))))

    (define (tail src . opts)
      "Syntax: (tail src [option ...])
Library: (scm text)
Description: Returns the last n lines of src (default 10). Options:
  '(lines . n) sets the count.
Example:
  (tail \"log.txt\" '(lines . 5))"
      (let* ((n (%opt-value opts 'lines 10))
             (lines (%lines-from src))
             (len (length lines)))
        (if (<= len n) lines (drop lines (- len n)))))

    (define (wc src . opts)
      "Syntax: (wc src [option ...])
Library: (scm text)
Description: Returns an alist with keys lines, words, chars for src.
  Options: 'lines-only ('-l), 'words-only ('-w), 'chars-only ('-c) return
  just that integer instead of the full alist.
Example:
  (wc \"log.txt\") => ((lines . 1234) (words . 9876) (chars . 54321))"
      (let* ((lines (%lines-from src))
             (line-count (length lines))
             (word-count
              (apply + (map (lambda (l) (length (string-split l " ")))
                            lines)))
             (char-count
              (apply + (map (lambda (l) (+ 1 (string-length l))) lines))))
        (cond
          ((%has-flag? opts 'lines-only) line-count)
          ((%has-flag? opts 'words-only) word-count)
          ((%has-flag? opts 'chars-only) char-count)
          (else (list (cons 'lines line-count)
                      (cons 'words word-count)
                      (cons 'chars char-count))))))

    (define (cat . srcs)
      "Syntax: (cat src ...)
Library: (scm text)
Description: Returns the concatenated contents of all src arguments as a
  single string, joining lines with newline. Each src is a filename, port,
  or list of strings.
Example:
  (cat \"a.txt\" \"b.txt\")"
      (string-join
        (apply append (map %lines-from srcs))
        "\n"))

    (define (cut src . opts)
      "Syntax: (cut src [option ...])
Library: (scm text)
Description: Selects fields from each line of src. Options:
  '(fields . (n ...)) — 1-based field indices to keep (required);
  '(delimiter . str) — field separator (default tab).
Example:
  (cut \"/etc/passwd\" '(fields . (1 3)) '(delimiter . \":\"))"
      (let* ((fields (%opt-value opts 'fields '()))
             (delim  (%opt-value opts 'delimiter "\t"))
             (lines  (%lines-from src)))
        (map (lambda (l)
               (let* ((parts (string-split l delim))
                      (n (length parts)))
                 (string-join
                  (filter-map
                   (lambda (i)
                     (if (and (>= i 1) (<= i n))
                         (list-ref parts (- i 1))
                         #f))
                   fields)
                  delim)))
             lines)))

    (define (sort-lines src . opts)
      "Syntax: (sort-lines src [option ...])
Library: (scm text)
Description: Returns the lines of src sorted lexicographically. Options:
  'reverse (-r), 'numeric (-n), 'unique (-u).
  Named sort-lines (not sort) to avoid clashing with srfi 132 sort.
Example:
  (sort-lines \"names.txt\" 'reverse)"
      (let* ((lines (%lines-from src))
             (numeric? (%has-flag? opts 'numeric))
             (reverse? (%has-flag? opts 'reverse))
             (unique?  (%has-flag? opts 'unique))
             (cmp (if numeric?
                      (lambda (a b)
                        (let ((na (string->number a))
                              (nb (string->number b)))
                          (if (and na nb)
                              (if reverse? (> na nb) (< na nb))
                              (if reverse? (string>? a b) (string<? a b)))))
                      (if reverse?
                          (lambda (a b) (string>? a b))
                          (lambda (a b) (string<? a b)))))
             (sorted (list-sort cmp lines)))
        (if unique? (uniq sorted) sorted)))

    (define (uniq lines)
      "Syntax: (uniq lines)
Library: (scm text)
Description: Returns lines with consecutive duplicates collapsed to a
  single entry. Matches the behavior of Linux uniq (input should usually
  be sorted first).
Example:
  (uniq '(\"a\" \"a\" \"b\" \"a\")) => (\"a\" \"b\" \"a\")"
      (cond
        ((null? lines) '())
        ((null? (cdr lines)) lines)
        (else
         (let loop ((prev (car lines)) (rest (cdr lines)) (acc (list (car lines))))
           (cond
             ((null? rest) (reverse acc))
             ((string=? (car rest) prev)
              (loop prev (cdr rest) acc))
             (else
              (loop (car rest) (cdr rest) (cons (car rest) acc))))))))

    (define (tr from to . opts)
      "Syntax: (tr from to [option ...])
Library: (scm text)
Description: Returns a procedure that translates characters in a string:
  each char in `from` is replaced by the char at the same index in `to`.
  When called on a string, returns the translated string. Option 'delete
  drops chars in `from` instead (to may be \"\").
Example:
  ((tr \"abc\" \"xyz\") \"banana\") => \"yxnxnx\""
      (let ((delete? (%has-flag? opts 'delete))
            (from-len (string-length from))
            (to-len   (string-length to)))
        (lambda (s)
          (let* ((n (string-length s))
                 (out (make-string n)))
            (let loop ((i 0) (j 0))
              (cond
                ((= i n) (substring out 0 j))
                (else
                 (let* ((ch (string-ref s i))
                        (k (string-index from ch)))
                   (cond
                     ((and k delete?)
                      (loop (+ i 1) j))
                     (k
                      (let ((rep (if (< k to-len)
                                     (string-ref to k)
                                     (string-ref to (- to-len 1)))))
                        (string-set! out j rep)
                        (loop (+ i 1) (+ j 1))))
                     (else
                      (string-set! out j ch)
                      (loop (+ i 1) (+ j 1))))))))))))

    (define (hexdump bv . opts)
      "Syntax: (hexdump bv [option ...])
Library: (scm text)
Description: Formats a bytevector as a canonical hex+ASCII dump (similar
  to xxd or hexdump -C), returning a string. Options:
    '(width . n)    — bytes per row (default 16)
    '(offset . n)   — starting offset for the address column (default 0)
    'no-ascii       — omit the trailing ASCII gutter
Example:
  (display (hexdump (string->utf8 \"hello world\")))"
      (let* ((width    (%opt-value opts 'width 16))
             (offset   (%opt-value opts 'offset 0))
             (no-ascii (%has-flag? opts 'no-ascii))
             (n        (bytevector-length bv))
             (hex      "0123456789abcdef")
             (out      (open-output-string)))
        (define (hex2 b)
          (write-char (string-ref hex (quotient b 16)) out)
          (write-char (string-ref hex (modulo b 16)) out))
        (define (addr a)
          (let loop ((shift 28))
            (when (>= shift 0)
              (write-char
                (string-ref hex (modulo (quotient a (expt 16 (quotient shift 4))) 16))
                out)
              (loop (- shift 4)))))
        (let row ((i 0))
          (when (< i n)
            (addr (+ offset i))
            (write-char #\space out)
            (write-char #\space out)
            (let pad ((j 0))
              (when (< j width)
                (cond
                  ((< (+ i j) n)
                   (hex2 (bytevector-u8-ref bv (+ i j)))
                   (write-char #\space out))
                  (else
                   (write-char #\space out)
                   (write-char #\space out)
                   (write-char #\space out)))
                (pad (+ j 1))))
            (unless no-ascii
              (write-char #\| out)
              (let ascii ((j 0))
                (when (and (< j width) (< (+ i j) n))
                  (let ((b (bytevector-u8-ref bv (+ i j))))
                    (write-char (if (and (>= b 32) (< b 127))
                                    (integer->char b)
                                    #\.)
                                out))
                  (ascii (+ j 1))))
              (write-char #\| out))
            (newline out)
            (row (+ i width))))
        (get-output-string out)))

    (define (awk action src . opts)
      "Syntax: (awk action src [option ...])
Library: (scm text)
Description: For each line of src, splits the line into fields and calls
  action with three arguments: the field list, the 1-based line number,
  and the original line. Returns the list of action results (with #f
  results filtered out, matching awk's pattern-action style where lines
  without a print produce no output).
  Options:
    '(delimiter . str) — field separator (default any run of whitespace)
    '(filter . pred)   — only call action when (pred fields line-no line)
                         returns true; equivalent to an awk pattern
Example:
  ;; print second field of each line
  (awk (lambda (fs n l) (list-ref fs 1)) \"data.tsv\")
  ;; filter and reformat /etc/passwd: name:uid for shells of /bin/bash
  (awk (lambda (fs n l)
         (string-append (list-ref fs 0) \":\" (list-ref fs 2)))
       \"/etc/passwd\"
       '(delimiter . \":\")
       `(filter . ,(lambda (fs n l)
                     (and (> (length fs) 6)
                          (string=? (list-ref fs 6) \"/bin/bash\")))))"
      (let* ((delim  (%opt-value opts 'delimiter #f))
             (filter (%opt-value opts 'filter
                                 (lambda (fs n l) #t)))
             (lines  (%lines-from src))
             (split  (if delim
                         (lambda (l) (string-split l delim))
                         awk-whitespace-split)))
        (let loop ((ls lines) (n 1) (acc '()))
          (cond
            ((null? ls) (reverse acc))
            (else
             (let* ((line (car ls))
                    (fs (split line))
                    (keep? (filter fs n line)))
               (loop (cdr ls) (+ n 1)
                     (if keep?
                         (let ((r (action fs n line)))
                           (if r (cons r acc) acc))
                         acc))))))))

    (define (awk-whitespace-split s)
      ;; Split on runs of spaces or tabs; mirror awk's default behavior:
      ;; leading whitespace is consumed (no empty leading field).
      (let ((n (string-length s)))
        (let loop ((i 0) (start -1) (acc '()))
          (cond
            ((>= i n)
             (reverse (if (>= start 0) (cons (substring s start i) acc) acc)))
            ((or (char=? (string-ref s i) #\space)
                 (char=? (string-ref s i) #\tab))
             (if (>= start 0)
                 (loop (+ i 1) -1 (cons (substring s start i) acc))
                 (loop (+ i 1) -1 acc)))
            (else
             (loop (+ i 1) (if (>= start 0) start i) acc))))))

    (define (tee text . files)
      "Syntax: (tee text file ...)
Library: (scm text)
Description: Writes text (a string, or a list of strings joined by
  newline) to each file path, and returns text. Mirrors `tee` reading
  stdin and writing to multiple destinations.
Example:
  (tee \"hello\\n\" \"/tmp/a\" \"/tmp/b\")"
      (let ((content (if (string? text)
                         text
                         (string-join text "\n"))))
        (for-each
          (lambda (f)
            (call-with-port (open-output-file f)
              (lambda (p) (write-string content p))))
          files)
        content))

    (define (diff a b . opts)
      "Syntax: (diff a b [option ...])
Library: (scm text)
Description: Compares two text inputs a and b and returns a unified-diff
  string (or #t when 'brief and inputs are identical, #f when different).
  a and b may each be a filename string, an input port, or a list of
  lines. Options:
    'unified                 — produce unified diff (default; -u)
    'brief                   — return #t/#f only (-q)
    'ignore-case             — case-insensitive comparison (-i)
    'ignore-whitespace       — ignore whitespace differences (-w, native only)
    '(context-lines . n)     — n lines of context (default 3, -U n)
    '(label-a . str)         — label for file a in the header
    '(label-b . str)         — label for file b in the header
    'pure                    — force pure-Scheme path (LCS-based)
  When the native diff command is on PATH and both inputs are filenames,
  diff shells out for full feature parity.
Example:
  (diff \"old.txt\" \"new.txt\")
  (diff a-lines b-lines 'brief)"
      (let ((pure? (%has-flag? opts 'pure))
            (native (which "diff")))
        (if (and (not pure?) native (string? a) (string? b))
            (diff/native native a b opts)
            (diff/scheme (%lines-from a) (%lines-from b) opts))))

    (define (diff/native native a b opts)
      (let* ((brief?  (%has-flag? opts 'brief))
             (ci?     (%has-flag? opts 'ignore-case))
             (iw?     (%has-flag? opts 'ignore-whitespace))
             (ctx     (%opt-value opts 'context-lines 3))
             (args (append
                     (list native)
                     (if brief? (list "-q")
                         (list (string-append "-U" (number->string ctx))))
                     (if ci? (list "-i") '())
                     (if iw? (list "-w") '())
                     (list a b)))
             (r (run-program/capture args)))
        (cond
          ((not (pair? r)) (if brief? #f ""))
          (brief? (zero? (car r)))
          (else (cadr r)))))

    (define (diff/scheme a-lines b-lines opts)
      (let* ((brief? (%has-flag? opts 'brief))
             (ci?    (%has-flag? opts 'ignore-case))
             (ctx    (%opt-value opts 'context-lines 3))
             (la     (%opt-value opts 'label-a "a"))
             (lb     (%opt-value opts 'label-b "b"))
             (norm   (if ci?
                         (lambda (s) (string-downcase s))
                         (lambda (s) s)))
             (a-key  (list->vector (map norm a-lines)))
             (b-key  (list->vector (map norm b-lines)))
             (a-vec  (list->vector a-lines))
             (b-vec  (list->vector b-lines))
             (edits  (diff-lcs-edits a-key b-key a-vec b-vec)))
        (cond
          (brief?
           (not (any (lambda (e) (not (eq? (car e) 'eq))) edits)))
          ((null? (filter (lambda (e) (not (eq? (car e) 'eq))) edits)) "")
          (else (diff-format-unified edits ctx la lb)))))

    (define (diff-lcs-edits a-key b-key a-vec b-vec)
      ;; Returns a list of edit entries (op . line) where op is 'eq 'del 'add.
      (let* ((m (vector-length a-key))
             (n (vector-length b-key))
             (dp (make-vector (+ m 1))))
        ;; Allocate rows
        (let init ((i 0))
          (when (<= i m)
            (vector-set! dp i (make-vector (+ n 1) 0))
            (init (+ i 1))))
        ;; Fill table
        (let outer ((i 0))
          (when (< i m)
            (let inner ((j 0))
              (when (< j n)
                (vector-set!
                  (vector-ref dp (+ i 1)) (+ j 1)
                  (if (string=? (vector-ref a-key i) (vector-ref b-key j))
                      (+ 1 (vector-ref (vector-ref dp i) j))
                      (let ((up   (vector-ref (vector-ref dp i) (+ j 1)))
                            (left (vector-ref (vector-ref dp (+ i 1)) j)))
                        (if (>= up left) up left))))
                (inner (+ j 1))))
            (outer (+ i 1))))
        ;; Backtrack
        (let walk ((i m) (j n) (acc '()))
          (cond
            ((and (> i 0) (> j 0)
                  (string=? (vector-ref a-key (- i 1)) (vector-ref b-key (- j 1))))
             (walk (- i 1) (- j 1)
                   (cons (cons 'eq (vector-ref a-vec (- i 1))) acc)))
            ((and (> j 0)
                  (or (= i 0)
                      (>= (vector-ref (vector-ref dp i) (- j 1))
                          (vector-ref (vector-ref dp (- i 1)) j))))
             (walk i (- j 1)
                   (cons (cons 'add (vector-ref b-vec (- j 1))) acc)))
            ((> i 0)
             (walk (- i 1) j
                   (cons (cons 'del (vector-ref a-vec (- i 1))) acc)))
            (else acc)))))

    (define (diff-format-unified edits ctx la lb)
      ;; Tag each edit with its 1-based position in a and b.
      (let* ((tagged
              (let walk ((es edits) (ai 1) (bi 1) (acc '()))
                (cond
                  ((null? es) (reverse acc))
                  (else
                   (let* ((e (car es))
                          (op (car e))
                          (line (cdr e)))
                     (walk (cdr es)
                           (if (eq? op 'add) ai (+ ai 1))
                           (if (eq? op 'del) bi (+ bi 1))
                           (cons (list op line ai bi) acc)))))))
             (tv (list->vector tagged))
             (n (vector-length tv)))
        ;; Find change indices.
        (define (change-at? i)
          (and (< i n) (not (eq? (car (vector-ref tv i)) 'eq))))
        ;; Build hunks.
        (let build ((i 0) (hunks '()))
          (cond
            ((>= i n) (diff-emit-hunks (reverse hunks) la lb))
            ((not (change-at? i)) (build (+ i 1) hunks))
            (else
             (let* ((hstart (max 0 (- i ctx)))
                    ;; Find end: extend while changes appear within 2*ctx
                    (hend (let extend ((k i) (last-change i))
                            (cond
                              ((>= k n) (min (- n 1) (+ last-change ctx)))
                              ((change-at? k) (extend (+ k 1) k))
                              ((<= (- k last-change) ctx) (extend (+ k 1) last-change))
                              (else (min (- n 1) (+ last-change ctx)))))))
               (build (+ hend 1)
                      (cons (diff-make-hunk tv hstart hend) hunks))))))))

    (define (diff-make-hunk tv hstart hend)
      ;; Return list of tagged edits in [hstart, hend].
      (let loop ((k hstart) (acc '()))
        (if (> k hend)
            (reverse acc)
            (loop (+ k 1) (cons (vector-ref tv k) acc)))))

    (define (diff-emit-hunks hunks la lb)
      (let ((header (string-append "--- " la "\n+++ " lb "\n")))
        (string-append
          header
          (apply string-append
                 (map diff-emit-hunk hunks)))))

    (define (diff-emit-hunk hunk)
      ;; hunk = list of (op line ai bi)
      (let* ((a-first (let loop ((h hunk))
                       (cond ((null? h) 1)
                             ((eq? (car (car h)) 'add) (loop (cdr h)))
                             (else (list-ref (car h) 2)))))
             (b-first (let loop ((h hunk))
                       (cond ((null? h) 1)
                             ((eq? (car (car h)) 'del) (loop (cdr h)))
                             (else (list-ref (car h) 3)))))
             (a-count (length (filter (lambda (e)
                                        (not (eq? (car e) 'add)))
                                      hunk)))
             (b-count (length (filter (lambda (e)
                                        (not (eq? (car e) 'del)))
                                      hunk)))
             (head (string-append
                     "@@ -" (number->string a-first) "," (number->string a-count)
                     " +" (number->string b-first) "," (number->string b-count)
                     " @@\n")))
        (string-append
          head
          (apply string-append
                 (map (lambda (e)
                        (let ((op (car e))
                              (line (cadr e)))
                          (string-append
                            (cond ((eq? op 'eq)  " ")
                                  ((eq? op 'del) "-")
                                  (else          "+"))
                            line
                            "\n")))
                      hunk)))))))

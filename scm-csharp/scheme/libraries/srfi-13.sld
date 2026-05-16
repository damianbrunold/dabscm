(define-library (srfi 13)
  (import (scheme base) (scheme char) (srfi 8) (srfi 14) (srfi 151))
  (export ;; Re-exports from (scheme base)
          string? make-string string string-length string-ref
          string-set! string-fill! string-copy string-copy!
          string->list list->string string-append
          string-map string-for-each
          ;; Re-exports from (scheme char)
          string-upcase string-downcase
          ;; Predicates
          string-null?
          string-every
          string-any
          ;; Comparison
          string-compare
          string-compare-ci
          string= string<> string< string> string<= string>=
          string-ci= string-ci<> string-ci< string-ci> string-ci<= string-ci>=
          ;; Constructors
          string-tabulate
          string-unfold
          string-unfold-right
          reverse-list->string
          substring/shared
          ;; Search
          string-index
          string-index-right
          string-skip
          string-skip-right
          string-contains
          string-contains-ci
          string-count
          ;; Selectors
          string-take
          string-drop
          string-take-right
          string-drop-right
          ;; Trim
          string-trim
          string-trim-right
          string-trim-both
          ;; Prefix/suffix
          string-prefix?
          string-prefix-ci?
          string-suffix?
          string-suffix-ci?
          string-prefix-length
          string-prefix-length-ci
          string-suffix-length
          string-suffix-length-ci
          ;; Concat/join
          string-concatenate
          string-concatenate/shared
          string-append/shared
          string-concatenate-reverse
          string-concatenate-reverse/shared
          string-join
          ;; Fold/map
          string-fold
          string-fold-right
          string-map!
          ;; For-each
          string-for-each-index
          ;; Reverse
          string-reverse
          string-reverse!
          ;; Case mapping
          string-titlecase
          string-titlecase!
          string-upcase!
          string-downcase!
          ;; Replace
          string-replace
          ;; Padding
          string-pad
          string-pad-right
          ;; Replicate
          xsubstring
          string-xcopy!
          ;; Tokenize / Filter / Delete
          string-tokenize
          string-filter
          string-delete
          ;; Hash
          string-hash
          string-hash-ci
          ;; Low-level
          string-parse-start+end
          string-parse-final-start+end
          let-string-start+end
          check-substring-spec
          substring-spec-ok?
          make-kmp-restart-vector
          kmp-step
          string-kmp-partial-search)
  (begin

    ;; Based on the SRFI-13 reference implementation by Olin Shivers.
    ;; See ACKNOWLEDGMENTS.md for details.

    ;; --- Internal helpers ---

    (define (check-arg pred val caller)
      (if (pred val) val (error "Bad argument" val caller)))

    ;; --- Support for START/END substring specs ---

    (define-syntax let-string-start+end
      (syntax-rules ()
        ((let-string-start+end (start end) proc s-exp args-exp body ...)
         (receive (start end) (string-parse-final-start+end proc s-exp args-exp)
           body ...))
        ((let-string-start+end (start end rest) proc s-exp args-exp body ...)
         (receive (rest start end) (string-parse-start+end proc s-exp args-exp)
           body ...))))

    (define-syntax let-string-start+end2
      (syntax-rules ()
        ((l-s-s+e2 (start1 end1 start2 end2) proc s1 s2 args body ...)
         (let ((procv proc))
           (let-string-start+end (start1 end1 rest) procv s1 args
             (let-string-start+end (start2 end2) procv s2 rest
               body ...))))))

    (define (string-parse-start+end proc s args)
      "Syntax: (string-parse-start+end proc s rest)
Library: (srfi 13)
Description: Validates and extracts start and end indices from the rest argument list.
Returns three values: the remaining args, start, and end.
Example:
  (string-parse-start+end 'my-proc \"hello\" '(1 4 extra)) => (extra) 1 4"
      (if (not (string? s)) (error "Non-string value" proc s))
      (let ((slen (string-length s)))
        (if (pair? args)
            (let ((start (car args))
                  (args (cdr args)))
              (if (and (integer? start) (exact? start) (>= start 0))
                  (receive (end args)
                      (if (pair? args)
                          (let ((end (car args))
                                (args (cdr args)))
                            (if (and (integer? end) (exact? end) (<= end slen))
                                (values end args)
                                (error "Illegal substring END spec" proc end s)))
                          (values slen args))
                    (if (<= start end) (values args start end)
                        (error "Illegal substring START/END spec"
                               proc start end s)))
                  (error "Illegal substring START spec" proc start s)))
            (values '() 0 slen))))

    (define (string-parse-final-start+end proc s args)
      "Syntax: (string-parse-final-start+end proc s rest)
Library: (srfi 13)
Description: Like string-parse-start+end but signals an error if extra args remain.
Example:
  (string-parse-final-start+end 'my-proc \"hello\" '(1 4)) => 1 and 4"
      (receive (rest start end) (string-parse-start+end proc s args)
        (if (pair? rest) (error "Extra arguments to procedure" proc rest)
            (values start end))))

    (define (substring-spec-ok? s start end)
      "Syntax: (substring-spec-ok? s start end)
Library: (srfi 13)
Description: Returns #t if start and end are valid substring indices for s.
Example:
  (substring-spec-ok? \"hello\" 0 5) => #t
  (substring-spec-ok? \"hello\" 3 2) => #f"
      (and (string? s)
           (integer? start) (exact? start)
           (integer? end) (exact? end)
           (<= 0 start) (<= start end) (<= end (string-length s))))

    (define (check-substring-spec proc s start end)
      "Syntax: (check-substring-spec proc s start end)
Library: (srfi 13)
Description: Signals an error if start/end are not valid substring bounds for s.
Example:
  (check-substring-spec 'test \"hello\" 0 5) => unspecified (no error)"
      (if (not (substring-spec-ok? s start end))
          (error "Illegal substring spec." proc s start end)))

    ;; --- Internal string-copy! that handles overlap ---

    (define (%string-copy! to tstart from fstart fend)
      (if (> fstart tstart)
          (do ((i fstart (+ i 1))
               (j tstart (+ j 1)))
              ((>= i fend))
            (string-set! to j (string-ref from i)))
          (do ((i (- fend 1) (- i 1))
               (j (+ -1 tstart (- fend fstart)) (- j 1)))
              ((< i fstart))
            (string-set! to j (string-ref from i)))))

    (define (%substring/shared s start end)
      (if (and (zero? start) (= end (string-length s))) s
          (substring s start end)))

    ;; --- Primitives ---

    (define string-join     (%primitive "string-join"))
    (define string-contains (%primitive "string-contains"))
    (define %%string-prefix? (%primitive "string-prefix?"))
    (define %%string-suffix? (%primitive "string-suffix?"))

    ;; --- Predicates ---

    (define (string-null? s)
      "Syntax: (string-null? s)
Library: (srfi 13)
Description: Returns #t if s is the empty string (length 0), #f otherwise.
Example:
  (string-null? \"\") => #t
  (string-null? \"hi\") => #f"
      (zero? (string-length s)))

    ;; --- string-every / string-any ---
    ;; Dispatch on char/char-set/pred for efficiency.

    (define (string-every criterion s . maybe-start+end)
      "Syntax: (string-every criterion s [start [end]])
Library: (srfi 13)
Description: Returns #t if criterion is satisfied by every character in
s[start..end), or #f as soon as it fails.
Example:
  (string-every char-alphabetic? \"hello\") => #t
  (string-every char-alphabetic? \"hello1\") => #f"
      (let-string-start+end (start end) string-every s maybe-start+end
        (cond ((char? criterion)
               (let lp ((i start))
                 (or (>= i end)
                     (and (char=? criterion (string-ref s i))
                          (lp (+ i 1))))))
              ((char-set? criterion)
               (let lp ((i start))
                 (or (>= i end)
                     (and (char-set-contains? criterion (string-ref s i))
                          (lp (+ i 1))))))
              ((procedure? criterion)
               (or (= start end)
                   (let lp ((i start))
                     (let ((c (string-ref s i))
                           (i1 (+ i 1)))
                       (if (= i1 end) (criterion c)
                           (and (criterion c) (lp i1)))))))
              (else (error "Second param is neither char-set, char, or predicate procedure."
                           string-every criterion)))))

    (define (string-any criterion s . maybe-start+end)
      "Syntax: (string-any criterion s [start [end]])
Library: (srfi 13)
Description: Returns the first truthy value returned by criterion applied to
characters in s[start..end), or #f if it returns #f for all characters.
Example:
  (string-any char-upper-case? \"hEllo\") => #t
  (string-any char-upper-case? \"hello\") => #f"
      (let-string-start+end (start end) string-any s maybe-start+end
        (cond ((char? criterion)
               (let lp ((i start))
                 (and (< i end)
                      (or (char=? criterion (string-ref s i))
                          (lp (+ i 1))))))
              ((char-set? criterion)
               (let lp ((i start))
                 (and (< i end)
                      (or (char-set-contains? criterion (string-ref s i))
                          (lp (+ i 1))))))
              ((procedure? criterion)
               (and (< start end)
                    (let lp ((i start))
                      (let ((c (string-ref s i))
                            (i1 (+ i 1)))
                        (if (= i1 end) (criterion c)
                            (or (criterion c) (lp i1)))))))
              (else (error "Second param is neither char-set, char, or predicate procedure."
                           string-any criterion)))))

    ;; --- Constructors ---

    (define (string-tabulate proc len)
      "Syntax: (string-tabulate f n)
Library: (srfi 13)
Description: Builds a string of length n by applying f to each index 0, 1, ..., n-1 in order.
Example:
  (string-tabulate (lambda (i) (integer->char (+ i 65))) 5) => \"ABCDE\""
      (check-arg procedure? proc string-tabulate)
      (let ((s (make-string len)))
        (do ((i (- len 1) (- i 1)))
            ((< i 0))
          (string-set! s i (proc i)))
        s))

    (define (string-unfold p f g seed . base+make-final)
      "Syntax: (string-unfold p f g seed [base [make-final]])
Library: (srfi 13)
Description: Builds a string by unfolding seed left-to-right. p is the termination predicate;
f maps seed to a character; g maps seed to the next seed. Optional base string is prepended;
make-final is called on the final seed to produce a suffix string.
Example:
  (string-unfold null? car cdr '(#\\h #\\e #\\l #\\l #\\o)) => \"hello\""
      (check-arg procedure? p string-unfold)
      (check-arg procedure? f string-unfold)
      (check-arg procedure? g string-unfold)
      (let ((base (if (pair? base+make-final) (car base+make-final) ""))
            (make-final (if (and (pair? base+make-final) (pair? (cdr base+make-final)))
                            (cadr base+make-final)
                            (lambda (x) ""))))
        (let lp ((chunks '()) (nchars 0)
                 (chunk (make-string 40)) (chunk-len 40)
                 (i 0) (seed seed))
          (let lp2 ((i i) (seed seed))
            (if (not (p seed))
                (let ((c (f seed))
                      (seed (g seed)))
                  (if (< i chunk-len)
                      (begin (string-set! chunk i c)
                             (lp2 (+ i 1) seed))
                      (let* ((nchars2 (+ chunk-len nchars))
                             (chunk-len2 (min 4096 nchars2))
                             (new-chunk (make-string chunk-len2)))
                        (string-set! new-chunk 0 c)
                        (lp (cons chunk chunks) (+ nchars chunk-len)
                            new-chunk chunk-len2 1 seed))))
                ;; Done. Make the answer string & install the bits.
                (let* ((final (make-final seed))
                       (flen (string-length final))
                       (base-len (string-length base))
                       (j (+ base-len nchars i))
                       (ans (make-string (+ j flen))))
                  (%string-copy! ans j final 0 flen)
                  (let ((j (- j i)))
                    (%string-copy! ans j chunk 0 i)
                    (let lp ((j j) (chunks chunks))
                      (if (pair? chunks)
                          (let* ((chunk  (car chunks))
                                 (chunks (cdr chunks))
                                 (chunk-len (string-length chunk))
                                 (j (- j chunk-len)))
                            (%string-copy! ans j chunk 0 chunk-len)
                            (lp j chunks)))))
                  (%string-copy! ans 0 base 0 base-len)
                  ans))))))

    (define (string-unfold-right p f g seed . base+make-final)
      "Syntax: (string-unfold-right p f g seed [base [make-final]])
Library: (srfi 13)
Description: Builds a string by unfolding seed right-to-left. p is the termination predicate;
f maps seed to a character; g maps seed to the next seed. Optional base string is appended;
make-final is called on the final seed to produce a prefix string.
Example:
  (string-unfold-right null? car cdr '(#\\o #\\l #\\l #\\e #\\h)) => \"hello\""
      (let ((base (if (pair? base+make-final) (car base+make-final) ""))
            (make-final (if (and (pair? base+make-final) (pair? (cdr base+make-final)))
                            (cadr base+make-final)
                            (lambda (x) ""))))
        (let lp ((chunks '()) (nchars 0)
                 (chunk (make-string 40)) (chunk-len 40)
                 (i 40) (seed seed))
          (let lp2 ((i i) (seed seed))
            (if (not (p seed))
                (let ((c (f seed))
                      (seed (g seed)))
                  (if (> i 0)
                      (let ((i (- i 1)))
                        (string-set! chunk i c)
                        (lp2 i seed))
                      (let* ((nchars2 (+ chunk-len nchars))
                             (chunk-len2 (min 4096 nchars2))
                             (new-chunk (make-string chunk-len2))
                             (i (- chunk-len2 1)))
                        (string-set! new-chunk i c)
                        (lp (cons chunk chunks) (+ nchars chunk-len)
                            new-chunk chunk-len2 i seed))))
                ;; Done.
                (let* ((final (make-final seed))
                       (flen (string-length final))
                       (base-len (string-length base))
                       (chunk-used (- chunk-len i))
                       (j (+ base-len nchars chunk-used))
                       (ans (make-string (+ j flen))))
                  (%string-copy! ans 0 final 0 flen)
                  (%string-copy! ans flen chunk i chunk-len)
                  (let lp ((j (+ flen chunk-used)) (chunks chunks))
                    (if (pair? chunks)
                        (let* ((chunk  (car chunks))
                               (chunks (cdr chunks))
                               (chunk-len (string-length chunk)))
                          (%string-copy! ans j chunk 0 chunk-len)
                          (lp (+ j chunk-len) chunks))
                        (%string-copy! ans j base 0 base-len)))
                  ans))))))

    (define (reverse-list->string clist)
      "Syntax: (reverse-list->string lst)
Library: (srfi 13)
Description: Converts a list of characters to a string after reversing it.
Example:
  (reverse-list->string '(#\\o #\\l #\\l #\\e #\\h)) => \"hello\""
      (let* ((len (length clist))
             (s (make-string len)))
        (do ((i (- len 1) (- i 1))
             (clist clist (cdr clist)))
            ((not (pair? clist)))
          (string-set! s i (car clist)))
        s))

    (define (substring/shared s start . maybe-end)
      "Syntax: (substring/shared s start [end])
Library: (srfi 13)
Description: Returns a substring of s from start to end.
Example:
  (substring/shared \"hello\" 1 4) => \"ell\"
  (substring/shared \"hello\" 2) => \"llo\""
      (let ((end (if (pair? maybe-end) (car maybe-end) (string-length s))))
        (%substring/shared s start end)))

    ;; --- Basic iterators ---

    (define (string-map! proc s . maybe-start+end)
      "Syntax: (string-map! proc s [start [end]])
Library: (srfi 13)
Description: Applies proc to each character of s[start..end) and stores the result back.
Example:
  (let ((s (string-copy \"hello\"))) (string-map! char-upcase s) s) => \"HELLO\""
      (check-arg procedure? proc string-map!)
      (let-string-start+end (start end) string-map! s maybe-start+end
        (do ((i (- end 1) (- i 1)))
            ((< i start))
          (string-set! s i (proc (string-ref s i))))))

    (define (string-fold kons knil s . maybe-start+end)
      "Syntax: (string-fold kons knil s [start [end]])
Library: (srfi 13)
Description: Left-to-right fold over the characters of s[start..end). kons receives (char acc).
Example:
  (string-fold cons '() \"hello\") => (#\\o #\\l #\\l #\\e #\\h)"
      (check-arg procedure? kons string-fold)
      (let-string-start+end (start end) string-fold s maybe-start+end
        (let lp ((v knil) (i start))
          (if (< i end) (lp (kons (string-ref s i) v) (+ i 1))
              v))))

    (define (string-fold-right kons knil s . maybe-start+end)
      "Syntax: (string-fold-right kons knil s [start [end]])
Library: (srfi 13)
Description: Right-to-left fold over the characters of s[start..end). kons receives (char acc).
Example:
  (string-fold-right cons '() \"hello\") => (#\\h #\\e #\\l #\\l #\\o)"
      (check-arg procedure? kons string-fold-right)
      (let-string-start+end (start end) string-fold-right s maybe-start+end
        (let lp ((v knil) (i (- end 1)))
          (if (>= i start) (lp (kons (string-ref s i) v) (- i 1))
              v))))

    (define (string-for-each-index proc s . maybe-start+end)
      "Syntax: (string-for-each-index proc s [start [end]])
Library: (srfi 13)
Description: Applies proc to each valid index of s[start..end) in order, for side effects.
Example:
  (string-for-each-index display \"hello\") ; displays 0 1 2 3 4"
      (check-arg procedure? proc string-for-each-index)
      (let-string-start+end (start end) string-for-each-index s maybe-start+end
        (let lp ((i start))
          (if (< i end) (begin (proc i) (lp (+ i 1)))))))

    ;; --- Prefix/suffix length ---
    ;; Core routines with EQ? fast paths.

    (define (%string-prefix-length s1 start1 end1 s2 start2 end2)
      (let* ((delta (min (- end1 start1) (- end2 start2)))
             (end1 (+ start1 delta)))
        (if (and (eq? s1 s2) (= start1 start2)) delta
            (let lp ((i start1) (j start2))
              (if (or (>= i end1)
                      (not (char=? (string-ref s1 i) (string-ref s2 j))))
                  (- i start1)
                  (lp (+ i 1) (+ j 1)))))))

    (define (%string-suffix-length s1 start1 end1 s2 start2 end2)
      (let* ((delta (min (- end1 start1) (- end2 start2)))
             (start1 (- end1 delta)))
        (if (and (eq? s1 s2) (= end1 end2)) delta
            (let lp ((i (- end1 1)) (j (- end2 1)))
              (if (or (< i start1)
                      (not (char=? (string-ref s1 i) (string-ref s2 j))))
                  (- (- end1 i) 1)
                  (lp (- i 1) (- j 1)))))))

    (define (%string-prefix-length-ci s1 start1 end1 s2 start2 end2)
      (let* ((delta (min (- end1 start1) (- end2 start2)))
             (end1 (+ start1 delta)))
        (if (and (eq? s1 s2) (= start1 start2)) delta
            (let lp ((i start1) (j start2))
              (if (or (>= i end1)
                      (not (char-ci=? (string-ref s1 i) (string-ref s2 j))))
                  (- i start1)
                  (lp (+ i 1) (+ j 1)))))))

    (define (%string-suffix-length-ci s1 start1 end1 s2 start2 end2)
      (let* ((delta (min (- end1 start1) (- end2 start2)))
             (start1 (- end1 delta)))
        (if (and (eq? s1 s2) (= end1 end2)) delta
            (let lp ((i (- end1 1)) (j (- end2 1)))
              (if (or (< i start1)
                      (not (char-ci=? (string-ref s1 i) (string-ref s2 j))))
                  (- (- end1 i) 1)
                  (lp (- i 1) (- j 1)))))))

    (define (string-prefix-length s1 s2 . maybe-starts+ends)
      "Syntax: (string-prefix-length s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the length of the longest common prefix of s1 and s2.
Example:
  (string-prefix-length \"abcdef\" \"abcxyz\") => 3"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-prefix-length s1 s2 maybe-starts+ends
        (%string-prefix-length s1 start1 end1 s2 start2 end2)))

    (define (string-suffix-length s1 s2 . maybe-starts+ends)
      "Syntax: (string-suffix-length s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the length of the longest common suffix of s1 and s2.
Example:
  (string-suffix-length \"xyzdef\" \"abcdef\") => 3"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-suffix-length s1 s2 maybe-starts+ends
        (%string-suffix-length s1 start1 end1 s2 start2 end2)))

    (define (string-prefix-length-ci s1 s2 . maybe-starts+ends)
      "Syntax: (string-prefix-length-ci s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-prefix-length.
Example:
  (string-prefix-length-ci \"ABCdef\" \"abcxyz\") => 3"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-prefix-length-ci s1 s2 maybe-starts+ends
        (%string-prefix-length-ci s1 start1 end1 s2 start2 end2)))

    (define (string-suffix-length-ci s1 s2 . maybe-starts+ends)
      "Syntax: (string-suffix-length-ci s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-suffix-length.
Example:
  (string-suffix-length-ci \"xyzDEF\" \"abcdef\") => 3"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-suffix-length-ci s1 s2 maybe-starts+ends
        (%string-suffix-length-ci s1 start1 end1 s2 start2 end2)))

    ;; --- Prefix/suffix predicates ---

    (define (%string-prefix? s1 start1 end1 s2 start2 end2)
      (let ((len1 (- end1 start1)))
        (and (<= len1 (- end2 start2))
             (= (%string-prefix-length s1 start1 end1 s2 start2 end2) len1))))

    (define (%string-suffix? s1 start1 end1 s2 start2 end2)
      (let ((len1 (- end1 start1)))
        (and (<= len1 (- end2 start2))
             (= len1 (%string-suffix-length s1 start1 end1 s2 start2 end2)))))

    (define (%string-prefix-ci? s1 start1 end1 s2 start2 end2)
      (let ((len1 (- end1 start1)))
        (and (<= len1 (- end2 start2))
             (= len1 (%string-prefix-length-ci s1 start1 end1 s2 start2 end2)))))

    (define (%string-suffix-ci? s1 start1 end1 s2 start2 end2)
      (let ((len1 (- end1 start1)))
        (and (<= len1 (- end2 start2))
             (= len1 (%string-suffix-length-ci s1 start1 end1 s2 start2 end2)))))

    (define (string-prefix? s1 s2 . maybe-starts+ends)
      "Syntax: (string-prefix? s1 s2 [s1-start [s1-end [s2-start [s2-end]]]])
Library: (srfi 13)
Description: Returns #t if s1 is a prefix of s2.
Example:
  (string-prefix? \"hel\" \"hello\") => #t
  (string-prefix? \"world\" \"hello\") => #f"
      (if (null? maybe-starts+ends)
          (%%string-prefix? s1 s2)
          (let-string-start+end2 (start1 end1 start2 end2)
                                 string-prefix? s1 s2 maybe-starts+ends
            (%string-prefix? s1 start1 end1 s2 start2 end2))))

    (define (string-suffix? s1 s2 . maybe-starts+ends)
      "Syntax: (string-suffix? s1 s2 [s1-start [s1-end [s2-start [s2-end]]]])
Library: (srfi 13)
Description: Returns #t if s1 is a suffix of s2.
Example:
  (string-suffix? \"llo\" \"hello\") => #t
  (string-suffix? \"hel\" \"hello\") => #f"
      (if (null? maybe-starts+ends)
          (%%string-suffix? s1 s2)
          (let-string-start+end2 (start1 end1 start2 end2)
                                 string-suffix? s1 s2 maybe-starts+ends
            (%string-suffix? s1 start1 end1 s2 start2 end2))))

    (define (string-prefix-ci? s1 s2 . maybe-starts+ends)
      "Syntax: (string-prefix-ci? s1 s2 [s1-start [s1-end [s2-start [s2-end]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-prefix?.
Example:
  (string-prefix-ci? \"HEL\" \"hello\") => #t"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-prefix-ci? s1 s2 maybe-starts+ends
        (%string-prefix-ci? s1 start1 end1 s2 start2 end2)))

    (define (string-suffix-ci? s1 s2 . maybe-starts+ends)
      "Syntax: (string-suffix-ci? s1 s2 [s1-start [s1-end [s2-start [s2-end]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-suffix?.
Example:
  (string-suffix-ci? \"LLO\" \"hello\") => #t"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-suffix-ci? s1 s2 maybe-starts+ends
        (%string-suffix-ci? s1 start1 end1 s2 start2 end2)))

    ;; --- Comparison ---

    (define (%string-compare s1 start1 end1 s2 start2 end2 proc< proc= proc>)
      (let ((size1 (- end1 start1))
            (size2 (- end2 start2)))
        (let ((match (%string-prefix-length s1 start1 end1 s2 start2 end2)))
          (if (= match size1)
              ((if (= match size2) proc= proc<) end1)
              ((if (= match size2) proc>
                   (if (char<? (string-ref s1 (+ start1 match))
                               (string-ref s2 (+ start2 match)))
                       proc< proc>))
               (+ match start1))))))

    (define (%string-compare-ci s1 start1 end1 s2 start2 end2 proc< proc= proc>)
      (let ((size1 (- end1 start1))
            (size2 (- end2 start2)))
        (let ((match (%string-prefix-length-ci s1 start1 end1 s2 start2 end2)))
          (if (= match size1)
              ((if (= match size2) proc= proc<) end1)
              ((if (= match size2) proc>
                   (if (char-ci<? (string-ref s1 (+ start1 match))
                                  (string-ref s2 (+ start2 match)))
                       proc< proc>))
               (+ start1 match))))))

    (define (string-compare s1 s2 proc< proc= proc> . maybe-starts+ends)
      "Syntax: (string-compare s1 s2 proc< proc= proc> [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Compares s1 and s2 lexicographically. Calls the appropriate proc with the mismatch index.
Example:
  (string-compare \"abc\" \"abd\" (lambda (i) 'less) (lambda (i) 'equal) (lambda (i) 'greater)) => less"
      (check-arg procedure? proc< string-compare)
      (check-arg procedure? proc= string-compare)
      (check-arg procedure? proc> string-compare)
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-compare s1 s2 maybe-starts+ends
        (%string-compare s1 start1 end1 s2 start2 end2 proc< proc= proc>)))

    (define (string-compare-ci s1 s2 proc< proc= proc> . maybe-starts+ends)
      "Syntax: (string-compare-ci s1 s2 proc< proc= proc> [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive version of string-compare.
Example:
  (string-compare-ci \"ABC\" \"abc\" (lambda (i) 'less) (lambda (i) 'equal) (lambda (i) 'greater)) => equal"
      (check-arg procedure? proc< string-compare-ci)
      (check-arg procedure? proc= string-compare-ci)
      (check-arg procedure? proc> string-compare-ci)
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-compare-ci s1 s2 maybe-starts+ends
        (%string-compare-ci s1 start1 end1 s2 start2 end2 proc< proc= proc>)))

    ;; --- Comparison operators with EQ? fast paths ---

    (define (string= s1 s2 . maybe-starts+ends)
      "Syntax: (string= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 and s2 are equal, #f otherwise.
Example:
  (string= \"abc\" \"abc\") => 3
  (string= \"abc\" \"abd\") => #f"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string= s1 s2 maybe-starts+ends
        (and (= (- end1 start1) (- end2 start2))
             (or (and (eq? s1 s2) (= start1 start2))
                 (%string-compare s1 start1 end1 s2 start2 end2
                                  (lambda (i) #f) values (lambda (i) #f))))))

    (define (string<> s1 s2 . maybe-starts+ends)
      "Syntax: (string<> s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 and s2 are not equal, #f otherwise.
Example:
  (string<> \"abc\" \"def\") => 0
  (string<> \"abc\" \"abc\") => #f"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string<> s1 s2 maybe-starts+ends
        (or (not (= (- end1 start1) (- end2 start2)))
            (and (not (and (eq? s1 s2) (= start1 start2)))
                 (%string-compare s1 start1 end1 s2 start2 end2
                                  values (lambda (i) #f) values)))))

    (define (string< s1 s2 . maybe-starts+ends)
      "Syntax: (string< s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 < s2, #f otherwise.
Example:
  (string< \"abc\" \"abd\") => 2
  (string< \"abd\" \"abc\") => #f"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string< s1 s2 maybe-starts+ends
        (if (and (eq? s1 s2) (= start1 start2))
            (< end1 end2)
            (%string-compare s1 start1 end1 s2 start2 end2
                             values (lambda (i) #f) (lambda (i) #f)))))

    (define (string> s1 s2 . maybe-starts+ends)
      "Syntax: (string> s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 > s2, #f otherwise.
Example:
  (string> \"abd\" \"abc\") => 2
  (string> \"abc\" \"abd\") => #f"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string> s1 s2 maybe-starts+ends
        (if (and (eq? s1 s2) (= start1 start2))
            (> end1 end2)
            (%string-compare s1 start1 end1 s2 start2 end2
                             (lambda (i) #f) (lambda (i) #f) values))))

    (define (string<= s1 s2 . maybe-starts+ends)
      "Syntax: (string<= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 <= s2, #f otherwise.
Example:
  (string<= \"abc\" \"abc\") => 3
  (string<= \"abc\" \"abd\") => 2"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string<= s1 s2 maybe-starts+ends
        (if (and (eq? s1 s2) (= start1 start2))
            (<= end1 end2)
            (%string-compare s1 start1 end1 s2 start2 end2
                             values values (lambda (i) #f)))))

    (define (string>= s1 s2 . maybe-starts+ends)
      "Syntax: (string>= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Returns the mismatch index if s1 >= s2, #f otherwise.
Example:
  (string>= \"abc\" \"abc\") => 3
  (string>= \"abd\" \"abc\") => 2"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string>= s1 s2 maybe-starts+ends
        (if (and (eq? s1 s2) (= start1 start2))
            (>= end1 end2)
            (%string-compare s1 start1 end1 s2 start2 end2
                             (lambda (i) #f) values values))))

    ;; --- Case-insensitive comparison operators ---

    (define (string-ci= s1 s2 . maybe-starts+ends)
      "Syntax: (string-ci= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string=.
Example:
  (string-ci= \"ABC\" \"abc\") => 3"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-ci= s1 s2 maybe-starts+ends
        (and (= (- end1 start1) (- end2 start2))
             (or (and (eq? s1 s2) (= start1 start2))
                 (%string-compare-ci s1 start1 end1 s2 start2 end2
                                     (lambda (i) #f) values (lambda (i) #f))))))

    (define (string-ci<> s1 s2 . maybe-starts+ends)
      "Syntax: (string-ci<> s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string<>.
Example:
  (string-ci<> \"abc\" \"ABC\") => #f"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-ci<> s1 s2 maybe-starts+ends
        (or (not (= (- end1 start1) (- end2 start2)))
            (and (not (and (eq? s1 s2) (= start1 start2)))
                 (%string-compare-ci s1 start1 end1 s2 start2 end2
                                     values (lambda (i) #f) values)))))

    (define (string-ci< s1 s2 . maybe-starts+ends)
      "Syntax: (string-ci< s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string<.
Example:
  (string-ci< \"abc\" \"ABD\") => 2"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-ci< s1 s2 maybe-starts+ends
        (if (and (eq? s1 s2) (= start1 start2))
            (< end1 end2)
            (%string-compare-ci s1 start1 end1 s2 start2 end2
                                values (lambda (i) #f) (lambda (i) #f)))))

    (define (string-ci> s1 s2 . maybe-starts+ends)
      "Syntax: (string-ci> s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string>.
Example:
  (string-ci> \"ABD\" \"abc\") => 2"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-ci> s1 s2 maybe-starts+ends
        (if (and (eq? s1 s2) (= start1 start2))
            (> end1 end2)
            (%string-compare-ci s1 start1 end1 s2 start2 end2
                                (lambda (i) #f) (lambda (i) #f) values))))

    (define (string-ci<= s1 s2 . maybe-starts+ends)
      "Syntax: (string-ci<= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string<=.
Example:
  (string-ci<= \"ABC\" \"abc\") => 3"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-ci<= s1 s2 maybe-starts+ends
        (if (and (eq? s1 s2) (= start1 start2))
            (<= end1 end2)
            (%string-compare-ci s1 start1 end1 s2 start2 end2
                                values values (lambda (i) #f)))))

    (define (string-ci>= s1 s2 . maybe-starts+ends)
      "Syntax: (string-ci>= s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string>=.
Example:
  (string-ci>= \"ABC\" \"abc\") => 3"
      (let-string-start+end2 (start1 end1 start2 end2)
                             string-ci>= s1 s2 maybe-starts+ends
        (if (and (eq? s1 s2) (= start1 start2))
            (>= end1 end2)
            (%string-compare-ci s1 start1 end1 s2 start2 end2
                                (lambda (i) #f) values values))))

    ;; --- Hash ---

    (define (%string-hash s char->int bound start end)
      (let ((iref (lambda (s i) (char->int (string-ref s i))))
            (mask (let lp ((i #x10000))
                    (if (>= i bound) (- i 1) (lp (+ i i))))))
        (let lp ((i start) (ans 0))
          (if (>= i end) (modulo ans bound)
              (lp (+ i 1) (bitwise-and mask (+ (* 37 ans) (iref s i))))))))

    (define (string-hash s . maybe-bound+start+end)
      "Syntax: (string-hash s [bound [start [end]]])
Library: (srfi 13)
Description: Returns a hash of s[start..end) as a non-negative integer less than bound.
Example:
  (string-hash \"hello\") => some integer
  (string-hash \"hello\" 100) => some integer < 100"
      (let* ((bound (if (pair? maybe-bound+start+end) (car maybe-bound+start+end) 4194304))
             (bound (if (zero? bound) 4194304 bound))
             (rest (if (pair? maybe-bound+start+end) (cdr maybe-bound+start+end) '())))
        (let-string-start+end (start end) string-hash s rest
          (%string-hash s char->integer bound start end))))

    (define (string-hash-ci s . maybe-bound+start+end)
      "Syntax: (string-hash-ci s [bound [start [end]]])
Library: (srfi 13)
Description: Case-insensitive string hash.
Example:
  (= (string-hash-ci \"Hello\") (string-hash-ci \"hello\")) => #t"
      (let* ((bound (if (pair? maybe-bound+start+end) (car maybe-bound+start+end) 4194304))
             (bound (if (zero? bound) 4194304 bound))
             (rest (if (pair? maybe-bound+start+end) (cdr maybe-bound+start+end) '())))
        (let-string-start+end (start end) string-hash-ci s rest
          (%string-hash s (lambda (c) (char->integer (char-downcase c)))
                        bound start end))))

    ;; --- Case mapping ---

    (define string-upcase!   string-upcase)
    (define string-downcase! string-downcase)

    (define (string-titlecase s . maybe-start+end)
      "Syntax: (string-titlecase s [start [end]])
Library: (srfi 13)
Description: Returns a titlecased copy of s[start..end): the first alphabetic character of each
word is uppercased and the rest are lowercased.
Example:
  (string-titlecase \"hello world\") => \"Hello World\""
      (let-string-start+end (start end) string-titlecase s maybe-start+end
        (let ((ans (substring s start end)))
          (%string-titlecase! ans 0 (- end start))
          ans)))

    (define (%string-titlecase! s start end)
      (let lp ((i start))
        (cond ((string-index s char-alphabetic? i end) =>
               (lambda (i)
                 (string-set! s i (char-upcase (string-ref s i)))
                 (let ((i1 (+ i 1)))
                   (cond ((string-skip s char-alphabetic? i1 end) =>
                          (lambda (j)
                            (do ((k i1 (+ k 1)))
                                ((>= k j))
                              (string-set! s k (char-downcase (string-ref s k))))
                            (lp (+ j 1))))
                         (else
                          (do ((k i1 (+ k 1)))
                              ((>= k end))
                            (string-set! s k (char-downcase (string-ref s k))))))))))))

    (define string-titlecase! string-titlecase)

    ;; --- Selectors ---

    (define (string-take s n)
      "Syntax: (string-take s n)
Library: (srfi 13)
Description: Returns the first n characters of s.
Example:
  (string-take \"hello\" 3) => \"hel\""
      (%substring/shared s 0 n))

    (define (string-take-right s n)
      "Syntax: (string-take-right s n)
Library: (srfi 13)
Description: Returns the last n characters of s.
Example:
  (string-take-right \"hello\" 3) => \"llo\""
      (let ((len (string-length s)))
        (%substring/shared s (- len n) len)))

    (define (string-drop s n)
      "Syntax: (string-drop s n)
Library: (srfi 13)
Description: Returns s with the first n characters removed.
Example:
  (string-drop \"hello\" 2) => \"llo\""
      (let ((len (string-length s)))
        (%substring/shared s n len)))

    (define (string-drop-right s n)
      "Syntax: (string-drop-right s n)
Library: (srfi 13)
Description: Returns s with the last n characters removed.
Example:
  (string-drop-right \"hello\" 2) => \"hel\""
      (%substring/shared s 0 (- (string-length s) n)))

    ;; --- Trim ---

    (define (string-trim s . criterion+start+end)
      "Syntax: (string-trim s [criterion [start [end]]])
Library: (srfi 13)
Description: Trims characters matching criterion from the left of s. Default: whitespace.
Example:
  (string-trim \"  hello  \") => \"hello  \""
      (let* ((criterion (if (pair? criterion+start+end) (car criterion+start+end) char-set:whitespace))
             (rest (if (pair? criterion+start+end) (cdr criterion+start+end) '())))
        (let-string-start+end (start end) string-trim s rest
          (cond ((string-skip s criterion start end) =>
                 (lambda (i) (%substring/shared s i end)))
                (else "")))))

    (define (string-trim-right s . criterion+start+end)
      "Syntax: (string-trim-right s [criterion [start [end]]])
Library: (srfi 13)
Description: Trims characters matching criterion from the right of s. Default: whitespace.
Example:
  (string-trim-right \"  hello  \") => \"  hello\""
      (let* ((criterion (if (pair? criterion+start+end) (car criterion+start+end) char-set:whitespace))
             (rest (if (pair? criterion+start+end) (cdr criterion+start+end) '())))
        (let-string-start+end (start end) string-trim-right s rest
          (cond ((string-skip-right s criterion start end) =>
                 (lambda (i) (%substring/shared s start (+ 1 i))))
                (else "")))))

    (define (string-trim-both s . criterion+start+end)
      "Syntax: (string-trim-both s [criterion [start [end]]])
Library: (srfi 13)
Description: Trims characters matching criterion from both sides of s. Default: whitespace.
Example:
  (string-trim-both \"  hello  \") => \"hello\""
      (let* ((criterion (if (pair? criterion+start+end) (car criterion+start+end) char-set:whitespace))
             (rest (if (pair? criterion+start+end) (cdr criterion+start+end) '())))
        (let-string-start+end (start end) string-trim-both s rest
          (cond ((string-skip s criterion start end) =>
                 (lambda (i)
                   (%substring/shared s i (+ 1 (string-skip-right s criterion i end)))))
                (else "")))))

    ;; --- Padding ---

    (define (string-pad s n . char+start+end)
      "Syntax: (string-pad s k [char [start [end]]])
Library: (srfi 13)
Description: Left-pads s[start..end) to width k using char (default: space).
Example:
  (string-pad \"42\" 5) => \"   42\"
  (string-pad \"hello\" 3) => \"llo\""
      (let* ((char (if (pair? char+start+end) (car char+start+end) #\space))
             (rest (if (pair? char+start+end) (cdr char+start+end) '())))
        (let-string-start+end (start end) string-pad s rest
          (let ((len (- end start)))
            (if (<= n len)
                (%substring/shared s (- end n) end)
                (let ((ans (make-string n char)))
                  (%string-copy! ans (- n len) s start end)
                  ans))))))

    (define (string-pad-right s n . char+start+end)
      "Syntax: (string-pad-right s k [char [start [end]]])
Library: (srfi 13)
Description: Right-pads s[start..end) to width k using char (default: space).
Example:
  (string-pad-right \"42\" 5) => \"42   \"
  (string-pad-right \"hello\" 3) => \"hel\""
      (let* ((char (if (pair? char+start+end) (car char+start+end) #\space))
             (rest (if (pair? char+start+end) (cdr char+start+end) '())))
        (let-string-start+end (start end) string-pad-right s rest
          (let ((len (- end start)))
            (if (<= n len)
                (%substring/shared s start (+ start n))
                (let ((ans (make-string n char)))
                  (%string-copy! ans 0 s start end)
                  ans))))))

    ;; --- Search: string-index, string-skip ---
    ;; Dispatch on char/char-set/pred for efficiency.

    (define (string-index str criterion . maybe-start+end)
      "Syntax: (string-index s criterion [start [end]])
Library: (srfi 13)
Description: Returns the index of the first character in s[start..end) matching criterion.
Example:
  (string-index \"hello\" #\\l) => 2
  (string-index \"hello\" char-upper-case?) => #f"
      (let-string-start+end (start end) string-index str maybe-start+end
        (cond ((char? criterion)
               (let lp ((i start))
                 (and (< i end)
                      (if (char=? criterion (string-ref str i)) i (lp (+ i 1))))))
              ((char-set? criterion)
               (let lp ((i start))
                 (and (< i end)
                      (if (char-set-contains? criterion (string-ref str i)) i (lp (+ i 1))))))
              ((procedure? criterion)
               (let lp ((i start))
                 (and (< i end)
                      (if (criterion (string-ref str i)) i (lp (+ i 1))))))
              (else (error "Second param is neither char-set, char, or predicate procedure."
                           string-index criterion)))))

    (define (string-index-right str criterion . maybe-start+end)
      "Syntax: (string-index-right s criterion [start [end]])
Library: (srfi 13)
Description: Returns the index of the last character in s[start..end) matching criterion.
Example:
  (string-index-right \"hello\" #\\l) => 3"
      (let-string-start+end (start end) string-index-right str maybe-start+end
        (cond ((char? criterion)
               (let lp ((i (- end 1)))
                 (and (>= i start)
                      (if (char=? criterion (string-ref str i)) i (lp (- i 1))))))
              ((char-set? criterion)
               (let lp ((i (- end 1)))
                 (and (>= i start)
                      (if (char-set-contains? criterion (string-ref str i)) i (lp (- i 1))))))
              ((procedure? criterion)
               (let lp ((i (- end 1)))
                 (and (>= i start)
                      (if (criterion (string-ref str i)) i (lp (- i 1))))))
              (else (error "Second param is neither char-set, char, or predicate procedure."
                           string-index-right criterion)))))

    (define (string-skip str criterion . maybe-start+end)
      "Syntax: (string-skip s criterion [start [end]])
Library: (srfi 13)
Description: Returns the index of the first character in s[start..end) NOT matching criterion.
Example:
  (string-skip \"  hello\" char-whitespace?) => 2"
      (let-string-start+end (start end) string-skip str maybe-start+end
        (cond ((char? criterion)
               (let lp ((i start))
                 (and (< i end)
                      (if (char=? criterion (string-ref str i)) (lp (+ i 1)) i))))
              ((char-set? criterion)
               (let lp ((i start))
                 (and (< i end)
                      (if (char-set-contains? criterion (string-ref str i)) (lp (+ i 1)) i))))
              ((procedure? criterion)
               (let lp ((i start))
                 (and (< i end)
                      (if (criterion (string-ref str i)) (lp (+ i 1)) i))))
              (else (error "Second param is neither char-set, char, or predicate procedure."
                           string-skip criterion)))))

    (define (string-skip-right str criterion . maybe-start+end)
      "Syntax: (string-skip-right s criterion [start [end]])
Library: (srfi 13)
Description: Returns the index of the last character in s[start..end) NOT matching criterion.
Example:
  (string-skip-right \"hello  \" char-whitespace?) => 4"
      (let-string-start+end (start end) string-skip-right str maybe-start+end
        (cond ((char? criterion)
               (let lp ((i (- end 1)))
                 (and (>= i start)
                      (if (char=? criterion (string-ref str i)) (lp (- i 1)) i))))
              ((char-set? criterion)
               (let lp ((i (- end 1)))
                 (and (>= i start)
                      (if (char-set-contains? criterion (string-ref str i)) (lp (- i 1)) i))))
              ((procedure? criterion)
               (let lp ((i (- end 1)))
                 (and (>= i start)
                      (if (criterion (string-ref str i)) (lp (- i 1)) i))))
              (else (error "Second param is neither char-set, char, or predicate procedure."
                           string-skip-right criterion)))))

    (define (string-count s criterion . maybe-start+end)
      "Syntax: (string-count s criterion [start [end]])
Library: (srfi 13)
Description: Counts the number of characters in s[start..end) matching criterion.
Example:
  (string-count \"hello world\" char-alphabetic?) => 10"
      (let-string-start+end (start end) string-count s maybe-start+end
        (cond ((char? criterion)
               (do ((i start (+ i 1))
                    (count 0 (if (char=? criterion (string-ref s i)) (+ count 1) count)))
                   ((>= i end) count)))
              ((char-set? criterion)
               (do ((i start (+ i 1))
                    (count 0 (if (char-set-contains? criterion (string-ref s i)) (+ count 1) count)))
                   ((>= i end) count)))
              ((procedure? criterion)
               (do ((i start (+ i 1))
                    (count 0 (if (criterion (string-ref s i)) (+ count 1) count)))
                   ((>= i end) count)))
              (else (error "CRITERION param is neither char-set, char, or predicate."
                           string-count criterion)))))

    ;; --- Contains ---

    (define (string-contains-ci text pattern . maybe-starts+ends)
      "Syntax: (string-contains-ci s1 s2 [start1 [end1 [start2 [end2]]]])
Library: (srfi 13)
Description: Case-insensitive string-contains. Uses KMP algorithm.
Example:
  (string-contains-ci \"Hello World\" \"world\") => 6"
      (let-string-start+end2 (t-start t-end p-start p-end)
                             string-contains-ci text pattern maybe-starts+ends
        (%kmp-search pattern text char-ci=? p-start p-end t-start t-end)))

    ;; --- Filter / Delete ---
    ;; Two-pass strategy for char/char-set (count then fill).
    ;; One-pass with temp buffer for predicates.

    (define (string-filter criterion s . maybe-start+end)
      "Syntax: (string-filter criterion s [start [end]])
Library: (srfi 13)
Description: Returns a string of characters from s[start..end) that match criterion.
Example:
  (string-filter char-alphabetic? \"h3ll0 w0rld\") => \"hllwrld\""
      (let-string-start+end (start end) string-filter s maybe-start+end
        (if (procedure? criterion)
            (let* ((slen (- end start))
                   (temp (make-string slen))
                   (ans-len (string-fold (lambda (c i)
                                           (if (criterion c)
                                               (begin (string-set! temp i c)
                                                      (+ i 1))
                                               i))
                                         0 s start end)))
              (if (= ans-len slen) temp (substring temp 0 ans-len)))
            (let* ((cset (cond ((char-set? criterion) criterion)
                               ((char? criterion) (char-set criterion))
                               (else (error "string-filter criterion not predicate, char or char-set" criterion))))
                   (len (string-fold (lambda (c i) (if (char-set-contains? cset c) (+ i 1) i))
                                     0 s start end))
                   (ans (make-string len)))
              (string-fold (lambda (c i) (if (char-set-contains? cset c)
                                             (begin (string-set! ans i c) (+ i 1))
                                             i))
                           0 s start end)
              ans))))

    (define (string-delete criterion s . maybe-start+end)
      "Syntax: (string-delete criterion s [start [end]])
Library: (srfi 13)
Description: Returns s[start..end) with characters matching criterion removed.
Example:
  (string-delete char-whitespace? \"hello world\") => \"helloworld\""
      (let-string-start+end (start end) string-delete s maybe-start+end
        (if (procedure? criterion)
            (let* ((slen (- end start))
                   (temp (make-string slen))
                   (ans-len (string-fold (lambda (c i)
                                           (if (criterion c) i
                                               (begin (string-set! temp i c)
                                                      (+ i 1))))
                                         0 s start end)))
              (if (= ans-len slen) temp (substring temp 0 ans-len)))
            (let* ((cset (cond ((char-set? criterion) criterion)
                               ((char? criterion) (char-set criterion))
                               (else (error "string-delete criterion not predicate, char or char-set" criterion))))
                   (len (string-fold (lambda (c i) (if (char-set-contains? cset c) i (+ i 1)))
                                     0 s start end))
                   (ans (make-string len)))
              (string-fold (lambda (c i) (if (char-set-contains? cset c)
                                             i
                                             (begin (string-set! ans i c) (+ i 1))))
                           0 s start end)
              ans))))

    ;; --- Reverse ---

    (define (string-reverse s . maybe-start+end)
      "Syntax: (string-reverse s [start [end]])
Library: (srfi 13)
Description: Returns a new string that is the reverse of s[start..end).
Example:
  (string-reverse \"hello\") => \"olleh\""
      (let-string-start+end (start end) string-reverse s maybe-start+end
        (let* ((len (- end start))
               (ans (make-string len)))
          (do ((i start (+ i 1))
               (j (- len 1) (- j 1)))
              ((< j 0))
            (string-set! ans j (string-ref s i)))
          ans)))

    (define string-reverse! string-reverse)

    ;; --- Replace ---

    (define (string-replace s1 s2 start1 end1 . maybe-start+end)
      "Syntax: (string-replace s1 s2 start1 end1 [start2 [end2]])
Library: (srfi 13)
Description: Returns a string built from s1 with s1[start1,end1) replaced by s2[start2,end2).
Example:
  (string-replace \"abcdef\" \"XY\" 2 4) => \"abXYef\""
      (check-substring-spec string-replace s1 start1 end1)
      (let-string-start+end (start2 end2) string-replace s2 maybe-start+end
        (let* ((slen1 (string-length s1))
               (sublen2 (- end2 start2))
               (alen (+ (- slen1 (- end1 start1)) sublen2))
               (ans (make-string alen)))
          (%string-copy! ans 0 s1 0 start1)
          (%string-copy! ans start1 s2 start2 end2)
          (%string-copy! ans (+ start1 sublen2) s1 end1 slen1)
          ans)))

    ;; --- Concatenate ---

    (define (string-concatenate strings)
      "Syntax: (string-concatenate lst)
Library: (srfi 13)
Description: Concatenates a list of strings into a single string.
Example:
  (string-concatenate '(\"foo\" \"bar\" \"baz\")) => \"foobarbaz\""
      (let* ((total (do ((strings strings (cdr strings))
                         (i 0 (+ i (string-length (car strings)))))
                        ((not (pair? strings)) i)))
             (ans (make-string total)))
        (let lp ((i 0) (strings strings))
          (if (pair? strings)
              (let* ((s (car strings))
                     (slen (string-length s)))
                (%string-copy! ans i s 0 slen)
                (lp (+ i slen) (cdr strings)))))
        ans))

    (define string-concatenate/shared string-concatenate)
    (define string-append/shared string-append)

    (define (string-concatenate-reverse string-list . maybe-final+end)
      "Syntax: (string-concatenate-reverse lst [final [end]])
Library: (srfi 13)
Description: Reverses lst then concatenates, optionally prepending (substring final 0 end).
Example:
  (string-concatenate-reverse '(\"baz\" \"bar\" \"foo\")) => \"foobarbaz\""
      (let* ((final (if (pair? maybe-final+end) (car maybe-final+end) ""))
             (end (if (and (pair? maybe-final+end) (pair? (cdr maybe-final+end)))
                      (cadr maybe-final+end) (string-length final))))
        (let ((len (let lp ((sum 0) (lis string-list))
                     (if (pair? lis)
                         (lp (+ sum (string-length (car lis))) (cdr lis))
                         sum))))
          (let ((ans (make-string (+ end len))))
            (%string-copy! ans len final 0 end)
            (let lp ((i len) (lis string-list))
              (if (pair? lis)
                  (let* ((s   (car lis))
                         (lis (cdr lis))
                         (slen (string-length s))
                         (i (- i slen)))
                    (%string-copy! ans i s 0 slen)
                    (lp i lis))))
            ans))))

    (define string-concatenate-reverse/shared string-concatenate-reverse)

    ;; --- Tokenize ---

    (define (string-tokenize s . token-chars+start+end)
      "Syntax: (string-tokenize s [token-set [start [end]]])
Library: (srfi 13)
Description: Splits s into a list of token strings, where a token is a maximal
non-empty contiguous sequence of chars in token-set (default: char-set:graphic).
Example:
  (string-tokenize \"hello world\") => (\"hello\" \"world\")"
      (let* ((token-chars (if (pair? token-chars+start+end) (car token-chars+start+end) char-set:graphic))
             (rest (if (pair? token-chars+start+end) (cdr token-chars+start+end) '())))
        (let-string-start+end (start end) string-tokenize s rest
          (let lp ((i end) (ans '()))
            (cond ((and (< start i) (string-index-right s token-chars start i)) =>
                   (lambda (tend-1)
                     (let ((tend (+ 1 tend-1)))
                       (cond ((string-skip-right s token-chars start tend-1) =>
                              (lambda (tstart-1)
                                (lp tstart-1
                                    (cons (substring s (+ 1 tstart-1) tend) ans))))
                             (else (cons (substring s start tend) ans))))))
                  (else ans))))))

    ;; --- Replicate ---

    (define (xsubstring s from . maybe-to+start+end)
      "Syntax: (xsubstring s from [to [start [end]]])
Library: (srfi 13)
Description: Returns a substring of the virtual infinite string formed by repeating s cyclically.
Example:
  (xsubstring \"hello\" 2 7) => \"llohe\"
  (xsubstring \"abc\" 0 9) => \"abcabcabc\""
      (receive (to start end)
               (if (pair? maybe-to+start+end)
                   (let-string-start+end (start end) xsubstring s (cdr maybe-to+start+end)
                     (values (car maybe-to+start+end) start end))
                   (let ((slen (string-length s)))
                     (values (+ from slen) 0 slen)))
        (let ((slen   (- end start))
              (anslen (- to  from)))
          (cond ((zero? anslen) "")
                ((zero? slen) (error "Cannot replicate empty (sub)string"
                                     xsubstring s from to start end))
                ((= 1 slen) (make-string anslen (string-ref s start)))
                ((= (floor (/ from slen)) (floor (/ to slen)))
                 (substring s (+ start (modulo from slen))
                            (+ start (modulo to   slen))))
                (else (let ((ans (make-string anslen)))
                        (%multispan-repcopy! ans 0 s from to start end)
                        ans))))))

    (define (string-xcopy! target tstart s sfrom . maybe-sto+start+end)
      "Syntax: (string-xcopy! target tstart s sfrom [sto [start [end]]])
Library: (srfi 13)
Description: Copies a cyclically repeated substring of s into target starting at tstart.
Example:
  (let ((t (string-copy \"......\"))) (string-xcopy! t 0 \"abc\" 0 6) t) => \"abcabc\""
      (receive (sto start end)
               (if (pair? maybe-sto+start+end)
                   (let-string-start+end (start end) string-xcopy! s (cdr maybe-sto+start+end)
                     (values (car maybe-sto+start+end) start end))
                   (let ((slen (string-length s)))
                     (values (+ sfrom slen) 0 slen)))
        (let* ((tocopy (- sto sfrom))
               (tend (+ tstart tocopy))
               (slen (- end start)))
          (check-substring-spec string-xcopy! target tstart tend)
          (cond ((zero? tocopy))
                ((zero? slen) (error "Cannot replicate empty (sub)string"
                                     string-xcopy! target tstart s sfrom sto start end))
                ((= 1 slen) (string-fill! target (string-ref s start) tstart tend))
                ((= (floor (/ sfrom slen)) (floor (/ sto slen)))
                 (%string-copy! target tstart s
                                (+ start (modulo sfrom slen))
                                (+ start (modulo sto   slen))))
                (else (%multispan-repcopy! target tstart s sfrom sto start end))))))

    (define (%multispan-repcopy! target tstart s sfrom sto start end)
      (let* ((slen (- end start))
             (i0 (+ start (modulo sfrom slen)))
             (total-chars (- sto sfrom)))
        (%string-copy! target tstart s i0 end)
        (let* ((ncopied (- end i0))
               (nleft (- total-chars ncopied))
               (nspans (quotient nleft slen)))
          (do ((i (+ tstart ncopied) (+ i slen))
               (nspans nspans (- nspans 1)))
              ((zero? nspans)
               (%string-copy! target i s start (+ start (- total-chars (- i tstart)))))
            (%string-copy! target i s start end)))))

    ;; --- KMP string search ---

    (define (%kmp-search pattern text c= p-start p-end t-start t-end)
      (let ((plen (- p-end p-start))
            (rv (make-kmp-restart-vector pattern c= p-start p-end)))
        (let lp ((ti t-start) (pi 0)
                 (tj (- t-end t-start))
                 (pj plen))
          (if (= pi plen)
              (- ti plen)
              (and (<= pj tj)
                   (if (c= (string-ref text ti)
                            (string-ref pattern (+ p-start pi)))
                       (lp (+ 1 ti) (+ 1 pi) (- tj 1) (- pj 1))
                       (let ((pi (vector-ref rv pi)))
                         (if (= pi -1)
                             (lp (+ ti 1) 0  (- tj 1) plen)
                             (lp ti       pi tj       (- plen pi))))))))))

    (define (make-kmp-restart-vector pattern . maybe-c=+start+end)
      "Syntax: (make-kmp-restart-vector pattern [c= [start [end]]])
Library: (srfi 13)
Description: Builds the KMP restart vector for pattern[start..end).
Example:
  (make-kmp-restart-vector \"abcabc\") => #(-1 0 0 -1 0 0)"
      (let* ((c= (if (pair? maybe-c=+start+end) (car maybe-c=+start+end) char=?))
             (rest (if (pair? maybe-c=+start+end) (cdr maybe-c=+start+end) '()))
             (start (if (pair? rest) (car rest) 0))
             (rest (if (pair? rest) (cdr rest) '()))
             (end (if (pair? rest) (car rest) (string-length pattern))))
        (let* ((rvlen (- end start))
               (rv (make-vector rvlen -1)))
          (if (> rvlen 0)
              (let ((rvlen-1 (- rvlen 1))
                    (c0 (string-ref pattern start)))
                (let lp1 ((i 0) (j -1) (k start))
                  (if (< i rvlen-1)
                      (let lp2 ((j j))
                        (cond ((= j -1)
                               (let ((i1 (+ 1 i)))
                                 (if (not (c= (string-ref pattern (+ k 1)) c0))
                                     (vector-set! rv i1 0))
                                 (lp1 i1 0 (+ k 1))))
                              ((c= (string-ref pattern k) (string-ref pattern (+ j start)))
                               (let* ((i1 (+ 1 i))
                                      (j1 (+ 1 j)))
                                 (vector-set! rv i1 j1)
                                 (lp1 i1 j1 (+ k 1))))
                              (else (lp2 (vector-ref rv j)))))))))
          rv)))

    (define (kmp-step pat rv c i c= p-start)
      "Syntax: (kmp-step pattern rv c i c= p-start)
Library: (srfi 13)
Description: Advances the KMP state machine by one character.
Example:
  (let ((rv (make-kmp-restart-vector \"abc\")))
    (kmp-step \"abc\" rv #\\a 0 char=? 0)) => 1"
      (let lp ((i i))
        (if (= i -1)
            (if (c= c (string-ref pat p-start)) 1 -1)
            (if (c= c (string-ref pat (+ i p-start)))
                (+ i 1)
                (let ((i (vector-ref rv i)))
                  (if (= i -1)
                      (if (c= c (string-ref pat p-start)) 1 -1)
                      (lp i)))))))

    (define (string-kmp-partial-search pat rv s i . c=+p-start+s-start+s-end)
      "Syntax: (string-kmp-partial-search pattern rv text i [c= [p-start [start [end]]]])
Library: (srfi 13)
Description: Searches text for pattern using KMP with partial match state.
Example:
  (let* ((pat \"abc\") (rv (make-kmp-restart-vector pat)))
    (string-kmp-partial-search pat rv \"xyzabc\" 0)) => -6"
      (let* ((c= (if (pair? c=+p-start+s-start+s-end) (car c=+p-start+s-start+s-end) char=?))
             (rest (if (pair? c=+p-start+s-start+s-end) (cdr c=+p-start+s-start+s-end) '()))
             (p-start (if (pair? rest) (car rest) 0))
             (rest (if (pair? rest) (cdr rest) '()))
             (s-start (if (pair? rest) (car rest) 0))
             (rest (if (pair? rest) (cdr rest) '()))
             (s-end (if (pair? rest) (car rest) (string-length s))))
        (let ((patlen (vector-length rv)))
          (let lp ((si s-start) (vi i))
            (cond ((= vi patlen) (- si))
                  ((= si s-end) vi)
                  (else
                   (let ((c (string-ref s si)))
                     (lp (+ si 1)
                         (let lp2 ((vi vi))
                           (if (c= c (string-ref pat (+ vi p-start)))
                               (+ vi 1)
                               (let ((vi (vector-ref rv vi)))
                                 (if (= vi -1) 0
                                     (lp2 vi)))))))))))))

    ))

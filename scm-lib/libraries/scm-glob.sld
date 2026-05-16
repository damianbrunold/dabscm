(define-library (scm glob)
  (import (scheme base) (scheme char) (srfi 1) (srfi 132) (scm fs))
  (export glob glob-match?)
  (begin

    ;; --- Internal helpers ---

    (define (%append-map f lst)
      "Like append-map but safe for empty lists."
      (if (null? lst) '()
          (apply append (map f lst))))

    (define %path-sep (%primitive "path-sep"))
    (define %path-sep-char (string-ref %path-sep 0))

    (define (%split-path str)
      "Split a path string into segments by the path separator character.
Skips empty segments caused by consecutive separators (e.g. //)"
      (let ((len (string-length str)))
        (let loop ((i 0) (start 0) (acc '()))
          (cond
            ((= i len)
             (reverse (if (= start i) acc (cons (substring str start i) acc))))
            ((char=? (string-ref str i) %path-sep-char)
             (let ((seg (substring str start i)))
               (loop (+ i 1) (+ i 1)
                     (if (string=? seg "") acc (cons seg acc)))))
            (else
             (loop (+ i 1) start acc))))))

    (define (%drive-prefix? str)
      "Returns #t if str starts with a Windows drive letter like C:.
Only triggers when the path separator is backslash (Windows)."
      (and (char=? %path-sep-char #\\)
           (>= (string-length str) 2)
           (char-alphabetic? (string-ref str 0))
           (char=? (string-ref str 1) #\:)))

    (define (%absolute-path? str)
      (or (and (> (string-length str) 0)
               (char=? (string-ref str 0) %path-sep-char))
          (%drive-prefix? str)))

    (define (%dotname? name)
      (and (> (string-length name) 0)
           (char=? (string-ref name 0) #\.)))

    (define (%globstar? seg)
      (string=? seg "**"))

    (define (%join-dir-name dir name)
      "Join dir and name, avoiding double separators."
      (let ((len (string-length dir)))
        (if (and (> len 0)
                 (char=? (string-ref dir (- len 1)) %path-sep-char))
            (string-append dir name)
            (string-append dir %path-sep name))))

    ;; --- Pattern matching engine ---

    (define (%match-char-class pat pi plen ch)
      "Match ch against a character class starting after the opening [.
Returns a pair (matched? . index-past-closing-bracket) or (#f . pi) on malformed."
      (let* ((negate? (and (< pi plen)
                           (let ((c (string-ref pat pi)))
                             (or (char=? c #\!) (char=? c #\^)))))
             (pi (if negate? (+ pi 1) pi))
             ;; ] as first char is literal
             (first-char? #t))
        (let loop ((i pi) (matched? #f) (first? first-char?))
          (cond
            ((>= i plen) (cons #f pi)) ; no closing ] found
            ((and (char=? (string-ref pat i) #\]) (not first?))
             (cons (if negate? (not matched?) matched?) (+ i 1)))
            (else
             (let ((pc (string-ref pat i)))
               ;; Check for range a-z
               (if (and (< (+ i 2) plen)
                        (char=? (string-ref pat (+ i 1)) #\-)
                        (not (char=? (string-ref pat (+ i 2)) #\])))
                   (let ((lo pc)
                         (hi (string-ref pat (+ i 2))))
                     (loop (+ i 3)
                           (or matched? (and (char<=? lo ch) (char<=? ch hi)))
                           #f))
                   (loop (+ i 1)
                         (or matched? (char=? pc ch))
                         #f))))))))

    (define (%glob-match-impl pat pi plen str si slen)
      "Core recursive glob matcher. Returns #t if pat[pi..plen) matches str[si..slen)."
      (cond
        ;; Pattern exhausted
        ((= pi plen) (= si slen))

        ;; ** globstar: matches zero or more path segments
        ((and (<= (+ pi 2) plen)
              (char=? (string-ref pat pi) #\*)
              (char=? (string-ref pat (+ pi 1)) #\*))
         (let ((npi (+ pi 2)))
           ;; Skip trailing separator after **
           (let ((npi (if (and (< npi plen)
                               (char=? (string-ref pat npi) %path-sep-char))
                          (+ npi 1)
                          npi)))
             ;; Try matching rest of pattern from every position
             (let loop ((si2 si))
               (cond
                 ((%glob-match-impl pat npi plen str si2 slen) #t)
                 ((= si2 slen) #f)
                 (else (loop (+ si2 1))))))))

        ;; * : match any chars except path separator
        ((char=? (string-ref pat pi) #\*)
         (let ((npi (+ pi 1)))
           (let loop ((si2 si))
             (cond
               ((%glob-match-impl pat npi plen str si2 slen) #t)
               ((= si2 slen) #f)
               ((char=? (string-ref str si2) %path-sep-char) #f)
               (else (loop (+ si2 1)))))))

        ;; ? : match one char except path separator
        ((char=? (string-ref pat pi) #\?)
         (and (< si slen)
              (not (char=? (string-ref str si) %path-sep-char))
              (%glob-match-impl pat (+ pi 1) plen str (+ si 1) slen)))

        ;; [...] : character class
        ((char=? (string-ref pat pi) #\[)
         (and (< si slen)
              (let ((result (%match-char-class pat (+ pi 1) plen (string-ref str si))))
                (and (car result)
                     (%glob-match-impl pat (cdr result) plen str (+ si 1) slen)))))

        ;; Literal character
        (else
         (and (< si slen)
              (char=? (string-ref pat pi) (string-ref str si))
              (%glob-match-impl pat (+ pi 1) plen str (+ si 1) slen)))))

    ;; --- Public API ---

    (define (glob-match? pattern str)
      "Syntax: (glob-match? pattern string)
Library: (scm glob)
Description: Tests whether string matches the glob pattern. Supports *
  (any characters except path separator), ? (single character except path
  separator), [...] character classes with ranges and negation ([!...]),
  and ** (matches zero or more path segments including separators).
  This is a pure string operation with no filesystem access.
Example:
  (glob-match? \"*.scm\" \"foo.scm\")       => #t
  (glob-match? \"src/**/*.scm\" \"src/lib/foo.scm\") => #t
  (glob-match? \"[abc].txt\" \"b.txt\")     => #t"
      (%glob-match-impl pattern 0 (string-length pattern)
                        str 0 (string-length str)))

    ;; --- Filesystem traversal ---

    (define (%all-entries dir)
      "Returns a list of (name . type) pairs where type is 'file or 'dir."
      (append
       (map (lambda (f) (cons f 'file)) (directory-files dir))
       (map (lambda (d) (cons d 'dir)) (directory-directories dir))))

    (define (%segment-pattern-allows-dots? seg)
      "Returns #t if the segment pattern explicitly starts with a dot."
      (and (> (string-length seg) 0)
           (char=? (string-ref seg 0) #\.)))

    (define (%collect-dirs-recursive dir include-dots?)
      "Collect dir and all subdirectories recursively. Returns list of paths."
      (let ((subdirs (directory-directories dir)))
        (let ((filtered (if include-dots? subdirs
                            (filter (lambda (d) (not (%dotname? d))) subdirs))))
          (let ((subpaths (map (lambda (d) (%join-dir-name dir d)) filtered)))
            (cons dir
                  (%append-map (lambda (p) (%collect-dirs-recursive p include-dots?))
                              subpaths))))))

    (define (%match-one-segment dir seg rest)
      "Match one glob segment against entries in dir, then recurse on rest."
      (let* ((entries (%all-entries dir))
             (allow-dots? (%segment-pattern-allows-dots? seg))
             (filtered (filter (lambda (e)
                                 (let ((name (car e)))
                                   (and (or allow-dots? (not (%dotname? name)))
                                        (glob-match? seg name))))
                               entries)))
        (if (null? rest)
            ;; Final segment: return matching paths
            (map (lambda (e) (%join-dir-name dir (car e))) filtered)
            ;; More segments: recurse into matching directories only
            (%append-map (lambda (e)
                          (if (eq? (cdr e) 'dir)
                              (%match-segments (%join-dir-name dir (car e)) rest)
                              '()))
                        filtered))))

    (define (%match-globstar dir rest)
      "Handle ** segment: match zero or more directory levels."
      (let* ((include-dots? (and (not (null? rest))
                                 (%segment-pattern-allows-dots? (car rest))))
             (all-dirs (%collect-dirs-recursive dir include-dots?)))
        (if (null? rest)
            ;; ** at end: return all files and dirs recursively
            (%append-map
             (lambda (d)
               (let ((entries (%all-entries d)))
                 (let ((filtered (if include-dots? entries
                                     (filter (lambda (e) (not (%dotname? (car e)))) entries))))
                   (append
                    (if (string=? d dir) '() (list d))
                    (map (lambda (e) (%join-dir-name d (car e))) filtered)))))
             all-dirs)
            ;; ** followed by more segments: try from each directory
            (%append-map (lambda (d) (%match-segments d rest))
                        all-dirs))))

    (define (%match-segments dir segs)
      "Recursively match path segments against the filesystem starting from dir."
      (cond
        ((null? segs)
         (if (or (file-exists? dir) (directory-exists? dir))
             (list dir)
             '()))
        ((%globstar? (car segs))
         (if (directory-exists? dir)
             (%match-globstar dir (cdr segs))
             '()))
        (else
         (if (directory-exists? dir)
             (%match-one-segment dir (car segs) (cdr segs))
             '()))))

    (define (%strip-dot-slash path)
      "Remove leading ./ from a path."
      (let ((len (string-length path)))
        (if (and (>= len 2)
                 (char=? (string-ref path 0) #\.)
                 (char=? (string-ref path 1) %path-sep-char))
            (substring path 2 len)
            path)))

    (define (glob pattern)
      "Syntax: (glob pattern)
Library: (scm glob)
Description: Returns a sorted list of file and directory paths matching
  the glob pattern. Supports * (any characters except path separator),
  ? (single character), [...] character classes, and ** (recursive
  globstar matching zero or more directory levels). Dotfiles are not
  matched by *, ?, or ** unless the pattern segment explicitly starts
  with a dot. Returns an empty list if no matches are found or the
  base directory does not exist.
Example:
  (glob \"src/*.scm\") => (\"src/bar.scm\" \"src/foo.scm\")
  (glob \"**/*.sld\") => (\"lib/a.sld\" \"lib/sub/b.sld\")"
      (let* ((segs (%split-path pattern))
             (absolute? (%absolute-path? pattern))
             (has-drive? (and (not (null? segs))
                              (%drive-prefix? (car segs))))
             (base (cond (has-drive?
                          (string-append (car segs) (string %path-sep-char)))
                         (absolute?
                          (string %path-sep-char))
                         (else ".")))
             (segs (if has-drive? (cdr segs) segs))
             (raw (%match-segments base segs))
             (results (if absolute?
                          raw
                          (map %strip-dot-slash raw))))
        (list-sort string<? results)))))

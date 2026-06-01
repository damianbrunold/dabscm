(define-library (scm fs-find)
  (import (scm core)
          (scheme base)
          (scheme write)
          (scm fs)
          (scm glob)
          (scm system)
          (srfi 1))
  (export du
          df
          find-file
          tree
          xargs)
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

    (define (%join dir name)
      (let ((n (string-length dir)))
        (if (and (> n 0)
                 (char=? (string-ref dir (- n 1)) (string-ref path-sep 0)))
            (string-append dir name)
            (string-append dir path-sep name))))

    (define (%walk root)
      "Yields a list of (path type) pairs reachable from root.
type is one of 'file or 'directory. root itself is included."
      (let walk ((p root) (acc '()))
        (cond
          ((directory-exists? p)
           (let* ((acc (cons (list p 'directory) acc))
                  (subs (directory-files p))
                  (acc (fold (lambda (n a)
                               (cons (list (%join p n) 'file) a))
                             acc subs))
                  (dirs (directory-directories p)))
             (fold (lambda (d a) (walk (%join p d) a)) acc dirs)))
          ((file-exists? p) (cons (list p 'file) acc))
          (else acc))))

    (define (find-file root . opts)
      "Syntax: (find-file root [option ...])
Library: (scm fs-find)
Description: Recursively walks the filesystem starting at root and returns
  the list of matching paths. Options:
    '(name . glob)         — match the basename against a glob pattern
    '(type . sym)          — restrict to 'file or 'directory
    '(maxdepth . n)        — limit recursion depth (root is depth 0)
    '(mindepth . n)        — exclude entries shallower than n
    '(predicate . proc)    — additional (string -> bool) test
    '(action . proc)       — invoke proc on each matching path
Example:
  (find-file \".\" '(name . \"*.scm\") '(type . file))
  (find-file \"/var/log\" `(predicate . ,(lambda (p) (> (file-size p) 1024))))"
      (let ((name      (%opt-value opts 'name #f))
            (type      (%opt-value opts 'type #f))
            (maxdepth  (%opt-value opts 'maxdepth -1))
            (mindepth  (%opt-value opts 'mindepth 0))
            (predicate (%opt-value opts 'predicate (lambda (_) #t)))
            (action    (%opt-value opts 'action    #f))
            (sep-ch    (string-ref path-sep 0)))
        (define (depth p)
          (let loop ((i 0) (d 0))
            (if (>= i (string-length p))
                d
                (loop (+ i 1)
                      (if (char=? (string-ref p i) sep-ch) (+ d 1) d)))))
        (let* ((root-depth (depth root))
               (all (reverse (%walk root)))
               (filtered
                 (filter
                   (lambda (entry)
                     (let* ((p (car entry))
                            (t (cadr entry))
                            (rel-depth (- (depth p) root-depth))
                            (bn (base-name p)))
                       (and (or (= maxdepth -1) (<= rel-depth maxdepth))
                            (>= rel-depth mindepth)
                            (or (not type) (eq? type t))
                            (or (not name) (glob-match? name bn))
                            (predicate p))))
                   all))
               (paths (map car filtered)))
          (when action (for-each action paths))
          paths)))

    (define (du path . opts)
      "Syntax: (du path [option ...])
Library: (scm fs-find)
Description: Returns the total size in bytes of path. If path is a
  directory the size is the recursive sum of all contained files.
  Option 'apparent (default) counts file-size; 'block-size sums via
  the native du command for filesystem block-aligned totals when
  available.
Example:
  (du \"/var/log\")"
      (let ((block? (%has-flag? opts 'block-size))
            (native (which "du")))
        (cond
          ((and block? native)
           (let ((r (run-program/capture (list native "-sb" path))))
             (if (and (pair? r) (zero? (car r)))
                 (string->number
                   (car (let ((s (cadr r)))
                          (let loop ((i 0))
                            (if (or (>= i (string-length s))
                                    (char=? (string-ref s i) #\tab)
                                    (char=? (string-ref s i) #\space))
                                (list (substring s 0 i))
                                (loop (+ i 1)))))))
                 0)))
          (else
           (let walk ((p path) (acc 0))
             (cond
               ((directory-exists? p)
                (let* ((files (directory-files p))
                       (acc (fold (lambda (n a)
                                    (+ a (file-size (%join p n))))
                                  acc files))
                       (dirs (directory-directories p)))
                  (fold (lambda (d a) (walk (%join p d) a)) acc dirs)))
               ((file-exists? p) (+ acc (file-size p)))
               (else acc)))))))

    (define (df . opts)
      "Syntax: (df [path])
Library: (scm fs-find)
Description: Returns a list of alists describing mounted filesystems.
  Each entry has keys: filesystem, size, used, available, use% (string),
  mount. Shells out to the native df command; returns '() if unavailable.
  When a path argument is given, restricts to that filesystem.
Example:
  (df)
  (df \"/home\")"
      (let ((native (which "df")))
        (if (not native)
            '()
            (let* ((path (and (pair? opts) (car opts)))
                   (args (if path
                             (list native "-P" path)
                             (list native "-P")))
                   (r (run-program/capture args)))
              (if (and (pair? r) (zero? (car r)))
                  (df-parse (cadr r))
                  '())))))

    (define (df-parse out)
      ;; Split into lines, drop header, parse 6-column df -P output:
      ;; Filesystem 1024-blocks Used Available Capacity Mounted-on
      (let* ((lines (let loop ((i 0) (start 0) (acc '()))
                      (cond
                        ((>= i (string-length out))
                         (reverse (if (= start i)
                                      acc
                                      (cons (substring out start i) acc))))
                        ((char=? (string-ref out i) #\newline)
                         (loop (+ i 1) (+ i 1)
                               (if (= start i)
                                   acc
                                   (cons (substring out start i) acc))))
                        (else (loop (+ i 1) start acc)))))
             (data (if (pair? lines) (cdr lines) '())))
        (map (lambda (line)
               (let ((fields (df-split-fields line)))
                 (if (>= (length fields) 6)
                     (list (cons 'filesystem (list-ref fields 0))
                           (cons 'size       (or (string->number (list-ref fields 1)) 0))
                           (cons 'used       (or (string->number (list-ref fields 2)) 0))
                           (cons 'available  (or (string->number (list-ref fields 3)) 0))
                           (cons 'use%       (list-ref fields 4))
                           (cons 'mount      (list-ref fields 5)))
                     '())))
             data)))

    (define (df-split-fields line)
      ;; Split on runs of whitespace; preserves the last field (mount point)
      ;; even if it contains spaces by limiting to 6 splits.
      (let ((n (string-length line)))
        (let loop ((i 0) (acc '()) (cur 0) (in-tok? #f) (count 0))
          (cond
            ((>= i n)
             (reverse (if in-tok?
                          (cons (substring line cur n) acc)
                          acc)))
            ((and (= count 5) in-tok?)
             ;; collect remainder as one field
             (reverse (cons (substring line cur n) acc)))
            (else
             (let ((ch (string-ref line i)))
               (cond
                 ((or (char=? ch #\space) (char=? ch #\tab))
                  (if in-tok?
                      (loop (+ i 1)
                            (cons (substring line cur i) acc)
                            (+ i 1) #f (+ count 1))
                      (loop (+ i 1) acc (+ i 1) #f count)))
                 (else
                  (if in-tok?
                      (loop (+ i 1) acc cur #t count)
                      (loop (+ i 1) acc i #t count))))))))))

    (define (tree root . opts)
      "Syntax: (tree root [option ...])
Library: (scm fs-find)
Description: Returns a string with a pretty ASCII tree of the directory at
  root, similar to the tree(1) command. Options:
    '(maxdepth . n)  — limit depth shown (root is depth 0)
    'dirs-only       — only show directories
Example:
  (display (tree \".\" '(maxdepth . 2)))"
      (let ((maxdepth (%opt-value opts 'maxdepth -1))
            (dirs-only? (%has-flag? opts 'dirs-only))
            (out (open-output-string)))
        (define (entries dir)
          ;; list of (name is-dir?), sorted, dirs after files for stable layout
          (let* ((files (if dirs-only? '()
                            (map (lambda (n) (cons n #f))
                                 (directory-files dir))))
                 (dirs  (map (lambda (n) (cons n #t))
                             (directory-directories dir)))
                 (all (append files dirs))
                 (cmp (lambda (a b) (string<? (car a) (car b)))))
            (sort-by cmp all)))
        (define (walk dir prefix depth)
          (when (or (= maxdepth -1) (< depth maxdepth))
            (let* ((es (entries dir))
                   (n  (length es)))
              (let loop ((es es) (i 0))
                (when (pair? es)
                  (let* ((e (car es))
                         (name (car e))
                         (is-dir? (cdr e))
                         (last? (= i (- n 1)))
                         (branch (if last? "`-- " "|-- "))
                         (next-prefix (if last? "    " "|   ")))
                    (display prefix out)
                    (display branch out)
                    (display name out)
                    (newline out)
                    (when is-dir?
                      (walk (%join dir name)
                            (string-append prefix next-prefix)
                            (+ depth 1))))
                  (loop (cdr es) (+ i 1)))))))
        (display root out)
        (newline out)
        (walk root "" 0)
        (get-output-string out)))

    (define (sort-by cmp lst)
      ;; small wrapper to avoid depending on srfi-132 list-sort symbol clash
      ;; with this module's exports.
      (if (null? lst) lst
          (let* ((vec (list->vector lst))
                 (n (vector-length vec)))
            (define (swap! i j)
              (let ((tmp (vector-ref vec i)))
                (vector-set! vec i (vector-ref vec j))
                (vector-set! vec j tmp)))
            ;; simple insertion sort — good enough for directory listings
            (let outer ((i 1))
              (when (< i n)
                (let inner ((j i))
                  (when (and (> j 0)
                             (cmp (vector-ref vec j) (vector-ref vec (- j 1))))
                    (swap! j (- j 1))
                    (inner (- j 1))))
                (outer (+ i 1))))
            (vector->list vec))))

    (define (xargs proc items . opts)
      "Syntax: (xargs proc items [option ...])
Library: (scm fs-find)
Description: Applies proc to chunks of items in turn. By default proc is
  called once per item. Option '(batch-size . n) calls proc with sublists
  of up to n items at a time. Returns the list of results.
Example:
  (xargs delete-file (find-file \"/tmp\" '(name . \"*.bak\")))
  (xargs (lambda (batch) (run-program (cons \"rm\" batch)))
         '(\"a\" \"b\" \"c\" \"d\") '(batch-size . 2))"
      (let ((batch-size (%opt-value opts 'batch-size 1)))
        (if (= batch-size 1)
            (map proc items)
            (let loop ((rest items) (acc '()))
              (cond
                ((null? rest) (reverse acc))
                (else
                 (let* ((take-n (min batch-size (length rest)))
                        (batch (take rest take-n))
                        (rest2 (drop rest take-n)))
                   (loop rest2 (cons (proc batch) acc))))))))) ))

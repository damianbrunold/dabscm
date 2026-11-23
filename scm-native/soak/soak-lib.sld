(define-library (soak lib)
  ;; Soak tests: a scenario runs rounds of work; after each round a major
  ;; collection, then a sample of what the program holds. After the
  ;; warm-up rounds nothing may keep growing: the live heap, the ports,
  ;; the native objects, the threads, the open files and the resident
  ;; memory. SOAK_ROUNDS sets the rounds (default 10), SOAK_SCALE
  ;; multiplies the work of a round (default 1).
  (export soak scale garbage)
  (import (scheme base)
          (scheme write)
          (scheme file)
          (scheme process-context)
          (scm fs))
  (cond-expand
    (dabscm-native
     (begin
       (define gc-collect (%primitive "gc-collect"))
       (define gc-statistics (%primitive "gc-statistics"))))
    (else
     (begin
       (define (gc-collect . _) #f)
       (define (gc-statistics) '()))))
  (begin
    (define (env-int name default)
      (let ((v (get-environment-variable name)))
        (or (and v (string->number v)) default)))

    (define rounds (env-int "SOAK_ROUNDS" 10))
    (define warm-up 3)

    ;; n scaled by SOAK_SCALE
    (define (scale n) (* n (env-int "SOAK_SCALE" 1)))

    ;; allocation for a few collections
    (define (garbage)
      (let loop ((i 0) (acc '()))
        (if (< i 20000)
            (loop (+ i 1) (if (= 0 (modulo i 1000)) '() (cons (make-vector 8 i) acc)))
            (length acc))))

    ;; the resident memory in KB and the open file descriptors (Linux)
    (define (proc-rss-kb)
      (guard (e (#t #f))
        (let* ((line (call-with-input-file "/proc/self/statm" read-line))
               (fields (let loop ((cs (string->list line)) (cur '()) (acc '()))
                         (cond ((null? cs)
                                (reverse (if (null? cur) acc (cons (list->string (reverse cur)) acc))))
                               ((char=? (car cs) #\space)
                                (loop (cdr cs) '() (if (null? cur) acc (cons (list->string (reverse cur)) acc))))
                               (else (loop (cdr cs) (cons (car cs) cur) acc))))))
          (* 4 (string->number (cadr fields))))))

    (define (proc-fds)
      (guard (e (#t #f))
        (length (directory-files "/proc/self/fd"))))

    (define (sample)
      (append (gc-statistics)
              (list (cons 'rss-kb (proc-rss-kb))
                    (cons 'fds (proc-fds)))))

    ;; how much a field may grow from the first sample after the warm-up
    ;; to the last: counts by a few, the live heap by 10% (plus 1 MB),
    ;; the resident memory by 25% (plus 16 MB: the C allocator keeps
    ;; freed memory)
    (define limits
      '((live-words 1/10 131072)
        (ports 0 4)
        (port-bytes 1/10 1048576)
        (native-objects 0 4)
        (threads 0 2)
        (fds 0 4)
        (rss-kb 1/4 16384)
        (malloc-bytes 1/20 262144)))

    (define (show-sample i s)
      (display "  round ")
      (display i)
      (for-each (lambda (p)
                  (when (assq (car p) limits)
                    (display " ")
                    (display (car p))
                    (display "=")
                    (display (cdr p))))
                s)
      (newline))

    (define (grown base final)
      (let loop ((ls limits) (acc '()))
        (if (null? ls)
            (reverse acc)
            (let* ((l (car ls))
                   (b (assq (car l) base))
                   (f (assq (car l) final)))
              (loop (cdr ls)
                    (if (and b f (cdr b) (cdr f)
                             (> (cdr f) (+ (cdr b) (* (cadr l) (cdr b)) (caddr l))))
                        (cons (list (car l) (cdr b) (cdr f)) acc)
                        acc))))))

    ;; the fields that must not grow steadily: a leak grows a little in
    ;; every round, also when the total stays within the limits (the
    ;; resident memory is not among them: fragmentation grows it too)
    (define steady-fields '(live-words ports native-objects threads fds malloc-bytes))

    ;; the least total growth of a steady field that counts (allocators
    ;; and the collector's own tables move by a few hundred bytes)
    (define (steady-minimum field)
      (case field
        ((live-words) 2048)
        ((malloc-bytes) 65536)
        (else 0)))

    ;; Run (step round) for the rounds; print the samples and the verdict;
    ;; exit 1 if something grew. Only the first sample after the warm-up
    ;; and the previous one are kept, and counts of the rounds in which
    ;; each steady field grew (fixnums in a vector made at the start), so
    ;; that the soak test itself does not grow the live heap
    (define (soak name step)
      (display "soak ")
      (display name)
      (newline)
      (let ((ups (make-vector (length steady-fields) 0)))
        (let loop ((i 1) (base #f) (prev #f))
          (if (<= i rounds)
              (begin
                (step i)
                (gc-collect)
                (let ((s (sample)))
                  (show-sample i s)
                  (when (and prev (> i warm-up))
                    (let count ((fs steady-fields) (k 0))
                      (unless (null? fs)
                        (let ((a (assq (car fs) prev))
                              (b (assq (car fs) s)))
                          (when (and a b (cdr a) (cdr b) (> (cdr b) (cdr a)))
                            (vector-set! ups k (+ 1 (vector-ref ups k)))))
                        (count (cdr fs) (+ k 1)))))
                  (loop (+ i 1) (if (= i warm-up) s base) s)))
              (let* ((steps (- rounds warm-up))
                     (over (if base (grown base prev) '()))
                     (steady (if (and base (>= steps 5))
                                 (let collect ((fs steady-fields) (k 0) (acc '()))
                                   (cond ((null? fs) (reverse acc))
                                         ((and (>= (* 5 (vector-ref ups k)) (* 4 steps))
                                               (> (cdr (assq (car fs) prev))
                                                  (+ (cdr (assq (car fs) base)) (steady-minimum (car fs))))
                                               (not (assq (car fs) over)))
                                          (collect (cdr fs) (+ k 1)
                                                   (cons (list (car fs) (cdr (assq (car fs) base)) (cdr (assq (car fs) prev))) acc)))
                                         (else (collect (cdr fs) (+ k 1) acc))))
                                 '()))
                     (g (append over steady)))
              (display "soak ")
              (display name)
              (display (if (null? g) ": ok" ": GROWS"))
              (for-each (lambda (x)
                          (display " ")
                          (display (car x))
                          (display " ")
                          (display (cadr x))
                          (display " -> ")
                          (display (caddr x)))
                        g)
              (newline)
              (exit (if (null? g) 0 1)))))))))

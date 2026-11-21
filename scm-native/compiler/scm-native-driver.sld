(define-library (scm native driver)
  (export compile-program
          compile-to-zig
          runtime-primitives)
  (import (scheme base)
          (scheme file)
          (scheme read)
          (scheme write)
          (scheme char)
          (srfi 1)
          (srfi 132)
          (scm fs)
          (scm io)
          (scm system)
          (scm crypto)
          (scm native ast)
          (scm native expand)
          (scm native optimize)
          (scm native anf)
          (scm native emit))
  (begin
;; Primitives the runtime provides: the `pub const @"%name"` declarations
    ;; of runtime/prims*.zig, as a list of (name module kind), kind code or
    ;; value (rt.ValuePrim).
    (define (runtime-primitives runtime-dir)
      (let ((prefix "pub const @\"%"))
        (append-map
         (lambda (file)
           (let ((module (substring file 0 (- (string-length file) 4))))
             (filter-map (lambda (line)
                           (and (>= (string-length line) (string-length prefix))
                                (string=? (substring line 0 (string-length prefix)) prefix)
                                (let loop ((i (string-length prefix)))
                                  (if (char=? (string-ref line i) #\")
                                      (list (string->symbol (substring line (string-length prefix) i))
                                            module
                                            (primitive-kind line))
                                      (loop (+ i 1))))))
                         (read-file-lines (join-path runtime-dir file)))))
         (filter (lambda (f) (and (>= (string-length f) 9)
                                  (string=? (substring f 0 5) "prims")
                                  (string=? (substring f (- (string-length f) 4) (string-length f)) ".zig")))
                 (directory-files runtime-dir)))))

    ;; value (rt.ValuePrim), leaf (made by WD or another ...D helper: callable
    ;; directly) or code
    (define (primitive-kind line)
      (cond ((string-contains line "rt.ValuePrim") 'value)
            ((let loop ((i 0))
               (cond ((>= (+ i 3) (string-length line)) #f)
                     ((and (char=? (string-ref line i) #\=) (char=? (string-ref line (+ i 1)) #\space))
                      (let scan ((j (+ i 2)))
                        (cond ((>= j (string-length line)) #f)
                              ((char=? (string-ref line j) #\()
                               (and (> j 0) (char=? (string-ref line (- j 1)) #\D)))
                              ((or (char-alphabetic? (string-ref line j)) (char=? (string-ref line j) #\.)) (scan (+ j 1)))
                              (else #f))))
                     (else (loop (+ i 1)))))
             'leaf)
            (else 'code)))

    (define (check-duplicates prims)
      (let loop ((ps prims))
        (unless (null? ps)
          (when (assq (car (car ps)) (cdr ps))
            (error "primitive defined twice in the runtime" (car (car ps))))
          (loop (cdr ps)))))

    (define (read-forms file)
      (call-with-input-file file
        (lambda (port)
          (let loop ((forms '()))
            (let ((f (read port)))
              (if (eof-object? f)
                  (reverse forms)
                  (loop (cons f forms))))))))

    ;; cond-expand features for a Zig target (#f: the host)
    (define (target-features target)
      (let* ((t (or target "x86_64-linux"))
             (has? (lambda (part) (string-contains t part))))
        (append '(r7rs scm dabscm-native exact-closed ieee-float)
                (cond ((has? "windows") '(windows))
                      ((has? "macos") '(darwin unix))
                      (else '(gnu-linux unix)))
                (cond ((has? "aarch64") '(arm64))
                      (else '(x86-64)))
                '(little-endian)
                srfi-features)))

    ;; as the JVM implementation's %features-list
    (define srfi-features
      '(srfi-1 srfi-2 srfi-8 srfi-9 srfi-13 srfi-14 srfi-18 srfi-19 srfi-26 srfi-27
        srfi-28 srfi-39 srfi-64 srfi-69 srfi-95 srfi-98 srfi-111 srfi-125 srfi-128
        srfi-132 srfi-133 srfi-151 srfi-158 srfi-194 srfi-271))

    (define (string-contains s part)
      (let ((n (string-length s)) (m (string-length part)))
        (let loop ((i 0))
          (cond ((> (+ i m) n) #f)
                ((string=? (substring s i (+ i m)) part) #t)
                (else (loop (+ i 1)))))))

    ;; The Zig modules for the program in file: a list of (symbol . source),
    ;; the libraries in initialization order and the program last.
    ;; lib-dir: the shared Scheme libraries (scm-lib).
    (define (compile-to-zig file runtime-dir lib-dir target)
      (let ((prims (runtime-primitives runtime-dir)))
        (check-duplicates prims)
        (let-values (((modules globs)
                      (expand-program file
                                      (list (directory-name (absolute-path file))
                                            (join-path lib-dir "libraries")
                                            ".")
                                      (target-features target)
                                      (map car prims)
                                      (join-path lib-dir "library.scm"))))
          (unless (null? (missing-primitives))
            (let ((err (current-error-port)))
              (display "scmc: warning: primitives not implemented in dabscm native yet:" err)
              (for-each (lambda (p) (display " " err) (display p err)) (missing-primitives))
              (newline err)))
          (set-leaf-primitives! (filter-map (lambda (p) (and (eq? (caddr p) 'leaf) (car p))) prims))
          (let ((modules (map (lambda (m)
                                (let ((body (anf (cdr m))))
                                  (compute-free! body)
                                  (cons (car m) body)))
                              (optimize modules))))
            (let ((version-file (join-path (directory-name (absolute-path lib-dir)) "VERSION")))
              (when (file-exists? version-file)
                (let ((v (call-with-input-file version-file read-line)))
                  (unless (eof-object? v) (set-program-version! v)))))
            (emit-modules modules prims)))))

    ;; The default target: a static (musl) executable on Linux
    (define (default-target)
      (if (eq? (sys-platform) 'linux) "x86_64-linux-musl" #f))

    ;; Compile the program in file to the executable output.
    ;; options: alist with 'optimize ("ReleaseFast", "ReleaseSafe", "Debug"),
    ;; 'target (a Zig target triple or #f), 'build-dir, 'zig.
    (define (compile-program file output native-dir options)
      (define (opt key default)
        (cond ((assq key options) => cdr)
              (else default)))
      (let* ((runtime-dir (join-path native-dir "runtime"))
             (optimize-mode (opt 'optimize "ReleaseFast"))
             (target (opt 'target (default-target)))
             (build-dir (opt 'build-dir (join-path native-dir "build")))
             (cfg-dir (join-path build-dir (string-append (or target "native") "-" optimize-mode)))
             (cache (join-path build-dir "zig-cache"))
             (zig (opt 'zig "zig"))
             (common `(,(string-append "-O" optimize-mode)
                       ,@(if (string=? optimize-mode "Debug") '("-fllvm") '())
                       ,@(if target (list "-target" target) '())
                       "--cache-dir" ,cache)))
        (unless (directory-exists? build-dir) (make-directory build-dir))
        (unless (directory-exists? cfg-dir) (make-directory cfg-dir))
        (let* ((sources (compile-to-zig file runtime-dir
                                         (join-path (directory-name native-dir) "scm-lib") target))
               (objects-dir (join-path build-dir "objects"))
               (flags (apply string-append (map (lambda (f) (string-append f " ")) common)))
               (abi-text (file->string (join-path runtime-dir "abi.zig")))
               (runtime-text
                (apply string-append
                       (map (lambda (f) (file->string (join-path runtime-dir f)))
                            (list-sort string<? (filter (lambda (f) (string-suffix? ".zig" f))
                                                        (directory-files runtime-dir))))))
               ;; the runtime object, then one per module, named by the hash of
               ;; everything that goes into it (the Zig CLI does not cache)
               (rt-obj (join-path objects-dir (string-append "rt-" (content-hash runtime-text flags) ".o")))
               (jobs
                (cons (list rt-obj `(,zig "build-obj" ,@common "-lc"
                                          ,(join-path runtime-dir "rtmain.zig")
                                          ,(string-append "-femit-bin=" rt-obj)))
                      (map (lambda (m)
                             (let* ((sym (car m))
                                    (zig-file (join-path cfg-dir (string-append sym ".zig")))
                                    (obj (join-path objects-dir
                                                    (string-append sym "-" (content-hash (string-append (cdr m) abi-text) flags) ".o"))))
                               (write-if-changed zig-file (cdr m))
                               (list obj `(,zig "build-obj" ,@common
                                                "--dep" "rt"
                                                ,(string-append "-Mroot=" zig-file)
                                                ,(string-append "-Mrt=" (join-path runtime-dir "abi.zig"))
                                                ,(string-append "-femit-bin=" obj)))))
                           sources))))
          (unless (directory-exists? objects-dir) (make-directory objects-dir))
          ;; build the missing objects in parallel, then link
          (for-each (lambda (r) (check-run "zig build-obj" r))
                    (run-parallel (lambda (job) (run-program/capture (cadr job)))
                                  (filter (lambda (job) (not (file-exists? (car job)))) jobs)))
          (check-run "zig build-exe"
                     (run-program/capture `(,zig "build-exe" ,@common "-lc"
                                                 ,@(map car jobs)
                                                 ,(string-append "-femit-bin=" output))))
          output)))

    (define (content-hash text flags)
      (substring (bytevector->hex (sha256-hash (string-append flags "\n" text))) 0 24))

    (define (string-suffix? suffix s)
      (and (>= (string-length s) (string-length suffix))
           (string=? suffix (substring s (- (string-length s) (string-length suffix)) (string-length s)))))

    (define (check-run what r)
      (unless (and r (zero? (car r)))
        (error (string-append what " failed")
               (if r (string-append (cadr r) (caddr r)) "could not run zig"))))

    (define (write-if-changed file text)
      (unless (and (file-exists? file) (string=? (file->string file) text))
        (call-with-output-file file (lambda (p) (write-string text p)))))))

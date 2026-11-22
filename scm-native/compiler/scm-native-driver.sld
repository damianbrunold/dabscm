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

    ;; primitives that (scm native eval) implements (runtime/prims_module.zig)
    (define eval-hook-primitives '(macroexpand bound?))

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
    ;; lib-dir: the shared Scheme libraries (scm-lib); extra-dirs: more
    ;; directories to search for libraries (scmc's -I).
    (define (compile-to-zig file runtime-dir lib-dir target . extra-dirs)
      (let ((prims (runtime-primitives runtime-dir)))
        (check-duplicates prims)
        (let-values (((modules globs)
                      (let ((expand
                             (lambda extra
                               (apply expand-program
                                      file
                                      (append (list (directory-name (absolute-path file)))
                                              (if (pair? extra-dirs) (car extra-dirs) '())
                                              (list (join-path lib-dir "libraries")
                                                    ;; (scm native eval) and the expander it links
                                                    (join-path (directory-name (absolute-path runtime-dir)) "compiler")
                                                    ;; the native implementations of libraries ((scm native http))
                                                    (join-path (directory-name (absolute-path runtime-dir)) "lib")
                                                    "."))
                                      (target-features target)
                                      (map car prims)
                                      (join-path lib-dir "library.scm")
                                      extra))))
                        (let-values (((modules globs) (expand)))
                          ;; primitives that need the expander at run time: again,
                          ;; with (scm native eval) linked
                          (if (and (any (lambda (p) (memq p (used-primitives))) eval-hook-primitives)
                                   (not (assoc '(scm native eval) modules)))
                              (expand '((import (only (scm native eval)))))
                              (values modules globs))))))
          (unless (null? (missing-primitives))
            (let ((err (current-error-port)))
              (display "scmc: warning: primitives not implemented in dabscm native yet:" err)
              (for-each (lambda (p) (display " " err) (display p err)) (missing-primitives))
              (newline err)))
          ;; a program that links eval carries the expander's state
          (set-eval-state!
           (and (assoc '(scm native eval) modules)
                (let ((out (open-output-string)))
                  (write (expander-state) out)
                  (get-output-string out))))
          (set-user-libraries! (user-library-exports (absolute-path (join-path lib-dir "libraries"))))
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

    ;; Run the commands of jobs ((output command) ...), at most as many at a
    ;; time as there are cores (each Zig compilation of a large module takes
    ;; a lot of memory), as processes: each writes its output to
    ;; output.log. The results are as run-program/capture's:
    ;; (exit-code output "").
    (define (run-batched jobs)
      (let ((n (max 1 (sys-num-cpu-cores))))
        (let loop ((jobs jobs) (acc '()))
          (if (null? jobs)
              (reverse acc)
              (let* ((k (min n (length jobs)))
                     (batch (list-head jobs k))
                     (procs (map (lambda (job)
                                   (let ((log (string-append (car job) ".log")))
                                     (cons log (start-program (cadr job) (list (list 'log-file log))))))
                                 batch))
                     (results (map (lambda (p)
                                     (let* ((code (process-wait (cdr p)))
                                            (out (if (file-exists? (car p)) (file->string (car p)) "")))
                                       (when (file-exists? (car p)) (delete-file (car p)))
                                       (list code out "")))
                                   procs)))
                (loop (list-tail jobs k) (append (reverse results) acc)))))))

    (define (list-head l k) (if (= k 0) '() (cons (car l) (list-head (cdr l) (- k 1)))))

    ;; The default target: a static (musl) executable on Linux
    (define (default-target)
      (if (eq? (sys-platform) 'linux) "x86_64-linux-musl" #f))

    ;; Compile the program in file to the executable output.
    ;; options: alist with 'optimize ("ReleaseFast", "ReleaseSafe", "Debug"),
    ;; 'target (a Zig target triple or #f), 'build-dir, 'zig, 'search-dirs
    ;; (a list of library directories).
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
                                         (join-path (directory-name native-dir) "scm-lib") target
                                         (opt 'search-dirs '())))
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
               (c-jobs (c-object-jobs native-dir objects-dir zig common flags))
               (jobs
                (cons (list rt-obj `(,zig "build-obj" ,@common "-lc"
                                          ,(join-path runtime-dir "rtmain.zig")
                                          ,(string-append "-femit-bin=" rt-obj)))
                      (append
                       c-jobs
                       (map (lambda (m)
                             ;; the source file is named by the hash as well: compilations
                             ;; running at the same time in one build directory must not
                             ;; overwrite each other's source
                             (let* ((sym (car m))
                                    (hash (content-hash (string-append (cdr m) abi-text) flags))
                                    (zig-file (join-path cfg-dir (string-append sym "-" hash ".zig")))
                                    (obj (join-path objects-dir (string-append sym "-" hash ".o"))))
                               (write-if-changed zig-file (cdr m))
                               (list obj `(,zig "build-obj" ,@common
                                                "--dep" "rt"
                                                ,(string-append "-Mroot=" zig-file)
                                                ,(string-append "-Mrt=" (join-path runtime-dir "abi.zig"))
                                                ,(string-append "-femit-bin=" obj)))))
                           sources)))))
          (unless (directory-exists? objects-dir) (make-directory objects-dir))
          ;; build the missing objects in parallel, then link
          (for-each (lambda (r) (check-run "zig build-obj" r))
                    (run-batched (filter (lambda (job) (not (file-exists? (car job)))) jobs)))
          (check-run "zig build-exe"
                     (run-program/capture `(,zig "build-exe" ,@common "-lc"
                                                 ,@(map car jobs)
                                                 ,(string-append "-femit-bin=" output))))
          output)))

    ;; The C sources linked into every program: the vendored zlib and the
    ;; runtime's interface to it. One object per file, all named by the hash
    ;; of every C source and header (and the flags).
    (define zlib-dir "zlib-1.3.1")
    (define zlib-sources '("adler32" "crc32" "deflate" "inflate" "inffast" "inftrees" "trees" "zutil"))

    (define (c-object-jobs native-dir objects-dir zig common flags)
      (let* ((zdir (join-path native-dir "vendor" zlib-dir))
             (files (append (map (lambda (s) (join-path zdir (string-append s ".c"))) zlib-sources)
                            (list (join-path native-dir "runtime" "zshim.c"))))
             (headers (map (lambda (f) (join-path zdir f))
                           (list-sort string<? (filter (lambda (f) (string-suffix? ".h" f))
                                                       (directory-files zdir)))))
             (hash (content-hash (apply string-append (map file->string (append files headers))) flags)))
        (map (lambda (file)
               (let* ((base (file-name-base file))
                      (obj (join-path objects-dir (string-append "c-" base "-" hash ".o"))))
                 (list obj `(,zig "build-obj" ,@common "-lc" "-I" ,zdir ,file
                                  ,(string-append "-femit-bin=" obj)))))
             files)))

    (define (file-name-base file)
      (let* ((name (let loop ((i (- (string-length file) 1)))
                     (cond ((< i 0) file)
                           ((char=? (string-ref file i) #\/) (substring file (+ i 1) (string-length file)))
                           (else (loop (- i 1)))))))
        (substring name 0 (- (string-length name) 2))))

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

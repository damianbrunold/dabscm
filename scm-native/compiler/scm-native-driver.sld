(define-library (scm native driver)
  (export compile-program
          compile-to-zig
          runtime-primitives)
  (import (scheme base)
          (scheme file)
          (only (scheme process-context) get-environment-variable)
          (scheme read)
          (scheme write)
          (scheme char)
          (only (scheme time) current-second)
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
          (scm native emit)
          (scm native split))
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
      (let* ((t (or target (host-target)))
             (has? (lambda (part) (string-contains t part))))
        (append '(r7rs scm dabscm-native exact-closed ieee-float)
                (cond ((has? "windows") '(windows))
                      ((has? "macos") '(darwin unix))
                      (else '(gnu-linux unix)))
                (cond ((has? "aarch64") '(arm64))
                      (else '(x86-64)))
                '(little-endian)
                srfi-features)))

    ;; the machine the compiler runs on, as a target triple (no --target:
    ;; scmc builds for it), from the running implementation's features
    (define (host-target)
      (let ((fs (features)))
        (string-append (if (memq 'arm64 fs) "aarch64" "x86_64")
                       (cond ((memq 'windows fs) "-windows")
                             ((memq 'darwin fs) "-macos")
                             (else "-linux")))))

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
          (set-eager-modules! (program-eager-modules))
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
                                       ;; (Windows: another build in the same directory
                                       ;; may hold the same log open)
                                       (guard (e (#t #f))
                                         (when (file-exists? (car p)) (delete-file (car p))))
                                       (list code out "")))
                                   procs)))
                (loop (list-tail jobs k) (append (reverse results) acc)))))))

    (define (list-head l k) (if (= k 0) '() (cons (car l) (list-head (cdr l) (- k 1)))))

    ;; The default target: a static (musl) executable on Linux
    (define (default-target)
      (if (eq? (sys-platform) 'linux) "x86_64-linux-musl" #f))

    (define (env name)
      (let ((v (get-environment-variable name)))
        (and v (not (string=? v "")) v)))

    ;; Zig: SCM_NATIVE_ZIG, else the one an installation bundles (zig/ next
    ;; to scm-native, as the Debian package installs it), else zig on the PATH
    (define (default-zig native-dir)
      (or (env "SCM_NATIVE_ZIG")
          (let ((bundled (join-path (directory-name native-dir) "zig"
                                    (if (eq? (sys-platform) 'windows) "zig.exe" "zig"))))
            (and (file-exists? bundled) bundled))
          "zig"))

    ;; The build directory (objects, generated Zig, Zig's cache): SCM_NATIVE_BUILD,
    ;; else scm-native/build when it can be written (a checkout), else the
    ;; user's cache directory (an installation)
    (define (default-build-dir native-dir)
      (let ((own (join-path native-dir "build")))
        (or (env "SCM_NATIVE_BUILD")
            (and (guard (e (#t #f))
                   (unless (directory-exists? own) (make-directory own))
                   (let ((probe (join-path own ".writable")))
                     (call-with-output-file probe (lambda (p) (write-string "" p)))
                     (delete-file probe)
                     #t))
                 own)
            (let ((cache (join-path (or (env "XDG_CACHE_HOME")
                                        (env "LOCALAPPDATA")
                                        (join-path (or (env "HOME") (env "USERPROFILE") ".") ".cache"))
                                    "dabscm-native")))
              (make-directories cache)
              cache))))

    (define (make-directories dir)
      (unless (directory-exists? dir)
        (let ((parent (directory-name dir)))
          (unless (or (string=? parent "") (string=? parent dir))
            (make-directories parent)))
        (make-directory dir)))

    ;; Compile the program in file to the executable output.
    ;; options: alist with 'optimize ("ReleaseFast", "ReleaseSafe", "Debug"),
    ;; 'target (a Zig target triple or #f), 'build-dir, 'zig, 'search-dirs,
    ;; 'strip (#t: no debug information in the executable), 'cpu (a Zig CPU
    ;; name such as native or x86_64_v3; the default is the target's baseline)
    ;; (a list of library directories).
    (define (compile-program file output native-dir options)
      (define (opt key default)
        (cond ((assq key options) => cdr)
              (else default)))
      (let* ((runtime-dir (join-path native-dir "runtime"))
             (optimize-mode (opt 'optimize "ReleaseFast"))
             (target (opt 'target (default-target)))
             (build-dir (opt 'build-dir (default-build-dir native-dir)))
             (cfg-dir (join-path build-dir (string-append (or target "native") "-" optimize-mode)))
             (cache (join-path build-dir "zig-cache"))
             (zig (opt 'zig (default-zig native-dir)))
             (common `(,(string-append "-O" optimize-mode)
                       ,@(if (string=? optimize-mode "Debug") '("-fllvm") '())
                       ,@(if target (list "-target" target) '())
                       ,@(let ((cpu (opt 'cpu #f))) (if cpu (list (string-append "-mcpu=" cpu)) '()))
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
               (_ (unless (directory-exists? objects-dir) (make-directory objects-dir)))
               (jobs
                (cons (list rt-obj `(,zig "build-obj" ,@common "-lc"
                                          ,(join-path runtime-dir "rtmain.zig")
                                          ,(string-append "-femit-bin=" rt-obj)))
                      (append
                       c-jobs
                       (append-map (lambda (m)
                                     (module-jobs m zig common flags abi-text cfg-dir objects-dir
                                                  (join-path runtime-dir "abi.zig")))
                                   sources)))))
          ;; build the missing objects in parallel, then link
          (for-each (lambda (r) (check-run "zig build-obj" r))
                    (run-batched (filter (lambda (job) (not (file-exists? (car job)))) jobs)))
          (check-run "zig build-exe"
                     (run-program/capture `(,zig "build-exe" ,@common "-lc"
                                                 ,@(if (opt 'strip #f) '("-fstrip") '())
                                                 ;; Windows: the system's certificate
                                                 ;; store (std.crypto.tls)
                                                 ,@(if (if target
                                                           (string-contains target "windows")
                                                           (eq? (sys-platform) 'windows))
                                                       '("-lcrypt32" "-lws2_32" "-ladvapi32")
                                                       '())
                                                 ,@(map car jobs)
                                                 ,(string-append "-femit-bin=" output))))
          (prune-cache! build-dir objects-dir (map car jobs))
          output)))

    ;; The jobs ((object command) ...) of a module (sym . zig-text): one, or
    ;; one per part of a large module (scm native split), compiled in
    ;; parallel. Its source files are named by the hash as well:
    ;; compilations running at the same time in one build directory must
    ;; not overwrite each other's source. <base>.parts holds the number of
    ;; parts, so that a module whose parts are built is not split again.
    (define split-threshold 4000000) ; characters of Zig
    (define split-target 2000000)
    (define split-version "split 1") ; in a split module's hash

    (define (module-jobs m zig common flags abi-text cfg-dir objects-dir abi-file)
      (let* ((sym (car m))
             (text (cdr m))
             (big? (> (string-length text) split-threshold))
             (hash (content-hash (string-append text abi-text (if big? split-version "")) flags))
             (base (string-append sym "-" hash))
             (job (lambda (zig-file obj)
                    (list obj `(,zig "build-obj" ,@common
                                     "--dep" "rt"
                                     ,(string-append "-Mroot=" zig-file)
                                     ,(string-append "-Mrt=" abi-file)
                                     ,(string-append "-femit-bin=" obj))))))
        (if (not big?)
            (let ((zig-file (join-path cfg-dir (string-append base ".zig"))))
              (write-if-changed zig-file text)
              (list (job zig-file (join-path objects-dir (string-append base ".o")))))
            (let* ((manifest (join-path objects-dir (string-append base ".parts")))
                   (part (lambda (dir i ext)
                           (join-path dir (string-append base "-p" (number->string i) ext))))
                   (built (and (file-exists? manifest)
                               (let ((n (guard (e (#t #f)) (call-with-input-file manifest read))))
                                 (and (exact-integer? n)
                                      (every (lambda (i) (file-exists? (part objects-dir i ".o"))) (iota n))
                                      n))))
                   (n (or built
                          (let ((parts (split-module sym text split-target)))
                            (let loop ((ps parts) (i 0))
                              (when (pair? ps)
                                (write-if-changed (part cfg-dir i ".zig") (car ps))
                                (loop (cdr ps) (+ i 1))))
                            (call-with-output-file manifest
                              (lambda (p) (write (length parts) p) (newline p)))
                            (length parts)))))
              (map (lambda (i) (job (part cfg-dir i ".zig") (part objects-dir i ".o"))) (iota n))))))

    ;; --- the object cache --------------------------------------------------
    ;; Objects are named by the hash of their input, so every change of the
    ;; compiler or the runtime leaves the earlier ones behind. After a link,
    ;; the objects it used are marked (their .log rewritten: its time is the
    ;; last use), and at most once an hour the cache is cleaned up: objects
    ;; unused for 14 days go, and then the least recently used ones while
    ;; the objects take more than SCM_NATIVE_CACHE_MB (default 4096) MB;
    ;; never one used within the last hour (another compilation may be about
    ;; to link it). Then the generated sources whose object is gone, and
    ;; Zig's cache of parsed files (zig-cache/z) in the same way, with a
    ;; quarter of the limit.
    (define hour-ms (* 3600 1000))
    (define max-unused-ms (* 14 24 hour-ms))

    (define (now-ms) (exact (round (* 1000 (current-second)))))

    (define (cache-limit-bytes)
      (* 1024 1024 (let ((v (env "SCM_NATIVE_CACHE_MB")))
                     (or (and v (let ((n (string->number v))) (and n (> n 0) n))) 4096))))

    (define (mark-used! obj)
      (let ((log (string-append obj ".log")))
        (guard (e (#t #f))
          (let ((text (if (file-exists? log) (file->string log) "")))
            (call-with-output-file log (lambda (p) (write-string text p)))))))

    (define (prune-cache! build-dir objects-dir used)
      (for-each mark-used! used)
      (let ((marker (join-path objects-dir "last-cleanup"))
            (now (now-ms)))
        (when (or (not (file-exists? marker))
                  (> (- now (file-modification-timestamp marker)) hour-ms))
          (guard (e (#t #f))
            (call-with-output-file marker (lambda (p) (write-string "" p)))
            (prune-files! objects-dir ".o" (lambda (f) (list (string-append f ".log")))
                          (cache-limit-bytes) now)
            (prune-orphans! objects-dir now)
            (prune-sources! build-dir objects-dir now)
            (let ((z (join-path build-dir "zig-cache" "z")))
              (when (directory-exists? z)
                (prune-files! z "" (lambda (f) '()) (quotient (cache-limit-bytes) 4) now)))))))

    (define (try-delete! f) (guard (e (#t #f)) (when (file-exists? f) (delete-file f))))

    ;; the files of dir ending in suffix, with their companions: the unused
    ;; for 14 days, then the oldest while they take more than limit bytes
    (define (prune-files! dir suffix companions limit now)
      (let* ((entries
              (filter-map
               (lambda (name)
                 (and (string-suffix? suffix name)
                      (let* ((f (join-path dir name))
                             (others (filter file-exists? (companions f))))
                        (guard (e (#t #f))
                          (list f
                                (apply max (map file-modification-timestamp (cons f others)))
                                (apply + (map file-size (cons f others)))
                                others)))))
               (directory-files dir)))
             (sorted (list-sort (lambda (a b) (< (cadr a) (cadr b))) entries))
             (delete! (lambda (e) (for-each try-delete! (cons (car e) (list-ref e 3))))))
        (let loop ((es sorted) (total (apply + 0 (map caddr entries))))
          (when (pair? es)
            (let* ((e (car es))
                   (age (- now (cadr e))))
              (cond ((> age max-unused-ms)
                     (delete! e)
                     (loop (cdr es) (- total (caddr e))))
                    ((and (> total limit) (> age hour-ms))
                     (delete! e)
                     (loop (cdr es) (- total (caddr e))))))))))

    ;; logs of failed builds and the part counts of modules whose parts are gone
    (define (prune-orphans! objects-dir now)
      (for-each
       (lambda (name)
         (let ((f (join-path objects-dir name)))
           (guard (e (#t #f))
             (when (> (- now (file-modification-timestamp f)) hour-ms)
               (cond ((string-suffix? ".o.log" name)
                      (unless (file-exists? (substring f 0 (- (string-length f) 4)))
                        (try-delete! f)))
                     ((string-suffix? ".parts" name)
                      (unless (file-exists? (string-append (substring f 0 (- (string-length f) 6))
                                                           "-p0.o"))
                        (try-delete! f))))))))
       (directory-files objects-dir)))

    ;; the generated Zig sources (<target>-<mode>/<module>-<hash>[-p<i>].zig)
    ;; whose object is gone
    (define (prune-sources! build-dir objects-dir now)
      (for-each
       (lambda (d)
         (when (any (lambda (mode) (string-suffix? mode d))
                    '("-ReleaseFast" "-ReleaseSafe" "-ReleaseSmall" "-Debug"))
           (let ((dir (join-path build-dir d)))
             (for-each
              (lambda (name)
                (when (string-suffix? ".zig" name)
                  (let ((f (join-path dir name)))
                    (guard (e (#t #f))
                      (when (and (> (- now (file-modification-timestamp f)) hour-ms)
                                 (not (file-exists?
                                       (join-path objects-dir
                                                  (string-append (substring name 0 (- (string-length name) 4))
                                                                 ".o")))))
                        (try-delete! f))))))
              (directory-files dir)))))
       (directory-directories build-dir)))

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
                           ((memv (string-ref file i) '(#\/ #\\)) (substring file (+ i 1) (string-length file)))
                           (else (loop (- i 1)))))))
        (substring name 0 (- (string-length name) 2))))

    (define (content-hash text flags)
      (substring (bytevector->hex (sha256-hash (string-append flags "\n" text))) 0 24))

    (define (string-suffix? suffix s)
      (and (>= (string-length s) (string-length suffix))
           (string=? suffix (substring s (- (string-length s) (string-length suffix)) (string-length s)))))

    (define (check-run what r)
      (unless (and r (zero? (car r)))
        ;; the exit code too: a Zig killed by a signal (out of memory, say)
        ;; prints nothing
        (error (if (and r (car r))
                   (string-append what " failed (exit code " (number->string (car r)) ")")
                   (string-append what " failed"))
               (if r (string-append (cadr r) (caddr r)) "could not run zig"))))

    (define (write-if-changed file text)
      (unless (and (file-exists? file) (string=? (file->string file) text))
        (call-with-output-file file (lambda (p) (write-string text p)))))))

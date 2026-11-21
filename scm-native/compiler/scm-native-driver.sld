(define-library (scm native driver)
  (export compile-program
          compile-to-zig
          runtime-primitives)
  (import (scheme base)
          (scheme file)
          (scheme read)
          (scheme write)
          (srfi 1)
          (scm fs)
          (scm io)
          (scm system)
          (scm native ast)
          (scm native expand)
          (scm native optimize)
          (scm native anf)
          (scm native emit))
  (begin
;; Primitives the runtime provides: the `pub const @"%name"` declarations
    ;; of runtime/prims*.zig, as an alist name -> Zig module (rt.<module>).
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
                                      (cons (string->symbol (substring line (string-length prefix) i))
                                            module)
                                      (loop (+ i 1))))))
                         (read-file-lines (join-path runtime-dir file)))))
         (filter (lambda (f) (and (>= (string-length f) 9)
                                  (string=? (substring f 0 5) "prims")
                                  (string=? (substring f (- (string-length f) 4) (string-length f)) ".zig")))
                 (directory-files runtime-dir)))))

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

    ;; The Zig source of the program module for the program in file.
    ;; lib-dir: the shared Scheme libraries (scm-lib).
    (define (compile-to-zig file runtime-dir lib-dir target)
      (let ((prims (runtime-primitives runtime-dir)))
        (check-duplicates prims)
        (let-values (((ast globs)
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
          (let ((ast (anf (optimize ast))))
            (compute-free! ast)
            (emit-program ast prims)))))

    ;; Compile the program in file to the executable output.
    ;; options: alist with 'optimize ("ReleaseFast", "ReleaseSafe", "Debug"),
    ;; 'target (a Zig target triple or #f), 'build-dir, 'zig.
    (define (compile-program file output native-dir options)
      (define (opt key default)
        (cond ((assq key options) => cdr)
              (else default)))
      (let* ((runtime-dir (join-path native-dir "runtime"))
             (build-dir (opt 'build-dir (join-path native-dir "build")))
             (zig-file (join-path build-dir (string-append (base-name output) ".zig")))
             (optimize (opt 'optimize "ReleaseFast"))
             (target (opt 'target #f))
             (zig (opt 'zig "zig")))
        (unless (directory-exists? build-dir) (make-directory build-dir))
        (let ((source (compile-to-zig file runtime-dir
                                      (join-path (directory-name native-dir) "scm-lib") target)))
          (call-with-output-file zig-file (lambda (p) (write-string source p))))
        (let ((cmd `(,zig "build-exe" ,(string-append "-O" optimize)
                          ,@(if (string=? optimize "Debug") '("-fllvm") '())
                          ,@(if target (list "-target" target) '())
                          "--dep" "rt" "--dep" "program"
                          ,(string-append "-Mroot=" (join-path runtime-dir "main.zig"))
                          "--dep" "rt"
                          ,(string-append "-Mprogram=" zig-file)
                          ,(string-append "-Mrt=" (join-path runtime-dir "rt.zig"))
                          "--cache-dir" ,(join-path build-dir "zig-cache")
                          ,(string-append "-femit-bin=" output))))
          (let ((r (run-program/capture cmd)))
            (unless (and r (zero? (car r)))
              (error "zig build-exe failed"
                     (if r (string-append (cadr r) (caddr r)) "could not run zig")))
            output))))))

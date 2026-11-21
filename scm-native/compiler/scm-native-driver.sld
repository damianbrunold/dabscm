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
          (scm native frontend)
          (scm native anf)
          (scm native emit))
  (begin
    ;; Primitive names the runtime provides: the `pub const @"%name"`
    ;; declarations of runtime/prims.zig.
    (define (runtime-primitives runtime-dir)
      (let ((prefix "pub const @\"%"))
        (filter-map (lambda (line)
                      (and (>= (string-length line) (string-length prefix))
                           (string=? (substring line 0 (string-length prefix)) prefix)
                           (let loop ((i (string-length prefix)))
                             (if (char=? (string-ref line i) #\")
                                 (string->symbol (substring line (string-length prefix) i))
                                 (loop (+ i 1))))))
                    (read-file-lines (join-path runtime-dir "prims.zig")))))

    (define (read-forms file)
      (call-with-input-file file
        (lambda (port)
          (let loop ((forms '()))
            (let ((f (read port)))
              (if (eof-object? f)
                  (reverse forms)
                  (loop (cons f forms))))))))

    ;; The Zig source of the program module for the program in file
    (define (compile-to-zig file runtime-dir)
      (let ((prims (runtime-primitives runtime-dir)))
        (let-values (((ast globals) (frontend (read-forms file) prims)))
          (let ((ast (anf ast)))
            (compute-free! ast)
            (emit-program ast globals prims)))))

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
        (let ((source (compile-to-zig file runtime-dir)))
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

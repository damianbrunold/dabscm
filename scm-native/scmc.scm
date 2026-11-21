;; scmc: compile a Scheme program to a native executable (Phase 1).
;;
;; Usage: scm scm-native/scmc.scm program.scm [-o output] [-O mode]
;;                                [--target triple] [--emit-zig]
;;   -O mode      ReleaseFast (default), ReleaseSafe or Debug
;;   --target     a Zig target such as x86_64-windows or aarch64-macos
;;   --emit-zig   print the generated Zig instead of building

(import (scheme base)
        (scheme process-context)
        (scheme write)
        (scm fs)
        (scm module))

(define native-dir (directory-name (absolute-path (car (command-line)))))
(module-search-path! (cons (join-path native-dir "compiler") (module-search-path)))

(import (scm native driver))

(define (usage)
  (display "usage: scmc program.scm [-o output] [-O mode] [--target triple] [--emit-zig]\n")
  (exit 2))

(define (strip-extension path)
  (let loop ((i (- (string-length path) 1)))
    (cond ((< i 0) path)
          ((char=? (string-ref path i) #\.) (substring path 0 i))
          ((char=? (string-ref path i) #\/) path)
          (else (loop (- i 1))))))

(let loop ((args (cdr (command-line))) (input #f) (output #f) (options '()) (emit #f))
  (cond ((null? args)
         (unless input (usage))
         (if emit
             (display (compile-to-zig input (join-path native-dir "runtime")))
             (compile-program input (or output (strip-extension input)) native-dir options)))
        ((and (string=? (car args) "-o") (pair? (cdr args)))
         (loop (cddr args) input (cadr args) options emit))
        ((and (string=? (car args) "-O") (pair? (cdr args)))
         (loop (cddr args) input output (cons (cons 'optimize (cadr args)) options) emit))
        ((and (string=? (car args) "--target") (pair? (cdr args)))
         (loop (cddr args) input output (cons (cons 'target (cadr args)) options) emit))
        ((string=? (car args) "--emit-zig")
         (loop (cdr args) input output options #t))
        ((not input) (loop (cdr args) (car args) output options emit))
        (else (usage))))

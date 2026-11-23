;; scmc: compile a Scheme program to a native executable (Phase 1).
;;
;; Usage: scm scm-native/scmc.scm program.scm [-o output] [-O mode]
;;                                [--target triple] [--emit-zig]
;;   -O mode      ReleaseFast (default), ReleaseSafe or Debug
;;   --target     a Zig target such as x86_64-windows or aarch64-macos
;;   --cpu        a Zig CPU name: native (this machine's), x86_64_v3, ...;
;;                the default is the target's baseline (runs everywhere)
;;   --strip      no debug information in the executable (for packages)
;;   --emit-zig   print the generated Zig instead of building
;;   -I dir       also search dir for libraries
;;
;; Compiled natively (scm scm-native/scmc.scm scm-native/scmc.scm
;; -I scm-native/compiler -o scm-native/build/scmc), it finds scm-native
;; from SCM_NATIVE_DIR, else as the parent of the directory of the
;; executable.

(import (scheme base)
        (scheme process-context)
        (scheme write)
        (scm fs))

(cond-expand
  (dabscm-native
   (define native-dir
     (or (get-environment-variable "SCM_NATIVE_DIR")
         (directory-name (directory-name (normalized-path (absolute-path (car (command-line)))))))))
  (else
   (import (scm module))
   (define native-dir (directory-name (normalized-path (absolute-path (car (command-line))))))))
;; on the JVM, the compiler's libraries are found at run time
(cond-expand
  (dabscm-native)
  (else (module-search-path! (cons (join-path native-dir "compiler") (module-search-path)))))

(import (scm native driver))

(define (usage)
  (display "usage: scmc program.scm [-o output] [-O mode] [--target triple] [--strip] [--emit-zig] [-I dir]\n")
  (exit 2))

(define (search-dirs options)
  (cond ((assq 'search-dirs options) => cdr)
        (else '())))

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
             (for-each (lambda (m)
                         (display "//// module ") (display (car m)) (newline)
                         (display (cdr m)))
                       (compile-to-zig input (join-path native-dir "runtime")
                                       (join-path (directory-name native-dir) "scm-lib")
                                       (cond ((assq 'target options) => cdr) (else #f))
                                       (search-dirs options)))
             (compile-program input (or output (strip-extension input)) native-dir options)))
        ((and (string=? (car args) "-o") (pair? (cdr args)))
         (loop (cddr args) input (cadr args) options emit))
        ((and (string=? (car args) "-O") (pair? (cdr args)))
         (loop (cddr args) input output (cons (cons 'optimize (cadr args)) options) emit))
        ((and (string=? (car args) "--target") (pair? (cdr args)))
         (loop (cddr args) input output (cons (cons 'target (cadr args)) options) emit))
        ((and (string=? (car args) "-I") (pair? (cdr args)))
         (loop (cddr args) input output
               (cons (cons 'search-dirs (append (search-dirs options) (list (absolute-path (cadr args)))))
                     options)
               emit))
        ((and (string=? (car args) "--cpu") (pair? (cdr args)))
         (loop (cddr args) input output (cons (cons 'cpu (cadr args)) options) emit))
        ((string=? (car args) "--strip")
         (loop (cdr args) input output (cons (cons 'strip #t) options) emit))
        ((string=? (car args) "--emit-zig")
         (loop (cdr args) input output options #t))
        ((not input) (loop (cdr args) (car args) output options emit))
        (else (usage))))

;; Soak tests: compile every scenario in scm-native/soak natively, run it
;; for SOAK_ROUNDS rounds (default 10), and check that nothing it holds
;; keeps growing: the live heap, ports, native objects, threads, open
;; files, resident memory (see soak/soak-lib.sld).
;;
;; Usage: scm scm-native/soak.scm [-O ReleaseSafe] [--target t] [--rounds n] [--scale n] [name ...]
;;   -O: the build mode (default ReleaseFast; ReleaseSafe adds Zig's checks)
;;   --target: e.g. x86_64-linux-gnu: with glibc the samples include the C
;;     allocator's bytes in use (malloc-bytes), which tell a leak from
;;     fragmentation (the resident memory shows both)
;;   --scale: multiplies the work of each round

(import (scheme base)
        (scheme process-context)
        (scheme write)
        (srfi 1)
        (srfi 132)
        (scm fs)
        (scm module)
        (scm system))

(define native-dir (directory-name (normalized-path (absolute-path (car (command-line))))))
(module-search-path! (cons (join-path native-dir "compiler") (module-search-path)))

(import (scm native driver))

(define soak-dir (join-path native-dir "soak"))
(define build-dir (join-path native-dir "build" "soak"))

(define optimize "ReleaseFast")
(define target #f)
(define rounds "10")
(define scale "1")

(define (parse args)
  (cond ((null? args) '())
        ((and (string=? (car args) "-O") (pair? (cdr args)))
         (set! optimize (cadr args))
         (parse (cddr args)))
        ((and (string=? (car args) "--target") (pair? (cdr args)))
         (set! target (cadr args))
         (parse (cddr args)))
        ((and (string=? (car args) "--rounds") (pair? (cdr args)))
         (set! rounds (cadr args))
         (parse (cddr args)))
        ((and (string=? (car args) "--scale") (pair? (cdr args)))
         (set! scale (cadr args))
         (parse (cddr args)))
        (else (cons (car args) (parse (cdr args))))))

(define (scenario-names)
  (map (lambda (f) (substring f 0 (- (string-length f) 4)))
       (filter (lambda (f) (and (> (string-length f) 4)
                                (string=? (substring f (- (string-length f) 4) (string-length f)) ".scm")))
               (list-sort string<? (directory-files soak-dir)))))

(define (make-directories dir)
  (unless (directory-exists? dir)
    (make-directories (directory-name dir))
    (make-directory dir)))

(define failures '())

(define (run name)
  (let ((source (join-path soak-dir (string-append name ".scm")))
        (exe (join-path build-dir (string-append name "-" optimize (if target (string-append "-" target) "")))))
    (guard (e (#t (set! failures (cons name failures))
                  (display "soak ")
                  (display name)
                  (display ": COMPILE FAILED: ")
                  (display (if (error-object? e) (error-object-message e) e))
                  (newline)))
      (compile-program source exe native-dir
                       `((optimize . ,optimize) (search-dirs ,soak-dir)
                         ,@(if target `((target . ,target)) '())))
      (let ((r (run-program (list exe)
                            `((work-dir ,build-dir)
                              (env (("SOAK_ROUNDS" . ,rounds) ("SOAK_SCALE" . ,scale)))))))
        (unless (eqv? r 0)
          (set! failures (cons name failures)))))))

(define names (let ((given (parse (cdr (command-line)))))
                (if (pair? given) given (scenario-names))))
(make-directories build-dir)
(for-each run names)
(newline)
(display (- (length names) (length failures)))
(display " of ")
(display (length names))
(display " soak tests passed")
(unless (null? failures)
  (display "; failed: ")
  (display (reverse failures)))
(newline)
(exit (if (null? failures) 0 1))

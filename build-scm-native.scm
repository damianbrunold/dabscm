;; Builds the native scmc and scm into scm-native/build (scmc.exe and scm.exe
;; on Windows):
;;
;;   builder.bat build-scm-native.scm [--native] [--strip] [-O mode] [scmc|scm ...]
;;   ./builder.sh build-scm-native.scm ...
;;
;; By default the compiler runs on the JVM (scm-java/scm.jar, so build that
;; first with build-scm-java.scm), which takes a few minutes. --native uses
;; the native scmc already in scm-native/build instead, which is much faster
;; once the libraries are cached; it runs a copy (scmc-prev), since Windows
;; cannot replace an executable that is running. Names select what to build
;; (default: both). Zig 0.17.1 must be on the PATH or in SCM_NATIVE_ZIG.

(import (scheme base)
        (scheme process-context)
        (scheme write)
        (scm fs)
        (scm system))

(define (say . xs) (for-each display xs) (newline))

(define (fail . xs)
  (apply say "build-scm-native: " xs)
  (exit 1))

(define base-dir (directory-name (absolute-path (car (command-line)))))
(define (repo . parts) (apply join-path base-dir parts))

(define windows? (eq? (sys-platform) 'windows))
(define (exe-name base) (if windows? (string-append base ".exe") base))

(define build-dir (repo "scm-native" "build"))

;; name -> source and extra scmc arguments
(define targets
  '(("scmc" "scm-native/scmc.scm" "-I" "scm-native/compiler")
    ("scm" "scm-native/tools/scm.scm")))

;; --- arguments ---------------------------------------------------------------

(define native? #f)
(define options '())
(define selected '())

(define (usage)
  (fail "usage: build-scm-native.scm [--native] [--strip] [-O mode] [scmc|scm ...]"))

(let loop ((args (cdr (command-line))))
  (unless (null? args)
    (let ((a (car args)))
      (cond ((string=? a "--native")
             (set! native? #t)
             (loop (cdr args)))
            ((string=? a "--strip")
             (set! options (append options (list a)))
             (loop (cdr args)))
            ((string=? a "-O")
             (when (null? (cdr args)) (usage))
             (set! options (append options (list a (cadr args))))
             (loop (cddr args)))
            ((assoc a targets)
             (set! selected (append selected (list a)))
             (loop (cdr args)))
            (else (usage))))))

(when (null? selected) (set! selected (map car targets)))

;; --- compiler ----------------------------------------------------------------

(define compiler
  (if native?
      (let ((scmc (join-path build-dir (exe-name "scmc")))
            (prev (join-path build-dir (exe-name "scmc-prev"))))
        (unless (file-exists? scmc)
          (fail scmc " not found (build it once without --native)"))
        (when (eq? (copy-file scmc prev) #f)
          (fail "cannot copy " scmc " to " prev))
        (list prev))
      (let ((jar (repo "scm-java" "scm.jar"))
            (java (which (if windows? "java.exe" "java"))))
        (unless (file-exists? jar)
          (fail jar " not found (run build-scm-java.scm first)"))
        (unless java (fail "java not found"))
        (list java "-jar" jar (repo "scm-native" "scmc.scm")))))

;; --- build -------------------------------------------------------------------

(unless (directory-exists? build-dir) (make-directory build-dir))

(for-each
 (lambda (name)
   (let* ((t (assoc name targets))
          (out (join-path build-dir (exe-name name)))
          (cmd (append compiler
                       (list (repo (cadr t)) "-o" out)
                       options
                       (map (lambda (x) (if (string=? x "-I") x (repo x)))
                            (cddr t)))))
     (say "building " out " ...")
     (unless (zero? (run-program cmd `((work-dir ,base-dir))))
       (fail "building " name " failed"))))
 selected)

(say "done")

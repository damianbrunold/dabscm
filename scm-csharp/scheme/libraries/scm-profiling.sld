(define-library (scm profiling)
  (import (scheme base)
          (scheme cxr)
          (scheme write)
          (scheme time)
          (srfi 69)
          (srfi 132)
          (scm module)
          (scm io))
  (export profile-instrument!
          profile-uninstrument!
          profile-reset!
          profile-data
          profile-report)
  (begin

    ;; Global profile table: string-key -> #(call-count total-jiffies original module-decl symbol wrapper)
    (define *profile-table* (make-hash-table))

    (define (profile-reset!)
      "Syntax: (profile-reset!)
Library: (scm profiling)
Description: Resets all profiling counters and durations to zero.
Instrumented procedures remain in place.
Example:
  (profile-reset!)"
      (hash-table-walk *profile-table*
        (lambda (key entry)
          (vector-set! entry 0 0)
          (vector-set! entry 1 0))))

    (define (make-profile-key module-decl symbol)
      (let ((mod-str (let loop ((parts module-decl) (acc "("))
                       (if (null? parts)
                           (string-append acc ")")
                           (loop (cdr parts)
                                 (string-append acc
                                                (if (string=? acc "(") "" " ")
                                                (symbol->string (car parts))))))))
        (string-append mod-str ":" (symbol->string symbol))))

    (define (instrument-one! module-decl symbol)
      (let* ((key (make-profile-key module-decl symbol))
             (original (%module-ref module-decl symbol)))
        (when (procedure? original)
          (let* ((entry (vector 0 0 original module-decl symbol #f))
                 (wrapper
                  (lambda args
                    (vector-set! entry 0 (+ 1 (vector-ref entry 0)))
                    (let ((t0 (current-jiffy)))
                      (call-with-values
                        (lambda () (apply original args))
                        (lambda results
                          (vector-set! entry 1
                            (+ (- (current-jiffy) t0) (vector-ref entry 1)))
                          (apply values results)))))))
            (vector-set! entry 5 wrapper)
            (hash-table-set! *profile-table* key entry)
            ;; Rebind in source module
            (%module-bind module-decl symbol wrapper)
            ;; Rebind in all other modules that have the same original
            (let ((sym-str (symbol->string symbol)))
              (for-each
                (lambda (mod-decl)
                  (when (memq symbol (%module-bindings mod-decl))
                    (when (eq? (%module-ref mod-decl symbol) original)
                      (%module-bind mod-decl symbol wrapper))))
                (modules)))))))

    (define (profile-instrument! . specs)
      "Syntax: (profile-instrument! spec ...)
Library: (scm profiling)
Description: Instruments procedures for profiling. Each spec is a list
whose car is a library name (as a list of symbols). The remaining
elements are symbols naming the procedures to instrument. If no
symbols are given, all procedures defined in the library are
instrumented (including primitives bound in the library, but
excluding imported bindings).
Example:
  (profile-instrument! '((scheme base) map for-each))
  (profile-instrument! '((my lib)))"
      (for-each
        (lambda (spec)
          (let ((module-decl (car spec))
                (symbols (cdr spec)))
            (if (null? symbols)
                ;; Instrument all procedures defined in the module
                (for-each
                  (lambda (sym)
                    (let ((val (%module-ref module-decl sym)))
                      (when (procedure? val)
                        (instrument-one! module-decl sym))))
                  (%module-defined-bindings module-decl))
                ;; Instrument specified symbols
                (for-each
                  (lambda (sym)
                    (instrument-one! module-decl sym))
                  symbols))))
        specs))

    (define (profile-uninstrument!)
      "Syntax: (profile-uninstrument!)
Library: (scm profiling)
Description: Removes all instrumentation, restoring the original
procedures. Clears all profiling data.
Example:
  (profile-uninstrument!)"
      (hash-table-walk *profile-table*
        (lambda (key entry)
          (let ((original (vector-ref entry 2))
                (module-decl (vector-ref entry 3))
                (symbol (vector-ref entry 4))
                (wrapper (vector-ref entry 5)))
            ;; Restore in source module
            (%module-bind module-decl symbol original)
            ;; Restore in all other modules that have the wrapper
            (for-each
              (lambda (mod-decl)
                (when (memq symbol (%module-bindings mod-decl))
                  (when (eq? (%module-ref mod-decl symbol) wrapper)
                    (%module-bind mod-decl symbol original))))
              (modules)))))
      (set! *profile-table* (make-hash-table)))

    (define (profile-data)
      "Syntax: (profile-data)
Library: (scm profiling)
Description: Returns profiling data as a list of lists, each of the
form (name calls total-jiffies), sorted by total-jiffies descending.
Example:
  (profile-data)
  => ((\"(my lib):proc-a\" 1000 4523400) ...)"
      (let ((entries '()))
        (hash-table-walk *profile-table*
          (lambda (key entry)
            (set! entries
              (cons (list key
                          (vector-ref entry 0)
                          (vector-ref entry 1))
                    entries))))
        (list-sort (lambda (a b) (> (caddr a) (caddr b))) entries)))

    (define (profile-report . args)
      "Syntax: (profile-report)
       (profile-report port)
Library: (scm profiling)
Description: Prints a formatted profiling report showing procedure
name, call count, total time in ms, average time in ms, and
percentage of total time. Output goes to the current output port
or to the given port.
Example:
  (profile-report)"
      (let* ((port (if (null? args) #t (car args)))
             (data (profile-data))
             (total-jiffies (apply + (map caddr data)))
             (jpm (/ (jiffies-per-second) 1000)))
        (format port "~%Profile Report~%")
        (format port "~-40a ~8a ~12a ~10a ~6a~%" "Name" "Calls" "Total ms" "Avg ms" "%")
        (format port "~a~%" (make-string 80 #\-))
        (for-each
          (lambda (entry)
            (let* ((name (car entry))
                   (calls (cadr entry))
                   (jiffies (caddr entry))
                   (ms (/ jiffies jpm))
                   (avg (if (> calls 0) (/ ms calls) 0))
                   (pct (if (> total-jiffies 0)
                            (* 100.0 (/ jiffies total-jiffies))
                            0.0)))
              (unless (zero? calls)
                (format port "~-40a ~8a ~12,2f ~10,2f ~5,1f%~%"
                        name calls ms avg pct))))
          data)
        (format port "~a~%" (make-string 80 #\-))
        (let ((total-calls (apply + (map cadr data)))
              (total-ms (/ total-jiffies jpm)))
          (format port "~-40a ~8a ~12,2f~%" "Total" total-calls total-ms))))))

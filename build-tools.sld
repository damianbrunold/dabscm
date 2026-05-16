(define-library (build tools)
  (export base-dir
          java-dir
          csharp-dir
          csharp-tests-dir
          dotnet-cmd
          java-cmd
          title
          failure?
          check-java-version
          check-dotnet-version
          run-builder
          run-tool-in-base
          run-tool-in-java
          run-tool-in-csharp
          run-tool-in-csharp-tests)
  (import (scheme base)
          (scheme write)
          (scheme process-context)
          (scm fs)
          (scm io)
          (scm system))
  (begin
    (define base-dir (directory-name (absolute-path (car (command-line)))))
    (define java-dir (join-path base-dir "scm-java"))
    (define csharp-dir (join-path base-dir "scm-csharp"))
    (define csharp-tests-dir (join-path csharp-dir "tests"))
    
    (define dotnet-cmd (if (eq? (sys-platform) 'windows)
                           (which "dotnet.exe")
                           (which "dotnet")))

    (define java-cmd (if (eq? (sys-platform) 'windows)
                         (which "java.exe")
                         (which "java")))

    (define (builder-cmd script args)
      `(,java-cmd "-jar" ,(join-path base-dir "scm-bootstrap.jar") ,script ,@args))
    
    (define (title s)
      (newline)
      (display s)
      (newline))

    (define (failure? x)
      (not (zero? x)))

    (define (check-java-version)
      (display "java ")
      (if (failure? (run-program `(,java-cmd "--version")))
          (error "java not available")))

    (define (check-dotnet-version)
      (display "dotnet ")
      (if (failure? (run-program `(,dotnet-cmd "--version")))
          (error "dotnet not available")))

    (define (run-builder script . args)
      (if (failure? (run-program (builder-cmd script args) `((work-dir ,base-dir))))
          (error (format #f "builder failed ~a ~a" script args))))

    (define (run-tool-in-base name cmd-line)
      (title (format #f "running ~a" name))
      (if (failure? (run-program cmd-line `((work-dir ,base-dir))))
          (error (format #f "~a failed" name))))
    
    (define (run-tool-in-java name cmd-line)
      (title (format #f "running ~a" name))
      (if (failure? (run-program cmd-line `((work-dir ,java-dir))))
          (error (format #f "~a failed" name))))
    
    (define (run-tool-in-csharp name cmd-line)
      (title (format #f "running ~a" name))
      (if (failure? (run-program cmd-line `((work-dir ,csharp-dir))))
          (error (format #f "~a failed" name))))
    
    (define (run-tool-in-csharp-tests name cmd-line)
      (title (format #f "running ~a" name))
      (if (failure? (run-program cmd-line `((work-dir ,csharp-tests-dir))))
          (error (format #f "~a failed" name))))
    ))

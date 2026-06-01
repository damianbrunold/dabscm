(import (scheme base)
        (scheme write)
        (scm test)
        (scm args))

(test-runner-factory scm-test-runner)

;; substring search (avoids pulling in srfi 13 just for this)
(define (has-substring? hay needle)
  (let ((hn (string-length hay)) (nn (string-length needle)))
    (let loop ((i 0))
      (cond ((> (+ i nn) hn) #f)
            ((string=? (substring hay i (+ i nn)) needle) #t)
            (else (loop (+ i 1)))))))

(test-begin "args")

;; A parser exercising every feature, used across groups.
(define (make-cli)
  (define-cli
    (program "tool")
    (description "A test tool.")
    (version "9.9")
    (option width   (short #\w) (long "width")   (type arg:integer) (required #t) (help "Width"))
    (option quality (short #\q) (long "quality") (type arg:integer) (default 85))
    (option mode    (long "mode") (type (arg:one-of 'fast 'slow)) (default 'fast))
    (option ratio   (long "ratio") (type arg:number))
    (option name    (long "name") (type arg:symbol))
    (option tags    (long "tag") (type arg:string) (repeat #t))
    (option nums    (long "nums") (type (arg:list arg:integer)))
    (flag   verbose (short #\v) (long "verbose"))
    (flag   color   (long "color") (default #t))
    (positional input  (type arg:string) (required #t))
    (positional output (type arg:string))))

;; helper: parse in raise mode so a failure does not exit the process
(define (parse args) (parse-args (make-cli) args 'on-error 'raise))

;; ------------------------------------------------------------------
(test-group "positionals-and-types"
  (let ((r (parse '("-w" "100" "in.txt" "out.txt"))))
    (test-equal 100 (args-ref r 'width))
    (test-equal "in.txt" (args-ref r 'input))
    (test-equal "out.txt" (args-ref r 'output)))
  ;; optional positional absent -> fallback
  (let ((r (parse '("-w" "1" "in.txt"))))
    (test-equal #f (args-ref r 'output))
    (test-equal "-" (args-ref r 'output "-"))))

(test-group "flags"
  (let ((r (parse '("-w" "1" "-v" "x"))))
    (test-equal #t (args-ref r 'verbose))
    (test-equal #t (args-ref r 'color)))            ; default
  (let ((r (parse '("-w" "1" "x"))))
    (test-equal #f (args-ref r 'verbose)))          ; absent flag -> #f
  ;; --no-<flag> negation
  (let ((r (parse '("-w" "1" "--no-color" "x"))))
    (test-equal #f (args-ref r 'color))))

(test-group "long-options"
  (let ((r (parse '("--width" "42" "x")))) (test-equal 42 (args-ref r 'width)))
  (let ((r (parse '("--width=42" "x"))))   (test-equal 42 (args-ref r 'width))))

(test-group "short-options"
  (let ((r (parse '("-w" "7" "x"))))   (test-equal 7 (args-ref r 'width)))
  (let ((r (parse '("-w=7" "x"))))     (test-equal 7 (args-ref r 'width))))

(test-group "clustering"
  ;; -vw 5 : v is a flag, w (last) consumes the next token
  (let ((r (parse '("-vw" "5" "x"))))
    (test-equal #t (args-ref r 'verbose))
    (test-equal 5 (args-ref r 'width))))

(test-group "repeatable"
  (let ((r (parse '("-w" "1" "--tag" "a" "--tag" "b" "x"))))
    (test-equal '("a" "b") (args-ref r 'tags)))
  ;; unseen repeatable -> '()
  (let ((r (parse '("-w" "1" "x"))))
    (test-equal '() (args-ref r 'tags))))

(test-group "types"
  (let ((r (parse '("-w" "1" "--mode" "slow" "--ratio" "1.5"
                    "--name" "hello" "--nums" "1,2,3" "x"))))
    (test-equal 'slow (args-ref r 'mode))
    (test-equal 1.5 (args-ref r 'ratio))
    (test-equal 'hello (args-ref r 'name))
    (test-equal '(1 2 3) (args-ref r 'nums))))

(test-group "defaults"
  (let ((r (parse '("-w" "1" "x"))))
    (test-equal 85 (args-ref r 'quality))
    (test-equal 'fast (args-ref r 'mode))))

(test-group "terminator"
  ;; -- stops option parsing; -5.txt becomes a positional
  (let ((r (parse '("-w" "1" "--" "-5.txt"))))
    (test-equal "-5.txt" (args-ref r 'input)))
  ;; leading-digit tokens are positionals without needing --
  (let ((r (parse '("-w" "1" "-9"))))
    (test-equal "-9" (args-ref r 'input))))

(test-group "rest-collection"
  ;; parser with no positional specs collects everything into rest
  (let* ((p (make-arg-parser
              'program "cat"
              'options (list (flag 'number 'short #\n))))
         (r (parse-args p '("-n" "a" "b" "c") 'on-error 'raise)))
    (test-equal #t (args-ref r 'number))
    (test-equal '("a" "b" "c") (args-rest r))))

(test-group "variadic-positional"
  (let* ((p (make-arg-parser
              'positionals (list (pos 'first 'type arg:string 'required #t)
                                 (pos 'others 'type arg:string 'repeat #t))))
         (r (parse-args p '("a" "b" "c") 'on-error 'raise)))
    (test-equal "a" (args-ref r 'first))
    (test-equal '("b" "c") (args-ref r 'others))
    (test-equal '() (args-rest r))))

(test-group "data-form-equivalence"
  (let* ((p (make-arg-parser
              'program "tool"
              'options (list (opt 'width 'short #\w 'type arg:integer 'required #t)
                             (flag 'verbose 'short #\v))
              'positionals (list (pos 'input 'type arg:string 'required #t))))
         (r (parse-args p '("-vw" "3" "f") 'on-error 'raise)))
    (test-equal 3 (args-ref r 'width))
    (test-equal #t (args-ref r 'verbose))
    (test-equal "f" (args-ref r 'input))))

(test-group "args->alist"
  (let ((al (args->alist (parse '("-w" "1" "x")))))
    (test-assert (pair? (assq 'width al)))
    (test-equal 1 (cdr (assq 'width al)))))

(test-group "errors"
  (test-error (parse '("x")))                       ; missing required option --width
  (test-error (parse '("-w" "1")))                  ; missing required positional input
  (test-error (parse '("-w" "notnum" "x")))         ; bad integer
  (test-error (parse '("-w")))                      ; option needs a value
  (test-error (parse '("--bogus" "-w" "1" "x")))    ; unknown long option
  (test-error (parse '("-z" "-w" "1" "x")))         ; unknown short option
  (test-error (parse '("-w" "1" "--mode" "weird" "x"))) ; one-of out of range
  (test-error (parse '("-w" "1" "--color=yes" "x"))); flag takes no value
  (test-error (parse '("-w" "1" "a" "b" "c"))))     ; too many positionals

(test-group "help-rendering"
  (define h (format-help (make-cli)))
  (test-assert (string? h))
  (test-assert (has-substring? h "Usage: tool"))
  (test-assert (has-substring? h "--width"))
  (test-assert (has-substring? h "(required)"))
  (test-assert (has-substring? h "default: 85"))
  (test-assert (has-substring? h "--help")))

(test-end "args")

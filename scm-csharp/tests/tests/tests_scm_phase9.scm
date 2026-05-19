(import (scheme base)
        (scheme write)
        (scm fs)
        (scm fs-find)
        (scm text)
        (scm system)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "scm-phase9")

(test-group "shell-quote"
  (test-equal "'plain'" (shell-quote "plain"))
  ;; embedded single quote: 'it'\''s fine'
  (test-equal "'it'\\''s fine'" (shell-quote "it's fine"))
  (test-equal "''" (shell-quote "")))

(test-group "run / run? / sh / sh-lines"
  (test-equal 0 (run "true"))
  (test-equal #t (run? "true"))
  (test-equal #f (run? "false"))
  (test-equal "hello\n" (sh "echo" "hello"))
  (test-equal '("a" "b" "c") (sh-lines "printf" "a\nb\nc\n")))

(test-group "cd round trip"
  (let ((orig (current-directory)))
    (cd "/tmp")
    (test-equal "/tmp" (current-directory))
    (cd orig)
    (test-equal orig (current-directory))))

(test-group "env-list"
  (let ((e (env-list)))
    (test-equal #t (list? e))
    (test-equal #t (> (length e) 0))
    ;; PATH is virtually always set on Unix and on Windows
    (test-equal #t (and (or (assoc "PATH" e)
                            (assoc "Path" e)
                            (assoc "HOME" e))
                        #t))))

(test-group "getopt"
  (let ((r (getopt '("-v" "--name" "foo" "x" "y")
                   '(("verbose" #\v #f)
                     ("name" #\n #t "anon")))))
    (test-equal #t (cdr (assoc "verbose" (car r))))
    (test-equal "foo" (cdr (assoc "name" (car r))))
    (test-equal '("x" "y") (cdr r)))
  ;; default value for absent option
  (let ((r (getopt '() '(("name" #\n #t "anon")))))
    (test-equal "anon" (cdr (assoc "name" (car r)))))
  ;; short option with attached value: -nFoo
  (let ((r (getopt '("-nFoo") '(("name" #\n #t)))))
    (test-equal "Foo" (cdr (assoc "name" (car r)))))
  ;; -- terminator
  (let ((r (getopt '("-v" "--" "-not-an-option")
                   '(("verbose" #\v #f)))))
    (test-equal '("-not-an-option") (cdr r))))

(test-group "awk"
  (test-equal '("b" "e")
              (awk (lambda (fs n l) (list-ref fs 1))
                   '("a b c" "d e f")))
  ;; explicit delimiter
  (test-equal '("3")
              (awk (lambda (fs n l) (list-ref fs 2))
                   '("a:b:3")
                   '(delimiter . ":")))
  ;; filter pattern
  (test-equal '("two")
              (awk (lambda (fs n l) (list-ref fs 0))
                   '("one" "two" "three")
                   `(filter . ,(lambda (fs n l) (= n 2))))))

(test-group "tree"
  (let ((td (mktempdir)))
    (touch (string-append td "/a"))
    (let ((t (tree td)))
      (test-equal #t (string? t))
      (test-equal #t (> (string-length t) 0)))
    (rm td 'recursive)))

(test-end "scm-phase9")

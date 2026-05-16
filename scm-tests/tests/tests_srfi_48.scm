(import (scheme base)
        (scheme write)
        (scm test)
        (srfi 48))

(test-runner-factory scm-test-runner)

(test-begin "srfi-48")

;; Basic string return (no dest)
(test-group "basic-no-dest"
  (test-equal "hello" (format "~a" "hello"))
  (test-equal "42" (format "~a" 42))
  (test-equal "" (format ""))
  (test-equal "no directives" (format "no directives")))

;; Explicit #f dest
(test-group "basic-with-false"
  (test-equal "hello" (format #f "~a" "hello"))
  (test-equal "42" (format #f "~d" 42)))

;; ~a display
(test-group "display"
  (test-equal "hello" (format "~a" "hello"))
  (test-equal "42" (format "~a" 42))
  (test-equal "(1 2 3)" (format "~a" '(1 2 3))))

;; ~s write
(test-group "write"
  (test-equal "\"hello\"" (format "~s" "hello"))
  (test-equal "42" (format "~s" 42))
  (test-equal "(1 2 3)" (format "~s" '(1 2 3))))

;; ~w write-shared
(test-group "write-shared"
  (test-equal "42" (format "~w" 42))
  (test-equal "(1 2 3)" (format "~w" '(1 2 3)))
  (test-equal "\"hello\"" (format "~w" "hello")))

;; ~d decimal
(test-group "decimal"
  (test-equal "42" (format "~d" 42))
  (test-equal "-7" (format "~d" -7))
  (test-equal "0" (format "~d" 0))
  (test-equal "999999999999999999999" (format "~d" 999999999999999999999))
  (test-equal "-999999999999999999999" (format "~d" -999999999999999999999)))

;; ~x hexadecimal
(test-group "hex"
  (test-equal "ff" (format "~x" 255))
  (test-equal "0" (format "~x" 0))
  (test-equal "10" (format "~x" 16))
  (test-equal "-ff" (format "~x" -255)))

;; ~o octal
(test-group "octal"
  (test-equal "10" (format "~o" 8))
  (test-equal "377" (format "~o" 255))
  (test-equal "-10" (format "~o" -8)))

;; ~b binary
(test-group "binary"
  (test-equal "1010" (format "~b" 10))
  (test-equal "0" (format "~b" 0))
  (test-equal "11111111" (format "~b" 255))
  (test-equal "-101" (format "~b" -5)))

;; ~c character
(test-group "char"
  (test-equal "A" (format "~c" #\A))
  (test-equal " " (format "~c" #\space)))

;; ~f fixed-point float
(test-group "float"
  (test-equal "3.141590" (format "~f" 3.14159))
  (test-equal "3.14" (format "~,2f" 3.14159))
  (test-equal "4" (format "~,0f" 3.7))
  (test-equal "42.0" (format "~,1f" 42))
  (test-equal "   32.00" (format "~8,2f" 32))
  (test-equal "32.00   " (format "~-8,2f" 32)))

;; ~y pretty-print
(test-group "pretty-print"
  (test-equal "42" (format "~y" 42))
  (test-equal "(1 2 3)" (format "~y" '(1 2 3)))
  (test-equal "\"hello\"" (format "~y" "hello")))

;; ~? and ~k recursive format
(test-group "recursive"
  (test-equal "1 and 2" (format "~?" "~a and ~a" '(1 2)))
  (test-equal "prefix 1 2" (format "~a ~?" "prefix" "~d ~d" '(1 2)))
  (test-equal "~" (format "~?" "~~" '()))
  ;; ~k is alias for ~?
  (test-equal "1 and 2" (format "~k" "~a and ~a" '(1 2)))
  (test-equal "prefix 1 2" (format "~a ~k" "prefix" "~d ~d" '(1 2))))

;; ~% newline
(test-group "newline"
  (test-equal "\n" (format "~%"))
  (test-equal "a\nb" (format "a~%b")))

;; ~n newline alias
(test-group "newline-alias"
  (test-equal "\n" (format "~n"))
  (test-equal "a\nb" (format "a~nb")))

;; ~& freshline
(test-group "freshline"
  (test-equal "\n" (format "~&"))
  (test-equal "\n" (format "~%~&"))
  (test-equal "\n\n" (format "~%~%"))
  (test-equal "hello\n" (format "hello~&"))
  (test-equal "hello\n" (format "hello~%~&")))

;; ~t tab
(test-group "tab"
  (test-equal "\t" (format "~t"))
  (test-equal "a\tb" (format "a~tb")))

;; ~_ space
(test-group "space"
  (test-equal " " (format "~_"))
  (test-equal "a b" (format "a~_b")))

;; ~~ tilde
(test-group "tilde"
  (test-equal "~" (format "~~"))
  (test-equal "~hi~" (format "~~~a~~" "hi")))

;; ~h help
(test-group "help"
  (test-assert (string? (format "~h")))
  (test-assert (> (string-length (format "~h")) 0)))

;; Width and alignment
(test-group "width"
  (test-equal "   42" (format "~5d" 42))
  (test-equal "42   " (format "~-5d" 42))
  (test-equal "  ff" (format "~4x" 255))
  (test-equal "1010    " (format "~-8b" 10))
  (test-equal "        hi" (format "~10a" "hi"))
  (test-equal "hi        " (format "~-10a" "hi")))

;; Mixed directives
(test-group "mixed"
  (test-equal "1 + 2 = 3" (format "~a + ~a = ~d" 1 2 3))
  (test-equal "char Z, int 42, hex 2a"
    (format "char ~c, int ~d, hex ~x" #\Z 42 42))
  (test-equal "10 in hex is a, in octal is 12, in binary is 1010"
    (format "~d in hex is ~x, in octal is ~o, in binary is ~b" 10 10 10 10)))

;; Port output
(test-group "port-output"
  (let ((p (open-output-string)))
    (format p "hello ~a" "world")
    (test-equal "hello world" (get-output-string p))))

(test-end "srfi-48")

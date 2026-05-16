(import (scheme base)
        (scm test)
        (scm io))

(test-runner-factory scm-test-runner)

(test-begin "srfi-28")

;; Verify (srfi 28) library loads
(test-group "srfi28-library"
  (import (rename (srfi 28) (format srfi28-format)))
  (test-equal "42" (srfi28-format "~a" 42))
  (test-equal "hello world" (srfi28-format "~a ~a" "hello" "world"))
  (test-equal "\"hello\"" (srfi28-format "~s" "hello"))
  (test-equal "no directives" (srfi28-format "no directives"))
  (test-equal "" (srfi28-format "")))

;; Literal tilde
(test-group "tilde"
  (test-equal "~" (format #f "~~"))
  (test-equal "~hi~" (format #f "~~~a~~" "hi")))

;; Newline directives
(test-group "newline"
  (test-equal "\n" (format #f "~%"))
  (test-equal "\n" (format #f "~n"))
  (test-equal "a\nb" (format #f "a~%b")))

;; Decimal integer ~d
(test-group "decimal"
  (test-equal "42" (format #f "~d" 42))
  (test-equal "-7" (format #f "~d" -7))
  (test-equal "0" (format #f "~d" 0)))

;; Hexadecimal ~x
(test-group "hex"
  (test-equal "ff" (format #f "~x" 255))
  (test-equal "0" (format #f "~x" 0))
  (test-equal "10" (format #f "~x" 16))
  (test-equal "-ff" (format #f "~x" -255)))

;; Octal ~o
(test-group "octal"
  (test-equal "10" (format #f "~o" 8))
  (test-equal "377" (format #f "~o" 255))
  (test-equal "-10" (format #f "~o" -8)))

;; Binary ~b
(test-group "binary"
  (test-equal "1010" (format #f "~b" 10))
  (test-equal "0" (format #f "~b" 0))
  (test-equal "11111111" (format #f "~b" 255))
  (test-equal "-101" (format #f "~b" -5)))

;; Character ~c
(test-group "char"
  (test-equal "A" (format #f "~c" #\A))
  (test-equal " " (format #f "~c" #\space)))

;; Float ~f
(test-group "float"
  (test-equal "3.141590" (format #f "~f" 3.14159))
  (test-equal "3.14" (format #f "~,2f" 3.14159))
  (test-equal "4" (format #f "~,0f" 3.7))
  (test-equal "42.0" (format #f "~,1f" 42)))

;; Width and alignment
(test-group "width"
  (test-equal "   42" (format #f "~5d" 42))
  (test-equal "42   " (format #f "~-5d" 42))
  (test-equal "  ff" (format #f "~4x" 255))
  (test-equal "1010    " (format #f "~-8b" 10))
  (test-equal "        hi" (format #f "~10a" "hi"))
  (test-equal "hi        " (format #f "~-10a" "hi"))
  (test-equal "      3.14" (format #f "~10,2f" 3.14))
  (test-equal "3.14      " (format #f "~-10,2f" 3.14)))

;; Recursive format ~?
(test-group "recursive"
  (test-equal "1 and 2" (format #f "~?" "~a and ~a" '(1 2)))
  (test-equal "prefix 1 2" (format #f "~a ~?" "prefix" "~d ~d" '(1 2)))
  (test-equal "~" (format #f "~?" "~~" '())))

;; Mixed directives
(test-group "mixed"
  (test-equal "1 + 2 = 3" (format #f "~a + ~a = ~d" 1 2 3))
  (test-equal "char Z, int 42, hex 2a" (format #f "char ~c, int ~d, hex ~x" #\Z 42 42))
  (test-equal "10 in hex is a, in octal is 12, in binary is 1010"
    (format #f "~d in hex is ~x, in octal is ~o, in binary is ~b" 10 10 10 10)))

(test-end "srfi-28")

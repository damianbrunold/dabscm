(import (scheme base)
        (scm test)
        (srfi 26))

(test-runner-factory scm-test-runner)

(test-begin "srfi-26")

;; Basic cut with single slot
(test-equal 8 ((cut + <> 5) 3))
(test-equal 15 ((cut + <> 5) 10))

;; cut with multiple slots
(test-equal '(1 2 3) ((cut list <> <> <>) 1 2 3))

;; cut with fixed arguments
(test-equal "hello, world!" ((cut string-append "hello" <> "!") ", world"))

;; cut with rest slot <...>
(test-equal '(1 2 3 4) ((cut list 1 <...>) 2 3 4))

;; cute: non-slot args evaluated once
(test-equal 1 (let ((count 0))
  (define add-n (cute + <> (begin (set! count (+ count 1)) count)))
  (add-n 10)
  (add-n 20)
  count))

;; cute with multiple invocations
(test-equal 10 ((cute * 2 <>) 5))
(test-equal 14 ((cute * 2 <>) 7))

(test-end "srfi-26")

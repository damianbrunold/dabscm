(import (scheme base)
        (scm fs)
        (scm fs-find)
        (scm test)
        (srfi 1)
        (srfi 132))

(test-runner-factory scm-test-runner)

(test-begin "scm-fs-find")

(define base (mktempdir '(prefix . "find-test")))
(make-directory (string-append base "/sub"))
(touch (string-append base "/a.txt"))
(touch (string-append base "/b.log"))
(touch (string-append base "/sub/c.txt"))
(touch (string-append base "/sub/d.log"))

(define (basenames paths)
  (list-sort string<? (map base-name paths)))

(test-group "find name pattern"
  (test-equal '("a.txt" "c.txt")
              (basenames (find base '(name . "*.txt")))))

(test-group "find type=file"
  (test-equal '("a.txt" "b.log" "c.txt" "d.log")
              (basenames (find base '(type . file)))))

(test-group "find maxdepth"
  (test-equal '("a.txt" "b.log")
              (basenames (find base '(maxdepth . 1) '(type . file)))))

(test-group "find with predicate"
  ;; All files exist, so the predicate must accept everything.
  (test-equal 4
              (length (find base
                            '(type . file)
                            `(predicate . ,(lambda (p) (file-exists? p)))))))

(test-group "find with action"
  (let ((collected '()))
    (find base
          '(type . file)
          `(action . ,(lambda (p) (set! collected (cons (base-name p) collected)))))
    (test-equal '("a.txt" "b.log" "c.txt" "d.log")
                (list-sort string<? collected))))

(test-group "du"
  ;; All files are empty, so du returns 0.
  (test-equal 0 (du base)))

(test-group "xargs"
  (test-equal '(1 2 3) (xargs (lambda (x) x) '(1 2 3)))
  (test-equal '(2 2 1) (xargs (lambda (b) (length b))
                              '(a b c d e)
                              '(batch-size . 2))))

(rm base 'recursive)

(test-end "scm-fs-find")

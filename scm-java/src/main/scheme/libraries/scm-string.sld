(define-library (scm string)
  (import (scm core) (scheme base))
  (export string-matches
          string-replace-all
          string-split
          string-split-vector
          symbol-starts-with?
          string-split-char
          string-split-lines
          string-contains-from)
  (begin
    (define string-matches (%primitive "string-matches"))
    (define string-replace-all (%primitive "string-replace-all"))
    (define string-split (%primitive "string-split"))
    (define string-split-vector (%primitive "string-split-vector"))
    (define symbol-starts-with? (%primitive "symbol-starts-with?"))

    (define (string-split-char s ch)
      "Syntax: (string-split-char s ch)
Library: (scm string)
Description: Splits string s into a list of substrings on every occurrence of
  character ch. Adjacent delimiters produce empty strings; the result always
  has at least one element.
Example:
  (string-split-char \"a,b,,c\" #\\,) => (\"a\" \"b\" \"\" \"c\")
  (string-split-char \"\" #\\,) => (\"\")"
      (let* ((n (string-length s)))
        (let loop ((i 0) (start 0) (acc '()))
          (cond
            ((= i n)
             (reverse (cons (substring s start n) acc)))
            ((char=? (string-ref s i) ch)
             (loop (+ i 1) (+ i 1)
                   (cons (substring s start i) acc)))
            (else (loop (+ i 1) start acc))))))

    (define (string-split-lines s)
      "Syntax: (string-split-lines s)
Library: (scm string)
Description: Splits string s into lines on newline (LF), dropping a trailing
  carriage return (CR) on each line. Empty lines are preserved.
Example:
  (string-split-lines \"a\\nb\\n\") => (\"a\" \"b\" \"\")
  (string-split-lines \"a\\r\\nb\") => (\"a\" \"b\")"
      (let* ((n (string-length s)))
        (let loop ((i 0) (start 0) (acc '()))
          (cond
            ((= i n)
             (reverse (cons (substring s start n) acc)))
            ((char=? (string-ref s i) #\newline)
             (let ((end (if (and (> i start)
                                 (char=? (string-ref s (- i 1)) #\return))
                            (- i 1)
                            i)))
               (loop (+ i 1) (+ i 1)
                     (cons (substring s start end) acc))))
            (else (loop (+ i 1) start acc))))))

    (define (string-contains-from haystack needle start)
      "Syntax: (string-contains-from haystack needle start)
Library: (scm string)
Description: Returns the index in haystack at or after start where needle
  first occurs, or #f if it does not. Allocation-free char-by-char scan;
  suitable for parsers operating on large strings.
Example:
  (string-contains-from \"hello world\" \"world\" 0) => 6
  (string-contains-from \"abcabc\" \"bc\" 2) => 4
  (string-contains-from \"abc\" \"xyz\" 0) => #f"
      (let* ((hn (string-length haystack))
             (nn (string-length needle))
             (limit (- hn nn)))
        (cond
          ((= nn 0) start)
          ((< limit 0) #f)
          (else
           (let ((n0 (string-ref needle 0)))
             (let outer ((i start))
               (cond
                 ((> i limit) #f)
                 ((not (char=? (string-ref haystack i) n0))
                  (outer (+ i 1)))
                 (else
                  (let inner ((j 1))
                    (cond
                      ((= j nn) i)
                      ((char=? (string-ref haystack (+ i j))
                               (string-ref needle j))
                       (inner (+ j 1)))
                      (else (outer (+ i 1))))))))))))))
)

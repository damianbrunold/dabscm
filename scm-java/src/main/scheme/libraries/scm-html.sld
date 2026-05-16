(define-library (scm html)
  (import (scm core) (scheme base))
  (export html-escape
          html-attr-escape
          strip-html-tags)
  (begin

    (define (html-escape s)
      "Syntax: (html-escape s)
Library: (scm html)
Description: Escapes the five HTML metacharacters (&, <, >, \", ') in s so
  the result is safe to splice into HTML text content or attribute values
  (quoted with either single or double quotes).
Example:
  (html-escape \"a < b & c\") => \"a &lt; b &amp; c\"
  (html-escape \"O'Brien\") => \"O&#39;Brien\""
      (let* ((n (string-length s))
             (out (open-output-string)))
        (let loop ((i 0))
          (cond
            ((= i n) (get-output-string out))
            (else
             (let ((c (string-ref s i)))
               (cond ((char=? c #\<) (write-string "&lt;"   out))
                     ((char=? c #\>) (write-string "&gt;"   out))
                     ((char=? c #\&) (write-string "&amp;"  out))
                     ((char=? c #\") (write-string "&quot;" out))
                     ((char=? c #\') (write-string "&#39;"  out))
                     (else           (write-char c out))))
             (loop (+ i 1)))))))

    ;; Alias for clarity at call sites that escape attribute values.
    ;; The escape rules are identical because html-escape escapes both
    ;; quote characters.
    (define html-attr-escape html-escape)

    (define (strip-html-tags s)
      "Syntax: (strip-html-tags s)
Library: (scm html)
Description: Removes anything that looks like an HTML tag (text from < to >)
  and collapses runs of whitespace into single spaces. Intended for plain-text
  contexts like tooltip values where you want a readable string. Does NOT
  decode HTML entities — call html-escape afterwards if you re-emit into HTML.
Example:
  (strip-html-tags \"<p>hello   <b>world</b></p>\") => \"hello world\"
  (strip-html-tags \"plain\") => \"plain\""
      (let* ((n   (string-length s))
             (out (open-output-string)))
        (let loop ((i 0) (in-tag? #f) (in-ws? #f) (any-out? #f))
          (cond
            ((= i n) (get-output-string out))
            (else
             (let ((c (string-ref s i)))
               (cond
                 (in-tag?
                  (cond
                    ((char=? c #\>) (loop (+ i 1) #f in-ws? any-out?))
                    (else           (loop (+ i 1) #t in-ws? any-out?))))
                 ((char=? c #\<)
                  (loop (+ i 1) #t in-ws? any-out?))
                 ((or (char=? c #\space) (char=? c #\tab)
                      (char=? c #\newline) (char=? c #\return))
                  (cond
                    ((not any-out?) (loop (+ i 1) #f #f #f))
                    (in-ws?         (loop (+ i 1) #f #t any-out?))
                    (else (write-char #\space out)
                          (loop (+ i 1) #f #t any-out?))))
                 (else
                  (write-char c out)
                  (loop (+ i 1) #f #f #t)))))))))
))

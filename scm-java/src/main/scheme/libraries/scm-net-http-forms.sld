(define-library (scm net http forms)
  (import (scm core) (scheme base) (scm uri) (scm string))
  (export parse-www-form
          form-ref
          form-refs-by-prefix)
  (begin

    (define (parse-www-form body)
      "Syntax: (parse-www-form body)
Library: (scm net http forms)
Description: Parses an application/x-www-form-urlencoded body or query
  string into an alist of decoded (key . value) string pairs. Empty body
  or #f → '(). Keys with no '=' map to empty-string values.
Example:
  (parse-www-form \"name=Ada&age=37\") => ((\"name\" . \"Ada\") (\"age\" . \"37\"))
  (parse-www-form \"\") => ()"
      (cond
        ((or (not body) (string=? body "")) '())
        (else
         (map (lambda (pair)
                (let ((parts (string-split-char pair #\=)))
                  (cond
                    ((null? (cdr parts))
                     (cons (percent-decode (car parts)) ""))
                    (else
                     ;; Re-join any extra '=' into the value, so values that
                     ;; happen to contain unencoded '=' don't get truncated.
                     (let* ((k (percent-decode (car parts)))
                            (v-raw (let join ((xs (cdr parts)) (acc ""))
                                     (cond
                                       ((null? xs) acc)
                                       ((string=? acc "")
                                        (join (cdr xs) (car xs)))
                                       (else
                                        (join (cdr xs)
                                              (string-append acc "=" (car xs))))))))
                       (cons k (percent-decode v-raw)))))))
              (string-split-char body #\&)))))

    (define (form-ref form key . default)
      "Syntax: (form-ref form key [default])
Library: (scm net http forms)
Description: Returns the value of key in form (an alist from parse-www-form),
  or default if missing, or #f if no default is supplied.
Example:
  (form-ref '((\"a\" . \"1\")) \"a\") => \"1\"
  (form-ref '() \"a\" \"-\") => \"-\""
      (let ((p (assoc key form)))
        (cond (p (cdr p))
              ((pair? default) (car default))
              (else #f))))

    (define (form-refs-by-prefix form prefix)
      "Syntax: (form-refs-by-prefix form prefix)
Library: (scm net http forms)
Description: Returns all (key . value) pairs from form whose key starts with
  prefix. Order is preserved.
Example:
  (form-refs-by-prefix '((\"opt-a\" . \"1\") (\"name\" . \"x\") (\"opt-b\" . \"2\")) \"opt-\")
  => ((\"opt-a\" . \"1\") (\"opt-b\" . \"2\"))"
      (let ((plen (string-length prefix)))
        (let loop ((ps form) (acc '()))
          (cond
            ((null? ps) (reverse acc))
            (else
             (let* ((p (car ps))
                    (k (car p)))
               (cond
                 ((and (>= (string-length k) plen)
                       (string=? (substring k 0 plen) prefix))
                  (loop (cdr ps) (cons p acc)))
                 (else (loop (cdr ps) acc)))))))))
))

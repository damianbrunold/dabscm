---
title: (scm templating) and (scm uri): templates and URLs
part: libraries
order: 1006
libraries: (scm templating) (scm uri)
summary: {{placeholders}} with dotted paths, loops and conditions, includes and template files, an engine for a directory of templates; percent-encoding for URLs; an e-mail and a report.
---
# (scm templating) and (scm uri): templates and URLs

`(scm templating)` fills text templates from data; `(scm uri)` encodes
values for URLs.

```scheme
(import (scheme base) (scheme file) (scheme write) (scm templating) (scm uri) (scm fs))
```

## Placeholders

`{{name}}` is replaced by the value of `name` in the context, an alist. Keys
can be symbols or strings, and dots walk into nested data:

```scheme
(template-render "Hello {{name}}!" '((name . "Ada")))           ;; => "Hello Ada!"
(template-render "{{user.name}} from {{user.city}}"
                 '((user . ((name . "Ada") (city . "London")))))  ;; => "Ada from London"
(template-render "first: {{items.0}}" '((items . #("pen" "ink")))) ;; => "first: pen"
(template-render "[{{missing}}]" '())                           ;; => "[]"
(template-render "{{n}} items, paid: {{paid}}" '((n . 3) (paid . #t)))
;; => "3 items, paid: true"
```

A missing value renders as nothing. Numbers, booleans and symbols are
converted; other values (lists, vectors) render as nothing too, so pass
them to loops instead.

`template-context` builds a context from alternating keys and values:

```scheme
(template-context 'name "Ada" 'year 1843)                      ;; => ((name . "Ada") (year . 1843))
```

## Loops and conditions

```scheme
(define invoice
  "Invoice {{number}}
{% for item in items %}- {{item.name}}: {{item.price}}
{% endfor %}{% if discount %}Discount: {{discount}}
{% else %}No discount
{% endif %}")

(template-render invoice
                 '((number . "R-17")
                   (items . (((name . "Book") (price . "24.00"))
                             ((name . "Pen") (price . "3.50"))))
                   (discount . #f)))
;; => "Invoice R-17\n- Book: 24.00\n- Pen: 3.50\nNo discount\n"
```

`{% for x in path %}` loops over a list or vector; `{% if path %}` tests a
value, which is false when missing, `#f`, empty or `""`.

## Templates in files

`template-render-file` reads the template from a file, and `{% include
"file" %}` pulls in another template relative to it. For a directory of
templates, `make-template-engine` gives a reusable renderer:

```scheme
(define dir (mktempdir '(prefix . "tmpl")))
(call-with-output-file (join-path dir "header.txt")
  (lambda (out) (display "== {{title}} ==\n" out)))
(call-with-output-file (join-path dir "page.txt")
  (lambda (out) (display "{% include \"header.txt\" %}{{body}}\n" out)))

(template-render-file (join-path dir "page.txt") '((title . "News") (body . "All quiet.")))
;; => "== News ==\nAll quiet.\n"

(define engine (make-template-engine dir))
(template-engine-render engine "page.txt" '((title . "Weather") (body . "Sunny.")))
;; => "== Weather ==\nSunny.\n"

(rm dir 'recursive)
```

## Escaping

Templates insert values as they are. For HTML pages, escape the values
first (see `(scm html)`), or build the page with `(scm html builder)`,
which escapes automatically. Otherwise a value like `<script>` ends up in
the page as code.

## URLs: percent-encoding

```scheme
(percent-encode "Zürich & Bern")           ;; => "Z%C3%BCrich%20%26%20Bern"
(percent-decode "Z%C3%BCrich%20%26%20Bern") ;; => "Zürich & Bern"
(percent-encode "a-b_c.d~e")               ;; => "a-b_c.d~e"

(define (query-string params)
  (let loop ((ps params) (acc ""))
    (if (null? ps)
        acc
        (loop (cdr ps)
              (string-append acc (if (string=? acc "") "?" "&")
                             (percent-encode (car (car ps))) "="
                             (percent-encode (cdr (car ps))))))))

(query-string '(("q" . "scheme tutorials") ("lang" . "de/fr")))
;; => "?q=scheme%20tutorials&lang=de%2Ffr"
```

Letters, digits and `- _ . ~` stay as they are; everything else, including
non-ASCII text (as UTF-8), becomes `%XX`.

## Where next

- `(scm html builder)` for HTML, `(scm net http client)` for requests.
- Reference: `(scm templating)`, `(scm uri)`.

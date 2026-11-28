---
title: (scm toml): configuration files
part: libraries
order: 1017
libraries: (scm toml)
summary: TOML values in Scheme, nested and dotted tables, arrays of tables, dates, defaults and validation for configuration, writing TOML, a settings loader with layered files.
---
# (scm toml): configuration files

TOML is made for configuration: readable, with comments, typed values and
sections. `(scm toml)` reads it into the same shapes as
[`(scm json simple)`](scm-json.md): tables become alists with string keys,
arrays vectors.

```scheme
(import (scheme base) (scheme cxr) (scheme write) (srfi 1) (scm toml))
```

## Reading

```scheme
(define config (toml-parse "
# the shop's settings
name = \"Teashop\"
version = 3
ratio = 0.25
debug = false
\"display name\" = 'Tea & Co'

[server]
host = \"0.0.0.0\"
port = 8080

[server.tls]
cert = \"/etc/shop/cert.pem\"

[[product]]
sku = \"T-1\"
price = 4.5
tags = [\"green\", \"loose\"]

[[product]]
sku = \"C-2\"
price = 12
"))

(toml-ref config "name")                    ;; => "Teashop"
(toml-ref config "debug")                   ;; => #f
(toml-ref config "display name")            ;; => "Tea & Co"
(toml-ref (toml-ref config "server") "port") ;; => 8080
(toml-ref (toml-ref (toml-ref config "server") "tls") "cert") ;; => "/etc/shop/cert.pem"
```

| TOML | Scheme |
|---|---|
| table `[server]` or `{ x = 1 }` | alist `(("x" . 1))` |
| array `[1, 2]` | vector `#(1 2)` |
| array of tables `[[product]]` | vector of alists |
| string (basic `"..."`, literal `'...'`, multi-line `"""..."""`) | string |
| integer / float | exact integer / inexact real |
| boolean | `#t` / `#f` |
| date, time, date-time | a `toml-datetime` record |

`[server.tls]` nests a table inside `server`. Arrays of tables are lists of
records, the natural place for repeated entries:

```scheme
(define products (vector->list (toml-ref config "product")))
(map (lambda (p) (toml-ref p "sku")) products) ;; => ("T-1" "C-2")
(map (lambda (p) (toml-ref p "tags" #())) products) ;; => (#("green" "loose") #())
(fold + 0 (map (lambda (p) (toml-ref p "price")) products)) ;; => 16.5
```

## Paths and defaults

A helper for dotted paths keeps configuration code short. Every setting
gets a default, so a minimal file works:

```scheme
(define (setting cfg path default)
  (let loop ((v cfg) (keys path))
    (cond ((null? keys) v)
          ((and (list? v) (assoc (car keys) v)) => (lambda (e) (loop (cdr e) (cdr keys))))
          (else default))))

(setting config '("server" "port") 80)      ;; => 8080
(setting config '("server" "workers") 4)    ;; => 4
(setting config '("db" "url") "sqlite:shop.db") ;; => "sqlite:shop.db"
```

## Validation

Configuration errors should be reported at startup, with the key, not as a
strange failure later. A small checker over a list of rules:

```scheme
(define rules
  `((("server" "port") ,(lambda (v) (and (exact-integer? v) (< 0 v 65536))) "a port number")
    (("server" "host") ,string? "a host name")
    (("name") ,string? "a string")))

(define (config-errors cfg)
  (filter-map (lambda (rule)
                (let ((v (setting cfg (car rule) #f)))
                  (and (not ((cadr rule) v))
                       (string-append (apply string-append
                                             (cdr (append-map (lambda (k) (list "." k)) (car rule))))
                                      " must be " (caddr rule)))))
              rules))

(config-errors config)                      ;; => ()
(config-errors (toml-parse "name = 1\n[server]\nport = 70000"))
;; => ("server.port must be a port number" "server.host must be a host name" "name must be a string")
```

## Errors in the file

Syntax errors and duplicate keys raise an error:

```scheme
(define (try text) (guard (e ((error-object? e) 'invalid)) (toml-parse text) 'ok))
(try "a = 1")                               ;; => ok
(try "a = ")                                ;; => invalid
(try "a = 1\na = 2")                        ;; => invalid
```

## Dates and times

TOML dates are values of their own. They come back as `toml-datetime`
records holding their kind and their text, so they never pass for strings:

```scheme
(define release (toml-parse "day = 2025-11-27\nat = 2025-11-27T10:30:00Z\nalarm = 07:15:00"))
(define day (toml-ref release "day"))
(toml-datetime? day)                        ;; => #t
(toml-datetime-kind day)                    ;; => local-date
(toml-datetime-text day)                    ;; => "2025-11-27"
(toml-datetime-kind (toml-ref release "at")) ;; => offset-date-time
(toml-datetime-kind (toml-ref release "alarm")) ;; => local-time
```

The text is ISO 8601, so `parse-iso8601` from
[`(scm datetime)`](scm-datetime.md) turns an offset date-time into epoch
seconds.

## Writing

`toml->string` writes scalar values first, then tables as sections and
vectors of alists as arrays of tables:

```scheme
(display (toml->string
          `(("title" . "Release notes")
            ("draft" . #f)
            ("authors" . #("ada" "alan"))
            ("build" ("target" . "x86_64") ("jobs" . 8))
            ("change" . #((("kind" . "fix") ("text" . "Markdown lists"))
                          (("kind" . "new") ("text" . "Tutorials")))))))
;; prints: title = "Release notes"
;; prints: draft = false
;; prints: authors = ["ada", "alan"]
;; prints: 
;; prints: [build]
;; prints: target = "x86_64"
;; prints: jobs = 8
;; prints: 
;; prints: [[change]]
;; prints: kind = "fix"
;; prints: text = "Markdown lists"
;; prints: 
;; prints: [[change]]
;; prints: kind = "new"
;; prints: text = "Tutorials"
```

Comments are not kept: a program that rewrites a hand-edited file loses
them. Write generated settings to their own file instead.

## Example: layered settings

Built-in defaults, then a system file, then a user file: each layer
overrides single keys of the one before:

```scheme
(define (merge base over)
  (if (and (list? base) (list? over))
      (append (map (lambda (b)
                     (let ((o (assoc (car b) over)))
                       (if o (cons (car b) (merge (cdr b) (cdr o))) b)))
                   base)
              (remove (lambda (o) (assoc (car o) base)) over))
      over))

(define defaults (toml-parse "[server]\nport = 8080\nhost = \"localhost\"\n[log]\nlevel = \"info\""))
(define system (toml-parse "[server]\nhost = \"0.0.0.0\""))
(define user (toml-parse "[log]\nlevel = \"debug\"\nfile = \"shop.log\""))

(define effective (fold (lambda (layer acc) (merge acc layer)) defaults (list system user)))
(setting effective '("server" "host") #f)   ;; => "0.0.0.0"
(setting effective '("server" "port") #f)   ;; => 8080
(setting effective '("log" "level") #f)     ;; => "debug"
(setting effective '("log" "file") #f)      ;; => "shop.log"
```

With files, read each layer with `(call-with-input-file path toml-read)`,
skipping the ones that do not exist.

## Where next

- [Structured data](techniques-08-structured-data.md), [`(scm json simple)`](scm-json.md),
  [`(scm args)`](scm-args.md) for settings from the command line.
- Reference: `(scm toml)`.

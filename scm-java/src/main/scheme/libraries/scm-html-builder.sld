(define-library (scm html builder)
  (import (scm core) (scheme base) (scheme write) (scm html))
  (export html->string
          html->port
          raw
          raw?
          raw-value
          html5)
  (begin

    ;; --------------------------------------------------------------
    ;; SXML-shaped HTML builder.
    ;;
    ;; Walks an SXML-style tree and emits HTML5. Strings and numbers
    ;; in content position are escaped automatically. Trusted, already-
    ;; rendered HTML is opted in via (raw "<...>"). The whole point of
    ;; the library is that the *default* is safe: forgetting to wrap a
    ;; user-controlled value cannot produce XSS.
    ;;
    ;; Tree shapes
    ;;
    ;;   "text"                  → escaped text
    ;;   42                      → "42"
    ;;   (raw "<b>x</b>")        → emitted verbatim
    ;;   (tag body ...)          → <tag>body...</tag>
    ;;   (tag (@ (k v) ...)
    ;;        body ...)          → <tag k="v" ...>body...</tag>
    ;;   (subnodes ...)          → fragment: each element walked in turn
    ;;                             (used for ,@(map ...) splicing)
    ;;   #f, ()                  → nothing
    ;;
    ;; Attribute values
    ;;
    ;;   string                  → escaped, quoted
    ;;   number                  → number->string, quoted
    ;;   #t                      → emit name only (boolean attribute)
    ;;   #f                      → omit the attribute entirely
    ;;
    ;; <script> and <style> bodies are escaped like any other text. If
    ;; you have inline JS or CSS, wrap it in (raw ...). The escape rules
    ;; for those contexts differ from HTML text, so opt-in is the safe
    ;; default.
    ;; --------------------------------------------------------------

    (define-record-type raw-tag
      (raw* value)
      raw?
      (value raw-value))

    (define (raw s)
      "Syntax: (raw s)
Library: (scm html builder)
Description: Wraps a string so the HTML builder emits it verbatim, without
  escaping. Use for trusted HTML fragments (rendered markdown, server-
  generated SVG, content from another HTML builder pass). Passing user
  input through raw defeats the library's XSS protection — only use it
  with HTML you produced yourself.
Example:
  (html->string `(div ,(raw \"<b>bold</b>\"))) => \"<div><b>bold</b></div>\""
      (raw* (cond ((string? s) s)
                  (else (error "raw: expected string" s)))))

    ;; HTML5 void elements — no closing tag, no body.
    (define void-elements
      '(area base br col embed hr img input link meta source track wbr))

    (define (void-element? sym)
      (memq sym void-elements))

    ;; --- attribute writing ---

    (define (write-attr-value v out)
      (write-char #\" out)
      (cond
        ((string? v) (write-string (html-attr-escape v) out))
        ((number? v) (write-string (number->string v) out))
        ((raw? v)    (write-string (raw-value v) out))
        (else (error "html: bad attribute value" v)))
      (write-char #\" out))

    (define (write-attrs attrs out)
      (let loop ((as attrs))
        (cond
          ((null? as) #f)
          (else
           (let* ((pair (car as))
                  (name (car pair))
                  (val  (cond ((pair? (cdr pair)) (cadr pair))
                              (else (error "html: bad attribute pair" pair)))))
             (cond
               ((eq? val #f) #f)
               ((eq? val #t)
                (write-char #\space out)
                (write-string (symbol->string name) out))
               (else
                (write-char #\space out)
                (write-string (symbol->string name) out)
                (write-char #\= out)
                (write-attr-value val out)))
             (loop (cdr as)))))))

    (define (split-attrs body)
      ;; If the first item of body is (@ ...), return two values
      ;; (attrs rest); else ('() body).
      (cond
        ((and (pair? body) (pair? (car body)) (eq? (caar body) '@))
         (values (cdr (car body)) (cdr body)))
        (else (values '() body))))

    ;; --- main walker ---

    (define (walk-children xs out)
      (let loop ((xs xs))
        (cond
          ((null? xs) #f)
          (else (walk (car xs) out) (loop (cdr xs))))))

    (define (walk node out)
      (cond
        ((not node) #f)              ; #f → nothing
        ((null? node) #f)            ; () → nothing
        ((string? node)
         (write-string (html-escape node) out))
        ((number? node)
         (write-string (number->string node) out))
        ((raw? node)
         (write-string (raw-value node) out))
        ((symbol? node)
         ;; A bare symbol in content position: render its name (escaped).
         ;; Useful enough for things like ,some-symbol in attributes; rare
         ;; in content but harmless.
         (write-string (html-escape (symbol->string node)) out))
        ((pair? node)
         (cond
           ((symbol? (car node)) (emit-element (car node) (cdr node) out))
           (else                 (walk-children node out))))
        (else
         (error "html: cannot render" node))))

    (define (emit-element tag body out)
      (call-with-values (lambda () (split-attrs body))
        (lambda (attrs children)
          (write-char #\< out)
          (write-string (symbol->string tag) out)
          (write-attrs attrs out)
          (cond
            ((void-element? tag)
             (write-char #\> out))
            (else
             (write-char #\> out)
             (walk-children children out)
             (write-string "</" out)
             (write-string (symbol->string tag) out)
             (write-char #\> out))))))

    ;; --- public entry points ---

    (define (html->port port sxml)
      "Syntax: (html->port port sxml)
Library: (scm html builder)
Description: Walks sxml and writes the HTML5 representation to port.
  Useful for streaming responses or appending to a larger string-port.
Example:
  (html->port (current-output-port) '(p \"hi\"))"
      (walk sxml port))

    (define (html->string sxml)
      "Syntax: (html->string sxml)
Library: (scm html builder)
Description: Walks sxml and returns the HTML5 representation as a string.
  String and number text is escaped automatically; (raw \"...\") wrappers
  pass through verbatim. Attribute values follow the same rules; an
  attribute whose value is #f is omitted, #t emits the name as a boolean
  attribute.
Example:
  (html->string `(p (@ (class \"hi\")) \"hello \" ,user))
  ;; → \"<p class=\\\"hi\\\">hello &lt;input&gt;</p>\" when user is \"<input>\""
      (let ((out (open-output-string)))
        (walk sxml out)
        (get-output-string out)))

    (define (html5 . body)
      "Syntax: (html5 body ...)
Library: (scm html builder)
Description: Returns SXML for a complete HTML5 document. The body
  arguments are spliced into a single <html> element, prefixed by the
  HTML5 doctype declaration. Render with html->string or html->port.
Example:
  (html->string
    (html5 '(head (title \"hi\"))
           '(body (p \"hello\"))))
  ;; → \"<!doctype html>\\n<html><head><title>hi</title></head>...\""
      (list (raw "<!doctype html>\n")
            (cons 'html body)))
))

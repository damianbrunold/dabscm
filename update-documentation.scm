(import (scheme base)
        (scheme file)
        (scheme read)
        (scheme write)
        (srfi 1)
        (srfi 132)
        (scm core)
        (scm fs)
        (scm string)
        (except (srfi 13) string-map string-for-each
                string? make-string string string-length string-ref
                string-set! string-fill! string-copy string-copy!
                string->list list->string string-append
                string-upcase string-downcase)
        (scm list)
        (scm system)
        (scm ooxml word))

(define base-dir    (directory-name script-name))
(define libs-dir    (join-path base-dir "scm-lib" "libraries"))
(define output-file (join-path base-dir "documentation" "libraries.html"))

;;; ── Helpers ─────────────────────────────────────────────────────────────────

(define (symbol<? a b)
  (string<? (symbol->string a) (symbol->string b)))

(define (html-escape s)
  (let loop ((chars (string->list s)) (acc '()))
    (if (null? chars)
        (list->string (reverse acc))
        (let ((c (car chars)))
          (cond
            ((char=? c #\&) (loop (cdr chars) (append (reverse (string->list "&amp;"))  acc)))
            ((char=? c #\<) (loop (cdr chars) (append (reverse (string->list "&lt;"))   acc)))
            ((char=? c #\>) (loop (cdr chars) (append (reverse (string->list "&gt;"))   acc)))
            (else           (loop (cdr chars) (cons c acc))))))))

(define (js-escape s)
  (let loop ((chars (string->list s)) (acc '()))
    (if (null? chars)
        (list->string (reverse acc))
        (let ((c (car chars)))
          (cond
            ((char=? c #\\)      (loop (cdr chars) (cons #\\ (cons #\\ acc))))
            ((char=? c #\")      (loop (cdr chars) (cons #\" (cons #\\ acc))))
            ((char=? c #\newline)(loop (cdr chars) (append (reverse (string->list "\\n")) acc)))
            ((char=? c #\return) (loop (cdr chars) (append (reverse (string->list "\\r")) acc)))
            (else                (loop (cdr chars) (cons c acc))))))))

(define (lib-id lib-name)
  ;; (scheme base) -> "scheme-base", (srfi 1) -> "srfi-1"
  (string-join (map (lambda (x) (if (number? x) (number->string x) (symbol->string x))) lib-name) "-"))

(define (lib-category lib-name)
  (cond ((eq? (car lib-name) 'scheme) 'r7rs)
        ((eq? (car lib-name) 'srfi)   'srfi)
        (else                          'scm)))

;;; ── Library metadata ────────────────────────────────────────────────────────

(define lib-descriptions
  '(((scheme base)            . "R7RS base library — core forms and procedures")
    ((scheme case-lambda)     . "Case-lambda for multi-arity procedures")
    ((scheme char)            . "Character classification and case operations")
    ((scheme complex)         . "Complex number arithmetic")
    ((scheme cxr)             . "Compositions of car and cdr up to 4 levels deep")
    ((scheme eval)            . "Evaluation of Scheme expressions")
    ((scheme file)            . "File-based port operations")
    ((scheme inexact)         . "Inexact number operations and trigonometry")
    ((scheme lazy)            . "Lazy evaluation and promises")
    ((scheme load)            . "Loading Scheme source files")
    ((scheme process-context) . "Process exit and context")
    ((scheme r5rs)            . "Full R5RS compatibility library")
    ((scheme read)            . "Reading Scheme data from ports")
    ((scheme repl)            . "REPL environment access")
    ((scheme syntax-case)     . "Syntax-case hygienic macro system")
    ((scheme time)            . "Timestamps and time formatting")
    ((scheme write)           . "Writing and displaying values to ports")
    ((scm compile)            . "Compiler introspection, bytecode access, and type predicates")
    ((scm compression)        . "Data compression and decompression")
    ((scm crypto)             . "Cryptographic hashing and encoding utilities")
    ((scm csv)                . "CSV parsing")
    ((scm database postgres)  . "PostgreSQL database connectivity")
    ((scm database sqlserver) . "SQL Server database connectivity")
    ((scm datetime)           . "Date and time operations")
    ((scm dict)               . "Dictionary / associative map operations")
    ((scm doc)                . "Documentation access")
    ((scm ooxml excel)        . "Excel workbook and worksheet creation (OOXML/XLSX format)")
    ((scm ooxml word)          . "Word document creation (OOXML/DOCX format)")
    ((scm odf spreadsheet)     . "ODF spreadsheet creation (ODS format)")
    ((scm odf writer)          . "ODF text document creation (ODT format)")
    ((scm pdf)                . "PDF document creation — pages, drawing, fonts, text flow, TTF embedding, images, links, outlines")
    ((scm fs)                 . "Filesystem operations — paths, directories, files")
    ((scm glob)               . "Filename globbing and pattern matching")
    ((scm io)                 . "Extended I/O — formatting, port utilities, property lists")
    ((scm json)               . "JSON file reading")
    ((scm list)               . "Extended list operations — higher-order, sorting, accessors")
    ((scm macro)              . "Non-standard macros and meta-programming utilities")
    ((scm match)              . "Pattern matching")
    ((scm math)               . "Math constants and non-standard numeric operations")
    ((scm module)             . "Module system — import, export, search paths, introspection")
    ((scm net http client)    . "HTTP client — GET, POST, and other request methods")
    ((scm net http request)   . "HTTP request construction and accessors")
    ((scm net http response)  . "HTTP response construction and accessors")
    ((scm net http route)     . "HTTP request routing for servers")
    ((scm net http server)    . "HTTP server — listen, accept, and serve requests")
    ((scm net sockets)        . "TCP socket operations — listen, accept, connect")
    ((scm net websocket)      . "WebSocket client and server support")
    ((scm profiling)          . "Execution profiling and performance measurement")
    ((scm string)             . "Extended string operations — search, split, trim, convert")
    ((scm system)             . "System info, environment variables, process execution")
    ((scm templating)         . "Text templating with variable substitution")
    ((scm terminal)           . "Terminal control — colors, cursor, raw mode")
    ((scm xml)                . "XML file reading and navigation")
    ((scm zip)                . "ZIP archive creation and entry writing")
    ((srfi 1)   . "SRFI-1 — List library: fold, any, every, take, drop, iota, lset ops")
    ((srfi 2)   . "SRFI-2 — and-let*: short-circuiting let")
    ((srfi 8)   . "SRFI-8 — receive: binding multiple values")
    ((srfi 9)   . "SRFI-9 — Record types (re-export from scheme base)")
    ((srfi 13)  . "SRFI-13 — String library: predicate-based string operations")
    ((srfi 14)  . "SRFI-14 — Character sets: predicate-wrapped char-set type")
    ((srfi 18)  . "SRFI-18 — Multithreading: threads, mutexes, condition variables")
    ((srfi 19)  . "SRFI-19 — Time data types and procedures: time, date, Julian Day, formatting")
    ((srfi 26)  . "SRFI-26 — cut/cute: partial application via slot notation")
    ((srfi 28)  . "SRFI-28 — Basic format strings")
    ((srfi 48)  . "SRFI-48 — Intermediate format strings: display, write, numeric bases, pretty-print")
    ((srfi 39)  . "SRFI-39 — Parameter objects (re-export from scheme base)")
    ((srfi 69)  . "SRFI-69 — Basic hash tables with eq?/eqv?/equal? support")
    ((srfi 95)  . "SRFI-95 — Sorting and merging: polymorphic sort, merge with optional key")
    ((srfi 98)  . "SRFI-98 — Environment variables")
    ((srfi 111) . "SRFI-111 — Boxes: mutable single-value containers")
    ((srfi 125) . "SRFI-125 — Intermediate hash tables: comparator-based hash tables with mapping, folding, and set operations")
    ((srfi 128) . "SRFI-128 — Comparators: bundled type-test, equality, ordering, and hash procedures")
    ((srfi 132) . "SRFI-132 — Sort libraries: list/vector sort, merge, select, median")
    ((srfi 133) . "SRFI-133 — Vector libraries")
    ((srfi 151) . "SRFI-151 — Bitwise operations: logic, shifts, fields, and folds on exact integers")
    ((srfi 158) . "SRFI-158 — Generators and accumulators: lazy sequences, composable pipelines, and value collectors")))

(define (lib-description lib-name)
  (let ((entry (find (lambda (e) (equal? (car e) lib-name)) lib-descriptions)))
    (if entry (cdr entry) "")))

;;; ── Parse .sld files ────────────────────────────────────────────────────────

(define (parse-sld-file filepath)
  ;; Returns (lib-name . sorted-export-list)
  (let* ((port (open-input-file filepath))
         (form (read port)))
    (close-input-port port)
    (let ((lib-name (cadr form))
          (clauses  (cddr form)))
      (let ((exports (apply append
                       (map (lambda (clause)
                              (if (and (pair? clause)
                                       (eq? (car clause) 'export))
                                  (map (lambda (e) (if (pair? e) (car e) e)) (cdr clause))
                                  '()))
                            clauses))))
        (cons lib-name (list-sort symbol<? exports))))))

(define sld-files
  (list-sort string<?
    (filter (lambda (f) (string-suffix? ".sld" f))
            (directory-files libs-dir))))

(define lib-data
  (map (lambda (f) (parse-sld-file (join-path libs-dir f)))
       sld-files))

;;; ── Subprocess-based doc collection ─────────────────────────────────────────

(define (get-java-executable cmd)
  (if (eq? (sys-platform) 'linux)
      (which cmd)
      (which (string-append cmd ".exe"))))

(define jar-path    (join-path base-dir "scm-java" "scm.jar"))
(define temp-script (join-path (special-folder-temp) "scm-doc-collect.scm"))
(define temp-output (join-path (special-folder-temp) "scm-doc-output.scm"))

(define (lib-name->import-spec lib-name)
  ;; (scheme base) -> "(scheme base)"
  (string-append "(" (string-join (map (lambda (x)
    (if (number? x) (number->string x) (symbol->string x))) lib-name) " ") ")"))

(define (collect-docs lib-name exports)
  ;; Write a temp script that imports the library, collects docs, writes to temp-output
  (let ((import-spec (lib-name->import-spec lib-name))
        (sym-list (string-join (map (lambda (s) (symbol->string s)) exports) " ")))
    (call-with-output-file temp-script
      (lambda (port)
        ;; Use minimal imports to avoid provenance conflicts with the target library.
        ;; Only import (scm doc) for procedure-doc and the target library.
        ;; Bind needed primitives directly via %primitive.
        (display "(import (scm core) " port)
        (display import-spec port)
        (display ")\n" port)
        (display "(set! procedure-doc (%primitive \"procedure-doc\"))\n" port)
        (display "(set! symbol->string (%primitive \"symbol->string\"))\n" port)
        (display "(set! write (%primitive \"write\"))\n" port)
        (display "(set! close-output-port (%primitive \"close-output-port\"))\n" port)
        (display "(let ((port ((%primitive \"open-output-file\") " port)
        (write temp-output port)
        (display ")))\n" port)
        (display "  (write\n    (map (lambda (sym) (cons (symbol->string sym) (procedure-doc sym)))\n         '(" port)
        (display sym-list port)
        (display "))\n    port)\n  (close-output-port port))\n" port)))
    ;; Run the subprocess
    (let ((exit-code (run-program (list (get-java-executable "java") "-jar" jar-path temp-script))))
      (if (not (zero? exit-code))
          '()
          ;; Read the result
          (guard (exn (#t '()))
            (let* ((port (open-input-file temp-output))
                   (data (read port)))
              (close-input-port port)
              ;; Filter out entries with #f doc
              (let loop ((lst data) (acc '()))
                (if (null? lst) (reverse acc)
                    (if (cdr (car lst))
                        (loop (cdr lst) (cons (car lst) acc))
                        (loop (cdr lst) acc))))))))))

;; all-lib-docs: list of (id-string . ((sym-str . doc-str) ...))
(define all-lib-docs
  (map (lambda (entry)
         (let* ((lib-name (car entry))
                (exports  (cdr entry)))
           (display "  ")
           (display lib-name)
           (newline)
           (cons (lib-id lib-name)
                 (collect-docs lib-name exports))))
       lib-data))

;;; ── JS docs object ──────────────────────────────────────────────────────────

(define (build-docs-js all-docs port)
  (display "const docs = {\n" port)
  (for-each
   (lambda (lib-entry)
     (let ((id   (car lib-entry))
           (syms (cdr lib-entry)))
       (when (not (null? syms))
         (display "  \"" port)
         (display id port)
         (display "\": {\n" port)
         (for-each
          (lambda (sym-entry)
            (display "    \"" port)
            (display (js-escape (car sym-entry)) port)
            (display "\": \"" port)
            (display (js-escape (cdr sym-entry)) port)
            (display "\",\n" port))
          syms)
         (display "  },\n" port))))
   all-docs)
  (display "};\n" port))

;;; ── HTML generation ─────────────────────────────────────────────────────────

(define (lib-name-str lib-name)
  (string-append
   "("
   (string-join (map (lambda (x)
                       (if (number? x)
                           (number->string x)
                           (symbol->string x)))
                     lib-name) " ")
   ")"))

(define r7rs-libs (filter (lambda (e) (eq? (lib-category (car e)) 'r7rs))
                          lib-data))
(define srfi-libs (list-sort
                   (lambda (a b) (< (cadr (car a)) (cadr (car b))))
                   (filter (lambda (e) (eq? (lib-category (car e)) 'srfi))
                           lib-data)))
(define scm-libs  (filter (lambda (e) (eq? (lib-category (car e)) 'scm))
                          lib-data))

(define (emit-nav-links libs class port)
  (for-each
   (lambda (entry)
     (let* ((lib-name (car entry))
            (id       (lib-id lib-name))
            (name     (lib-name-str lib-name)))
       (display "  <a href=\"#" port)
       (display id port)
       (display "\" class=\"" port)
       (display class port)
       (display "\">" port)
       (display (html-escape name) port)
       (display "</a>\n" port)))
   libs))

(define (emit-library-card entry port)
  (let* ((lib-name (car entry))
         (exports  (cdr entry))
         (id       (lib-id lib-name))
         (class    (symbol->string (lib-category lib-name)))
         (name     (lib-name-str lib-name))
         (desc     (lib-description lib-name)))
    (display "<div class=\"library " port) (display class port) (display "\" id=\"" port)
    (display id port) (display "\">\n" port)
    (display "  <div class=\"lib-header\">\n" port)
    (display "    <span class=\"lib-name\">" port)
    (display (html-escape name) port)
    (display "</span>\n" port)
    (display "    <span class=\"lib-desc\">" port)
    (display (html-escape desc) port)
    (display "</span>\n" port)
    (display "    <span class=\"lib-count\" id=\"" port)
    (display id port) (display "-count\"></span>\n" port)
    (display "  </div>\n" port)
    (display "  <div class=\"lib-body\">\n" port)
    (display "    <div class=\"exports\" data-lib=\"" port)
    (display id port) (display "\">\n" port)
    (for-each
     (lambda (sym)
       (display "      " port)
       (display (html-escape (symbol->string sym)) port)
       (newline port))
     exports)
    (display "    </div>\n" port)
    (display "    <div class=\"doc-panel\" id=\"" port)
    (display id port) (display "-doc-panel\"></div>\n" port)
    (display "  </div>\n" port)
    (display "</div>\n\n" port)))

;;; ── Write output ────────────────────────────────────────────────────────────
(call-with-output-file output-file
  (lambda (port)

    (display "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n" port)
    (display "<meta charset=\"UTF-8\">\n" port)
    (display "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n" port)
    (display "<title>Scm Library Reference</title>\n" port)
    (display "<style>\n" port)
    (display "  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }\n\n" port)
    (display "  :root {\n" port)
    (display "    --bg: #0f1117;\n" port)
    (display "    --bg2: #181c27;\n" port)
    (display "    --bg3: #1e2333;\n" port)
    (display "    --border: #2a3050;\n" port)
    (display "    --text: #c9d1e0;\n" port)
    (display "    --text-dim: #6b7899;\n" port)
    (display "    --r7rs: #4a9eff;\n" port)
    (display "    --r7rs-bg: #0d2040;\n" port)
    (display "    --r7rs-border: #1a3a6a;\n" port)
    (display "    --scm: #5ec48a;\n" port)
    (display "    --scm-bg: #0a2018;\n" port)
    (display "    --scm-border: #1a4a30;\n" port)
    (display "    --srfi: #c792ea;\n" port)
    (display "    --srfi-bg: #1a0d2e;\n" port)
    (display "    --srfi-border: #3a1a5a;\n" port)
    (display "    --tag-bg: #1e2a45;\n" port)
    (display "    --tag-text: #8baad4;\n" port)
    (display "    --heading: #e8edf5;\n" port)
    (display "    --code: #b8c8e8;\n" port)
    (display "  }\n\n" port)
    (display "  body {\n    font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, sans-serif;\n    background: var(--bg);\n    color: var(--text);\n    line-height: 1.6;\n    min-height: 100vh;\n  }\n\n" port)
    (display "  header {\n    background: var(--bg2);\n    border-bottom: 1px solid var(--border);\n    padding: 24px 40px;\n    position: sticky;\n    top: 0;\n    z-index: 100;\n    display: flex;\n    align-items: center;\n    gap: 24px;\n  }\n\n" port)
    (display "  header h1 {\n    font-size: 1.3rem;\n    font-weight: 600;\n    color: var(--heading);\n    letter-spacing: -0.02em;\n  }\n\n" port)
    (display "  header p { color: var(--text-dim); font-size: 0.875rem; }\n\n" port)
    (display "  #search {\n    margin-left: auto;\n    background: var(--bg3);\n    border: 1px solid var(--border);\n    border-radius: 6px;\n    padding: 7px 14px;\n    color: var(--text);\n    font-size: 0.875rem;\n    width: 260px;\n    outline: none;\n    transition: border-color 0.15s;\n  }\n\n" port)
    (display "  #search:focus { border-color: var(--r7rs); }\n  #search::placeholder { color: var(--text-dim); }\n\n" port)
    (display "  .layout {\n    display: flex;\n    min-height: calc(100vh - 65px);\n  }\n\n" port)
    (display "  nav {\n    width: 220px;\n    flex-shrink: 0;\n    background: var(--bg2);\n    border-right: 1px solid var(--border);\n    padding: 24px 0;\n    position: sticky;\n    top: 65px;\n    height: calc(100vh - 65px);\n    overflow-y: auto;\n  }\n\n" port)
    (display "  nav h2 {\n    font-size: 0.7rem;\n    font-weight: 600;\n    text-transform: uppercase;\n    letter-spacing: 0.08em;\n    color: var(--text-dim);\n    padding: 0 20px 8px;\n    margin-top: 20px;\n  }\n\n" port)
    (display "  nav h2:first-child { margin-top: 0; }\n\n" port)
    (display "  nav a {\n    display: block;\n    padding: 5px 20px;\n    font-size: 0.8rem;\n    color: var(--text-dim);\n    text-decoration: none;\n    transition: color 0.1s, background 0.1s;\n    border-left: 2px solid transparent;\n  }\n\n" port)
    (display "  nav a:hover { color: var(--text); background: var(--bg3); }\n\n" port)
    (display "  nav a.r7rs { border-left-color: transparent; }\n  nav a.r7rs:hover { color: var(--r7rs); border-left-color: var(--r7rs); }\n  nav a.scm:hover { color: var(--scm); border-left-color: var(--scm); }\n  nav a.srfi:hover { color: var(--srfi); border-left-color: var(--srfi); }\n\n" port)
    (display "  main {\n    flex: 1;\n    padding: 40px;\n    max-width: 1100px;\n  }\n\n" port)
    (display "  .section-heading {\n    display: flex;\n    align-items: center;\n    gap: 12px;\n    margin-bottom: 24px;\n    margin-top: 40px;\n  }\n\n" port)
    (display "  .section-heading:first-child { margin-top: 0; }\n\n" port)
    (display "  .section-heading h2 {\n    font-size: 1rem;\n    font-weight: 600;\n    color: var(--heading);\n  }\n\n" port)
    (display "  .section-heading hr {\n    flex: 1;\n    border: none;\n    border-top: 1px solid var(--border);\n  }\n\n" port)
    (display "  .badge {\n    font-size: 0.65rem;\n    font-weight: 700;\n    text-transform: uppercase;\n    letter-spacing: 0.06em;\n    padding: 2px 7px;\n    border-radius: 4px;\n  }\n\n" port)
    (display "  .badge-r7rs { background: var(--r7rs-bg); color: var(--r7rs); border: 1px solid var(--r7rs-border); }\n  .badge-scm  { background: var(--scm-bg);  color: var(--scm);  border: 1px solid var(--scm-border);  }\n  .badge-srfi { background: var(--srfi-bg); color: var(--srfi); border: 1px solid var(--srfi-border); }\n\n" port)
    (display "  .library {\n    background: var(--bg2);\n    border: 1px solid var(--border);\n    border-radius: 10px;\n    margin-bottom: 20px;\n    overflow: hidden;\n    transition: border-color 0.15s;\n  }\n\n" port)
    (display "  .library:hover { border-color: #3a4560; }\n\n" port)
    (display "  .library.r7rs { border-left: 3px solid var(--r7rs); }\n  .library.scm  { border-left: 3px solid var(--scm);  }\n  .library.srfi { border-left: 3px solid var(--srfi); }\n\n" port)
    (display "  .lib-header {\n    display: flex;\n    align-items: baseline;\n    gap: 12px;\n    padding: 16px 20px 12px;\n    border-bottom: 1px solid var(--border);\n    cursor: pointer;\n    user-select: none;\n  }\n\n" port)
    (display "  .lib-name {\n    font-family: \"SF Mono\", \"Fira Code\", \"Cascadia Code\", Consolas, monospace;\n    font-size: 0.95rem;\n    font-weight: 600;\n    color: var(--heading);\n  }\n\n" port)
    (display "  .library.r7rs .lib-name { color: var(--r7rs); }\n  .library.scm  .lib-name { color: var(--scm); }\n  .library.srfi .lib-name { color: var(--srfi); }\n\n" port)
    (display "  .lib-desc {\n    font-size: 0.8rem;\n    color: var(--text-dim);\n  }\n\n" port)
    (display "  .lib-count {\n    margin-left: auto;\n    font-size: 0.75rem;\n    color: var(--text-dim);\n    white-space: nowrap;\n  }\n\n" port)
    (display "  .lib-body {\n    padding: 16px 20px;\n  }\n\n" port)
    (display "  .exports {\n    display: flex;\n    flex-wrap: wrap;\n    gap: 6px;\n  }\n\n" port)
    (display "  .export {\n    font-family: \"SF Mono\", \"Fira Code\", \"Cascadia Code\", Consolas, monospace;\n    font-size: 0.75rem;\n    padding: 3px 8px;\n    border-radius: 4px;\n    background: var(--tag-bg);\n    color: var(--tag-text);\n    border: 1px solid transparent;\n    transition: background 0.1s, color 0.1s;\n    cursor: pointer;\n  }\n\n" port)
    (display "  .library.r7rs .export { background: var(--r7rs-bg); color: #6aafe8; border-color: var(--r7rs-border); }\n  .library.scm  .export { background: var(--scm-bg);  color: #5ab87e; border-color: var(--scm-border); }\n  .library.srfi .export { background: var(--srfi-bg); color: #c0a0e0; border-color: var(--srfi-border); }\n\n" port)
    (display "  .export.highlight {\n    background: #3a2800;\n    color: #ffcc55;\n    border-color: #5a4400;\n  }\n\n" port)
    (display "  .export.active { background: #3a2800; color: #ffcc55; border-color: #5a4400; }\n  .library.r7rs .export.active { background: #0d2a50; color: #7ac0f0; border-color: #1e4a80; }\n  .library.scm  .export.active { background: #0d2a18; color: #6edd90; border-color: #1a4a28; }\n  .library.srfi .export.active { background: #200d38; color: #d4a8f0; border-color: #4a1a70; }\n\n" port)
    (display "  .export.hidden { display: none; }\n\n" port)
    (display "  .doc-panel {\n    display: none;\n    margin-top: 12px;\n    padding: 12px;\n    background: var(--bg3);\n    border: 1px solid var(--border);\n    border-radius: 6px;\n    font-family: \"SF Mono\", \"Fira Code\", \"Cascadia Code\", Consolas, monospace;\n    font-size: 0.8rem;\n    white-space: pre-wrap;\n    color: var(--text);\n  }\n\n" port)
    (display "  .doc-panel.visible { display: block; }\n\n" port)
    (display "  .library.hidden { display: none; }\n\n" port)
    (display "  @media (max-width: 768px) {\n    header { padding: 16px 20px; }\n    main { padding: 20px; }\n    nav { display: none; }\n    #search { width: 180px; }\n  }\n" port)
    (display "</style>\n</head>\n<body>\n\n" port)

    ;; Header
    (display "<header>\n  <div>\n    <h1>Scm Library Reference</h1>\n    <p>scm &mdash; available libraries and their exports</p>\n  </div>\n  <input type=\"search\" id=\"search\" placeholder=\"Search identifiers&hellip;\" autocomplete=\"off\" spellcheck=\"false\">\n</header>\n\n" port)

    ;; Layout
    (display "<div class=\"layout\">\n\n" port)

    ;; Nav
    (display "<nav>\n  <h2>R7RS Standard</h2>\n" port)
    (emit-nav-links r7rs-libs "r7rs" port)
    (display "  <h2>SRFI Libraries</h2>\n" port)
    (emit-nav-links srfi-libs "srfi" port)
    (display "  <h2>Scm Extensions</h2>\n" port)
    (emit-nav-links scm-libs "scm" port)
    (display "</nav>\n\n" port)

    ;; Main
    (display "<main>\n\n" port)

    (display "<div class=\"section-heading\">\n  <h2>R7RS Standard Libraries</h2>\n  <hr>\n  <span class=\"badge badge-r7rs\">R7RS</span>\n</div>\n\n" port)
    (for-each (lambda (e) (emit-library-card e port)) r7rs-libs)

    (display "<div class=\"section-heading\">\n  <h2>SRFI Libraries</h2>\n  <hr>\n  <span class=\"badge badge-srfi\">SRFI</span>\n</div>\n\n" port)
    (for-each (lambda (e) (emit-library-card e port)) srfi-libs)

    (display "<div class=\"section-heading\">\n  <h2>Scm Extension Libraries</h2>\n  <hr>\n  <span class=\"badge badge-scm\">scm</span>\n</div>\n\n" port)
    (for-each (lambda (e) (emit-library-card e port)) scm-libs)

    (display "</main>\n</div>\n\n" port)

    ;; JavaScript
    (display "<script>\n" port)

    ;; Part A: tokenise exports into spans
    (display "const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');\n\n" port)
    (display "document.querySelectorAll('.exports').forEach(div => {\n" port)
    (display "  const libId = div.dataset.lib;\n" port)
    (display "  const tokens = div.textContent.trim().split(/\\s+/).filter(Boolean);\n" port)
    (display "  div.innerHTML = tokens.map(t => `<span class=\"export\" data-sym=\"${esc(t)}\">${esc(t)}</span>`).join('');\n" port)
    (display "  const countEl = document.getElementById(libId + '-count');\n" port)
    (display "  if (countEl) countEl.textContent = tokens.length + ' bindings';\n" port)
    (display "});\n\n" port)

    ;; Part B: docs object
    (build-docs-js all-lib-docs port)
    (newline port)

    ;; Part C: click handler
    (display "document.querySelectorAll('.exports').forEach(div => {\n" port)
    (display "  const libId = div.dataset.lib;\n" port)
    (display "  const libDocs = docs[libId] || {};\n" port)
    (display "  const panel = document.getElementById(libId + '-doc-panel');\n" port)
    (display "  div.addEventListener('click', e => {\n" port)
    (display "    const span = e.target.closest('.export');\n" port)
    (display "    if (!span) return;\n" port)
    (display "    const sym = span.dataset.sym;\n" port)
    (display "    if (span.classList.contains('active')) {\n" port)
    (display "      span.classList.remove('active');\n" port)
    (display "      if (panel) { panel.classList.remove('visible'); panel.textContent = ''; }\n" port)
    (display "      return;\n" port)
    (display "    }\n" port)
    (display "    div.querySelectorAll('.export.active').forEach(s => s.classList.remove('active'));\n" port)
    (display "    span.classList.add('active');\n" port)
    (display "    if (panel && libDocs[sym]) {\n" port)
    (display "      panel.textContent = libDocs[sym];\n" port)
    (display "      panel.classList.add('visible');\n" port)
    (display "    } else if (panel) {\n" port)
    (display "      panel.classList.remove('visible'); panel.textContent = '';\n" port)
    (display "    }\n" port)
    (display "  });\n" port)
    (display "});\n\n" port)

    ;; Part D: search
    (display "const search = document.getElementById('search');\n" port)
    (display "search.addEventListener('input', () => {\n" port)
    (display "  const q = search.value.trim().toLowerCase();\n" port)
    (display "  document.querySelectorAll('.library').forEach(lib => {\n" port)
    (display "    const libId = lib.querySelector('.exports') && lib.querySelector('.exports').dataset.lib;\n" port)
    (display "    const libDocs = (libId && docs[libId]) || {};\n" port)
    (display "    const panel = libId ? document.getElementById(libId + '-doc-panel') : null;\n" port)
    (display "    if (!q) {\n" port)
    (display "      lib.classList.remove('hidden');\n" port)
    (display "      lib.querySelectorAll('.export').forEach(e => e.classList.remove('highlight', 'active', 'hidden'));\n" port)
    (display "      if (panel) { panel.classList.remove('visible'); panel.textContent = ''; }\n" port)
    (display "      return;\n" port)
    (display "    }\n" port)
    (display "    const matches = [];\n" port)
    (display "    lib.querySelectorAll('.export').forEach(e => {\n" port)
    (display "      const sym = e.dataset.sym.toLowerCase();\n" port)
    (display "      if (sym.includes(q)) {\n" port)
    (display "        e.classList.add('highlight');\n" port)
    (display "        e.classList.remove('hidden', 'active');\n" port)
    (display "        matches.push(e);\n" port)
    (display "      } else {\n" port)
    (display "        e.classList.add('hidden');\n" port)
    (display "        e.classList.remove('highlight', 'active');\n" port)
    (display "      }\n" port)
    (display "    });\n" port)
    (display "    lib.classList.toggle('hidden', matches.length === 0);\n" port)
    (display "    if (matches.length === 1 && panel) {\n" port)
    (display "      const sym = matches[0].dataset.sym;\n" port)
    (display "      matches[0].classList.add('active');\n" port)
    (display "      if (libDocs[sym]) { panel.textContent = libDocs[sym]; panel.classList.add('visible'); }\n" port)
    (display "      else { panel.classList.remove('visible'); panel.textContent = ''; }\n" port)
    (display "    } else if (panel) {\n" port)
    (display "      panel.classList.remove('visible'); panel.textContent = '';\n" port)
    (display "    }\n" port)
    (display "  });\n" port)
    (display "});\n" port)

    (display "</script>\n\n</body>\n</html>\n" port)))

;;; ── Markdown and RTF helpers ─────────────────────────────────────────────────

(define (docs-for-lib id)
  (let ((entry (find (lambda (e) (equal? (car e) id)) all-lib-docs)))
    (if entry (cdr entry) '())))

(define (md-escape s)
  (let loop ((chars (string->list s)) (acc '()))
    (if (null? chars) (list->string (reverse acc))
        (let ((c (car chars)))
          (cond ((char=? c #\`) (loop (cdr chars) (cons #\` (cons #\\ acc))))
                ((char=? c #\|) (loop (cdr chars) (cons #\| (cons #\\ acc))))
                (else           (loop (cdr chars) (cons c acc))))))))

;;; ── Per-library Markdown generation ─────────────────────────────────────────

(define md-libs-dir (join-path base-dir "documentation" "libraries"))

(unless (directory-exists? md-libs-dir)
  (make-directory md-libs-dir))

(for-each
 (lambda (f)
   (when (string-suffix? ".md" f)
     (delete-file (join-path md-libs-dir f))))
 (directory-files md-libs-dir))

(for-each
 (lambda (entry)
   (let* ((lib-name (car entry))
          (exports  (cdr entry))
          (id       (lib-id lib-name))
          (name     (lib-name-str lib-name))
          (desc     (lib-description lib-name))
          (docs     (docs-for-lib id))
          (outfile  (join-path md-libs-dir (string-append id ".md"))))
     (call-with-output-file outfile
       (lambda (port)
         (display "# `" port)
         (display name port)
         (display "`\n\n" port)
         (when (not (string=? desc ""))
           (display desc port)
           (display "\n\n" port))
         (display "## Exports\n\n" port)
         (for-each
          (lambda (sym)
            (let* ((sym-str  (symbol->string sym))
                   (doc-entry (find (lambda (e) (string=? (car e) sym-str)) docs)))
              (display "### `" port)
              (display (md-escape sym-str) port)
              (display "`\n\n" port)
              (if (and doc-entry (not (string=? (cdr doc-entry) "")))
                  (begin
                    (display "```\n" port)
                    (display (cdr doc-entry) port)
                    (newline port)
                    (display "```\n\n" port))
                  (begin
                    (display "*(no documentation)*\n\n" port)))))
          exports)))))
 lib-data)

;;; ── Markdown TOC (index.md) ──────────────────────────────────────────────────

(define md-index-file (join-path base-dir "documentation" "index.md"))

(call-with-output-file md-index-file
  (lambda (port)
    (display "# Scm Library Reference\n\n" port)

    (display "## R7RS Standard Libraries\n\n" port)
    (display "| Library | Description |\n" port)
    (display "|---------|-------------|\n" port)
    (for-each
     (lambda (entry)
       (let* ((lib-name (car entry))
              (id       (lib-id lib-name))
              (name     (lib-name-str lib-name))
              (desc     (lib-description lib-name)))
         (display "| [`" port)
         (display (md-escape name) port)
         (display "`](libraries/" port)
         (display id port)
         (display ".md) | " port)
         (display (md-escape desc) port)
         (display " |\n" port)))
     r7rs-libs)
    (newline port)

    (display "## SRFI Libraries\n\n" port)
    (display "| Library | Description |\n" port)
    (display "|---------|-------------|\n" port)
    (for-each
     (lambda (entry)
       (let* ((lib-name (car entry))
              (id       (lib-id lib-name))
              (name     (lib-name-str lib-name))
              (desc     (lib-description lib-name)))
         (display "| [`" port)
         (display (md-escape name) port)
         (display "`](libraries/" port)
         (display id port)
         (display ".md) | " port)
         (display (md-escape desc) port)
         (display " |\n" port)))
     srfi-libs)
    (newline port)
    
    (display "## Scm Extension Libraries\n\n" port)
    (display "| Library | Description |\n" port)
    (display "|---------|-------------|\n" port)
    (for-each
     (lambda (entry)
       (let* ((lib-name (car entry))
              (id       (lib-id lib-name))
              (name     (lib-name-str lib-name))
              (desc     (lib-description lib-name)))
         (display "| [`" port)
         (display (md-escape name) port)
         (display "`](libraries/" port)
         (display id port)
         (display ".md) | " port)
         (display (md-escape desc) port)
         (display " |\n" port)))
     scm-libs)))


;;; ── DOCX reference (reference.docx) ─────────────────────────────────────────

(define docx-output-file (join-path base-dir "documentation" "reference.docx"))

;;; Parse a docstring into an alist of field name -> value string.
;;; Fields: "Syntax", "Library", "Description", "Example".
;;; "Example:" collects all remaining lines as the value.
(define (parse-docstring doc)
  (let ((lines (string-split doc "\n")))
    (let loop ((lines lines) (result '()))
      (if (null? lines)
          (reverse result)
          (let ((line (car lines)))
            (cond
              ((string-prefix? "Syntax: " line)
               (loop (cdr lines)
                     (cons (cons "Syntax" (substring line 8 (string-length line))) result)))
              ((string-prefix? "Library: " line)
               (loop (cdr lines)
                     (cons (cons "Library" (substring line 9 (string-length line))) result)))
              ((string-prefix? "Description: " line)
               (loop (cdr lines)
                     (cons (cons "Description" (substring line 13 (string-length line))) result)))
              ((or (string=? line "Example:")
                   (string-prefix? "Example: " line))
               ;; Everything remaining is the example body
               (let* ((first (if (string=? line "Example:") ""
                                 (substring line 9 (string-length line))))
                      (rest  (cdr lines))
                      (all   (if (string=? first "") rest (cons first rest))))
                 (reverse (cons (cons "Example" (string-join all "\n")) result))))
              (else
               (loop (cdr lines) result))))))))

;;; Strip up to two leading spaces (docstring indentation convention).
(define (strip-indent-2 s)
  (if (and (>= (string-length s) 2)
           (char=? (string-ref s 0) #\space)
           (char=? (string-ref s 1) #\space))
      (substring s 2 (string-length s))
      s))

;;; Returns #t if s contains at least one non-space character.
(define (non-blank? s)
  (let loop ((cs (string->list s)))
    (cond ((null? cs) #f)
          ((char=? (car cs) #\space) (loop (cdr cs)))
          (else #t))))

;;; Emit one symbol entry as DOCX: heading, index entry, and parsed doc fields.
(define (emit-docx-entry wdoc sym-str doc-string)
  ;; Heading 2 with symbol name + index entry
  (let ((h (document-add-heading! wdoc 2 sym-str)))
    (paragraph-add-index-entry! h sym-str))
  (if (and doc-string (not (string=? doc-string "")))
      (let* ((fields (parse-docstring doc-string))
             (syntax (assoc "Syntax" fields))
             (desc   (assoc "Description" fields))
             (ex     (assoc "Example" fields)))
        ;; Syntax: monospace, left-indented — the call signature
        (when syntax
          (let ((p (document-add-paragraph! wdoc)))
            (paragraph-set-indent! p 18)
            (paragraph-set-spacing! p 0 2)
            (paragraph-add-run! p (cdr syntax) font: "Courier New" size: 8)))
        ;; Description: proportional font, indented
        (when desc
          (let ((p (document-add-paragraph! wdoc)))
            (paragraph-set-indent! p 18)
            (paragraph-set-spacing! p 0 2)
            (paragraph-add-run! p (cdr desc) size: 9)))
        ;; Example block: italic label then monospace code lines, extra indent
        (when ex
          (let ((code-lines (filter non-blank? (string-split (cdr ex) "\n"))))
            (when (not (null? code-lines))
              (let ((p (document-add-paragraph! wdoc)))
                (paragraph-set-indent! p 18)
                (paragraph-set-spacing! p 0 1)
                (paragraph-add-run! p "Example:" italic size: 8))
              (for-each
               (lambda (line)
                 (let ((p (document-add-paragraph! wdoc)))
                   (paragraph-set-indent! p 36)
                   (paragraph-set-spacing! p 0 0)
                   (paragraph-add-run! p (strip-indent-2 line) font: "Courier New" size: 8)))
               code-lines)))))
      ;; No documentation available
      (let ((p (document-add-paragraph! wdoc)))
        (paragraph-set-indent! p 18)
        (paragraph-add-run! p "(no documentation)" italic size: 9))))

(define (emit-docx-lib-section wdoc entry)
  (let* ((lib-name (car entry))
         (exports  (cdr entry))
         (id       (lib-id lib-name))
         (name     (lib-name-str lib-name))
         (desc     (lib-description lib-name))
         (docs     (docs-for-lib id)))
    ;; Library heading (Heading 1 — appears in TOC) + index entry
    (let ((h (document-add-heading! wdoc 1 name)))
      (paragraph-add-index-entry! h name))
    ;; Library description in italic below the heading
    (when (not (string=? desc ""))
      (let ((p (document-add-paragraph! wdoc)))
        (paragraph-set-spacing! p 0 8)
        (paragraph-add-run! p desc italic size: 9)))
    ;; Each exported symbol
    (for-each
     (lambda (sym)
       (let* ((sym-str   (symbol->string sym))
              (doc-entry (find (lambda (e) (string=? (car e) sym-str)) docs)))
         (emit-docx-entry wdoc sym-str (if doc-entry (cdr doc-entry) #f))))
     exports)
    ;; Page break between libraries
    (document-add-page-break! wdoc)))

(let ((wdoc (make-document)))
  (document-set-page-size! wdoc 'a5)
  ;; Page number footer
  (let ((f (document-add-paragraph! wdoc)))
    (paragraph-set-alignment! f 'center)
    (paragraph-add-page-number! f)
    (document-set-footer! wdoc f))
  ;; Title page
  (let ((p (document-add-paragraph! wdoc)))
    (paragraph-set-alignment! p 'center)
    (paragraph-set-spacing! p 54 6)
    (paragraph-add-run! p "Scm Library Reference" bold size: 26))
  (let ((p (document-add-paragraph! wdoc)))
    (paragraph-set-alignment! p 'center)
    (paragraph-set-spacing! p 6 0)
    (paragraph-add-run! p "Scm R7RS Scheme Interpreter" italic size: 10))
  (document-add-page-break! wdoc)

  ;; Table of Contents — shows only Heading 1 (libraries)
  (document-add-table-of-contents! wdoc "Table of Contents" 1)
  (document-add-page-break! wdoc)

  ;; R7RS Standard Libraries
  (document-add-heading! wdoc 1 "R7RS Standard Libraries")
  (document-add-page-break! wdoc)
  (for-each (lambda (e) (emit-docx-lib-section wdoc e)) r7rs-libs)

  ;; SRFI Libraries
  (document-add-heading! wdoc 1 "SRFI Libraries")
  (document-add-page-break! wdoc)
  (for-each (lambda (e) (emit-docx-lib-section wdoc e)) srfi-libs)

  ;; Scm Extension Libraries
  (document-add-heading! wdoc 1 "Scm Extension Libraries")
  (document-add-page-break! wdoc)
  (for-each (lambda (e) (emit-docx-lib-section wdoc e)) scm-libs)

  ;; Symbol Index
  (document-add-index! wdoc "Symbol Index")

  (document-save wdoc docx-output-file))

(display "done")
(newline)

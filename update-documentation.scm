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
        (scm markdown)
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
    ((scm archive)            . "Archive and compression — tar, gzip, bzip2, xz, and zip operations")
    ((scm args)               . "Declarative command-line argument parsing — options, flags, positionals, typed values")
    ((scm compile)            . "Compiler introspection, bytecode access, and type predicates")
    ((scm compression)        . "Data compression and decompression")
    ((scm crypto)             . "Cryptographic hashing and encoding utilities")
    ((scm csv)                . "CSV parsing")
    ((scm database migrations) . "Forward-only SQL migration runner")
    ((scm database postgres)  . "PostgreSQL database connectivity")
    ((scm database sqlserver) . "SQL Server database connectivity")
    ((scm datetime)           . "Date and time operations")
    ((scm dict)               . "Dictionary / associative map operations")
    ((scm doc)                . "Documentation access")
    ((scm duration)           . "Duration string parsing and formatting (seconds, minutes, hours, days)")
    ((scm feed)               . "Atom and RSS 2.0 feed parsing")
    ((scm fs)                 . "Filesystem operations — paths, directories, files")
    ((scm fs-find)            . "Filesystem traversal and reporting — find-file, tree, du, df, xargs")
    ((scm glob)               . "Filename globbing and pattern matching")
    ((scm html)               . "HTML escaping and tag stripping")
    ((scm html builder)       . "SXML-shaped HTML5 builder with automatic escaping")
    ((scm io)                 . "Extended I/O — formatting, port utilities, property lists")
    ((scm json)               . "JSON file reading")
    ((scm json simple)        . "High-level JSON codec — parse and serialize JSON as Scheme data")
    ((scm list)               . "Extended list operations — higher-order, sorting, accessors")
    ((scm log)                . "Structured single-line logging")
    ((scm macro)              . "Non-standard macros and meta-programming utilities")
    ((scm markdown)           . "Markdown parser and HTML renderer (CommonMark subset)")
    ((scm match)              . "Pattern matching")
    ((scm math)               . "Math constants and non-standard numeric operations")
    ((scm module)             . "Module system — import, export, search paths, introspection")
    ((scm net http client)    . "HTTP client — GET, POST, and other request methods")
    ((scm net http cookies)   . "HTTP cookie header parsing and Set-Cookie formatting")
    ((scm net http forms)     . "application/x-www-form-urlencoded form and query parsing")
    ((scm net http multipart) . "multipart/form-data parsing (RFC 7578)")
    ((scm net http request)   . "HTTP request construction and accessors")
    ((scm net http response)  . "HTTP response construction and accessors")
    ((scm net http route)     . "HTTP request routing for servers")
    ((scm net http server)    . "HTTP server — listen, accept, and serve requests")
    ((scm net sockets)        . "TCP socket operations — listen, accept, connect")
    ((scm net websocket)      . "WebSocket client and server support")
    ((scm net-remote)         . "Remote operations — curl, wget, ssh, scp, rsync")
    ((scm odf spreadsheet)     . "ODF spreadsheet creation (ODS format)")
    ((scm odf writer)          . "ODF text document creation (ODT format)")
    ((scm ooxml excel)        . "Excel workbook and worksheet creation (OOXML/XLSX format)")
    ((scm ooxml excel-reader) . "Excel workbook reading (OOXML/XLSX format)")
    ((scm ooxml word)          . "Word document creation (OOXML/DOCX format)")
    ((scm ooxml word-reader)  . "Word document text reading (OOXML/DOCX format)")
    ((scm pdf)                . "PDF document creation — pages, drawing, fonts, text flow, TTF embedding, images, links, outlines")
    ((scm png)                . "PNG image writing — grayscale, RGB, and RGBA")
    ((scm profiling)          . "Execution profiling and performance measurement")
    ((scm qr)                 . "QR code encoding — PNG, SVG, and ASCII output")
    ((scm random access)      . "Random-access file I/O — seek, read, write, truncate")
    ((scm repl)               . "REPL support — completions, syntax info, core form names")
    ((scm store)              . "Immutable on-disk indexed record store")
    ((scm string)             . "Extended string operations — search, split, trim, convert")
    ((scm sysadmin)           . "System administration toolkit aggregating fs, archive, remote, logging, and more")
    ((scm system)             . "System info, environment variables, process execution")
    ((scm templating)         . "Text templating with variable substitution")
    ((scm terminal)           . "Terminal control — colors, cursor, raw mode")
    ((scm test)               . "Test framework — SRFI-64 runner with summary reporting")
    ((scm text)               . "Text processing utilities — awk, sed, grep, cut, sort, diff, and more")
    ((scm toml)               . "TOML reading and writing")
    ((scm uri)                . "URI percent-encoding and decoding")
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
    ((srfi 64)  . "SRFI-64 — A Scheme API for test suites")
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

;;; ── Per-library preambles ────────────────────────────────────────────────────
;;; Optional hand-written Markdown intros, one per library, in
;;; documentation/preambles/<id>.md. Injected (verbatim into .md, rendered via
;;; (scm markdown) into HTML, walked into the docx). Missing files are fine.

(define preambles-dir (join-path base-dir "documentation" "preambles"))

(define (file->string path)
  (let ((p (open-input-file path)) (out (open-output-string)))
    (let loop ()
      (let ((c (read-char p)))
        (if (eof-object? c)
            (begin (close-input-port p) (get-output-string out))
            (begin (write-char c out) (loop)))))))

(define (read-preamble id)
  ;; Returns the preamble Markdown string for library id, or #f if none.
  (let ((path (join-path preambles-dir (string-append id ".md"))))
    (if (file-exists? path) (file->string path) #f)))

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
    (let ((preamble (read-preamble id)))
      (when preamble
        (display "    <div class=\"lib-preamble\">\n" port)
        (display (markdown->html preamble) port)
        (display "\n    </div>\n" port)))
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
    (display "<link rel=\"stylesheet\" href=\"assets/style.css\">\n" port)
    (display "</head>\n<body>\n\n" port)

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
         (let ((preamble (read-preamble id)))
           (when preamble
             (display preamble port)
             (display "\n\n" port)))
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

;;; Walk a (scm markdown) AST into the docx, used for library preambles.
;;; Preamble headings are rendered as bold paragraphs (not Word headings) so
;;; they do not pollute the document's heading structure / table of contents.

(define (docx-run! p text bold? italic? mono?)
  (let ((rs (make-run-style)))
    (rs 'set-font-size 9)
    (when bold? (rs 'set-bold #t))
    (when italic? (rs 'set-italic #t))
    (when mono? (rs 'set-font-name "Courier New"))
    (paragraph-add-styled-run! p text rs)))

(define (docx-inlines! p nodes bold? italic?)
  (for-each (lambda (node) (docx-inline! p node bold? italic?)) nodes))

(define (docx-inline! p node bold? italic?)
  (cond
    ((string? node) (docx-run! p node bold? italic? #f))
    ((pair? node)
     (case (car node)
       ((strong) (docx-inlines! p (cdr node) #t italic?))
       ((emph)   (docx-inlines! p (cdr node) bold? #t))
       ((code)   (docx-run! p (cadr node) bold? italic? #t))
       ((link)
        (docx-inlines! p (cadr node) bold? italic?)
        (docx-run! p (string-append " (" (caddr node) ")") bold? #t #f))
       (else #f)))))

(define (docx-block! wdoc node)
  (case (car node)
    ((heading)
     (let ((p (document-add-paragraph! wdoc)))
       (paragraph-set-spacing! p 4 2)
       (docx-inlines! p (cddr node) #t #f)))
    ((paragraph)
     (let ((p (document-add-paragraph! wdoc)))
       (paragraph-set-spacing! p 0 4)
       (docx-inlines! p (cdr node) #f #f)))
    ((code-block)
     (for-each
      (lambda (line)
        (let ((p (document-add-paragraph! wdoc)))
          (paragraph-set-indent! p 18)
          (paragraph-set-spacing! p 0 0)
          (docx-run! p line #f #f #t)))
      (string-split (caddr node) "\n")))
    ((bullet-list)
     (for-each
      (lambda (it)
        (let ((p (document-add-paragraph! wdoc)))
          (paragraph-set-indent! p 18)
          (paragraph-set-spacing! p 0 1)
          (docx-run! p "• " #f #f #f)
          (docx-inlines! p (cdr it) #f #f)))
      (cdr node)))
    ((ordered-list)
     (let loop ((items (cddr node)) (i (cadr node)))
       (unless (null? items)
         (let ((p (document-add-paragraph! wdoc)))
           (paragraph-set-indent! p 18)
           (paragraph-set-spacing! p 0 1)
           (docx-run! p (string-append (number->string i) ". ") #f #f #f)
           (docx-inlines! p (cdr (car items)) #f #f))
         (loop (cdr items) (+ i 1)))))
    ((blockquote)
     (for-each
      (lambda (b)
        (if (eq? (car b) 'paragraph)
            (let ((p (document-add-paragraph! wdoc)))
              (paragraph-set-indent! p 24)
              (paragraph-set-spacing! p 0 2)
              (docx-inlines! p (cdr b) #f #t))
            (docx-block! wdoc b)))
      (cdr node)))
    ((thematic-break)
     (let ((p (document-add-paragraph! wdoc)))
       (paragraph-add-styled-run! p "———" (make-run-style))))
    (else #f)))

(define (emit-docx-preamble wdoc markdown-text)
  (for-each (lambda (b) (docx-block! wdoc b)) (parse-markdown markdown-text)))

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
    ;; Optional hand-written preamble
    (let ((preamble (read-preamble id)))
      (when preamble (emit-docx-preamble wdoc preamble)))
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

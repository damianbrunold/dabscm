# Scm Library Reference

## R7RS Standard Libraries

| Library | Description |
|---------|-------------|
| [`(scheme base)`](libraries/scheme-base.md) | R7RS base library — core forms and procedures |
| [`(scheme case-lambda)`](libraries/scheme-case-lambda.md) | Case-lambda for multi-arity procedures |
| [`(scheme char)`](libraries/scheme-char.md) | Character classification and case operations |
| [`(scheme complex)`](libraries/scheme-complex.md) | Complex number arithmetic |
| [`(scheme cxr)`](libraries/scheme-cxr.md) | Compositions of car and cdr up to 4 levels deep |
| [`(scheme eval)`](libraries/scheme-eval.md) | Evaluation of Scheme expressions |
| [`(scheme file)`](libraries/scheme-file.md) | File-based port operations |
| [`(scheme inexact)`](libraries/scheme-inexact.md) | Inexact number operations and trigonometry |
| [`(scheme lazy)`](libraries/scheme-lazy.md) | Lazy evaluation and promises |
| [`(scheme load)`](libraries/scheme-load.md) | Loading Scheme source files |
| [`(scheme process-context)`](libraries/scheme-process-context.md) | Process exit and context |
| [`(scheme r5rs)`](libraries/scheme-r5rs.md) | Full R5RS compatibility library |
| [`(scheme read)`](libraries/scheme-read.md) | Reading Scheme data from ports |
| [`(scheme repl)`](libraries/scheme-repl.md) | REPL environment access |
| [`(scheme time)`](libraries/scheme-time.md) | Timestamps and time formatting |
| [`(scheme write)`](libraries/scheme-write.md) | Writing and displaying values to ports |

## SRFI Libraries

| Library | Description |
|---------|-------------|
| [`(srfi 1)`](libraries/srfi-1.md) | SRFI-1 — List library: fold, any, every, take, drop, iota, lset ops |
| [`(srfi 2)`](libraries/srfi-2.md) | SRFI-2 — and-let*: short-circuiting let |
| [`(srfi 8)`](libraries/srfi-8.md) | SRFI-8 — receive: binding multiple values |
| [`(srfi 9)`](libraries/srfi-9.md) | SRFI-9 — Record types (re-export from scheme base) |
| [`(srfi 13)`](libraries/srfi-13.md) | SRFI-13 — String library: predicate-based string operations |
| [`(srfi 14)`](libraries/srfi-14.md) | SRFI-14 — Character sets: predicate-wrapped char-set type |
| [`(srfi 18)`](libraries/srfi-18.md) | SRFI-18 — Multithreading: threads, mutexes, condition variables |
| [`(srfi 19)`](libraries/srfi-19.md) | SRFI-19 — Time data types and procedures: time, date, Julian Day, formatting |
| [`(srfi 26)`](libraries/srfi-26.md) | SRFI-26 — cut/cute: partial application via slot notation |
| [`(srfi 28)`](libraries/srfi-28.md) | SRFI-28 — Basic format strings |
| [`(srfi 39)`](libraries/srfi-39.md) | SRFI-39 — Parameter objects (re-export from scheme base) |
| [`(srfi 48)`](libraries/srfi-48.md) | SRFI-48 — Intermediate format strings: display, write, numeric bases, pretty-print |
| [`(srfi 64)`](libraries/srfi-64.md) |  |
| [`(srfi 69)`](libraries/srfi-69.md) | SRFI-69 — Basic hash tables with eq?/eqv?/equal? support |
| [`(srfi 95)`](libraries/srfi-95.md) | SRFI-95 — Sorting and merging: polymorphic sort, merge with optional key |
| [`(srfi 98)`](libraries/srfi-98.md) | SRFI-98 — Environment variables |
| [`(srfi 111)`](libraries/srfi-111.md) | SRFI-111 — Boxes: mutable single-value containers |
| [`(srfi 125)`](libraries/srfi-125.md) | SRFI-125 — Intermediate hash tables: comparator-based hash tables with mapping, folding, and set operations |
| [`(srfi 128)`](libraries/srfi-128.md) | SRFI-128 — Comparators: bundled type-test, equality, ordering, and hash procedures |
| [`(srfi 132)`](libraries/srfi-132.md) | SRFI-132 — Sort libraries: list/vector sort, merge, select, median |
| [`(srfi 133)`](libraries/srfi-133.md) | SRFI-133 — Vector libraries |
| [`(srfi 151)`](libraries/srfi-151.md) | SRFI-151 — Bitwise operations: logic, shifts, fields, and folds on exact integers |
| [`(srfi 158)`](libraries/srfi-158.md) | SRFI-158 — Generators and accumulators: lazy sequences, composable pipelines, and value collectors |

## Scm Extension Libraries

| Library | Description |
|---------|-------------|
| [`(scm archive)`](libraries/scm-archive.md) |  |
| [`(scm compile)`](libraries/scm-compile.md) | Compiler introspection, bytecode access, and type predicates |
| [`(scm compression)`](libraries/scm-compression.md) | Data compression and decompression |
| [`(scm crypto)`](libraries/scm-crypto.md) | Cryptographic hashing and encoding utilities |
| [`(scm csv)`](libraries/scm-csv.md) | CSV parsing |
| [`(scm database migrations)`](libraries/scm-database-migrations.md) |  |
| [`(scm database postgres)`](libraries/scm-database-postgres.md) | PostgreSQL database connectivity |
| [`(scm database sqlserver)`](libraries/scm-database-sqlserver.md) | SQL Server database connectivity |
| [`(scm datetime)`](libraries/scm-datetime.md) | Date and time operations |
| [`(scm dict)`](libraries/scm-dict.md) | Dictionary / associative map operations |
| [`(scm doc)`](libraries/scm-doc.md) | Documentation access |
| [`(scm duration)`](libraries/scm-duration.md) |  |
| [`(scm feed)`](libraries/scm-feed.md) |  |
| [`(scm fs-find)`](libraries/scm-fs-find.md) |  |
| [`(scm fs)`](libraries/scm-fs.md) | Filesystem operations — paths, directories, files |
| [`(scm glob)`](libraries/scm-glob.md) | Filename globbing and pattern matching |
| [`(scm html builder)`](libraries/scm-html-builder.md) |  |
| [`(scm html)`](libraries/scm-html.md) |  |
| [`(scm io)`](libraries/scm-io.md) | Extended I/O — formatting, port utilities, property lists |
| [`(scm json)`](libraries/scm-json.md) | JSON file reading |
| [`(scm list)`](libraries/scm-list.md) | Extended list operations — higher-order, sorting, accessors |
| [`(scm log)`](libraries/scm-log.md) |  |
| [`(scm macro)`](libraries/scm-macro.md) | Non-standard macros and meta-programming utilities |
| [`(scm match)`](libraries/scm-match.md) | Pattern matching |
| [`(scm math)`](libraries/scm-math.md) | Math constants and non-standard numeric operations |
| [`(scm module)`](libraries/scm-module.md) | Module system — import, export, search paths, introspection |
| [`(scm net http client)`](libraries/scm-net-http-client.md) | HTTP client — GET, POST, and other request methods |
| [`(scm net http cookies)`](libraries/scm-net-http-cookies.md) |  |
| [`(scm net http forms)`](libraries/scm-net-http-forms.md) |  |
| [`(scm net http multipart)`](libraries/scm-net-http-multipart.md) |  |
| [`(scm net http request)`](libraries/scm-net-http-request.md) | HTTP request construction and accessors |
| [`(scm net http response)`](libraries/scm-net-http-response.md) | HTTP response construction and accessors |
| [`(scm net http route)`](libraries/scm-net-http-route.md) | HTTP request routing for servers |
| [`(scm net http server)`](libraries/scm-net-http-server.md) | HTTP server — listen, accept, and serve requests |
| [`(scm net-remote)`](libraries/scm-net-remote.md) |  |
| [`(scm net sockets)`](libraries/scm-net-sockets.md) | TCP socket operations — listen, accept, connect |
| [`(scm net websocket)`](libraries/scm-net-websocket.md) | WebSocket client and server support |
| [`(scm odf spreadsheet)`](libraries/scm-odf-spreadsheet.md) | ODF spreadsheet creation (ODS format) |
| [`(scm odf writer)`](libraries/scm-odf-writer.md) | ODF text document creation (ODT format) |
| [`(scm ooxml excel)`](libraries/scm-ooxml-excel.md) | Excel workbook and worksheet creation (OOXML/XLSX format) |
| [`(scm ooxml word)`](libraries/scm-ooxml-word.md) | Word document creation (OOXML/DOCX format) |
| [`(scm pdf)`](libraries/scm-pdf.md) |  |
| [`(scm png)`](libraries/scm-png.md) |  |
| [`(scm profiling)`](libraries/scm-profiling.md) | Execution profiling and performance measurement |
| [`(scm qr)`](libraries/scm-qr.md) |  |
| [`(scm repl)`](libraries/scm-repl.md) |  |
| [`(scm string)`](libraries/scm-string.md) | Extended string operations — search, split, trim, convert |
| [`(scm sysadmin)`](libraries/scm-sysadmin.md) |  |
| [`(scm system)`](libraries/scm-system.md) | System info, environment variables, process execution |
| [`(scm templating)`](libraries/scm-templating.md) | Text templating with variable substitution |
| [`(scm terminal)`](libraries/scm-terminal.md) | Terminal control — colors, cursor, raw mode |
| [`(scm test)`](libraries/scm-test.md) |  |
| [`(scm text)`](libraries/scm-text.md) |  |
| [`(scm uri)`](libraries/scm-uri.md) |  |
| [`(scm xml)`](libraries/scm-xml.md) | XML file reading and navigation |
| [`(scm zip)`](libraries/scm-zip.md) | ZIP archive creation and entry writing |

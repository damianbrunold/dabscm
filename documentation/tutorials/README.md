# dabscm tutorials

Tutorials for learning Scheme with dabscm and for getting things done with
its libraries. They complement the [library reference](../index.md): the
reference lists every procedure, the tutorials show how to put them
together, with worked examples.

Every tested example in these tutorials is run by dabscm's test suites, on
the JVM, .NET and native implementations, so the code works as shown.

## Where to start

- **New to Scheme?** Read the [basics](#basics) in order. Each chapter
  builds on the previous one.
- **Know Scheme, new to dabscm?** Skim [getting started](basics-01-getting-started.md),
  then go to the [techniques](#techniques) you need.
- **Looking for a specific task?** See [find by task](#find-by-task) below.

## Basics

1. [Getting started](basics-01-getting-started.md): scripts, the REPL, one-liners, `scm fmt`/`scm lint`, native executables
2. [Expressions and values](basics-02-values.md): numbers, booleans, symbols, strings, `display` versus `write`, equality
3. [Definitions and procedures](basics-03-procedures.md): `define`, `lambda`, `let`, optional arguments, closures
4. [Pairs and lists](basics-04-lists.md): building lists, `map`/`filter`/`fold`, association lists, quasiquote
5. [Control flow and recursion](basics-05-control.md): `cond`, `case`, named `let`, tail calls, `do`
6. [Vectors, bytevectors and other data](basics-06-data.md): indexed and binary data, choosing a structure
7. [Higher-order programming](basics-07-higher-order.md): closures, composition, `cut`, memoization
8. [Records](basics-08-records.md): `define-record-type`, collections of records, multiple values
9. [Errors and exceptions](basics-09-errors.md): `error`, `guard`, `raise`, `dynamic-wind`
10. [Libraries and programs](basics-10-libraries.md): `import`, `define-library`, project layout
11. [Macros and pattern matching](basics-11-macros.md): `syntax-rules`, `match`, a small interpreter
12. [Continuations, generators and laziness](basics-12-continuations.md): `call/cc`, SRFI 158 generators, streams

## Techniques

1. [Strings and text](techniques-01-strings.md): searching, splitting, padding, regular expressions, formatting, templates
2. [Characters and Unicode](techniques-02-characters.md): character classes, case, character sets, UTF-8
3. [Files and directories](techniques-03-files.md): reading and writing, encodings, paths, globbing, finding files
4. [Hash tables and dictionaries](techniques-04-hash-tables.md): key equality, counting, grouping, SRFI 69 and 125
5. [Sorting and searching](techniques-05-sorting.md): sorting by keys and several criteria, binary search, median
6. [Iteration patterns](techniques-06-iteration.md): choosing the loop construct, folds, windows, generator pipelines
7. [Dates and times](techniques-07-dates.md): ISO timestamps, date arithmetic, weekdays, durations
8. [Structured data](techniques-08-structured-data.md): JSON, XML, TOML, CSV
9. [Command-line programs](techniques-09-command-line.md): options, help, exit codes, colors, logging
10. [Testing your code](techniques-10-testing.md): `(scm test)`, test layout, all three implementations
11. [Concurrency](techniques-11-concurrency.md): threads, mutexes, a work queue, errors in threads
12. [The system](techniques-12-system.md): running programs, environment, platform

## Find by task

| task | tutorial |
|---|---|
| run a script, try code in the REPL | [Getting started](basics-01-getting-started.md) |
| build a standalone executable | [Getting started](basics-01-getting-started.md#native-executables) |
| compute exactly with fractions or big numbers | [Expressions and values](basics-02-values.md#numbers) |
| split a string, trim it, pad it | [Strings](techniques-01-strings.md#splitting-and-joining) |
| match or replace with a regular expression | [Strings](techniques-01-strings.md#regular-expressions) |
| format numbers with fixed decimals, print a table | [Strings](techniques-01-strings.md#formatting-values) |
| compare text ignoring case, remove accents | [Characters](techniques-02-characters.md#case) |
| read a file line by line, or all at once | [Files](techniques-03-files.md#reading-a-text-file) |
| write a file in Latin-1 or append to it | [Files](techniques-03-files.md#appending-and-encodings) |
| read or write binary data | [Files](techniques-03-files.md#binary-files) |
| find files by name in a directory tree | [Files](techniques-03-files.md#globbing-and-finding-files) |
| count or group things | [Hash tables](techniques-04-hash-tables.md#counting-and-grouping) |
| use strings as keys ignoring case | [Hash tables](techniques-04-hash-tables.md#case-insensitive-keys) |
| sort records by several fields | [Sorting](techniques-05-sorting.md#several-criteria) |
| loop over two lists at once, number elements | [Iteration](techniques-06-iteration.md#several-sequences-at-once) |
| parse an ISO 8601 timestamp, add days to a date | [Dates and times](techniques-07-dates.md) |
| parse or produce JSON | [Structured data](techniques-08-structured-data.md#json) |
| read a configuration file | [Structured data](techniques-08-structured-data.md#toml) |
| read a CSV file | [Structured data](techniques-08-structured-data.md#csv) |
| parse command-line options | [Command-line programs](techniques-09-command-line.md) |
| test my code | [Testing](techniques-10-testing.md) |
| use several cores | [Concurrency](techniques-11-concurrency.md) |
| run an external program and capture its output | [The system](techniques-12-system.md#running-a-program) |
| write a small web server or JSON API | [HTTP servers](scm-http-server.md#example-a-json-api) |
| call a web API | [HTTP client](scm-http-client.md) |
| add a login to a web app | [Web applications](scm-web-app.md#example-tasting-notes-with-a-login) |
| accept file uploads | [Web applications](scm-web-app.md#uploads) |
| send an e-mail | [E-mail](scm-email.md) |
| query PostgreSQL safely | [Databases](scm-database.md#parameters) |
| start a new web application | [Scaffold](scm-scaffold.md) |
| filter, group and summarise a table | [Data frames](scm-data.md#groups-group-by-and-summarise) |
| join two tables, pivot wide or long | [Joining and reshaping](scm-data-reshape.md) |
| compare two groups statistically | [Hypothesis tests](scm-data-tests.md#two-groups) |
| draw a bar chart or a map | [Charts and maps](scm-data-plot.md) |
| write a report with tables and charts as PDF | [Reports](scm-data-report.md) |
| handle an error and continue | [Errors and exceptions](basics-09-errors.md#catching-errors-with-guard) |
| destructure data with patterns | [Macros and pattern matching](basics-11-macros.md#pattern-matching-with-match) |
| write my own control construct | [Macros](basics-11-macros.md) |

## Library tutorials

Guided tours of the individual libraries, each with worked examples.

### SRFIs

| tutorial | covers |
|---|---|
| [SRFI 1: lists](srfi-1.md) | constructing, selecting, folding, searching, alists, lists as sets |
| [SRFI 2, 8 and 26](srfi-26.md) | `and-let*`, `receive`, `cut` and `cute` |
| [SRFI 9, 39, 98 and 111](srfi-111.md) | boxes, parameters, environment variables, records |
| [SRFI 13: strings](srfi-13.md) | searching, trimming, padding, folding, a word wrapper |
| [SRFI 14: character sets](srfi-14.md) | building sets, set algebra, a password-strength check |
| [SRFI 18: threads](srfi-18.md) | threads, mutexes, condition variables, timeouts, a bounded buffer |
| [SRFI 19: time and dates](srfi-19.md) | times, durations, dates, formatting and parsing, time zones |
| [SRFI 27 and 194: random numbers](srfi-27.md) | random sources, reproducibility, distributions, shuffling |
| [SRFI 28 and 48: format](srfi-48.md) | format strings, numbers, widths, a receipt |
| [SRFI 64: unit tests](srfi-64.md) | assertions, groups, expected failures, custom runners |
| [SRFI 69: hash tables](srfi-69.md) | the whole API, an inverted index |
| [SRFI 125 and 128](srfi-125.md) | comparators, comparator-based hash tables, set operations |
| [SRFI 132 and 95: sorting](srfi-132.md) | stable sorting, merging, order statistics, a leaderboard |
| [SRFI 133: vectors](srfi-133.md) | vector operations, a moving average, the game of life |
| [SRFI 151: bitwise operations](srfi-151.md) | bits, bit fields, permission flags, packed colors |
| [SRFI 158: generators](srfi-158.md) | generators and accumulators, a streaming log analysis |
| [SRFI 271: random ports](srfi-271.md) | secure random bytes, tokens, UUIDs, reproducible streams |

### Core dabscm libraries

| tutorial | covers |
|---|---|
| [`(scm string)`](scm-string.md) | regular expressions, searching and replacing with groups, splitting |
| [`(scm list)` and `(scm macro)`](scm-list.md) | property lists, neighbouring duplicates, pretty-printing |
| [`(scm match)`](scm-match.md) | pattern matching, destructuring data, a symbolic differentiator |
| [`(scm io)`](scm-io.md) | string ports, whole-file reading, reading untrusted data |
| [`(scm text)`](scm-text.md) | grep, sed, awk, sort, uniq, wc, diff and hexdump in Scheme |
| [`(scm templating)` and `(scm uri)`](scm-templating.md) | templates with loops and includes, percent-encoding |
| [`(scm args)`](scm-args.md) | command-line options, types, help, errors |
| [`(scm terminal)` and `(scm log)`](scm-terminal.md) | colors, display width, raw keys, logging |
| [`(scm fs)`, `(scm fs-find)`, `(scm glob)`](scm-fs.md) | paths, directories, finding files, globs, backup rotation |
| [`(scm system)` and `(scm sysadmin)`](scm-system.md) | running programs, platform, parallel maps, scripting |
| [`(scm archive)`, `(scm zip)`, `(scm compression)`](scm-archive.md) | gzip, ZIP and tar archives, compressing bytevectors |
| [`(scm store)`](scm-store.md) | an indexed on-disk record store |
| [`(scm crypto)`](scm-crypto.md) | hashes, HMAC, encryption, passwords, signed tokens |
| [`(scm datetime)` and `(scm duration)`](scm-datetime.md) | parsing and formatting timestamps, durations |

### Formats

| tutorial | covers |
|---|---|
| [`(scm json simple)` and `(scm json)`](scm-json.md) | JSON mapping, lookups, writing, API responses, streaming large files |
| [`(scm xml)` and `(scm feed)`](scm-xml.md) | the XML pull reader, records from streams, namespaces, Atom and RSS feeds |
| [`(scm toml)`](scm-toml.md) | configuration files, defaults, validation, layered settings |
| `(scm csv)` | see [structured data](techniques-08-structured-data.md#csv) |
| [`(scm markdown)`](scm-markdown.md) | Markdown to HTML, the tree, custom renderers, tables of contents |
| [`(scm html)`, builder and parser](scm-html.md) | safe HTML from trees, components, parsing and scraping pages |
| [Excel and OpenDocument spreadsheets](scm-excel.md) | `.xlsx` writing, streaming, reading, templates; `.ods` |
| [Word and OpenDocument texts](scm-word.md) | `.docx` documents and letters, reading Word files; `.odt` |
| [`(scm ooxml presentation)`](scm-presentation.md) | PowerPoint slides with shapes, tables, pictures, notes |
| [`(scm pdf)` and `(scm svg pdf)`](scm-pdf.md) | PDF pages, text, wrapping, an invoice, SVG as vectors |
| [Images, QR codes, SVG](scm-images.md) | PNG and JPEG, thumbnails, drawing, QR codes, SVG to PNG |

### Web, network and databases

| tutorial | covers |
|---|---|
| [HTTP servers and routing](scm-http-server.md) | handlers, responses, routes, a JSON API, streaming, production |
| [`(scm net http client)`](scm-http-client.md) | requests, JSON APIs, tokens, binary bodies, redirects, errors, retries |
| [Web applications](scm-web-app.md) | forms, passwords, sessions, a login app, middleware, static files, uploads |
| [Sockets and WebSockets](scm-websocket.md) | a TCP line protocol, binary framing, TLS, a WebSocket chat room |
| [E-mail](scm-email.md) | messages, Cc and Bcc, a local mail catcher, sending one or many |
| [SQL databases](scm-database.md) | PostgreSQL and SQL Server, parameters, transactions, pools, migrations |
| [`(scm scaffold)`](scm-scaffold.md) | the starter applications and `scm new-app` |
| [`(scm net-remote)`](scm-net-remote.md) | ssh, scp, rsync, curl, wget; a deployment script |

### Data analysis

| tutorial | covers |
|---|---|
| [Data frames and verbs](scm-data.md) | frames, CSV, missing values, where/mutate/summarise, expressions, dates |
| [Joining and reshaping](scm-data-reshape.md) | joins, stacking, pivots, list columns, window functions, own functions |
| [Statistics and formatting](scm-data-stats.md) | centre and spread, correlation, frequency tables, number formats |
| [Hypothesis tests](scm-data-tests.md) | t-test, Wilcoxon, proportions, tables, correlation, p-adjust, `lm` |
| [Reading and writing data](scm-data-io.md) | CSV, Excel, JSON, Scheme data, SQL results, geometries |
| [Charts and maps](scm-data-plot.md) | ggplot-style charts, SVG/PNG/PDF, choropleth maps |
| [Reports](scm-data-report.md) | reports as data to HTML, Markdown and PDF |
| [Clustering](scm-data-cluster.md) | similarity, Louvain communities, hierarchical clustering, k-means |
| [R translation](scm-data-r.md) | tidyverse R to `(scm data)` and back |

Tutorials for the remaining libraries follow. Until then, the
[library reference](../index.md) has an overview and examples for every
library.

## Running the examples yourself

Copy a code block into a file, keep the `import` from the chapter's first
block, and run it with `scm file.scm`. Lines ending in `;; => value` show
what an expression returns; `;; prints:` shows what it writes.

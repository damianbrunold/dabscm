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
| handle an error and continue | [Errors and exceptions](basics-09-errors.md#catching-errors-with-guard) |
| destructure data with patterns | [Macros and pattern matching](basics-11-macros.md#pattern-matching-with-match) |
| write my own control construct | [Macros](basics-11-macros.md) |

## Library tutorials

Tutorials for the individual SRFIs and dabscm libraries follow; until then,
the techniques above cover the most-used ones, and the
[library reference](../index.md) has an overview and examples for every
library.

## Running the examples yourself

Copy a code block into a file, keep the `import` from the chapter's first
block, and run it with `scm file.scm`. Lines ending in `;; => value` show
what an expression returns; `;; prints:` shows what it writes.

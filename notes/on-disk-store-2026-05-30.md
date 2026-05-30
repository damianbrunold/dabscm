# On-disk indexed store + random-access file I/O (2026-05-30)

Adds two layers so dabscm can replace a Python+SQLite "compute results, then
query them quickly on a server" workflow without external dependencies, using
only .NET 8 and Java 11 built-ins.

## Layer 1 — `(scm random access)` (native primitives)

dabscm's existing binary ports (`BinaryInputStream`/`BinaryOutputStream`) are
sequential streams: C# buffers a `FileStream`, Java buffers a non-seekable
`InputStream`. There was no byte-offset seek, so no random-access reads.

New native handle `RandomAccessFileHandle`:
- C#  — wraps a seekable `FileStream` (`Seek` + `Read`/`Write`).
- Java — wraps `java.io.RandomAccessFile` (`seek` + `read`/`write`).

Exposed primitives (positioned / offset-explicit, stateless per call — no
shared cursor, so the same handle serves arbitrary random access):

| primitive | meaning |
|---|---|
| `(open-random-access-file filename mode)` | mode = `read` \| `write` (create/truncate) \| `update` (create, keep) |
| `(close-random-access-file f)` | |
| `(random-access-file? obj)` | predicate |
| `(random-access-file-read f offset count)` | → bytevector (shorter/empty at EOF) |
| `(random-access-file-write! f offset bv [start [end]])` | → bytes written; extends file |
| `(random-access-file-size f)` | |
| `(random-access-file-truncate! f size)` | |
| `(random-access-file-flush f)` | fsync |
| `(call-with-random-access-file filename mode proc)` | open + dynamic-wind close |

C# files: `RandomAccessFileHandle.cs`, `primitives/PrimitiveRandomAccessFile*.cs`,
`primitives/PrimitiveOpenRandomAccessFile.cs`, `primitives/PrimitiveCloseRandomAccessFile.cs`,
bound in `Primitives.cs`. Java mirror under `scm-java/src/main/scheme/`.

## Layer 2 — `(scm store)` (pure Scheme, single source, both impls)

A small **immutable** on-disk indexed record store — not SQLite-compatible and
not a SQL engine; a focused document store matched to the actual query shapes
(equality, set-membership, distinct, paginated key listing, fetch-by-key).

A record has: a dense integer key (0,1,2,… in insertion order), an opaque
**payload** (any Scheme datum, serialised with `write`/`read`), and indexed
fields of two kinds:
- **scalar** — one value per record → equality + distinct
- **multi**  — a set of values per record → set membership

### Write (batch) — indexes built in memory, then flushed
```scheme
(define w (store-writer-open "r.store" '(burnr splg) '(quer errors)))
(store-writer-add! w payload-datum
  '((burnr . "100") (splg . "A1") (quer . ("x" "y")) (errors . ())))
(store-writer-close w)   ; writes primary index, field indexes, footer; fsync
```
Payloads stream straight to disk on each `add!`. Only small
`value → rowid-list` tables are held in memory during the write (one hash-table
per field), exactly as the SQLite version held index-build state. **The write
side is the only place that holds index state in memory**; for very large
inputs this is the place to add an external merge sort later (the per-field
`write-field-index!` is the seam).

### Read (per request) — fully random-access, never loads the dataset
```scheme
(define s (store-open "r.store"))          ; reads only the small footer
(store-count s)                            ; total
(store-ref s 0)                            ; payload by key — one seek+read
(store-field-values s 'splg)               ; distinct sorted values (dropdowns)
(store-query s '((eq splg "A1") (in quer ("x" "y"))))  ; → sorted key list
(store-count-matching s clauses)           ; COUNT(*)
(store-page s clauses offset limit)        ; ORDER BY key LIMIT/OFFSET
(store-page-records s clauses offset limit) ; → ((rowid . payload) ...)
(store-close s)
```
Clauses: `(eq field value)`, `(in field (value ...))`, `(present field)`,
AND-combined. Each clause resolves to a sorted rowid list by **on-disk binary
search** of the field's value table + reading that value's sorted postings;
clauses combine by sorted-list intersection. Only the matched values' integer
postings are read (never payloads); only the page's payloads are fetched. The
unfiltered page is generated directly without materialising all keys.

### File layout (all integers little-endian)
```
header  16B : magic "SCMSTOR1" (8) + footer-offset u64 (8, backpatched at close)
data        : concatenated payload bytes
primary idx : per key — u64 payload-offset + u32 payload-len  (12B, key*12)
field idx   : per field — postings, then value blob, then value table
                postings(value) : u32 count + count*u32 rowids (sorted)
                value table[i]  : u64 val-off, u32 val-len, u64 postings-off
                                  (20B, sorted by value → binary searchable)
footer      : magic, version, count, primary-base, field directory
```

## Mapping the SPLG use case (`writer_splg.py` `WriterSPLGSqlite`)
- `cases` table + `raw` JSON  → store payload (the per-case datum)
- scalar columns burnr/plz/standort/splg/falltyp → `store-writer-open` scalar fields
- child tables case_quer/case_mfzs/case_errors/… → multi fields
- controller listing `… WHERE … ORDER BY rowid LIMIT/OFFSET` → `store-page`
- `COUNT(*)` → `store-count-matching`
- `rowid IN (SELECT case_rowid FROM case_quer WHERE splg IN (…))` → `(in quer (…))`
- "has errors" → `(present errors)`
- `SELECT DISTINCT col` dropdowns → `store-field-values`
- detail by rowid → `store-ref`

## Tests
`scm-tests/tests/tests_store.scm` — random-access primitives + store writer/reader,
queries, pagination, and a 500-record set exercising binary search and multi-byte
offsets. 39 assertions, passing on C# and Java (full suite: 5619 tests, 0 failures).

## Not done / future
- SQLite-format reader (so external tools can read the output) — explicitly
  deferred; current output is an internal cache format.
- External-sort index build for inputs too large to hold field tables in RAM.
- Chunked posting cursors (currently a queried value's full postings list is
  read into memory; fine because it is integer ids for filtered values only,
  not payloads).

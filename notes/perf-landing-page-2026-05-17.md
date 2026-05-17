# Landing page perf investigation (2026-05-17)

Measured dabsite's `/` endpoint with `bin/load-test.scm` (100 requests, 4
threads, ~30-170 ms random pause between requests) against postgres on
localhost.

## Result

| | p50 | mean | throughput |
|---|---:|---:|---:|
| Baseline | 156 ms | 169 ms | 14.8 req/s |
| + connection pool | 61 ms | 95 ms | 19.8 req/s |
| + TCP_NODELAY | **16 ms** | 28 ms | **28.9 req/s** |

About **10× faster** end-to-end. No application-level changes.

## What was wrong

1. **Every request opened a fresh postgres connection.** `with-db`
   called `with-pg-connection`, which called `pg-connect`, which did a
   TCP handshake plus SCRAM-SHA-256 (server-side PBKDF2 is intentionally
   slow). Cost: ~97 ms per request.
2. **TCP_NODELAY was off on every socket scm opened.** With Nagle's
   algorithm on the sending side and delayed-ACK on the postgres side,
   small back-and-forth RPC traffic stalls for ~40 ms per query. Cost:
   ~40 ms per query.

`psql` saw the same SELECT at 0.2 ms; scm saw it at 44 ms. The
difference was entirely Nagle/delayed-ACK.

## What we did

1. Added a connection pool to `(scm database postgres)`:
   `make-pg-pool`, `pg-pool-checkout`, `pg-pool-checkin`,
   `with-pg-pool-connection`, `pg-pool-close-all!`. SRFI 18 mutex +
   condition variable for synchronization. Lazy connection creation
   up to capacity; `(mutex-unlock! mutex cv)` for waiting when at
   capacity. Connections are closed (not pooled) on exception.
2. Wired `(dabsite db)` to construct a pool inside `make-db-config`
   (optional 6th arg = capacity, default 8) and route `with-db`
   through `with-pg-pool-connection`.
3. Set `TCP_NODELAY` (C# `client.NoDelay = true` / Java
   `client.setTcpNoDelay(true)`) on every `tcp-connect`. Almost every
   TCP client in this runtime is RPC-style; bulk-transfer workloads
   are rare and can be opted back in later if needed.

## Warm-request breakdown after the fixes

| Phase | Avg |
|---|---:|
| Pool checkout | < 0.1 ms |
| `db.wait` (postgres-side) | 0.4 ms |
| `db.read` (decoder) | 2.1 ms |
| Total `db` | 5.0 ms |
| SXML body | 1.3 ms |
| `render-page` shell | 4.2 ms |
| HTTP server overhead | ~5 ms |
| **Wall time per request** | **~16 ms** |

## Open follow-ups, by expected payoff

1. **Compile-time HTML macro.** SXML rendering is now ~35 % of warm
   time. A macro that emits a sequence of `write-string` calls at
   compile time would plausibly cut this from ~5.5 ms to 1-2 ms.
2. **Pre-warm the pool.** Eliminate the cold-start outliers (the
   first 3 requests after server boot still pay ~175 ms each for
   connect). ~5 lines.
3. **Buffered binary input port.** The decoder's `read-u8`-per-byte
   header parsing crosses the VM boundary many times per query. A
   `BufferedStream` wrapper around `NetworkStream` (and Java's
   socket InputStream) could shave ~1 ms off `db.read`.
4. **Pool sizing under load.** Capacity 8 was fine for 4-client load
   tests. Real load testing with more concurrent clients should
   confirm 8 (or surface a need to make it configurable per-deploy).
5. **`set!` across threads.** Separate but adjacent: see
   `notes/threading-shared-bindings.md`. The load test pattern
   stumbled into this on day one of the investigation.

## What we didn't touch but should remember

- `(scm database postgres)` uses Simple Query (Q messages). The
  Extended Query protocol (Parse/Bind/Execute) would let postgres
  cache query plans across calls. Worthwhile if any non-trivial
  query becomes the bottleneck.
- pg-query's "fat row" decode path allocates a fresh bytevector and
  string per column. For wide rows or large TEXT columns, batched
  decoding could matter.

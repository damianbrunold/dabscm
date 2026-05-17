# Threading: share bindings across threads instead of cloning

## Status

Proposal. Not implemented.

## The current behaviour

`thread-start!` calls `Modules.DeepClone()` (both C# and Java), which
copies every binding in every module into a fresh dictionary per thread.
This isolates threads but means `set!` on a top-level `define`d
variable in one thread is invisible to every other thread, including
the thread that spawned them.

Reproducer:

```scheme
(import (scheme base) (scheme write) (srfi 18))
(define counter 0)
(define ts
  (map (lambda (i)
         (let ((t (make-thread (lambda () (set! counter (+ counter 1))))))
           (thread-start! t) t))
       '(0 1 2 3)))
(for-each thread-join! ts)
(display counter) (newline)  ;; → 0, not 4
```

The workaround today is to share a mutable vector (whose reference is
captured by the worker closures), which works because vector mutation
doesn't go through the bindings dict. SRFI 18 mutexes can sit on top
of that.

## The minimal fix: indirect every binding through a Cell

Replace `Dictionary<string, object> Bindings` with
`Dictionary<string, Cell>`, where `Cell` is a one-field box.

```csharp
public sealed class Cell { public object value; public Cell(object v) { value = v; } }

// Module.cs
public Dictionary<string, Cell> bindings = new();

public object Resolve(SourcePos? pos, string sym) =>
    bindings.TryGetValue(sym, out var c)
        ? c.value
        : throw new SchemeError(pos, Name + ": ~a is not bound", sym);

public void Bind(string sym, object v, string origin) {
    if (bindings.TryGetValue(sym, out var c)) c.value = v;   // rebind in place
    else bindings[sym] = new Cell(v);
    Provenance[sym] = origin;
}
```

The VM's global-set opcode looks the cell up once and writes
`cell.value`. `set!` from any thread is then immediately visible
elsewhere — a single reference assignment is atomic on both .NET (CLR
guarantees aligned ref writes are atomic) and JVM (JLS 17.7), so there
are no torn objects.

`Modules.DeepClone()` and `Module.Clone()` go away.
`PrimitiveThreadStartB` passes the parent's `Modules` straight to the
new VM.

## Three pieces of state that must become per-thread

These are mutated during execution and would race if shared:

1. **`currentModule`** — written by `(module foo)` and the body of
   `define-library`. Move it from `Modules` onto the `VM`
   (or `SchemeThread`). Each thread already creates its own VM, so
   this is a one-line move.
2. **`loadingModules`** — circular-import detector. Per-thread is
   correct.
3. **SRFI 39 parameters / dynamic-wind state** — must already be
   per-thread; verify they don't accidentally rely on the clone.

## Three pieces that stay shared (with care)

1. **The bindings dict's key set during library load** — append-only
   at boot, read-only at steady state. Two threads importing the same
   library concurrently would race on dict writes. Wrap library load
   in a `lock(module.bindings) { ... }`. Cost is negligible (runs once
   per name).
2. **`BindingTable` and `moduleScopes`** for the macro expander —
   already shared today, no change.
3. **`*modules*` binding** — mutated via `UpdateModuleVar`. Same
   lock-on-load story.

## Imports: design call

`ImportBinding` today copies the *value* into the importer's dict. Two
options with cells:

- **Share the cell** (Racket / CL style): importer's dict stores the
  same `Cell` as the exporter's. `set!` on an exported variable is
  visible through every importer.
- **Snapshot at import time**: importer stores a fresh `Cell`
  initialised to the current value. Later mutations don't propagate.

**Recommendation: share the cell.** Matches "the binding *is* the
cell" semantics, matches the new threading model, and matches most
other Schemes.

## Implementation order

Each step is ~half a day. Run dabscm + dabsite tests after each.

1. Add `Cell`. Switch `Module.bindings` to map to `Cell`. Update
   `Resolve` / `Bind` / `ImportBinding` and the global-set opcode in
   the VM. Same on Java.
2. Move `currentModule` and `loadingModules` to the VM.
3. Drop `DeepClone` from `thread-start!`. Run dabscm tests + dabsite
   tests + `bin/load-test.scm` on both impls.
4. Decide on share-cell vs snapshot for imports (recommendation:
   share). Any test that breaks was relying on accidental isolation.
5. Add a regression test: two threads incrementing a shared counter
   under a mutex; assert the total.

## Risks to flag

- REPL semantics shift slightly: a top-level `(define x …)` in the
  REPL while a background thread is running will be visible to the
  worker. Usually desirable.
- Audit anything that `set!`s a binding from `(scm core)` or another
  shared service library. If a feature was implicitly relying on the
  clone for isolation, it should switch to `make-parameter`.
- Verify `make-parameter` already uses thread-locals; the clone may
  have been masking a misimplementation.

## Why this is worth doing

- Removes O(total bindings across all loaded modules) of copying at
  every `thread-start!`.
- Lets natural patterns work: shared counters, work queues, cached
  lookups, the dabsite feed scheduler writing "last poll" timestamps
  from a worker thread, the `bin/load-test.scm` style result
  accumulator.
- One extra `.value` deref per binding read; one field write per
  `set!`. Both negligible.

## Found while

Writing `bin/load-test.scm` in dabsite (2026-05-17). The first version
used a shared `results` list updated via mutex; every worker silently
saw its own copy. Worked around with a per-thread accumulator list
returned via `thread-join!`'s value. The script has a comment block
pointing here.

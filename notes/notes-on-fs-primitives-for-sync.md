# Notes on filesystem primitives for a dabsync port

These are the primitives that `(scm fs)` is missing for a faithful port of
the `dabsync` copy/sync tool. The tool needs three capabilities the current
library cannot express:

1. **Symlink preservation** — detect, read, and create symlinks *without*
   following them. Today `file-exists?`/`directory-exists?` follow links,
   `readlink` canonicalizes (shells out to `readlink -f`), and `ln` shells
   out. None of this reproduces Python's `os.path.islink` / `os.readlink`
   (raw target) / `os.symlink`.
2. **Directory metadata** — set a directory's modification time after
   recreating it. `copy-file` already preserves file mtime (C# `File.Copy`
   preserves timestamps, Java uses `COPY_ATTRIBUTES`), but there is no way
   to set an mtime on a directory.
3. **Windows long-path support** — bypass `MAX_PATH`. This is a primitive
   internal concern, not a new export; see the last section.

All native APIs below exist in .NET 8 and Java 11, so no version bumps are
needed. Add each primitive in **both** implementations in lockstep, register
it alphabetically in `Primitives.cs` / `Primitives.java`, export it from
`scm-lib/libraries/scm-fs.sld`, and run `update-scheme-files.scm` to sync.

The `info()` docstring is the API documentation (per CLAUDE.md "Documentation"),
so each spec below gives the exact `info()` text to use.

---

## Conventions recap (so the new primitives match the existing ones)

- C# class `PrimitiveXxx : Primitive`, methods `Name()`, `Info()`,
  `Apply(SourcePos? pos, object[] arguments)`. Java mirrors with lowercase
  `name()`, `info()`, `apply(SourcePos pos, Object[] arguments)`.
- Strings in: `new String(Value.AsString(args[i]))` (C#) /
  `new String(Value.asString(arguments[i]))` (Java).
- Strings out: `s.ToCharArray()` / `s.toCharArray()`.
- Booleans out: `Value.T` / `Value.F`.
- Unspecified out: `new Values()`.
- Arg count: `CheckArgs(pos, arguments, min, max)` / `checkArgs(...)`.
- Two error styles exist in the codebase: soft (`copy-file`/`move-file`
  return `Value.F` on failure) and hard (`delete-file` throws a
  `SchemeError` wrapping a `FileErrorObject`). The new primitives follow the
  **soft** style — sync walks large trees and must keep going past a single
  failure, exactly as the Python tool swallows `OSError` per entry.

---

## 1. `file-symlink?`  (new)

Predicate: is the entry *itself* a symbolic link, without following it?
Returns `#t` for a symlink (even a dangling one), `#f` otherwise (including
when the path does not exist). This is the `os.path.islink` equivalent and is
the linchpin of the whole port.

`info()`:

    Syntax: (file-symlink? path)
    Library: (scm fs)
    Description: Returns #t if path names a symbolic link itself (without
      following it), otherwise #f. Returns #t even for a dangling link whose
      target is missing, and #f if path does not exist.
    Example:
      (file-symlink? "/usr/local/bin/python") => #t

C# (.NET 8):

```csharp
public override object Apply(SourcePos? pos, object[] arguments)
{
    CheckArgs(pos, arguments, 1, 1);
    var path = new String(Value.AsString(arguments[0]));
    try
    {
        // LinkTarget is non-null iff the entry is a reparse point/symlink.
        var fi = new FileInfo(path);
        if (fi.Exists || fi.LinkTarget != null) return fi.LinkTarget != null ? Value.T : Value.F;
        var di = new DirectoryInfo(path);
        return di.LinkTarget != null ? Value.T : Value.F;
    }
    catch (Exception) { return Value.F; }
}
```

Java (11):

```java
public Object apply(SourcePos pos, Object[] arguments) {
    checkArgs(pos, arguments, 1, 1);
    var path = new String(Value.asString(arguments[0]));
    try {
        return Files.isSymbolicLink(new File(path).toPath()) ? Value.T : Value.F;
    } catch (Exception e) {
        return Value.F;
    }
}
```

---

## 2. `read-symlink`  (new — replaces shelling out)

Returns the **raw** target text of a symlink (what the link stores), *not*
the canonicalized real path. This is `os.readlink`. The existing `readlink`
in `(scm fs)` shells out to `readlink -f`, which resolves the whole chain to
its final target — wrong for replication, because we want to recreate the
link verbatim. Recommend adding this as a primitive and rewriting the `(scm
fs)` `readlink` lambda to call it (keeping the canonicalizing behavior under
a different name if it is still wanted, e.g. `realpath`).

`info()`:

    Syntax: (read-symlink path)
    Library: (scm fs)
    Description: Returns the raw target string stored in the symbolic link at
      path, exactly as recorded (not resolved or canonicalized). Returns #f
      if path is not a symbolic link or cannot be read.
    Example:
      (read-symlink "/usr/local/bin/python") => "../bin/python3"

C#:

```csharp
public override object Apply(SourcePos? pos, object[] arguments)
{
    CheckArgs(pos, arguments, 1, 1);
    var path = new String(Value.AsString(arguments[0]));
    try
    {
        var fi = new FileInfo(path);
        var target = fi.LinkTarget;
        if (target == null)
        {
            var di = new DirectoryInfo(path);
            target = di.LinkTarget;
        }
        return target == null ? Value.F : target.ToCharArray();
    }
    catch (Exception) { return Value.F; }
}
```

Note: `FileInfo.LinkTarget` (.NET 6+) returns the immediate, unresolved
target — exactly the raw text we want. Do **not** use `ResolveLinkTarget(path,
true)`, which follows the chain.

Java:

```java
public Object apply(SourcePos pos, Object[] arguments) {
    checkArgs(pos, arguments, 1, 1);
    var path = new String(Value.asString(arguments[0]));
    try {
        var target = Files.readSymbolicLink(new File(path).toPath());
        return target.toString().toCharArray();
    } catch (Exception e) {
        return Value.F;
    }
}
```

`Files.readSymbolicLink` returns the raw target unmodified.

---

## 3. `make-symlink`  (new — replaces shelling out)

Creates a symbolic link at `linkpath` pointing at `target` (raw string,
copied verbatim). `os.symlink` equivalent. Does **not** delete an existing
entry first — that is the caller's job (matches `os.symlink`, which raises
`FileExistsError`); return `#f` on any failure including a pre-existing path.

`info()`:

    Syntax: (make-symlink target linkpath)
    Library: (scm fs)
    Description: Creates a symbolic link at linkpath whose target is the
      string target, stored verbatim (target need not exist). Does not
      replace an existing linkpath. Returns unspecified on success, #f on
      failure. On Windows, requires symlink-creation privilege (Developer
      Mode or elevation).
    Example:
      (make-symlink "../bin/python3" "/usr/local/bin/python")

C#:

```csharp
public override object Apply(SourcePos? pos, object[] arguments)
{
    CheckArgs(pos, arguments, 2, 2);
    var target = new String(Value.AsString(arguments[0]));
    var link   = new String(Value.AsString(arguments[1]));
    try
    {
        // Pick the directory vs file API based on what the target resolves to,
        // relative to the link's own directory. On Unix this distinction is
        // cosmetic; on Windows it sets the correct link type. Fall back to the
        // file API when the target cannot be classified (dangling link).
        var linkDir = Path.GetDirectoryName(Path.GetFullPath(link)) ?? ".";
        var resolved = Path.IsPathRooted(target) ? target : Path.Combine(linkDir, target);
        if (Directory.Exists(resolved))
            Directory.CreateSymbolicLink(link, target);
        else
            File.CreateSymbolicLink(link, target);
        return new Values();
    }
    catch (Exception) { return Value.F; }
}
```

Java:

```java
public Object apply(SourcePos pos, Object[] arguments) {
    checkArgs(pos, arguments, 2, 2);
    var target = new String(Value.asString(arguments[0]));
    var link   = new String(Value.asString(arguments[1]));
    try {
        Files.createSymbolicLink(new File(link).toPath(),
                                 new File(target).toPath());
        return new Values();
    } catch (Exception e) {
        return Value.F;
    }
}
```

Caveat to document: on Windows, creating symlinks needs privilege (Developer
Mode, or running elevated). `#f` will be returned otherwise; sync should log
and continue, just as the Python tool logs the `OSError`.

---

## 4. `directory-entries`  (new — symlink-aware listing)

The current `directory-files` / `directory-directories` split classifies by
*following* links (Java's `isDirectory()` follows; C# `GetFiles`/
`GetDirectories` likewise), so a symlink-to-directory is silently treated as
a real directory and recursed into — the opposite of what sync wants. A
faithful walk needs the entry type *without following*.

Add one primitive that returns the full listing tagged by no-follow type, so
the Scheme walker classifies each entry once:

`info()`:

    Syntax: (directory-entries dirname)
    Library: (scm fs)
    Description: Returns a list of (name . type) pairs for the entries in
      dirname, where name is the entry name (not a full path) and type is one
      of the symbols 'file, 'directory, or 'symlink. Symlinks are reported as
      'symlink regardless of what they point to (they are not followed).
    Example:
      (directory-entries "/tmp")
        => (("a.txt" . file) ("sub" . directory) ("link" . symlink) ...)

C#:

```csharp
public override object Apply(SourcePos? pos, object[] arguments)
{
    CheckArgs(pos, arguments, 1, 1);
    var dir = new String(Value.AsString(arguments[0]));
    var di = new DirectoryInfo(dir);
    object result = Value.NIL;
    var entries = di.GetFileSystemInfos();
    for (int i = entries.Length - 1; i >= 0; i--)
    {
        var e = entries[i];
        object type;
        if (e.LinkTarget != null) type = "symlink".ToCharArray()... // use a symbol
        else if ((e.Attributes & FileAttributes.Directory) != 0) type = ...'directory
        else type = ...'file
        result = new Pair(new Pair(e.Name.ToCharArray(), type), result);
    }
    return result;
}
```

> Note: emit the type as an interned **symbol**, not a string — match however
> other primitives build symbols (e.g. how `sys-platform` returns `'windows`).
> Pseudocode above marks the spots; use the codebase's symbol constructor.

Java:

```java
public Object apply(SourcePos pos, Object[] arguments) {
    checkArgs(pos, arguments, 1, 1);
    File dir = new File(new String(Value.asString(arguments[0])));
    File[] entries = dir.listFiles();
    Object result = Value.NIL;
    if (entries == null) return result;
    for (int i = entries.length - 1; i >= 0; i--) {
        File e = entries[i];
        Object type;
        if (Files.isSymbolicLink(e.toPath()))      type = /* symbol */ "symlink";
        else if (e.isDirectory())                  type = /* symbol */ "directory";
        else                                       type = /* symbol */ "file";
        result = new Pair(new Pair(e.getName().toCharArray(), type), result);
    }
    return result;
}
```

This single primitive lets the Scheme `%walk` (cf. `scm-fs-find.scm`)
distinguish symlinks cheaply. `directory-files`/`directory-directories` can
stay as they are for non-sync callers, or be reimplemented on top of this.

> If you would rather not add a new listing primitive, the fallback is to keep
> using `directory-files`/`directory-directories` and call `file-symlink?` on
> each entry. That is correct but does an extra stat per entry and, on Java,
> still mis-sorts a dir-symlink into the directories list — so you'd have to
> filter symlinks out of both lists first. `directory-entries` is cleaner.

---

## 5. `set-file-modification-time!`  (new)

Sets the mtime of a file *or* directory, given milliseconds since the Unix
epoch (UTC) — the same unit `file-modification-timestamp` returns, so the two
round-trip. Needed to give a freshly created destination directory the
source's mtime (`_copystat_safe` in the Python tool). For files, `copy-file`
already handles this; this primitive is mainly for directories and for a
`--force`-style mtime fix-up.

`info()`:

    Syntax: (set-file-modification-time! path millis)
    Library: (scm fs)
    Description: Sets the last-modification time of the file or directory at
      path to millis (milliseconds since the Unix epoch, UTC). Returns
      unspecified on success, #f on failure. The unit matches the value
      returned by file-modification-timestamp.
    Example:
      (set-file-modification-time! "dir" (file-modification-timestamp "src"))

C#:

```csharp
public override object Apply(SourcePos? pos, object[] arguments)
{
    CheckArgs(pos, arguments, 2, 2);
    var path = new String(Value.AsString(arguments[0]));
    var millis = Value.AsLong(arguments[1]);   // use the codebase's int accessor
    try
    {
        var when = DateTimeOffset.FromUnixTimeMilliseconds(millis).UtcDateTime;
        if (Directory.Exists(path)) Directory.SetLastWriteTimeUtc(path, when);
        else                        File.SetLastWriteTimeUtc(path, when);
        return new Values();
    }
    catch (Exception) { return Value.F; }
}
```

Java:

```java
public Object apply(SourcePos pos, Object[] arguments) {
    checkArgs(pos, arguments, 2, 2);
    var path = new String(Value.asString(arguments[0]));
    long millis = Value.asLong(arguments[1]);  // use the codebase's int accessor
    try {
        Files.setLastModifiedTime(new File(path).toPath(),
                                  FileTime.fromMillis(millis));
        return new Values();
    } catch (Exception e) {
        return Value.F;
    }
}
```

(Match whatever integer accessor the codebase already uses for `long`
arguments — check how, e.g., a primitive taking a numeric arg reads it.)

---

## 6. Optional: `path-exists?`  (no-follow existence)

`os.path.lexists` — true if the path exists, including a dangling symlink.
Strictly speaking this is derivable in Scheme as

    (or (file-exists? p) (directory-exists? p) (file-symlink? p))

so it is optional. Add it only if you want the walker to read cleanly:

    Syntax: (path-exists? path)
    Library: (scm fs)
    Description: Returns #t if path exists as a file, directory, or symbolic
      link (a dangling link still counts), without following links;
      otherwise #f. This is the lexists-style check.

C# `File.Exists(p) || Directory.Exists(p) || new FileInfo(p).LinkTarget != null`;
Java `Files.exists(path, NOFOLLOW_LINKS)`.

---

## 7. Windows long paths (`MAX_PATH`) — primitive-internal, no new export

This is a behavioral fix inside the existing primitives, not a new function.
The Python tool prefixes absolute paths with `\\?\` (`_wlp`) to bypass the
260-char `MAX_PATH`. dabscm does none of this and currently cannot do long
paths reliably on Windows. Two separate problems:

**C# side.** `FileInfo`/`DirectoryInfo`/`File.Copy`/`Path.GetFullPath` honor
long paths on .NET only when the OS has `LongPathsEnabled` set in the
registry, or the app manifest declares `longPathAware`. Neither is guaranteed
on a user's machine. The robust fix: prefix paths with `\\?\` inside the
primitives. .NET accepts the prefix on all the file APIs. Add a shared helper
(mirroring `_wlp`):

```csharp
internal static string Wlp(string path)
{
    if (!OperatingSystem.IsWindows() || string.IsNullOrEmpty(path)) return path;
    if (path.StartsWith(@"\\?\")) return path;
    var abs = Path.GetFullPath(path);
    if (abs.StartsWith(@"\\")) return @"\\?\UNC\" + abs.Substring(2);
    return @"\\?\" + abs;
}
```

Apply it at the top of every fs primitive's `Apply`. Strip the prefix back
off any path *returned* to Scheme (the `_strip_wlp` inverse), so the prefix
never leaks into user-visible strings (`read-symlink` results, listings).

**Java side — the harder half.** Most fs primitives use `java.io.File`
(`directory-files`, `directory-directories`, `file-size`, `file-exists?`,
`copy-file` constructs `new File(...).toPath()`). `java.io.File` is hard-
capped at `MAX_PATH` on Windows and *normalizes away* a `\\?\` prefix, so the
C#-style trick does not work from either Scheme or Java. The fix is to
migrate the Java fs primitives from `java.io.File` to `java.nio.file.Path` /
`Files`, which do honor long paths (and accept the `\\?\` prefix). Most are
near-mechanical:

- `new File(s).exists()` → `Files.exists(Paths.get(s))`
- `dir.listFiles()` → `Files.newDirectoryStream(dir)` /
  `Files.list(dir)` (and use it in `directory-entries` from the start)
- `file.length()` → `Files.size(path)`
- `Files.copy(...)` already uses nio — good.

Because the Java `File` approach can't be rescued with a string prefix, do
`directory-entries` (and any other *new* primitive) on `java.nio.file` from
the outset, and schedule the migration of the older `File`-based ones.

**Recommendation:** make the prefixing transparent inside the primitives
rather than exposing `\\?\` handling to Scheme. That keeps the eventual
`dabsync.scm` identical across platforms — no `_wlp`/`_strip_wlp` logic in
Scheme at all — which is the whole point of dabscm being OS-independent.

---

## Summary of work

New exports in `(scm fs)`:

| primitive | replaces (Python) | native API (C# / Java) |
|---|---|---|
| `file-symlink?` | `os.path.islink` | `FileInfo.LinkTarget` / `Files.isSymbolicLink` |
| `read-symlink` | `os.readlink` (raw) | `FileInfo.LinkTarget` / `Files.readSymbolicLink` |
| `make-symlink` | `os.symlink` | `File.CreateSymbolicLink` / `Files.createSymbolicLink` |
| `directory-entries` | `os.listdir` + type | `GetFileSystemInfos` / `Files.list`+`isSymbolicLink` |
| `set-file-modification-time!` | `_copystat_safe` (dir mtime) | `File/Directory.SetLastWriteTimeUtc` / `Files.setLastModifiedTime` |
| `path-exists?` *(optional)* | `os.path.lexists` | derivable; or `Files.exists(..., NOFOLLOW_LINKS)` |

Internal, no new export:

- `\\?\` prefixing in C# fs primitives (+ strip on return).
- Migrate Java fs primitives from `java.io.File` to `java.nio.file`.

Tests: add a `tests_fs_symlink.scm` (gate symlink-creation tests on Windows
privilege, mirroring how the Python suite gates its Windows tests) covering
create→`file-symlink?`→`read-symlink` round-trips, `directory-entries` type
tagging, dangling-link handling, and `set-file-modification-time!` round-trip
against `file-modification-timestamp`.

# `(scm deb)`

Debian packages in pure Scheme — tar, ar and .deb writers

## Exports

### `add-parent-dirs`

```
Syntax: (add-parent-dirs entries)
Library: (scm deb)
Description: entries plus a 0755 directory entry for every parent directory
  that has none yet.
Example:
  (map entry-name (add-parent-dirs (list (list "a/b/c" #o644 (bytevector)))))
  => ("a/" "a/b/" "a/b/c")
```

### `ar-bytevector`

```
Syntax: (ar-bytevector members mtime)
Library: (scm deb)
Description: A common-format ar archive (the outer container of a .deb) as
  a bytevector. members is a list of (name bytevector); names are at most
  15 characters.
Example:
  (ar-bytevector (list (list "debian-binary" (string->utf8 "2.0\n"))) 0)
```

### `deb-bytevector`

```
Syntax: (deb-bytevector control-entries data-entries mtime)
Library: (scm deb)
Description: A complete .deb package as a bytevector: debian-binary,
  control.tar.gz from control-entries (control, md5sums, maintainer
  scripts) and data.tar.gz from data-entries (missing parent directories
  are added). All entries get mtime; write the result with
  write-bytevector to <name>_<version>_<arch>.deb.
Example:
  (deb-bytevector (list (list "control" #o644 (string->utf8 control-text)))
                  (list (list "usr/bin/hello" #o755 script-bytes))
                  1700000000)
```

### `entry-content`

```
Syntax: (entry-content entry)
Library: (scm deb)
Description: The bytes of a package entry, or #f for a directory.
Example:
  (entry-content (list "opt/app/" #o755 #f)) => #f
```

### `entry-mode`

```
Syntax: (entry-mode entry)
Library: (scm deb)
Description: The file mode (an integer such as #o644) of a package entry.
Example:
  (entry-mode (list "etc/app.conf" #o644 (bytevector))) => 420
```

### `entry-name`

```
Syntax: (entry-name entry)
Library: (scm deb)
Description: The archive path of a package entry (name mode content),
  without the "./" prefix; directories end in "/".
Example:
  (entry-name (list "usr/bin/app" #o755 (bytevector))) => "usr/bin/app"
```

### `sort-entries`

```
Syntax: (sort-entries entries)
Library: (scm deb)
Description: entries sorted by name, so a directory precedes its contents
  and the order is the same on every host.
Example:
  (map entry-name (sort-entries (list (list "b" #o644 #f) (list "a" #o644 #f))))
  => ("a" "b")
```

### `tar-bytevector`

```
Syntax: (tar-bytevector entries mtime)
Library: (scm deb)
Description: An uncompressed USTAR tar archive of entries as a bytevector,
  as dpkg-deb writes it: names get a "./" prefix, the archive starts with
  the "./" directory, owner root:root, every entry with mtime (seconds
  since the epoch). Entries are written in the given order.
Example:
  (bytevector-length (tar-bytevector (list (list "a.txt" #o644 (string->utf8 "hi"))) 0))
  => 2560
```


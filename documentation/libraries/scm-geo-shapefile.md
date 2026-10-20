# `(scm geo shapefile)`

Reading ESRI shapefiles and dBASE tables

## Overview

`(scm geo shapefile)` reads ESRI shapefiles into the features of `(scm geo)`:
the geometry from the `.shp` file, the attributes from the dBASE table in the
`.dbf` file, decoded as UTF-8 or Latin-1 as the `.cpg` file says. Polygons,
polylines and points are read, with or without Z and M values (which are
dropped).

## Common uses

```scheme
(import (scm geo) (scm geo shapefile))

(define cantons (read-shapefile "cantons.shp"))
(map (lambda (f) (feature-ref f "NAME")) cantons)   ;; => ("Zürich" ...)
```

`shapefile->features` takes the files' contents as bytevectors instead, so a
shapefile can be read straight out of a ZIP archive with `(scm zip)`:

```scheme
(call-with-input-zip "boundaries.zip"
  (lambda (z)
    (shapefile->features (zip-read-entry-bytevector z "cantons.shp")
                         (zip-read-entry-bytevector z "cantons.dbf")
                         'utf-8)))
```


## Exports

### `dbf->records`

```
Syntax: (dbf->records dbf [encoding])
Library: (scm geo shapefile)
Description: Returns the records of a dBASE table, dbf a bytevector with the
  contents of a .dbf file, as a list of alists from field name to value.
  Character fields become strings (decoded with encoding, the symbol utf-8,
  the default, or latin-1) without trailing blanks, numeric and float fields
  numbers (exact when integral), logical fields #t or #f, date fields strings
  "YYYY-MM-DD". An empty value is the symbol null, as in (scm json simple).
  Deleted records are skipped.
Example:
  (dbf->records dbf-bytes) => ((("NAME" . "Bern") ("KANTONSNUM" . 2)) ...)
```

### `read-shapefile`

```
Syntax: (read-shapefile path [encoding])
Library: (scm geo shapefile)
Description: Reads the ESRI shapefile path (the .shp file) and its attribute
  table (the .dbf file next to it) and returns a list of features, in file
  order. Text attributes are decoded with encoding, the symbol utf-8 or
  latin-1; by default the one named in the .cpg file next to it, else utf-8.
  See shapefile->features for the geometry and attribute types.
Example:
  (map (lambda (f) (feature-ref f "NAME")) (read-shapefile "cantons.shp")) => ("Zürich" ...)
```

### `shapefile->features`

```
Syntax: (shapefile->features shp dbf [encoding])
Library: (scm geo shapefile)
Description: Returns the features of a shapefile given as bytevectors: shp the
  contents of the .shp file, dbf those of the .dbf file or #f. This reads a
  shapefile straight out of a ZIP archive. Polygons (types 5, 15, 25) become
  polygon geometries, polylines (3, 13, 23) polylines and points (1, 8, 11,
  18, 21, 28) multipoints; Z and M values are dropped. A null shape has the
  geometry #f. Attributes are as returned by dbf->records.
Example:
  (length (shapefile->features shp-bytes dbf-bytes 'utf-8)) => 26
```


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

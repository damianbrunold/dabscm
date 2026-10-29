# `(scm fonts)`

Fonts by family name from font files: the dabscm-fonts package or any directory or zip of .ttf files

## Exports

### `find-font`

```
Syntax: (find-font family [weight [style [options]]])
Library: (scm fonts)
Description: The font (see (scm truetype)) of family nearest to weight
  (100 to 900, or thin, extra-light, light, regular, medium, semi-bold,
  bold, extra-bold, black; default 400) and style (normal or italic,
  default normal), or #f when the family is not found. options go to
  read-truetype, e.g. ((features "tnum")). Fonts are read once.
Example:
  (find-font "JetBrains Mono" 'bold 'italic)
  (find-font "Inter" 400 'normal '((features "tnum")))
```

### `find-font-file`

```
Syntax: (find-font-file family [weight [style]])
Library: (scm fonts)
Description: The TrueType file (bytevector) of the face find-font
  would choose, or #f: for embedding the font as it is, e.g. with
  pdf-embed-truetype-font (which subsets it).
Example:
  (pdf-embed-truetype-font doc (find-font-file "Roboto" 'bold) "Roboto-Bold")
```

### `font-faces`

```
Syntax: (font-faces family)
Library: (scm fonts)
Description: The faces of family as (weight italic?) lists, upright
  before italic, lighter first; () when the family is not found.
Example:
  (font-faces "JetBrains Mono") => ((400 #f) (700 #f) (400 #t) (700 #t))
```

### `font-families`

```
Syntax: (font-families)
Library: (scm fonts)
Description: The names of the font families found along the search
  path, sorted.
Example:
  (font-families) => ("IBM Plex Mono" "IBM Plex Sans" "Inter" "JetBrains Mono" ...)
```

### `font-license`

```
Syntax: (font-license family)
Library: (scm fonts)
Description: The licence text of family's fonts, or #f when the family
  is not found or no licence file is beside its fonts.
Example:
  (font-license "JetBrains Mono") => "Copyright 2020 The JetBrains Mono Project Authors ..."
```

### `font-search-path`

```
Syntax: (font-search-path)
Library: (scm fonts)
Description: The directories and zip files fonts are looked up in, in
  order.
Example:
  (font-search-path) => ("/home/me/.local/share/dabscm/fonts" "/usr/local/share/dabscm/fonts" "/usr/share/dabscm/fonts")
```

### `font-search-path!`

```
Syntax: (font-search-path! paths)
Library: (scm fonts)
Description: Sets the directories and zip files fonts are looked up in
  (a list of paths), and forgets the fonts found so far.
Example:
  (font-search-path! (cons "/srv/app/fonts" (font-search-path)))
```


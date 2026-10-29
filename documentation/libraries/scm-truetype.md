# `(scm truetype)`

TrueType font reading — glyph outlines, advances, kerning, OpenType features, text as paths

## Exports

### `font->truetype`

```
Syntax: (font->truetype font family [style [chars]])
Library: (scm truetype)
Description: Returns a TrueType file (bytevector) with the glyphs of
  font as it draws them (OpenType features it was read with applied):
  for the characters chars (a list or string), by default all of the
  font's. family names it; style is "Regular" (default), "Bold",
  "Black" and so on, which also sets the weight. The file has no
  hinting and no kerning table: a PDF positions the glyphs itself.
Example:
  (pdf-embed-truetype-font doc (font->truetype inter-regular "Inter") "Inter")
  (font->truetype (read-truetype bv '((features "tnum"))) "Inter" "Regular" "0123456789")
```

### `font-ascent`

*(no documentation)*

### `font-chars`

```
Syntax: (font-chars font)
Library: (scm truetype)
Description: The characters font has glyphs for, ascending. For a font
  read with read-truetype they come from its cmap.
Example:
  (length (font-chars inter-regular)) => 312
```

### `font-descent`

*(no documentation)*

### `font-glyph`

```
Syntax: (font-glyph font char)
Library: (scm truetype)
Description: Returns the glyph for char as (advance . contours), or #f
  when the font has none. advance is in font units; contours is a list of
  contours, each a list of points (x y on-curve?) in font units with y
  pointing up, as TrueType stores them.
Example:
  (car (font-glyph font #\A)) => 1401   ; DejaVu Sans
```

### `font-kerning`

```
Syntax: (font-kerning font left right)
Library: (scm truetype)
Description: Returns the kerning adjustment between the characters left
  and right, in font units (usually negative), or 0.
Example:
  (font-kerning font #\A #\V) => -77   ; DejaVu Sans
```

### `font-text-path`

```
Syntax: (font-text-path font size x y string)
Library: (scm truetype)
Description: Returns string set in font at size (pixels per em) as a path
  for (scm raster), starting at x on the baseline y, in canvas coordinates
  (y pointing down). Fill it with the non-zero rule.
Example:
  (canvas-fill-path! canvas (font-text-path font 11 10 20 "Intern")
                     (rgba 0 0 0))
```

### `font-text-width`

```
Syntax: (font-text-width font size string)
Library: (scm truetype)
Description: Returns the advance width of string set in font at size
  (in pixels per em), kerning included.
Example:
  (font-text-width font 11 "Intern") => 33.4...
```

### `font-units-per-em`

*(no documentation)*

### `font?`

*(no documentation)*

### `make-outline-font`

```
Syntax: (make-outline-font units-per-em ascent descent glyphs [kerning])
Library: (scm truetype)
Description: Returns a font made from glyph data: glyphs is an alist of
  (char advance . contours), as font-glyph returns them; kerning an alist
  of ((left . right) . value). For fonts compiled into a library, such as
  (scm fonts dejavu).
Example:
  (make-outline-font 1000 800 -200
    (list (list #\- 400 '((50 250 #t) (350 250 #t) (350 300 #t) (50 300 #t)))))
```

### `read-truetype`

```
Syntax: (read-truetype bytevector [options])
Library: (scm truetype)
Description: Parses a TrueType font (.ttf) and returns a font. Glyph
  outlines are decoded when first asked for. OpenType fonts with CFF
  outlines (.otf) are not supported. options is an alist; (features
  "ss07" "tnum" ...) switches on OpenType features, of which the
  single substitutions are applied (stylistic sets, character variants,
  figure styles); kerning stays that of the kern table.
Example:
  (define font (read-truetype (call-with-port
                 (open-binary-input-file "DejaVuSans.ttf")
                 (lambda (p) (read-bytevector 1000000 p)))))
  (read-truetype bv '((features "tnum")))
```

### `truetype-info`

```
Syntax: (truetype-info bytevector)
Library: (scm truetype)
Description: What a TrueType font (.ttf) says about itself, without
  reading its glyphs: an alist with family (the typographic family name,
  e.g. "Inter" also for Inter Bold), style (e.g. "Bold Italic"),
  weight (100 to 900, from the OS/2 table) and italic (#t or #f).
Example:
  (truetype-info bv)
  => ((family . "JetBrains Mono") (style . "Bold Italic") (weight . 700) (italic . #t))
```


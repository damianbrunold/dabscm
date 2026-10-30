## Overview

The format-neutral half of the SVG renderers, shared by `(scm svg raster)`
(canvas, PNG) and `(scm svg pdf)` (PDF vectors): an XML reader to SXML, tree
accessors, number and transform parsing, path data (arcs become cubic
curves), CSS rules with the cascade (type, class and id selectors,
descendants, specificity), paints and the geometry of the basic shapes. Both
renderers support the same SVG subset, described in `(scm svg raster)`.

Programs normally use the renderers; this library is for writing another one.

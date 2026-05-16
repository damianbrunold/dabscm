# Acknowledgments

This file documents third-party code included in the dabscm Scheme
interpreter, as well as the academic works and algorithms that influenced
its design.

dabscm is licensed under the MIT License (see `LICENSE` in the repository
root).

## Third-Party Code

### Pattern Matching Library

- **File:** `scm-lib/libraries/scm-match.sld`
- **Author:** Alex Shinn
- **License:** Public Domain

> "This code is written by Alex Shinn and placed in the Public Domain.
> All warranties are disclaimed."

This is the well-known `match.scm` pattern matching library, also distributed
with Chibi-Scheme.

### SRFI-26 (`cut` / `cute`)

- **File:** `scm-lib/libraries/srfi-26.sld`
- **Author:** Sebastian Egner (original reference implementation)
- **License:** Public Domain

The implementation of `cut` and `cute` is based on the SRFI-26 reference
implementation by Sebastian Egner. The reference implementation was placed in
the Public Domain by the author.

### SRFI-11 `let-values`

- **Location:** within `scm-lib/libraries/scheme-base.sld`
- **Author:** Lars T Hansen (original reference implementation)

The `let-values` and `let*-values` macros are based on the SRFI-11 reference
implementation by Lars T Hansen.

### SRFI-9 `define-record-type`

- **Location:** within `scm-lib/libraries/scheme-base.sld`
- **Author:** Richard Kelsey (original reference implementation)

The `define-record-type` macro and supporting record infrastructure are based
on the SRFI-9 reference implementation by Richard Kelsey.

### SRFI-19 Reference Test Suite

- **File:** `scm-tests/tests/tests_srfi_19.scm` (partial)
- **Author:** Will Fitzgerald (original reference implementation and test suite)
- **License:** Public Domain

The SRFI-19 test suite includes tests adapted from the reference implementation's
test suite by Will Fitzgerald, covering TAI-UTC leap second boundary edge cases,
ISO 8601 week number calculations, and date formatting directives.

### Chibi-Scheme R7RS Test Suite

- **File:** `scm-tests/tests/tests_chibi_r7rs_tests.scm`
- **Author:** Alex Shinn
- **License:** BSD

The R7RS conformance test suite is adapted from the Chibi-Scheme project by
Alex Shinn, which is distributed under a BSD license.

### SRFI-1 (List Library)

- **File:** `scm-lib/libraries/srfi-1.sld`
- **Author:** Olin Shivers (original reference implementation)
- **License:** MIT

The list processing library is based on the SRFI-1 reference implementation
by Olin Shivers. The code has been adapted to work within the R7RS library
system with docstrings added for the project's documentation infrastructure.

### SRFI-13 (String Library)

- **File:** `scm-lib/libraries/srfi-13.sld`
- **Author:** Olin Shivers (original reference implementation)
- **License:** BSD / MIT (MIT Scheme portions)

The string processing library is based on the SRFI-13 reference implementation
by Olin Shivers. The code has been adapted to work within the R7RS library
system with docstrings added for the project's documentation infrastructure.

## SRFI Implementations

The following 22 SRFIs are implemented: 1, 2, 8, 9, 13, 14, 18, 19, 26, 28,
39, 64, 69, 95, 98, 111, 125, 128, 132, 133, 151, 158.

Except for SRFI-1, SRFI-9, SRFI-13, SRFI-26, and the SRFI-11 `let-values`
noted above, these are original implementations written for this project, not
copies of the SRFI reference implementations. The SRFI specifications are published by the Scheme
community at <https://srfi.schemers.org/>.

## Algorithmic Inspirations

The following works influenced the design of the interpreter. No code was
copied from these sources.

- **Peter Norvig**, *Paradigms of Artificial Intelligence Programming* (1992).
  Inspired the compiler structure.

- **Matthew Flatt**, "Binding as Sets of Scopes" (POPL 2016).
  The macro expander implements Flatt's sets-of-scopes algorithm for hygiene.

## Standards

This project implements R7RS-small (Revised^7 Report on the Algorithmic
Language Scheme). The specification is available at
<https://small.r7rs.org/>.

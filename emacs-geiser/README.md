# Using dabscm from Emacs with Geiser

This directory contains everything needed to use the **dabscm** Scheme
interpreter inside GNU Emacs through [Geiser](https://www.nongnu.org/geiser/),
the generic Emacs/Scheme interaction mode.

With this set up you get an enhanced REPL plus, while editing `.scm`/`.sld`
files: expression evaluation from the buffer, namespace-aware completion,
autodoc (signatures shown in the echo area) and macro expansion — all backed by
the running dabscm process.

Contents:

- `geiser-dabscm.el` — the Emacs Lisp Geiser backend for dabscm.
- The Scheme side lives with the interpreter as the `(scm geiser)` library
  (`scm-lib/libraries/scm-geiser.sld`); it is built into both the C# and Java
  interpreters, so there is nothing extra to install for it.

These instructions target **Emacs 30 or later** but also work on Emacs 26+.

---

## 1. Prerequisites

### 1.1 A dabscm build with Geiser support

You need a dabscm executable that understands the `--geiser` flag (dabscm
**1.9.3 or later**). Build it from the repository root:

```bash
# C# build -> produces scm-csharp/repl/bin/Release/net8.0/scm
./builder.sh build-scm-csharp.scm

# or the Java build -> produces scm-java/scm.jar
./builder.sh build-scm-java.scm
```

Make the executable reachable on your `PATH` (or note its absolute path for the
configuration below). A common setup is a small wrapper on your `PATH`:

```bash
# ~/bin/scm  (C# build)
#!/bin/bash
exec /path/to/dabscm/scm-csharp/repl/bin/Release/net8.0/scm "$@"
```

```bash
# ~/bin/scmj (Java build)
#!/bin/bash
exec java -jar /path/to/dabscm/scm-java/scm.jar "$@"
```

Verify it works:

```bash
scm --version          # prints e.g. 1.9.3
echo "(geiser:eval #f '(+ 1 2))" | scm --geiser
# => > ((result "3") (output . ""))
```

### 1.2 Geiser core

Geiser itself is available from NonGNU ELPA, which is enabled by default in
Emacs 28+. Install the core package:

```
M-x package-install RET geiser RET
```

You do **not** need any of the per-Scheme packages (`geiser-guile`, etc.) — the
dabscm backend in this directory replaces them.

---

## 2. Install the dabscm backend

Pick whichever method you prefer.

### Option A — `load-path` (simplest)

Copy or symlink `geiser-dabscm.el` somewhere on your `load-path`, or point at
this directory directly. In your `init.el`:

```elisp
(add-to-list 'load-path "/path/to/dabscm/emacs-geiser")
(require 'geiser-dabscm)
```

### Option B — `use-package` (recommended, Emacs 29+)

```elisp
(use-package geiser
  :ensure t)

(use-package geiser-dabscm
  :load-path "/path/to/dabscm/emacs-geiser"
  :after geiser
  :custom
  ;; "scm" = C# build, "scmj" = Java build. Use an absolute path if the
  ;; executable is not on your PATH.
  (geiser-dabscm-binary "scm"))
```

### Option C — `package-vc-install` (Emacs 30+)

If the repository is published on a forge you can install straight from version
control:

```
M-x package-vc-install RET https://github.com/dab/dabscm RET
```

(then `(require 'geiser-dabscm)`).

---

## 3. Configuration

The backend exposes two customizable variables:

| Variable | Default | Meaning |
|---|---|---|
| `geiser-dabscm-binary` | `"scm"` | Executable to launch. Set to `"scmj"` for the Java build, or an absolute path. May be a list `("scm" "extra-arg")`. |
| `geiser-dabscm-extra-command-line-parameters` | `nil` | Extra command-line arguments passed before `--geiser`. |

Example:

```elisp
(setq geiser-dabscm-binary "/home/me/bin/scm")
```

To make dabscm the default Scheme for `scheme-mode` buffers:

```elisp
(setq geiser-default-implementation 'dabscm)
(add-to-list 'geiser-active-implementations 'dabscm)
```

The backend already associates the `.scm` and `.sld` file extensions with the
`dabscm` implementation.

---

## 4. Usage

### Start a REPL

```
M-x run-dabscm
```

This launches `scm --geiser` (or your configured binary) in a `*dabscm REPL*`
buffer. You should see the `> ` prompt and be able to evaluate expressions:

```scheme
> (+ 1 2)
3
> (map (lambda (x) (* x x)) '(1 2 3))
(1 4 9)
```

`M-x switch-to-dabscm` jumps to a running REPL (or starts one).

### Editing Scheme files

Open any `.scm` or `.sld` file. With the REPL running you can use the standard
Geiser bindings:

| Binding | Action |
|---|---|
| `C-x C-e` | Evaluate the expression before point |
| `C-M-x`   | Evaluate the top-level definition at point |
| `C-c C-r` | Evaluate the region |
| `C-c C-b` | Evaluate the whole buffer |
| `C-c C-k` | Load the current file into the REPL |
| `M-.`     | (location lookup — see Limitations) |
| `C-c C-d C-d` | Show documentation for the symbol at point |

Completion is available with `M-TAB` (or your `completion-at-point` key), and
the signature of the procedure you are calling is shown in the echo area
(autodoc) as you type.

---

## 5. How it works

Geiser does not use a special wire protocol or a socket — it runs the Scheme
REPL as an inferior process over a pipe and talks to it in plain text:

1. `geiser-dabscm.el` launches `scm --geiser`. The `--geiser` flag tells dabscm
   to import the `(scm geiser)` library and run a REPL loop that always prints
   the `> ` prompt (even though Emacs connects stdin via a pipe).
2. For each operation Geiser sends one s-expression, e.g.
   `(geiser:eval #f '(+ 1 2))`, and reads the reply up to the next prompt.
3. The `(scm geiser)` procedures answer with the structures Geiser expects, e.g.
   `((result "3") (output . ""))` for evaluation.

The `geiser:*` procedures are documented in
`scm-lib/libraries/scm-geiser.sld`.

---

## 6. Limitations

- **Jump to definition** (`M-.`): per-symbol source locations are not yet
  tracked by the interpreter, so `geiser:symbol-location` returns no location
  and `M-.` will report that it cannot find the definition. Everything else
  (eval, completion, autodoc, macro expansion, module completion) works.
- Autodoc signatures are derived from each procedure's documented `Syntax:`
  line, so the displayed arglist is only as good as the documentation. Required
  and rest (`...`) arguments are distinguished; keyword/optional metadata is
  not.

---

## 7. Troubleshooting

- **REPL hangs on startup / "Geiser is starting…" never finishes.**
  Check that `scm --geiser` works from a shell (see §1.1). The prompt regexp
  Geiser waits for is exactly `"> "`; an old build that suppresses the prompt
  under a pipe will hang.
- **"Unable to determine version" / version too old.**
  The backend requires dabscm ≥ 1.9.3. Run `scm --version` and rebuild if
  needed.
- **`scm: command not found`.**
  Set `geiser-dabscm-binary` to an absolute path, or add the executable to your
  `PATH`.
- **Wrong interpreter.**
  Set `geiser-dabscm-binary` to `"scmj"` for the Java build or `"scm"` for the
  C# build.

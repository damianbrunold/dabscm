# `(scm module)`

Module system — import, export, search paths, introspection

## Exports

### `%load-module`

```
Syntax: (%load-module module-name)
Library: (scm core)
Description: Internal primitive. Loads the named library module from an embedded .sld file or from the module search path. Returns #t if loaded successfully.
Example:
  (%load-module '(scheme base))
```

### `%module-bind`

```
Syntax: (%module-bind module-name symbol value)
Library: (scm core)
Description: Binds or rebinds symbol to value in the named module, bypassing import checks. If the symbol is exported, the export is updated too.
Example:
  (%module-bind '(scheme base) 'car new-car-impl)
```

### `%module-bindings`

```
Syntax: (%module-bindings module-name)
Library: (scm core)
Description: Returns an alphabetically sorted list of all symbols bound in the named module.
Example:
  (%module-bindings '(scheme base))
```

### `%module-defined-bindings`

```
Syntax: (%module-defined-bindings module-name)
Library: (scm core)
Description: Returns an alphabetically sorted list of all symbols
defined (not imported) in the named module. A symbol is considered
defined if its provenance matches the module's own name.
Example:
  (%module-defined-bindings '(scheme base))
```

### `%module-export-bindings`

```
Syntax: (%module-export-bindings module-name symbol ...)
Library: (scm core)
Description: Internal primitive. Marks the given symbols as exported from the named module. Each symbol must already be bound in the module.
Example:
  (%module-export-bindings '(my lib) 'foo 'bar)
```

### `%module-exports`

```
Syntax: (%module-exports module-name)
Library: (scm core)
Description: Returns an alphabetically sorted list of all symbols exported by the named module.
Example:
  (%module-exports '(scheme base))
```

### `%module-import-bindings`

```
Syntax: (%module-import-bindings module-dest module-src symbol ...)
Library: (scm core)
Description: Internal primitive. Imports the given symbols from module-src's exports into module-dest's bindings. A symbol may be a (old-name new-name) pair for renaming.
Example:
  (%module-import-bindings '(my lib) '(scheme base) 'cons 'car 'cdr)
```

### `%module-ref`

```
Syntax: (%module-ref module-name symbol)
Library: (scm core)
Description: Returns the value bound to symbol in the named module. Raises an error if the symbol is not bound.
Example:
  (%module-ref '(scheme base) 'car)
```

### `%reset-modules`

```
Syntax: (%reset-modules)
Library: (scm core)
Description: Clears all loaded modules except scm core, forcing libraries to be re-imported on next use. Used for testing and development.
Example:
  (%reset-modules)
```

### `current-module`

```
Syntax: (current-module)
Library: (scm core)
Description: Returns the name declaration of the current module.
Example:
  (current-module) => (user main)
```

### `import`

*(no documentation)*

### `module-search-path`

```
Syntax: (module-search-path)
Library: (scm core)
Description: Returns the current list of directory paths searched when loading modules. The default is ('.'). Used by the module loader to locate .sld library files.
Example:
  (module-search-path) => (".")
```

### `module-search-path!`

```
Syntax: (module-search-path! path)
Library: (scm core)
Description: Sets the module search path to path, which must be a list of directory strings. Subsequent module loads will search these directories.
Example:
  (module-search-path! '("." "/usr/share/scheme"))
```

### `modules`

*(no documentation)*

### `set-current-module`

```
Syntax: (set-current-module module-name)
Library: (scm core)
Description: Sets the specified module as the active module. Subsequent definitions will be made in that module.
Example:
  (set-current-module '(scm core))
  (current-module) => (scm core)
```


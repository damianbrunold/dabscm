;;; geiser-dabscm.el --- dabscm's implementation of the geiser protocols  -*- lexical-binding: t; -*-

;; Author: Damian Brunold
;; Maintainer: Damian Brunold
;; Keywords: languages, dabscm, scheme, geiser
;; Homepage: https://github.com/dab/dabscm
;; Package-Requires: ((emacs "26.1") (geiser "0.18"))
;; SPDX-License-Identifier: BSD-3-Clause
;; Version: 1.0.0

;;; Commentary:

;; This package provides support for the dabscm Scheme interpreter in Geiser.
;;
;; dabscm is started with the `--geiser' flag, which launches a REPL that
;; preloads the `(scm geiser)' support library (shipped with dabscm) and always
;; emits the "> " prompt so that Geiser can drive it over a pipe.
;;
;; Once `geiser' is installed and this file is on your `load-path', add
;;
;;     (require 'geiser-dabscm)
;;
;; to your init file and then run `M-x run-dabscm'.  Point
;; `geiser-dabscm-binary' at your `scm' executable (the C# build) or at `scmj'
;; (the Java build) as desired.

;;; Code:

(require 'geiser-connection)
(require 'geiser-syntax)
(require 'geiser-impl)
(require 'geiser-custom)
(require 'geiser-base)
(require 'geiser-eval)
(require 'geiser-edit)
(require 'geiser-log)
(require 'geiser)

(require 'compile)

(eval-when-compile (require 'cl-lib))


;;; Customization:

(defgroup geiser-dabscm nil
  "Customization for Geiser's dabscm Scheme flavour."
  :group 'geiser)

(geiser-custom--defcustom geiser-dabscm-binary
    "scm"
  "Name to use to call the dabscm executable when starting a REPL.
Use \"scm\" for the C# build or \"scmj\" for the Java build.  May also
be a list whose first element is the executable and whose remaining
elements are extra arguments."
  :type '(choice string (repeat string))
  :group 'geiser-dabscm)

(geiser-custom--defcustom geiser-dabscm-extra-command-line-parameters
    nil
  "Additional parameters to supply to the dabscm binary."
  :type '(repeat string)
  :group 'geiser-dabscm)


;;; REPL support:

(defun geiser-dabscm--binary ()
  "Return the path to the dabscm executable."
  (if (listp geiser-dabscm-binary)
      (car geiser-dabscm-binary)
    geiser-dabscm-binary))

(defun geiser-dabscm--parameters ()
  "Return a list with all parameters needed to start dabscm.
The `--geiser' flag makes dabscm preload the `(scm geiser)' support
library and always print its prompt."
  `(,@geiser-dabscm-extra-command-line-parameters
    "--geiser"
    ,@(and (listp geiser-dabscm-binary) (cdr geiser-dabscm-binary))))

(defconst geiser-dabscm--prompt-regexp "> ")


;;; Evaluation support:

(defun geiser-dabscm--geiser-procedure (proc &rest args)
  "Transform PROC in a string for a scheme procedure using ARGS."
  (cl-case proc
    ((eval compile)
     (let ((form (mapconcat 'identity (cdr args) " "))
           (module (cond ((string-equal "'()" (car args))
                          "'()")
                         ((and (car args))
                          (concat "'" (car args)))
                         (t
                          "#f"))))
       (format "(geiser:eval %s '%s)" module form)))
    ((load-file compile-file)
     (format "(geiser:load-file %s)" (car args)))
    ((no-values)
     "(geiser:no-values)")
    (t
     (let ((form (mapconcat 'identity args " ")))
       (format "(geiser:%s %s)" proc form)))))

(defun geiser-dabscm--get-module (&optional module)
  "Find current buffer's module, using MODULE as a hint."
  (cond ((null module) :f)
        ((listp module) module)
        ((stringp module)
         (condition-case nil
             (car (geiser-syntax--read-from-string module))
           (error :f)))
        (t :f)))

(defun geiser-dabscm--symbol-begin (module)
  "Return beginning of current symbol while in MODULE."
  (if module
      (max (save-excursion (beginning-of-line) (point))
           (save-excursion (skip-syntax-backward "^(>") (1- (point))))
    (save-excursion (skip-syntax-backward "^'-()>") (point))))

(defun geiser-dabscm--import-command (module)
  "Return string representing an sexp importing MODULE."
  (format "(import %s)" module))

(defun geiser-dabscm--exit-command ()
  "Return string representing a REPL exit sexp."
  "(exit 0)")


;;; REPL startup:

(defconst geiser-dabscm-minimum-version "1.9.3")

(defun geiser-dabscm--version (binary)
  "Use BINARY to find the dabscm version."
  (car (process-lines binary "--version")))

(defun geiser-dabscm--startup (_remote)
  "Startup function."
  (let ((geiser-log-verbose-p t))
    (compilation-setup t)))


;;; Implementation definition:

(define-geiser-implementation dabscm
  (binary geiser-dabscm--binary)
  (arglist geiser-dabscm--parameters)
  (version-command geiser-dabscm--version)
  (minimum-version geiser-dabscm-minimum-version)
  (repl-startup geiser-dabscm--startup)
  (prompt-regexp geiser-dabscm--prompt-regexp)
  (debugger-prompt-regexp nil)
  (marshall-procedure geiser-dabscm--geiser-procedure)
  (find-module geiser-dabscm--get-module)
  (exit-command geiser-dabscm--exit-command)
  (import-command geiser-dabscm--import-command)
  (find-symbol-begin geiser-dabscm--symbol-begin))

;;;###autoload
(geiser-implementation-extension 'dabscm "sld")

;;;###autoload
(geiser-implementation-extension 'dabscm "scm")

;;;###autoload
(geiser-activate-implementation 'dabscm)

;;;###autoload
(autoload 'run-dabscm "geiser-dabscm" "Start a Geiser dabscm Scheme REPL." t)

;;;###autoload
(autoload 'switch-to-dabscm "geiser-dabscm"
  "Start a Geiser dabscm Scheme REPL, or switch to a running one." t)


(provide 'geiser-dabscm)
;;; geiser-dabscm.el ends here

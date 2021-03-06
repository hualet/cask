;;; cask.el --- Emacs dependency management made easy

;; Copyright (C) 2012, 2013 Johan Andersson
;; Copyright (C) 2013 Sebastian Wiesner
;; Copyright (C) 2013 Takafumi Arakaki

;; Author: Johan Andersson <johan.rejeep@gmail.com>
;; Maintainer: Johan Andersson <johan.rejeep@gmail.com>
;; Version: 0.4.6
;; Keywords: speed, convenience
;; URL: http://github.com/rejeep/cask.el

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;;; Code:

(eval-when-compile
  (require 'cl))

(eval-and-compile
  (defconst cask-directory
    ;; Fall back to buffer file name to handle M-x eval-buffer
    (file-name-directory
     (cond
      (load-in-progress load-file-name)
      ((and (boundp 'byte-compile-current-file) byte-compile-current-file)
       byte-compile-current-file)
      (:else (buffer-file-name))))
    "The directory to which Cask is installed.")

  (defun cask-resource-path (name)
    "Get the path of a Cask resource with NAME."
    (expand-file-name name cask-directory)))

(require 'epl (cask-resource-path "epl"))

(defstruct cask-package name version description)
(defstruct cask-dependency name version)
(defstruct cask-source name url)

(defvar cask-project-path nil
  "Path to project.")

(defvar cask-project-name nil
  "Name of project.")

(defvar cask-file nil
  "Path to `Cask` file.")

(defvar cask-package-file nil
  "Path to project package (`-pkg.el`) file.")

(defvar cask-development-dependencies nil
  "List of development dependencies.")

(defvar cask-runtime-dependencies nil
  "List of runtime dependencies.")

(defvar cask-package nil
  "Project package information.")

(defvar cask-source-mapping
  '((gnu         . "http://elpa.gnu.org/packages/")
    (melpa       . "http://melpa.milkbox.net/packages/")
    (marmalade   . "http://marmalade-repo.org/packages/")
    (SC          . "http://joseito.republika.pl/sunrise-commander/")
    (org         . "http://orgmode.org/elpa/")
    (cask-test   . "http://127.0.0.1:9191/packages/"))
  "Mapping of source name and url.")

(defstruct cask-source-position line column)

(defun cask-current-source-position ()
  "Get the current position in the buffer."
  (make-cask-source-position :line (line-number-at-pos)
                             :column (1+ (current-column))))

(defun cask-read (filename)
  "Read a cask file from FILENAME.

Return all directives in the Cask file as list."
  (with-temp-buffer
    (insert-file-contents filename)
    (goto-char (point-min))
    (let (forms)
      (condition-case err
          ;; Skip over blank lines and comments while reading to get exact
          ;; line/column information for errors (shamelessly taken from
          ;; `byte-compile-from-buffer')
          (while (progn
                   (while (progn (skip-chars-forward " \t\n\^l")
                                 (looking-at ";"))
                     (forward-line 1))
                   (not (eobp)))        ; Read until end of file
            (push (read (current-buffer)) forms))
        (error
         ;; Re-emit any error with position information
         (signal (car err) (cons (cask-current-source-position)
                                 (cdr err)))))
      (nreverse forms))))

(defun cask-get-dep-list-for-scope (scope)
  "Get the dependency list symbol for SCOPE."
  (if (eq scope :development)
      'cask-development-dependencies
    'cask-runtime-dependencies))

(defun cask-add-dependency (name &optional version scope)
  "Add the dependency NAME with VERSION in SCOPE."
  (let* ((name (if (stringp name) (intern name) name))
         (dependency (make-cask-dependency :name name :version version))
         (dep-list (cask-get-dep-list-for-scope scope)))
    (add-to-list dep-list dependency t)))

(defun cask-parse-epl-package (package)
  "Parse an EPL PACKAGE."
  (setq cask-package
        (make-cask-package :name (epl-package-name package)
                             :version (epl-package-version-string package)
                             :description (epl-package-summary package)))
  (dolist (req (epl-package-requirements package))
    (cask-add-dependency (epl-requirement-name req)
                             (epl-requirement-version-string req))))

(defun cask-eval (forms &optional scope)
  "Evaluate cask FORMS in SCOPE.

SCOPE may be nil or :development."
  (dolist (form forms)
    (case (car form)
      (source
       (destructuring-bind (_ name-or-alias &optional url) form
         (unless url
           (let ((mapping (assq name-or-alias cask-source-mapping)))
             (unless mapping
               (error "Unknown package archive: %s" name-or-alias))
             (setq name-or-alias (symbol-name (car mapping)))
             (setq url (cdr mapping))))
         (epl-add-archive name-or-alias url)))
      (package
       (destructuring-bind (_ name version description) form
         (setq cask-package (make-cask-package :name name
                                                   :version version
                                                   :description description))))
      (package-file
       (destructuring-bind (_ filename) form
         (cask-parse-epl-package
          (epl-package-from-file
           (expand-file-name filename cask-project-path)))))
      (depends-on
       (destructuring-bind (_ name &optional version) form
         (cask-add-dependency name version scope)))
      (development
       (destructuring-bind (_ . body) form
         (cask-eval body :development)))
      (t
       (error "Unknown directive: %S" form)))))

(defun cask-elpa-dir ()
  "Return full path to `cask-project-path'/.cask/elpa/`emacs-version'."
  (expand-file-name (format ".cask/%s/elpa" emacs-version)
                    cask-project-path))

(defun cask-setup (project-path)
  "Setup cask for project at PROJECT-PATH."
  (setq cask-project-path (directory-file-name project-path))
  (setq cask-project-name (file-name-nondirectory cask-project-path))
  (setq cask-file (expand-file-name "Cask" cask-project-path))
  (setq cask-package-file (expand-file-name (concat cask-project-name "-pkg.el") cask-project-path))
  (when (equal (epl-package-dir) (epl-default-package-dir))
    (epl-change-package-dir (cask-elpa-dir)))
  (unless (file-exists-p cask-file)
    (let ((carton-file (expand-file-name "Carton" cask-project-path)))
      (if (file-exists-p carton-file)
        (progn
          (message "[DEPRECATION WARNING] Rename the file 'Carton' to 'Cask'")
          (setq cask-file carton-file))
        (error "Could not locate `Cask` file"))))
  (cask-eval (cask-read cask-file)))

(defun cask-initialize ()
  "Initialize packages under \"~/.emacs.d/\".
Setup `package-user-dir' appropriately and then call `package-initialize'."
  (cask-setup user-emacs-directory)
  (epl-initialize))

(defun cask--template-get (name)
  "Return content of template with NAME."
  (let* ((templates-dir (cask-resource-path "templates"))
         (template-file (expand-file-name name templates-dir)))
    (with-temp-buffer
      (insert-file-contents template-file)
      (buffer-string))))

(defun cask-update ()
  "Update dependencies.

Return a list of updated packages."
  (epl-refresh)
  (epl-initialize)
  (epl-upgrade))

(defun cask-install ()
  "Install dependencies."
  (let ((cask-dependencies (append cask-development-dependencies cask-runtime-dependencies)))
    (when cask-dependencies
      (epl-refresh)
      (epl-initialize)
      (dolist (dependency cask-dependencies)
        (epl-package-install (cask-dependency-name dependency))))))

(defun cask-init (path &optional dev-mode)
  "Create new project at PATH with optional DEV-MODE."
  (let ((init-content
         (cask--template-get
          (if dev-mode "init-dev.tpl" "init.tpl")))
        (cask-file-path (expand-file-name "Cask" path)))
    (if (file-exists-p cask-file-path)
        (error "Cask file already exists.")
      (with-temp-buffer
        (insert init-content)
        (write-file cask-file-path)))))

(defmacro with-cask-package (&rest body)
  `(if cask-package
       (progn ,@body)
     (error "Missing `package` or `package-file` directive")))

(defun cask-info ()
  "Return info about this project."
  (with-cask-package cask-package))

(defun cask-version ()
  "Return the version of this project."
  (with-cask-package (cask-package-version cask-package)))

(defun cask-package ()
  "Package this project."
  (with-cask-package (cask-define-package-string)))

(defun cask-load-path ()
  "Return Emacs `load-path' (including package dependencies)."
  (mapconcat
   'identity
   (append
    (file-expand-wildcards (concat (cask-elpa-dir) "/*") t)
    load-path)
   path-separator))

(defun cask-path ()
  "Return Emacs `exec-path' (including package dependencies)."
  (mapconcat
   'identity
   (append
    (file-expand-wildcards (concat (cask-elpa-dir) "/*/bin") t)
    exec-path)
   path-separator))

(defun cask-define-package-string ()
  "Return `define-package' string."
  (format
   "(define-package \"%s\" \"%s\"\n  \"%s\"%s)\n"
   (cask-package-name cask-package)
   (cask-package-version cask-package)
   (cask-package-description cask-package)
   (let ((dependency-string (cask-dependency-string)))
     (if (equal dependency-string "")
         "" (format "\n  '(%s)" dependency-string)))))

(defun cask-dependency-string ()
  "Return dependencies as string."
  (mapconcat
   (lambda (package)
     (let ((name (cask-dependency-name package))
           (version (cask-dependency-version package)))
       (format "(%s \"%s\")" name (or version ""))))
   cask-runtime-dependencies " "))

(provide 'cask)

;;; cask.el ends here

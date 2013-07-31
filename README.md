# Cask [![Build Status](https://api.travis-ci.org/rejeep/cask.el.png?branch=master)](http://travis-ci.org/rejeep/cask.el)

![Cask](https://raw.github.com/rejeep/cask.el/master/cask.png)

Cask for Emacs is what Bundler is to Ruby. It aims to make ELPA
dependency management in Emacs painless (as painless as it can
be). This includes both your local Emacs installation and Emacs
package development.

[<img src="http://img.youtube.com/vi/gzFxNO_X5yA/0.jpg">](https://www.youtube.com/watch?v=gzFxNO_X5yA)

## Migration from Carton

This project was previously named Carton, but because of a name clash
with another project, this project was renamed to Cask. A few things
needs to be done to migrate:

1. Use the `cask` command instead of the `carton` command
2. If your Emacs configuration dependes on `carton`, depend on `cask` instead:

   `(depends-on "carton")` => `(depends-on "cask")`

3. Rename the file `Carton` to `Cask`
4. Rename the installation directory (default `~/.carton`) to `~/.cask` (don't forget to update the path in you shell config)

_(And ohh, don't forget to update your `.travis.yml` and `.gitignore` files)_

## Installation

To automatically install Cask, run this command:

```bash
$ curl -fsSkL https://raw.github.com/rejeep/cask.el/master/go | sh
```

You can also clone the repository.

```bash
$ git clone https://github.com/rejeep/cask.el.git
```

Don't forget to add Cask's bin to your `PATH`.

```bash
$ export PATH="/path/to/code/cask/bin:$PATH"
```


## Usage

Create a file called `Cask` in your project root and specify
dependencies:

```bash
$ cask init [--dev]
```

_(Use `--dev` if the project is for package development)_

To install all dependencies, run:

```bash
$ cask [install]
```

This will create a directory called `.cask`, containing all dependencies.

To update package version, run:

```bash
$ cask update
```

To list all dependencies, run:

```bash
$ cask list
```

### Emacs configuration

Add this to your `.emacs` file.

```lisp
(require 'cask "~/.cask/cask.el")
(cask-initialize)
```

#### Tips

To automatically keep the `Cask` file up to date with what you
install from ELPA, check out <https://github.com/rdallasgray/pallet>.

### Package development

To create a `-pkg.el` file, run:

```bash
$ cask package
```

To run some Emacs Lisp code with ELPA load paths all set up for you, use:

```bash
$ cask exec [COMMAND]
```

Example:

```bash
$ cask exec make test
```

To print info about the current project:

```bash
$ cask info
```

## DSL

### source

Add an ELPA mirror.

```lisp
(source ALIAS)
(source NAME URL)
```

Example:

```lisp
(source melpa)
(source "melpa" "http://melpa.milkbox.net/packages/")
```

Available sources:

 * `gnu` <http://elpa.gnu.org/packages/>
 * `melpa` <http://melpa.milkbox.net/packages/>
 * `marmalade` <http://marmalade-repo.org/packages/>
 * `SC` <http://joseito.republika.pl/sunrise-commander/>
 * `org` <http://orgmode.org/elpa/>

### package

Define this package (used only for package development).

```lisp
(package NAME VERSION DESCRIPTION)
```

Example:

```lisp
(package "ecukes" "0.2.1" "Cucumber for Emacs.")
```

### depends-on

Add a runtime dependency.

```lisp
(depends-on NAME VERSION)
```

Example:

```lisp
(depends-on "magit" "0.8.1")
```

### package-file

Define this package and its runtime dependencies from the package headers of a
file (used only for package development).  The name of the file is relative to
the directory containing the `Cask` file.

```lisp
(package-file FILENAME)
```

Example:

```lisp
(package-file "foo.el")
```

### development

Set scope to development dependencies.

```lisp
(development [DEPENDENCIES])
```

Example:

```lisp
(development
 (depends-on "ecukes" "0.2.1")
 (depends-on "espuds" "0.1.0"))
```

## Example

### Local Emacs installation

```lisp
(source melpa)

(depends-on "magit")
(depends-on "drag-stuff")
(depends-on "wrap-region")
```

### Package development

```lisp
(source melpa)

(package "ecukes" "0.2.1" "Cucumber for Emacs.")

(depends-on "ansi")

(development
 (depends-on "el-mock")
 (depends-on "ert"))
```

## Completion

To install ZSH completion add the following to your `~/.zshrc`:

```bash
source /path/to/code/cask/etc/cask_completion.zsh
```

## I still don't get it, give me some real examples

These are some projects using Cask:

* [rejeep/emacs](https://github.com/rejeep/emacs)
* [drag-stuff](https://github.com/rejeep/drag-stuff)
* [emacs-jedi](https://github.com/tkf/emacs-jedi)
* [enclose](https://github.com/rejeep/enclose)
* [espuds](https://github.com/rejeep/espuds)
* [flycheck](https://github.com/lunaryorn/flycheck)
* [html-script-src](https://github.com/rejeep/html-script-src)
* [projectile](https://github.com/bbatsov/projectile)
* [ruby-end](https://github.com/rejeep/ruby-end)
* [ruby-tools](https://github.com/rejeep/ruby-tools)
* [wrap-region](https://github.com/rejeep/wrap-region)
* ...

## Contribution

Be sure to!

For each make command below, prefix with:

```bash
$ EMACS="/path/to/emacs"
```

For exmaple:

```bash
$ EMACS="/path/to/emacs" make abc
```

Run the unit tests with:

```bash
$ make unit
```

To run the Ecukes tests, first start the fake ELPA server:

```bash
$ make server
```

Then to run the tests:

```bash
$ make ecukes
```

Run all tests with:

```bash
$ make
```

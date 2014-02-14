IOCaml
======

IOCaml is an OCaml kernel for the [IPython
notebook](http://ipython.org/notebook.html). This provides a REPL
within a web browser with a nice user interface including markdown
based comments/documentation, mathjax formula and the possibility of
generating all manner of HTML based output media from your code.  Here
are a few features I think are particularly interesting;

* Uses ocp-index.lib to provide code completion and types
  (includes documentation if .cmt files exist).  Only works with
  installed libraries at the moment.  Very new, a wee bit buggy, but
  I love it.

* I copy/pasted the OCaml core language documentation page into
  a notebook.  Now you can learn interactively!

* Play with TyXML in the notebook and render typed HTML interactively.

Have a look at [the
example](http://nbviewer.ipython.org/github/andrewray/iocaml/blob/master/notebooks/iocaml-test-notebook.ipynb),
using the IPython web viewer to browse an IOCaml notebook.

# Installation

Installation is reasonably painless through opam, though you currently
need to add my remote repository [^1] and require a >=4.00.1 compiler.
Installation of IPython is a touch more involved as you will have to
update (using [pip](http://www.pip-installer.org/en/latest/)) some
python components [^2].  Instructions for Ubuntu 13.10 can be found
below, and I have also tested Fedora 20 which was, apart from some
slightly different package names, very similar.

[^1]: I'd love to push this to opam proper but require ocaml-zmq >=3.2.
There was a [recent
discussion](http://alan.petitepomme.net/cwn/2014.01.14.html#5) on the
caml-list about this (indeed reading about ZeroMQ led me to IPython)
so hopefully this will happen before too long.

[^2]: I haven't tested this release with 0.13.2 which the distros
provide.  Maybe it works anyway.

## Installing IPython

IOCaml is currently being developed against IPython 1.1. To set this up on Ubuntu 13.10 64 bit do;

```
$ sudo apt-get install libzmq3-dev python-dev ipython ipython-notebook \
   python-pip python-setuptools python-jinja2 m4 zlib1g-dev
```

Then update the following python packages;

```
$ sudo pip install -U ipython pyzmq
```

At the time of writing this should get IPython 1.1 installed.

```
$ ipython console
> Python 2.7.5+ (default, Sep 19 2013, 13:48:49) 
"copyright", "credits" or "license" for more information.

IPython 1.1.0 -- An enhanced Interactive Python.
?         -> Introduction and overview of IPython's features.
%quickref -> Quick reference.
help      -> Python's own help system.
object?   -> Details about 'object', use 'object??' for extra details.
```

For development testing you can download IPython packages or the github repository then run

```
$ python -m IPython [args]
```

from the directory the package in unpacked to.

## Installing IOCaml

### Via opam (>=1.1)

```
$ opam remote add iocaml git://github.com/andrewray/opam.git
$ opam install iocaml
```

Some notebooks and profile files are copied into the opam share directory.

Note that this will upgrade the opam version of ocaml-zmq to use the branch from [here](https://github.com/issuu/ocaml-zmq).

### Manually

Install required packages.

```
$ opam install atdgen cryptokit uuidm ounit uint oasis ocamlnet ocp-index optcomp
```

Clone the repositories we need to compile

```
$ git clone https://github.com/issuu/ocaml-zmq.git
$ git clone https://github.com/andrewray/iocaml.git
```

Compile ocaml-zmq

```
$ cd ocaml-zmq
$ oasis setup
$ make all
$ make install
```

compile IOCaml

```
$ cd iocaml
$ make all
$ make install
```

## Setting up IOCaml

Run IPython to setup a new iocaml profile

```
$ ipython profile create iocaml
```

Copy the contents of `profile/` into the the ipython profile directory `~/.config/ipython/profile_iocaml` (or sometimes `~/.ipython/profile_iocaml`).

```
$ cp -r profile/* ~/.config/ipython/profile_iocaml/
```

If installed with opam then the profile files are in share.

```
cp -r `opam config var share`/iocaml/profile/* ~/.config/ipython/profile_iocaml
```

Now you can run iocaml with

```
$ ipython notebook --profile=iocaml
```

## Command line options

There are a few command line options to iocaml which are set up in the ipython_config.py configuration file.

```
$ iocaml.top --help
iocaml kernel
  -log <filename>             open log file
  -connection-file <filename> connection file name
  -suppress {stdout|stderr|compiler|all}
                              suppress channel at start up
  -package <package>          load package at startup
  -completion                 enable tab completion
  -object-info                enable introspection
  -help                       Display this list of options
  --help                      Display this list of options

```

The defualt configuration loads the iocaml package at startup.


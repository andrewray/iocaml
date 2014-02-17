IOCaml
======

IOCaml is an OCaml kernel for the 
[IPython notebook](http://ipython.org/notebook.html). 
This provides a REPL within a web browser with a nice user interface 
including markdown based comments/documentation, mathjax formula and 
the possibility of generating all manner of HTML based output media 
from your code.  

[Example](notebooks/notebook-example-polys.png)
[![Example picture](https://github.com/andrewray/iocaml/raw/master/notebook/notebook-example-polys.png)]


Here are a few features I think are particularly interesting;

* Uses ocp-index.lib to provide code completion and types
  (includes documentation if .cmt files exist).  Only works with
  installed libraries at the moment.  Very new, a wee bit buggy, but
  I love it.

* I copy/pasted the OCaml core language documentation page into
  a notebook.  Now you can learn interactively!

* Play with TyXML in the notebook and render typed HTML interactively.

Have a look at 
[the example](http://nbviewer.ipython.org/github/andrewray/iocaml/blob/master/notebooks/iocaml-test-notebook.ipynb),
using the IPython web viewer to browse an IOCaml notebook.

# Installation

Installation is reasonably painless through opam, though you currently
need to add my remote repository and require a >=4.00.1 compiler.
Installation of IPython is a touch more involved as you will have to
update (using [pip](http://www.pip-installer.org/en/latest/)) some
python components.  Instructions for Ubuntu 13.10 can be found
below, and I have also tested Fedora 20 which was, apart from some
slightly different package names, very similar.

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

### Development IPython versions

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

## Setting up IOCaml

Run IPython to setup a new iocaml profile

```
$ ipython profile create iocaml
```

This will create a new profile hidden away in your home directory.  You can find out where with

```
$ ipython locate profile iocaml
```

Copy the default IOcaml profile files to the IPython profile

```
cp -r `opam config var share`/iocaml/profile/* `ipython locate profile iocaml`
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
  -package <package>          load package(s) at startup
  -thread                     enable system threads
  -syntax {none|camlp4o|camlp4r}
                              enable camlp4 pre-processor
  -completion                 enable tab completion
  -object-info                enable introspection
  -help                       Display this list of options
  --help                      Display this list of options

```

The defualt configuration loads the iocaml package at startup.


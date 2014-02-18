IOCaml
======

IOCaml is an OCaml kernel for the 
[IPython notebook](http://ipython.org/notebook.html). 
This provides a REPL within a web browser with a nice user interface 
including markdown based comments/documentation, mathjax formula and 
the possibility of generating all manner of HTML based output media 
from your code.  

[![Example picture](https://github.com/andrewray/iocaml/raw/master/notebooks/notebook-example-polys.png)]


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

Installation is reasonably painless through opam and requires >=4.00.1 compiler.
Installation of IPython is a touch more involved as you may have to
update (using [pip](http://www.pip-installer.org/en/latest/)) some
python components.  Instructions for Ubuntu 13.10 can be found
below, and I have also tested Fedora 20 which was, apart from some
slightly different package names, very similar.

## Installing IPython

### Ubuntu 13.10 (64 bit)

IOCaml is currently being developed against IPython 1.1. To set this up on Ubuntu 13.10 64 bit do;

```
$ sudo apt-get install libzmq3-dev python-dev ipython ipython-notebook \
   python-pip python-setuptools python-jinja2 m4 zlib1g-dev
```

Then update the following python packages;

```
$ sudo pip install -U ipython pyzmq
```

### MacOS X 10.9

[Installation script](https://gist.github.com/avsm/9041133)

### Arch linux

* Ipython 1.1 is already in arch's repository, no need to use pip

* ZMQ is version 4.0 in arch, but the ocaml binding is for 3.2, and it's not compiling anymore, so you need to install it manually (it works fine with abs).

* ipython-notebook is included in the ipython2, you just need to install python2-tornado and python2-jinja.

* It doesn't work with python 3, which is the default under arch, so you need to use ipython2

### Development IPython versions

For development testing you can download IPython packages or the github repository then run

```
$ python -m IPython [args]
```

from the directory the package in unpacked to.

## Installing IOCaml

### Via opam (>=1.1)

```
$ opam install iocaml
```

Some notebooks and profile files are copied into the opam share directory.

***Note*** If you previously added my opam remote repository from
git://github.com/andrewray/opam.git first '''opam remove'''
iocaml and ocaml-zmq packages then '''opam remote remove''' the repo.

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


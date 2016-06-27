![IOCaml logo](https://raw.githubusercontent.com/andrewray/iocamlserver/master/logos/IOlogo.png "IOCaml logo")

[![Build Status](https://travis-ci.org/andrewray/iocaml.svg?branch=master)](https://travis-ci.org/andrewray/iocaml)

IOCaml
======

IOCaml is an OCaml kernel for the 
[IPython notebook](http://ipython.org/notebook.html). 
This provides a REPL within a web browser with a nice user interface 
including markdown based comments/documentation, mathjax formula and 
the possibility of generating all manner of HTML based output media 
from your code.  

See also

* [IOCaml-kernel](https://github.com/andrewray/iocaml)
* [IOCamlJS-kernel](https://github.com/andrewray/iocamljs)
* [IOCaml-server](https://github.com/andrewray/iocamlserver)

This repository hosts the iocaml-kernel package.

![Example picture](https://github.com/andrewray/iocaml/raw/master/notebooks/notebook-example-polys.png)

# Installation

> **Note:** Currently you need to pin `cohttp` before installing iocaml:
> ```
$ opam pin add -y cohttp 0.20.2
$ opam install iocaml
```

Installation requires opam and OCaml >= 4.01.0.  To use the OCaml server 

```
$ opam install iocaml
```

which will install the kernels and server.  The individual kernels can be instaled with

```
$ opam install iocaml-kernel
$ opam install iocamljs-kernel
```

The kernel can also be used with the IPython/Jupyter server.

* [IPython](https://github.com/andrewray/iocaml/wiki/ipython_install) 
* [Jupyter](https://github.com/andrewray/iocaml/wiki/jupyter)

> **Note:** To use IOCaml with the latest IPython/Jupyter notebook, you'll need to start it with `--Session.key=''`:
> ```
jupyter notebook --Session.key=''
```
> This disables some security measures that iocaml doesn't yet support.

## Command line options

The following options may be given to the IOCaml-kernel (via
the IPython profile config) or IOCaml-server.

* ``` -log <filename> ``` open log file
* ``` -init <file> ``` load ```file``` instead of default init file
* ``` -completion ``` enable tab completion
* ``` -object-info ``` enable introspection

The following option is for use with IPython

* ``` -connection-file <filename> ``` connection file name

